extends CanvasLayer
## Heads-up display for Special Delivery. Stays minimal — the spec wants
## immersion, so the HUD only shows: a stamp row tracking deliveries, a small
## interaction prompt, the letter carousel, and the end-of-day card.

@onready var stamp_row: HBoxContainer = $StampRow
@onready var prompt_label: Label = $PromptLabel
@onready var inspection: Control = $Inspection
@onready var carousel_row: HBoxContainer = $Inspection/CarouselRow
@onready var pager_hint: Label = $Inspection/PagerHint
@onready var summary: Control = $Summary
@onready var summary_label: Label = $Summary/Center/SummaryLabel

var _player: Node = null
var _showing_inspection: bool = false
var _showing_back: bool = false
var _cards: Array = []
var _nearby_interactable = null

var _style_selected: StyleBoxFlat
var _style_idle: StyleBoxFlat


func _ready() -> void:
	_build_styles()
	inspection.visible = false
	summary.visible = false
	prompt_label.text = ""
	GameState.day_started.connect(_on_day_started)
	GameState.day_ended.connect(_on_day_ended)
	GameState.letter_delivered.connect(_on_letter_delivered)
	GameState.selected_letter_changed.connect(_on_selected_changed)


func _build_styles() -> void:
	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = Color(0.96, 0.91, 0.78)
	_style_selected.border_color = Color(0.55, 0.20, 0.18)
	_style_selected.set_border_width_all(4)
	_style_selected.set_corner_radius_all(6)
	_style_selected.shadow_color = Color(0, 0, 0, 0.45)
	_style_selected.shadow_size = 16
	_style_selected.shadow_offset = Vector2(0, 8)

	_style_idle = StyleBoxFlat.new()
	_style_idle.bg_color = Color(0.93, 0.87, 0.72)
	_style_idle.border_color = Color(0.45, 0.28, 0.18)
	_style_idle.set_border_width_all(2)
	_style_idle.set_corner_radius_all(4)


## Bound by the level so HUD can release/recapture the mouse when inspecting.
func bind_player(player: Node) -> void:
	_player = player


func set_prompt(text: String) -> void:
	prompt_label.text = text


func set_nearby_interactable(target) -> void:
	_nearby_interactable = target
	if _showing_inspection:
		_update_pager_hint()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inspect_mail"):
		_toggle_inspection()
	elif _showing_inspection:
		if event.is_action_pressed("interact"):
			if _nearby_interactable and _player:
				_nearby_interactable.interact(_player)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("flip_letter"):
			_showing_back = not _showing_back
			_refresh_carousel()
		elif event.is_action_pressed("next_letter"):
			GameState.cycle_selection(1)
		elif event.is_action_pressed("prev_letter"):
			GameState.cycle_selection(-1)


## Opens the carousel from outside (e.g. when the player presses E near a mailbox).
func open_inspection() -> void:
	if _showing_inspection or GameState.mail_bag.is_empty():
		return
	_showing_inspection = true
	inspection.visible = true
	_showing_back = false
	_rebuild_carousel()
	if _player and _player.has_method("set_input_active"):
		_player.set_input_active(false)


func _toggle_inspection() -> void:
	if GameState.mail_bag.is_empty() and not _showing_inspection:
		return
	_showing_inspection = not _showing_inspection
	inspection.visible = _showing_inspection
	if _showing_inspection:
		_showing_back = false
		_rebuild_carousel()
	if _player and _player.has_method("set_input_active"):
		_player.set_input_active(not _showing_inspection)


## Rebuilds all cards from the current mail bag — called on open and after delivery.
func _rebuild_carousel() -> void:
	for child in carousel_row.get_children():
		child.queue_free()
	_cards.clear()
	for _i in GameState.mail_bag.size():
		var card := _make_card()
		carousel_row.add_child(card)
		_cards.append(card)
	_refresh_carousel()


## Updates visual state of every card without recreating nodes.
func _refresh_carousel() -> void:
	var bag := GameState.mail_bag
	var sel := GameState.selected_index
	for i in _cards.size():
		if i >= bag.size():
			break
		_apply_card_state(_cards[i], bag[i], i == sel)
	_update_pager_hint()


func _update_pager_hint() -> void:
	var bag := GameState.mail_bag
	if bag.is_empty():
		pager_hint.text = "Bag empty"
		return
	var nav := "%d / %d   ◀ A   D ▶   R: flip" % [GameState.selected_index + 1, bag.size()]
	if _nearby_interactable and _nearby_interactable.has_method("interact"):
		var label: String = _nearby_interactable.house_label if "house_label" in _nearby_interactable else ""
		var dest := "  →  " + label if label else ""
		pager_hint.text = "E: Deliver%s        %s" % [dest, nav]
	else:
		pager_hint.text = "Close (Tab) and walk near a mailbox to deliver        %s" % nav


