extends Node
## One short, explicitly started native recognition session. No microphone on load.
## The macOS helper communicates through an atomic JSON file in a private session.
signal status_changed(message: String)
signal phase_changed(phase: String)
signal meter_changed(level: float, remaining_seconds: int)
signal recognized(result: Dictionary)
signal failed(message: String)

const HELPER := "res://build/NoteSpeech.app"
const ERRORS := {
	"speech_denied": "語音辨識未獲授權，請在系統設定允許 FR–12 Voice；也可輸入答案。",
	"microphone_denied": "麥克風未獲授權，請在系統設定允許 FR–12 Voice；也可輸入答案。",
	"offline_unavailable": "此辨識語言的裝置端模型不可用。可換另一種語言，或輸入答案。",
	"unavailable": "語音辨識目前不可用，請稍後重試，或輸入答案。",
	"no_input": "找不到可用的麥克風，請檢查輸入裝置。",
	"no_speech": "沒有聽清楚，請再說一次；這次不計錯。",
	"silent_input": "沒有收到清楚的聲音。請檢查麥克風輸入音量，靠近後重試；不計錯。",
	"recognition_error": "這次未能完成辨識，請重說；這次不計錯。"
}
var active: bool = false
var phase: String = "idle"
var input_level: float = 0.0
var remaining_seconds: int = 10
var session_path: String = ""
var request_id: String = ""
var elapsed: float = 0.0
var last_payload: String = ""
var launch_native: bool = true # Tests disable launching and feed the real file protocol.


func available() -> bool:
	return OS.get_name() == "macOS" and FileAccess.file_exists(HELPER.path_join("Contents/MacOS/NoteSpeech"))


func start(locale: String = "en-US") -> bool:
	cancel()
	if launch_native and not available():
		_set_phase("error")
		failed.emit("此版本尚未提供語音元件。可先輸入音名／唱名作答；macOS 開發版請先建立語音元件。")
		return false
	request_id = Crypto.new().generate_random_bytes(16).hex_encode()
	session_path = ProjectSettings.globalize_path("user://voice-session-" + request_id)
	if DirAccess.make_dir_recursive_absolute(session_path) != OK:
		_set_phase("error")
		failed.emit("無法建立語音工作目錄，請先使用輸入答案。")
		return false
	active = true
	elapsed = 0.0
	last_payload = ""
	_set_phase("preparing")
	status_changed.emit("先不用說話。正在準備麥克風；首次使用請允許系統權限。")
	if launch_native:
		var pid: int = OS.create_process("/usr/bin/open", PackedStringArray(["-n", "-g", ProjectSettings.globalize_path(HELPER), "--args", "--session", session_path, "--id", request_id, "--locale", locale]))
		if pid < 0:
			cancel()
			_set_phase("error")
			failed.emit("無法啟動語音元件，請先使用輸入答案。")
			return false
	return true


func finish() -> void:
	if active and phase == "listening":
		_write_command("finish")
		_set_phase("stopping")
		status_changed.emit("請停止說話。正在關閉這次收音…")


func _set_phase(value: String) -> void:
	if phase != value:
		phase = value
		elapsed = 0.0
		phase_changed.emit(phase)


func _write_command(command: String) -> void:
	var file := FileAccess.open(session_path.path_join(command), FileAccess.WRITE)
	if file != null:
		file.store_string(request_id)


func cancel() -> void:
	if active:
		_write_command("cancel")
	active = false
	_set_phase("idle")
	input_level = 0.0
	remaining_seconds = 10
	meter_changed.emit(input_level, remaining_seconds)
	_cleanup_files()


func _cleanup_files() -> void:
	if session_path.is_empty():
		return
	# A cancel marker remains briefly so a helper still showing a permission prompt
	# can see it. Native helper removes it and the folder when it exits.
	for filename in ["status.json", "finish"]:
		DirAccess.remove_absolute(session_path.path_join(filename))
	if not FileAccess.file_exists(session_path.path_join("cancel")):
		DirAccess.remove_absolute(session_path)


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	var timeout: float = 70.0 if phase == "preparing" else 20.0
	if elapsed > timeout:
		cancel()
		_set_phase("error")
		failed.emit("等待語音權限或辨識逾時，請重試；這次不計錯。")
		return
	var path := session_path.path_join("status.json")
	if not FileAccess.file_exists(path):
		return
	var payload := FileAccess.get_file_as_string(path)
	if payload == last_payload:
		return
	var decoded: Variant = JSON.parse_string(payload)
	if not decoded is Dictionary or str(decoded.get("id", "")) != request_id:
		return
	last_payload = payload
	var state: String = str(decoded.get("state", ""))
	if state == "listening":
		if phase in ["stopping", "processing"]:
			return # A late meter update cannot reopen the stop button.
		var was_listening: bool = phase == "listening"
		_set_phase("listening")
		input_level = clampf(float(decoded.get("level", 0.0)), 0.0, 1.0)
		remaining_seconds = clampi(int(decoded.get("remaining_seconds", 10)), 0, 10)
		meter_changed.emit(input_level, remaining_seconds)
		if not was_listening:
			status_changed.emit("現在可以說一個音名或唱名。說完請按「說完了」；最長收音 10 秒。")
	elif state == "processing":
		_set_phase("processing")
		input_level = 0.0
		meter_changed.emit(0.0, 0)
		status_changed.emit("收音已停止，正在辨識。請等結果，不必再說話。")
	elif state == "partial":
		# Native recognition only starts after capture has stopped. Its first
		# partial can replace the processing file before a render-frame poll.
		_set_phase("processing")
		input_level = 0.0
		meter_changed.emit(0.0, 0)
		status_changed.emit("收音已停止，正在確認：%s" % str(decoded.get("text", "")))
	elif state == "result":
		active = false
		_set_phase("idle")
		_cleanup_files()
		recognized.emit(decoded)
	elif state == "error":
		active = false
		_set_phase("error")
		_cleanup_files()
		failed.emit(ERRORS.get(str(decoded.get("code", "")), ERRORS.recognition_error))


func _exit_tree() -> void:
	cancel()
