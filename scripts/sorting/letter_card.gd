extends Control
## A single Papers Please-style letter. Shows the destination address in
## prominent monospace type — reading that address and matching it to a
## house number is the entire puzzle.
##
## While in the tray the card sits in a slot assigned by LetterTray; during
## a drag it's reparented into the desk's DragLayer so it paints above the
## rest of the scene. On drop, the desk decides whether to attach the card
## to a house or return it to its slot.

const CREAM        := Color(0.97, 0.93, 0.82, 1)
const CREAM_DARK   := Color(0.93, 0.86, 0.72, 1)
const INK          := Color(0.17, 0.14, 0.10, 1)
const WARM_GRAY    := Color(0.40, 0.35, 0.28, 1)
const BORDER       := Color(0.52, 0.42, 0.30, 1)
const STAMP_ACCENT := Color(0.82, 0.32, 0.22, 1)
const STAMP_DEEP   := Color(0.56, 0.18, 0.14, 1)
const NOT_MAIL_RED := Color(0.78, 0.16, 0.14, 0.88)

const CARD_SIZE := Vector2(240, 150)

var mail: Mail
var desk                     ## SortingDesk (forward-declared to avoid cyclic types)
var tray                     ## LetterTray — set by the tray when added
var home_position: Vector2   ## Resting position (in tray coords)
var home_rotation: float     ## Resting rotation (in tray coords)
var attached_house           ## HouseCard, or null
var attached_to_house_id: String = ""

var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _target_rotation: float = 0.0
var _not_mail_stamp_visible: bool = false
var _hover_lift_tween: Tween

var _address_label: Label
var _recipient_label: Label
var _deliver_to_label: Label
var _not_mail_label: Control


func configure(m: Mail) -> void:
	mail = m
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_children()
	queue_redraw()


func _build_children() -> void:
	_deliver_to_label = Label.new()
	_deliver_to_label.text = "DELIVER TO"
	_deliver_to_label.add_theme_font_size_override("font_size", 10)
	_deliver_to_label.add_theme_color_override("font_color", WARM_GRAY)
	_deliver_to_label.position = Vector2(16, 22)
	_deliver_to_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_deliver_to_label)

	_recipient_label = Label.new()
	_recipient_label.text = (mail.recipient_name as String).to_upper()
	_recipient_label.add_theme_font_size_override("font_size", 13)
	_recipient_label.add_theme_color_override("font_color", INK)
	_recipient_label.position = Vector2(16, 38)
	_recipient_label.size = Vector2(CARD_SIZE.x - 80, 16)
	_recipient_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_recipient_label)

	_address_label = Label.new()
	_address_label.text = _format_address(mail.address_line)
	_address_label.add_theme_font_size_override("font_size", 18)
	_address_label.add_theme_color_override("font_color", INK)
	_address_label.position = Vector2(16, 60)
	_address_label.size = Vector2(CARD_SIZE.x - 30, 60)
	_address_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_address_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_address_label)

	_not_mail_label = _build_not_mail_stamp()
	_not_mail_label.visible = false
	add_child(_not_mail_label)


func _format_address(addr: String) -> String:
	# Papers Please register: uppercase, trimmed. Leaves obscured "?? Maple…"
	# addresses intact so the elimination-puzzle levels still work.
	return addr.to_upper().strip_edges()


func _build_not_mail_stamp() -> Control:
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.size = Vector2(200, 50)
	wrap.position = Vector2(20, 50)
	wrap.rotation = deg_to_rad(-10.0)

	var stamp_label := Label.new()
	stamp_label.text = "NOT MY MAIL"
	stamp_label.add_theme_font_size_override("font_size", 28)
	stamp_label.add_theme_color_override("font_color", NOT_MAIL_RED)
	stamp_label.add_theme_color_override("font_outline_color", Color(0.45, 0.08, 0.06, 0.6))
	stamp_label.add_theme_constant_override("outline_size", 4)
	stamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp_label.size = Vector2(200, 50)
	stamp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(stamp_label)
	return wrap


# ─────────────────────────────────────────────────────────────────────────────
# Drawing
# ─────────────────────────────────────────────────────────────────────────────

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	# Drop shadow
	draw_rect(Rect2(Vector2(3, 4), size), Color(0, 0, 0, 0.18), true)
	# Paper
	draw_rect(rect, CREAM, true)
	# Deckled edge strip (slightly darker band at top for variety)
	draw_rect(Rect2(0, 0, size.x, 12), CREAM_DARK, true)
	# Border
	draw_rect(rect, BORDER, false, 1.0)

	# Stamp rectangle (top-right)
	var stamp_rect := Rect2(size.x - 72, 10, 60, 70)
	draw_rect(stamp_rect, STAMP_ACCENT, true)
	# Inner dashed border — approximated with dotted rects.
	_draw_dashed_border(stamp_rect.grow(-4), Color(1, 1, 1, 0.85), 4.0, 3.0)
	# Stamp mini-illustration: concentric arcs suggest an icon without needing art.
	var cx := stamp_rect.position.x + stamp_rect.size.x * 0.5
	var cy := stamp_rect.position.y + stamp_rect.size.y * 0.45
	draw_circle(Vector2(cx, cy), 12.0, Color(1, 1, 1, 0.25))
	draw_circle(Vector2(cx, cy), 8.0, STAMP_DEEP)
	# Stamp denomination text
	var stamp_label_pos := Vector2(stamp_rect.position.x, stamp_rect.position.y + stamp_rect.size.y - 14)
	draw_string(
		ThemeDB.fallback_font,
		stamp_label_pos + Vector2(0, 10),
		"5¢",
		HORIZONTAL_ALIGNMENT_CENTER,
		stamp_rect.size.x,
		10,
		Color(1, 1, 1, 0.92),
	)

	# Postmark: faint offset circle overlapping the stamp
	var pm_center := Vector2(size.x - 72, 70)
	draw_arc(pm_center, 22.0, 0, TAU, 32, Color(0.28, 0.22, 0.16, 0.5), 1.2)
	draw_arc(pm_center, 18.0, 0, TAU, 32, Color(0.28, 0.22, 0.16, 0.45), 1.0)
	draw_string(
		ThemeDB.fallback_font,
		pm_center + Vector2(-16, -2),
		"1966",
		HORIZONTAL_ALIGNMENT_CENTER,
		32,
		8,
		Color(0.28, 0.22, 0.16, 0.7),
	)

	# Bottom address underline
	draw_line(Vector2(16, size.y - 14), Vector2(size.x - 16, size.y - 14), WARM_GRAY, 1.0)


