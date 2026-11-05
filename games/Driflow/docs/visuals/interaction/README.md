# Driflow 互動配圖與再製

本組配圖對應 2026-11-05 的距離式物件互動原型。4 張實際遊戲截圖 + 9 張原創說明圖，共 13 張 PNG；9 張說明圖另保留可編輯 SVG。配圖供本機 Markdown 與 Notion 閱讀，不是新增的遊戲素材或 UI。

## 圖片索引

| 檔名 | 內容 | 性質 |
| --- | --- | --- |
| 01-switch-response.png | 黃色開關與燈光反應 | Godot 實際擷取 |
| 02-proximity-prompt.png | 女偵探走近櫃子的按鍵提示 | Godot 實際擷取 |
| 03-cabinet-menu.png | 櫃子選單開啟 | Godot 實際擷取 |
| 04-menu-response.png | 選定開啟後的具體反應 | Godot 實際擷取 |
| 05-interaction-flow | 按鍵至訊號反應的流程 | PNG + SVG 概念圖 |
| 06-responsibility-map | 管理器、組件、主角與反應分工 | PNG + SVG 結構圖 |
| 07-distance-priority | 距離與 priority 規則 | PNG + SVG 示意圖；距離為範例 |
| 08-scene-structure | 場景節點與檔案對照 | PNG + SVG 結構圖 |
| 09-input-guard | 選單確認與跳躍的輸入隔離 | PNG + SVG 時序圖 |
| 10-interaction-lifecycle | 就緒、選單、反應與禁用狀態 | PNG + SVG 狀態圖 |
| 11-add-an-object | 新增物件與 Inspector 欄位 | PNG + SVG 操作示意；不是編輯器截圖 |
| 12-platform-data | 平台、展示物件與測試共用資料 | PNG + SVG 資料依賴圖 |
| 13-verification-map | 42 項核心、21 項整合與原動作回歸 | PNG + SVG 驗證範圍圖 |

## 重新產生概念圖

來源：`source/generate_diagrams.py`。需要 Python 3 與 Pillow；本機驗證使用 Pillow 13.0.0。中文使用 macOS 的 STHeiti 字型；換電腦時請將來源的 FONT／BOLD 改為可用的中文字型。

從 monorepo 根目錄執行：

```sh
python3 games/Driflow/docs/visuals/interaction/source/generate_diagrams.py /tmp/driflow-diagrams
```

輸出 PNG 與 SVG，先檢查文字可讀、箭頭方向、數值與程式一致，再更新 repo 及 Notion 的對應圖。這支腳本只產生原創圖形，不會編輯遊戲截圖。

## 重新擷取實際畫面

來源：`source/capture_interactions.gd`。需要 Godot 4.6.2、可用的圖形 renderer 與目前 Driflow 專案。圖片來源為實際關卡、角色與互動 UI，沒有生成式改畫。

```sh
/Applications/Godot.app/Contents/MacOS/Godot \
  --path /Users/clydewang/GITHUB/godot-games/games/Driflow \
  --script /Users/clydewang/GITHUB/godot-games/games/Driflow/docs/visuals/interaction/source/capture_interactions.gd \
  -- /tmp/driflow-documentation-frames
```

不要加 `--headless`；此模式無法輸出實際渲染畫面。預期 `DOCUMENTATION CAPTURE: PASS (4 actual game frames)`，並檢查 4 個 PNG 確實存在、不是空白。擷取會在獨立執行程序內觸發展示物件，不修改專案或存檔。

本目錄的 `.gdignore` 避免 Godot 編輯器把文件配圖匯入成遊戲素材。擷取腳本以明確的絕對檔案路徑交給 CLI 執行。

## 圖文維護規則

- 截圖、概念圖、欄位範例分別標示，圖說指出讀者應觀察的重點。
- 結構圖的箭頭對應實際呼叫、訊號或資料來源；InteractionOption 是資料，不會發送 interacted。
- 圖中的距離範例與 Inspector 範例不代表展示物件的實際設定；真實值仍以場景和程式為準。
- 變更輸入、狀態或平台後，檢查相關圖的函式名、流程與數值，必要時重新擷取；歷史測試結果仍需保留時間與範圍。
- 圖片放在對應章節旁，不以大量無關圖片取代技術說明。
- Notion 已上傳 13 張 PNG；repo 同時保留 SVG 與來源。上傳憑證、短期上傳網址不保存在 repo。

技術棧與工具：Godot 4.6.2／GDScript 原場景擷取；Python 3／Pillow／SVG 原創圖形；Notion 連接器準備專用上傳網址，單次 multipart POST 傳送圖片，再以原生 image block 插入既有頁面。

## Notion 閱讀版

- [開發日誌](https://app.notion.com/p/40fc42073e3381089418ff23b6833ac7)
- [維護指南](https://app.notion.com/p/40fc42073e3381db838cf7b1696b274a)
