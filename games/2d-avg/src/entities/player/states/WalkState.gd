class_name PlayerWalkState
extends State

func enter() -> void:
	# 日後在此播放 walk 動畫
	pass

func physics_update(_delta: float) -> void:
	var player := state_machine.get_parent() as Player
	if not player:
		return

	if player.nav_agent.is_navigation_finished():
		state_machine.transition_to("idle")
		return

	var next_pos := player.nav_agent.get_next_path_position()
	var direction := (next_pos - player.global_position).normalized()
	player.velocity = direction * Player.WALK_SPEED
	player.move_and_slide()
