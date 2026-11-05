# 2026-11-05｜儀器面板、口說讀譜與根音操作更新

本次將初版之後的更新整理提交到 `codex/guitar-intervals-prototype`。專案維持在 `godot-games/games/guitar-intervals/`，以獨立的 `project.godot` 啟動。

## 已實作

- 依使用者指定參考 Teenage Engineering OP–1 field／EP–133 的面板語言：奶灰色外殼、深色指板顯示區、等寬標示、實體鍵帽感與橘色主要操作。
- 將音程／和弦下拉選單改成平鋪按鍵；大小音程並排，和弦直接顯示音級公式，根音欄顯示實際音名與弦品。
- 點擊位置的圓圈直接顯示完整音名，例如 E3、F♯3；合奏可同時顯示多個音。播放結束／靜音後保留名稱，新選音更新、切題清除。
- 完整答對顯示綠色回饋，1.6 秒後自動切題。部分三和弦、錯答與揭答不切題；手動換題或設定變更取消舊計時。
- 單擊試聽／作答、雙擊設定根音。雙擊第一下造成的作答計分會撤回，避免設定根音增加答對／錯答次數；舊題換題計時也會取消。原本的選根音按鈕保留。
- 第四模式「口說讀譜」接受 A–G 與固定唱名（C＝Do，B＝Si／Ti），含升降與等音。按下才開始聽，低信心／候選衝突／權限錯誤不計錯；提供輸入答案。詳見同日口說讀譜日誌。

## 技術棧與複用

- Skill：依 `core_directives.md`，使用 `godot_expert` 與 `self_improving_agent`；視覺參考 `ux_director` 的個人專案原則與使用者指定的產品方向。
- 引擎與介面：Godot 4.6.2、GDScript、Control 自繪指板；`src/ui/` 共用色彩與樣式，附 Noto Sans TC／Roboto Mono（SIL OFL）。
- 播放：AudioStreamWAV／AudioStreamPlayer 離線合成，依實際 MIDI 音高合奏。
- 語音：macOS Swift、AppKit、Speech、AVFoundation；Xcode Command Line Tools 建立並 ad-hoc 簽署原生 helper。只使用裝置端辨識，沒有外部付費服務。
- 複現：開啟 `games/guitar-intervals/project.godot`；macOS 口說需先執行 `bash games/guitar-intervals/tools/build_voice_macos.sh`，首次使用再由使用者授權。生成的 App 與 Swift cache 不進 Git，保留來源、建置腳本與授權說明。
- 驗證產物位於 `artifacts/`，以 `.gdignore` 排除 Godot 匯入。

## 驗證與審查

- 最新圖形回歸：**65,179 checks，0 failures**，含理論、實際 viewport 點擊、PCM 頻譜、音訊匯流排、顯示／計分／自動切題，以及雙擊根音的分數撤回與舊計時取消。
- 口說與圓圈操作：**305 checks，0 failures**，涵蓋雙命名、全部指板位置、低信心／衝突、實際原生 App 啟動與結果協定、取消／過期請求隔離。測試不開麥克風。
- Swift 編譯、codesign 與 Info.plist 驗證通過；日誌未見 SCRIPT ERROR，`git diff --check` 通過。
- 自行審查確認：切題與換模式清除舊狀態，雙擊不保留第一下誤計分，音名保留不依賴音訊是否播放，辨識結果以請求 ID 隔離。
- 已沉澱：型別陣列的動態 Node 呼叫、受限 shell 下的 Speech 探測誤判、靜態畫面截圖等待，記錄於共用 Godot skill；共用規則倉庫其他未提交變更不混入本專案提交。
- 此工作樹沒有 Git 提交身份設定；提交沿用初版的作者身份，僅用此次命令的設定，不修改全域 Git 設定。

## 待接續

- 使用者首次授權後驗證真人口說辨識效果；目前的原生協定測試不能代表辨識準確度。
- iPad／iOS 原生語音橋接、匯出／簽署與實機觸控測試。
- 其他調弦、左手模式、進度存檔與真實吉他取樣。
