# scripts/calendar_view.gd
# 30-day season calendar showing harvest schedule, festival flags, and daily gold.
extends Control

const COL_BG       := Color(0.06, 0.18, 0.06)
const COL_PANEL    := Color(0.10, 0.26, 0.10)
const COL_HEADER   := Color(0.98, 0.95, 0.60)
const COL_DAY_BG   := Color(0.14, 0.32, 0.14)
const COL_DAY_LITE := Color(0.18, 0.40, 0.18)
const COL_GOLD     := Color(0.95, 0.85, 0.20)
const COL_TEXT     := Color(0.88, 0.92, 0.80)
const COL_SUBTEXT  := Color(0.60, 0.75, 0.55)

# Harvest density thresholds for colour coding
const LIGHT_THRESHOLD  : int = 1
const MEDIUM_THRESHOLD : int = 8
const HEAVY_THRESHOLD  : int = 16

var _season       : String = "spring"
var _schedule     : Dictionary = {}
var _timeline     : Dictionary = {}
var _summary      : Dictionary = {}
var _scroll       : ScrollContainer
var _calendar_box : VBoxContainer
var _summary_label: Label
var _season_option: OptionButton


func _ready() -> void:
	_season = AppState.active_season
	_recalculate()
	_build_ui()
	AppState.plan_changed.connect(_on_plan_changed)


func _recalculate() -> void:
	var entries := AppState.active_plan_entries
	_schedule = Calculator.build_daily_schedule(_season, entries)
	_timeline  = Economics.daily_gold_timeline(_season, entries)
	_summary   = Economics.season_summary(_season, entries)


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

	# ── Top bar ───────────────────────────────────────────────────────────────
	root_vbox.add_child(_make_top_bar())

	# ── Summary strip ─────────────────────────────────────────────────────────
	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 12)
	_summary_label.add_theme_color_override("font_color", COL_TEXT)
	_summary_label.custom_minimum_size = Vector2(0, 32)
	root_vbox.add_child(_summary_label)
	_update_summary_label()

	# ── Festival legend ───────────────────────────────────────────────────────
	root_vbox.add_child(_make_legend())

	# ── Scrollable calendar ───────────────────────────────────────────────────
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_scroll)

	_calendar_box = VBoxContainer.new()
	_calendar_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_calendar_box.add_theme_constant_override("separation", 2)
	_scroll.add_child(_calendar_box)

	_populate_calendar()


func _make_top_bar() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 48)
	hbox.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "Season Calendar"
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

	var btn_planner := Button.new()
	btn_planner.text = "← Planner"
	btn_planner.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/season_planner.tscn")
	)
	hbox.add_child(btn_planner)

	var btn_econ := Button.new()
	btn_econ.text = "Economics →"
	btn_econ.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/economics_panel.tscn")
	)
	hbox.add_child(btn_econ)

	var btn_menu := Button.new()
	btn_menu.text = "Menu"
	btn_menu.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	hbox.add_child(btn_menu)

	return hbox


func _make_legend() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 28)
	hbox.add_theme_constant_override("separation", 16)

	var legend_items := [
		[Color(0.85, 0.15, 0.15, 0.80), "Blocking festival"],
		[Color(0.95, 0.75, 0.10, 0.80), "Morning-safe"],
		[Color(0.90, 0.50, 0.10, 0.80), "Risky"],
		[Color(0.20, 0.55, 0.80, 0.80), "Light harvest"],
		[Color(0.55, 0.80, 0.20, 0.80), "Medium harvest"],
		[Color(0.90, 0.45, 0.10, 0.80), "Heavy harvest"],
	]

	for item in legend_items:
		var row := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.color = item[0] as Color
		swatch.custom_minimum_size = Vector2(14, 14)
		row.add_child(swatch)
		var lbl := Label.new()
		lbl.text = item[1] as String
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", COL_SUBTEXT)
		row.add_child(lbl)
		hbox.add_child(row)

	return hbox


func _populate_calendar() -> void:
	for child in _calendar_box.get_children():
		child.queue_free()

	for day in range(1, 31):
		_calendar_box.add_child(_make_day_row(day))


