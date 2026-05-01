extends Control
## Root controller for the 2D mail-sorting experiment. Builds the scene
## procedurally: a flat 2D street across the top, a fanned tray of letters
## across the bottom, HUD chrome, drag layer. Reuses letter + house data
## from the existing 3D levels via SortingLevelExtractor.
##
## Intentionally self-contained: no GameState writes, no signals touching the
## side-scroller HUD. Flipping the mode flag or pressing F1 leaves the 3D
## code path untouched.

const HouseCardScript := preload("res://scripts/sorting/house_card.gd")
const LetterCardScript := preload("res://scripts/sorting/letter_card.gd")
const LetterTrayScript := preload("res://scripts/sorting/letter_tray.gd")
const EndDaySummaryScript := preload("res://scripts/sorting/end_day_summary.gd")

const SKY_COLOR      := Color(0.72, 0.88, 0.98, 1)
const SKY_TOP_COLOR  := Color(0.48, 0.76, 0.96, 1)
const GRASS_COLOR    := Color(0.56, 0.78, 0.42, 1)
const STREET_COLOR   := Color(0.42, 0.42, 0.44, 1)
const SIDEWALK_COLOR := Color(0.86, 0.82, 0.70, 1)
const CREAM          := Color(0.96, 0.93, 0.82, 1)
const INK            := Color(0.17, 0.14, 0.10, 1)
const WARM_GRAY      := Color(0.32, 0.28, 0.24, 1)

const HOUSES_BAND_HEIGHT_RATIO := 0.62
const TRAY_HEIGHT_RATIO        := 0.32

var _level_index: int = SortingMode.DEFAULT_LEVEL_INDEX
var _level_data: SortingLevelExtractor.LevelData
var _house_cards: Array = []  ## [HouseCard]
var _letter_cards: Array = []  ## [LetterCard]
var _tray
var _drag_layer: Control
var _hud_layer: Control
var _letters_remaining_label: Label
var _end_day_button: Button
var _level_label: Label
var _hint_label: Label
var _summary
var _first_day_action_taken: bool = false

## Day-run stats. Reset each time the tray is reloaded (new day).
var _total_letters: int = 0
var _correct_first_try: int = 0
## Letter ids that have been placed somewhere — used to mark "first try" only
## on the initial end-of-day pass.
var _ever_placed_ids: Dictionary = {}
var _has_evaluated_once: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_static_backdrop()
	_build_drag_layer()
	_build_hud_layer()
	_build_summary()
	_consume_pending_level()
	_load_level(_level_index)


## If the sorting level selector stashed a chosen level on SortingMode,
## convert it to an index into SORTING_LEVEL_PATHS and clear the stash.
## A stash that doesn't match any pool entry is ignored — the desk falls
## back to the default level rather than crashing.
func _consume_pending_level() -> void:
	var pending: String = SortingMode.pending_level_path
	if pending.is_empty():
		return
	SortingMode.pending_level_path = ""
	var idx := SortingMode.SORTING_LEVEL_PATHS.find(pending)
	if idx >= 0:
		_level_index = idx


# ─────────────────────────────────────────────────────────────────────────────
# Layout
# ─────────────────────────────────────────────────────────────────────────────

