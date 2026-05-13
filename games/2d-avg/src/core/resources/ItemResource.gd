class_name ItemResource
extends Resource

## AVG 道具資源類。
## 定義道具的資料結構，可用於建立 .tres 檔案。

## 道具的唯一 ID（用於代碼識別與存檔）
@export var item_id: String = ""

## 道具名稱（顯示於 UI）
@export var item_name: String = ""

## 道具描述（滑鼠懸標時顯示）
@export_multiline var description: String = ""

## 道具圖示（顯示於道具欄）
@export var icon: Texture2D

## 是否為消耗品（使用後消失）
@export var is_consumable: bool = false
