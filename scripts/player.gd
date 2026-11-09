extends Node2D

var health := 100.0
var max_health := 100.0
var damage := 20.0
var fire_interval := 0.30
var projectile_count := 1
var gun_level := 1
var scrap := 0
var muzzle_flash := 0.0
var walk_time := 0.0
var hurt_flash := 0.0
var target_x := 270.0

func reset() -> void:
	health = 100.0
	max_health = 100.0
	damage = 20.0
	fire_interval = 0.30
	projectile_count = 1
	gun_level = 1
	scrap = 0
	muzzle_flash = 0.0
	hurt_flash = 0.0
	target_x = 270.0
	position = Vector2(270, 758)
	queue_redraw()

func tick(delta: float) -> void:
	position.x = move_toward(position.x, target_x, 560.0 * delta)
	position.x = clampf(position.x, 65.0, 475.0)
	walk_time += delta * 10.0
	muzzle_flash = maxf(0.0, muzzle_flash - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	queue_redraw()

func fire() -> void:
	muzzle_flash = 0.055

func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	hurt_flash = 0.18

func apply_upgrade(id: String) -> void:
	match id:
		"damage":
			damage *= 1.4
			gun_level += 1
		"rate":
			fire_interval = maxf(0.095, fire_interval * 0.76)
			gun_level += 1
		"split":
			projectile_count = mini(5, projectile_count + 1)
			gun_level += 1
		"heal":
			health = minf(max_health, health + 40.0)

func _draw() -> void:
	var bob := sin(walk_time) * 2.0
	var leg := sin(walk_time) * 6.0
	# Soft shadow and legs.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2(0, 18), 34.0, Color(0.01, 0.02, 0.018, 0.45))
	draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(-10, 14), Vector2(-12 + leg, 34), Color("25352e"), 10.0, true)
	draw_line(Vector2(10, 14), Vector2(12 - leg, 34), Color("25352e"), 10.0, true)
	draw_line(Vector2(-14 + leg, 34), Vector2(-4 + leg, 34), Color("0b1210"), 7.0, true)
	draw_line(Vector2(10 - leg, 34), Vector2(20 - leg, 34), Color("0b1210"), 7.0, true)
	# Backpack and jacket.
	draw_style_box(_box(Color("344b3c"), 7), Rect2(-25, -28 + bob, 50, 52))
	draw_colored_polygon(PackedVector2Array([Vector2(-28,-21+bob),Vector2(20,-25+bob),Vector2(27,14+bob),Vector2(-24,18+bob)]), Color("bfdf45") if hurt_flash <= 0 else Color("ffffff"))
	draw_colored_polygon(PackedVector2Array([Vector2(-28,-21+bob),Vector2(-10,-24+bob),Vector2(-8,17+bob),Vector2(-24,18+bob)]), Color("7c9636"))
	draw_line(Vector2(-5,-21+bob), Vector2(-4,14+bob), Color("17241d"), 3.0)
	# Head, cap and face.
	draw_circle(Vector2(0, -39 + bob), 16, Color("d8a06e"))
	draw_arc(Vector2(0,-42+bob), 16, PI, TAU, 16, Color("18251f"), 10.0, true)
	draw_line(Vector2(-15,-43+bob), Vector2(18,-40+bob), Color("18251f"), 5.0, true)
	# Arms and gun point up-screen.
	draw_line(Vector2(-21,-14+bob), Vector2(-10,-43+bob), Color("d8a06e"), 10.0, true)
	draw_line(Vector2(21,-13+bob), Vector2(11,-48+bob), Color("d8a06e"), 10.0, true)
	draw_line(Vector2(0,-28+bob), Vector2(0,-78+bob), Color("101917"), 12.0, true)
	draw_line(Vector2(0,-49+bob), Vector2(0,-82+bob), Color("62756c"), 5.0, true)
	draw_line(Vector2(-8,-37+bob), Vector2(8,-37+bob), Color("101917"), 7.0, true)
	if muzzle_flash > 0:
		draw_colored_polygon(PackedVector2Array([Vector2(0,-101+bob),Vector2(-8,-82+bob),Vector2(0,-86+bob),Vector2(8,-82+bob)]), Color("fff2a8"))
		draw_circle(Vector2(0,-84+bob), 7, Color("ff9d42"))

func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box
