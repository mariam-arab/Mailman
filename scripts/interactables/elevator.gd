extends "res://scripts/interactables/interactable_object.gd"
class_name Elevator

@export var floor_ys: PackedFloat32Array = PackedFloat32Array([0.0, 4.0, 8.0])
@export var floor_labels: PackedStringArray = PackedStringArray(["Floor 1", "Floor 2", "Floor 3"])
@export var y_offset_from_floor: float = 0.5


func prompt_text() -> String:
	return "E: Take elevator"


func interact(player: Node) -> void:
	if not enabled or floor_ys.is_empty():
		return
	var hud = get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("open_floor_picker"):
		return
	var current := _closest_floor(player.global_position.y)
	var labels: Array = []
	for i in floor_ys.size():
		labels.append(floor_labels[i] if i < floor_labels.size() else "Floor %d" % (i + 1))
	hud.open_floor_picker(labels, current, func(idx: int) -> void: _go_to_floor(player, idx))


func _go_to_floor(player: Node, idx: int) -> void:
	if idx < 0 or idx >= floor_ys.size():
		return
	player.global_position.y = floor_ys[idx] + y_offset_from_floor
	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO


func _closest_floor(y: float) -> int:
	var best := 0
	var best_d := INF
	for i in floor_ys.size():
		var d := absf(floor_ys[i] - y)
		if d < best_d:
			best = i
			best_d = d
	return best
