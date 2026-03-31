# scripts/crop_reference.gd
# Crop Reference — per-crop stats and optimal planting guide.
extends Control

const COL_BG      := Color(0.06, 0.18, 0.06)
const COL_PANEL   := Color(0.10, 0.26, 0.10)
const COL_HEADER  := Color(0.98, 0.95, 0.60)
const COL_GOLD    := Color(0.95, 0.85, 0.20)
const COL_GREEN   := Color(0.45, 0.90, 0.45)
const COL_RED     := Color(0.90, 0.40, 0.40)
const COL_TEXT    := Color(0.88, 0.92, 0.80)
const COL_SUBTEXT := Color(0.60, 0.75, 0.55)
const COL_DIM     := Color(0.50, 0.55, 0.45)

# Where we came from so the back button can return there.
# Set by calling scene before changing to this scene.
# Defaults to main menu.
const DEFAULT_BACK := "res://scenes/main_menu.tscn"

var _back_scene: String = DEFAULT_BACK


func _ready() -> void:
	_back_scene = AppState.crop_reference_back_scene
	_build_ui()


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

	# Column header
	root_vbox.add_child(_make_header_row())

	# Scrollable body
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 1)
	scroll.add_child(body)

	_populate_body(body)

	# Footer note
	var note := Label.new()
	note.text = (
		"  * Latest Plant Day = last day you can plant and still get the maximum " +
		"number of harvests that season.   † Profit/Tile assumes planting on Day 1."
	)
	note.add_theme_font_size_override("font_size", 9)
	note.add_theme_color_override("font_color", COL_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(0, 32)
	root_vbox.add_child(note)


func _make_top_bar() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 48)
	hbox.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "Crop Reference"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COL_HEADER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	var btn_back := Button.new()
	btn_back.text = "← Back"
	btn_back.pressed.connect(func():
		get_tree().change_scene_to_file(_back_scene)
	)
	hbox.add_child(btn_back)

	var btn_menu := Button.new()
	btn_menu.text = "Menu"
	btn_menu.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	hbox.add_child(btn_menu)

	return hbox


# Column layout: [header_text, min_width, color]
const COLUMNS := [
	["Crop",              150],
	["Season",             70],
	["Growth",             65],
	["Regrow",             60],
	["Seed/Throw",         80],
	["Sell/Crop",          75],
	["Latest Day*",        85],
	["Max Harvests",       95],
	["Profit/Tile†",       90],
	["Unlock",            200],
]


func _make_header_row() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 30)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.35, 0.15)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(hbox)

	for col in COLUMNS:
		var lbl := Label.new()
		lbl.text = col[0] as String
		lbl.custom_minimum_size = Vector2(col[1] as int, 0)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", COL_HEADER)
		hbox.add_child(lbl)

	return panel


func _populate_body(body: VBoxContainer) -> void:
	for season in ["spring", "summer", "fall"]:
		# Season divider
		var divider := _make_season_divider(season)
		body.add_child(divider)

		var season_crops := CropsData.get_season_crops(season)
		# Remove "any" season crops from each section (farm_grass will appear once under "any")
		var ids: Array = []
		for crop_id in season_crops:
			if CropsData.get_crop(crop_id).get("season", "") == season:
				ids.append(crop_id)
		ids.sort()  # alphabetical for consistency

		var alternate := false
		for crop_id in ids:
			body.add_child(_make_crop_row(crop_id, alternate))
			alternate = not alternate

	# Farm Grass (multi-season) at the bottom
	var any_divider := _make_season_divider("any")
	body.add_child(any_divider)
	body.add_child(_make_crop_row("farm_grass", false))


func _make_season_divider(season: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 26)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.22, 0.08)
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	var display: String = season.capitalize() if season != "any" else "Multi-Season"
	lbl.text = "  — %s —" % display
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", COL_HEADER)
	panel.add_child(lbl)

	return panel


func _make_crop_row(crop_id: String, alternate: bool) -> PanelContainer:
	var crop: Dictionary = CropsData.get_crop(crop_id)
	if crop.is_empty():
		return PanelContainer.new()

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 30)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.28, 0.12) if alternate else Color(0.10, 0.24, 0.10)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(hbox)

	var crop_color: Color = crop.get("color", Color.WHITE) as Color

	# Compute stats
	var max_count: int = Calculator.get_harvest_count(crop_id, 1)
	for d in range(1, Calculator.SEASON_LENGTH + 1):
		var c: int = Calculator.get_harvest_count(crop_id, d)
		if c > max_count:
			max_count = c

	var latest_day: int  = Calculator.latest_max_plant_day(crop_id)
	var seed_cost_d1: int = Calculator.get_seed_cost_total(crop_id, 1)
	var sellable: bool    = crop.get("sellable", false) as bool
	var sell_price: int   = crop.get("sell_price", 0) as int
	var gross_d1: int     = max_count * sell_price if sellable else 0
	var profit_d1: int    = gross_d1 - seed_cost_d1

	var regrow: int = crop.get("regrow_days", 0) as int
	var regrow_str: String = "%dd" % regrow if regrow > 0 else "replant"

	var unlock: String = crop.get("unlock", "") as String

	var cells: Array = [
		[crop.get("name", crop_id),       150, crop_color.lightened(0.2)],
		[crop.get("season", "").capitalize(), 70, COL_SUBTEXT],
		["%dd" % crop.get("first_harvest", 0), 65, COL_TEXT],
		[regrow_str,                        60, COL_TEXT],
		["%dG" % crop.get("seed_cost", 0), 80, COL_RED],
		["%dG" % sell_price if sellable else "—", 75, COL_GOLD if sellable else COL_DIM],
		["Day %d" % latest_day if latest_day > 0 else "—", 85, COL_GREEN],
		[str(max_count) if max_count > 0 else "—", 95, COL_TEXT],
		[
			("%+dG" % profit_d1) if sellable else "N/A",
			90,
			COL_GREEN if profit_d1 >= 0 else COL_RED if sellable else COL_DIM
		],
		[unlock if unlock != "" else "Always",   200, COL_SUBTEXT],
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
