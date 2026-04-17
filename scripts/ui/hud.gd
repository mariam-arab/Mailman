extends CanvasLayer
## HUD for Special Delivery — visual redesign.
## Tab opens the mail overlay: 3D world dims, themed envelopes fan at the bottom.
## Click an envelope to pull it up into the workspace (max 2 at once).
## Drag any envelope onto a mailbox slot to deliver. Right-click to flip.

@onready var stamp_row:        HBoxContainer = $StampRow
@onready var stamp_counter:    Label         = $StampCounter
@onready var prompt_label:     Label         = $PromptLabel
@onready var inspection:       Control       = $Inspection
@onready var envelopes_layer:  Control       = $Inspection/EnvelopesLayer
@onready var notebook_node:    Panel         = $Inspection/Notebook
@onready var notebook_content: Label         = $Inspection/Notebook/Content
@onready var nb_prev:          Label         = $Inspection/Notebook/PagePrev
@onready var nb_next:          Label         = $Inspection/Notebook/PageNext
@onready var tape_bar:         Panel         = $Inspection/TapeBar
@onready var pager_hint:       Label         = $Inspection/TapeBar/PagerHint
@onready var summary:          Control       = $Summary
@onready var summary_label:    Label         = $Summary/Center/SummaryLabel
@onready var dialogue_panel:   Panel         = $DialoguePanel
@onready var dialogue_speaker: Label         = $DialoguePanel/Speaker
@onready var dialogue_text:    Label         = $DialoguePanel/Text
@onready var dialogue_hint:    Label         = $DialoguePanel/Hint

# -- envelope themes -----------------------------------------------------------

enum EnvTheme { CREAM, KRAFT, AIRMAIL, OFFICIAL, SEALED, AGED }

const THEME_DATA := {
	EnvTheme.CREAM: {
		"bg":         Color(0.97, 0.93, 0.85, 1),
		"border":     Color(0.68, 0.52, 0.32, 1),
		"ink":        Color(0.22, 0.14, 0.08, 1),
		"stamp_bg":   Color(0.28, 0.58, 0.32, 1),
		"stamp_text": "POSTES\nCANADA",
		"tracker":    Color(0.28, 0.62, 0.35, 1),
	},
	EnvTheme.KRAFT: {
		"bg":         Color(0.74, 0.60, 0.38, 1),
		"border":     Color(0.52, 0.36, 0.16, 1),
		"ink":        Color(0.14, 0.08, 0.02, 1),
		"stamp_bg":   Color(0.85, 0.65, 0.18, 1),
		"stamp_text": "CANADA\n5c",
		"tracker":    Color(0.85, 0.65, 0.18, 1),
	},
	EnvTheme.AIRMAIL: {
		"bg":         Color(0.92, 0.96, 1.0, 1),
		"border":     Color(0.22, 0.38, 0.75, 1),
		"ink":        Color(0.10, 0.18, 0.52, 1),
		"stamp_bg":   Color(0.78, 0.18, 0.18, 1),
		"stamp_text": "CANADA\n8c",
		"tracker":    Color(0.25, 0.42, 0.78, 1),
	},
	EnvTheme.OFFICIAL: {
		"bg":         Color(0.98, 0.97, 0.94, 1),
		"border":     Color(0.48, 0.42, 0.32, 1),
		"ink":        Color(0.18, 0.14, 0.10, 1),
		"stamp_bg":   Color(0.78, 0.22, 0.22, 1),
		"stamp_text": "CANADA\n6c",
		"tracker":    Color(0.78, 0.22, 0.22, 1),
	},
	EnvTheme.SEALED: {
		"bg":         Color(0.97, 0.93, 0.87, 1),
		"border":     Color(0.52, 0.32, 0.18, 1),
		"ink":        Color(0.22, 0.14, 0.08, 1),
		"stamp_bg":   Color(0.52, 0.28, 0.62, 1),
		"stamp_text": "CANADA\n4c",
		"tracker":    Color(0.52, 0.28, 0.62, 1),
		"seal_color": Color(0.72, 0.14, 0.14, 1),
	},
	EnvTheme.AGED: {
		"bg":         Color(0.88, 0.82, 0.62, 1),
		"border":     Color(0.48, 0.36, 0.18, 1),
		"ink":        Color(0.24, 0.16, 0.08, 1),
		"stamp_bg":   Color(0.62, 0.38, 0.22, 1),
		"stamp_text": "CANADA\n3c",
		"tracker":    Color(0.62, 0.38, 0.22, 1),
	},
}

func _letter_theme(letter) -> int:
	match letter.id:
		"letter_01": return EnvTheme.KRAFT
		"letter_02": return EnvTheme.OFFICIAL
		"letter_03": return EnvTheme.CREAM
		"letter_04": return EnvTheme.AIRMAIL
		"letter_05": return EnvTheme.SEALED
		"letter_06": return EnvTheme.AGED
		_:           return EnvTheme.CREAM


