# scripts/day_simulator.gd
# Day-by-day season simulator — step through days, see crop states on the map,
# review today's tasks and tomorrow's preview, and watch the season play out.
extends Control

# ── Constants ──────────────────────────────────────────────────────────────────
const FIELD_OFFSET : Vector2 = Vector2(272.0, 176.0)
const TILE_SIZE    : int     = 16
const FIELD_COLS   : int     = 43
const FIELD_ROWS   : int     = 25

const COL_BG           := Color(0.06, 0.18, 0.06)
const COL_PANEL        := Color(0.10, 0.26, 0.10)
const COL_HEADER       := Color(0.98, 0.95, 0.60)
const COL_TEXT         := Color(0.88, 0.92, 0.80)
const COL_SUBTEXT      := Color(0.60, 0.75, 0.55)
const COL_GOLD         := Color(0.95, 0.85, 0.20)
const COL_GREEN        := Color(0.45, 0.90, 0.45)
const COL_RED          := Color(0.90, 0.40, 0.40)
const COL_WATER        := Color(0.40, 0.70, 1.00)
const COL_TILLED       := Color(0.85, 0.72, 0.30, 0.35)
const COL_RIPE_BORDER  := Color(1.00, 1.00, 0.30, 0.90)
const COL_GRID         := Color(0.20, 0.20, 0.20, 0.28)
const COL_FIELD_BORDER := Color(0.90, 0.75, 0.20, 0.80)

const SEASON_MAPS := {
	"spring": "res://assets/farm_maps/farm_spring.png",
	"summer": "res://assets/farm_maps/farm_summer.png",
	"fall":   "res://assets/farm_maps/farm_autumn.png",
}

# Play speeds: seconds per day advance
const PLAY_SPEEDS       := [2.0, 1.0, 0.5, 0.2]
const PLAY_SPEED_LABELS := ["Slow", "Normal", "Fast", "Very Fast"]

# ── State ──────────────────────────────────────────────────────────────────────
var _season      : String     = "spring"
var _plan_entries: Array      = []
var _schedule    : Dictionary = {}
var _timeline    : Dictionary = {}
var _current_day : int        = 1
var _playing     : bool       = false
var _speed_idx   : int        = 1      # default: Normal
var _play_timer  : float      = 0.0

# ── UI refs ────────────────────────────────────────────────────────────────────
var _day_label    : Label
var _task_box     : VBoxContainer
var _tomorrow_box : VBoxContainer
var _stats_box    : VBoxContainer
var _grid_overlay : Control
var _map_texture  : TextureRect
var _play_btn     : Button
var _speed_btn    : Button


func _ready() -> void:
	_season       = AppState.active_season
	_plan_entries = AppState.active_plan_entries.duplicate()
	_schedule     = Calculator.build_daily_schedule(_season, _plan_entries)
	_timeline     = Economics.daily_gold_timeline(_season, _plan_entries)
	_build_ui()
	_refresh()


func _process(delta: float) -> void:
	if not _playing:
		return
	_play_timer += delta
	if _play_timer >= PLAY_SPEEDS[_speed_idx]:
		_play_timer = 0.0
		if _current_day < Calculator.SEASON_LENGTH:
			_current_day += 1
			_refresh()
		else:
			_stop_play()


# ── UI build ───────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	root_vbox.add_child(_make_top_bar())

	var main_hbox := HBoxContainer.new()
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 0)
	root_vbox.add_child(main_hbox)

	main_hbox.add_child(_make_sidebar())

	# ── Farm map ────────────────────────────────────────────────────────────
	var map_scroll := ScrollContainer.new()
	map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(map_scroll)

	var map_container := Control.new()
	map_container.custom_minimum_size = Vector2(1024, 704)
	map_scroll.add_child(map_container)

	_map_texture = TextureRect.new()
	_map_texture.size = Vector2(1024, 704)
	_map_texture.stretch_mode = TextureRect.STRETCH_KEEP
	_map_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_container.add_child(_map_texture)
	_load_season_map()

	_grid_overlay = Control.new()
	_grid_overlay.size = Vector2(1024, 704)
	_grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_overlay.draw.connect(_on_grid_draw)
	map_container.add_child(_grid_overlay)


