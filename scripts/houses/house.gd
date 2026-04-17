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
	_add_number_sign()


func _add_number_sign() -> void:
	if house_label.is_empty():
		return
	var lbl := Label3D.new()
	lbl.text            = house_label
	lbl.font_size       = 64
	lbl.outline_size    = 8
	lbl.modulate        = Color(0.96, 0.91, 0.78, 1)
	lbl.outline_modulate = Color(0.28, 0.16, 0.08, 1)
	lbl.billboard       = BaseMaterial3D.BILLBOARD_DISABLED
	lbl.double_sided    = true
	lbl.no_depth_test   = false
	lbl.pixel_size      = 0.006
	# Above the door (door is at local Z=-2.24, Y≈0.95). The house is rotated
	# 90° Y in the level so local -Z faces the camera (+X world).
	lbl.position        = Vector3(0.0, 2.6, -2.28)
	lbl.scale           = Vector3(-1.0, 1.0, 1.0)
	add_child(lbl)


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
