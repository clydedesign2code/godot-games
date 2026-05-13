class_name ItemCombination
extends Resource

## AVG 道具合成配方資源。
## 定義「道具 A + 道具 B = 結果 C」的結合規則。

## 道具 A 的 ID
@export var item_id_a: String = ""

## 道具 B 的 ID
@export var item_id_b: String = ""

## 合成後的產出道具資源
@export var result_item: ItemResource

## 合成此配方是否需要特定的遊戲旗標進度
@export var required_flag: String = ""
