extends Node2D

var health := 34.0
var age := 0.0
var dead := false
var radius := 25.0

func tick(delta: float) -> void:
	age += delta
	position.y += 47.0 * delta
	var depth := clampf((position.y - 140.0) / 650.0, 0.0, 1.0)
	scale = Vector2.ONE * lerpf(0.55, 1.05, depth)
	z_index = int(position.y)
	queue_redraw()

func take_hit(amount: float) -> bool:
	health -= amount
	if health <= 0:
		dead = true
	return dead

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.4))
	draw_circle(Vector2(0,22), 27, Color(0,0,0,0.35))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-22,-30,44,54), Color("a43c2d"))
	draw_rect(Rect2(-22,-20,44,11), Color("d9c64d"))
	draw_rect(Rect2(-22,10,44,8), Color("592921"))
	draw_line(Vector2(-23,-30),Vector2(23,-30),Color("e26a43"),5)
	draw_line(Vector2(-23,24),Vector2(23,24),Color("55251e"),5)
	draw_circle(Vector2(0,-15), 5, Color("20251c"))
	# Small warning glint.
	draw_circle(Vector2(14,-25), 2.0 + sin(age*5.0), Color("ffb43c"))
