import AppKit
import AVFoundation
import Speech

// This helper is launched only by an explicit microphone button press.
// It requires on-device recognition and never stores microphone recordings.
final class NoteSpeech: NSObject, NSApplicationDelegate {
    let session: URL
    let identifier: String
    let locale: String
    let protocolTest: Bool
    let workflowTest: Bool
    static let maxRecordingSeconds: Double = 10
    let engine = AVAudioEngine()
    var recognizer: SFSpeechRecognizer?
    var request: SFSpeechAudioBufferRecognitionRequest?
    var task: SFSpeechRecognitionTask?
    var timer: Timer?
    var listening = false
    var ending = false
    var terminal = false
    var tapInstalled = false
    let launched = Date()
    var started = Date()
    var endedAt: Date?
    let bufferLock = NSLock()
    var buffers: [AVAudioPCMBuffer] = []
    var captureEnabled = false
    var capturedFrames: AVAudioFrameCount = 0
    var level: Float = 0
    var peakLevel: Float = 0
    var measuredLevel = false

    init(session: URL, identifier: String, locale: String, protocolTest: Bool = false, workflowTest: Bool = false) {
        self.session = session
        self.identifier = identifier
        self.locale = locale
        self.protocolTest = protocolTest
        self.workflowTest = workflowTest
    }

