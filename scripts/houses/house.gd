extends StaticBody3D
## Block-out house — a colored cardstock body with a triangular roof and a
## window that glows from inside. Sprint 6 will replace the meshes with
## imported .glb craft models, but the API stays the same: set body_color and
## roof_color in the inspector and the materials update on _ready.

@export var body_color: Color = Color(0.74, 0.45, 0.30):  # dusty terracotta
	set(v):
		body_color = v
		if is_inside_tree():
			_apply_colors()
@export var roof_color: Color = Color(0.55, 0.30, 0.20):
	set(v):
		roof_color = v
		if is_inside_tree():
			_apply_colors()
## Optional bilingual label shown on a small sign near the front door.
@export var house_label: String = ""

@onready var body_mesh: MeshInstance3D = $Body
@onready var roof_mesh: MeshInstance3D = $Roof


func _ready() -> void:
	_apply_colors()


func _apply_colors() -> void:
	if body_mesh:
		var bm := StandardMaterial3D.new()
		bm.albedo_color = body_color
		bm.roughness = 1.0
		body_mesh.set_surface_override_material(0, bm)
	if roof_mesh:
		var rm := StandardMaterial3D.new()
		rm.albedo_color = roof_color
		rm.roughness = 1.0
		roof_mesh.set_surface_override_material(0, rm)
