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
    var lastSpeech: Date?
    var endedAt: Date?

    init(session: URL, identifier: String, locale: String, protocolTest: Bool = false) {
        self.session = session
        self.identifier = identifier
        self.locale = locale
        self.protocolTest = protocolTest
    }

    func write(_ fields: [String: Any]) {
        var payload = fields
        payload["id"] = identifier
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? data.write(to: session.appendingPathComponent("status.json"), options: .atomic)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if protocolTest {
            // Exercise the same LaunchServices lifecycle and atomic output path,
            // without requesting permissions or opening an input device.
            complete(["state": "result", "text": "B flat", "confidence": 0.9, "alternatives": ["A sharp"]])
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.poll() }
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
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = false
        request.taskHint = .confirmation
        // Every pitch is equally represented. Never supply the correct answer.
        request.contextualStrings = ["A", "B", "C", "D", "E", "F", "G", "A sharp", "B flat", "C sharp", "D flat", "D sharp", "E flat", "F sharp", "G flat", "G sharp", "A flat", "do", "re", "mi", "fa", "sol", "la", "si", "ti", "升 Do", "降 Re", "升 Re", "降 Mi", "升 Fa", "降 Sol", "升 Sol", "降 La", "升 La", "降 Si"]
        self.request = request
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { fail("no_input"); return }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
        tapInstalled = true
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
                        self.lastSpeech = Date()
                        self.write(["state": "partial", "text": text])
                    }
                }
                if error != nil { self.fail("recognition_error") }
            }
        }
        do {
            engine.prepare()
            try engine.start()
            listening = true
            started = Date()
            write(["state": "listening"])
        } catch { fail("no_input") }
    }

    func poll() {
        guard !terminal else { return }
        if FileManager.default.fileExists(atPath: session.appendingPathComponent("cancel").path) {
            cancel(); return
        }
        if Date().timeIntervalSince(launched) > 65 { fail("no_speech"); return }
        guard listening else { return }
        if ending {
            if let endedAt, Date().timeIntervalSince(endedAt) > 4 { fail("no_speech") }
            return
        }
        let finish = FileManager.default.fileExists(atPath: session.appendingPathComponent("finish").path)
        let silent = lastSpeech.map { Date().timeIntervalSince($0) > 1.6 } ?? false
        if finish || silent || Date().timeIntervalSince(started) > 8 {
            ending = true
            endedAt = Date()
            stopInput()
            request?.endAudio()
        }
    }

    func stopInput() {
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
        write(payload)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
    }

    func cancel() {
        terminal = true
        stopInput()
        task?.cancel()
        timer?.invalidate()
        // Only this per-request random directory is ever removed.
        try? FileManager.default.removeItem(at: session)
        NSApp.terminate(nil)
    }
}

@main
struct Main {
    static func main() {
        let args = CommandLine.arguments
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
        let delegate = NoteSpeech(session: session, identifier: id, locale: value("--locale") ?? "en-US", protocolTest: args.contains("--protocol-test"))
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}