func _make_top_bar() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 48)
	hbox.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Day Simulator"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", COL_HEADER)
	title.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var btn_prev := Button.new()
	btn_prev.text = "◀ Prev"
	btn_prev.pressed.connect(func():
		if _current_day > 1:
			_current_day -= 1
			_refresh()
	)
	hbox.add_child(btn_prev)

	_day_label = Label.new()
	_day_label.custom_minimum_size = Vector2(110, 0)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label.add_theme_font_size_override("font_size", 16)
	_day_label.add_theme_color_override("font_color", COL_HEADER)
	hbox.add_child(_day_label)

	var btn_next := Button.new()
	btn_next.text = "Next ▶"
	btn_next.pressed.connect(func():
		if _current_day < Calculator.SEASON_LENGTH:
			_current_day += 1
			_refresh()
	)
	hbox.add_child(btn_next)

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(12, 0)
	hbox.add_child(sep)

	_play_btn = Button.new()
	_play_btn.text = "▶ Play"
	_play_btn.custom_minimum_size = Vector2(80, 0)
	_play_btn.pressed.connect(_toggle_play)
	hbox.add_child(_play_btn)

	_speed_btn = Button.new()
	_speed_btn.custom_minimum_size = Vector2(130, 0)
	_speed_btn.pressed.connect(_cycle_speed)
	hbox.add_child(_speed_btn)
	_update_speed_label()

	var sep2 := Control.new()
	sep2.custom_minimum_size = Vector2(12, 0)
	hbox.add_child(sep2)

	var btn_planner := Button.new()
	btn_planner.text = "← Planner"
	btn_planner.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/season_planner.tscn")
	)
	hbox.add_child(btn_planner)

	var btn_menu := Button.new()
	btn_menu.text = "Menu"
	btn_menu.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	hbox.add_child(btn_menu)

	return hbox


func _make_sidebar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = COL_PANEL
	panel.add_theme_stylebox_override("panel", style)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	# Today (populated in _refresh)
	_task_box = VBoxContainer.new()
	_task_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_task_box.add_theme_constant_override("separation", 4)
	vbox.add_child(_task_box)

	vbox.add_child(HSeparator.new())

	_add_lbl(vbox, "Tomorrow", 12, COL_HEADER)

	_tomorrow_box = VBoxContainer.new()
	_tomorrow_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tomorrow_box.add_theme_constant_override("separation", 4)
	vbox.add_child(_tomorrow_box)

	vbox.add_child(HSeparator.new())

	_add_lbl(vbox, "Season Stats", 12, COL_HEADER)

	_stats_box = VBoxContainer.new()
	_stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_box.add_theme_constant_override("separation", 4)
	vbox.add_child(_stats_box)

	return panel


func _load_season_map() -> void:
	var path: String = SEASON_MAPS.get(_season, SEASON_MAPS["spring"])
	var tex := load(path) as Texture2D
	if tex:
		_map_texture.texture = tex


# ── Refresh ────────────────────────────────────────────────────────────────────

func _refresh() -> void:
	_day_label.text = "Day %02d / %d" % [_current_day, Calculator.SEASON_LENGTH]
	_build_today_panel()
	_build_tomorrow_panel()
	_build_stats_panel()
	_grid_overlay.queue_redraw()


func _build_today_panel() -> void:
	for c in _task_box.get_children():
		c.queue_free()

	var day_data : Dictionary = _schedule.get(_current_day, {})
	var festival : Dictionary = day_data.get("festival", {})
	var f_type   : String     = day_data.get("festival_type", "")

	_add_lbl(_task_box, "Day %d  —  %s" % [_current_day, _season.capitalize()], 14, COL_HEADER)

	# Festival
	if not festival.is_empty():
		var fc: Color = HolidaysData.get_festival_color(f_type).lightened(0.3)
		_add_lbl(_task_box, "🎉 %s" % festival.get("name", ""), 11, fc)

	# Harvests
	var harvests: Array = day_data.get("harvests", [])
	if not harvests.is_empty():
		_add_lbl(_task_box, "Harvest (%d)" % harvests.size(), 11, COL_GOLD)
		var by_crop: Dictionary = {}
		for h in harvests:
			var cname: String = CropsData.get_crop(h.crop_id).get("name", "?")
			by_crop[cname] = by_crop.get(cname, 0) + 1
		for cname in by_crop:
			_add_lbl(_task_box, "  • %s × %d" % [cname, by_crop[cname]], 11, COL_TEXT)

	# Replants (non-regrow crops being replanted on a harvest day)
	var replants: Array = _get_replants_on(_current_day)
	if not replants.is_empty():
		_add_lbl(_task_box, "Replant (%d)" % replants.size(), 11, COL_GREEN)
		var by_crop: Dictionary = {}
		for cname in replants:
			by_crop[cname] = by_crop.get(cname, 0) + 1
		for cname in by_crop:
			_add_lbl(_task_box, "  • %s × %d" % [cname, by_crop[cname]], 11, COL_TEXT)

	# Watering
	var water_tiles: Array = _get_water_tiles(_current_day)
	if not water_tiles.is_empty():
		# Group by crop name for a cleaner list
		var by_crop: Dictionary = {}
		for entry in water_tiles:
			var cname: String = CropsData.get_crop(entry.crop_id).get("name", "?")
			by_crop[cname] = by_crop.get(cname, 0) + 1
		_add_lbl(_task_box, "Water (%d tiles)" % water_tiles.size(), 11, COL_WATER)
		for cname in by_crop:
			_add_lbl(_task_box, "  • %s × %d" % [cname, by_crop[cname]], 11, COL_TEXT)

	if harvests.is_empty() and replants.is_empty() and water_tiles.is_empty() and festival.is_empty():
		_add_lbl(_task_box, "Nothing to do today.", 11, COL_SUBTEXT)


