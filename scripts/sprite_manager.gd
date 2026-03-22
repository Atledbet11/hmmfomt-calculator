# scripts/sprite_manager.gd
# Harvest Sprite Manager — track friendship, plan contracts, see birthdays.
extends Control

const COL_BG      := Color(0.06, 0.18, 0.06)
const COL_PANEL   := Color(0.10, 0.26, 0.10)
const COL_HEADER  := Color(0.98, 0.95, 0.60)
const COL_TEXT    := Color(0.88, 0.92, 0.80)
const COL_SUBTEXT := Color(0.60, 0.75, 0.55)
const COL_GOLD    := Color(0.95, 0.85, 0.20)
const COL_GREEN   := Color(0.45, 0.90, 0.45)
const COL_RED     := Color(0.90, 0.40, 0.40)

var _season       : String = "spring"
var _season_option: OptionButton
var _sprite_cards : Dictionary = {}   # sprite_id -> card VBox reference
var _contract_box : VBoxContainer


func _ready() -> void:
	_season = AppState.active_season
	_build_ui()
	AppState.plan_changed.connect(_refresh_contract_panel)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 8)
	add_child(root_vbox)

	root_vbox.add_child(_make_top_bar())
	root_vbox.add_child(HSeparator.new())

	# ── Sprite grid ───────────────────────────────────────────────────────────
	var sprites_label := Label.new()
	sprites_label.text = "Harvest Sprites — Friendship & Hiring"
	sprites_label.add_theme_font_size_override("font_size", 14)
	sprites_label.add_theme_color_override("font_color", COL_HEADER)
	root_vbox.add_child(sprites_label)

	var sprite_grid := GridContainer.new()
	sprite_grid.columns = 4
	sprite_grid.add_theme_constant_override("h_separation", 8)
	sprite_grid.add_theme_constant_override("v_separation", 8)
	root_vbox.add_child(sprite_grid)

	for sprite_id in SpritesData.get_all_ids():
		sprite_grid.add_child(_make_sprite_card(sprite_id))

	root_vbox.add_child(HSeparator.new())

	# ── Contract planner ──────────────────────────────────────────────────────
	var contract_title := Label.new()
	contract_title.text = "Contract Suggestions — based on harvest calendar"
	contract_title.add_theme_font_size_override("font_size", 14)
	contract_title.add_theme_color_override("font_color", COL_HEADER)
	root_vbox.add_child(contract_title)

	var contract_scroll := ScrollContainer.new()
	contract_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(contract_scroll)

	_contract_box = VBoxContainer.new()
	_contract_box.add_theme_constant_override("separation", 4)
	contract_scroll.add_child(_contract_box)

	_refresh_contract_panel()

	# ── Hiring rules reminder ─────────────────────────────────────────────────
	var rules_label := Label.new()
	rules_label.add_theme_font_size_override("font_size", 10)
	rules_label.add_theme_color_override("font_color", COL_SUBTEXT)
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_label.text = (
		"Hiring rules: Contracts = 1/3/7 days  |  Work starts NEXT day  |  1 day rest after contract  |  " +
		"Hut: 9am–6pm (9am–7pm on festivals)  |  Need ≥3 hearts to hire  |  Best gift: Flour (50G, gift-wrapped)"
	)
	root_vbox.add_child(rules_label)


func _make_top_bar() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 48)
	hbox.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "Sprite Manager"
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

	var btn_econ := Button.new()
	btn_econ.text = "← Economics"
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


func _make_sprite_card(sprite_id: String) -> PanelContainer:
	var sp     := SpritesData.get_sprite(sprite_id)
	var hearts := AppState.get_sprite_hearts(sprite_id)
	var hireable := SpritesData.can_hire(hearts)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 160)

	var style := StyleBoxFlat.new()
	var sp_color: Color = sp.get("color", Color.WHITE)
	style.bg_color = sp_color.darkened(0.70)
	style.border_color = sp_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Name + color badge
	var name_lbl := Label.new()
	name_lbl.text = "%s (%s)" % [sp.name, sp.color_name]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", sp_color.lightened(0.5))
	vbox.add_child(name_lbl)

	# Birthday
	var bday_lbl := Label.new()
	bday_lbl.text = "Birthday: %s %d" % [sp.birth_season.capitalize(), sp.birth_day]
	bday_lbl.add_theme_font_size_override("font_size", 10)
	bday_lbl.add_theme_color_override("font_color", COL_SUBTEXT)
	vbox.add_child(bday_lbl)

	# Birthday in current season?
	if sp.birth_season == _season:
		var alert := Label.new()
		alert.text = "🎂 Birthday this season! Gift flour."
		alert.add_theme_font_size_override("font_size", 10)
		alert.add_theme_color_override("font_color", COL_GOLD)
		vbox.add_child(alert)

	# Hearts input
	var hbox_hearts := HBoxContainer.new()
	var hearts_lbl := Label.new()
	hearts_lbl.text = "Hearts:"
	hearts_lbl.add_theme_font_size_override("font_size", 11)
	hearts_lbl.add_theme_color_override("font_color", COL_TEXT)
	hbox_hearts.add_child(hearts_lbl)

	var hearts_spin := SpinBox.new()
	hearts_spin.min_value = 0
	hearts_spin.max_value = SpritesData.MAX_HEARTS
	hearts_spin.value = hearts
	hearts_spin.custom_minimum_size = Vector2(70, 0)
	hearts_spin.value_changed.connect(func(v):
		AppState.set_sprite_hearts(sprite_id, int(v))
		_update_card_hireable(sprite_id, SpritesData.can_hire(int(v)))
	)
	hbox_hearts.add_child(hearts_spin)
	vbox.add_child(hbox_hearts)

	# Hireable status
	var hire_lbl := Label.new()
	hire_lbl.text = "✓ Can hire" if hireable else "✗ Need %d more hearts" % (SpritesData.MIN_HEARTS_TO_HIRE - hearts)
	hire_lbl.add_theme_font_size_override("font_size", 11)
	hire_lbl.add_theme_color_override("font_color", COL_GREEN if hireable else COL_RED)
	hire_lbl.name = "HireLabel"
	vbox.add_child(hire_lbl)

	_sprite_cards[sprite_id] = {"panel": panel, "hire_lbl": hire_lbl}
	return panel


