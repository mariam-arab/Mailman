extends StaticBody3D
class_name InteractableObject
## Base class for anything the player can target with the camera ray and
## activate with E. Subclasses override `interact` and `prompt_text`.
##
## Convention: place the script on a StaticBody3D on physics layer 3 (Interactable).
## The player's RayCast3D has collision_mask = 4 so it picks up only this layer.

@export var enabled: bool = true


## Short text shown in the bottom-left HUD when the player is looking at this
## object. Subclasses should return something like "E: Open mailbox".
func prompt_text() -> String:
	return "E: Interact"


## Called when the player presses the interact action while looking at this
## object. Subclasses implement the actual behavior.
func interact(player: Node) -> void:
	pass
