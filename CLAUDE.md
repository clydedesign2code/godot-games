# CLAUDE.md — godot-games

> Claude Code 專屬入口。跨 IDE 通用規則請見 `AGENTS.md`。

---

## Bootstrap Protocol

每次對話開始時，靜默執行：

1. 讀取 `.agents/rules/core_directives.md`（最高行為準則）
2. 讀取 `AGENTS.md`（本 monorepo 規則）
3. 依任務類型按需載入 `.agents/skills/<skill_name>/SKILL.md`

**Single Source of Truth：** `.agents/` submodule > `AGENTS.md` > 本檔

---

## 核心行為準則

- 修改任何檔案前，先讀取確認現有結構
- 發現既有架構時主動詢問：「要擴充還是另建？」
- 絕對禁止未確認直接覆蓋
- 新確認的規則/決策 → 寫入 `AGENTS.md` 對應章節，靜默回報一句話

---

## 遊戲目錄索引

| 遊戲 | 路徑 | 技術棧 | 狀態 |
|------|------|--------|------|
| 2D AVG（像素解謎冒險）| `games/2d-avg/` | Godot 4 + Dialogic 2.0 | 架構完成，待美術 |

---

## 推薦技能組合

| 任務 | Skill |
|------|-------|
| Godot 遊戲架構 / GDScript | `godot_expert` |
| 自我進化 / 復盤 | `self_improving_agent` |
