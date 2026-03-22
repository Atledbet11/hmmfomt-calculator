# scripts/farm_editor.gd
# Farm Grid Editor — paint tilled/obstacle/clear tiles on the 43x25 field.
# The farm map PNG is displayed as background; a grid overlay is drawn on top.
#
# FIELD ALIGNMENT:
#   FIELD_OFFSET is the pixel position within the farm map image where the
#   top-left corner of the farmable 43x25 grid begins.
#   This is an ESTIMATE and needs calibration — the user will help align it.
#   To calibrate: adjust FIELD_OFFSET until the grid lines match the in-game field borders.
extends Control

# ── Constants ──────────────────────────────────────────────────────────────────
const TILE_SIZE    : int     = 16
const FIELD_COLS   : int     = 43
const FIELD_ROWS   : int     = 25
# Estimated pixel offset from farm map top-left to field top-left corner.
# Needs calibration with the user.
const FIELD_OFFSET : Vector2 = Vector2(272.0, 176.0)

const SEASON_MAPS := {
	"spring": "res://assets/farm_maps/farm_spring.png",
	"summer": "res://assets/farm_maps/farm_summer.png",
	"fall":   "res://assets/farm_maps/farm_autumn.png",
	"winter": "res://assets/farm_maps/farm_winter.png",
}

const COL_TILLED   := Color(0.85, 0.72, 0.30, 0.55)
const COL_OBSTACLE := Color(0.65, 0.15, 0.15, 0.70)
const COL_HOVER    := Color(1.00, 1.00, 1.00, 0.30)
const COL_GRID     := Color(0.20, 0.20, 0.20, 0.35)
const COL_FIELD_BORDER := Color(0.90, 0.75, 0.20, 0.80)

const COL_BG_PANEL := Color(0.10, 0.25, 0.10, 0.95)
const COL_BTN      := Color(0.70, 0.52, 0.18)
const COL_BTN_HOV  := Color(0.88, 0.68, 0.24)

enum Tool { TILL, CLEAR, OBSTACLE }

# ── State ──────────────────────────────────────────────────────────────────────
var _tool       : Tool    = Tool.TILL
var _hover_tile : Vector2i = Vector2i(-1, -1)
var _is_painting: bool    = false
var _paint_mode : int     = -1  # 1 = add, 0 = remove (determined on mouse-down)

var _tilled    : Dictionary = {}   # Vector2i -> true
var _obstacles : Dictionary = {}   # Vector2i -> true

var _current_season: String = "spring"
var _blueprint_name: LineEdit

# ── Nodes ─────────────────────────────────────────────────────────────────────
var _map_texture  : TextureRect
var _grid_overlay : Control
var _scroll       : ScrollContainer
var _stats_label  : Label
var _season_option: OptionButton


func _ready() -> void:
	_load_from_app_state()
	_build_ui()


func _load_from_app_state() -> void:
	for t in AppState.active_tilled_tiles:
		_tilled[t] = true
	for t in AppState.active_obstacle_tiles:
		_obstacles[t] = true
	_current_season = AppState.active_season


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Root HBox: sidebar | map
	var root_hbox := HBoxContainer.new()
	root_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_hbox)

	# ── Left sidebar ──────────────────────────────────────────────────────────
	var sidebar := _make_sidebar()
	root_hbox.add_child(sidebar)

	# ── Map area ──────────────────────────────────────────────────────────────
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	root_hbox.add_child(_scroll)

	# Container for farm map + overlay (must be same size as the map image)
	var map_container := Control.new()
	map_container.custom_minimum_size = Vector2(1024, 704)
	_scroll.add_child(map_container)

	# Farm map background
	_map_texture = TextureRect.new()
	_map_texture.size = Vector2(1024, 704)
	_map_texture.stretch_mode = TextureRect.STRETCH_KEEP
	_map_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_container.add_child(_map_texture)
	_load_season_map()

	# Grid overlay (draws grid lines + tile colors, handles input)
	_grid_overlay = Control.new()
	_grid_overlay.size = Vector2(1024, 704)
	_grid_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_grid_overlay.draw.connect(_on_grid_draw)
	_grid_overlay.gui_input.connect(_on_grid_input)
	_grid_overlay.mouse_exited.connect(func():
		_hover_tile = Vector2i(-1, -1)
		_grid_overlay.queue_redraw()
	)
	map_container.add_child(_grid_overlay)


