class_name PlayerWalkState
extends State

func enter() -> void:
	pass # 日後播放 walk 動畫

func physics_update(_delta: float) -> void:
	var player := state_machine.get_parent() as Player
	if not player:
		return

	var dir := Input.get_axis("move_left", "move_right")

	if dir == 0.0:
		state_machine.transition_to("idle")
		return

	player.velocity.x = dir * Player.WALK_SPEED
	player.animated_sprite.flip_h = dir < 0.0
	player.move_and_slide()
