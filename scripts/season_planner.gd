# scripts/season_planner.gd
# Season Planner — assign crops + plant days to tilled tiles.
extends Control

const TILE_SIZE    : int     = 16
const FIELD_COLS   : int     = 43
const FIELD_ROWS   : int     = 25
const FIELD_OFFSET : Vector2 = Vector2(272.0, 176.0)

const SEASON_MAPS := {
	"spring": "res://assets/farm_maps/farm_spring.png",
	"summer": "res://assets/farm_maps/farm_summer.png",
	"fall":   "res://assets/farm_maps/farm_autumn.png",
}

const COL_TILLED      := Color(0.85, 0.72, 0.30, 0.30)
const COL_TILE_BORDER := Color(1.00, 1.00, 1.00, 0.55)
const COL_HOVER       := Color(1.00, 1.00, 1.00, 0.30)
const COL_GRID        := Color(0.20, 0.20, 0.20, 0.28)
const COL_BG_PANEL    := Color(0.10, 0.25, 0.10, 0.95)

var _hover_tile      : Vector2i    = Vector2i(-1, -1)
var _grid_overlay    : Control
var _map_texture     : TextureRect
var _side_list       : VBoxContainer
var _plan_name_edit  : LineEdit
var _season_option   : OptionButton
var _current_season  : String      = "spring"

# Paint brush
var _paint_active    : bool   = false
var _paint_crop_id   : String = ""
var _paint_plant_day : int    = 1
var _is_painting     : bool   = false
var _batch_painting  : bool   = false  # suppresses side list rebuild during drag
var _crop_dropdown   : OptionButton
var _day_spin        : SpinBox
var _crop_id_list    : Array  = []
var _holiday_label   : Label


func _ready() -> void:
	_current_season = AppState.active_season
	_build_ui()
	AppState.plan_changed.connect(_on_plan_changed_external)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root_hbox := HBoxContainer.new()
	root_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_hbox)

	root_hbox.add_child(_make_sidebar())

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	root_hbox.add_child(scroll)

	var map_container := Control.new()
	map_container.custom_minimum_size = Vector2(1024, 704)
	scroll.add_child(map_container)

	_map_texture = TextureRect.new()
	_map_texture.size = Vector2(1024, 704)
	_map_texture.stretch_mode = TextureRect.STRETCH_KEEP
	_map_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_container.add_child(_map_texture)
	_load_season_map()

	_grid_overlay = Control.new()
	_grid_overlay.size = Vector2(1024, 704)
	_grid_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_grid_overlay.draw.connect(_on_grid_draw)
	_grid_overlay.gui_input.connect(_on_grid_input)
	_grid_overlay.mouse_exited.connect(func():
		_hover_tile = Vector2i(-1, -1)
		_finish_painting()
		_grid_overlay.queue_redraw()
	)
	map_container.add_child(_grid_overlay)


