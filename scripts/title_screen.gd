# scripts/title_screen.gd
# Animated title screen sequence — placeholder rectangles, real UI assets.
# Swap ColorRect placeholders for AnimatedSprite2D when art is ready.
extends Control

const NEXT_SCENE := "res://scenes/main_menu.tscn"

# ── Layout constants ──────────────────────────────────────────────────────────
const PANEL_W   : float = 1280.0   # each bg panel fills screen width
const PANEL_H   : float = 800.0
const GROUND_Y  : float = 530.0    # y where character feet rest

# Title logo: source 160×96, displayed at 4× = 640×384
const LOGO_W    : float = 640.0
const LOGO_H    : float = 384.0
const LOGO_X    : float = (1280.0 - 640.0) / 2.0   # 320

# ── Timing (seconds) ─────────────────────────────────────────────────────────
const T_FADE_IN    : float = 0.50
const T_PAN        : float = 2.00   # pan + player walk-in
const T_ROTATE     : float = 0.20   # per rotation (squish & flip)
const T_PAUSE_1    : float = 0.50   # before whistle
const T_DOG_RUN    : float = 0.75
const T_ANIMALS_IN : float = 1.50   # cow + sheep + player jumps
const T_JUMP_EACH  : float = 0.22   # × 6 jumps
const T_TITLE_DROP : float = 0.65
const T_CHICK_OUT  : float = 0.40
const T_PAUSE_2    : float = 0.30
const T_CHICK_IN   : float = 0.65
const T_BTN_APPEAR : float = 0.35

# ── Placeholder colours ───────────────────────────────────────────────────────
const COL_PLAYER  := Color(0.20, 0.45, 0.90)
const COL_DOG     := Color(0.55, 0.35, 0.15)
const COL_COW     := Color(0.85, 0.65, 0.30)
const COL_SHEEP   := Color(0.95, 0.95, 0.95)
const COL_CHICKEN := Color(0.95, 0.85, 0.10)

# ── Character sizes (screen pixels) ──────────────────────────────────────────
const PLAYER_SIZE  := Vector2(50.0, 80.0)
const DOG_SIZE     := Vector2(40.0, 35.0)
const COW_SIZE     := Vector2(80.0, 55.0)
const SHEEP_SIZE   := Vector2(70.0, 50.0)
const CHICKEN_SIZE := Vector2(35.0, 30.0)

# ── Final character screen positions (x = left edge) ─────────────────────────
const PLAYER_FINAL_X   : float = 615.0
const DOG_FINAL_X      : float = 672.0
const COW_FINAL_X      : float = 855.0
const SHEEP_FINAL_X    : float = 395.0
const CHICKEN1_LAND_X  : float = 365.0   # lands near sheep
const CHICKEN2_LAND_X  : float = 862.0   # lands near cow

# ── Node references ───────────────────────────────────────────────────────────
var _bg_container  : Control
var _player        : Control
var _player_dir    : Label
var _dog           : ColorRect
var _cow           : ColorRect
var _sheep         : ColorRect
var _chicken1      : Control
var _chicken2      : Control
var _title_logo    : TextureRect
var _continue_btn  : TextureRect
var _start_btn     : TextureRect
var _pointer       : TextureRect
var _overlay       : ColorRect

var _can_skip      : bool = false


func _ready() -> void:
	_build_ui()
	_run_sequence()


