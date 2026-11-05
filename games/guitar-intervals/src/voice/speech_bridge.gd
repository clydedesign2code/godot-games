extends Node
## One short, explicitly started native recognition session. No microphone on load.
## The macOS helper communicates through an atomic JSON file in a private session.
signal status_changed(message: String)
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
	"recognition_error": "這次未能完成辨識，請重說；這次不計錯。"
}
var active: bool = false
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
		failed.emit("此版本尚未提供語音元件。可先輸入音名／唱名作答；macOS 開發版請先建立語音元件。")
		return false
	request_id = Crypto.new().generate_random_bytes(16).hex_encode()
	session_path = ProjectSettings.globalize_path("user://voice-session-" + request_id)
	if DirAccess.make_dir_recursive_absolute(session_path) != OK:
		failed.emit("無法建立語音工作目錄，請先使用輸入答案。")
		return false
	active = true
	elapsed = 0.0
	last_payload = ""
	status_changed.emit("準備麥克風…首次使用需允許系統權限。")
	if launch_native:
		var pid: int = OS.create_process("/usr/bin/open", PackedStringArray(["-n", "-g", ProjectSettings.globalize_path(HELPER), "--args", "--session", session_path, "--id", request_id, "--locale", locale]))
		if pid < 0:
			cancel()
			failed.emit("無法啟動語音元件，請先使用輸入答案。")
			return false
	return true


func finish() -> void:
	if active:
		_write_command("finish")
		status_changed.emit("正在確認你說的音名…")


func _write_command(command: String) -> void:
	var file := FileAccess.open(session_path.path_join(command), FileAccess.WRITE)
	if file != null:
		file.store_string(request_id)


func cancel() -> void:
	if active:
		_write_command("cancel")
	active = false
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
	if elapsed > 70.0:
		cancel()
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
		status_changed.emit("正在聽…說一個音名或唱名，說完稍停，或按「完成說話」。")
	elif state == "partial":
		status_changed.emit("聽辨中：%s" % str(decoded.get("text", "")))
	elif state == "result":
		active = false
		_cleanup_files()
		recognized.emit(decoded)
	elif state == "error":
		active = false
		_cleanup_files()
		failed.emit(ERRORS.get(str(decoded.get("code", "")), ERRORS.recognition_error))


func _exit_tree() -> void:
	cancel()
