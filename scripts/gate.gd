extends Node2D

var left: Dictionary = {}
var right: Dictionary = {}
var resolved := false
var selected := -1
var fade := 1.0
var pulse := 0.0

func setup(first: Dictionary, second: Dictionary) -> void:
	left = first
	right = second

func tick(delta: float) -> void:
	pulse += delta
	if not resolved:
		position.y += 105.0 * delta
	else:
		fade = maxf(0.0, fade - delta * 2.4)
	var depth := clampf((position.y - 140.0) / 650.0, 0.0, 1.0)
	scale = Vector2.ONE * lerpf(0.76, 1.0, depth)
	z_index = int(position.y) - 5
	queue_redraw()

func choose(player_x: float) -> Dictionary:
	if resolved:
		return {}
	resolved = true
	selected = 0 if player_x < 270.0 else 1
	return left if selected == 0 else right

func _draw() -> void:
	_draw_option(left, -137.0, 0)
	_draw_option(right, 137.0, 1)

func _draw_option(option: Dictionary, x: float, index: int) -> void:
	if option.is_empty():
		return
	var color: Color = option.get("color", Color("c9f54a"))
	var active := not resolved or selected == index
	var alpha := fade * (1.0 if active else 0.18)
	var rect := Rect2(x - 119, -47, 238, 94)
	# Posts and holographic panel.
	draw_line(Vector2(x-119,45), Vector2(x-119,75), Color(0.35,0.45,0.38,alpha), 6.0)
	draw_line(Vector2(x+119,45), Vector2(x+119,75), Color(0.35,0.45,0.38,alpha), 6.0)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.035,0.075,0.063,0.92*alpha)
	panel.border_color = Color(color, alpha * (0.75 + sin(pulse*4.0)*0.15))
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(12)
	draw_style_box(panel, rect)
	draw_rect(Rect2(x-112,-40,224,4), Color(color,alpha))
	var font := ThemeDB.fallback_font
	var title: String = option.get("title", "UPGRADE")
	var detail: String = option.get("detail", "+40%")
	draw_string(font, Vector2(x-101,-6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.93,0.96,0.88,alpha))
	draw_string(font, Vector2(x-101,26), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color(color,alpha))