    func write(_ fields: [String: Any]) {
        var payload = fields
        payload["id"] = identifier
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? data.write(to: session.appendingPathComponent("status.json"), options: .atomic)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if FileManager.default.fileExists(atPath: session.appendingPathComponent("cancel").path) {
            cancel(); return
        }
        if protocolTest {
            // Exercise the same LaunchServices lifecycle and atomic output path,
            // without requesting permissions or opening an input device.
            complete(["state": "result", "text": "B flat", "confidence": 0.9, "alternatives": ["A sharp"]])
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.poll() }
        if workflowTest {
            // Real app/command/status lifecycle; no microphone or permissions.
            listening = true
            started = Date()
            writeListening()
            return
        }
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
        guard let recognizer, recognizer.supportsOnDeviceRecognition else {
            fail("offline_unavailable"); return
        }
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard !self.terminal else { return }
                guard status == .authorized else { self.fail("speech_denied"); return }
                AVCaptureDevice.requestAccess(for: .audio) { allowed in
                    DispatchQueue.main.async {
                        guard !self.terminal else { return }
                        if allowed { self.begin() } else { self.fail("microphone_denied") }
                    }
                }
            }
        }
    }

    func begin() {
        guard !FileManager.default.fileExists(atPath: session.appendingPathComponent("cancel").path) else {
            cancel(); return
        }
        guard let recognizer, recognizer.isAvailable else { fail("unavailable"); return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { fail("no_input"); return }
        bufferLock.lock()
        captureEnabled = true
        bufferLock.unlock()
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.capture(buffer)
        }
        tapInstalled = true
        do {
            engine.prepare()
            try engine.start()
            listening = true
            started = Date()
            writeListening() // Only after the input engine has actually started.
        } catch { fail("no_input") }
    }

    func capture(_ buffer: AVAudioPCMBuffer) {
        // Keep at most ten seconds in RAM. No recording is written to disk.
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { return }
        copy.frameLength = buffer.frameLength
        let source = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: buffer.audioBufferList))
        let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for index in 0..<source.count {
            if let from = source[index].mData, let to = destination[index].mData {
                to.copyMemory(from: from, byteCount: Int(source[index].mDataByteSize))
            }
        }
        var rms: Float = 0
        let measurable = buffer.format.commonFormat == .pcmFormatFloat32
        if measurable, let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 {
            let stride = buffer.format.isInterleaved ? Int(buffer.format.channelCount) : 1
            var squares: Float = 0
            for index in 0..<Int(buffer.frameLength) {
                let sample = samples[index * stride]
                squares += sample * sample
            }
            rms = sqrt(squares / Float(buffer.frameLength))
        }
        bufferLock.lock()
        defer { bufferLock.unlock() }
        let maxFrames = AVAudioFrameCount(buffer.format.sampleRate * Self.maxRecordingSeconds)
        guard captureEnabled, capturedFrames < maxFrames else { return }
        copy.frameLength = min(copy.frameLength, maxFrames - capturedFrames)
        buffers.append(copy)
        capturedFrames += copy.frameLength
        level = rms
        peakLevel = max(peakLevel, rms)
        measuredLevel = measuredLevel || measurable
    }

    func writeListening() {
        bufferLock.lock()
        let meter = min(1.0, Double(level) * 8)
        bufferLock.unlock()
        let remaining = max(0, Int(ceil(Self.maxRecordingSeconds - Date().timeIntervalSince(started))))
        write(["state": "listening", "level": workflowTest ? 0.35 : meter, "remaining_seconds": remaining])
    }

    func finishCapture(reason: String) {
        guard listening, !ending, !terminal else { return }
        ending = true
        endedAt = Date()
        stopInput()
        write(["state": "processing", "reason": reason])
        if workflowTest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.complete(["state": "result", "text": "B flat", "confidence": 0.9, "alternatives": ["A sharp"]])
            }
            return
        }
        bufferLock.lock()
        let recording = buffers
        buffers.removeAll()
        let silent = measuredLevel && peakLevel < 0.0005
        bufferLock.unlock()
        guard !recording.isEmpty else { fail("no_speech"); return }
        guard !silent else { fail("silent_input"); return }
        startRecognition(recording)
    }

    func startRecognition(_ recording: [AVAudioPCMBuffer]) {
        guard let recognizer, recognizer.isAvailable else { fail("unavailable"); return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = false
        request.taskHint = .confirmation
        // Every pitch is equally represented. Never supply the correct answer.
        request.contextualStrings = ["A", "B", "C", "D", "E", "F", "G", "A sharp", "B flat", "C sharp", "D flat", "D sharp", "E flat", "F sharp", "G flat", "G sharp", "A flat", "do", "re", "mi", "fa", "sol", "la", "si", "ti", "升 Do", "降 Re", "升 Re", "降 Mi", "升 Fa", "降 Sol", "升 Sol", "降 La", "升 La", "降 Si"]
        self.request = request
        task = recognizer.recognitionTask(with: request) { result, error in
            DispatchQueue.main.async {
                guard !self.terminal else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    if result.isFinal {
                        let segments = result.bestTranscription.segments
                        let confidence = segments.isEmpty ? 0.0 : segments.map { Double($0.confidence) }.min() ?? 0.0
                        self.complete([
                            "state": "result", "text": text, "confidence": confidence,
                            "alternatives": Array(result.transcriptions.dropFirst().prefix(4)).map { $0.formattedString }
                        ])
                        return
                    }
                    if !text.isEmpty {
                        self.write(["state": "partial", "text": text])
                    }
                }
                if let error {
                    let diagnostic = error as NSError
                    NSLog("Speech recognition failed: %@ [%ld]", diagnostic.domain, diagnostic.code)
                    self.fail("recognition_error")
                }
            }
        }
        for buffer in recording { request.append(buffer) }
        request.endAudio()
    }

    func poll() {
        guard !terminal else { return }
        if FileManager.default.fileExists(atPath: session.appendingPathComponent("cancel").path) {
            cancel(); return
        }
        if !listening, Date().timeIntervalSince(launched) > 65 { fail("unavailable"); return }
        if ending {
            if let endedAt, Date().timeIntervalSince(endedAt) > 15 { fail("recognition_error") }
            return
        }
        guard listening else { return }
        let finish = FileManager.default.fileExists(atPath: session.appendingPathComponent("finish").path)
        if finish { finishCapture(reason: "manual") }
        else if Date().timeIntervalSince(started) >= Self.maxRecordingSeconds { finishCapture(reason: "time_limit") }
        else { writeListening() }
    }

    func stopInput() {
        bufferLock.lock()
        captureEnabled = false
        bufferLock.unlock()
        if engine.isRunning { engine.stop() }
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
    }

    func fail(_ code: String) { complete(["state": "error", "code": code]) }

    func complete(_ payload: [String: Any]) {
        guard !terminal else { return }
        terminal = true
        stopInput()
        task?.cancel()
        timer?.invalidate()
        buffers.removeAll()
        write(payload)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
    }

    func cancel() {
        terminal = true
        stopInput()
        task?.cancel()
        timer?.invalidate()
        buffers.removeAll()
        // Only this per-request random directory is ever removed.
        try? FileManager.default.removeItem(at: session)
        NSApp.terminate(nil)
    }
}

