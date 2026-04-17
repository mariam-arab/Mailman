extends CanvasLayer
## HUD for Special Delivery.
## Tab toggles the mail overlay. No keyboard nav — delivery is drag-only:
## grab an envelope, drop it onto the mailbox slot that appears above the
## nearest mailbox in world space. Right-click flips. Drag to the bottom
## edge dismisses back to the bag. Envelope positions persist across toggles.

@onready var stamp_row: HBoxContainer   = $StampRow
@onready var prompt_label: Label        = $PromptLabel
@onready var inspection: Control        = $Inspection
@onready var envelopes_layer: Control   = $Inspection/EnvelopesLayer
@onready var notebook_node: Panel       = $Inspection/Notebook
@onready var notebook_content: Label    = $Inspection/Notebook/Content
@onready var nb_prev: Label             = $Inspection/Notebook/PagePrev
@onready var nb_next: Label             = $Inspection/Notebook/PageNext
@onready var pager_hint: Label          = $Inspection/PagerHint
@onready var summary: Control           = $Summary
@onready var summary_label: Label       = $Summary/Center/SummaryLabel

var _player: Node               = null
var _showing_inspection: bool   = false
var _nearby_interactable        = null
var _cards: Array               = []

# Drag
var _drag_card                  = null
var _drag_offset: Vector2       = Vector2.ZERO

# Persisted envelope positions (letter.id → Vector2)
var _saved_positions: Dictionary = {}

# Delivery slot projected from the 3D mailbox
var _slot_panel: Panel          = null
var _camera: Camera3D           = null

# Notebook
const _NB_PAGES := [
	"Today's Route\n\n• House A — The Baker\n• House B — Hockey Family\n• House E — The Professor",
	"Delivery Tips\n\nRight-click an envelope\nto read the clue on\nthe back.",
	"Reminders\n\nDrag an envelope to the\nbottom of the screen to\nput it back in the bag.",
]
var _nb_page: int = 0

# Styles
var _sty_env:     StyleBoxFlat
var _sty_env_bk:  StyleBoxFlat
var _sty_nb:      StyleBoxFlat


# ── init ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_styles()
	_build_notebook()
	inspection.visible = false
	summary.visible    = false
	prompt_label.text  = ""
	GameState.day_started.connect(_on_day_started)
	GameState.day_ended.connect(_on_day_ended)
	GameState.letter_delivered.connect(_on_letter_delivered)
	GameState.selected_letter_changed.connect(_on_selected_changed)


func _build_styles() -> void:
	_sty_env = StyleBoxFlat.new()
	_sty_env.bg_color      = Color(0.96, 0.91, 0.78, 1)
	_sty_env.border_color  = Color(0.65, 0.48, 0.30, 1)
	_sty_env.set_border_width_all(2)
	_sty_env.set_corner_radius_all(3)
	_sty_env.shadow_color  = Color(0, 0, 0, 0.32)
	_sty_env.shadow_size   = 10
	_sty_env.shadow_offset = Vector2(3, 5)

	_sty_env_bk = StyleBoxFlat.new()
	_sty_env_bk.bg_color      = Color(0.88, 0.82, 0.66, 1)
	_sty_env_bk.border_color  = Color(0.55, 0.38, 0.22, 1)
	_sty_env_bk.set_border_width_all(2)
	_sty_env_bk.set_corner_radius_all(3)
	_sty_env_bk.shadow_color  = Color(0, 0, 0, 0.32)
	_sty_env_bk.shadow_size   = 10
	_sty_env_bk.shadow_offset = Vector2(3, 5)

	_sty_nb = StyleBoxFlat.new()
	_sty_nb.bg_color      = Color(0.96, 0.93, 0.85, 1)
	_sty_nb.border_color  = Color(0.60, 0.44, 0.28, 1)
	_sty_nb.set_border_width_all(2)
	_sty_nb.set_corner_radius_all(4)
	_sty_nb.shadow_color  = Color(0, 0, 0, 0.28)
	_sty_nb.shadow_size   = 8
	_sty_nb.shadow_offset = Vector2(2, 4)
	notebook_node.add_theme_stylebox_override("panel", _sty_nb)


func _build_notebook() -> void:
	_nb_page = 0
	notebook_content.text = _NB_PAGES[0]
	nb_prev.text = ""
	nb_next.text = "▶" if _NB_PAGES.size() > 1 else ""


