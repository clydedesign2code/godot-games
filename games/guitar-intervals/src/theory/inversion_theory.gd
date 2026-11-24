extends RefCounted
## Chord grips, spelled degrees and actual bass on consecutive guitar strings.

const Theory = preload("res://src/theory/fretboard_theory.gd")
const Fingering = preload("res://src/theory/guitar_fingering.gd")
const TRIAD_IDS: Array[int] = [0, 1, 2, 3]
const SEVENTH_IDS: Array[int] = [4, 5, 6, 7, 12, 13]
const SIXTH_IDS: Array[int] = [8, 9]
const SUS_IDS: Array[int] = [10, 11]
const DEGREE_NAMES := ["根音", "二度", "三度", "四度", "五度", "六度", "七度"]
const EXTRA_SEVENTHS: Dictionary = {
	12: {"name": "半減七和弦", "suffix": "m7♭5", "formula": "1 · ♭3 · ♭5 · ♭7", "full_tones": [0, 3, 6, 10], "full_steps": [0, 2, 4, 6]},
	13: {"name": "減七和弦", "suffix": "dim7", "formula": "1 · ♭3 · ♭5 · ♭♭7", "full_tones": [0, 3, 6, 9], "full_steps": [0, 2, 4, 6]},
}


static func definition(chord_index: int) -> Dictionary:
	if EXTRA_SEVENTHS.has(chord_index):
		return EXTRA_SEVENTHS[chord_index]
	if chord_index in TRIAD_IDS or chord_index in SEVENTH_IDS or chord_index in SIXTH_IDS or chord_index in SUS_IDS:
		return Theory.CHORDS[chord_index]
	return {}


static func degree_name(chord_index: int, index: int) -> String:
	var steps: Array = definition(chord_index).get("full_steps", [])
	return DEGREE_NAMES[steps[index]] if index >= 0 and index < steps.size() else ""


static func note_names(chord_index: int, root_pc: int) -> Array[String]:
	var chord := definition(chord_index)
	var names: Array[String] = []
	if chord.is_empty() or root_pc < 0 or root_pc >= 12:
		return names
	var root := Vector2i(5, posmod(root_pc - Theory.OPEN_MIDI[5], 12))
	for index in range(chord.full_tones.size()):
		names.append(Theory.spelled_note(root, chord.full_tones[index], chord.full_steps[index]))
	return names


static func interval_label(chord_index: int, root_pc: int, target_midi: int) -> String:
	return Theory.chord_interval_label(definition(chord_index), target_midi - root_pc)


## Backward-compatible shortcut for the original two exercise families.
static func string_rows(chord_index: int, highest_group: bool = false) -> Array[int]:
	if chord_index not in TRIAD_IDS and chord_index not in SEVENTH_IDS:
		return []
	var count: int = definition(chord_index).get("full_tones", []).size()
	return span_rows(count, 1 if highest_group else 7 - count)


static func span_rows(count: int, first_string: int) -> Array[int]:
	var rows: Array[int] = []
	if count in [3, 4, 5] and first_string >= 1 and first_string + count - 1 <= 6:
		rows.assign(range(first_string + count - 2, first_string - 2, -1))
	return rows


## Degree indices always refer to the full chord, even when its fifth is omitted.
static func available_inversions(chord_index: int, count: int) -> Array[int]:
	var degrees: Array[int] = []
	var chord := definition(chord_index)
	if chord.is_empty() or count not in [3, 4, 5]:
		return degrees
	if count == 3 and chord.full_tones.size() == 4:
		if chord.full_tones[2] == 7:
			degrees.assign([0, 1, 3])
	else:
		degrees.assign(range(chord.full_tones.size()))
	return degrees


static func supports_count(chord_index: int, count: int) -> bool:
	return not available_inversions(chord_index, count).is_empty()


static func playable_inversions(chord_index: int, root_pc: int, count: int, first_string: int) -> Array[int]:
	var playable: Array[int] = []
	for inversion in available_inversions(chord_index, count):
		if not _find_voicings(chord_index, root_pc, inversion, count, first_string, true).is_empty():
			playable.append(inversion)
	return playable


static func voicings(chord_index: int, root_pc: int, inversion: int, highest_group: bool = false) -> Array[Array]:
	if chord_index not in TRIAD_IDS and chord_index not in SEVENTH_IDS:
		return []
	var count: int = definition(chord_index).get("full_tones", []).size()
	return span_voicings(chord_index, root_pc, inversion, count, 1 if highest_group else 7 - count)


static func span_voicings(chord_index: int, root_pc: int, inversion: int, count: int, first_string: int) -> Array[Array]:
	return _find_voicings(chord_index, root_pc, inversion, count, first_string, false)