func _update_card_hireable(sprite_id: String, hireable: bool) -> void:
	var card = _sprite_cards.get(sprite_id, {})
	if card.is_empty():
		return
	var hire_lbl: Label = card.get("hire_lbl")
	if hire_lbl == null:
		return
	var hearts := AppState.get_sprite_hearts(sprite_id)
	hire_lbl.text = "✓ Can hire" if hireable else "✗ Need %d more hearts" % (SpritesData.MIN_HEARTS_TO_HIRE - hearts)
	hire_lbl.add_theme_color_override("font_color", COL_GREEN if hireable else COL_RED)
	_refresh_contract_panel()


func _refresh_contract_panel() -> void:
	if _contract_box == null:
		return
	for child in _contract_box.get_children():
		child.queue_free()

	var schedule := Calculator.build_daily_schedule(_season, AppState.active_plan_entries)
	var hireable := AppState.get_hireable_sprites()

	if hireable.is_empty():
		var lbl := Label.new()
		lbl.text = "No sprites with ≥3 hearts. Raise friendship to unlock hiring."
		lbl.add_theme_color_override("font_color", COL_SUBTEXT)
		lbl.add_theme_font_size_override("font_size", 11)
		_contract_box.add_child(lbl)
		return

	# Find heavy harvest days
	var heavy_days: Array = []
	for day in range(1, 31):
		var count: int = schedule.get(day, {}).get("count", 0)
		if count > 0:
			heavy_days.append({"day": day, "count": count})

	if heavy_days.is_empty():
		var lbl := Label.new()
		lbl.text = "No harvests scheduled. Add crops in the Season Planner."
		lbl.add_theme_color_override("font_color", COL_SUBTEXT)
		_contract_box.add_child(lbl)
		return

	# Group harvest days into contract windows
	# Strategy: for each harvest cluster, suggest hiring a sprite 1 day before
	var suggestions := _suggest_contracts(heavy_days, hireable)

	for s in suggestions:
		var lbl := Label.new()
		var sp := SpritesData.get_sprite(s.sprite_id)
		lbl.text = (
			"Hire %s on Day %d  →  %d-day contract (works Days %d–%d)  |  covers %d harvests" % [
				sp.get("name", s.sprite_id),
				s.hire_day,
				s.contract_days,
				s.hire_day + 1,
				s.hire_day + s.contract_days,
				s.harvests_covered,
			]
		)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", (sp.get("color", Color.WHITE) as Color).lightened(0.3))
		_contract_box.add_child(lbl)


func _suggest_contracts(heavy_days: Array, hireable: Array) -> Array:
	if heavy_days.is_empty() or hireable.is_empty():
		return []

	var suggestions: Array = []
	var sprite_available_from: Dictionary = {}
	for sid in hireable:
		sprite_available_from[sid] = 1  # available from day 1

	# Walk harvest days and assign contracts greedily
	var i := 0
	while i < heavy_days.size():
		var start_day: int = heavy_days[i].day

		# Find how many consecutive/close harvest days form a cluster
		var cluster_end := start_day
		var j := i
		while j < heavy_days.size() and heavy_days[j].day <= cluster_end + 3:
			cluster_end = heavy_days[j].day
			j += 1

		var duration := cluster_end - start_day + 1
		var contract_len: int = 1
		for cl in [7, 3, 1]:
			if cl >= duration:
				contract_len = cl

		var hire_day := max(1, start_day - 1)  # hire the day before cluster starts

		# Pick the first available hireable sprite
		var chosen_sprite := ""
		for sid in hireable:
			if sprite_available_from.get(sid, 1) <= hire_day:
				chosen_sprite = sid
				break

		if chosen_sprite != "":
			var harvests_covered := 0
			for hd in heavy_days:
				var work_start := hire_day + 1
				var work_end   := hire_day + contract_len
				if hd.day >= work_start and hd.day <= work_end:
					harvests_covered += hd.count

			suggestions.append({
				"sprite_id": chosen_sprite,
				"hire_day": hire_day,
				"contract_days": contract_len,
				"harvests_covered": harvests_covered,
			})

			# Mark sprite unavailable during contract + 1 rest day
			sprite_available_from[chosen_sprite] = hire_day + contract_len + SpritesData.REST_DAYS_AFTER_CONTRACT + 1

		i = j

	return suggestions


func _on_season_changed(idx: int) -> void:
	_season = ["spring", "summer", "fall"][idx]
	AppState.set_season(_season)
	_refresh_contract_panel()
