# scripts/economics_panel.gd
# Economics dashboard — per-crop breakdown and season summary.
extends Control

const COL_BG      := Color(0.06, 0.18, 0.06)
const COL_PANEL   := Color(0.10, 0.26, 0.10)
const COL_HEADER  := Color(0.98, 0.95, 0.60)
const COL_GOLD    := Color(0.95, 0.85, 0.20)
const COL_GREEN   := Color(0.45, 0.90, 0.45)
const COL_RED     := Color(0.90, 0.40, 0.40)
const COL_TEXT    := Color(0.88, 0.92, 0.80)
const COL_SUBTEXT := Color(0.60, 0.75, 0.55)

var _season       : String    = "spring"
var _breakdown    : Array     = []
var _summary      : Dictionary = {}
var _table_box    : VBoxContainer
var _summary_label: Label
var _season_option: OptionButton


func _ready() -> void:
	_season = AppState.active_season
	_recalculate()
	_build_ui()
	AppState.plan_changed.connect(_on_plan_changed)


func _recalculate() -> void:
	var entries := AppState.active_plan_entries
	_breakdown = Economics.season_breakdown(_season, entries)
	_summary   = Economics.season_summary(_season, entries)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 4)
	add_child(root_vbox)

	# ── Top bar ───────────────────────────────────────────────────────────────
	root_vbox.add_child(_make_top_bar())

	# ── Summary strip ─────────────────────────────────────────────────────────
	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 13)
	_summary_label.add_theme_color_override("font_color", COL_TEXT)
	_summary_label.custom_minimum_size = Vector2(0, 36)
	root_vbox.add_child(_summary_label)
	_update_summary_label()

	# ── Table header ──────────────────────────────────────────────────────────
	root_vbox.add_child(_make_table_header())

	# ── Scrollable table ──────────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	_table_box = VBoxContainer.new()
	_table_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table_box.add_theme_constant_override("separation", 1)
	scroll.add_child(_table_box)

	_populate_table()

	# ── Optimal planting suggestions ──────────────────────────────────────────
	root_vbox.add_child(_make_optimal_panel())


func _make_top_bar() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 48)
	hbox.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "Economics Dashboard"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COL_HEADER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	_season_option = OptionButton.new()
	for s in ["spring", "summer", "fall"]:
		_season_option.add_item(s.capitalize())
	_season_option.selected = ["spring", "summer", "fall"].find(_season)
	_season_option.item_selected.connect(_on_season_changed)
	hbox.add_child(_season_option)

	var btn_cal := Button.new()
	btn_cal.text = "← Calendar"
	btn_cal.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/calendar_view.tscn")
	)
	hbox.add_child(btn_cal)

	var btn_sprite := Button.new()
	btn_sprite.text = "Sprites →"
	btn_sprite.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/sprite_manager.tscn")
	)
	hbox.add_child(btn_sprite)

	var btn_menu := Button.new()
	btn_menu.text = "Menu"
	btn_menu.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	hbox.add_child(btn_menu)

	return hbox


func _make_table_header() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 30)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.35, 0.15)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(hbox)

	var cols := [
		["Crop",         160, COL_HEADER],
		["Tiles",         55, COL_HEADER],
		["Harvests",      70, COL_HEADER],
		["Seed Cost",     80, COL_HEADER],
		["Gross",         80, COL_HEADER],
		["Net Profit",    90, COL_HEADER],
		["Break-Even",    90, COL_HEADER],
	]
	for col in cols:
		var lbl := Label.new()
		lbl.text = col[0] as String
		lbl.custom_minimum_size = Vector2(col[1] as int, 0)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", col[2] as Color)
		hbox.add_child(lbl)

	return panel


func _populate_table() -> void:
	for child in _table_box.get_children():
		child.queue_free()

	if _breakdown.is_empty():
		var lbl := Label.new()
		lbl.text = "No crops planted. Go to the Season Planner to assign crops."
		lbl.add_theme_color_override("font_color", COL_SUBTEXT)
		_table_box.add_child(lbl)
		return

	var alternate := false
	for row in _breakdown:
		_table_box.add_child(_make_table_row(row, alternate))
		alternate = not alternate


func _make_table_row(row: Dictionary, alternate: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 30)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.28, 0.12) if alternate else Color(0.10, 0.24, 0.10)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(hbox)

	var crop := CropsData.get_crop(row.crop_id)
	var crop_color: Color = crop.get("color", Color.WHITE) if not crop.is_empty() else Color.WHITE

	var net: int = row.get("net_profit", 0)
	var be_day: int = row.get("break_even_day", -1)

	var cells := [
		[row.get("name", "?"),                                          160, crop_color.lightened(0.2)],
		[str(row.get("tiles_planted", 0)),                               55, COL_TEXT],
		[str(row.get("total_harvests", 0)),                              70, COL_TEXT],
		["%dG" % row.get("seed_cost_total", 0),                          80, COL_RED],
		["%dG" % row.get("gross_revenue", 0),                            80, COL_GOLD],
		[("%+dG" % net),                                                 90, COL_GREEN if net >= 0 else COL_RED],
		["Day %d" % be_day if be_day > 0 else ("Never" if row.get("sellable", true) else "N/A"), 90, COL_SUBTEXT],
	]

	for cell in cells:
		var lbl := Label.new()
		lbl.text = cell[0] as String
		lbl.custom_minimum_size = Vector2(cell[1] as int, 0)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", cell[2] as Color)
		lbl.clip_text = true
		hbox.add_child(lbl)

	return panel


func _make_optimal_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 120)
	var style := StyleBoxFlat.new()
	style.bg_color = COL_PANEL
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Optimal Plant Days (to maximise harvests before Day 30)"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", COL_HEADER)
	vbox.add_child(title)

	var optimal := Calculator.optimal_plant_days(_season)
	var season_crops := CropsData.get_season_crops(_season)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	vbox.add_child(grid)

	for crop_id in optimal:
		var info := optimal[crop_id]
		var cname: String = season_crops.get(crop_id, {}).get("name", crop_id)
		var lbl := Label.new()
		lbl.text = "%s: Plant Day %d (%d harvests)" % [cname, info.plant_day, info.harvest_count]
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", COL_TEXT)
		grid.add_child(lbl)

	return panel


func _update_summary_label() -> void:
	if _summary_label == null:
		return
	var net: int = _summary.get("total_net", 0)
	_summary_label.text = (
		"  Season: %s   |   Tiles Planted: %d   |   Total Harvests: %d   |   Seeds: %dG   |   Gross: %dG   |   Net Profit: %dG" % [
			_season.capitalize(),
			_summary.get("total_tiles", 0),
			_summary.get("total_harvests", 0),
			_summary.get("total_seed_cost", 0),
			_summary.get("total_gross", 0),
			net,
		]
	)
	_summary_label.add_theme_color_override(
		"font_color",
		COL_GREEN if net >= 0 else COL_RED
	)


func _on_season_changed(idx: int) -> void:
	_season = ["spring", "summer", "fall"][idx]
	AppState.set_season(_season)
	_recalculate()
	_update_summary_label()
	_populate_table()


func _on_plan_changed() -> void:
	_season = AppState.active_season
	_recalculate()
	_update_summary_label()
	_populate_table()
