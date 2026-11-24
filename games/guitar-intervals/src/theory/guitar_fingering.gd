extends RefCounted
## Suggested left-hand fingers for a grip on three or four consecutive strings.
## Positions and fingers are ordered from the thickest to the thinnest string.

static func fingers(shape: Array) -> Array[int]:
	var result: Array[int] = []
	if shape.size() < 3 or shape.size() > 4:
		return result
	var frets: Array[int] = []
	for i in range(shape.size()):
		var position: Vector2i = shape[i]
		if position.y < 0 or (i > 0 and position.x != shape[i - 1].x - 1):
			return result
		if position.y > 0 and position.y not in frets:
			frets.append(position.y)
	result.resize(shape.size())
	result.fill(0)
	frets.sort()

	# At one fret a barre can pass underneath a higher fretted note.
	# An open string or a lower target fret splits it into separate fingers.
	var groups: Array[Array] = []
	for fret in frets:
		var group: Array[int] = []
		for i in range(shape.size()):
			if shape[i].y == fret:
				group.append(i)
			elif shape[i].y < fret and not group.is_empty():
				groups.append(group)
				group = []
		if not group.is_empty():
			groups.append(group)

	var previous_finger := 0
	for i in range(groups.size()):
		var group: Array = groups[i]
		var fret: int = shape[group[0]].y
		var natural_finger := 1 + fret - frets[0]
		# Keep fingers in fret order, reserving one for each remaining group.
		var finger := clampi(natural_finger, previous_finger + 1, 4 - (groups.size() - i - 1))
		for string_index: int in group:
			result[string_index] = finger
		previous_finger = finger
	return result