func _apply_card_state(card: Panel, letter, is_selected: bool) -> void:
	card.custom_minimum_size = Vector2(280, 360) if is_selected else Vector2(170, 250)
	card.add_theme_stylebox_override("panel", _style_selected if is_selected else _style_idle)
	card.modulate = Color.WHITE if is_selected else Color(1, 1, 1, 0.55)

	var vbox: VBoxContainer = card.get_node("VBox")
	var sender_lbl: Label = vbox.get_node("Sender")
	var address_lbl: Label = vbox.get_node("Address")
	var recipient_lbl: Label = vbox.get_node("Recipient")
	var clue_header_lbl: Label = vbox.get_node("ClueHeader")
	var clue_lbl: Label = vbox.get_node("Clue")

	if is_selected and _showing_back:
		sender_lbl.visible = false
		address_lbl.visible = false
		recipient_lbl.visible = false
		clue_header_lbl.visible = true
		clue_lbl.visible = true
		clue_lbl.text = letter.clue_text
	elif is_selected:
		sender_lbl.visible = true
		address_lbl.visible = true
		recipient_lbl.visible = true
		clue_header_lbl.visible = false
		clue_lbl.visible = false
		sender_lbl.text = "%s\n%s" % [letter.sender_name, letter.sender_address]
		address_lbl.text = letter.address_line
		recipient_lbl.text = letter.recipient_description
	else:
		# Condensed: address + sender only.
		sender_lbl.visible = true
		address_lbl.visible = true
		recipient_lbl.visible = false
		clue_header_lbl.visible = false
		clue_lbl.visible = false
		sender_lbl.text = letter.sender_name
		address_lbl.text = letter.address_line


func _make_card() -> Panel:
	var card := Panel.new()
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20
	vbox.offset_top = 20
	vbox.offset_right = -20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 12)

	var sender := Label.new()
	sender.name = "Sender"
	sender.autowrap_mode = TextServer.AUTOWRAP_WORD
	sender.add_theme_font_size_override("font_size", 14)
	sender.add_theme_color_override("font_color", Color(0.40, 0.28, 0.18))

	var address := Label.new()
	address.name = "Address"
	address.autowrap_mode = TextServer.AUTOWRAP_WORD
	address.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	address.add_theme_font_size_override("font_size", 22)
	address.add_theme_color_override("font_color", Color(0.20, 0.14, 0.10))

	var recipient := Label.new()
	recipient.name = "Recipient"
	recipient.autowrap_mode = TextServer.AUTOWRAP_WORD
	recipient.add_theme_font_size_override("font_size", 16)
	recipient.add_theme_color_override("font_color", Color(0.35, 0.22, 0.15))

	var clue_header := Label.new()
	clue_header.name = "ClueHeader"
	clue_header.text = "— scrawled on the back —"
	clue_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clue_header.add_theme_font_size_override("font_size", 14)
	clue_header.add_theme_color_override("font_color", Color(0.40, 0.28, 0.20))

	var clue := Label.new()
	clue.name = "Clue"
	clue.autowrap_mode = TextServer.AUTOWRAP_WORD
	clue.add_theme_font_size_override("font_size", 18)
	clue.add_theme_color_override("font_color", Color(0.20, 0.15, 0.10))

	vbox.add_child(sender)
	vbox.add_child(address)
	vbox.add_child(recipient)
	vbox.add_child(clue_header)
	vbox.add_child(clue)
	card.add_child(vbox)
	return card


func _on_selected_changed(_index: int, _letter) -> void:
	if _showing_inspection:
		_showing_back = false
		_refresh_carousel()


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
			if was_correct:
				mark.text = "✓"
				mark.add_theme_color_override("font_color", Color(0.18, 0.55, 0.20))
			else:
				mark.text = "?"
				mark.add_theme_color_override("font_color", Color(0.55, 0.40, 0.18))
			break
	if _showing_inspection:
		_rebuild_carousel()


func _on_day_ended(day: int, results: Array) -> void:
	var correct := 0
	for r in results:
		if r["delivered"] and r["correct"]:
			correct += 1
	summary_label.text = "Day %d complete\n\n%d / %d letters delivered correctly\n\nESC to release mouse" % [
		day, correct, results.size()
	]
	summary.visible = true
	inspection.visible = false
	_showing_inspection = false
	if _player and _player.has_method("set_input_active"):
		_player.set_input_active(false)


func _make_stamp_slot() -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(40, 48)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.91, 0.78)
	sb.border_color = Color(0.55, 0.30, 0.20)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	slot.add_theme_stylebox_override("panel", sb)
	var mark := Label.new()
	mark.name = "Mark"
	mark.text = ""
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.add_theme_font_size_override("font_size", 28)
	slot.add_child(mark)
	slot.set_meta("delivered", false)
	return slot