# ── public API ────────────────────────────────────────────────────────────────

func bind_player(player: Node) -> void:
	_player = player


func set_prompt(text: String) -> void:
	prompt_label.text = text


func set_nearby_interactable(target) -> void:
	_nearby_interactable = target


func open_inspection() -> void:
	if _showing_inspection or GameState.mail_bag.is_empty():
		return
	_showing_inspection = true
	inspection.visible  = true
	_rebuild_envelopes()
	if _player and _player.has_method("set_input_active"):
		_player.set_input_active(false)


# ── input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inspect_mail"):
		_toggle_inspection()
		return

	if not _showing_inspection:
		return

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_try_start_drag(event.global_position)
				else:
					_end_drag(event.global_position)
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					_try_flip_at(event.global_position)
					_try_notebook_page(event.global_position)

	elif event is InputEventMouseMotion:
		if _drag_card != null:
			_drag_card.global_position = event.global_position - _drag_offset
			_update_slot_highlight(event.global_position)
			get_viewport().set_input_as_handled()


func _toggle_inspection() -> void:
	if GameState.mail_bag.is_empty() and not _showing_inspection:
		return
	if _showing_inspection:
		_showing_inspection = false
		_drag_card = null
		if _player and _player.has_method("set_input_active"):
			_player.set_input_active(true)
		if _slot_panel:
			var tw := create_tween()
			tw.tween_property(_slot_panel, "modulate:a", 0.0, 0.15)
		_slide_envelopes_out(func():
			if not _showing_inspection:
				inspection.visible = false
		)
	else:
		_showing_inspection = true
		inspection.visible  = true
		_rebuild_envelopes()
		if _player and _player.has_method("set_input_active"):
			_player.set_input_active(false)


# ── envelopes ─────────────────────────────────────────────────────────────────

func _rebuild_envelopes() -> void:
	for child in envelopes_layer.get_children():
		child.queue_free()
	_cards.clear()
	_slot_panel = null
	var bag := GameState.mail_bag
	for i in bag.size():
		var card := _make_envelope(bag[i], i, bag.size())
		envelopes_layer.add_child(card)
		_cards.append(card)
	_build_delivery_slot()
	_slide_envelopes_in()
	_update_pager_hint()


func _rest_position(index: int, total: int) -> Vector2:
	var vp    := get_viewport().get_visible_rect().size
	var ew    := 268.0
	var gap   := 28.0
	var total_w := total * ew + (total - 1) * gap
	var x     := (vp.x - total_w) * 0.5 + index * (ew + gap)
	var y     := vp.y * 0.62
	return Vector2(x, y)


func _envelope_tilt(id: String) -> float:
	return ((id.hash() % 13) - 6) * 0.75


func _make_envelope(letter, index: int, total: int) -> Panel:
	const EW := 268.0
	const EH := 172.0
	var card := Panel.new()
	card.custom_minimum_size = Vector2(EW, EH)
	card.size                = Vector2(EW, EH)
	card.pivot_offset        = Vector2(EW * 0.5, EH * 0.5)
	card.mouse_filter        = Control.MOUSE_FILTER_PASS
	card.set_meta("letter",       letter)
	card.set_meta("showing_back", false)

	var rest: Vector2 = _saved_positions.get(letter.id, _rest_position(index, total))
	card.position         = rest
	card.rotation_degrees = _envelope_tilt(letter.id)

	# Front
	var front := Control.new()
	front.name = "Front"
	front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front.mouse_filter = Control.MOUSE_FILTER_PASS
	var fv := VBoxContainer.new()
	fv.name = "VBox"
	fv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fv.offset_left = 16; fv.offset_top = 14; fv.offset_right = -16; fv.offset_bottom = -14
	fv.add_theme_constant_override("separation", 6)
	var s := Label.new(); s.name = "Sender"
	s.autowrap_mode = TextServer.AUTOWRAP_WORD
	s.add_theme_font_size_override("font_size", 11)
	s.add_theme_color_override("font_color", Color(0.40, 0.28, 0.18, 1))
	var a := Label.new(); a.name = "Address"
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a.autowrap_mode = TextServer.AUTOWRAP_WORD
	a.add_theme_font_size_override("font_size", 19)
	a.add_theme_color_override("font_color", Color(0.18, 0.12, 0.08, 1))
	var r := Label.new(); r.name = "Recipient"
	r.autowrap_mode = TextServer.AUTOWRAP_WORD
	r.add_theme_font_size_override("font_size", 13)
	r.add_theme_color_override("font_color", Color(0.35, 0.22, 0.15, 1))
	fv.add_child(s); fv.add_child(a); fv.add_child(r)
	front.add_child(fv)

	# Back
	var back := Control.new()
	back.name = "Back"; back.visible = false
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_PASS
	var bv := VBoxContainer.new()
	bv.name = "VBox"
	bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bv.offset_left = 18; bv.offset_top = 16; bv.offset_right = -18; bv.offset_bottom = -16
	bv.add_theme_constant_override("separation", 8)
	var ch := Label.new()
	ch.text = "— scrawled on the back —"
	ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ch.add_theme_font_size_override("font_size", 12)
	ch.add_theme_color_override("font_color", Color(0.42, 0.30, 0.20, 1))
	var cl := Label.new(); cl.name = "Clue"
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD
	cl.add_theme_font_size_override("font_size", 14)
	cl.add_theme_color_override("font_color", Color(0.18, 0.12, 0.08, 1))
	bv.add_child(ch); bv.add_child(cl)
	back.add_child(bv)

	card.add_child(front)
	card.add_child(back)
	_apply_face(card, letter, false)
	return card