func _build_static_backdrop() -> void:
	var bg := ColorRect.new()
	bg.color = SKY_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Subtle sky top tint via a second rect — avoids pulling in a gradient resource.
	var sky_top := ColorRect.new()
	sky_top.color = SKY_TOP_COLOR
	sky_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_top.anchor_left = 0.0
	sky_top.anchor_right = 1.0
	sky_top.anchor_top = 0.0
	sky_top.anchor_bottom = 0.0
	sky_top.offset_bottom = 140.0
	add_child(sky_top)

	var sun := _make_sun()
	add_child(sun)

	for cloud_data in [[0.15, 60.0, 1.0], [0.42, 90.0, 0.7], [0.78, 50.0, 1.15]]:
		add_child(_make_cloud(cloud_data[0], cloud_data[1], cloud_data[2]))

	# Grass band
	var grass := ColorRect.new()
	grass.color = GRASS_COLOR
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grass.anchor_left = 0.0
	grass.anchor_right = 1.0
	grass.anchor_top = HOUSES_BAND_HEIGHT_RATIO
	grass.anchor_bottom = HOUSES_BAND_HEIGHT_RATIO
	grass.offset_top = -4.0
	grass.offset_bottom = 46.0
	add_child(grass)

	# Sidewalk band
	var sidewalk := ColorRect.new()
	sidewalk.color = SIDEWALK_COLOR
	sidewalk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sidewalk.anchor_left = 0.0
	sidewalk.anchor_right = 1.0
	sidewalk.anchor_top = HOUSES_BAND_HEIGHT_RATIO
	sidewalk.anchor_bottom = HOUSES_BAND_HEIGHT_RATIO
	sidewalk.offset_top = 46.0
	sidewalk.offset_bottom = 78.0
	add_child(sidewalk)

	# Thin street strip under the sidewalk
	var street := ColorRect.new()
	street.color = STREET_COLOR
	street.mouse_filter = Control.MOUSE_FILTER_IGNORE
	street.anchor_left = 0.0
	street.anchor_right = 1.0
	street.anchor_top = HOUSES_BAND_HEIGHT_RATIO
	street.anchor_bottom = HOUSES_BAND_HEIGHT_RATIO
	street.offset_top = 78.0
	street.offset_bottom = 118.0
	add_child(street)

	# Tray backdrop panel — warm wood-ish cream so letters pop against it.
	var tray_bg := ColorRect.new()
	tray_bg.color = Color(0.72, 0.62, 0.48, 1)
	tray_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray_bg.anchor_left = 0.0
	tray_bg.anchor_right = 1.0
	tray_bg.anchor_top = 1.0 - TRAY_HEIGHT_RATIO
	tray_bg.anchor_bottom = 1.0
	add_child(tray_bg)

	var tray_edge := ColorRect.new()
	tray_edge.color = Color(0.52, 0.42, 0.30, 1)
	tray_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray_edge.anchor_left = 0.0
	tray_edge.anchor_right = 1.0
	tray_edge.anchor_top = 1.0 - TRAY_HEIGHT_RATIO
	tray_edge.anchor_bottom = 1.0 - TRAY_HEIGHT_RATIO
	tray_edge.offset_bottom = 4.0
	add_child(tray_edge)


func _make_sun() -> Node:
	var n := Polygon2D.new()
	n.color = Color(0.98, 0.86, 0.38, 1)
	var pts := PackedVector2Array()
	var r := 42.0
	var steps := 28
	for i in steps:
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	n.polygon = pts
	n.position = Vector2(140, 110)
	return n


func _make_cloud(x_frac: float, y: float, scale_factor: float) -> Node:
	var wrap := Node2D.new()
	wrap.position = Vector2(x_frac * 1280.0, y)
	wrap.scale = Vector2.ONE * scale_factor
	for offset in [Vector2(-36, 0), Vector2(0, -14), Vector2(26, 4), Vector2(56, -6), Vector2(82, 8)]:
		var poly := Polygon2D.new()
		poly.color = Color(1.0, 1.0, 1.0, 0.95)
		var pts := PackedVector2Array()
		var r := 22.0
		for i in 16:
			var a := TAU * float(i) / 16.0
			pts.append(Vector2(cos(a) * r, sin(a) * r * 0.7))
		poly.polygon = pts
		poly.position = offset
		wrap.add_child(poly)
	return wrap


func _build_drag_layer() -> void:
	_drag_layer = Control.new()
	_drag_layer.name = "DragLayer"
	_drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drag_layer.z_index = 100
	add_child(_drag_layer)


func _build_hud_layer() -> void:
	_hud_layer = Control.new()
	_hud_layer.name = "HUD"
	_hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_layer.z_index = 50
	add_child(_hud_layer)

	_letters_remaining_label = _make_pill_label("letters: 0 / 0")
	_letters_remaining_label.position = Vector2(22, 22)
	_hud_layer.add_child(_letters_remaining_label)

	_level_label = _make_pill_label("")
	_level_label.position = Vector2(22, 64)
	_hud_layer.add_child(_level_label)

	_end_day_button = _make_pill_button("END DAY")
	_end_day_button.pressed.connect(_on_end_day_pressed)
	# Anchor top-right.
	_end_day_button.anchor_left = 1.0
	_end_day_button.anchor_right = 1.0
	_end_day_button.anchor_top = 0.0
	_end_day_button.anchor_bottom = 0.0
	_end_day_button.offset_left = -182.0
	_end_day_button.offset_top = 22.0
	_end_day_button.offset_right = -22.0
	_end_day_button.offset_bottom = 62.0
	_hud_layer.add_child(_end_day_button)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", Color(0.18, 0.14, 0.10, 0.55))
	_hint_label.text = "click + drag a letter to a house"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.anchor_left = 0.0
	_hint_label.anchor_right = 1.0
	_hint_label.anchor_top = 1.0 - TRAY_HEIGHT_RATIO
	_hint_label.anchor_bottom = 1.0 - TRAY_HEIGHT_RATIO
	_hint_label.offset_top = -24.0
	_hint_label.offset_bottom = -4.0
	_hud_layer.add_child(_hint_label)


