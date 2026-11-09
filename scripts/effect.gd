extends Node2D

var velocity := Vector2.ZERO
var life := 0.5
var total_life := 0.5
var tint := Color.WHITE
var size := 5.0
var gravity := 0.0
var text := ""
var ring := false

func tick(delta: float) -> void:
	life -= delta
	position += velocity * delta
	velocity.y += gravity * delta
	z_index = 2000
	queue_redraw()

func _draw() -> void:
	var a := clampf(life / total_life, 0.0, 1.0)
	if not text.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(-25,0), text, HORIZONTAL_ALIGNMENT_CENTER, 50, 18, Color(tint,a))
	elif ring:
		draw_arc(Vector2.ZERO, size*(1.0-a+0.2), 0, TAU, 40, Color(tint,a), 5.0*a+1.0, true)
	else:
		draw_circle(Vector2.ZERO, size*a, Color(tint,a))