func _apply_face(card: Panel, letter, showing_back: bool) -> void:
	var front: Control = card.get_node("Front")
	var back:  Control = card.get_node("Back")
	front.visible = not showing_back
	back.visible  = showing_back
	if showing_back:
		card.add_theme_stylebox_override("panel", _sty_env_bk)
		back.get_node("VBox/Clue").text = letter.clue_text
	else:
		card.add_theme_stylebox_override("panel", _sty_env)
		front.get_node("VBox/Sender").text    = "%s\n%s" % [letter.sender_name, letter.sender_address]
		front.get_node("VBox/Address").text   = letter.address_line
		front.get_node("VBox/Recipient").text = letter.recipient_description


# ── delivery slot ─────────────────────────────────────────────────────────────

func _build_delivery_slot() -> void:
	if _slot_panel != null:
		_slot_panel.queue_free()
		_slot_panel = null
	if _nearby_interactable == null:
		return
	_camera = get_viewport().get_camera_3d()
	if _camera == null:
		return

	# Project a point just above the mailbox into screen space.
	var world_pos: Vector3 = _nearby_interactable.global_position + Vector3(0, 2.0, 0)
	var screen_pos: Vector2 = _camera.unproject_position(world_pos)

	var house_lbl: String = _nearby_interactable.house_label \
		if "house_label" in _nearby_interactable else "Mailbox"
	_slot_panel = _make_slot_panel(house_lbl, screen_pos)
	envelopes_layer.add_child(_slot_panel)


func _make_slot_panel(house_lbl: String, screen_pos: Vector2) -> Panel:
	const SW := 124.0
	const SH :=  66.0
	var p := Panel.new()
	p.custom_minimum_size = Vector2(SW, SH)
	p.size                = Vector2(SW, SH)
	p.position            = screen_pos - Vector2(SW, SH) * 0.5
	p.mouse_filter        = Control.MOUSE_FILTER_PASS

	var sty_idle := StyleBoxFlat.new()
	sty_idle.bg_color     = Color(0.14, 0.10, 0.06, 0.80)
	sty_idle.border_color = Color(0.70, 0.50, 0.16, 1)
	sty_idle.set_border_width_all(2)
	sty_idle.set_corner_radius_all(8)

	var sty_hot := StyleBoxFlat.new()
	sty_hot.bg_color     = Color(0.22, 0.16, 0.06, 0.90)
	sty_hot.border_color = Color(0.96, 0.78, 0.22, 1)
	sty_hot.set_border_width_all(3)
	sty_hot.set_corner_radius_all(8)
	sty_hot.shadow_color = Color(0.96, 0.78, 0.22, 0.55)
	sty_hot.shadow_size  = 14

	p.add_theme_stylebox_override("panel", sty_idle)
	p.set_meta("sty_idle", sty_idle)
	p.set_meta("sty_hot",  sty_hot)

	var icon := Label.new()
	icon.text = "✉"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	icon.offset_top = 8; icon.offset_bottom = 40
	icon.add_theme_font_size_override("font_size", 20)
	icon.add_theme_color_override("font_color", Color(0.88, 0.82, 0.65, 1))

	var lbl := Label.new()
	lbl.text = house_lbl
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.offset_top = -24; lbl.offset_bottom = -5
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.88, 0.84, 0.70, 1))

	p.add_child(icon)
	p.add_child(lbl)
	return p


