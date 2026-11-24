extends RefCounted
## Pure musical model. Rows follow the player's view: high e on top, low E below.
## Answers compare pitch classes relative to a root, with octave equivalence.

const OPEN_MIDI: Array[int] = [64, 59, 55, 50, 45, 40]
const STRING_NAMES: Array[String] = ["e", "B", "G", "D", "A", "E"]
const LAST_FRET: int = 15
const LOCAL_RADIUS: int = 4
const NOTE_NAMES: Array[String] = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
const LETTERS: Array[String] = ["C", "D", "E", "F", "G", "A", "B"]
const NATURAL_PC: Array[int] = [0, 2, 4, 5, 7, 9, 11]
const ROOT_LETTERS: Array[int] = [0, 0, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6]
const INTERVALS: Array[Dictionary] = [
	{"name": "同音級 / 八度", "symbol": "1/8", "semitones": 0, "letter_steps": 0},
	{"name": "小二度", "symbol": "♭2", "semitones": 1, "letter_steps": 1},
	{"name": "大二度", "symbol": "2", "semitones": 2, "letter_steps": 1},
	{"name": "小三度", "symbol": "♭3", "semitones": 3, "letter_steps": 2},
	{"name": "大三度", "symbol": "3", "semitones": 4, "letter_steps": 2},
	{"name": "完全四度", "symbol": "4", "semitones": 5, "letter_steps": 3},
	{"name": "增四 / 減五度", "symbol": "♭5", "semitones": 6, "letter_steps": 4},
	{"name": "完全五度", "symbol": "5", "semitones": 7, "letter_steps": 4},
	{"name": "小六度", "symbol": "♭6", "semitones": 8, "letter_steps": 5},
	{"name": "大六度", "symbol": "6", "semitones": 9, "letter_steps": 5},
	{"name": "小七度", "symbol": "♭7", "semitones": 10, "letter_steps": 6},
	{"name": "大七度", "symbol": "7", "semitones": 11, "letter_steps": 6},
]
# Full chord definitions include the root; tones/steps/symbols describe only the
# two answers in this exercise's three-note voicing. The root is always given.
const CHORDS: Array[Dictionary] = [
	{"name": "大三和弦", "suffix": "", "formula": "1 · 3 · 5", "full_tones": [0, 4, 7], "full_steps": [0, 2, 4], "voicing_formula": "1 · 3 · 5", "tones": [4, 7], "steps": [2, 4], "symbols": ["3", "5"], "group": "basic_sus", "omit_fifth": false},
	{"name": "小三和弦", "suffix": "m", "formula": "1 · ♭3 · 5", "full_tones": [0, 3, 7], "full_steps": [0, 2, 4], "voicing_formula": "1 · ♭3 · 5", "tones": [3, 7], "steps": [2, 4], "symbols": ["♭3", "5"], "group": "basic_sus", "omit_fifth": false},
	{"name": "減三和弦", "suffix": "dim", "formula": "1 · ♭3 · ♭5", "full_tones": [0, 3, 6], "full_steps": [0, 2, 4], "voicing_formula": "1 · ♭3 · ♭5", "tones": [3, 6], "steps": [2, 4], "symbols": ["♭3", "♭5"], "group": "basic_sus", "omit_fifth": false},
	{"name": "增三和弦", "suffix": "aug", "formula": "1 · 3 · ♯5", "full_tones": [0, 4, 8], "full_steps": [0, 2, 4], "voicing_formula": "1 · 3 · ♯5", "tones": [4, 8], "steps": [2, 4], "symbols": ["3", "♯5"], "group": "basic_sus", "omit_fifth": false},
	{"name": "大七和弦", "suffix": "maj7", "formula": "1 · 3 · 5 · 7", "full_tones": [0, 4, 7, 11], "full_steps": [0, 2, 4, 6], "voicing_formula": "1 · 3 · 7", "tones": [4, 11], "steps": [2, 6], "symbols": ["3", "7"], "group": "seventh_sixth", "omit_fifth": true},
	{"name": "屬七和弦", "suffix": "7", "formula": "1 · 3 · 5 · ♭7", "full_tones": [0, 4, 7, 10], "full_steps": [0, 2, 4, 6], "voicing_formula": "1 · 3 · ♭7", "tones": [4, 10], "steps": [2, 6], "symbols": ["3", "♭7"], "group": "seventh_sixth", "omit_fifth": true},
	{"name": "小七和弦", "suffix": "m7", "formula": "1 · ♭3 · 5 · ♭7", "full_tones": [0, 3, 7, 10], "full_steps": [0, 2, 4, 6], "voicing_formula": "1 · ♭3 · ♭7", "tones": [3, 10], "steps": [2, 6], "symbols": ["♭3", "♭7"], "group": "seventh_sixth", "omit_fifth": true},
	{"name": "小大七和弦", "suffix": "mMaj7", "formula": "1 · ♭3 · 5 · 7", "full_tones": [0, 3, 7, 11], "full_steps": [0, 2, 4, 6], "voicing_formula": "1 · ♭3 · 7", "tones": [3, 11], "steps": [2, 6], "symbols": ["♭3", "7"], "group": "seventh_sixth", "omit_fifth": true},
	{"name": "大六和弦", "suffix": "6", "formula": "1 · 3 · 5 · 6", "full_tones": [0, 4, 7, 9], "full_steps": [0, 2, 4, 5], "voicing_formula": "1 · 3 · 6", "tones": [4, 9], "steps": [2, 5], "symbols": ["3", "6"], "group": "seventh_sixth", "omit_fifth": true},
	{"name": "小六和弦", "suffix": "m6", "formula": "1 · ♭3 · 5 · 6", "full_tones": [0, 3, 7, 9], "full_steps": [0, 2, 4, 5], "voicing_formula": "1 · ♭3 · 6", "tones": [3, 9], "steps": [2, 5], "symbols": ["♭3", "6"], "group": "seventh_sixth", "omit_fifth": true},
	{"name": "掛二和弦", "suffix": "sus2", "formula": "1 · 2 · 5", "full_tones": [0, 2, 7], "full_steps": [0, 1, 4], "voicing_formula": "1 · 2 · 5", "tones": [2, 7], "steps": [1, 4], "symbols": ["2", "5"], "group": "basic_sus", "omit_fifth": false},
	{"name": "掛四和弦", "suffix": "sus4", "formula": "1 · 4 · 5", "full_tones": [0, 5, 7], "full_steps": [0, 3, 4], "voicing_formula": "1 · 4 · 5", "tones": [5, 7], "steps": [3, 4], "symbols": ["4", "5"], "group": "basic_sus", "omit_fifth": false},
]


