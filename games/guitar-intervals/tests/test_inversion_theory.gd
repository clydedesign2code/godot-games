extends SceneTree
## Fixed-string grips and inversions, including open-string bass crossings.

const Model = preload("res://src/theory/inversion_theory.gd")
const Theory = preload("res://src/theory/fretboard_theory.gd")
const Fingering = preload("res://src/theory/guitar_fingering.gd")
const FORMULAS: Dictionary = {
	0: [0, 4, 7], 1: [0, 3, 7], 2: [0, 3, 6], 3: [0, 4, 8],
	4: [0, 4, 7, 11], 5: [0, 4, 7, 10], 6: [0, 3, 7, 10], 7: [0, 3, 7, 11],
	12: [0, 3, 6, 10], 13: [0, 3, 6, 9],
}
const SIXTH_SUS_FORMULAS: Dictionary = {
	8: [0, 4, 7, 9], 9: [0, 3, 7, 9], 10: [0, 2, 7], 11: [0, 5, 7],
}

var checks := 0
var failures := 0


func _initialize() -> void:
	_verify_group(false)
	_verify_group(true)
	_verify_interval_labels()
	_verify_all_spans(FORMULAS, [1822, 4751])
	_verify_all_spans(SIXTH_SUS_FORMULAS, [992, 2024])
	_verify_degree_names()
	_verify_examples(0, [[8, 7, 5], [12, 10, 10], [3, 3, 2]])
	_verify_examples(5, [[8, 10, 8, 9], [12, 13, 10, 12], [3, 3, 2, 3], [6, 7, 5, 5]])
	_verify_examples(0, [[5, 5, 3], [9, 8, 8], [0, 1, 0]], true)
	_verify_examples(5, [[10, 12, 11, 12], [2, 3, 1, 3], [5, 5, 5, 6], [8, 9, 8, 8]], true)
	_check(Model.note_names(13, 0) == ["C", "E♭", "G♭", "B♭♭"], "diminished seventh spelling")
	_check(Model.note_names(12, 1) == ["C♯", "E", "G", "B"], "half-diminished spelling")
	var crossed: Array[Vector2i] = [Vector2i(5, 8), Vector2i(4, 0), Vector2i(3, 4), Vector2i(2, 8)]
	_check(crossed in Model.voicings(13, 0, 3), "open fifth string sounds the diminished seventh in the bass")
	_check(crossed not in Model.voicings(13, 0, 0), "sixth-string root above an open bass is an inversion")
	var high_e_bass: Array[Vector2i] = [Vector2i(2, 12), Vector2i(1, 13), Vector2i(0, 0)]
	_check(high_e_bass in Model.voicings(0, 0, 1, true), "the open first string is the bass of C/E")
	_check(high_e_bass not in Model.voicings(0, 0, 2, true), "the third-string G sounds above E4")
	_check(Model.string_rows(8, true).is_empty(), "unsupported chord has no fixed string group")
	for invalid: Array in [[8, 0, 0], [0, -1, 0], [0, 12, 0], [0, 0, 3], [5, 0, 4], [0, 0, -1]]:
		_check(Model.voicings(invalid[0], invalid[1], invalid[2]).is_empty(), "reject invalid exercise %s" % [invalid])
	print("Inversion theory: %s checks, %s failures" % [checks, failures])
	quit(1 if failures else 0)


func _verify_degree_names() -> void:
	for id in Model.SIXTH_IDS:
		_check(Model.degree_name(id, 3) == "六度", "the added sixth has the correct bass role")
		_check(Model.interval_label(id, 0, 57) == "6", "both major and minor sixth chords use a major sixth")
	for id in Model.SEVENTH_IDS:
		_check(Model.degree_name(id, 3) == "七度", "seventh chords keep the seventh bass role")
	_check(Model.degree_name(10, 1) == "二度" and Model.degree_name(11, 1) == "四度", "suspended notes replace the third")
	_check(Model.note_names(10, 1) == ["C♯", "D♯", "G♯"] and Model.note_names(11, 1) == ["C♯", "F♯", "G♯"], "suspended tones spelled by letter distance")
	_check(Model.note_names(9, 0) == ["C", "E♭", "G", "A"], "Cm6 retains the major sixth")
	_check(Model.degree_name(99, 1).is_empty() and Model.degree_name(10, -1).is_empty() and Model.degree_name(11, 3).is_empty(), "invalid degree has no role")