func _make_sidebar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(264, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = COL_BG_PANEL
	panel.add_theme_stylebox_override("panel", style)

	var outer := ScrollContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(vbox)

	_add_label(vbox, "Season Planner", 15, Color(0.98, 0.95, 0.60))
	vbox.add_child(HSeparator.new())

	# ── Season ────────────────────────────────────────────────────────────────
	_add_label(vbox, "Season", 11, Color(0.80, 0.80, 0.60))
	_season_option = OptionButton.new()
	for s in ["spring", "summer", "fall"]:
		_season_option.add_item(s.capitalize())
	_season_option.selected = ["spring", "summer", "fall"].find(_current_season)
	_season_option.item_selected.connect(_on_season_changed)
	vbox.add_child(_season_option)

	vbox.add_child(HSeparator.new())

	# ── Blueprint ─────────────────────────────────────────────────────────────
	_add_label(vbox, "Farm Blueprint", 11, Color(0.80, 0.80, 0.60))

	var bp_name_lbl := Label.new()
	bp_name_lbl.add_theme_font_size_override("font_size", 10)
	bp_name_lbl.add_theme_color_override("font_color", Color(0.65, 0.80, 0.65))
	bp_name_lbl.text = AppState.active_blueprint_name if AppState.active_blueprint_name != "" else "(none loaded)"
	bp_name_lbl.name = "BpNameLabel"
	vbox.add_child(bp_name_lbl)

	vbox.add_child(_make_button("Load Blueprint...", func(): _show_blueprint_dialog(bp_name_lbl)))

	vbox.add_child(HSeparator.new())

	# ── Plan save / load ──────────────────────────────────────────────────────
	_add_label(vbox, "Season Plan", 11, Color(0.80, 0.80, 0.60))
	_plan_name_edit = LineEdit.new()
	_plan_name_edit.placeholder_text = "My Season Plan"
	_plan_name_edit.text = AppState.active_plan_name
	vbox.add_child(_plan_name_edit)
	vbox.add_child(_make_button("Save Plan", _save_plan))
	vbox.add_child(_make_button("Load Plan...", _show_load_dialog))
	vbox.add_child(_make_button("Clear All Crops", func():
		AppState.clear_plan()
		_grid_overlay.queue_redraw()
	))

	vbox.add_child(HSeparator.new())

	# ── Paint Brush ───────────────────────────────────────────────────────────
	_add_label(vbox, "Paint Brush", 12, Color(0.98, 0.90, 0.50))

	var paint_toggle := CheckButton.new()
	paint_toggle.text = "Paint Mode"
	paint_toggle.add_theme_font_size_override("font_size", 11)
	paint_toggle.toggled.connect(func(on: bool): _paint_active = on)
	vbox.add_child(paint_toggle)

	_add_label(vbox, "Crop", 11, Color(0.75, 0.80, 0.65))
	_crop_dropdown = OptionButton.new()
	_crop_dropdown.add_theme_font_size_override("font_size", 11)
	_populate_crop_dropdown()
	_crop_dropdown.item_selected.connect(func(idx: int):
		_paint_crop_id = _get_crop_id_at(idx)
		_update_holiday_preview()
	)
	vbox.add_child(_crop_dropdown)

	_add_label(vbox, "Plant Day", 11, Color(0.75, 0.80, 0.65))
	_day_spin = SpinBox.new()
	_day_spin.min_value = 1
	_day_spin.max_value = 30
	_day_spin.value = 1
	_day_spin.value_changed.connect(func(v: float):
		_paint_plant_day = int(v)
		_update_holiday_preview()
	)
	vbox.add_child(_day_spin)

	# Holiday preview
	_holiday_label = Label.new()
	_holiday_label.add_theme_font_size_override("font_size", 10)
	_holiday_label.add_theme_color_override("font_color", Color(0.80, 0.88, 0.72))
	_holiday_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_holiday_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_holiday_label)
	_update_holiday_preview()

	_add_label(vbox, "Right-click tile to remove", 10, Color(0.55, 0.65, 0.50))

	vbox.add_child(HSeparator.new())

	# ── Legend ────────────────────────────────────────────────────────────────
	_add_label(vbox, "Legend", 11, Color(0.80, 0.80, 0.60))
	_add_legend_row(vbox, Color(0.85, 0.15, 0.15, 0.65), "Blocking festival")
	_add_legend_row(vbox, Color(0.95, 0.75, 0.10, 0.55), "Morning-safe festival")
	_add_legend_row(vbox, Color(0.90, 0.50, 0.10, 0.55), "Risky festival")

	vbox.add_child(HSeparator.new())

	# ── Planted crops list ────────────────────────────────────────────────────
	_add_label(vbox, "Planted Crops", 11, Color(0.80, 0.80, 0.60))
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.custom_minimum_size = Vector2(0, 80)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(list_scroll)

	_side_list = VBoxContainer.new()
	_side_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_side_list)
	_refresh_side_list()

	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_button("View Calendar →", func():
		get_tree().change_scene_to_file("res://scenes/calendar_view.tscn")
	))
	vbox.add_child(_make_button("← Back to Menu", func():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	))

	return panel


# ── Crop dropdown ──────────────────────────────────────────────────────────────

func _populate_crop_dropdown() -> void:
	_crop_id_list = []
	_crop_dropdown.clear()
	var season_crops := CropsData.get_season_crops(_current_season)
	var ids: Array = season_crops.keys()
	ids.sort()
	for cid in ids:
		_crop_id_list.append(cid)
		_crop_dropdown.add_item(season_crops[cid].name)
	_paint_crop_id = _crop_id_list[0] if _crop_id_list.size() > 0 else ""


func _get_crop_id_at(idx: int) -> String:
	if idx >= 0 and idx < _crop_id_list.size():
		return _crop_id_list[idx]
	return ""


# ── Holiday preview ────────────────────────────────────────────────────────────

