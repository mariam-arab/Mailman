extends RefCounted
class_name SortingLevelExtractor
## Reads a 3D level .tscn and extracts the data the 2D sorting desk needs:
## an ordered list of houses (id, label, colors) and the letter array.
##
## Why this exists: houses are hand-placed in the 3D scene files, not stored
## as data. Rather than edit those files to add a parallel 2D data block or
## ask the user to author one per level, we instantiate the PackedScene
## detached from the SceneTree. `_ready` does not fire until a node enters
## the tree, so this is a pure data read — no 3D renders, no autoloads run,
## no audio plays. The detached tree is queue_freed after extraction.

class HouseRecord extends RefCounted:
	var id: String          ## Matches Mail.correct_house_id, e.g. "house_891".
	var label: String       ## Number shown on the house, e.g. "891".
	var body_color: Color
	var roof_color: Color
	## Position along the street (world Z in the original 3D scene). The
	## sorting desk sorts houses by this so their left-to-right order in 2D
	## matches the 3D side-scroller's order.
	var sort_key: float = 0.0


class LevelData extends RefCounted:
	var level_name: String = ""
	var day_number: int = 1
	var houses: Array = []    ## [HouseRecord]
	var letters: Array = []   ## [Mail]


static func extract(level_path: String) -> LevelData:
	var data := LevelData.new()
	data.level_name = level_path.get_file().get_basename()

	var packed: PackedScene = load(level_path) as PackedScene
	if packed == null:
		push_warning("SortingLevelExtractor: could not load %s" % level_path)
		return data

	var root: Node = packed.instantiate()
	if root == null:
		return data

	# House + mailbox records are correlated by house_label, which both the
	# House and Mailbox nodes carry. We collect mailboxes first (they have
	# house_id, which is the key letters match against) and then walk houses.
	var mailboxes_by_label: Dictionary = {}
	var houses_by_label: Dictionary = {}
	_walk(root, mailboxes_by_label, houses_by_label)

	for label in houses_by_label.keys():
		var h_data: Dictionary = houses_by_label[label]
		var rec := HouseRecord.new()
		rec.label = label
		rec.body_color = h_data["body_color"]
		rec.roof_color = h_data["roof_color"]
		rec.sort_key = h_data["sort_key"]
		if mailboxes_by_label.has(label):
			rec.id = mailboxes_by_label[label]
		else:
			# Fall back to deriving the id from the label; keeps the puzzle
			# playable even if a level forgets to place a mailbox.
			rec.id = "house_%s" % label
		data.houses.append(rec)

	data.houses.sort_custom(func(a, b): return a.sort_key < b.sort_key)

	data.letters = _extract_letters(root)
	data.day_number = _extract_day_number(root)

	root.queue_free()
	return data


static func _walk(node: Node, mailboxes: Dictionary, houses: Dictionary) -> void:
	# Houses and mailboxes both expose `house_label`; houses additionally
	# carry `body_color`/`roof_color`, mailboxes additionally carry `house_id`.
	# We duck-type on the property set rather than importing the classes so a
	# level that uses a variant script still works.
	var label_v: Variant = _safe_get(node, "house_label")
	if typeof(label_v) == TYPE_STRING and not (label_v as String).is_empty():
		var label: String = label_v
		var house_id_v: Variant = _safe_get(node, "house_id")
		if typeof(house_id_v) == TYPE_STRING and not (house_id_v as String).is_empty():
			mailboxes[label] = house_id_v
		var body_v: Variant = _safe_get(node, "body_color")
		var roof_v: Variant = _safe_get(node, "roof_color")
		if typeof(body_v) == TYPE_COLOR and typeof(roof_v) == TYPE_COLOR:
			var sort_key := 0.0
			if node is Node3D:
				sort_key = (node as Node3D).transform.origin.z
			houses[label] = {
				"body_color": body_v,
				"roof_color": roof_v,
				"sort_key": sort_key,
			}
	for child in node.get_children():
		_walk(child, mailboxes, houses)


static func _extract_letters(root: Node) -> Array:
	var letters: Array = []
	var script: Script = root.get_script()
	if script == null:
		return letters
	var consts: Dictionary = script.get_script_constant_map()
	if not consts.has("LETTERS"):
		return letters
	var entries: Array = consts["LETTERS"]
	for data in entries:
		var m := Mail.new()
		m.id               = data.get("id", "")
		m.sender_name      = data.get("sender_name", "")
		m.recipient_name   = data.get("recipient_name", "")
		m.address_line     = data.get("address_line", "")
		m.message          = data.get("message", "")
		m.correct_house_id = data.get("correct_house_id", "")
		m.difficulty       = data.get("difficulty", 1)
		letters.append(m)
	return letters


static func _extract_day_number(root: Node) -> int:
	# Inferred from the level filename pattern neighborhood_XX_YY → day = XX * 10 + YY,
	# good enough for the summary panel's "Day N" line. Falls back to 1.
	var path := root.scene_file_path
	if path.is_empty():
		return 1
	var base := path.get_file().get_basename()  # e.g. "neighborhood_01_03"
	var parts := base.split("_")
	if parts.size() >= 3:
		var a := int(parts[parts.size() - 2])
		var b := int(parts[parts.size() - 1])
		return a * 10 + b
	return 1


static func _safe_get(node: Object, prop: String) -> Variant:
	# Guards against nodes that don't declare the property at all. Using
	# `in` checks the script + built-ins, avoiding the "Invalid get index"
	# error path.
	if prop in node:
		return node.get(prop)
	return null
