extends Node2D

## 第一章開場房間：主角的房間。
## 場景結構（RoomStart.tscn）：
##
##   RoomStart (Node2D)
##   ├── Background (Sprite2D)            ← 背景圖
##   ├── Floor (StaticBody2D)             ← 地板碰撞
##   │   └── CollisionShape2D            (寬=場景寬度，高=16px，Y=地板位置)
##   ├── WallLeft (StaticBody2D)          ← 左邊界
##   │   └── CollisionShape2D
##   ├── WallRight (StaticBody2D)         ← 右邊界
##   │   └── CollisionShape2D
##   ├── Camera2D                         ← 跟隨玩家，limit 設定場景邊界
##   ├── Player (Player.tscn instance)    ← 玩家
##   └── RadioCassettePlayer.tscn        ← 電台隨身聽

func _ready() -> void:
	EventBus.room_entered.emit("room_start")
	GameManager.current_state = GameManager.GameState.PLAYING