func _verify_all_spans(formulas: Dictionary, expected_counts: Array) -> void:
	for count in [3, 4]:
		var total := 0
		for first_string in range(1, 8 - count):
			var rows := range(first_string + count - 2, first_string - 2, -1)
			_check(Model.span_rows(count, first_string) == rows, "contiguous strings in bass-to-treble order")
			for id: int in formulas:
				var formula: Array = formulas[id]
				var required: Array = range(formula.size())
				if count == 3 and formula.size() == 4:
					required = [0, 1, 3] if formula[2] == 7 else []
				_check(Model.supports_count(id, count) == not required.is_empty(), "only a perfect fifth can be omitted")
				_check(Model.available_inversions(id, count) == required, "inversions retain their full chord indices")
				for root_pc in range(12):
					var usable := required.duplicate()
					# On D–G–B, seven keys have no mMaj7 shell with the major seventh
					# below both the root and minor third inside the hand-span limit.
					if id == 7 and count == 3 and first_string == 2 and root_pc in [1, 2, 5, 6, 7, 9, 10]:
						usable.erase(3)
					_check(Model.playable_inversions(id, root_pc, count, first_string) == usable, "only physically available inversions selectable")
					for inversion in range(formula.size()):
						var shapes := Model.span_voicings(id, root_pc, inversion, count, first_string)
						total += shapes.size()
						_check(shapes.is_empty() == (inversion not in usable), "only reachable questions have shapes")
						for shape in shapes:
							_verify_span_shape(shape, rows, root_pc, formula, required, inversion)
		# Independent exhaustive fret-tuple enumeration over all keys and groups.
		_check(total == expected_counts[count - 3], "total number of valid grips on all contiguous groups")
	_check(Model.span_rows(2, 1).is_empty() and Model.span_rows(4, 4).is_empty(), "invalid string groups")
	_check(Model.span_voicings(0, 0, 0, 3, 0).is_empty(), "string numbers are one-based")
	_check(Model.span_voicings(0, 12, 0, 3, 1).is_empty(), "invalid root")
	_check(Model.span_voicings(6, 0, 2, 3, 1).is_empty(), "no second inversion with an omitted fifth")
	_check(Model.span_voicings(0, 0, 0, 4, 2)[0] == [Vector2i(4, 3), Vector2i(3, 2), Vector2i(2, 0), Vector2i(1, 1)], "four-string C doubles C at the octave")
	_check(Model.span_voicings(6, 7, 1, 4, 1)[0] == [Vector2i(3, 8), Vector2i(2, 10), Vector2i(1, 8), Vector2i(0, 10)], "high Gm7/B-flat drop-2 grip")


func _verify_span_shape(shape: Array, rows: Array, root_pc: int, formula: Array, required: Array, inversion: int) -> void:
	_check(shape.size() == rows.size(), "one sound per required string")
	var bass_midi := 128
	var seen := {}
	var min_fretted := 15
	var max_fretted := 0
	for i in range(shape.size()):
		var pos: Vector2i = shape[i]
		_check(pos.x == rows[i] and Theory.is_position_valid(pos), "string and fret in range")
		var pitch := Theory.midi(pos)
		bass_midi = mini(bass_midi, pitch)
		seen[formula.find(posmod(pitch - root_pc, 12))] = true
		if pos.y > 0:
			min_fretted = mini(min_fretted, pos.y)
			max_fretted = maxi(max_fretted, pos.y)
	var degrees := seen.keys()
	degrees.sort()
	_check(degrees == required, "composition includes precisely the requested degrees")
	_check(posmod(bass_midi - root_pc, 12) == formula[inversion], "actual MIDI bass decides inversion")
	_check(max_fretted - min_fretted <= 4, "fretted notes are within hand span")
	var fingers := Fingering.fingers(shape)
	_check(fingers.size() == shape.size() and fingers.min() >= 0 and fingers.max() <= 4, "existing fingering model covers each result")


