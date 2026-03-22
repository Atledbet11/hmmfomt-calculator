# scripts/main_menu.gd
# Main menu screen.
# Music stub: opening theme will be triggered here when audio is added.
extends Control

const COL_BG        := Color(0.08, 0.28, 0.08)
const COL_PANEL     := Color(0.12, 0.38, 0.12)
const COL_TITLE     := Color(0.98, 0.95, 0.60)
const COL_BTN_NORM  := Color(0.70, 0.52, 0.18)
const COL_BTN_HOV   := Color(0.88, 0.68, 0.24)
const COL_BTN_TXT   := Color(0.10, 0.06, 0.02)

const SCENES := {
	"Farm Editor":     "res://scenes/farm_editor.tscn",
	"Season Planner":  "res://scenes/season_planner.tscn",
	"Calendar View":   "res://scenes/calendar_view.tscn",
	"Economics":       "res://scenes/economics_panel.tscn",
	"Sprite Manager":  "res://scenes/sprite_manager.tscn",
}


func _ready() -> void:
	# TODO: play opening theme here once audio assets are available
	# $AudioStreamPlayer.play()

	_build_ui()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centered panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 480)
	panel.position = Vector2(-210, -240)

	var style := StyleBoxFlat.new()
	style.bg_color = COL_PANEL
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_color = COL_BTN_NORM
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	# Spacer top
	var spacer_top := Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer_top)

	# Title
	var title := Label.new()
	title.text = "HMMFOMT\nFarm Calculator"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COL_TITLE)
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	# Subtitle
	var sub := Label.new()
	sub.text = "Harvest Moon: More Friends of Mineral Town"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.80, 0.78, 0.50))
	sub.add_theme_font_size_override("font_size", 11)
	vbox.add_child(sub)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", COL_BTN_NORM)
	vbox.add_child(sep)

	# Nav buttons
	for label in SCENES.keys():
		vbox.add_child(_make_button(label, SCENES[label]))

	# Spacer bottom
	var spacer_bot := Control.new()
	spacer_bot.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer_bot)

	# Version label
	var ver := Label.new()
	ver.text = "v0.1.0 — planning tool only"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_color_override("font_color", Color(0.55, 0.72, 0.45))
	ver.add_theme_font_size_override("font_size", 10)
	add_child(ver)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ver.offset_top = -28


func _make_button(label: String, scene_path: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(320, 44)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", COL_BTN_TXT)

	var style_norm := StyleBoxFlat.new()
	style_norm.bg_color = COL_BTN_NORM
	style_norm.corner_radius_top_left = 6
	style_norm.corner_radius_top_right = 6
	style_norm.corner_radius_bottom_left = 6
	style_norm.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style_norm)

	var style_hov := StyleBoxFlat.new()
	style_hov.bg_color = COL_BTN_HOV
	style_hov.corner_radius_top_left = 6
	style_hov.corner_radius_top_right = 6
	style_hov.corner_radius_bottom_left = 6
	style_hov.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("hover", style_hov)

	btn.pressed.connect(func(): _goto(scene_path))
	return btn


func _goto(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
