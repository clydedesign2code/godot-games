# 2026-11-05｜口說讀指板原型

使用者需求：在指板隨機出現圓點，讓使用者說出該位置的音名並判斷；音名、唱名都要支援。

## 決策與行為

- 新增第四模式「口說讀譜」，與根音相對音程練習獨立。只問名稱，不測唱歌音準或八度。
- A–G 與固定唱名同時接受，C＝Do、B＝Si／Ti；支援升降與等音，如 F sharp／升 Fa／G flat。
- 自然音入門可切換全部半音；答對顯示音名，1.6 秒後進下一題。
- 麥克風按下才啟動。原生元件只使用裝置端辨識，不儲存錄音、不默默切換雲端。
- 顯示辨識文字，低信心、候選衝突、未授權、缺模型或麥克風錯誤不計錯。取消、換模式／語言／題目後舊結果不能判新題。
- 輸入答案可用同一套判題；聽音提示的完成與獨立完成分開計分，揭答不計完成。

## 技術棧與依賴

- Skill：先讀 `core_directives.md` → `godot_expert/SKILL.md`；`.agents` 未掛載，沿用本機 `ai-agent-skills` 的規則來源。
- Godot 4.6.2／GDScript：`src/voice/voice_quiz.gd` 管理題目與 UI，`note_answer.gd` 嚴格解析完整回答，`speech_bridge.gd` 管理非同步請求與隨機 ID 隔離。
- macOS Swift／AppKit／Speech／AVFoundation：以 `SFSpeechRecognizer`、`AVAudioEngine` 接收真實口說，原生 helper 作為獨立 App，使用 Info.plist 的兩項權限說明。Godot 以 `open` 啟動，原子 JSON 傳回文字、信心與替代候選。
- 開發依賴 Xcode Command Line Tools、`swiftc` 與 `codesign`，無套件或付費 API。`build/` 本機生成且不進 Godot 匯入／Git。
- 重現：執行 `bash games/guitar-intervals/tools/build_voice_macos.sh` → Godot 開啟專案 → 第四模式 → 明確按下麥克風並授權。英文／中文辨識語言可切換，但兩種答案命名都接受。
- 依據：[Apple on-device 能力](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition)、[強制裝置端辨識](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition)、[Godot OS](https://docs.godotengine.org/en/4.6/classes/class_os.html)。

## 驗證與界線

- Swift 編譯、App 簽署驗證與 Info.plist 格式檢查通過。
- 不開麥克風的正常權限能力探測確認此開發機 en-US／zh-TW 皆支援裝置端辨識；Speech 權限仍未請求。受限 shell 的探測曾誤報不可用，已核對正常本機環境。
- 口說測試包含所有 96 個指板位置的雙命名解析、實際 viewport 點擊、低信心／衝突、錯答重試、等音、成功換題、聽音提示、揭答、取消與過期請求。
- 原生 App 測試走實際 LaunchServices 啟動與 JSON 結果回傳，使用明確的測試結果，**不代表已驗證真人辨識**。
- 真人麥克風辨識準確度需使用者首次授權後試說；英文字母與唱名存在同音／近音，辨識文字用來讓使用者核對。
- 此版只接 macOS 開發環境。iOS／iPad 原生插件、匯出、權限與裝置測試待做，不能直接搬 macOS helper。
- 測試曾抓到動態 Node 呼叫未定型陣列導致聽音提示失敗；已改顯式 `Array[int]`，加入真實播放音高與白圈斷言。判題測試零失敗仍需檢查 SCRIPT ERROR，避免誤宣告。
