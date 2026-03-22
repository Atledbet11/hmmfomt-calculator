# core/blueprint_manager.gd
# Autoloaded as BlueprintManager
# Handles saving and loading Farm Blueprints and Season Plans to/from JSON files.
extends Node

const SAVE_DIR: String = "user://saves/"
const BLUEPRINT_EXT: String = ".blueprint.json"
const PLAN_EXT: String = ".plan.json"

signal blueprint_saved(name: String)
signal blueprint_loaded(name: String)
signal plan_saved(name: String)
signal plan_loaded(name: String)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


# ── Farm Blueprint ─────────────────────────────────────────────────────────────
# Blueprint format:
# {
#   "version": 1,
#   "name": String,
#   "tilled_tiles": [[col, row], ...],
#   "obstacle_tiles": [[col, row], ...],
# }

func save_blueprint(blueprint_name: String, tilled_tiles: Array, obstacle_tiles: Array) -> bool:
	var data: Dictionary = {
		"version": 1,
		"name": blueprint_name,
		"tilled_tiles": _vec2i_array_to_json(tilled_tiles),
		"obstacle_tiles": _vec2i_array_to_json(obstacle_tiles),
	}
	return _write_json(SAVE_DIR + _safe_name(blueprint_name) + BLUEPRINT_EXT, data)


func load_blueprint(blueprint_name: String) -> Dictionary:
	var data = _read_json(SAVE_DIR + _safe_name(blueprint_name) + BLUEPRINT_EXT)
	if data.is_empty():
		return {}
	return {
		"name": data.get("name", blueprint_name),
		"tilled_tiles": _json_to_vec2i_array(data.get("tilled_tiles", [])),
		"obstacle_tiles": _json_to_vec2i_array(data.get("obstacle_tiles", [])),
	}


func list_blueprints() -> Array:
	return _list_files(BLUEPRINT_EXT)


func delete_blueprint(blueprint_name: String) -> void:
	DirAccess.remove_absolute(SAVE_DIR + _safe_name(blueprint_name) + BLUEPRINT_EXT)


# ── Season Plan ────────────────────────────────────────────────────────────────
# Plan format:
# {
#   "version": 1,
#   "name": String,
#   "season": String,
#   "blueprint_name": String,
#   "entries": [
#     { "crop_id": String, "plant_day": int, "tile": [col, row] },
#     ...
#   ]
# }

func save_plan(plan_name: String, season: String, blueprint_name: String, entries: Array) -> bool:
	var json_entries: Array = []
	for e in entries:
		json_entries.append({
			"crop_id": e.crop_id,
			"plant_day": e.plant_day,
			"tile": [e.tile.x, e.tile.y],
		})
	var data: Dictionary = {
		"version": 1,
		"name": plan_name,
		"season": season,
		"blueprint_name": blueprint_name,
		"entries": json_entries,
	}
	return _write_json(SAVE_DIR + _safe_name(plan_name) + PLAN_EXT, data)


func load_plan(plan_name: String) -> Dictionary:
	var data = _read_json(SAVE_DIR + _safe_name(plan_name) + PLAN_EXT)
	if data.is_empty():
		return {}
	var entries: Array = []
	for e in data.get("entries", []):
		entries.append({
			"crop_id": e.get("crop_id", ""),
			"plant_day": e.get("plant_day", 1),
			"tile": Vector2i(e.get("tile", [0, 0])[0], e.get("tile", [0, 0])[1]),
		})
	return {
		"name": data.get("name", plan_name),
		"season": data.get("season", "spring"),
		"blueprint_name": data.get("blueprint_name", ""),
		"entries": entries,
	}


func list_plans() -> Array:
	return _list_files(PLAN_EXT)


func delete_plan(plan_name: String) -> void:
	DirAccess.remove_absolute(SAVE_DIR + _safe_name(plan_name) + PLAN_EXT)


# ── Internal helpers ───────────────────────────────────────────────────────────

func _write_json(path: String, data: Dictionary) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("BlueprintManager: could not open for writing: " + path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	var result = JSON.parse_string(text)
	if result is Dictionary:
		return result
	return {}


func _list_files(extension: String) -> Array:
	var names: Array = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		return names
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(extension):
			names.append(fname.trim_suffix(extension))
		fname = dir.get_next()
	return names


func _safe_name(s: String) -> String:
	return s.replace(" ", "_").replace("/", "_").replace("\\", "_")


func _vec2i_array_to_json(tiles: Array) -> Array:
	var result: Array = []
	for t in tiles:
		result.append([t.x, t.y])
	return result


func _json_to_vec2i_array(data: Array) -> Array:
	var result: Array = []
	for item in data:
		if item is Array and item.size() >= 2:
			result.append(Vector2i(item[0], item[1]))
	return result