# -- state ---------------------------------------------------------------------

var _player: Node              = null
var _showing_inspection: bool  = false

var _dialogue_lines: Array     = []
var _dialogue_idx: int         = 0
var _nearby_interactable       = null
var _cards: Array              = []
var _delivered_count: int      = 0

const MAX_PULLED                := 2
const DRAG_THRESHOLD            := 8.0
var _pull_cards: Array          = []
var _press_card                 = null
var _press_pos: Vector2         = Vector2.ZERO
var _is_dragging: bool          = false
var _press_was_in_slot: bool    = false

var _drag_card                  = null
var _drag_offset: Vector2       = Vector2.ZERO

var _slot_panels: Dictionary   = {}
var _camera: Camera3D          = null

var _delivered_letters: Dictionary = {}
var _slotted_cards:     Dictionary = {}


const _NB_PAGES := [
	"Today's Route\n\n311 - L. Hughes\n312 - Thomas (Tom)\n313 - K. Lyne\n314 - J. Sydney\n315 - M. Hughes\n316 - Linda M.",
	"How to Deliver\n\nWalk near a mailbox.\nA slot appears above it.\n\nOpen your bag (Tab),\nthen drag an envelope\nonto the slot.",
	"Tips\n\nRight-click an envelope\nto open it and read\nthe message inside.\n\nDrag to the bottom\nedge to put a letter\nback in your bag.",
]
var _nb_page: int = 0

var _sty_nb: StyleBoxFlat


# -- init ----------------------------------------------------------------------

func _ready() -> void:
	add_to_group("hud")
	_build_styles()
	_build_vignette()
	_build_notebook()
	inspection.visible     = false
	summary.visible        = false
	dialogue_panel.visible = false
	prompt_label.text      = ""
	stamp_counter.text     = ""
	GameState.day_started.connect(_on_day_started)
	GameState.day_ended.connect(_on_day_ended)
	GameState.letter_delivered.connect(_on_letter_delivered)
	GameState.selected_letter_changed.connect(_on_selected_changed)


func _build_styles() -> void:
	_sty_nb = StyleBoxFlat.new()
	_sty_nb.bg_color      = Color(0.94, 0.89, 0.74, 1)
	_sty_nb.border_color  = Color(0.58, 0.42, 0.22, 1)
	_sty_nb.set_border_width_all(2)
	_sty_nb.set_corner_radius_all(4)
	_sty_nb.shadow_color  = Color(0, 0, 0, 0.28)
	_sty_nb.shadow_size   = 8
	_sty_nb.shadow_offset = Vector2(2, 4)
	notebook_node.add_theme_stylebox_override("panel", _sty_nb)




func _build_vignette() -> void:
	# Dark-to-transparent gradient covering bottom 40% of screen,
	# giving envelopes a dark backdrop to pop against.
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.42))

	var tex := GradientTexture2D.new()
	tex.gradient  = grad
	tex.fill      = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to   = Vector2(0.5, 1.0)

	var tr := TextureRect.new()
	tr.texture      = tex
	tr.anchor_left   = 0.0
	tr.anchor_top    = 0.60   # covers bottom 40 % of screen
	tr.anchor_right  = 1.0
	tr.anchor_bottom = 1.0
	tr.offset_left   = 0; tr.offset_top    = 0
	tr.offset_right  = 0; tr.offset_bottom = 0
	tr.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode  = TextureRect.STRETCH_SCALE
	tr.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	inspection.add_child(tr)
	inspection.move_child(tr, 2)   # after DimRect(0), StreetName(1); before EnvelopesLayer


func _build_notebook() -> void:
	_nb_page = 0
	notebook_content.text = _NB_PAGES[0]
	nb_prev.text = ""
	nb_next.text = ">" if _NB_PAGES.size() > 1 else ""


# -- public API ----------------------------------------------------------------

func bind_player(player: Node) -> void:
	_player = player


func set_prompt(text: String) -> void:
	if _showing_inspection and text == "Tab — open bag to deliver":
		prompt_label.text = "drag envelope into a mail slot to deliver"
	else:
		prompt_label.text = text


func set_nearby_interactable(target) -> void:
	_nearby_interactable = target


func open_inspection() -> void:
	if _showing_inspection:
		return
	if GameState.mail_bag.is_empty() and _delivered_letters.is_empty():
		return
	_showing_inspection = true
	inspection.visible  = true
	_rebuild_envelopes()


func open_dialogue(lines: Array, speaker_name: String = "") -> void:
	_dialogue_lines = lines
	_dialogue_idx   = 0
	dialogue_speaker.text = speaker_name
	dialogue_panel.visible = true
	_show_dialogue_line()