func _make_sidebar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = COL_BG_PANEL
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	_add_label(vbox, "Farm Blueprint Editor", 15, Color(0.98, 0.95, 0.60))
	vbox.add_child(HSeparator.new())

	# Season selector
	_add_label(vbox, "Season", 12, Color(0.80, 0.80, 0.60))
	_season_option = OptionButton.new()
	for s in ["spring", "summer", "fall", "winter"]:
		_season_option.add_item(s.capitalize())
	_season_option.selected = ["spring","summer","fall","winter"].find(_current_season)
	_season_option.item_selected.connect(_on_season_changed)
	vbox.add_child(_season_option)

	vbox.add_child(HSeparator.new())

	# Tool selector
	_add_label(vbox, "Tool", 12, Color(0.80, 0.80, 0.60))
	var tool_option := OptionButton.new()
	tool_option.add_item("Till Soil")
	tool_option.add_item("Clear Tile")
	tool_option.add_item("Mark Obstacle")
	tool_option.item_selected.connect(func(idx): _tool = idx as Tool)
	vbox.add_child(tool_option)

	_add_label(vbox, "Left-click to paint  |  Right-click to clear", 10,
			Color(0.65, 0.80, 0.65))

	vbox.add_child(HSeparator.new())

	# Blueprint name
	_add_label(vbox, "Blueprint Name", 12, Color(0.80, 0.80, 0.60))
	_blueprint_name = LineEdit.new()
	_blueprint_name.placeholder_text = "My Farm"
	_blueprint_name.text = AppState.active_blueprint_name
	vbox.add_child(_blueprint_name)

	vbox.add_child(_make_button("Save Blueprint", _save_blueprint))
	vbox.add_child(_make_button("Load Blueprint...", _show_load_dialog))
	vbox.add_child(_make_button("Clear All Tiles", _clear_all))

	vbox.add_child(HSeparator.new())

	# Stats
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 11)
	_stats_label.add_theme_color_override("font_color", Color(0.80, 0.90, 0.70))
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_stats_label)
	_update_stats()

	# Fill remaining space
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_button("← Back to Menu", func():
		_push_to_app_state()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	))

	return panel


func _load_season_map() -> void:
	var path: String = SEASON_MAPS.get(_current_season, SEASON_MAPS["spring"])
	var tex := load(path) as Texture2D
	if tex:
		_map_texture.texture = tex


func _on_season_changed(idx: int) -> void:
	_current_season = ["spring", "summer", "fall", "winter"][idx]
	_load_season_map()


# ── Drawing ────────────────────────────────────────────────────────────────────

func _on_grid_draw() -> void:
	var overlay := _grid_overlay

	# Draw tilled tiles
	for tile in _tilled:
		var r := _tile_rect(tile)
		overlay.draw_rect(r, COL_TILLED)

	# Draw obstacle tiles
	for tile in _obstacles:
		var r := _tile_rect(tile)
		overlay.draw_rect(r, COL_OBSTACLE)

	# Draw hover
	if _hover_tile.x >= 0:
		overlay.draw_rect(_tile_rect(_hover_tile), COL_HOVER)

	# Draw grid lines over the field
	for col in range(FIELD_COLS + 1):
		var x := FIELD_OFFSET.x + col * TILE_SIZE
		overlay.draw_line(
			Vector2(x, FIELD_OFFSET.y),
			Vector2(x, FIELD_OFFSET.y + FIELD_ROWS * TILE_SIZE),
			COL_GRID, 1.0
		)
	for row in range(FIELD_ROWS + 1):
		var y := FIELD_OFFSET.y + row * TILE_SIZE
		overlay.draw_line(
			Vector2(FIELD_OFFSET.x, y),
			Vector2(FIELD_OFFSET.x + FIELD_COLS * TILE_SIZE, y),
			COL_GRID, 1.0
		)

	# Draw field border
	var field_rect := Rect2(
		FIELD_OFFSET,
		Vector2(FIELD_COLS * TILE_SIZE, FIELD_ROWS * TILE_SIZE)
	)
	overlay.draw_rect(field_rect, COL_FIELD_BORDER, false, 2.0)


func _tile_rect(tile: Vector2i) -> Rect2:
	return Rect2(
		FIELD_OFFSET + Vector2(tile.x * TILE_SIZE, tile.y * TILE_SIZE),
		Vector2(TILE_SIZE, TILE_SIZE)
	)


func _pixel_to_tile(pos: Vector2) -> Vector2i:
	var local := pos - FIELD_OFFSET
	var col := int(local.x / TILE_SIZE)
	var row := int(local.y / TILE_SIZE)
	return Vector2i(col, row)


