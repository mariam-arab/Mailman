extends CanvasLayer
## Heads-up display for Special Delivery. Stays minimal — the spec wants
## immersion, so the HUD only shows: a stamp row tracking deliveries, a small
## interaction prompt, the envelope inspection panel, and the end-of-day card.

@onready var stamp_row: HBoxContainer = $StampRow
@onready var prompt_label: Label = $PromptLabel
@onready var inspection: Control = $Inspection
@onready var inspect_envelope: Panel = $Inspection/Envelope
@onready var inspect_front: VBoxContainer = $Inspection/Envelope/Front
@onready var inspect_back: VBoxContainer = $Inspection/Envelope/Back
@onready var sender_label: Label = $Inspection/Envelope/Front/Sender
@onready var address_label: Label = $Inspection/Envelope/Front/Address
@onready var recipient_label: Label = $Inspection/Envelope/Front/Recipient
@onready var clue_label: Label = $Inspection/Envelope/Back/Clue
@onready var pager_label: Label = $Inspection/Envelope/Pager
@onready var summary: Control = $Summary
@onready var summary_label: Label = $Summary/Center/SummaryLabel

var _player: Node = null
var _showing_inspection: bool = false
var _showing_back: bool = false


func _ready() -> void:
	inspection.visible = false
	summary.visible = false
	prompt_label.text = ""
	GameState.day_started.connect(_on_day_started)
	GameState.day_ended.connect(_on_day_ended)
	GameState.letter_delivered.connect(_on_letter_delivered)
	GameState.selected_letter_changed.connect(_on_selected_changed)


## Bound by the level so HUD can release/recapture the mouse when inspecting.
func bind_player(player: Node) -> void:
	_player = player


func set_prompt(text: String) -> void:
	prompt_label.text = text


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inspect_mail"):
		_toggle_inspection()
	elif _showing_inspection:
		if event.is_action_pressed("flip_letter"):
			_showing_back = not _showing_back
			inspect_front.visible = not _showing_back
			inspect_back.visible = _showing_back
		elif event.is_action_pressed("next_letter"):
			GameState.cycle_selection(1)
		elif event.is_action_pressed("prev_letter"):
			GameState.cycle_selection(-1)


func _toggle_inspection() -> void:
	if GameState.mail_bag.is_empty() and not _showing_inspection:
		return
	_showing_inspection = not _showing_inspection
	inspection.visible = _showing_inspection
	if _showing_inspection:
		_showing_back = false
		inspect_front.visible = true
		inspect_back.visible = false
		_refresh_inspection()
	# Release the mouse during inspection so the player can read comfortably.
	if _player and _player.has_method("set_input_active"):
		_player.set_input_active(not _showing_inspection)


func _refresh_inspection() -> void:
	var letter = GameState.get_selected_letter()
	if letter == null:
		sender_label.text = ""
		address_label.text = ""
		recipient_label.text = ""
		clue_label.text = ""
		pager_label.text = "Bag empty"
		return
	# Front of envelope — sender block, smudged street, vague recipient.
	sender_label.text = "%s\n%s" % [letter.sender_name, letter.sender_address]
	address_label.text = letter.address_line
	recipient_label.text = letter.recipient_description
	# Back — handwritten clue.
	clue_label.text = letter.clue_text
	pager_label.text = "%d / %d   ◀ Q   E ▶   R: flip" % [
		GameState.selected_index + 1, GameState.mail_bag.size()
	]


func _on_selected_changed(_index: int, _letter) -> void:
	if _showing_inspection:
		_refresh_inspection()


func _on_day_started(_day: int, letters: Array) -> void:
	# Rebuild the stamp row — one TextureRect-style placeholder per letter.
	for child in stamp_row.get_children():
		child.queue_free()
	for i in letters.size():
		var slot := _make_stamp_slot()
		stamp_row.add_child(slot)


func _on_letter_delivered(_letter, _house_id: String, was_correct: bool) -> void:
	# Stamp the next slot. Green check for correct, "?" for wrong.
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
		_refresh_inspection()


func _on_day_ended(day: int, results: Array) -> void:
	var correct := 0
	for r in results:
		if r["delivered"] and r["correct"]:
			correct += 1
	summary_label.text = "Day %d complete\n\n%d / %d letters delivered correctly\n\nESC to release mouse" % [
		day, correct, results.size()
	]
	summary.visible = true
	if _player and _player.has_method("set_input_active"):
		_player.set_input_active(false)


func _make_stamp_slot() -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(40, 48)
	# Subtle vintage-stamp look: cream background with a thin warm border.
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
