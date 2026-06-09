class_name PlayerIdleState
extends State

func enter() -> void:
	pass # 日後播放 idle 動畫

func physics_update(_delta: float) -> void:
	if Input.get_axis("move_left", "move_right") != 0.0:
		state_machine.transition_to("walk")