static func is_position_valid(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < 6 and position.y >= 0 and position.y <= LAST_FRET


static func midi(position: Vector2i) -> int:
	assert(is_position_valid(position), "Position outside the fretboard")
	return OPEN_MIDI[position.x] + position.y


static func relative_pc(root: Vector2i, position: Vector2i) -> int:
	return posmod(midi(position) - midi(root), 12)


static func note_name(position: Vector2i) -> String:
	var value: int = midi(position)
	return "%s%d" % [NOTE_NAMES[value % 12], value / 12 - 1]


static func pitch_class_name(position: Vector2i) -> String:
	return NOTE_NAMES[midi(position) % 12]


static func root_name(root: Vector2i) -> String:
	return pitch_class_name(root)


## The optional diatonic spelling distinguishes e.g. an augmented fifth from a
## minor sixth. Unspelled auditioned notes use the interval lookup's convention.
static func interval_label(semitones: int, letter_steps: int = -1) -> String:
	var pc := posmod(semitones, 12)
	var step := posmod(letter_steps, 7) if letter_steps >= 0 else int(INTERVALS[pc].letter_steps)
	var degree := str(step + 1)
	var change := posmod(pc - NATURAL_PC[step] + 6, 12) - 6
	if change == 0:
		if step == 0:
			return "R"
		return "maj7" if step == 6 else degree
	if step in [1, 2, 5, 6]:
		if change == -1:
			return "m" + degree
		if change == -2:
			return "dim" + degree
	return ("♯".repeat(change) if change > 0 else "♭".repeat(-change)) + degree


static func chord_interval_label(chord: Dictionary, semitones: int) -> String:
	var tones: Array = chord.get("full_tones", [])
	var index := tones.find(posmod(semitones, 12))
	return interval_label(semitones, chord.full_steps[index] if index >= 0 else -1)


static func spelled_note(root: Vector2i, semitones: int, letter_steps: int) -> String:
	var root_pc: int = midi(root) % 12
	var letter_index: int = (ROOT_LETTERS[root_pc] + letter_steps) % 7
	var target_pc: int = posmod(root_pc + semitones, 12)
	var alteration: int = posmod(target_pc - NATURAL_PC[letter_index] + 6, 12) - 6
	var accidental: String = "♯".repeat(alteration) if alteration > 0 else "♭".repeat(-alteration)
	return LETTERS[letter_index] + accidental


static func in_scope(root: Vector2i, position: Vector2i, nearby: bool) -> bool:
	return is_position_valid(position) and (not nearby or absi(position.y - root.y) <= LOCAL_RADIUS)


static func candidates(root: Vector2i, semitones: int, nearby: bool = true) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for string_index in range(6):
		for fret in range(LAST_FRET + 1):
			var position := Vector2i(string_index, fret)
			if position != root and in_scope(root, position, nearby) and relative_pc(root, position) == posmod(semitones, 12):
				result.append(position)
	return result


static func movement(root: Vector2i, position: Vector2i) -> String:
	var strings: int = root.x - position.x
	var frets: int = position.y - root.y
	var string_text: String = "同弦" if strings == 0 else "%s %d 弦" % ["往細弦" if strings > 0 else "往粗弦", absi(strings)]
	var fret_text: String = "同品" if frets == 0 else "%s %d 品" % ["往琴橋" if frets > 0 else "往琴頭", absi(frets)]
	var delta: int = midi(position) - midi(root)
	return "%s，%s（實際音高 %+d 半音）" % [string_text, fret_text, delta]


static func chord_note_names(root: Vector2i, chord_index: int, played_only: bool = false) -> Array[String]:
	var chord: Dictionary = CHORDS[chord_index]
	var result: Array[String] = [root_name(root)]
	if played_only:
		for index in range(chord.tones.size()):
			result.append(spelled_note(root, chord.tones[index], chord.steps[index]))
	else:
		for index in range(1, chord.full_tones.size()):
			result.append(spelled_note(root, chord.full_tones[index], chord.full_steps[index]))
	return result


static func chord_voicings(root: Vector2i, chord_index: int, nearby: bool = true) -> Array[Array]:
	## Position candidates on different strings, with a four-fret fretted span.
	## Open strings do not stretch the fretting hand; the fixed root counts in the span.
	var chord: Dictionary = CHORDS[chord_index]
	var result: Array[Array] = []
	for first in candidates(root, chord.tones[0], nearby):
		for other in candidates(root, chord.tones[1], nearby):
			if root.x == first.x or root.x == other.x or first.x == other.x:
				continue
			var fretted: Array[int] = []
			for position: Vector2i in [root, first, other]:
				if position.y > 0:
					fretted.append(position.y)
			if fretted.is_empty() or fretted.max() - fretted.min() <= LOCAL_RADIUS:
				result.append([first, other])
	return result