func _update_holiday_preview() -> void:
	if _holiday_label == null or _paint_crop_id.is_empty():
		if _holiday_label != null:
			_holiday_label.text = ""
		return

	var hdays := Calculator.get_harvest_days(_paint_crop_id, _paint_plant_day)
	if hdays.is_empty():
		_holiday_label.text = "No harvest before Day 30."
		_holiday_label.add_theme_color_override("font_color", Color(0.80, 0.55, 0.55))
		return

	var lines: Array = []
	lines.append("Harvests: " + ", ".join(hdays.map(func(d: int) -> String: return "D" + str(d))))

	var conflicts: Array = []
	for hd in hdays:
		var festival := HolidaysData.get_festival(_current_season, hd)
		if not festival.is_empty():
			var ft: String = festival.get("type", "")
			var icon := "🔴" if ft == "blocking" else ("🟡" if ft == "morning_safe" else "🟠")
			conflicts.append("%s D%d %s" % [icon, hd, festival.get("name", "")])

	if conflicts.is_empty():
		lines.append("✓ No festival conflicts")
		_holiday_label.add_theme_color_override("font_color", Color(0.60, 0.88, 0.60))
	else:
		lines.append("Conflicts:")
		lines.append_array(conflicts)
		_holiday_label.add_theme_color_override("font_color", Color(0.95, 0.80, 0.45))

	_holiday_label.text = "\n".join(lines)


# ── Season map ────────────────────────────────────────────────────────────────

func _load_season_map() -> void:
	var path: String = SEASON_MAPS.get(_current_season, SEASON_MAPS["spring"])
	var tex := load(path) as Texture2D
	if tex:
		_map_texture.texture = tex


func _on_season_changed(idx: int) -> void:
	_current_season = ["spring", "summer", "fall"][idx]
	AppState.set_season(_current_season)
	_populate_crop_dropdown()
	_update_holiday_preview()
	_load_season_map()
	_grid_overlay.queue_redraw()


# ── Drawing ────────────────────────────────────────────────────────────────────

func _on_grid_draw() -> void:
	var o := _grid_overlay

	# Tilled tile fills + borders
	for tile in AppState.active_tilled_tiles:
		if AppState.get_plan_entry(tile).is_empty():
			o.draw_rect(_tile_rect(tile), COL_TILLED)
		o.draw_rect(_tile_rect(tile), COL_TILE_BORDER, false, 1.0)

	# Assigned tiles: crop color + conflict overlay + plant day label
	for entry in AppState.active_plan_entries:
		var tile: Vector2i = entry.tile
		var crop := CropsData.get_crop(entry.crop_id)
		if crop.is_empty():
			continue
		var col: Color = crop.color
		col.a = 0.80
		o.draw_rect(_tile_rect(tile), col)

		var harvest_days := Calculator.get_harvest_days(entry.crop_id, entry.plant_day)
		for hd in harvest_days:
			if HolidaysData.get_festival_type(_current_season, hd) == "blocking":
				o.draw_rect(_tile_rect(tile), Color(0.85, 0.15, 0.15, 0.30))
				break

		var rect := _tile_rect(tile)
		o.draw_string(
			ThemeDB.fallback_font,
			rect.position + Vector2(2, TILE_SIZE - 3),
			str(entry.plant_day),
			HORIZONTAL_ALIGNMENT_LEFT,
			TILE_SIZE, 8,
			Color(1, 1, 1, 0.90)
		)
		o.draw_rect(_tile_rect(tile), COL_TILE_BORDER, false, 1.0)

	# Hover
	if _hover_tile.x >= 0 and AppState.is_tilled(_hover_tile):
		o.draw_rect(_tile_rect(_hover_tile), COL_HOVER)

	# Paint preview under cursor
	if _paint_active and _hover_tile.x >= 0 and not _paint_crop_id.is_empty():
		var crop := CropsData.get_crop(_paint_crop_id)
		if not crop.is_empty():
			var preview: Color = crop.color
			preview.a = 0.50
			o.draw_rect(_tile_rect(_hover_tile), preview)

	# Grid lines
	for col in range(FIELD_COLS + 1):
		var x := FIELD_OFFSET.x + col * TILE_SIZE
		o.draw_line(
			Vector2(x, FIELD_OFFSET.y),
			Vector2(x, FIELD_OFFSET.y + FIELD_ROWS * TILE_SIZE),
			COL_GRID, 1.0
		)
	for row in range(FIELD_ROWS + 1):
		var y := FIELD_OFFSET.y + row * TILE_SIZE
		o.draw_line(
			Vector2(FIELD_OFFSET.x, y),
			Vector2(FIELD_OFFSET.x + FIELD_COLS * TILE_SIZE, y),
			COL_GRID, 1.0
		)


func _tile_rect(tile: Vector2i) -> Rect2:
	return Rect2(
		FIELD_OFFSET + Vector2(tile.x * TILE_SIZE, tile.y * TILE_SIZE),
		Vector2(TILE_SIZE, TILE_SIZE)
	)


