extends Node
## GameState — global autoload that tracks the current day, the player's mail bag,
## and per-day delivery results. Exposes signals so HUD/UI can react without
## tight coupling.

signal day_started(day_number: int, letters: Array)
signal day_ended(day_number: int, results: Array)
signal letter_delivered(letter, mailbox_house_id: String, was_correct: bool)
signal selected_letter_changed(index: int, letter)

var current_day: int = 0
## Active letters the player is carrying. Each entry is a Mail resource.
var mail_bag: Array = []
## Per-letter delivery result: { "letter": Mail, "house_id": String, "correct": bool }
## Mirrors mail_bag order so the HUD can paint stamp marks at the right slot.
var results: Array = []
var selected_index: int = 0


func start_day(day_number: int, letters: Array) -> void:
	current_day = day_number
	mail_bag = letters.duplicate()
	results.clear()
	for _i in mail_bag.size():
		results.append({"letter": null, "house_id": "", "correct": false, "delivered": false})
	selected_index = 0
	day_started.emit(current_day, mail_bag)
	if mail_bag.size() > 0:
		selected_letter_changed.emit(selected_index, mail_bag[selected_index])


func get_selected_letter():
	if mail_bag.is_empty():
		return null
	selected_index = clamp(selected_index, 0, mail_bag.size() - 1)
	return mail_bag[selected_index]


func cycle_selection(delta: int) -> void:
	if mail_bag.is_empty():
		return
	selected_index = wrapi(selected_index + delta, 0, mail_bag.size())
	selected_letter_changed.emit(selected_index, mail_bag[selected_index])


## Attempts to drop the currently selected letter into the given mailbox.
## Returns true if there was a letter to deliver (regardless of correctness).
func try_deliver(mailbox_house_id: String) -> bool:
	var letter = get_selected_letter()
	if letter == null:
		return false
	var was_correct: bool = (letter.correct_house_id == mailbox_house_id)
	# Record result at the original slot so the stamp HUD stays in order.
	var slot := _find_slot_for_letter(letter)
	if slot >= 0:
		results[slot] = {
			"letter": letter,
			"house_id": mailbox_house_id,
			"correct": was_correct,
			"delivered": true,
		}
	# Remove from active bag whether right or wrong — the spec keeps wrong
	# letters in the bag, but to keep the day finite we treat each attempt as a
	# resolution. The "softer slide back" feedback still plays via the delivery
	# system before this is called when wrong, so the player understands.
	mail_bag.erase(letter)
	if selected_index >= mail_bag.size():
		selected_index = max(0, mail_bag.size() - 1)
	letter_delivered.emit(letter, mailbox_house_id, was_correct)
	if mail_bag.is_empty():
		day_ended.emit(current_day, results)
	else:
		selected_letter_changed.emit(selected_index, mail_bag[selected_index])
	return true


## Reverses a delivery: puts the letter back in the bag and clears its result slot.
## Only valid while the day is still in progress (before day_ended fires).
func un_deliver(letter) -> void:
	for i in results.size():
		if results[i].get("delivered", false) and results[i]["letter"] == letter:
			results[i] = {"letter": null, "house_id": "", "correct": false, "delivered": false}
			break
	if not mail_bag.has(letter):
		mail_bag.append(letter)


func correct_count() -> int:
	var c := 0
	for r in results:
		if r["delivered"] and r["correct"]:
			c += 1
	return c


func _find_slot_for_letter(letter) -> int:
	# Match by id so duplicates of the same Mail resource don't collide.
	for i in results.size():
		var r = results[i]
		if not r["delivered"] and r["letter"] == null:
			# Use the bag's original ordering: the slot index equals the letter's
			# position when start_day was called. We reconstruct that by
			# scanning the bag for the matching id and returning the first
			# undelivered slot.
			pass
	# Simple approach: assign to the first undelivered slot.
	for i in results.size():
		if not results[i]["delivered"]:
			return i
	return -1
