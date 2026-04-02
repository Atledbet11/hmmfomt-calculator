# scripts/splash_screen.gd
# Opening splash: white → fade-in Natsume logo → hold → fade-out to white → main menu.
extends Control

const NEXT_SCENE    : String = "res://scenes/title_screen.tscn"
const FADE_IN_TIME  : float  = 0.5
const HOLD_TIME     : float  = 3.0
const FADE_OUT_TIME : float  = 0.5

var _overlay: ColorRect


func _ready() -> void:
	_build_ui()
	_run_sequence()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Pure white background — visible at start and end of sequence
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Logo — centred, aspect-correct, scaled to fit the window
	var logo_tex := load("res://assets/natsume_logo.png") as Texture2D
	if logo_tex:
		var logo := TextureRect.new()
		logo.texture = logo_tex
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(logo)

	# White overlay drawn on top — starts fully opaque (white screen).
	# Animating its alpha reveals and then hides the logo beneath.
	_overlay = ColorRect.new()
	_overlay.color = Color.WHITE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func _run_sequence() -> void:
	var tween := create_tween()
	# Fade in: white overlay dissolves away → logo becomes visible
	tween.tween_property(_overlay, "color:a", 0.0, FADE_IN_TIME).set_ease(Tween.EASE_IN_OUT)
	# Hold: logo sits on screen
	tween.tween_interval(HOLD_TIME)
	# Fade out: white overlay fades back in → white screen again
	tween.tween_property(_overlay, "color:a", 1.0, FADE_OUT_TIME).set_ease(Tween.EASE_IN_OUT)
	# Music starts the moment the screen is fully white again
	tween.tween_callback(func() -> void:
		MusicManager.play_menu_music()
	)
	# Advance to the title screen
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file(NEXT_SCENE)
	)


# Allow skipping the sequence with any key or mouse click
func _input(event: InputEvent) -> void:
	if event.is_pressed():
		get_tree().change_scene_to_file(NEXT_SCENE)
