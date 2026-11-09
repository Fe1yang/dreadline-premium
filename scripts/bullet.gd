extends Node2D

var velocity := Vector2(0,-820)
var damage := 20.0
var life := 1.4
var tint := Color("fff2a8")

func tick(delta: float) -> void:
	position += velocity * delta
	life -= delta
	z_index = int(position.y) + 2
	queue_redraw()

func _draw() -> void:
	var tail := velocity.normalized() * -18.0
	draw_line(tail, Vector2.ZERO, Color(tint, 0.18), 8.0, true)
	draw_line(tail, Vector2.ZERO, tint, 3.0, true)
	draw_circle(Vector2.ZERO, 2.5, Color.WHITE)