func _build_summary() -> void:
	_summary = EndDaySummaryScript.new()
	_summary.visible = false
	_summary.z_index = 200
	_summary.finish_pressed.connect(_on_summary_finish_pressed)
	add_child(_summary)


func _make_pill_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", INK)
	l.add_theme_color_override("font_outline_color", CREAM)
	l.add_theme_constant_override("outline_size", 6)
	l.custom_minimum_size = Vector2(0, 28)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var bg := StyleBoxFlat.new()
	bg.bg_color = CREAM
	bg.border_color = WARM_GRAY
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(14)
	bg.content_margin_left = 16
	bg.content_margin_right = 16
	bg.content_margin_top = 4
	bg.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", bg)
	return l


func _make_pill_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	var bg := StyleBoxFlat.new()
	bg.bg_color = CREAM
	bg.border_color = WARM_GRAY
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(14)
	bg.content_margin_left = 16
	bg.content_margin_right = 16
	bg.content_margin_top = 6
	bg.content_margin_bottom = 6
	b.add_theme_stylebox_override("normal", bg)
	var hov := bg.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.94, 0.90, 0.78, 1)
	b.add_theme_stylebox_override("hover", hov)
	var pressed := bg.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.90, 0.86, 0.72, 1)
	b.add_theme_stylebox_override("pressed", pressed)
	return b


# ─────────────────────────────────────────────────────────────────────────────
# Level loading
# ─────────────────────────────────────────────────────────────────────────────

func _load_level(idx: int) -> void:
	var path: String = SortingMode.SORTING_LEVEL_PATHS[idx]
	_level_data = SortingLevelExtractor.extract(path)
	_level_label.text = "day %d · %s" % [_level_data.day_number, _level_data.level_name]

	_clear_houses()
	_clear_letters()

	_spawn_houses(_level_data.houses)
	_spawn_letters(_level_data.letters)

	_total_letters = _letter_cards.size()
	_correct_first_try = 0
	_ever_placed_ids.clear()
	_has_evaluated_once = false
	_first_day_action_taken = false

	_hint_label.visible = (idx == SortingMode.DEFAULT_LEVEL_INDEX)
	_update_letters_remaining()


func _clear_houses() -> void:
	for c in _house_cards:
		c.queue_free()
	_house_cards.clear()


func _clear_letters() -> void:
	for c in _letter_cards:
		c.queue_free()
	_letter_cards.clear()
	if _tray != null:
		_tray.queue_free()
		_tray = null


func _spawn_houses(houses: Array) -> void:
	if houses.is_empty():
		return
	var viewport_size := get_viewport_rect().size
	var band_top := 60.0
	var band_bottom := viewport_size.y * HOUSES_BAND_HEIGHT_RATIO
	var band_height := band_bottom - band_top

	var n := houses.size()
	# House width scales so 2 houses aren't enormous and 6 still fit.
	var available_width := viewport_size.x - 80.0
	var slot_width := available_width / float(n)
	var house_width: float = clampf(slot_width * 0.78, 140.0, 230.0)
	var house_height: float = clampf(band_height * 0.9, 180.0, 320.0)

	for i in n:
		var rec: SortingLevelExtractor.HouseRecord = houses[i]
		var card := HouseCardScript.new()
		card.configure(rec, Vector2(house_width, house_height))
		var slot_center_x := 40.0 + slot_width * (float(i) + 0.5)
		card.position = Vector2(slot_center_x - house_width * 0.5, band_bottom - house_height)
		add_child(card)
		_house_cards.append(card)


func _spawn_letters(letters: Array) -> void:
	var viewport_size := get_viewport_rect().size
	var tray_top := viewport_size.y * (1.0 - TRAY_HEIGHT_RATIO)
	var tray_height := viewport_size.y * TRAY_HEIGHT_RATIO

	_tray = LetterTrayScript.new()
	_tray.desk = self
	_tray.drag_layer = _drag_layer
	_tray.anchor_left = 0.0
	_tray.anchor_right = 1.0
	_tray.anchor_top = 1.0 - TRAY_HEIGHT_RATIO
	_tray.anchor_bottom = 1.0
	_tray.z_index = 10
	add_child(_tray)

	for i in letters.size():
		var mail: Mail = letters[i]
		var card := LetterCardScript.new()
		card.configure(mail)
		card.desk = self
		_letter_cards.append(card)
		_tray.add_letter(card)

	_tray.layout(viewport_size.x, tray_height)