func _tile_in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < FIELD_COLS and tile.y >= 0 and tile.y < FIELD_ROWS


# ── Input ──────────────────────────────────────────────────────────────────────

func _on_grid_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var tile := _pixel_to_tile(event.position)
		if _tile_in_bounds(tile):
			_hover_tile = tile
		else:
			_hover_tile = Vector2i(-1, -1)

		if _is_painting and _hover_tile.x >= 0:
			_apply_paint(_hover_tile)

		_grid_overlay.queue_redraw()

	elif event is InputEventMouseButton:
		var tile := _pixel_to_tile(event.position)
		if not _tile_in_bounds(tile):
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_painting = true
				# If tile already has the painted state, treat as remove
				_paint_mode = 0 if _tile_has_tool_state(tile) else 1
				_apply_paint(tile)
			else:
				_is_painting = false

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Right-click always clears
			_tilled.erase(tile)
			_obstacles.erase(tile)
			_update_stats()
			_grid_overlay.queue_redraw()


func _tile_has_tool_state(tile: Vector2i) -> bool:
	match _tool:
		Tool.TILL:     return _tilled.has(tile)
		Tool.OBSTACLE: return _obstacles.has(tile)
		Tool.CLEAR:    return not _tilled.has(tile) and not _obstacles.has(tile)
	return false


func _apply_paint(tile: Vector2i) -> void:
	match _tool:
		Tool.TILL:
			if _paint_mode == 1:
				_tilled[tile] = true
				_obstacles.erase(tile)
			else:
				_tilled.erase(tile)
		Tool.OBSTACLE:
			if _paint_mode == 1:
				_obstacles[tile] = true
				_tilled.erase(tile)
			else:
				_obstacles.erase(tile)
		Tool.CLEAR:
			_tilled.erase(tile)
			_obstacles.erase(tile)
	_update_stats()
	_grid_overlay.queue_redraw()


# ── Save / Load / Clear ────────────────────────────────────────────────────────

func _save_blueprint() -> void:
	var name := _blueprint_name.text.strip_edges()
	if name.is_empty():
		name = "Unnamed Blueprint"
		_blueprint_name.text = name
	var tilled_arr   := _tilled.keys()
	var obstacle_arr := _obstacles.keys()
	BlueprintManager.save_blueprint(name, tilled_arr, obstacle_arr)
	_push_to_app_state()
	_update_stats()


func _show_load_dialog() -> void:
	var names := BlueprintManager.list_blueprints()
	if names.is_empty():
		return
	# Simple popup with list of saved blueprints
	var dialog := AcceptDialog.new()
	dialog.title = "Load Blueprint"
	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)
	for bp_name in names:
		var btn := Button.new()
		btn.text = bp_name
		btn.pressed.connect(func():
			_do_load(bp_name)
			dialog.queue_free()
		)
		vbox.add_child(btn)
	add_child(dialog)
	dialog.popup_centered(Vector2(300, 200))


func _do_load(bp_name: String) -> void:
	var data := BlueprintManager.load_blueprint(bp_name)
	if data.is_empty():
		return
	_blueprint_name.text = data.name
	_tilled = {}
	_obstacles = {}
	for t in data.tilled_tiles:
		_tilled[t] = true
	for t in data.obstacle_tiles:
		_obstacles[t] = true
	_push_to_app_state()
	_update_stats()
	_grid_overlay.queue_redraw()


func _clear_all() -> void:
	_tilled = {}
	_obstacles = {}
	_update_stats()
	_grid_overlay.queue_redraw()


func _push_to_app_state() -> void:
	AppState.set_blueprint(
		_blueprint_name.text.strip_edges(),
		_tilled.keys(),
		_obstacles.keys()
	)


# ── Helpers ────────────────────────────────────────────────────────────────────

func _update_stats() -> void:
	if _stats_label == null:
		return
	var total   := FIELD_COLS * FIELD_ROWS
	var tilled  := _tilled.size()
	var blocked := _obstacles.size()
	var free    := total - tilled - blocked
	_stats_label.text = (
		"Field: %dx%d (%d tiles)\n" % [FIELD_COLS, FIELD_ROWS, total] +
		"Tilled:    %d\n" % tilled +
		"Obstacles: %d\n" % blocked +
		"Empty:     %d\n" % free +
		"\n[Calibration]\nFIELD_OFFSET = %s\nTILE_SIZE = %d" % [str(FIELD_OFFSET), TILE_SIZE]
	)


func _add_label(parent: Control, text: String, size: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)


func _make_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 36)
	btn.pressed.connect(callback)
	return btn