func _build_tomorrow_panel() -> void:
	for c in _tomorrow_box.get_children():
		c.queue_free()

	if _current_day >= Calculator.SEASON_LENGTH:
		_add_lbl(_tomorrow_box, "End of season.", 11, COL_SUBTEXT)
		return

	var next_day  : int        = _current_day + 1
	var day_data  : Dictionary = _schedule.get(next_day, {})
	var festival  : Dictionary = day_data.get("festival", {})
	var f_type    : String     = day_data.get("festival_type", "")
	var harvests  : Array      = day_data.get("harvests", [])
	var replants  : Array      = _get_replants_on(next_day)
	var water_cnt : int        = _get_water_tiles(next_day).size()
	var nothing   : bool       = harvests.is_empty() and replants.is_empty() and water_cnt == 0 and festival.is_empty()

	if not festival.is_empty():
		var fc: Color = HolidaysData.get_festival_color(f_type).lightened(0.3)
		_add_lbl(_tomorrow_box, "🎉 %s" % festival.get("name", ""), 11, fc)

	if not harvests.is_empty():
		_add_lbl(_tomorrow_box, "🌾 Harvest: %d crops" % harvests.size(), 11, COL_GOLD)

	if not replants.is_empty():
		_add_lbl(_tomorrow_box, "🌱 Replant: %d tiles" % replants.size(), 11, COL_GREEN)

	if water_cnt > 0:
		_add_lbl(_tomorrow_box, "💧 Water: %d tiles" % water_cnt, 11, COL_WATER)

	if nothing:
		_add_lbl(_tomorrow_box, "Nothing scheduled.", 11, COL_SUBTEXT)


func _build_stats_panel() -> void:
	for c in _stats_box.get_children():
		c.queue_free()

	var td: Dictionary = _timeline.get(_current_day, {})
	var earned: int = td.get("earned_today",    0)
	var spent : int = td.get("spent_today",     0)
	var gross : int = td.get("cumulative_gross", 0)
	var costs : int = td.get("cumulative_costs", 0)
	var net   : int = td.get("cumulative_net",   0)

	if earned > 0:
		_add_lbl(_stats_box, "Earned today:  +%dG" % earned, 11, COL_GOLD)
	if spent > 0:
		_add_lbl(_stats_box, "Spent today:   -%dG" % spent, 11, COL_RED)
	_add_lbl(_stats_box, "Gross to date:  %dG" % gross, 11, COL_TEXT)
	_add_lbl(_stats_box, "Costs to date:  %dG" % costs, 11, COL_TEXT)
	_add_lbl(_stats_box, "Net to date:    %+dG" % net, 11, COL_GREEN if net >= 0 else COL_RED)


# ── Task helpers ───────────────────────────────────────────────────────────────

# Returns crop names of non-regrow tiles being replanted on `day`.
func _get_replants_on(day: int) -> Array:
	var result: Array = []
	for entry in _plan_entries:
		var crop_id  : String = entry.get("crop_id",  "")
		var plant_day: int    = entry.get("plant_day", 1)
		var crop     : Dictionary = CropsData.get_crop(crop_id)
		if crop.is_empty() or int(crop.get("regrow_days", 0)) > 0:
			continue
		# get_planting_days[0] is the initial plant; the rest are replant days
		var pdays: Array = Calculator.get_planting_days(crop_id, plant_day)
		for i in range(1, pdays.size()):
			if int(pdays[i]) == day:
				result.append(crop.get("name", crop_id))
				break
	return result