@main
struct Main {
    static func bufferSelfTest() -> Bool {
        let helper = NoteSpeech(session: URL(fileURLWithPath: "/tmp"), identifier: "", locale: "en-US")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        input.frameLength = 1024
        for index in 0..<1024 { input.floatChannelData![0][index] = 0.25 }
        helper.captureEnabled = true
        helper.capture(input)
        input.floatChannelData![0][0] = 0
        guard helper.buffers.count == 1, helper.buffers[0].floatChannelData![0][0] == 0.25,
              helper.buffers[0].frameLength == 1024, helper.level > 0.2 else { return false }
        for _ in 0..<500 { helper.capture(input) }
        guard helper.capturedFrames == 441000 else { return false }
        let count = helper.buffers.count
        helper.captureEnabled = false
        helper.capture(input)
        guard helper.buffers.count == count else { return false }
        // Exercise the generic buffer-list copy for interleaved integer stereo.
        let stereo = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 2, interleaved: true)!
        let pair = AVAudioPCMBuffer(pcmFormat: stereo, frameCapacity: 32)!
        pair.frameLength = 32
        let source = UnsafeMutableAudioBufferListPointer(pair.mutableAudioBufferList)[0].mData!.assumingMemoryBound(to: Int16.self)
        for index in 0..<64 { source[index] = Int16(index * 3) }
        let second = NoteSpeech(session: URL(fileURLWithPath: "/tmp"), identifier: "", locale: "en-US")
        second.captureEnabled = true
        second.capture(pair)
        guard let copied = second.buffers.first else { return false }
        let samples = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: copied.audioBufferList))[0].mData!.assumingMemoryBound(to: Int16.self)
        return samples[63] == 189 && copied.format.channelCount == 2 && copied.frameLength == 32
    }

    static func main() {
        let args = CommandLine.arguments
        if args.contains("--buffer-self-test") {
            let passed = bufferSelfTest()
            print("BUFFER TEST RESULT: \(passed ? "PASS" : "FAIL") — deep PCM copy, input meter, duration cap, stop gate and interleaved channels; no microphone")
            exit(passed ? 0 : 1)
        }
        func value(_ key: String) -> String? {
            guard let index = args.firstIndex(of: key), index + 1 < args.count else { return nil }
            return args[index + 1]
        }
        if args.contains("--probe") {
            let locales = ["en-US", "zh-TW"]
            let values = locales.map { code -> [String: Any] in
                let r = SFSpeechRecognizer(locale: Locale(identifier: code))
                return ["locale": code, "on_device": r?.supportsOnDeviceRecognition ?? false]
            }
            let result: [String: Any] = ["locales": values, "speech_authorization": SFSpeechRecognizer.authorizationStatus().rawValue, "microphone_authorization": AVCaptureDevice.authorizationStatus(for: .audio).rawValue]
            if let data = try? JSONSerialization.data(withJSONObject: result), let string = String(data: data, encoding: .utf8) { print(string) }
            return // Capability probe never requests permission or opens the microphone.
        }
        guard let folder = value("--session"), let id = value("--id"), id.count == 32,
              id.allSatisfy({ $0.isHexDigit }), folder.hasSuffix("voice-session-" + id) else { return }
        let session = URL(fileURLWithPath: folder, isDirectory: true)
        guard FileManager.default.fileExists(atPath: session.path) else { return }
        let delegate = NoteSpeech(session: session, identifier: id, locale: value("--locale") ?? "en-US", protocolTest: args.contains("--protocol-test"), workflowTest: args.contains("--workflow-test"))
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}
