extends Control
## Holds all letters for the day, fanned out across the bottom strip.
## Chosen layout: FANNED (slight rotations, slight overlap). Row layout was
## considered but with 6+ letters the row felt too rigid; fan reads more
## like a hand of documents being worked through.
##
## The tray never scrolls. With many letters the fan overlaps more; the
## desk's spec forbids hiding any.

var desk                          ## SortingDesk
var drag_layer: Control
var _cards: Array = []            ## [LetterCard]
var _slot_positions: Array = []   ## [Vector2] — rest positions per card
var _slot_rotations: Array = []   ## [float]  — rest rotations per card


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add_letter(card) -> void:
	card.tray = self
	_cards.append(card)
	add_child(card)


func layout(viewport_width: float, tray_height: float) -> void:
	_slot_positions.clear()
	_slot_rotations.clear()
	var n := _cards.size()
	if n == 0:
		return

	var card_size: Vector2 = _cards[0].size
	var horizontal_padding := 60.0
	var usable_w := viewport_width - 2.0 * horizontal_padding
	# Spacing: if more letters than fit comfortably, allow overlap. A single
	# letter gets its own full width.
	var desired_gap := 18.0
	var total_if_flush := card_size.x * float(n) + desired_gap * float(n - 1)
	var step: float
	if total_if_flush <= usable_w:
		step = card_size.x + desired_gap
	else:
		# Overlap so all letters fit.
		step = (usable_w - card_size.x) / max(1.0, float(n - 1))
	var row_width := step * float(n - 1) + card_size.x
	var start_x := (viewport_width - row_width) * 0.5

	# Vertical: fan arc. Center letter sits highest; edges dip slightly.
	var arc_depth := 22.0
	var base_y := tray_height * 0.18

	for i in n:
		var t := 0.0 if n == 1 else (float(i) / float(n - 1)) * 2.0 - 1.0  # -1..1
		var x := start_x + step * float(i)
		# Parabolic curve so the fan has a gentle arc
		var y := base_y + (t * t) * arc_depth
		var rot := deg_to_rad(lerp(-6.0, 6.0, 0.0 if n == 1 else float(i) / float(n - 1)))
		var pos := Vector2(x, y)
		_slot_positions.append(pos)
		_slot_rotations.append(rot)
		var card = _cards[i]
		card.home_position = pos
		card.home_rotation = rot
		if card.attached_to_house_id == "":
			card.position = pos
			card.rotation = rot


func return_card_to_slot(card) -> void:
	# Lookup the slot by identity in _cards.
	var idx := _cards.find(card)
	if idx == -1:
		return
	card.home_position = _slot_positions[idx]
	card.home_rotation = _slot_rotations[idx]
	card.return_to_tray_slot()
