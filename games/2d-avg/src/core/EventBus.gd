extends Node

## Globally accessible Event Bus.
## Use this for decoupled communication between deeply nested nodes or unrelated systems.
##
## Usage (emit):   EventBus.hotspot_clicked.emit("door_01", "examine")
## Usage (listen): EventBus.hotspot_clicked.connect(_on_hotspot_clicked)

# ─── 熱區互動 ───────────────────────────────────────────
## 玩家點擊一個 Hotspot 時發出。
## hotspot_id: Hotspot 的唯一識別名稱（String）
## verb: 動作類型（"examine" | "talk" | "use" | "pick_up"）
signal hotspot_clicked(hotspot_id: String, verb: String)

## Hotspot 的狀態被外部改變時（例如被撿走後隱藏）
signal hotspot_state_changed(hotspot_id: String, enabled: bool)

# ─── 道具欄 ──────────────────────────────────────────────
## 玩家取得道具
signal item_added(item_id: String)

## 玩家使用道具於某個目標（Hotspot 或其他 item）
signal item_used_on(item_id: String, target_id: String)

## 兩個道具合成成功時發出
signal items_combined(item_id_a: String, item_id_b: String, result_item_id: String)

## 道具被消耗/移除
signal item_removed(item_id: String)


# ─── 游標 / Hotspot 懸停 ────────────────────────────────
## 滑鼠進入 Hotspot 時發出（供 HUD 顯示描述文字、CursorManager 換游標）
signal hotspot_hovered(hotspot_id: String, description: String, verb: String)

## 滑鼠離開 Hotspot 時發出
signal hotspot_unhovered(hotspot_id: String)

# ─── 場景 / Room ─────────────────────────────────────────
## 離開目前場景前發出（可用於入場動畫）
signal room_exit_started(from_room: String)

## 新場景載入完成後發出
signal room_entered(room_id: String)

# ─── 對話 ────────────────────────────────────────────────
## Dialogic 對話開始（由 Room/Hotspot 觸發後統一由此廣播）
signal dialogue_started(timeline_name: String)

## Dialogic 對話結束
signal dialogue_ended(timeline_name: String)

# ─── 進度 / 謎題 ─────────────────────────────────────────
## 謎題或旗標變更（供 SaveManager 監聽並持久化）
signal flag_changed(flag_key: String, value: Variant)

## 玩家死亡（若有戰鬥或計時機制）
signal player_died()

# ─── 磁帶日誌 ─────────────────────────────────────────────
## 新增一筆錄音
signal tape_entry_added(entry_id: String)

## 播放一筆錄音（is_anomaly：是否為異常錄音）
signal tape_entry_played(entry_id: String, is_anomaly: bool)

## 磁帶播放器開啟 / 關閉
signal tape_player_opened()
signal tape_player_closed()

# ─── 電台隨身聽 ────────────────────────────────────────────
## 模式切換（RADIO = 0, CASSETTE = 1）
signal radio_mode_changed(mode: int)