func _input(event: InputEvent) -> void:
	if _can_skip and event.is_pressed():
		get_tree().change_scene_to_file(NEXT_SCENE)


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Scrolling background (clipped to screen)
	var clip := Control.new()
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.clip_contents = true
	add_child(clip)

	_bg_container = Control.new()
	_bg_container.position = Vector2(-PANEL_W, 0.0)  # start showing right panel
	clip.add_child(_bg_container)

	var bg_tex := load("res://assets/title_screen_bg1.png") as Texture2D
	for i in 2:
		var tr := TextureRect.new()
		tr.texture = bg_tex
		tr.size = Vector2(PANEL_W, PANEL_H)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.position = Vector2(i * PANEL_W, 0.0)
		_bg_container.add_child(tr)

	# ── Placeholders ─────────────────────────────────────────────────────────

	# Sheep — starts off the left edge
	_sheep = _make_rect(COL_SHEEP, SHEEP_SIZE, "Sheep")
	_sheep.position = Vector2(-160.0, GROUND_Y - SHEEP_SIZE.y)
	add_child(_sheep)

	# Cow — starts off the right edge
	_cow = _make_rect(COL_COW, COW_SIZE, "Cow")
	_cow.position = Vector2(1450.0, GROUND_Y - COW_SIZE.y)
	add_child(_cow)

	# Dog — starts off the right edge
	_dog = _make_rect(COL_DOG, DOG_SIZE, "Dog")
	_dog.position = Vector2(1450.0, GROUND_Y - DOG_SIZE.y)
	add_child(_dog)

	# Chickens — start hidden behind where the title will land
	_chicken1 = _make_ctrl(COL_CHICKEN, CHICKEN_SIZE, "Chk")
	_chicken1.position = Vector2(LOGO_X + 120.0, LOGO_H * 0.35)
	_chicken1.modulate.a = 0.0
	add_child(_chicken1)

	_chicken2 = _make_ctrl(COL_CHICKEN, CHICKEN_SIZE, "Chk")
	_chicken2.position = Vector2(LOGO_X + LOGO_W - 155.0, LOGO_H * 0.35)
	_chicken2.modulate.a = 0.0
	add_child(_chicken2)

	# Player — starts off the right edge, has direction arrow
	_player = Control.new()
	_player.pivot_offset = PLAYER_SIZE / 2.0
	var pr := ColorRect.new()
	pr.color = COL_PLAYER
	pr.size = PLAYER_SIZE
	_player.add_child(pr)
	_player_dir = Label.new()
	_player_dir.text = "←"
	_player_dir.add_theme_font_size_override("font_size", 20)
	_player_dir.add_theme_color_override("font_color", Color.WHITE)
	_player_dir.position = Vector2(10.0, 26.0)
	_player.add_child(_player_dir)
	_player.position = Vector2(1450.0, GROUND_Y - PLAYER_SIZE.y)
	add_child(_player)

	# ── Real assets ───────────────────────────────────────────────────────────

	# Title logo — starts above the screen
	var logo_tex := load("res://assets/title_screen_logo.png") as Texture2D
	_title_logo = TextureRect.new()
	_title_logo.texture = logo_tex
	_title_logo.size = Vector2(LOGO_W, LOGO_H)
	_title_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_logo.position = Vector2(LOGO_X, -LOGO_H)
	add_child(_title_logo)

	# Continue button: 79×18 at 4× = 316×72, centred
	var cont_tex := load("res://assets/title_screen_continue.png") as Texture2D
	_continue_btn = TextureRect.new()
	_continue_btn.texture = cont_tex
	_continue_btn.size = Vector2(316.0, 72.0)
	_continue_btn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_continue_btn.position = Vector2((1280.0 - 316.0) / 2.0, 415.0)
	_continue_btn.modulate.a = 0.0
	add_child(_continue_btn)

	# Start button: 54×15 at 4× = 216×60, centred
	var start_tex := load("res://assets/title_screen_start.png") as Texture2D
	_start_btn = TextureRect.new()
	_start_btn.texture = start_tex
	_start_btn.size = Vector2(216.0, 60.0)
	_start_btn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_start_btn.position = Vector2((1280.0 - 216.0) / 2.0, 496.0)
	_start_btn.modulate.a = 0.0
	add_child(_start_btn)

	# Pointer: 16×13 at 4× = 64×52, left of Continue
	var ptr_tex := load("res://assets/title_screen_pointer.png") as Texture2D
	_pointer = TextureRect.new()
	_pointer.texture = ptr_tex
	_pointer.size = Vector2(64.0, 52.0)
	_pointer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pointer.position = Vector2((1280.0 - 316.0) / 2.0 - 72.0, 426.0)
	_pointer.modulate.a = 0.0
	add_child(_pointer)

	# White overlay — sits on top of everything, fades out at start
	_overlay = ColorRect.new()
	_overlay.color = Color.WHITE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)


# ── Sequence ──────────────────────────────────────────────────────────────────