func _show_dialogue_line() -> void:
	dialogue_text.text = _dialogue_lines[_dialogue_idx]
	var last: bool = _dialogue_idx >= _dialogue_lines.size() - 1
	dialogue_hint.text = "E - close" if last else "E - continue"


func _close_dialogue() -> void:
	_dialogue_lines = []
	var tw := create_tween()
	tw.tween_property(dialogue_panel, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func():
		dialogue_panel.visible = false
		dialogue_panel.modulate.a = 1.0
	)


# -- input ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _dialogue_lines.size() > 0 and event.is_action_pressed("interact"):
		_dialogue_idx += 1
		if _dialogue_idx >= _dialogue_lines.size():
			_close_dialogue()
		else:
			_show_dialogue_line()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("inspect_mail"):
		_toggle_inspection()
		return

	if not _showing_inspection:
		return

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_on_left_press(event.global_position)
				else:
					_on_left_release(event.global_position)
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					_try_flip_at(event.global_position)
					_try_notebook_page(event.global_position)

	elif event is InputEventMouseMotion:
		if _press_card != null and not _is_dragging:
			if event.global_position.distance_to(_press_pos) > DRAG_THRESHOLD:
				_start_drag()
		if _is_dragging and _drag_card != null:
			_drag_card.global_position = event.global_position - _drag_offset
			_update_slot_highlight(event.global_position)
			get_viewport().set_input_as_handled()


func _start_drag() -> void:
	_is_dragging = true
	_drag_card   = _press_card
	_drag_offset = _press_pos - _press_card.global_position
	if _press_was_in_slot:
		var mb = _drag_card.get_meta("slot_mailbox", null)
		if mb:
			_slotted_cards.erase(mb)
		_drag_card.set_meta("in_slot", false)
		_drag_card.set_meta("slot_mailbox", null)
	_drag_card.set_meta("was_in_slot", _press_was_in_slot)
	_pull_cards.erase(_drag_card)
	envelopes_layer.move_child(_drag_card, -1)
	var tw := create_tween()
	tw.tween_property(_drag_card, "scale", Vector2(1.04, 1.04), 0.08)


func _on_left_press(pos: Vector2) -> void:
	var children := envelopes_layer.get_children()
	for i in range(children.size() - 1, -1, -1):
		var card = children[i]
		if _slot_panels.values().has(card):
			continue
		if _hit(card, pos):
			_press_card        = card
			_press_pos         = pos
			_is_dragging       = false
			_press_was_in_slot = card.get_meta("in_slot", false)
			return


func _on_left_release(pos: Vector2) -> void:
	if _is_dragging and _drag_card != null:
		_end_drag(pos)
	elif _press_card != null:
		_on_card_click(_press_card)
	_press_card  = null
	_is_dragging = false


func _on_card_click(card: Panel) -> void:
	if card.get_meta("in_slot", false):
		return
	_toggle_pull_card(card)


func _toggle_inspection() -> void:
	if GameState.mail_bag.is_empty() and _delivered_letters.is_empty() and not _showing_inspection:
		return
	if _showing_inspection:
		_showing_inspection = false
		_drag_card   = null
		_press_card  = null
		_is_dragging = false
		_pull_cards.clear()
		for mb in _slot_panels:
			var sp: Panel = _slot_panels[mb]
			var tw := create_tween()
			tw.tween_property(sp, "modulate:a", 0.0, 0.15)
		_slot_panels.clear()
		for mb in _slotted_cards:
			var sc: Panel = _slotted_cards[mb]
			if is_instance_valid(sc):
				var tw := create_tween()
				tw.tween_property(sc, "modulate:a", 0.0, 0.15)
				tw.tween_callback(sc.queue_free)
		_slotted_cards.clear()
		_slide_envelopes_out(func():
			if not _showing_inspection:
				inspection.visible = false
		)
	else:
		_showing_inspection = true
		inspection.visible  = true
		_rebuild_envelopes()


# -- envelopes -----------------------------------------------------------------

func _rebuild_envelopes() -> void:
	for child in envelopes_layer.get_children():
		child.queue_free()
	_cards.clear()
	_pull_cards.clear()
	_slot_panels.clear()
	_slotted_cards.clear()
	var bag := GameState.mail_bag
	for i in bag.size():
		var card := _make_envelope(bag[i], i, bag.size())
		envelopes_layer.add_child(card)
		_cards.append(card)
	for letter in _delivered_letters:
		var card := _make_envelope(letter, 0, 0)
		card.set_meta("in_slot", true)
		card.set_meta("slot_mailbox", _delivered_letters[letter])
		card.scale    = Vector2(0.55, 0.55)
		card.modulate = Color(1, 1, 1, 0)
		card.position = Vector2(-2000.0, -2000.0)
		envelopes_layer.add_child(card)
		envelopes_layer.move_child(card, 0)
		_slotted_cards[_delivered_letters[letter]] = card
	_slide_envelopes_in()
	_update_pager_hint()


