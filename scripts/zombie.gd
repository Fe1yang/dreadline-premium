extends Node2D

var kind := "walker"
var health := 40.0
var max_health := 40.0
var speed := 55.0
var damage := 18.0
var reward := 1
var radius := 29.0
var age := 0.0
var hit_flash := 0.0
var dead := false

func configure(type: String, difficulty: float) -> void:
	kind = type
	match kind:
		"runner":
			health = 26.0 * difficulty
			speed = 91.0 + difficulty * 3.0
			damage = 14.0
			reward = 2
			radius = 24.0
		"brute":
			health = 150.0 * difficulty
			speed = 35.0 + difficulty
			damage = 32.0
			reward = 5
			radius = 41.0
		_:
			health = 44.0 * difficulty
			speed = 52.0 + difficulty * 2.0
			damage = 18.0
			reward = 1
	max_health = health
	age = randf() * 4.0

func tick(delta: float) -> void:
	age += delta
	position.y += speed * delta
	var depth := clampf((position.y - 140.0) / 650.0, 0.0, 1.0)
	scale = Vector2.ONE * lerpf(0.52, 1.06, depth)
	z_index = int(position.y)
	hit_flash = maxf(0.0, hit_flash - delta)
	queue_redraw()

func take_hit(amount: float) -> bool:
	health -= amount
	hit_flash = 0.075
	if health <= 0.0:
		dead = true
	return dead

func _draw() -> void:
	var brute := kind == "brute"
	var runner := kind == "runner"
	var body: Color = Color("823d35") if runner else Color("455b49")
	var skin: Color = Color("a6bd71") if not brute else Color("78985c")
	if hit_flash > 0:
		body = Color("f2edc7")
		skin = Color("ffffff")
	var w := 1.32 if brute else 1.0
	var bob := sin(age * (10.0 if runner else 6.0)) * 2.0
	var step := sin(age * (10.0 if runner else 6.0)) * 6.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1,0.38))
	draw_circle(Vector2(0, 22), 31.0 * w, Color(0.01,0.02,0.015,0.42))
	draw_set_transform(Vector2.ZERO)
	# Uneven legs sell the shamble.
	draw_line(Vector2(-10*w,10), Vector2(-12*w+step,31), Color("28352f"), 10.0*w, true)
	draw_line(Vector2(10*w,10), Vector2(13*w-step,31), Color("28352f"), 10.0*w, true)
	# Reaching arms.
	draw_line(Vector2(-19*w,-17+bob), Vector2(-31*w,-41+bob+step), skin, 11.0*w, true)
	draw_line(Vector2(19*w,-17+bob), Vector2(30*w,-45+bob-step), skin, 11.0*w, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-23*w,-24+bob),Vector2(21*w,-23+bob),Vector2(25*w,13),Vector2(-20*w,16)]), body)
	# Torn shirt highlights.
	draw_colored_polygon(PackedVector2Array([Vector2(-23*w,-24+bob),Vector2(-5*w,-23+bob),Vector2(-9*w,14),Vector2(-20*w,16)]), body.darkened(0.22))
	draw_line(Vector2(3,-18+bob), Vector2(14,4), Color("b8c49b"), 3.0)
	# Head and glowing eyes.
	draw_circle(Vector2(0,-40+bob), 17.0*w, skin)
	draw_colored_polygon(PackedVector2Array([Vector2(-16*w,-43+bob),Vector2(15*w,-48+bob),Vector2(13*w,-33+bob),Vector2(-14*w,-31+bob)]), skin.darkened(0.12))
	draw_circle(Vector2(-6*w,-42+bob), 2.4, Color("ff5e3a"))
	draw_circle(Vector2(6*w,-43+bob), 2.4, Color("ff5e3a"))
	draw_line(Vector2(-5,-32+bob), Vector2(6,-33+bob), Color("253027"), 3.0)
	if health < max_health or brute:
		var width := 52.0 * w
		draw_rect(Rect2(-width/2,-75*w,width,5), Color(0.04,0.07,0.06,0.85))
		draw_rect(Rect2(-width/2,-75*w,width*clampf(health/max_health,0,1),5), Color("ff7043") if brute else Color("c9f54a"))