func _run_sequence() -> void:
	# 1. Fade in from white
	var t := create_tween()
	t.tween_property(_overlay, "color:a", 0.0, T_FADE_IN).set_ease(Tween.EASE_IN_OUT)
	await t.finished

	# 2. Pan background left + player walks in from right (simultaneous)
	var t2 := create_tween()
	t2.set_parallel(true)
	t2.tween_property(_bg_container, "position:x", 0.0, T_PAN) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t2.tween_property(_player, "position:x", PLAYER_FINAL_X, T_PAN) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await t2.finished

	# 3. Rotate player to face down (squish-flip effect)
	await _flip_player("↓")

	await get_tree().create_timer(0.25).timeout

	# 4. Rotate player to face right
	await _flip_player("→")

	# 5. Pause, then whistle
	await get_tree().create_timer(T_PAUSE_1).timeout
	_show_whistle()

	# 6. Dog runs in from right
	var t6 := create_tween()
	t6.tween_property(_dog, "position:x", DOG_FINAL_X, T_DOG_RUN) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await t6.finished

	await get_tree().create_timer(0.2).timeout

	# 7. Cow + Sheep walk in simultaneously; player celebrates with 6 jumps
	var t7 := create_tween()
	t7.set_parallel(true)
	t7.tween_property(_cow, "position:x", COW_FINAL_X, T_ANIMALS_IN) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t7.tween_property(_sheep, "position:x", SHEEP_FINAL_X, T_ANIMALS_IN) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_do_player_jumps()   # fire-and-forget coroutine — runs alongside animals
	await t7.finished

	_player_dir.text = "→"
	await get_tree().create_timer(0.3).timeout

	# 8. Title logo drops from above, bounces into place
	var t8 := create_tween()
	t8.tween_property(_title_logo, "position:y", 0.0, T_TITLE_DROP) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await t8.finished

	await get_tree().create_timer(0.2).timeout

	# 9. Chickens emerge from behind title, fly off at 45° angles
	_chicken1.modulate.a = 1.0
	_chicken2.modulate.a = 1.0
	var t9 := create_tween()
	t9.set_parallel(true)
	t9.tween_property(_chicken1, "position", Vector2(-220.0, 920.0), T_CHICK_OUT) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t9.tween_property(_chicken2, "position", Vector2(1500.0, 920.0), T_CHICK_OUT) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await t9.finished

	await get_tree().create_timer(T_PAUSE_2).timeout

	# 10. Chickens fly back in and land beside sheep and cow
	var land_y: float = GROUND_Y - CHICKEN_SIZE.y
	var t10 := create_tween()
	t10.set_parallel(true)
	t10.tween_property(_chicken1, "position", Vector2(CHICKEN1_LAND_X, land_y), T_CHICK_IN) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t10.tween_property(_chicken2, "position", Vector2(CHICKEN2_LAND_X, land_y), T_CHICK_IN) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await t10.finished

	# 11. Buttons and pointer fade in
	var t11 := create_tween()
	t11.set_parallel(true)
	t11.tween_property(_continue_btn, "modulate:a", 1.0, T_BTN_APPEAR)
	t11.tween_property(_start_btn,    "modulate:a", 1.0, T_BTN_APPEAR)
	t11.tween_property(_pointer,      "modulate:a", 1.0, T_BTN_APPEAR)
	await t11.finished

	# Sequence complete — any key proceeds to main menu
	_can_skip = true


# ── Sub-animations ────────────────────────────────────────────────────────────

func _flip_player(new_dir: String) -> void:
	var ta := create_tween()
	ta.tween_property(_player, "scale:x", 0.0, T_ROTATE / 2.0).set_ease(Tween.EASE_IN)
	await ta.finished
	_player_dir.text = new_dir
	var tb := create_tween()
	tb.tween_property(_player, "scale:x", 1.0, T_ROTATE / 2.0).set_ease(Tween.EASE_OUT)
	await tb.finished


func _do_player_jumps() -> void:
	var base_y: float = GROUND_Y - PLAYER_SIZE.y
	for i in range(6):
		_player_dir.text = "↑"
		var tj := create_tween()
		tj.tween_property(_player, "position:y", base_y - 26.0, T_JUMP_EACH / 2.0) \
			.set_ease(Tween.EASE_OUT)
		tj.tween_property(_player, "position:y", base_y, T_JUMP_EACH / 2.0) \
			.set_ease(Tween.EASE_IN)
		await tj.finished
		_player_dir.text = "→"


func _show_whistle() -> void:
	var note := Label.new()
	note.text = "♪"
	note.add_theme_font_size_override("font_size", 24)
	note.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	note.position = _player.position + Vector2(8.0, -40.0)
	add_child(note)
	var tn := create_tween()
	tn.set_parallel(true)
	tn.tween_property(note, "position:y", note.position.y - 35.0, 0.9)
	tn.tween_property(note, "modulate:a", 0.0, 0.9)
	await tn.finished
	note.queue_free()


# ── Placeholder helpers ───────────────────────────────────────────────────────

func _make_rect(color: Color, size: Vector2, tag: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.size = size
	var lbl := Label.new()
	lbl.text = tag
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.65))
	lbl.position = Vector2(2.0, 2.0)
	rect.add_child(lbl)
	return rect


func _make_ctrl(color: Color, size: Vector2, tag: String) -> Control:
	var ctrl := Control.new()
	var rect := ColorRect.new()
	rect.color = color
	rect.size = size
	ctrl.add_child(rect)
	var lbl := Label.new()
	lbl.text = tag
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.65))
	lbl.position = Vector2(2.0, 2.0)
	ctrl.add_child(lbl)
	return ctrl