func _verify_interval_labels() -> void:
	var chromatic := ["R", "m2", "2", "m3", "3", "4", "♭5", "5", "m6", "6", "m7", "maj7"]
	for semitones in range(-24, 25):
		_check(Theory.interval_label(semitones) == chromatic[posmod(semitones, 12)], "unspelled audition labels are octave equivalent")
	_check(Theory.interval_label(6, 3) == "♯4" and Theory.interval_label(6, 4) == "♭5", "tritone has a spelling")
	_check(Theory.chord_interval_label(Theory.CHORDS[8], 9) == "6", "C6 has a major sixth")
	for root_pc in range(12):
		_check(Model.interval_label(13, root_pc, root_pc + 57) == "dim7", "fully diminished seventh keeps its diatonic role")
		_check(Model.interval_label(3, root_pc, root_pc + 56) == "♯5", "augmented triad has a raised fifth")
		_check(Model.interval_label(1, root_pc, root_pc + 56) == "m6", "non-chord audition uses chromatic fallback")
		_check(Model.interval_label(4, root_pc, root_pc + 59) == "maj7", "major seventh keeps its diatonic role")
	var low_e := Vector2i(5, 0)
	var high_e := Vector2i(0, 0)
	_check(Theory.pitch_class_name(low_e) == "E" and Theory.pitch_class_name(high_e) == "E", "octaves share a display name")
	_check(Theory.note_name(low_e) == "E2" and Theory.note_name(high_e) == "E4", "exact pitch names remain available")
	_check(Theory.midi(high_e) - Theory.midi(low_e) == 24, "sounding string registers remain distinct")


func _verify_group(highest_group: bool) -> void:
	for id: int in FORMULAS:
		var tones: Array = FORMULAS[id]
		var rows: Array = [2, 1, 0] if tones.size() == 3 else [3, 2, 1, 0]
		if not highest_group:
			rows = [5, 4, 3] if tones.size() == 3 else [5, 4, 3, 2]
		_check(Model.string_rows(id, highest_group) == rows, "supported strings in bass-to-treble order")
		for root_pc in range(12):
			for inversion in range(tones.size()):
				var shapes := Model.voicings(id, root_pc, inversion, highest_group)
				_check(not shapes.is_empty(), "missing grip %s/%s/%s on %s" % [id, root_pc, inversion, rows])
				if not shapes.is_empty():
					_verify_example_register(shapes[0], root_pc, tones, inversion)
				for shape in shapes:
					_verify_shape(shape, root_pc, tones, inversion, rows)


func _verify_shape(shape: Array, root_pc: int, tones: Array, inversion: int, rows: Array) -> void:
	var played: Array[int] = []
	var pitches: Array[int] = []
	var fretted: Array[int] = []
	_check(shape.size() == tones.size(), "complete chord")
	for string_index in range(shape.size()):
		var pos: Vector2i = shape[string_index]
		_check(pos.x == rows[string_index] and Theory.is_position_valid(pos), "specified strings and frets")
		var pitch := Theory.midi(pos)
		played.append(posmod(pitch - root_pc, 12))
		pitches.append(pitch)
		if pos.y > 0:
			fretted.append(pos.y)
	played.sort()
	_check(played == tones, "all required pitch classes once")
	_check(posmod(int(pitches.min()) - root_pc, 12) == tones[inversion], "actual bass matches inversion")
	_check(fretted.is_empty() or fretted.max() - fretted.min() <= 4, "non-open fret span")


func _verify_examples(chord_id: int, frets: Array, highest_group: bool = false) -> void:
	for inversion in range(frets.size()):
		var shapes := Model.voicings(chord_id, 0, inversion, highest_group)
		if shapes.is_empty():
			continue
		var example: Array[int] = []
		for pos: Vector2i in shapes[0]:
			example.append(pos.y)
		_check(example == frets[inversion], "model example expected %s, got %s" % [frets[inversion], example])


func _verify_example_register(shape: Array, root_pc: int, tones: Array, inversion: int) -> void:
	var order: Array = [0, 1, 2] if tones.size() == 3 else [0, 2, 3, 1]
	var reference: int = Theory.midi(shape.front())
	for i in range(order.size()):
		var degree: int = (inversion + int(order[i])) % tones.size()
		reference += posmod(root_pc + int(tones[degree]) - reference, 12)
		_check(Theory.midi(shape[i]) == reference, "example in close triad / drop-2 seventh register")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
