class_name PlayerInteractState
extends State

func enter() -> void:
	# 目前無互動動畫，直接回到 idle
	# 日後在此播放互動動畫，動畫結束後再 transition_to("idle")
	state_machine.call_deferred("transition_to", "idle")
