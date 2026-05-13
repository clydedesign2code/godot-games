extends Node

## Handles pooling and playing of sound effects and music seamlessly.

func play_sfx(stream: AudioStream, position: Vector2 = Vector2.ZERO) -> void:
	# Add logic here to spawn a temporary AudioStreamPlayer2D or AudioStreamPlayer
	# pool to play the sound and remove/free when finished.
	pass

func play_music(stream: AudioStream, crossfade_time: float = 1.0) -> void:
	# Handle background music with fading
	pass