# -- fan layout ----------------------------------------------------------------

func _fan_position(index: int, total: int) -> Vector2:
	var vp   := get_viewport().get_visible_rect().size
	const EW := 200.0
	const EH := 125.0
	# Step sized so the fan fills ~90 % of viewport width, capped for readability.
	var max_step := (vp.x * 0.90 - EW) / maxf(total - 1, 1)
	var step     := clampf(max_step, 55.0, 110.0)
	var total_w  := EW + (total - 1) * step
	var x        := (vp.x - total_w) * 0.5 + index * step
	# Show ~70 px of card above the tape bar; rest stays below screen edge.
	var y        := vp.y - 46.0 - 70.0
	return Vector2(x, y)


func _fan_tilt(_index: int, _total: int) -> float:
	return 0.0


func _pulled_position(pull_index: int, total_pulled: int) -> Vector2:
	var vp   := get_viewport().get_visible_rect().size
	const EW := 200.0
	const GAP := 36.0
	var total_w := total_pulled * EW + (total_pulled - 1) * GAP
	var x    := (vp.x - total_w) * 0.5 + pull_index * (EW + GAP)
	var y    := vp.y * 0.20
	return Vector2(x, y)


func _toggle_pull_card(card: Panel) -> void:
	if _pull_cards.has(card):
		_pull_cards.erase(card)
		var idx := _cards.find(card)
		if idx >= 0:
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(card, "position", _fan_position(idx, _cards.size()), 0.24) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "rotation_degrees", _fan_tilt(idx, _cards.size()), 0.20)
		_reposition_pull_cards()
	else:
		if _pull_cards.size() >= MAX_PULLED:
			var old: Panel = _pull_cards[0]
			_pull_cards.erase(old)
			var oi := _cards.find(old)
			if oi >= 0:
				var ot := create_tween()
				ot.set_parallel(true)
				ot.tween_property(old, "position", _fan_position(oi, _cards.size()), 0.18) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				ot.tween_property(old, "rotation_degrees", _fan_tilt(oi, _cards.size()), 0.16)
		_pull_cards.append(card)
		envelopes_layer.move_child(card, -1)
		_reposition_pull_cards()


func _reposition_pull_cards() -> void:
	for i in _pull_cards.size():
		var card = _pull_cards[i]
		var dest := _pulled_position(i, _pull_cards.size())
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(card, "position", dest, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "rotation_degrees", 0.0, 0.18)


# -- envelope construction -----------------------------------------------------

