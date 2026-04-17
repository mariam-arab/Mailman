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
@onready var dialogue_panel: Panel      = $DialoguePanel
@onready var dialogue_speaker: Label    = $DialoguePanel/Speaker
@onready var dialogue_text: Label       = $DialoguePanel/Text
@onready var dialogue_hint: Label       = $DialoguePanel/Hint

var _player: Node               = null
var _showing_inspection: bool   = false

# Dialogue
var _dialogue_lines: Array      = []
var _dialogue_idx: int          = 0
var _nearby_interactable        = null
var _cards: Array               = []

# Drag
var _drag_card                  = null
var _drag_offset: Vector2       = Vector2.ZERO

# Persisted envelope positions (letter.id → Vector2)
var _saved_positions: Dictionary = {}

# Delivery slots projected from 3D mailboxes in frame (interactable → Panel)
var _slot_panels: Dictionary    = {}
var _camera: Camera3D           = null

# Letters that have been delivered but can still be dragged back (Mail → mailbox node)
var _delivered_letters: Dictionary = {}
# Cards parked in delivery slots (mailbox node → Panel card)
var _slotted_cards: Dictionary  = {}

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
	add_to_group("hud")
	_build_styles()
	_build_notebook()
	inspection.visible     = false
	summary.visible        = false
	dialogue_panel.visible = false
	prompt_label.text      = ""
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
	dialogue_hint.text = "E — close" if last else "E — continue"


func _close_dialogue() -> void:
	_dialogue_lines = []
	var tw := create_tween()
	tw.tween_property(dialogue_panel, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func():
		dialogue_panel.visible = false
		dialogue_panel.modulate.a = 1.0
	)


# ── input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# Dialogue takes priority — consume E so level.gd doesn't also fire.
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
	if GameState.mail_bag.is_empty() and _delivered_letters.is_empty() and not _showing_inspection:
		return
	if _showing_inspection:
		_showing_inspection = false
		_drag_card = null
		for mb in _slot_panels:
			var sp: Panel = _slot_panels[mb]
			var tw := create_tween()
			tw.tween_property(sp, "modulate:a", 0.0, 0.15)
		_slot_panels.clear()
		# Fade out slotted cards — they will be recreated on next open
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


# ── envelopes ─────────────────────────────────────────────────────────────────

func _rebuild_envelopes() -> void:
	for child in envelopes_layer.get_children():
		child.queue_free()
	_cards.clear()
	_slot_panels.clear()
	_slotted_cards.clear()
	var bag := GameState.mail_bag
	for i in bag.size():
		var card := _make_envelope(bag[i], i, bag.size())
		envelopes_layer.add_child(card)
		_cards.append(card)
	# Recreate cards for letters already in delivery slots
	for letter in _delivered_letters:
		var card := _make_envelope(letter, 0, 0)
		card.set_meta("in_slot", true)
		card.set_meta("slot_mailbox", _delivered_letters[letter])
		card.scale    = Vector2(0.70, 0.70)
		card.modulate = Color(1, 1, 1, 0)          # start invisible — positioned by _update_delivery_slots
		card.position = Vector2(-2000.0, -2000.0)  # off-screen until slot panel places it
		envelopes_layer.add_child(card)
		envelopes_layer.move_child(card, 0)        # behind bag cards
		_slotted_cards[_delivered_letters[letter]] = card
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
	const EW := 200.0
	const EH := 128.0
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
	s.add_theme_font_size_override("font_size", 9)
	s.add_theme_color_override("font_color", Color(0.40, 0.28, 0.18, 1))
	var a := Label.new(); a.name = "Address"
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a.autowrap_mode = TextServer.AUTOWRAP_WORD
	a.add_theme_font_size_override("font_size", 14)
	a.add_theme_color_override("font_color", Color(0.18, 0.12, 0.08, 1))
	var r := Label.new(); r.name = "Recipient"
	r.autowrap_mode = TextServer.AUTOWRAP_WORD
	r.add_theme_font_size_override("font_size", 10)
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
	ch.add_theme_font_size_override("font_size", 10)
	ch.add_theme_color_override("font_color", Color(0.42, 0.30, 0.20, 1))
	var cl := Label.new(); cl.name = "Clue"
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD
	cl.add_theme_font_size_override("font_size", 11)
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


# ── delivery slots (live, updated every frame while overlay is open) ──────────

func _process(_delta: float) -> void:
	if _showing_inspection:
		_update_delivery_slots()