func _draw_dashed_border(rect: Rect2, color: Color, dash: float, gap: float) -> void:
	var perimeter := 2.0 * (rect.size.x + rect.size.y)
	var step := dash + gap
	var t := 0.0
	while t < perimeter:
		var p1 := _point_on_rect(rect, t)
		var p2 := _point_on_rect(rect, min(t + dash, perimeter))
		draw_line(p1, p2, color, 1.0)
		t += step


func _point_on_rect(rect: Rect2, t: float) -> Vector2:
	var w := rect.size.x
	var h := rect.size.y
	var tt := fposmod(t, 2.0 * (w + h))
	if tt < w:
		return rect.position + Vector2(tt, 0)
	tt -= w
	if tt < h:
		return rect.position + Vector2(w, tt)
	tt -= h
	if tt < w:
		return rect.position + Vector2(w - tt, h)
	tt -= w
	return rect.position + Vector2(0, h - tt)


# ─────────────────────────────────────────────────────────────────────────────
# Input
# ─────────────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _is_dragging:
			_begin_drag(event.global_position)
			accept_event()


func _process(_delta: float) -> void:
	# Smoothly interpolate rotation toward target for a bit of weight.
	rotation = lerp_angle(rotation, _target_rotation, 0.25)


func _input(event: InputEvent) -> void:
	if not _is_dragging:
		return
	if event is InputEventMouseMotion:
		_update_drag_position(event.global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag(event.global_position)


# ─────────────────────────────────────────────────────────────────────────────
# Drag lifecycle
# ─────────────────────────────────────────────────────────────────────────────

func _begin_drag(mouse_global: Vector2) -> void:
	_is_dragging = true
	_drag_offset = mouse_global - global_position
	# Reparent into the desk's drag layer so we paint above everything.
	var drag_layer: Node = desk._drag_layer
	var current_global := global_position
	var current_rot := rotation
	get_parent().remove_child(self)
	drag_layer.add_child(self)
	global_position = current_global
	rotation = current_rot
	_target_rotation = deg_to_rad(-6.0)
	if desk.has_method("on_letter_drag_started"):
		desk.on_letter_drag_started(self)


func _update_drag_position(mouse_global: Vector2) -> void:
	global_position = mouse_global - _drag_offset
	if desk.has_method("on_letter_drag_moved"):
		desk.on_letter_drag_moved(self, mouse_global)


func _end_drag(mouse_global: Vector2) -> void:
	_is_dragging = false
	_target_rotation = 0.0
	if desk.has_method("on_letter_drag_released"):
		desk.on_letter_drag_released(self, mouse_global)


# ─────────────────────────────────────────────────────────────────────────────
# Placement helpers (called by the desk)
# ─────────────────────────────────────────────────────────────────────────────

func attach_to_house(house) -> void:
	attached_house = house
	attached_to_house_id = house.house_id
	# Reparent into the house so the card follows the house's future motion
	# (e.g. if we animate houses or resize the scene). The card retains its
	# own rotation so it still reads as a piece of paper slapped on the door.
	var target_global: Vector2 = house.attachment_global_point()
	get_parent().remove_child(self)
	house.add_child(self)
	global_position = target_global - size * 0.5
	_target_rotation = deg_to_rad(randf_range(-8.0, 8.0))
	rotation = _target_rotation
	# Clear any prior "NOT MY MAIL" stamp — the player is trying again.
	if _not_mail_stamp_visible:
		_not_mail_label.visible = false
		_not_mail_stamp_visible = false
		modulate = Color(1, 1, 1, 1)


func return_to_tray_slot(tween_duration: float = 0.22) -> void:
	# Reparented back into the tray, then animated to the slot.
	if tray == null:
		return
	if get_parent() != tray:
		var keep_global := global_position
		if get_parent() != null:
			get_parent().remove_child(self)
		tray.add_child(self)
		global_position = keep_global
	var target_local := home_position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_local, tween_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", home_rotation, tween_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_target_rotation = home_rotation
	attached_house = null
	attached_to_house_id = ""


func mark_not_my_mail() -> void:
	_not_mail_label.visible = true
	_not_mail_stamp_visible = true
	# Fade in via modulate on the stamp wrapper
	_not_mail_label.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_not_mail_label, "modulate", Color(1, 1, 1, 1), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