func _update_slot_highlight(mouse_pos: Vector2) -> void:
	if _slot_panel == null:
		return
	var hot: bool = _hit(_slot_panel, mouse_pos)
	_slot_panel.add_theme_stylebox_override("panel",
		_slot_panel.get_meta("sty_hot") if hot else _slot_panel.get_meta("sty_idle"))


# ── animations ────────────────────────────────────────────────────────────────

func _slide_envelopes_in() -> void:
	var vph := get_viewport().get_visible_rect().size.y
	for i in _cards.size():
		var card = _cards[i]
		var rest: Vector2 = card.position
		card.position = Vector2(rest.x, vph + 220)
		var tw := create_tween()
		tw.tween_property(card, "position", rest, 0.28 + i * 0.055)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _slide_envelopes_out(on_done: Callable) -> void:
	var vph := get_viewport().get_visible_rect().size.y
	if _cards.is_empty():
		on_done.call()
		return
	var tw := create_tween()
	tw.set_parallel(true)
	for i in _cards.size():
		tw.tween_property(_cards[i], "position:y", vph + 220, 0.20 + i * 0.03)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(on_done)


# ── drag ──────────────────────────────────────────────────────────────────────

func _try_start_drag(pos: Vector2) -> void:
	var children := envelopes_layer.get_children()
	for i in range(children.size() - 1, -1, -1):
		var card = children[i]
		if card == _slot_panel:
			continue
		if _hit(card, pos):
			_drag_card   = card
			_drag_offset = pos - card.global_position
			envelopes_layer.move_child(card, -1)
			var tw := create_tween()
			tw.tween_property(card, "scale", Vector2(1.04, 1.04), 0.08)
			return


func _end_drag(pos: Vector2) -> void:
	if _drag_card == null:
		return
	# Drop onto mailbox slot → deliver
	if _slot_panel != null and _hit(_slot_panel, pos):
		_deliver_dragged()
		return
	# Drag to bottom edge → dismiss to bag
	var vph := get_viewport().get_visible_rect().size.y
	if pos.y > vph * 0.85:
		_dismiss_card(_drag_card)
	else:
		var tw := create_tween()
		tw.tween_property(_drag_card, "scale", Vector2.ONE, 0.14)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_saved_positions[_drag_card.get_meta("letter").id] = _drag_card.position
	_drag_card = null


func _deliver_dragged() -> void:
	if _drag_card == null or _nearby_interactable == null or _player == null:
		_drag_card = null
		return
	var letter = _drag_card.get_meta("letter")
	# Point GameState at this letter so mailbox.interact delivers the right one.
	var idx := GameState.mail_bag.find(letter)
	if idx >= 0:
		GameState.selected_index = idx
	# Fly to slot then trigger mailbox.
	var target: Vector2 = _slot_panel.global_position + _slot_panel.size * 0.5 \
		- _drag_card.size * 0.5
	var tw := create_tween()
	tw.tween_property(_drag_card, "position", target, 0.18)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_drag_card, "scale", Vector2.ZERO, 0.14)\
		.set_trans(Tween.TRANS_CUBIC)
	var mb = _nearby_interactable
	var pl = _player
	tw.tween_callback(func(): mb.interact(pl))
	_drag_card = null


func _dismiss_card(card: Panel) -> void:
	var vph := get_viewport().get_visible_rect().size.y
	var tw  := create_tween()
	tw.tween_property(card, "position:y", vph + 220, 0.22)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(card.queue_free)
	_cards.erase(card)
	_drag_card = null
	_update_pager_hint()


func _hit(card: Control, pos: Vector2) -> bool:
	return Rect2(card.global_position, card.size * card.scale).has_point(pos)


# ── flip ──────────────────────────────────────────────────────────────────────