# ─────────────────────────────────────────────────────────────────────────────
# Drag-and-drop contract (called by LetterCard)
# ─────────────────────────────────────────────────────────────────────────────

## Called when the player begins dragging a letter. Moves the letter card
## into the drag layer so it paints above everything else.
func on_letter_drag_started(card) -> void:
	if card.attached_to_house_id != "":
		# Dragging a letter off a house back to the tray — clear the record
		# so the evaluation pass treats it as undelivered until re-dropped.
		_detach_letter_from_house(card)
	_clear_house_hover_highlight()


## Called during drag motion — highlight the house currently under the cursor.
## Note: this is NOT correctness feedback. Every house pulses equally when
## hovered, regardless of whether it matches the letter's address. The puzzle
## is reading the address yourself.
func on_letter_drag_moved(_card, global_pos: Vector2) -> void:
	var hovered = _house_at(global_pos)
	for c in _house_cards:
		c.set_hover(c == hovered)


## Called when the letter is released. Returns the house it landed on, or null.
## The desk is responsible for attaching / returning-to-slot.
func on_letter_drag_released(card, global_pos: Vector2):
	_clear_house_hover_highlight()
	_first_day_action_taken = true
	_hint_label.visible = false
	var house = _house_at(global_pos)
	if house != null:
		_attach_letter_to_house(card, house)
		_ever_placed_ids[card.mail.id] = true
		_update_letters_remaining()
		# If the tray is empty after this drop, auto-trigger end-of-day.
		if _count_letters_in_tray() == 0:
			_run_end_of_day()
	else:
		_tray.return_card_to_slot(card)


func _clear_house_hover_highlight() -> void:
	for c in _house_cards:
		c.set_hover(false)


func _house_at(global_pos: Vector2):
	# Front-to-back hit test against the house cards' drop targets.
	for c in _house_cards:
		if c.contains_drop_point(global_pos):
			return c
	return null


func _attach_letter_to_house(card, house) -> void:
	card.attach_to_house(house)
	house.receive_letter(card)


func _detach_letter_from_house(card) -> void:
	if card.attached_house != null:
		card.attached_house.release_letter(card)
	card.attached_house = null
	card.attached_to_house_id = ""


# ─────────────────────────────────────────────────────────────────────────────
# End-of-day
# ─────────────────────────────────────────────────────────────────────────────

func _on_end_day_pressed() -> void:
	_run_end_of_day()


func _run_end_of_day() -> void:
	var placed: Array = []
	var wrong: Array = []
	for c in _letter_cards:
		if c.attached_to_house_id != "":
			placed.append(c)
			# Address-matching rule — mirrors the 3D mode's check at
			# game_state.gd:52 and mailbox.gd:30.
			var correct: bool = (c.mail.correct_house_id == c.attached_to_house_id)
			if correct:
				if not _has_evaluated_once:
					_correct_first_try += 1
			else:
				wrong.append(c)

	# First-try accounting uses the ids that were ever placed before this
	# evaluation; after the first eval we don't re-bump correct_first_try.
	_has_evaluated_once = true

	for c in wrong:
		_return_wrong_letter(c)

	_update_letters_remaining()

	# If nothing to correct AND nothing to place, show final summary.
	var remaining_in_tray := _count_letters_in_tray()
	if remaining_in_tray == 0 and wrong.is_empty():
		_show_summary()


func _return_wrong_letter(card) -> void:
	_detach_letter_from_house(card)
	card.mark_not_my_mail()
	_tray.return_card_to_slot(card)


func _count_letters_in_tray() -> int:
	var c := 0
	for card in _letter_cards:
		if card.attached_to_house_id == "":
			c += 1
	return c


func _update_letters_remaining() -> void:
	var placed_count := 0
	for c in _letter_cards:
		if c.attached_to_house_id != "":
			placed_count += 1
	_letters_remaining_label.text = "letters: %d / %d placed" % [placed_count, _total_letters]


func _show_summary() -> void:
	var final_correct := 0
	for c in _letter_cards:
		if c.attached_to_house_id != "" and c.mail.correct_house_id == c.attached_to_house_id:
			final_correct += 1
	_summary.show_for_day(
		_level_data.day_number,
		_total_letters,
		_correct_first_try,
		final_correct,
	)


func _on_summary_finish_pressed() -> void:
	_summary.visible = false
	_advance_to_next_level()


func _advance_to_next_level() -> void:
	_level_index = (_level_index + 1) % SortingMode.SORTING_LEVEL_PATHS.size()
	_load_level(_level_index)