func _make_envelope(letter, index: int, total: int) -> Panel:
	const EW := 200.0
	const EH := 125.0

	var theme_id := _letter_theme(letter)
	var td: Dictionary = THEME_DATA[theme_id]

	var card := Panel.new()
	card.custom_minimum_size = Vector2(EW, EH)
	card.size                = Vector2(EW, EH)
	card.pivot_offset        = Vector2(EW * 0.5, EH * 0.5)
	card.mouse_filter        = Control.MOUSE_FILTER_PASS
	card.set_meta("letter",       letter)
	card.set_meta("showing_back", false)
	card.set_meta("in_slot",      false)
	card.set_meta("slot_mailbox", null)
	card.set_meta("was_in_slot",  false)
	card.set_meta("theme_id",     theme_id)

	card.position         = _fan_position(index, total)
	card.rotation_degrees = _fan_tilt(index, total)

	var sty_f := StyleBoxFlat.new()
	sty_f.bg_color      = td["bg"]
	sty_f.border_color  = td["border"]
	sty_f.set_border_width_all(2)
	sty_f.set_corner_radius_all(4)
	sty_f.shadow_color  = Color(0, 0, 0, 0.35)
	sty_f.shadow_size   = 14
	sty_f.shadow_offset = Vector2(3, 6)
	card.add_theme_stylebox_override("panel", sty_f)
	card.set_meta("sty_front", sty_f)

	var sty_b := StyleBoxFlat.new()
	sty_b.bg_color      = td["bg"].darkened(0.08)
	sty_b.border_color  = td["border"]
	sty_b.set_border_width_all(2)
	sty_b.set_corner_radius_all(4)
	sty_b.shadow_color  = Color(0, 0, 0, 0.35)
	sty_b.shadow_size   = 14
	sty_b.shadow_offset = Vector2(3, 6)
	card.set_meta("sty_back", sty_b)

	if theme_id == EnvTheme.AIRMAIL:
		_add_airmail_stripes(card, EW, EH)

	var front := Control.new()
	front.name        = "Front"
	front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front.mouse_filter = Control.MOUSE_FILTER_PASS

	var sender := Label.new()
	sender.name          = "Sender"
	sender.position      = Vector2(16, 12)
	sender.size          = Vector2(160, 36)
	sender.autowrap_mode = TextServer.AUTOWRAP_WORD
	sender.add_theme_font_size_override("font_size", 9)
	sender.add_theme_color_override("font_color", td["ink"].lerp(Color.WHITE, 0.38))

	var addr := Label.new()
	addr.name                 = "Address"
	addr.position             = Vector2(14, 60)
	addr.size                 = Vector2(EW - 28.0, 62.0)
	addr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	addr.autowrap_mode        = TextServer.AUTOWRAP_WORD
	addr.add_theme_font_size_override("font_size", 17)
	addr.add_theme_color_override("font_color", td["ink"])

	var recip := Label.new()
	recip.name                 = "Recipient"
	recip.position             = Vector2(14, 128)
	recip.size                 = Vector2(EW - 28.0, 24.0)
	recip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recip.add_theme_font_size_override("font_size", 11)
	recip.add_theme_color_override("font_color", td["ink"].lerp(Color.WHITE, 0.28))

	front.add_child(sender)
	front.add_child(addr)
	front.add_child(recip)

	var back := Control.new()
	back.name         = "Back"
	back.visible      = false
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_PASS

	var bv := VBoxContainer.new()
	bv.name = "VBox"
	bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bv.offset_left = 18; bv.offset_top = 16; bv.offset_right = -18; bv.offset_bottom = -16
	bv.add_theme_constant_override("separation", 8)

	var ch := Label.new()
	ch.text                 = "-- scrawled on the back --"
	ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ch.add_theme_font_size_override("font_size", 10)
	ch.add_theme_color_override("font_color", td["ink"].lerp(Color.WHITE, 0.48))

	var cl := Label.new()
	cl.name          = "Clue"
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD
	cl.add_theme_font_size_override("font_size", 11)
	cl.add_theme_color_override("font_color", td["ink"])

	bv.add_child(ch)
	bv.add_child(cl)
	back.add_child(bv)

	card.add_child(front)
	card.add_child(back)

	_add_stamp(card, td["stamp_bg"], td["stamp_text"], EW)
	if theme_id == EnvTheme.SEALED:
		_add_wax_seal(card, td["seal_color"], EH)

	_apply_face(card, letter, false)
	return card


func _add_airmail_stripes(card: Panel, _ew: float, eh: float) -> void:
	const SW := 5.0
	var colors := [
		Color(0.18, 0.26, 0.72, 1),
		Color(0.92, 0.96, 1.0, 0.9),
		Color(0.78, 0.14, 0.14, 1),
	]
	for i in 3:
		var cr := ColorRect.new()
		cr.color        = colors[i]
		cr.position     = Vector2(i * SW, 0.0)
		cr.size         = Vector2(SW, eh)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cr)
	var par := Label.new()
	par.position     = Vector2(3.0 * SW + 5.0, 9.0)
	par.mouse_filter = Control.MOUSE_FILTER_IGNORE
	par.add_theme_font_size_override("font_size", 9)
	par.add_theme_color_override("font_color", Color(0.10, 0.18, 0.62, 1))
	card.add_child(par)


func _add_stamp(card: Panel, stamp_bg: Color, stamp_text: String, card_w: float) -> void:
	const SW := 42.0
	const SH := 52.0
	var outer := Panel.new()
	outer.name         = "Stamp"
	outer.position     = Vector2(card_w - SW - 10.0, 9.0)
	outer.size         = Vector2(SW + 4.0, SH + 4.0)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sty_o := StyleBoxFlat.new()
	sty_o.bg_color     = Color(0.97, 0.93, 0.85, 1)
	sty_o.border_color = Color(0.80, 0.74, 0.60, 1)
	sty_o.set_border_width_all(2)
	sty_o.set_corner_radius_all(3)
	outer.add_theme_stylebox_override("panel", sty_o)

	var inner := Panel.new()
	inner.position     = Vector2(2, 2)
	inner.size         = Vector2(SW, SH)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sty_i := StyleBoxFlat.new()
	sty_i.bg_color = stamp_bg
	sty_i.set_corner_radius_all(2)
	inner.add_theme_stylebox_override("panel", sty_i)

	var lbl := Label.new()
	lbl.text                 = stamp_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))

	inner.add_child(lbl)
	outer.add_child(inner)
	card.add_child(outer)