func _pixel_to_tile(pos: Vector2) -> Vector2i:
	var local := pos - FIELD_OFFSET
	return Vector2i(int(local.x / TILE_SIZE), int(local.y / TILE_SIZE))


func _tile_in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < FIELD_COLS and tile.y >= 0 and tile.y < FIELD_ROWS


# ── Input ──────────────────────────────────────────────────────────────────────

func _on_grid_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var tile := _pixel_to_tile(event.position)
		_hover_tile = tile if _tile_in_bounds(tile) and AppState.is_tilled(tile) else Vector2i(-1, -1)

		if _is_painting and _paint_active and _hover_tile.x >= 0:
			_apply_paint_silent(_hover_tile)

		_grid_overlay.queue_redraw()

	elif event is InputEventMouseButton:
		var tile := _pixel_to_tile(event.position)

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _tile_in_bounds(tile) and AppState.is_tilled(tile):
					if _paint_active and not _paint_crop_id.is_empty():
						_is_painting = true
						_batch_painting = true
						_apply_paint_silent(tile)
					else:
						_open_crop_picker(tile)
			else:
				_finish_painting()

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _tile_in_bounds(tile):
				AppState.remove_plan_entry(tile)
				_grid_overlay.queue_redraw()


# Directly writes into AppState without emitting plan_changed.
# Called on every mouse-move during drag — avoids rebuilding the side list
# node tree on every event. _finish_painting() does the single end-of-stroke refresh.
func _apply_paint_silent(tile: Vector2i) -> void:
	if _paint_crop_id.is_empty():
		return
	var entries := AppState.active_plan_entries
	for i in range(entries.size()):
		if entries[i].tile == tile:
			if entries[i].crop_id == _paint_crop_id and entries[i].plant_day == _paint_plant_day:
				return  # already painted, skip redraw entirely
			entries[i].crop_id   = _paint_crop_id
			entries[i].plant_day = _paint_plant_day
			_grid_overlay.queue_redraw()
			return
	AppState.active_plan_entries.append({
		"crop_id":   _paint_crop_id,
		"plant_day": _paint_plant_day,
		"tile":      tile,
	})
	_grid_overlay.queue_redraw()


func _finish_painting() -> void:
	if not _is_painting:
		return
	_is_painting = false
	_batch_painting = false
	# Single refresh now that the stroke is done
	_refresh_side_list()
	AppState.emit_signal("plan_changed")


# ── Crop picker dialog (click / non-paint mode) ────────────────────────────────

func _open_crop_picker(tile: Vector2i) -> void:
	var existing := AppState.get_plan_entry(tile)
	var season_crops := CropsData.get_season_crops(_current_season)

	var dialog := Window.new()
	dialog.title = "Assign Crop — Tile (%d, %d)" % [tile.x, tile.y]
	dialog.size = Vector2i(360, 380)
	dialog.exclusive = true
	add_child(dialog)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var crop_option := OptionButton.new()
	var crop_ids: Array = season_crops.keys()
	crop_ids.sort()
	var sel_idx := 0
	for i in range(crop_ids.size()):
		var cid: String = crop_ids[i]
		crop_option.add_item(season_crops[cid].name)
		if cid == existing.get("crop_id", ""):
			sel_idx = i
	crop_option.selected = sel_idx
	vbox.add_child(_small_label("Crop:"))
	vbox.add_child(crop_option)

	var day_spin := SpinBox.new()
	day_spin.min_value = 1
	day_spin.max_value = 30
	day_spin.value = existing.get("plant_day", 1)
	vbox.add_child(_small_label("Plant Day:"))
	vbox.add_child(day_spin)

	var info_lbl := Label.new()
	info_lbl.add_theme_font_size_override("font_size", 11)
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_lbl)

	var refresh := func():
		var cid: String = crop_ids[crop_option.selected]
		var pd := int(day_spin.value)
		var hdays := Calculator.get_harvest_days(cid, pd)
		var lines := ["Harvests: %d  |  First: Day %s" % [
			hdays.size(),
			str(hdays[0]) if hdays.size() > 0 else "—"
		]]
		for hd in hdays:
			var f := HolidaysData.get_festival(_current_season, hd)
			if not f.is_empty():
				lines.append("⚠ Day %d — %s" % [hd, f.get("name", "")])
		info_lbl.text = "\n".join(lines)

	crop_option.item_selected.connect(func(_i): refresh.call())
	day_spin.value_changed.connect(func(_v): refresh.call())
	refresh.call()

	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)

	var ok := Button.new()
	ok.text = "Assign"
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func():
		var cid: String = crop_ids[crop_option.selected]
		AppState.upsert_plan_entry(tile, cid, int(day_spin.value))
		_grid_overlay.queue_redraw()
		dialog.queue_free()
	)
	hbox.add_child(ok)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func(): dialog.queue_free())
	hbox.add_child(cancel)

	if not existing.is_empty():
		var remove := Button.new()
		remove.text = "Remove Crop"
		remove.pressed.connect(func():
			AppState.remove_plan_entry(tile)
			_grid_overlay.queue_redraw()
			dialog.queue_free()
		)
		vbox.add_child(remove)

	dialog.popup_centered()


