extends SceneTree

const Fingering = preload("res://src/theory/guitar_fingering.gd")
const Inversions = preload("res://src/theory/inversion_theory.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	var questions := 0
	var grips := 0
	for chord_id: int in Inversions.TRIAD_IDS + Inversions.SEVENTH_IDS:
		for root_pc in range(12):
			for inversion in range(Inversions.definition(chord_id).full_tones.size()):
				for high_strings in [false, true]:
					var shapes := Inversions.voicings(chord_id, root_pc, inversion, high_strings)
					_check(not shapes.is_empty(), "question has at least one grip")
					for shape in shapes:
						_verify_fingers(shape, Fingering.fingers(shape))
					grips += shapes.size()
					questions += 1
	_check(questions == 864, "all roots, qualities and inversions covered on both string sets")
	# First suggested grips for C, C/E, C/G and the four inversions of C7.
	_check_examples(0, [[4, 3, 1], [3, 1, 1], [2, 2, 1]])
	_check_examples(5, [[1, 3, 1, 2], [2, 4, 1, 3], [2, 2, 1, 3], [2, 3, 1, 1]])
	_check_examples(0, [[3, 3, 1], [2, 1, 1], [0, 1, 0]], true)
	_check_examples(5, [[1, 3, 2, 4], [2, 3, 1, 4], [1, 1, 1, 2], [1, 2, 1, 1]], true)
	_check(_for_frets([5, 7, 5, 5]) == [1, 3, 1, 1], "index barre underneath a higher fret")
	_check(_for_frets([5, 0, 5]) == [1, 0, 2], "open middle string requires split fingers")
	_check(_for_frets([5, 4, 5]) == [2, 1, 3], "lower middle fret requires split fingers")
	_check(_for_frets([0, 1, 5, 5]) == [0, 1, 4, 4], "open bass and stretched little-finger barre")
	_check(_for_frets([0, 0, 0]) == [0, 0, 0], "all open strings")
	print("Guitar fingering: %d questions, %d grips, %d checks, %d failures" % [questions, grips, checks, failures])
	quit(1 if failures else 0)


func _verify_fingers(shape: Array, fingers: Array[int]) -> void:
	_check(fingers.size() == shape.size(), "one digit per string")
	if fingers.size() != shape.size():
		return
	for i in range(shape.size()):
		var fret: int = shape[i].y
		if fret == 0:
			_check(fingers[i] == 0, "open strings use no finger")
			continue
		_check(fingers[i] >= 1 and fingers[i] <= 4, "fretted strings use a left-hand finger")
		for j in range(i + 1, shape.size()):
			if fingers[j] == fingers[i]:
				_check(shape[j].y == fret, "both ends of a barre occupy the same fret")
				for k in range(i + 1, j):
					_check(shape[k].y >= fret, "barre clears all intervening notes")
			elif shape[j].y > 0 and shape[j].y != fret:
				_check((fingers[j] > fingers[i]) == (shape[j].y > fret), "fingers ascend with frets")


func _check_examples(chord_id: int, expected: Array, high_strings: bool = false) -> void:
	for inversion in range(expected.size()):
		var shape: Array = Inversions.voicings(chord_id, 0, inversion, high_strings)[0]
		var actual := Fingering.fingers(shape)
		_check(actual == expected[inversion], "C chord %s inversion %s, high strings %s: expected %s, got %s" % [chord_id, inversion, high_strings, expected[inversion], actual])


func _for_frets(frets: Array) -> Array[int]:
	var shape: Array[Vector2i] = []
	for i in range(frets.size()):
		shape.append(Vector2i(5 - i, frets[i]))
	return Fingering.fingers(shape)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