func _update_delivery_slots() -> void:
	_camera = get_viewport().get_camera_3d()
	if _camera == null:
		return
	var vp := get_viewport().get_visible_rect()
	var prev_count := _slot_panels.size()

	for node in get_tree().get_nodes_in_group("interactable"):
		if not (node is InteractableObject) or not node.enabled:
			continue
		var world_pos: Vector3 = node.global_position + Vector3(0, 2.0, 0)
		var screen_pos: Vector2 = _camera.unproject_position(world_pos)

		if vp.has_point(screen_pos):
			if _slot_panels.has(node):
				# Already exists — just update its position.
				var sp: Panel = _slot_panels[node]
				sp.position = screen_pos - sp.size * 0.5
				# Snap any parked card to stay centred on the slot, above the slot panel
				if _slotted_cards.has(node):
					var sc: Panel = _slotted_cards[node]
					if is_instance_valid(sc):
						sc.position  = sp.position + sp.size * 0.5 - sc.size * sc.scale * 0.5
						sc.modulate.a = 1.0
						if sc.get_index() <= sp.get_index():
							envelopes_layer.move_child(sc, sp.get_index() + 1)
			else:
				# Came into frame — create and fade in.
				var house_lbl: String = node.house_label if "house_label" in node else "Mailbox"
				var sp := _make_slot_panel(house_lbl, screen_pos)
				sp.modulate.a = 0.0
				envelopes_layer.add_child(sp)
				envelopes_layer.move_child(sp, 0)
				_slot_panels[node] = sp
				var tw := create_tween()
				tw.tween_property(sp, "modulate:a", 1.0, 0.25)
				# If a card is already parked here, position and show it above the slot panel
				if _slotted_cards.has(node):
					var sc: Panel = _slotted_cards[node]
					if is_instance_valid(sc):
						sc.position  = sp.position + sp.size * 0.5 - sc.size * sc.scale * 0.5
						sc.modulate.a = 1.0
						envelopes_layer.move_child(sc, sp.get_index() + 1)
		else:
			if _slot_panels.has(node):
				# Left frame — fade out and remove.
				var sp: Panel = _slot_panels[node]
				_slot_panels.erase(node)
				var tw := create_tween()
				tw.tween_property(sp, "modulate:a", 0.0, 0.20)
				tw.tween_callback(sp.queue_free)

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
	for mb in _slot_panels:
		var sp: Panel = _slot_panels[mb]
		var hot: bool = _hit(sp, mouse_pos)
		sp.add_theme_stylebox_override("panel",
			sp.get_meta("sty_hot") if hot else sp.get_meta("sty_idle"))


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
		if _slot_panels.values().has(card):
			continue
		if _hit(card, pos):
			var from_slot: bool = card.get_meta("in_slot", false)
			if from_slot:
				# Lift card out of its slot
				var mb = card.get_meta("slot_mailbox", null)
				if mb:
					_slotted_cards.erase(mb)
				card.set_meta("in_slot", false)
				card.set_meta("slot_mailbox", null)
			card.set_meta("was_in_slot", from_slot)
			_drag_card   = card
			_drag_offset = pos - card.global_position
			envelopes_layer.move_child(card, -1)
			var tw := create_tween()
			tw.tween_property(card, "scale", Vector2(1.04, 1.04), 0.08)
			return


func _end_drag(pos: Vector2) -> void:
	if _drag_card == null:
		return
	var was_in_slot: bool = _drag_card.get_meta("was_in_slot", false)
	# Drop onto any mailbox slot → deliver to that mailbox
	for mb in _slot_panels:
		var sp: Panel = _slot_panels[mb]
		if _hit(sp, pos):
			_deliver_dragged(mb)
			return
	# Drag to bottom edge → dismiss (remove from game entirely)
	var vph := get_viewport().get_visible_rect().size.y
	if pos.y > vph * 0.85:
		if was_in_slot:
			GameState.un_deliver(_drag_card.get_meta("letter"))
			_delivered_letters.erase(_drag_card.get_meta("letter"))
		_dismiss_card(_drag_card)
	else:
		# Dropped back into bag area
		if was_in_slot:
			GameState.un_deliver(_drag_card.get_meta("letter"))
			_delivered_letters.erase(_drag_card.get_meta("letter"))
		var tw := create_tween()
		tw.tween_property(_drag_card, "scale", Vector2.ONE, 0.14)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_saved_positions[_drag_card.get_meta("letter").id] = _drag_card.position
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
	# Point GameState at this letter so mailbox.interact delivers the right one.
	var idx := GameState.mail_bag.find(letter)
	if idx >= 0:
		GameState.selected_index = idx
	# Fly card to slot and shrink it to sit inside the slot panel — but keep it visible.
	var target: Vector2 = sp.global_position + sp.size * 0.5 - _drag_card.size * 0.5
	var card: Panel = _drag_card
	_drag_card = null
	card.set_meta("in_slot", true)
	card.set_meta("slot_mailbox", mailbox)
	card.set_meta("was_in_slot", false)
	_slotted_cards[mailbox] = card
	_delivered_letters[letter] = mailbox
	envelopes_layer.move_child(card, sp.get_index() + 1)  # above slot panel so it's visible
	var tw := create_tween()
	tw.tween_property(card, "position", target, 0.18)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(0.70, 0.70), 0.14)\
		.set_trans(Tween.TRANS_CUBIC)
	var mb = mailbox
	var pl = _player
	tw.tween_callback(func(): mb.interact(pl))


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
	if _slot_panels.size() > 0:
		pager_hint.text = "Drag a letter onto a mailbox slot to deliver   |   right-click to flip"
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
	# Don't rebuild — the card is now parked in the delivery slot and stays visible.


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