func _add_wax_seal(card: Panel, seal_color: Color, card_h: float) -> void:
	const R := 22.0
	var seal := Panel.new()
	seal.name         = "WaxSeal"
	seal.position     = Vector2(20.0, card_h * 0.5 - R)
	seal.size         = Vector2(R * 2.0, R * 2.0)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sty := StyleBoxFlat.new()
	sty.bg_color     = seal_color
	sty.set_corner_radius_all(R)
	sty.shadow_color  = Color(0, 0, 0, 0.30)
	sty.shadow_size   = 5
	sty.shadow_offset = Vector2(1, 2)
	seal.add_theme_stylebox_override("panel", sty)

	var lbl := Label.new()
	lbl.text                 = "seal"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))

	seal.add_child(lbl)
	card.add_child(seal)


func _apply_face(card: Panel, letter, showing_back: bool) -> void:
	var front: Control = card.get_node("Front")
	var back:  Control = card.get_node("Back")
	front.visible = not showing_back
	back.visible  = showing_back
	if showing_back:
		card.add_theme_stylebox_override("panel", card.get_meta("sty_back"))
		back.get_node("VBox/Clue").text = letter.message
	else:
		card.add_theme_stylebox_override("panel", card.get_meta("sty_front"))
		front.get_node("Sender").text    = "%s\n%s" % [letter.sender_name, letter.sender_address]
		front.get_node("Address").text   = letter.address_line
		front.get_node("Recipient").text = letter.recipient_name


# -- delivery slots ------------------------------------------------------------

func _process(_delta: float) -> void:
	if _showing_inspection:
		_update_delivery_slots()


func _update_delivery_slots() -> void:
	_camera = get_viewport().get_camera_3d()
	if _camera == null:
		return
	var vp        := get_viewport().get_visible_rect()
	var prev_count := _slot_panels.size()

	for node in get_tree().get_nodes_in_group("interactable"):
		if not (node is Mailbox) or not node.enabled:
			continue
		var world_pos:  Vector3 = node.global_position + Vector3(0, 2.0, 0)
		var screen_pos: Vector2 = _camera.unproject_position(world_pos)

		if vp.has_point(screen_pos):
			if _slot_panels.has(node):
				var sp: Panel = _slot_panels[node]
				sp.position = screen_pos - sp.size * 0.5
				if _slotted_cards.has(node):
					var sc: Panel = _slotted_cards[node]
					if is_instance_valid(sc):
						sc.position   = sp.position + sp.size * 0.5 - sc.size * sc.scale * 0.5
						sc.modulate.a = 1.0
			else:
				var house_lbl: String = node.house_label if "house_label" in node else "Mailbox"
				var sp := _make_slot_panel(house_lbl, screen_pos)
				sp.modulate.a = 0.0
				envelopes_layer.add_child(sp)
				envelopes_layer.move_child(sp, 0)
				_slot_panels[node] = sp
				var tw := create_tween()
				tw.tween_property(sp, "modulate:a", 1.0, 0.25)
				if _slotted_cards.has(node):
					var sc: Panel = _slotted_cards[node]
					if is_instance_valid(sc):
						sc.position   = sp.position + sp.size * 0.5 - sc.size * sc.scale * 0.5
						sc.modulate.a = 1.0
		else:
			if _slot_panels.has(node):
				var sp: Panel = _slot_panels[node]
				_slot_panels.erase(node)
				var tw := create_tween()
				tw.tween_property(sp, "modulate:a", 0.0, 0.20)
				tw.tween_callback(sp.queue_free)
				# Hide any delivered card parked here — it will reappear when
				# the slot scrolls back into view.
				if _slotted_cards.has(node):
					var sc: Panel = _slotted_cards[node]
					if is_instance_valid(sc):
						sc.modulate.a = 0.0
						sc.position   = Vector2(-2000.0, -2000.0)

	if _slot_panels.size() != prev_count:
		_update_pager_hint()



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
	icon.text                 = "E"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	icon.offset_top    = 8
	icon.offset_bottom = 40
	icon.add_theme_font_size_override("font_size", 20)
	icon.add_theme_color_override("font_color", Color(0.88, 0.82, 0.65, 1))

	var lbl := Label.new()
	lbl.text                 = house_lbl
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.offset_top    = -24
	lbl.offset_bottom = -5
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.88, 0.84, 0.70, 1))

	p.add_child(icon)
	p.add_child(lbl)
	return p


func _update_slot_highlight(mouse_pos: Vector2) -> void:
	for mb in _slot_panels:
		var sp: Panel = _slot_panels[mb]
		sp.add_theme_stylebox_override("panel",
			sp.get_meta("sty_hot") if _hit(sp, mouse_pos) else sp.get_meta("sty_idle"))


# -- house zone projection -----------------------------------------------------

