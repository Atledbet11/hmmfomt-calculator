# core/app_state.gd
# Autoloaded as AppState
# Holds the current working state of the app across scene transitions.
extends Node

# ── Current farm blueprint being worked on ────────────────────────────────────
var active_blueprint_name: String = ""
var active_tilled_tiles: Array = []    # Array of Vector2i
var active_obstacle_tiles: Array = []  # Array of Vector2i

# ── Current season plan being worked on ──────────────────────────────────────
var active_plan_name: String = ""
var active_season: String = "spring"   # "spring" | "summer" | "fall"
var active_plan_entries: Array = []    # Array of { crop_id, plant_day, tile: Vector2i }

# ── Navigation helpers ────────────────────────────────────────────────────────
# Set before navigating to crop_reference so the Back button returns correctly.
var crop_reference_back_scene: String = "res://scenes/main_menu.tscn"

# ── Sprite friendship levels (persisted in memory, saved with plans later) ───
# Dict: sprite_id -> hearts (0–10)
var sprite_hearts: Dictionary = {
	"bold": 0, "staid": 0, "aqua": 0,
	"timid": 0, "hoggy": 0, "chef": 0, "nappy": 0,
}

# ── Signals ───────────────────────────────────────────────────────────────────
signal blueprint_changed()
signal plan_changed()
signal season_changed(new_season: String)


# ── Blueprint helpers ──────────────────────────────────────────────────────────

func set_blueprint(name: String, tilled: Array, obstacles: Array) -> void:
	active_blueprint_name = name
	active_tilled_tiles = tilled.duplicate()
	active_obstacle_tiles = obstacles.duplicate()
	emit_signal("blueprint_changed")


func clear_blueprint() -> void:
	active_blueprint_name = ""
	active_tilled_tiles = []
	active_obstacle_tiles = []
	emit_signal("blueprint_changed")


func is_tilled(tile: Vector2i) -> bool:
	return tile in active_tilled_tiles


func is_obstacle(tile: Vector2i) -> bool:
	return tile in active_obstacle_tiles


# ── Season plan helpers ────────────────────────────────────────────────────────

func set_season(season: String) -> void:
	if active_season != season:
		active_season = season
		active_plan_entries = []
		emit_signal("season_changed", season)
		emit_signal("plan_changed")


func set_plan(name: String, season: String, entries: Array) -> void:
	active_plan_name = name
	active_season = season
	active_plan_entries = entries.duplicate()
	emit_signal("plan_changed")


func upsert_plan_entry(tile: Vector2i, crop_id: String, plant_day: int) -> void:
	for i in range(active_plan_entries.size()):
		if active_plan_entries[i].tile == tile:
			active_plan_entries[i].crop_id = crop_id
			active_plan_entries[i].plant_day = plant_day
			emit_signal("plan_changed")
			return
	active_plan_entries.append({
		"crop_id": crop_id,
		"plant_day": plant_day,
		"tile": tile,
	})
	emit_signal("plan_changed")


func remove_plan_entry(tile: Vector2i) -> void:
	for i in range(active_plan_entries.size()):
		if active_plan_entries[i].tile == tile:
			active_plan_entries.remove_at(i)
			emit_signal("plan_changed")
			return


func get_plan_entry(tile: Vector2i) -> Dictionary:
	for e in active_plan_entries:
		if e.tile == tile:
			return e
	return {}


func clear_plan() -> void:
	active_plan_name = ""
	active_plan_entries = []
	emit_signal("plan_changed")


# ── Sprite helpers ─────────────────────────────────────────────────────────────

func set_sprite_hearts(sprite_id: String, hearts: int) -> void:
	sprite_hearts[sprite_id] = clampi(hearts, 0, SpritesData.MAX_HEARTS)


func get_sprite_hearts(sprite_id: String) -> int:
	return sprite_hearts.get(sprite_id, 0)


func get_hireable_sprites() -> Array:
	var result: Array = []
	for id in sprite_hearts:
		if SpritesData.can_hire(sprite_hearts[id]):
			result.append(id)
	return result
