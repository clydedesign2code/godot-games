extends RefCounted
## Parse a whole spoken answer. Never search a sentence for a convenient letter.
## Fixed do: C=Do. Enharmonic spellings compare by pitch class, without octaves.

const NAMES := ["C", "C♯ / D♭", "D", "D♯ / E♭", "E", "F", "F♯ / G♭", "G", "G♯ / A♭", "A", "A♯ / B♭", "B"]
const BASES := {
	"c": 0, "see": 0, "sea": 0, "cee": 0,
	"d": 2, "dee": 2,
	"e": 4, "ee": 4,
	"f": 5, "eff": 5,
	"g": 7, "gee": 7,
	"a": 9, "ay": 9,
	"b": 11, "bee": 11, "be": 11,
	"do": 0, "doh": 0, "dough": 0, "哆": 0, "多": 0,
	"re": 2, "ray": 2, "ré": 2, "瑞": 2, "來": 2, "来": 2,
	"mi": 4, "me": 4, "咪": 4, "米": 4,
	"fa": 5, "fah": 5, "發": 5, "发": 5,
	"sol": 7, "so": 7, "soh": 7, "嗦": 7,
	"la": 9, "lah": 9, "拉": 9,
	"si": 11, "ti": 11, "tee": 11, "tea": 11, "西": 11, "希": 11
}


static func parse(transcript: String) -> int:
	var text := transcript.strip_edges().to_lower().replace("♯", " sharp ").replace("♭", " flat ").replace("＃", " sharp ").replace("#", " sharp ")
	# Compact letter accidentals, including Bb; don't interpret the word 'be' as B♭.
	var compact := RegEx.new()
	compact.compile("^([a-g])b$")
	var flat := compact.search(text)
	if flat != null:
		text = flat.get_string(1) + " flat"
	text = text.replace("-", " ").replace("’", "'")
	var punctuation := RegEx.new()
	punctuation.compile("[.,!?。！？、]")
	text = punctuation.sub(text, "", true).strip_edges()
	for prefix in ["this is ", "it is ", "it's ", "the note is ", "note ", "這是", "这是", "答案是"]:
		if text.begins_with(prefix):
			text = text.trim_prefix(prefix).strip_edges()
			break
	flat = compact.search(text)
	if flat != null:
		text = flat.get_string(1) + " flat"
	var whitespace := RegEx.new()
	whitespace.compile("\\s+")
	text = whitespace.sub(text, " ", true)
	# Permit an article only before another unambiguous note token ("a B").
	if text.begins_with("a ") and text != "a sharp" and text != "a flat" and text != "a natural":
		text = text.trim_prefix("a ")
	var delta: int = 0
	var accidental: bool = false
	for prefix in ["升", "降"]:
		if text.begins_with(prefix):
			delta = 1 if prefix == "升" else -1
			accidental = true
			text = text.trim_prefix(prefix).strip_edges()
	for suffix in [" sharp", " flat", " natural", "升", "降", "還原", "还原"]:
		if text.ends_with(suffix):
			if accidental:
				return -1
			delta = 1 if suffix in [" sharp", "升"] else (-1 if suffix in [" flat", "降"] else 0)
			text = text.trim_suffix(suffix).strip_edges()
			break
	if not BASES.has(text):
		return -1
	return posmod(int(BASES[text]) + delta, 12)


static func from_recognition(result: Dictionary) -> int:
	# Missing/low confidence and conflicting alternative notes are recognition issues,
	# not wrong music answers. The caller must offer retry without penalizing.
	if float(result.get("confidence", 0.0)) < 0.35:
		return -1
	var note: int = parse(str(result.get("text", "")))
	if note < 0:
		return -1
	for alternative in result.get("alternatives", []):
		var other: int = parse(str(alternative))
		if other >= 0 and other != note:
			return -1
	return note
