extends Control
## One flat 2D house. Body rectangle + triangular roof + door + windows +
## a prominent number plaque above the roof. Exposes a drop target rect
## centered on the door — letters get stuck there when delivered.
##
## No 3D assets are reused; colors come from the existing House node's
## `body_color` / `roof_color` so the 2D street still reads as the same
## neighborhood.

signal hover_changed(is_hover: bool)

const WARM_GRAY := Color(0.28, 0.22, 0.16, 1)
const CREAM     := Color(0.96, 0.93, 0.82, 1)

var house_id: String = ""
var house_label: String = ""
var body_color: Color = Color(0.74, 0.45, 0.30)
var roof_color: Color = Color(0.55, 0.30, 0.20)

var _body_rect: Rect2
var _roof_points: PackedVector2Array
var _door_rect: Rect2
var _windows: Array = []  ## [Rect2]
var _number_label: Label
var _hovered: bool = false
var _attached_letters: Array = []  ## [LetterCard]


func configure(rec: SortingLevelExtractor.HouseRecord, target_size: Vector2) -> void:
	house_id = rec.id
	house_label = rec.label
	body_color = rec.body_color
	roof_color = rec.roof_color
	custom_minimum_size = target_size
	size = target_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compute_geometry()
	_ensure_number_label()
	queue_redraw()


func _compute_geometry() -> void:
	var w := size.x
	var h := size.y
	var body_h := h * 0.65
	var roof_h := h * 0.25
	var plaque_h := h * 0.10
	# plaque sits above the roof so the number reads against the sky.
	var body_top := plaque_h + roof_h
	_body_rect = Rect2(0, body_top, w, body_h)
	_roof_points = PackedVector2Array([
		Vector2(-8, body_top),
		Vector2(w + 8, body_top),
		Vector2(w * 0.5, plaque_h * 0.2),
	])

	var door_w := w * 0.22
	var door_h := body_h * 0.55
	_door_rect = Rect2(
		(w - door_w) * 0.5,
		body_top + body_h - door_h,
		door_w,
		door_h,
	)

	# Varying window layout per house keeps them visually distinct beyond
	# just the number.
	var seed_val := int(house_label) if house_label.is_valid_int() else house_label.length()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val * 131 + 7
	_windows.clear()
	var win_w := w * 0.18
	var win_h := body_h * 0.22
	var win_y := body_top + body_h * 0.18
	var layout := rng.randi_range(0, 2)
	match layout:
		0:
			_windows.append(Rect2(w * 0.12, win_y, win_w, win_h))
			_windows.append(Rect2(w - w * 0.12 - win_w, win_y, win_w, win_h))
		1:
			_windows.append(Rect2(w * 0.10, win_y, win_w * 0.8, win_h))
			_windows.append(Rect2(w * 0.38, win_y, win_w * 0.8, win_h))
			_windows.append(Rect2(w - w * 0.10 - win_w * 0.8, win_y, win_w * 0.8, win_h))
		_:
			_windows.append(Rect2(w * 0.16, win_y, win_w * 1.15, win_h * 1.15))
			_windows.append(Rect2(w - w * 0.16 - win_w * 1.15, win_y, win_w * 1.15, win_h * 1.15))


func _ensure_number_label() -> void:
	if _number_label == null:
		_number_label = Label.new()
		_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_number_label)
	_number_label.text = house_label
	_number_label.add_theme_font_size_override("font_size", int(size.y * 0.11))
	_number_label.add_theme_color_override("font_color", WARM_GRAY)
	_number_label.add_theme_color_override("font_outline_color", CREAM)
	_number_label.add_theme_constant_override("outline_size", 8)
	_number_label.size = Vector2(size.x, size.y * 0.10)
	_number_label.position = Vector2(0, 0)


func _draw() -> void:
	# Roof triangle
	draw_colored_polygon(_roof_points, roof_color)
	# Roof outline
	var roof_outline := _roof_points.duplicate()
	roof_outline.append(_roof_points[0])
	draw_polyline(roof_outline, WARM_GRAY, 3.0, true)

	# Body
	draw_rect(_body_rect, body_color, true)
	draw_rect(_body_rect, WARM_GRAY, false, 3.0)

	# Windows (cream interior with warm-gray sash)
	for w_any in _windows:
		var w: Rect2 = w_any
		draw_rect(w, Color(0.98, 0.94, 0.72, 1), true)
		draw_rect(w, WARM_GRAY, false, 2.0)
		# Sash cross
		var mid: Vector2 = w.position + Vector2(w.size.x * 0.5, w.size.y * 0.5)
		draw_line(Vector2(w.position.x, mid.y), Vector2(w.position.x + w.size.x, mid.y), WARM_GRAY, 1.5)
		draw_line(Vector2(mid.x, w.position.y), Vector2(mid.x, w.position.y + w.size.y), WARM_GRAY, 1.5)

	# Door — intentionally drawn with the roof_color so it's a visual echo
	# of the palette without needing a third swatch.
	draw_rect(_door_rect, roof_color.darkened(0.15), true)
	draw_rect(_door_rect, WARM_GRAY, false, 3.0)
	# Door knob
	var knob_pos := _door_rect.position + Vector2(_door_rect.size.x * 0.82, _door_rect.size.y * 0.5)
	draw_circle(knob_pos, 3.0, Color(0.92, 0.82, 0.32, 1))

	# Hover pulse — "this is a drop zone" NOT "this is correct".
	if _hovered:
		var pulse_rect := _door_rect.grow(6.0)
		draw_rect(pulse_rect, Color(0.98, 0.93, 0.72, 0.35), true)
		draw_rect(pulse_rect, Color(0.28, 0.22, 0.16, 0.9), false, 2.5)


# ─────────────────────────────────────────────────────────────────────────────
# Drop target API
# ─────────────────────────────────────────────────────────────────────────────

func get_drop_target_global_rect() -> Rect2:
	# The door + its immediate surround, in global coordinates.
	var grown := _door_rect.grow(8.0)
	return Rect2(global_position + grown.position, grown.size)


func contains_drop_point(global_pos: Vector2) -> bool:
	return get_drop_target_global_rect().has_point(global_pos)


func set_hover(h: bool) -> void:
	if _hovered == h:
		return
	_hovered = h
	queue_redraw()
	hover_changed.emit(h)


# ─────────────────────────────────────────────────────────────────────────────
# Letter attachment bookkeeping
# ─────────────────────────────────────────────────────────────────────────────

func receive_letter(card) -> void:
	if not _attached_letters.has(card):
		_attached_letters.append(card)


func release_letter(card) -> void:
	_attached_letters.erase(card)


## Global point at which the attached letter should settle — the top-center
## of the door. Slight offset up so the letter overlaps the door frame and
## reads as "stuck to it" rather than lying in front of it.
func attachment_global_point() -> Vector2:
	var p := _door_rect.position + Vector2(_door_rect.size.x * 0.5, _door_rect.size.y * 0.3)
	return global_position + p
