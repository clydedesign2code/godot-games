# AGENTS.md — godot-games

## Bootstrap Protocol
每次對話開始時，靜默執行以下步驟：

1. 讀取 `.agents/rules/core_directives.md`（最高行為準則）
2. 依任務類型按需載入 `.agents/skills/{skill_name}/SKILL.md`
3. 載入完成後再開始回應用戶

**Single Source of Truth：** GitHub `.agents` submodule  
**Notion 定位：** 僅供人類閱讀，不是規則來源

---

## Monorepo 結構

```
godot-games/
├── .agents/          ← ai-agent-skills submodule（跨工具共用規則）
├── games/            ← 各遊戲獨立子目錄，每個子目錄都是完整 Godot 專案
│   ├── 2d-avg/         ← 2D 像素解謎冒險（原 _Godot_2D_AVG）
│   ├── udemy-frogger/  ← Udemy 課程：Frogger 複製版（已完成）
│   └── udemy-metroid/  ← Udemy 課程：Metroid-like（起始包，待實作）
└── shared/           ← 預留跨遊戲共用資源
```

**原則**：每個 `games/<name>/` 都包含完整 `project.godot`，可被 Godot 編輯器直接開啟，路徑全部為 `res://` 相對路徑，互不干擾。

---

## 遊戲技術棧

| 目錄 | 引擎版本 | Addons | 主要語言 | 備注 |
|------|---------|--------|---------|------|
| `games/2d-avg/` | Godot 4.6 | Dialogic 2.0 | GDScript | 原創冒險遊戲 |
| `games/udemy-frogger/` | Godot 4 | — | GDScript | Udemy 課程習作，已完成 |
| `games/udemy-metroid/` | Godot 4 | — | GDScript | Udemy 課程習作，起始包待實作 |

---

## 記憶寫入規範

- 新學到的 Godot 規則、GDScript 踩坑 → `.agents/skills/godot_expert/SKILL.md`
- Monorepo 基礎設施變更 → 本檔 `AGENTS.md`
- 跨工具通用規則 → `.agents/rules/core_directives.md`
- 禁止寫入 `~/.claude/projects/.../memory/`（非正式規則存放處）

---

## 推薦技能組合

- `godot_expert`（Godot 4 架構、GDScript、像素渲染）
- `self_improving_agent`（自我進化、復盤）

---

## 📜 決策與進度日誌

### 2026-06-10 | Udemy 課程專案整合
- **來源**：`_GodotProjects-udemy/`（外部 repo）→ monorepo
- **udemy-frogger**：完整可執行的 Frogger 遊戲，含 scenes/、audio/、fonts/、graphics/
- **udemy-metroid**：Udemy 起始包（assets + project.godot），Metroid-like 遊戲待實作
- **原則**：課程習作與原創遊戲平行存放，不共用資源，res:// 路徑各自獨立

### 2026-07-20 | Popochiu 最小骨架重建
- **背景**：`547d620` 安裝 Popochiu v2.1.1 後，開啟編輯器觸發首次設定精靈，自動生成完整 demo（Clyde 角色、BedRoom/Kitchen/GuestRoom 三房、SimpleClickHighRes GUI），與 `DESIGN.md` 定位（Popochiu 僅供「他者時代／靈魂閃回」片段使用）不符
- **決策**：清空 demo 素材（`game/characters`、`game/gui`、`game/rooms`），還原 `c.gd`/`r.gd`/`popochiu_data.cfg`，`project.godot` 僅移除 demo 的 `run/main_scene`，保留 godot_mcp autoloads 與 1920x1080 `canvas_items` 顯示設定（與 demo 無關的既有變更）
- **完成**：已透過 Popochiu dock 建立最小骨架 `Room1`（`game/rooms/room_1/`）+ `Character1`（`game/characters/character_1/`），GUI 樣板（`game/gui/`，SimpleClickHighRes）為必要框架本體一併生成，非 demo 內容
- **驗證通過**：房間導航（點擊走動）、Hotspot 觸發對話樹（`TestDialog`）、inventory item 線索追蹤（`Clue`，`I.Clue.add()`）三條技術流程都已跑通。過程中踩到三個坑，已寫進 `.agents/skills/godot_expert/SKILL.md` 的已知陷阱：Popochiu 缺少 Input Map 動作導致點擊無反應、房間裡手動塞角色會變不可互動的幽靈副本、`project.godot` 的 `run/main_scene` 文字編輯不可靠
- **待辦**：目前 `Room1`/`Character1`/`TestDialog`/`Clue` 都是技術驗證用的占位命名，尚未清理成正式內容。依 `DESIGN.md` 的 Pentiment 式他者時代場次，下一步要決定第一個具體場景/角色，再把這些占位物件替換或擴充為實際內容

### 2026-05-13 | Monorepo 初始化 + 2D AVG 遷移
- **決策**：`godot-games` 採 monorepo，每個遊戲放 `games/<name>/`，廢棄 `_Godot_2D_AVG` 獨立 repo
- **遷移內容**：`src/`（23 GDScript 檔）、`assets/`、`addons/`（Dialogic 2.0）、`dialogic/`、`fonts/`、`resources/`、`artifacts/`、`_steam/`、`project.godot`
- **架構保留**：GameManager / SaveManager / AudioManager / CursorManager / InventoryManager + EventBus + Composition-based Components + 3-state Player FSM
- **不需要修改**：所有 `res://` 路徑自動成立，Dialogic UID 由 Godot 重建
- **待辦**：用 Godot 4 編輯器開啟 `games/2d-avg/project.godot` 驗證、歸檔原 `_Godot_2D_AVG` repo
