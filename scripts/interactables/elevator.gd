extends "res://scripts/interactables/interactable_object.gd"
class_name Elevator

@export var floor_ys: PackedFloat32Array = PackedFloat32Array([0.0, 4.0, 8.0])
@export var y_offset_from_floor: float = 0.5


func prompt_text() -> String:
	return "E: Take elevator"


func interact(player: Node) -> void:
	if not enabled or floor_ys.is_empty():
		return
	var current := _closest_floor(player.global_position.y)
	var next := (current + 1) % floor_ys.size()
	player.global_position.y = floor_ys[next] + y_offset_from_floor
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