func _try_flip_at(pos: Vector2) -> void:
	var children := envelopes_layer.get_children()
	for i in range(children.size() - 1, -1, -1):
		var card = children[i]
		if card != _slot_panel and _hit(card, pos):
			_flip_envelope(card)
			return


func _flip_envelope(card: Panel) -> void:
	var tw := create_tween()
	tw.tween_property(card, "scale:x", 0.0, 0.10).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func():
		var flipped: bool = not card.get_meta("showing_back", false)
		card.set_meta("showing_back", flipped)
		_apply_face(card, card.get_meta("letter"), flipped)
	)
	tw.tween_property(card, "scale:x", 1.0, 0.10).set_trans(Tween.TRANS_CUBIC)


# ── notebook ──────────────────────────────────────────────────────────────────

func _try_notebook_page(pos: Vector2) -> void:
	if not notebook_node.visible:
		return
	var nb_rect := Rect2(notebook_node.global_position, notebook_node.size)
	if not nb_rect.has_point(pos):
		return
	var mid_x := notebook_node.global_position.x + notebook_node.size.x * 0.5
	_nb_page = wrapi(_nb_page + (1 if pos.x >= mid_x else -1), 0, _NB_PAGES.size())
	notebook_content.text = _NB_PAGES[_nb_page]
	nb_prev.text = "◀" if _nb_page > 0 else ""
	nb_next.text = "▶" if _nb_page < _NB_PAGES.size() - 1 else ""


# ── pager hint ────────────────────────────────────────────────────────────────

func _update_pager_hint() -> void:
	var bag := GameState.mail_bag
	if bag.is_empty():
		pager_hint.text = "Bag empty"
		return
	if _nearby_interactable != null:
		var lbl: String = _nearby_interactable.house_label \
			if "house_label" in _nearby_interactable else ""
		var dest := "  (" + lbl + ")" if lbl else ""
		pager_hint.text = "Drag a letter onto the slot to deliver%s   |   right-click to flip" % dest
	else:
		pager_hint.text = "Tab to close   |   right-click to flip   |   walk near a mailbox to deliver"


# ── signal handlers ───────────────────────────────────────────────────────────

func _on_selected_changed(_index: int, _letter) -> void:
	pass  # selection no longer drives the overlay UI


func _on_day_started(_day: int, letters: Array) -> void:
	for child in stamp_row.get_children():
		child.queue_free()
	for _i in letters.size():
		stamp_row.add_child(_make_stamp_slot())


func _on_letter_delivered(_letter, _house_id: String, was_correct: bool) -> void:
	for slot in stamp_row.get_children():
		if slot.get_meta("delivered", false) == false:
			slot.set_meta("delivered", true)
			var mark: Label = slot.get_node("Mark")
			mark.text = "✓" if was_correct else "?"
			mark.add_theme_color_override("font_color",
				Color(0.18, 0.55, 0.20) if was_correct else Color(0.55, 0.40, 0.18))
			break
	_saved_positions.erase(_letter.id)
	if _showing_inspection:
		_rebuild_envelopes()


func _on_day_ended(day: int, results: Array) -> void:
	var correct := 0
	for r in results:
		if r["delivered"] and r["correct"]:
			correct += 1
	summary_label.text = "Day %d complete\n\n%d / %d letters delivered correctly\n\nESC to release mouse" % [
		day, correct, results.size()
	]
	summary.visible     = true
	inspection.visible  = false
	_showing_inspection = false
	if _player and _player.has_method("set_input_active"):
		_player.set_input_active(false)


# ── stamp slot ────────────────────────────────────────────────────────────────

func _make_stamp_slot() -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(40, 48)
	var sb := StyleBoxFlat.new()
	sb.bg_color     = Color(0.96, 0.91, 0.78, 1)
	sb.border_color = Color(0.55, 0.30, 0.20, 1)
	sb.border_width_left = 2; sb.border_width_right  = 2
	sb.border_width_top  = 2; sb.border_width_bottom = 2
	sb.corner_radius_top_left    = 2; sb.corner_radius_top_right    = 2
	sb.corner_radius_bottom_left = 2; sb.corner_radius_bottom_right = 2
	slot.add_theme_stylebox_override("panel", sb)
	var mark := Label.new()
	mark.name = "Mark"; mark.text = ""
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.add_theme_font_size_override("font_size", 28)
	slot.add_child(mark)
	slot.set_meta("delivered", false)
	return slot