func _make_day_row(day: int) -> PanelContainer:
	var day_data  : Dictionary = _schedule.get(day, {})
	var time_data : Dictionary = _timeline.get(day, {})
	var festival  : Dictionary = day_data.get("festival", {})
	var f_type    : String     = day_data.get("festival_type", "")
	var count     : int        = day_data.get("count", 0)
	var gold_today: int        = day_data.get("gold", 0)
	var cumul_net : int        = time_data.get("cumulative_net", 0)
	var sprite_bday: String    = SpritesData.get_birthday_sprite(_season, day)

	# Row background color based on harvest density
	var bg_col := COL_DAY_BG
	if count >= HEAVY_THRESHOLD:
		bg_col = Color(0.35, 0.22, 0.06)
	elif count >= MEDIUM_THRESHOLD:
		bg_col = Color(0.16, 0.32, 0.10)
	elif count >= LIGHT_THRESHOLD:
		bg_col = Color(0.12, 0.28, 0.18)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 36)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_col
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# Day number
	var day_lbl := Label.new()
	day_lbl.text = "Day %02d" % day
	day_lbl.custom_minimum_size = Vector2(60, 0)
	day_lbl.add_theme_font_size_override("font_size", 13)
	day_lbl.add_theme_color_override("font_color", COL_HEADER)
	hbox.add_child(day_lbl)

	# Festival badge
	var f_color := HolidaysData.get_festival_color(f_type)
	var f_badge := Label.new()
	f_badge.custom_minimum_size = Vector2(140, 0)
	f_badge.add_theme_font_size_override("font_size", 10)
	if not festival.is_empty():
		f_badge.text = "🎉 " + festival.get("name", "")
		f_badge.add_theme_color_override("font_color", f_color.lightened(0.4))
	else:
		f_badge.text = ""
	hbox.add_child(f_badge)

	# Sprite birthday badge
	var bday_lbl := Label.new()
	bday_lbl.custom_minimum_size = Vector2(90, 0)
	bday_lbl.add_theme_font_size_override("font_size", 10)
	if sprite_bday != "":
		var sp := SpritesData.get_sprite(sprite_bday)
		bday_lbl.text = "🎂 " + sp.get("name", "")
		bday_lbl.add_theme_color_override("font_color", (sp.get("color", Color.WHITE) as Color).lightened(0.3))
	hbox.add_child(bday_lbl)

	# Harvest count
	var harvest_lbl := Label.new()
	harvest_lbl.custom_minimum_size = Vector2(90, 0)
	harvest_lbl.add_theme_font_size_override("font_size", 12)
	if count > 0:
		harvest_lbl.text = "🌾 %d crops" % count
		var h_color := Color(0.70, 0.90, 0.50)
		if count >= HEAVY_THRESHOLD:
			h_color = Color(0.95, 0.55, 0.15)
		elif count >= MEDIUM_THRESHOLD:
			h_color = Color(0.80, 0.90, 0.30)
		harvest_lbl.add_theme_color_override("font_color", h_color)
	else:
		harvest_lbl.text = "—"
		harvest_lbl.add_theme_color_override("font_color", Color(0.40, 0.50, 0.40))
	hbox.add_child(harvest_lbl)

	# Gold earned today
	var gold_lbl := Label.new()
	gold_lbl.custom_minimum_size = Vector2(80, 0)
	gold_lbl.add_theme_font_size_override("font_size", 11)
	if gold_today > 0:
		gold_lbl.text = "+%dG" % gold_today
		gold_lbl.add_theme_color_override("font_color", COL_GOLD)
	else:
		gold_lbl.text = ""
	hbox.add_child(gold_lbl)

	# Cumulative net
	var net_lbl := Label.new()
	net_lbl.custom_minimum_size = Vector2(100, 0)
	net_lbl.add_theme_font_size_override("font_size", 11)
	net_lbl.text = "Net: %dG" % cumul_net
	net_lbl.add_theme_color_override("font_color",
		Color(0.50, 0.90, 0.50) if cumul_net >= 0 else Color(0.90, 0.40, 0.40)
	)
	hbox.add_child(net_lbl)

	# Crop breakdown (tooltip-style, small text)
	var crop_detail := Label.new()
	crop_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crop_detail.add_theme_font_size_override("font_size", 9)
	crop_detail.add_theme_color_override("font_color", COL_SUBTEXT)
	crop_detail.clip_text = true
	if count > 0:
		var names_by_crop: Dictionary = {}
		for h in day_data.get("harvests", []):
			var cname := CropsData.get_crop(h.crop_id).get("name", "?")
			names_by_crop[cname] = names_by_crop.get(cname, 0) + 1
		var parts := []
		for cname in names_by_crop:
			parts.append("%s×%d" % [cname, names_by_crop[cname]])
		crop_detail.text = "  " + ", ".join(parts)
	hbox.add_child(crop_detail)

	return panel


func _update_summary_label() -> void:
	if _summary_label == null:
		return
	_summary_label.text = (
		"  Season: %s   |   Tiles: %d   |   Total Harvests: %d   |   Seeds Cost: %dG   |   Gross: %dG   |   Net: %dG" % [
			_season.capitalize(),
			_summary.get("total_tiles", 0),
			_summary.get("total_harvests", 0),
			_summary.get("total_seed_cost", 0),
			_summary.get("total_gross", 0),
			_summary.get("total_net", 0),
		]
	)


func _on_season_changed(idx: int) -> void:
	_season = ["spring", "summer", "fall"][idx]
	AppState.set_season(_season)
	_recalculate()
	_update_summary_label()
	_populate_calendar()


func _on_plan_changed() -> void:
	_season = AppState.active_season
	_recalculate()
	_update_summary_label()
	_populate_calendar()