# Returns plan entries whose crops need watering on `day`
# (active, not a harvest day, not farm_grass).
func _get_water_tiles(day: int) -> Array:
	# Build set of tiles being harvested today for quick lookup
	var harvest_tiles: Dictionary = {}
	var day_data: Dictionary = _schedule.get(day, {})
	for h in day_data.get("harvests", []):
		harvest_tiles[h.tile] = true

	var result: Array = []
	for entry in _plan_entries:
		var crop_id  : String   = entry.get("crop_id",  "")
		var plant_day: int      = entry.get("plant_day", 1)
		var tile     : Vector2i = entry.get("tile", Vector2i(-1, -1))
		if crop_id == "farm_grass":
			continue
		var stage: int = Calculator.get_crop_stage(crop_id, plant_day, day)
		if stage < 0:
			continue  # not active
		if harvest_tiles.has(tile):
			continue  # harvested today, no watering needed
		result.append(entry)
	return result


# ── Play mode ──────────────────────────────────────────────────────────────────

func _toggle_play() -> void:
	_playing = not _playing
	if _playing:
		# If already at the end, restart from day 1
		if _current_day >= Calculator.SEASON_LENGTH:
			_current_day = 1
			_refresh()
		_play_btn.text = "⏸ Pause"
		_play_timer = 0.0
	else:
		_stop_play()


func _stop_play() -> void:
	_playing = false
	_play_btn.text = "▶ Play"


func _cycle_speed() -> void:
	_speed_idx = (_speed_idx + 1) % PLAY_SPEEDS.size()
	_update_speed_label()


func _update_speed_label() -> void:
	_speed_btn.text = "Speed: %s" % PLAY_SPEED_LABELS[_speed_idx]


# ── Drawing ────────────────────────────────────────────────────────────────────

func _on_grid_draw() -> void:
	var overlay := _grid_overlay

	# Tilled tile base
	for t in AppState.active_tilled_tiles:
		overlay.draw_rect(_tile_rect(t), COL_TILLED)

	# Crop growth stage overlays
	for entry in _plan_entries:
		var crop_id  : String   = entry.get("crop_id",  "")
		var plant_day: int      = entry.get("plant_day", 1)
		var tile     : Vector2i = entry.get("tile", Vector2i(-1, -1))
		var crop     : Dictionary = CropsData.get_crop(crop_id)
		if crop.is_empty():
			continue

		var stage    : int   = Calculator.get_crop_stage(crop_id, plant_day, _current_day)
		if stage < 0:
			continue  # not yet planted or done for the season

		var num_stages  : int   = (crop.get("stage_days", []) as Array).size()
		var crop_color  : Color = crop.get("color", Color.WHITE) as Color
		var rect        : Rect2 = _tile_rect(tile)

		if stage >= num_stages:
			# Ripe — full crop color with a gold border
			overlay.draw_rect(rect, crop_color.lightened(0.1))
			overlay.draw_rect(rect, COL_RIPE_BORDER, false, 1.5)
		else:
			# Growing — darken proportionally to show progress
			var progress: float = float(stage) / float(max(num_stages, 1))
			var draw_color: Color = crop_color.darkened(0.65 - progress * 0.55)
			overlay.draw_rect(rect, draw_color)

	# Grid lines
	for col in range(FIELD_COLS + 1):
		var x: float = FIELD_OFFSET.x + col * TILE_SIZE
		overlay.draw_line(
			Vector2(x, FIELD_OFFSET.y),
			Vector2(x, FIELD_OFFSET.y + FIELD_ROWS * TILE_SIZE),
			COL_GRID, 1.0
		)
	for row in range(FIELD_ROWS + 1):
		var y: float = FIELD_OFFSET.y + row * TILE_SIZE
		overlay.draw_line(
			Vector2(FIELD_OFFSET.x, y),
			Vector2(FIELD_OFFSET.x + FIELD_COLS * TILE_SIZE, y),
			COL_GRID, 1.0
		)

	# Field border
	overlay.draw_rect(
		Rect2(FIELD_OFFSET, Vector2(FIELD_COLS * TILE_SIZE, FIELD_ROWS * TILE_SIZE)),
		COL_FIELD_BORDER, false, 2.0
	)


func _tile_rect(tile: Vector2i) -> Rect2:
	return Rect2(
		FIELD_OFFSET + Vector2(tile.x * TILE_SIZE, tile.y * TILE_SIZE),
		Vector2(TILE_SIZE, TILE_SIZE)
	)


# ── Label helper ───────────────────────────────────────────────────────────────

func _add_lbl(parent: Control, text: String, size: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)