# ── Side list ─────────────────────────────────────────────────────────────────

func _on_plan_changed_external() -> void:
	# Called by AppState.plan_changed signal.
	# Skip during batch painting — _finish_painting handles the refresh.
	if _batch_painting:
		return
	_refresh_side_list()


func _refresh_side_list() -> void:
	if _side_list == null:
		return
	for child in _side_list.get_children():
		child.queue_free()

	var entries := AppState.active_plan_entries
	if entries.is_empty():
		var lbl := Label.new()
		lbl.text = "No crops planted yet."
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.60, 0.75, 0.60))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_side_list.add_child(lbl)
		return

	# Aggregate by crop_id + plant_day for a compact summary
	var summary: Dictionary = {}
	for entry in entries:
		var key := entry.crop_id + "|" + str(entry.plant_day)
		if not summary.has(key):
			summary[key] = {"crop_id": entry.crop_id, "plant_day": entry.plant_day, "count": 0}
		summary[key].count += 1

	for key: String in summary:
		var row: Dictionary = summary[key]
		var crop := CropsData.get_crop(row.crop_id)
		if crop.is_empty():
			continue
		var hdays := Calculator.get_harvest_days(row.crop_id, row.plant_day)
		var lbl := Label.new()
		lbl.text = "%s × %d  D%d → %d×" % [crop.name, row.count, row.plant_day, hdays.size()]
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", (crop.color as Color).lightened(0.3))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_side_list.add_child(lbl)


# ── Blueprint loader ───────────────────────────────────────────────────────────

func _show_blueprint_dialog(name_label: Label) -> void:
	var names := BlueprintManager.list_blueprints()

	var dialog := AcceptDialog.new()
	dialog.title = "Load Farm Blueprint"

	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)

	if names.is_empty():
		var lbl := Label.new()
		lbl.text = "No saved blueprints found.\nCreate one in the Farm Editor."
		vbox.add_child(lbl)
	else:
		for bp_name in names:
			var btn := Button.new()
			btn.text = bp_name
			btn.pressed.connect(func():
				var data := BlueprintManager.load_blueprint(bp_name)
				if not data.is_empty():
					AppState.set_blueprint(data.name, data.tilled_tiles, data.obstacle_tiles)
					name_label.text = data.name
				dialog.queue_free()
				_grid_overlay.queue_redraw()
			)
			vbox.add_child(btn)

	add_child(dialog)
	dialog.popup_centered(Vector2(300, 220))


# ── Plan save / load ───────────────────────────────────────────────────────────

func _save_plan() -> void:
	var name := _plan_name_edit.text.strip_edges()
	if name.is_empty():
		name = "Unnamed Plan"
		_plan_name_edit.text = name
	BlueprintManager.save_plan(name, _current_season, AppState.active_blueprint_name, AppState.active_plan_entries)
	AppState.active_plan_name = name


func _show_load_dialog() -> void:
	var names := BlueprintManager.list_plans()
	if names.is_empty():
		return
	var dialog := AcceptDialog.new()
	dialog.title = "Load Plan"
	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)
	for pname in names:
		var btn := Button.new()
		btn.text = pname
		btn.pressed.connect(func():
			var data := BlueprintManager.load_plan(pname)
			if not data.is_empty():
				AppState.set_plan(data.name, data.season, data.entries)
			dialog.queue_free()
			_grid_overlay.queue_redraw()
		)
		vbox.add_child(btn)
	add_child(dialog)
	dialog.popup_centered(Vector2(300, 200))


# ── Helpers ────────────────────────────────────────────────────────────────────

func _small_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	return lbl


func _add_legend_row(parent: Control, color: Color, text: String) -> void:
	var hbox := HBoxContainer.new()
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(14, 14)
	hbox.add_child(swatch)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.80, 0.85, 0.75))
	hbox.add_child(lbl)
	parent.add_child(hbox)


func _add_label(parent: Control, text: String, size: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)


func _make_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 32)
	btn.pressed.connect(callback)
	return btn
