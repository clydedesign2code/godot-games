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
const TRIADS: Array[Dictionary] = [
	{"name": "大三和弦", "suffix": "", "formula": "1 · 3 · 5", "tones": [4, 7], "steps": [2, 4], "symbols": ["3", "5"]},
	{"name": "小三和弦", "suffix": "m", "formula": "1 · ♭3 · 5", "tones": [3, 7], "steps": [2, 4], "symbols": ["♭3", "5"]},
	{"name": "減三和弦", "suffix": "dim", "formula": "1 · ♭3 · ♭5", "tones": [3, 6], "steps": [2, 4], "symbols": ["♭3", "♭5"]},
	{"name": "增三和弦", "suffix": "aug", "formula": "1 · 3 · ♯5", "tones": [4, 8], "steps": [2, 4], "symbols": ["3", "♯5"]},
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


static func root_name(root: Vector2i) -> String:
	return NOTE_NAMES[midi(root) % 12]


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


static func triad_voicings(root: Vector2i, chord_index: int, nearby: bool = true) -> Array[Array]:
	## Different strings and a maximum four-fret fretted span make answers playable.
	## Open strings do not stretch the fretting hand; the fixed root counts in the span.
	var chord: Dictionary = TRIADS[chord_index]
	var result: Array[Array] = []
	for third in candidates(root, chord.tones[0], nearby):
		for fifth in candidates(root, chord.tones[1], nearby):
			if root.x == third.x or root.x == fifth.x or third.x == fifth.x:
				continue
			var fretted: Array[int] = []
			for position: Vector2i in [root, third, fifth]:
				if position.y > 0:
					fretted.append(position.y)
			if fretted.is_empty() or fretted.max() - fretted.min() <= LOCAL_RADIUS:
				result.append([third, fifth])
	return result
