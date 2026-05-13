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
│   └── 2d-avg/       ← 2D 像素解謎冒險（原 _Godot_2D_AVG）
└── shared/           ← 預留跨遊戲共用資源
```

**原則**：每個 `games/<name>/` 都包含完整 `project.godot`，可被 Godot 編輯器直接開啟，路徑全部為 `res://` 相對路徑，互不干擾。

---

## 遊戲技術棧

| 目錄 | 引擎版本 | Addons | 主要語言 |
|------|---------|--------|---------|
| `games/2d-avg/` | Godot 4.6 | Dialogic 2.0 | GDScript |

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

### 2026-05-13 | Monorepo 初始化 + 2D AVG 遷移
- **決策**：`godot-games` 採 monorepo，每個遊戲放 `games/<name>/`，廢棄 `_Godot_2D_AVG` 獨立 repo
- **遷移內容**：`src/`（23 GDScript 檔）、`assets/`、`addons/`（Dialogic 2.0）、`dialogic/`、`fonts/`、`resources/`、`artifacts/`、`_steam/`、`project.godot`
- **架構保留**：GameManager / SaveManager / AudioManager / CursorManager / InventoryManager + EventBus + Composition-based Components + 3-state Player FSM
- **不需要修改**：所有 `res://` 路徑自動成立，Dialogic UID 由 Godot 重建
- **待辦**：用 Godot 4 編輯器開啟 `games/2d-avg/project.godot` 驗證、歸檔原 `_Godot_2D_AVG` repo