## Returns a screen-space Rect2 that covers the house belonging to `mailbox`.
## We project 8 world-space corners of the house bounding box so the zone
## automatically shrinks for far houses and grows for near ones (perspective).
func _house_zone(mailbox: Node) -> Rect2:
	if _camera == null:
		return Rect2()
	# House bbox in world-space relative to the mailbox origin.
	# Houses sit ~6 units behind (in -X) the mailbox, are ~7.5 units tall,
	# and ~3.5 units wide (in Z).  Scale 1.3 is already baked into world coords.
	const X_NEAR :=  0.5    # just past mailbox towards camera
	const X_FAR  := -9.0    # back wall of house
	const Y_TOP  :=  6.5    # chimney top
	const Z_HALF :=  2.0    # half street-width (house body is ±2.86 but trim to body face)
	var mb: Vector3 = (mailbox as Node3D).global_position
	var corners := [
		mb + Vector3(X_NEAR, 0.0,   -Z_HALF),
		mb + Vector3(X_NEAR, 0.0,    Z_HALF),
		mb + Vector3(X_FAR,  0.0,   -Z_HALF),
		mb + Vector3(X_FAR,  0.0,    Z_HALF),
		mb + Vector3(X_NEAR, Y_TOP, -Z_HALF),
		mb + Vector3(X_NEAR, Y_TOP,  Z_HALF),
		mb + Vector3(X_FAR,  Y_TOP, -Z_HALF),
		mb + Vector3(X_FAR,  Y_TOP,  Z_HALF),
	]
	var min_x := INF;  var min_y := INF
	var max_x := -INF; var max_y := -INF
	for c in corners:
		var p := _camera.unproject_position(c)
		min_x = minf(min_x, p.x)
		min_y = minf(min_y, p.y)
		max_x = maxf(max_x, p.x)
		max_y = maxf(max_y, p.y)
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)


# -- animations ----------------------------------------------------------------

func _slide_envelopes_in() -> void:
	var vph := get_viewport().get_visible_rect().size.y
	for i in _cards.size():
		var card = _cards[i]
		var rest: Vector2 = card.position
		card.position = Vector2(rest.x, vph + 200.0)
		var tw := create_tween()
		tw.tween_property(card, "position", rest, 0.26 + i * 0.05) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _slide_envelopes_out(on_done: Callable) -> void:
	var vph := get_viewport().get_visible_rect().size.y
	if _cards.is_empty():
		on_done.call()
		return
	var tw := create_tween()
	tw.set_parallel(true)
	for i in _cards.size():
		tw.tween_property(_cards[i], "position:y", vph + 200.0, 0.18 + i * 0.03) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(on_done)


# -- drag ----------------------------------------------------------------------

func _end_drag(pos: Vector2) -> void:
	if _drag_card == null:
		return
	var was_in_slot: bool = _drag_card.get_meta("was_in_slot", false)

	for mb in _slot_panels:
		var zone := _house_zone(mb)
		if zone.has_point(pos):
			_deliver_dragged(mb)
			return

	var vph := get_viewport().get_visible_rect().size.y
	if pos.y > vph - 46.0:
		if was_in_slot:
			GameState.un_deliver(_drag_card.get_meta("letter"))
			_delivered_letters.erase(_drag_card.get_meta("letter"))
		_dismiss_card(_drag_card)
	else:
		if was_in_slot:
			GameState.un_deliver(_drag_card.get_meta("letter"))
			_delivered_letters.erase(_drag_card.get_meta("letter"))
		# Card sticks wherever it was dropped — just reset scale and straighten.
		var card: Panel = _drag_card
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(card, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "rotation_degrees", 0.0, 0.16)
	_drag_card = null


func _deliver_dragged(mailbox) -> void:
	if _drag_card == null or _player == null:
		_drag_card = null
		return
	var sp: Panel = _slot_panels.get(mailbox)
	if sp == null:
		_drag_card = null
		return
	var letter = _drag_card.get_meta("letter")
	var idx    := GameState.mail_bag.find(letter)
	if idx >= 0:
		GameState.selected_index = idx
	var target: Vector2 = sp.global_position + sp.size * 0.5 - _drag_card.size * 0.5
	var card: Panel     = _drag_card
	_drag_card = null
	card.set_meta("in_slot",      true)
	card.set_meta("slot_mailbox", mailbox)
	card.set_meta("was_in_slot",  false)
	_slotted_cards[mailbox]    = card
	_delivered_letters[letter] = mailbox
	_pull_cards.erase(card)
	envelopes_layer.move_child(card, 0)
	var tw := create_tween()
	tw.tween_property(card, "position", target, 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(0.55, 0.55), 0.14) \
		.set_trans(Tween.TRANS_CUBIC)
	var mb = mailbox
	var pl = _player
	tw.tween_callback(func(): mb.interact(pl))