static func _find_voicings(chord_index: int, root_pc: int, inversion: int, count: int, first_string: int, first_only: bool) -> Array[Array]:
	var shapes: Array[Array] = []
	var rows := span_rows(count, first_string)
	var degrees := available_inversions(chord_index, count)
	var bass := degrees.find(inversion)
	if rows.is_empty() or root_pc < 0 or root_pc >= 12 or bass < 0:
		return shapes
	var full_tones: Array = definition(chord_index).full_tones
	var tones: Array[int] = []
	for degree in degrees:
		tones.append(full_tones[degree])
	var partial: Array[Vector2i] = []
	_collect(tones, root_pc, bass, rows, 0, Vector2i(Theory.LAST_FRET, 0), partial, shapes, first_only)
	if not first_only and shapes.size() > 1:
		var ranks := {}
		for shape in shapes:
			ranks[shape] = _example_rank(shape, tones, root_pc, bass)
		shapes.sort_custom(func(a: Array, b: Array) -> bool: return ranks[a] < ranks[b])
	return shapes


static func _collect(tones: Array, root_pc: int, inversion: int, rows: Array[int], used: int, frets: Vector2i, partial: Array[Vector2i], shapes: Array[Array], first_only: bool) -> void:
	if partial.size() == rows.size():
		if used != (1 << tones.size()) - 1:
			return
		var lowest_midi: int = Theory.midi(partial[0])
		for position in partial:
			lowest_midi = mini(lowest_midi, Theory.midi(position))
		if posmod(lowest_midi - root_pc, 12) != tones[inversion]:
			return
		if rows.size() < 5 or not Fingering.fingers(partial).is_empty():
			shapes.append(partial.duplicate())
		return
	var row := rows[partial.size()]
	for degree in range(tones.size()):
		var bit := 1 << degree
		if used & bit and rows.size() == tones.size():
			continue
		var first_fret := posmod(root_pc + int(tones[degree]) - Theory.OPEN_MIDI[row], 12)
		for fret in range(first_fret, Theory.LAST_FRET + 1, 12):
			var next_frets := frets
			if fret > 0:
				next_frets = Vector2i(mini(frets.x, fret), maxi(frets.y, fret))
				if next_frets.y - next_frets.x > Theory.LOCAL_RADIUS:
					continue
			partial.append(Vector2i(row, fret))
			_collect(tones, root_pc, inversion, rows, used | bit, next_frets, partial, shapes, first_only)
			partial.pop_back()
			if first_only and not shapes.is_empty():
				return


## Prefer close-position triads and drop-2 sevenths for the example and hint.
## Other playable spreads and open-string voicings remain valid answers.
static func _example_rank(shape: Array, tones: Array, root_pc: int, inversion: int) -> int:
	var first: int = Theory.midi(shape[0])
	var previous := first - 1
	var ascending := true
	var highest_fret := 0
	var lowest_fret: int = Theory.LAST_FRET
	for position: Vector2i in shape:
		var pitch: int = Theory.midi(position)
		ascending = ascending and pitch > previous
		previous = pitch
		highest_fret = maxi(highest_fret, position.y)
		lowest_fret = mini(lowest_fret, position.y)
	var conventional := ascending and previous - first < 12
	if shape.size() == 5:
		# Movable E/A-style shapes double the fifth at the octave, e.g.
		# Cm7 on 6–2 as C–G–B♭–E♭–G. Rotate these degrees for inversions.
		var order := [0, 2, 3, 1, 2] if tones.size() == 4 else [0, 2, 0, 1, 2]
		var top_degree: int = tones[(inversion + 2) % tones.size()]
		conventional = ascending and previous - first == 12 + posmod(top_degree - int(tones[inversion]), 12)
		for i in range(shape.size()):
			if posmod(Theory.midi(shape[i]) - root_pc, 12) != tones[(inversion + int(order[i])) % tones.size()]:
				conventional = false
				break
	elif shape.size() == 4 and tones.size() == 3:
		# A close four-string triad doubles the bass one octave above.
		conventional = ascending and previous - first == 12
	elif shape.size() == 4:
		var drop_two_order: Array[int] = [0, 2, 3, 1]
		var top_interval := posmod(int(tones[(inversion + 1) % 4]) - int(tones[inversion]), 12)
		conventional = ascending and previous - first == 12 + top_interval
		for string_index in range(shape.size()):
			var expected: int = tones[(inversion + drop_two_order[string_index]) % 4]
			if posmod(Theory.midi(shape[string_index]) - root_pc, 12) != expected:
				conventional = false
				break
	var category := 0 if conventional else (1 if ascending else 2)
	var fret_count: int = Theory.LAST_FRET + 1
	return category * fret_count * fret_count + (highest_fret - lowest_fret) * fret_count + highest_fret