func _dismiss_card(card: Panel) -> void:
	var vph := get_viewport().get_visible_rect().size.y
	var tw  := create_tween()
	tw.tween_property(card, "position:y", vph + 200.0, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(card.queue_free)
	_cards.erase(card)
	_drag_card = null
	_update_pager_hint()


func _hit(card: Control, pos: Vector2) -> bool:
	return Rect2(card.global_position, card.size * card.scale).has_point(pos)


# -- flip ----------------------------------------------------------------------

func _try_flip_at(pos: Vector2) -> void:
	var children := envelopes_layer.get_children()
	for i in range(children.size() - 1, -1, -1):
		var card = children[i]
		if not _slot_panels.values().has(card) and _hit(card, pos):
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
	tw.tween_property(card, "scale:x", card.scale.y, 0.10).set_trans(Tween.TRANS_CUBIC)


# -- notebook ------------------------------------------------------------------

func _try_notebook_page(pos: Vector2) -> void:
	if not notebook_node.visible:
		return
	var nb_rect := Rect2(notebook_node.global_position, notebook_node.size)
	if not nb_rect.has_point(pos):
		return
	var mid_x := notebook_node.global_position.x + notebook_node.size.x * 0.5
	_nb_page = wrapi(_nb_page + (1 if pos.x >= mid_x else -1), 0, _NB_PAGES.size())
	notebook_content.text = _NB_PAGES[_nb_page]
	nb_prev.text = "<" if _nb_page > 0 else ""
	nb_next.text = ">" if _nb_page < _NB_PAGES.size() - 1 else ""


# -- pager hint ----------------------------------------------------------------

func _update_pager_hint() -> void:
	var bag := GameState.mail_bag
	if bag.is_empty() and _delivered_letters.is_empty():
		pager_hint.text = "bag empty -- all letters delivered"
		return
	if _slot_panels.size() > 0:
		pager_hint.text = "drag envelope onto a mailbox slot to deliver   |   right-click to flip"
	else:
		pager_hint.text = "walk near a mailbox — slots appear above it   |   Tab to close"


# -- signal handlers -----------------------------------------------------------

func _on_selected_changed(_index: int, _letter) -> void:
	pass


func _on_day_started(_day: int, letters: Array) -> void:
	for child in stamp_row.get_children():
		child.queue_free()
	_delivered_count = 0
	for letter in letters:
		stamp_row.add_child(_make_stamp_slot(letter))
	_update_stamp_counter(letters.size())


func _on_letter_delivered(_letter, _house_id: String, was_correct: bool) -> void:
	_delivered_count += 1
	for slot in stamp_row.get_children():
		if slot.get_meta("delivered", false) == false:
			slot.set_meta("delivered", true)
			var mark: Label = slot.get_meta("mark_label")
			mark.text = "v" if was_correct else "x"
			mark.add_theme_color_override("font_color",
				Color(1, 1, 1, 0.95) if was_correct else Color(1, 0.9, 0.4, 0.9))
			break
	_update_stamp_counter(stamp_row.get_child_count())


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


# -- stamp slot ----------------------------------------------------------------

func _make_stamp_slot(letter = null) -> Control:
	var theme_id := _letter_theme(letter) if letter != null else 0
	var td: Dictionary = THEME_DATA[theme_id]

	const OW := 40.0
	const OH := 50.0

	var outer := Control.new()
	outer.custom_minimum_size = Vector2(OW, OH)

	var p_outer := Panel.new()
	p_outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p_outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sty_o := StyleBoxFlat.new()
	sty_o.bg_color     = Color(0.97, 0.93, 0.85, 1)
	sty_o.border_color = Color(0.80, 0.74, 0.60, 1)
	sty_o.set_border_width_all(3)
	sty_o.set_corner_radius_all(3)
	p_outer.add_theme_stylebox_override("panel", sty_o)

	var p_inner := Panel.new()
	p_inner.position     = Vector2(4, 4)
	p_inner.size         = Vector2(OW - 8.0, OH - 8.0)
	p_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sty_i := StyleBoxFlat.new()
	sty_i.bg_color = td["tracker"]
	sty_i.set_corner_radius_all(2)
	p_inner.add_theme_stylebox_override("panel", sty_i)

	var mark := Label.new()
	mark.name                 = "Mark"
	mark.text                 = ""
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	mark.add_theme_font_size_override("font_size", 20)
	mark.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))

	p_inner.add_child(mark)
	outer.add_child(p_outer)
	outer.add_child(p_inner)
	outer.set_meta("delivered",  false)
	outer.set_meta("mark_label", mark)
	return outer


func _update_stamp_counter(total: int) -> void:
	stamp_counter.text = "%d / %d livre" % [_delivered_count, total]
