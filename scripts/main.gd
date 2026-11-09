extends Node2D

const PlayerScript = preload("res://scripts/player.gd")
const ZombieScript = preload("res://scripts/zombie.gd")
const BulletScript = preload("res://scripts/bullet.gd")
const GateScript = preload("res://scripts/gate.gd")
const BarrelScript = preload("res://scripts/barrel.gd")
const EffectScript = preload("res://scripts/effect.gd")
const SoundScript = preload("res://scripts/sound.gd")
const HudScript = preload("res://scripts/hud.gd")

var state := "menu"
var player: Node2D
var sound: Node
var hud: Control
var zombies: Array = []
var bullets: Array = []
var gates: Array = []
var barrels: Array = []
var effects: Array = []
var buildings: Array = []
var props: Array = []
var rng := RandomNumberGenerator.new()
var run_time := 0.0
var distance := 0.0
var kills := 0
var wave := 1
var best_distance := 0
var spawn_timer := 0.0
var gate_timer := 7.0
var barrel_timer := 5.0
var shot_timer := 0.0
var scroll := 0.0
var elapsed := 0.0
var damage_flash := 0.0
var shake := 0.0
var wave_banner := 0.0
var hint_time := 5.0
var dragging := false
var new_gate_index := 0

func _ready() -> void:
	rng.randomize()
	_load_save()
	_make_environment()
	sound = SoundScript.new()
	add_child(sound)
	sound.muted = _read_muted()
	player = PlayerScript.new()
	add_child(player)
	player.reset()
	player.z_index = 760
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HudScript.new()
	hud.game = self
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_zombies()
	if "--capture" in OS.get_cmdline_user_args():
		call_deferred("_capture")
	elif "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("_smoke_test")
	elif "--soak-test" in OS.get_cmdline_user_args():
		call_deferred("_soak_test")

func _process(delta: float) -> void:
	elapsed += delta
	scroll += delta * (88.0 if state == "playing" else 16.0)
	_update_props(delta * (1.0 if state == "playing" else 0.18))
	damage_flash = maxf(0.0, damage_flash - delta)
	shake = maxf(0.0, shake - delta * 2.8)
	position = Vector2(rng.randf_range(-5,5),rng.randf_range(-4,4)) * shake if shake > 0 else Vector2.ZERO
	queue_redraw()
	if state != "playing":
		return
	run_time += delta
	distance += delta * 10.5
	hint_time = maxf(0.0, hint_time-delta)
	wave_banner = maxf(0.0, wave_banner-delta)
	var next_wave := int(run_time / 22.0) + 1
	if next_wave != wave:
		wave = next_wave
		wave_banner = 2.0
		sound.play("gate")
	var axis := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		axis -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		axis += 1.0
	if axis != 0.0:
		player.target_x += axis * 420.0 * delta
	player.target_x = clampf(player.target_x, 65.0, 475.0)
	player.tick(delta)
	shot_timer -= delta
	if shot_timer <= 0.0 and not zombies.is_empty():
		_fire()
		shot_timer = player.fire_interval
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_zombie()
		spawn_timer = maxf(0.34, 0.90 - run_time * 0.004) * rng.randf_range(0.75,1.18)
	gate_timer -= delta
	if gate_timer <= 0.0:
		_spawn_gate()
		gate_timer = 15.0
	barrel_timer -= delta
	if barrel_timer <= 0.0:
		_spawn_barrel()
		barrel_timer = rng.randf_range(8.0,12.0)
	_tick_bullets(delta)
	_tick_zombies(delta)
	_tick_barrels(delta)
	_tick_gates(delta)
	_tick_effects(delta)
	if player.health <= 0.0:
		_end_run()

func _draw() -> void:
	# Dusk sky and a ruined skyline.
	draw_rect(Rect2(0,0,540,960), Color("09120f"))
	draw_rect(Rect2(0,0,540,210), Color("14231e"))
	for item in buildings:
		var x: float = item.x
		var w: float = item.w
		var h: float = item.h
		draw_rect(Rect2(x,190-h,w,h), Color("0c1714"))
		if item.get("broken",false):
			draw_colored_polygon(PackedVector2Array([Vector2(x,190-h),Vector2(x+w*0.35,190-h-16),Vector2(x+w*0.7,190-h),Vector2(x+w,190-h-9),Vector2(x+w,190-h+12),Vector2(x,190-h+12)]),Color("0c1714"))
		for wy in range(int(198-h),182,18):
			for wx in range(int(x+8),int(x+w-5),15):
				if (wx+wy)%3 == 0:
					draw_rect(Rect2(wx,wy,4,6),Color("334338"))
	# Ground and road perspective.
	draw_rect(Rect2(0,190,540,770),Color("15231a"))
	draw_colored_polygon(PackedVector2Array([Vector2(177,170),Vector2(363,170),Vector2(540,960),Vector2(0,960)]),Color("29332d"))
	draw_polyline(PackedVector2Array([Vector2(177,170),Vector2(0,960)]),Color("62704d"),5.0,true)
	draw_polyline(PackedVector2Array([Vector2(363,170),Vector2(540,960)]),Color("62704d"),5.0,true)
	# Road patches and lane dashes move toward the player.
	for i in range(12):
		var y := 170.0 + fmod(i*83.0+scroll,850.0)
		var t := clampf((y-170.0)/790.0,0,1)
		var dash_h := lerpf(7.0,42.0,t)
		draw_line(Vector2(270,y),Vector2(270,y+dash_h),Color(0.64,0.67,0.47,0.32),lerpf(1.0,5.0,t),true)
	for i in range(9):
		var y := 195.0 + fmod(i*107.0+scroll*0.7,790.0)
		var t := (y-170.0)/790.0
		var half := lerpf(80.0,270.0,t)
		var x := 270.0 + sin(i*12.3)*half*0.65
		draw_line(Vector2(x-12*t,y),Vector2(x+18*t,y+4),Color(0.05,0.08,0.065,0.35),2.0+t*2.0,true)
	for p in props:
		_draw_prop(p)
	# Horizon haze.
	draw_rect(Rect2(0,166,540,4),Color(0.61,0.72,0.43,0.15))

func _make_environment() -> void:
	var x := -10.0
	while x < 550:
		var w := rng.randf_range(25,62)
		buildings.append({"x":x,"w":w,"h":rng.randf_range(30,115),"broken":rng.randf()>0.45})
		x += w + rng.randf_range(4,13)
	for i in range(18):
		props.append({"side":-1 if i%2==0 else 1,"y":rng.randf_range(180,960),"kind":i%3})

func _update_props(delta: float) -> void:
	for p in props:
		p.y += delta*80.0
		if p.y > 1000:
			p.y = 175.0
			p.kind = rng.randi_range(0,2)

func _draw_prop(p: Dictionary) -> void:
	var t: float = clampf((p.y-170.0)/790.0,0,1)
	var edge := lerpf(177.0,0.0,t) if p.side == -1 else lerpf(363.0,540.0,t)
	var x: float = edge + p.side*lerpf(18.0,45.0,t)
	var s := lerpf(0.35,1.25,t)
	var y: float = p.y
	if p.kind == 0:
		draw_line(Vector2(x,y),Vector2(x,y-65*s),Color("344331"),7*s,true)
		draw_line(Vector2(x,y-40*s),Vector2(x-p.side*22*s,y-57*s),Color("344331"),5*s,true)
		draw_line(Vector2(x,y-52*s),Vector2(x+p.side*16*s,y-70*s),Color("344331"),4*s,true)
	elif p.kind == 1:
		draw_line(Vector2(x,y),Vector2(x,y-70*s),Color("1a241f"),4*s,true)
		draw_line(Vector2(x,y-70*s),Vector2(x-p.side*18*s,y-70*s),Color("1a241f"),4*s,true)
		draw_circle(Vector2(x-p.side*18*s,y-68*s),4*s,Color("d9b45b"))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(x-15*s,y),Vector2(x-12*s,y-26*s),Vector2(x+17*s,y-22*s),Vector2(x+21*s,y)]),Color("3b4936"))

func _menu_zombies() -> void:
	for i in range(3):
		var z := ZombieScript.new()
		add_child(z)
		z.configure("walker" if i != 1 else "brute",1.0)
		z.position = Vector2(205+i*65,275+i*45)
		z.scale = Vector2.ONE*(0.62+i*0.08)
		z.z_index = int(z.position.y)
		zombies.append(z)

func start_run() -> void:
	_clear_world()
	state = "playing"
	run_time = 0.0
	distance = 0.0
	kills = 0
	wave = 1
	spawn_timer = 0.2
	gate_timer = 7.0
	barrel_timer = 5.0
	shot_timer = 0.0
	hint_time = 5.0
	damage_flash = 0.0
	new_gate_index = 0
	player.reset()
	for i in range(3):
		_spawn_zombie(160.0-i*45)

func _clear_world() -> void:
	for collection in [zombies,bullets,gates,barrels,effects]:
		for node in collection:
			if is_instance_valid(node):
				node.queue_free()
		collection.clear()

func _end_run() -> void:
	state = "gameover"
	dragging = false
	best_distance = maxi(best_distance,int(distance))
	_save()

func _spawn_zombie(at_y := 155.0) -> void:
	var z := ZombieScript.new()
	var difficulty := 1.0 + run_time/75.0
	var roll := rng.randf()
	var kind := "walker"
	if run_time > 12.0 and roll < 0.24:
		kind = "runner"
	if run_time > 24.0 and roll > 0.87:
		kind = "brute"
	add_child(z)
	z.configure(kind,difficulty)
	z.position = Vector2(rng.randf_range(190,350),at_y)
	z.scale = Vector2.ONE*0.52
	zombies.append(z)

func _find_target() -> Node2D:
	var target: Node2D = null
	var best_y := -INF
	for z in zombies:
		if is_instance_valid(z) and not z.dead and z.position.y < player.position.y-35 and z.position.y > best_y:
			target = z
			best_y = z.position.y
	return target

func _fire() -> void:
	var target := _find_target()
	if target == null:
		return
	player.fire()
	sound.play("shot")
	var origin: Vector2 = player.position + Vector2(0,-79)
	var base: Vector2 = (target.position-origin).normalized()
	var count: int = player.projectile_count
	for i in range(count):
		var spread := (i-(count-1)/2.0)*0.105
		var b := BulletScript.new()
		b.position = origin
		b.velocity = base.rotated(spread)*850.0
		b.damage = player.damage
		add_child(b)
		bullets.append(b)
	_spark(origin,Color("ffd073"),2,35.0)

func _tick_bullets(delta: float) -> void:
	for i in range(bullets.size()-1,-1,-1):
		var b = bullets[i]
		b.tick(delta)
		var consumed := false
		for z in zombies:
			if is_instance_valid(z) and not z.dead and b.position.distance_to(z.position-Vector2(0,20)) < z.radius*z.scale.x+8:
				_hit_zombie(z,b.damage)
				consumed = true
				break
		if not consumed:
			for barrel in barrels:
				if not barrel.dead and b.position.distance_to(barrel.position) < 30*barrel.scale.x+7:
					if barrel.take_hit(b.damage):
						_explode(barrel)
					consumed = true
					break
		if consumed or b.life <= 0 or b.position.y < 100 or b.position.x < -30 or b.position.x > 570:
			bullets.remove_at(i)
			b.queue_free()

func _tick_zombies(delta: float) -> void:
	for i in range(zombies.size()-1,-1,-1):
		var z = zombies[i]
		z.tick(delta)
		if z.position.y > player.position.y-28 and z.position.y < player.position.y+40 and absf(z.position.x-player.position.x)<z.radius+24:
			_hurt_player(z.damage)
			_burst(z.position,Color("91a85c"),8)
			zombies.remove_at(i)
			z.queue_free()
		elif z.position.y > 940:
			zombies.remove_at(i)
			z.queue_free()

func _hit_zombie(z: Node2D, amount: float) -> void:
	_spark(z.position-Vector2(0,24),Color("d8ed8b"),3,70.0)
	if z.take_hit(amount):
		kills += 1
		player.scrap += z.reward
		sound.play("kill")
		_popup(z.position,"+%d"%z.reward,Color("c9f54a"))
		_burst(z.position,Color("78935c"),6)
		zombies.erase(z)
		z.queue_free()
	else:
		sound.play("hit")

func _hurt_player(amount: float) -> void:
	player.take_damage(amount)
	damage_flash = 0.42
	shake = 0.75
	sound.play("hurt")

func _spawn_gate() -> void:
	var sets := [
		[{"id":"damage","title":"HEAVY ROUNDS","detail":"+40% DMG","color":Color("ff9e51")},{"id":"rate","title":"FAST TRIGGER","detail":"+32% RPM","color":Color("62dfe1")}],
		[{"id":"split","title":"SPLIT BARREL","detail":"+1 BULLET","color":Color("cf9bff")},{"id":"damage","title":"HEAVY ROUNDS","detail":"+40% DMG","color":Color("ff9e51")}],
		[{"id":"heal","title":"FIELD MEDIC","detail":"+40 HP","color":Color("c9f54a")},{"id":"rate","title":"FAST TRIGGER","detail":"+32% RPM","color":Color("62dfe1")}]
	]
	var pair: Array = sets[new_gate_index%sets.size()]
	new_gate_index += 1
	var gate := GateScript.new()
	gate.position = Vector2(270,190)
	gate.setup(pair[0],pair[1])
	add_child(gate)
	gates.append(gate)

func _tick_gates(delta: float) -> void:
	for i in range(gates.size()-1,-1,-1):
		var g = gates[i]
		var old_y: float = g.position.y
		g.tick(delta)
		if not g.resolved and old_y < player.position.y and g.position.y >= player.position.y:
			var choice: Dictionary = g.choose(player.position.x)
			if not choice.is_empty():
				player.apply_upgrade(choice.id)
				sound.play("gate")
				_popup(player.position-Vector2(0,105),choice.detail,choice.color)
		if g.fade <= 0 or g.position.y > 1000:
			gates.remove_at(i)
			g.queue_free()

func _spawn_barrel() -> void:
	var barrel := BarrelScript.new()
	barrel.position = Vector2(rng.randf_range(195,345),160)
	add_child(barrel)
	barrels.append(barrel)

func _tick_barrels(delta: float) -> void:
	for i in range(barrels.size()-1,-1,-1):
		var barrel = barrels[i]
		if barrel.dead:
			barrels.remove_at(i)
			barrel.queue_free()
			continue
		barrel.tick(delta)
		if barrel.position.y > 930:
			barrels.remove_at(i)
			barrel.queue_free()

func _explode(barrel: Node2D) -> void:
	if barrel.dead and not barrels.has(barrel):
		return
	barrel.dead = true
	sound.play("boom")
	shake = 1.0
	_burst(barrel.position,Color("ff9b45"),18)
	var ring := EffectScript.new()
	ring.position = barrel.position
	ring.ring = true
	ring.size = 145.0
	ring.life = 0.42
	ring.total_life = 0.42
	ring.tint = Color("ffd073")
	add_child(ring)
	effects.append(ring)
	for z in zombies.duplicate():
		if is_instance_valid(z) and z.position.distance_to(barrel.position)<145:
			_hit_zombie(z,95.0)

func _spark(pos: Vector2, color: Color, count: int, force: float) -> void:
	for i in range(count):
		var e := EffectScript.new()
		e.position = pos
		e.velocity = Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(force*0.4,force)
		e.tint = color
		e.size = rng.randf_range(2,4)
		e.life = 0.22
		e.total_life = 0.22
		add_child(e)
		effects.append(e)

func _burst(pos: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		var e := EffectScript.new()
		e.position = pos-Vector2(0,20)
		e.velocity = Vector2(rng.randf_range(-100,100),rng.randf_range(-140,-25))
		e.gravity = 280.0
		e.tint = color
		e.size = rng.randf_range(3,7)
		e.life = rng.randf_range(0.35,0.65)
		e.total_life = e.life
		add_child(e)
		effects.append(e)

func _popup(pos: Vector2, text: String, color: Color) -> void:
	var e := EffectScript.new()
	e.position = pos
	e.text = text
	e.tint = color
	e.velocity = Vector2(0,-42)
	e.life = 0.85
	e.total_life = 0.85
	add_child(e)
	effects.append(e)

func _tick_effects(delta: float) -> void:
	for i in range(effects.size()-1,-1,-1):
		var e = effects[i]
		e.tick(delta)
		if e.life <= 0:
			effects.remove_at(i)
			e.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER,KEY_SPACE] and state in ["menu","gameover"]:
			start_run()
		elif event.keycode in [KEY_ESCAPE,KEY_P]:
			if state == "playing":
				state = "paused"
				dragging = false
			elif state == "paused":
				state = "playing"
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down(event.position)
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging and state == "playing":
		player.target_x = clampf(event.position.x,65,475)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_pointer_down(event.position)
		else:
			dragging = false
	elif event is InputEventScreenDrag and dragging and state == "playing":
		player.target_x = clampf(event.position.x,65,475)

func _pointer_down(pos: Vector2) -> void:
	if Rect2(424,24,42,42).has_point(pos):
		_toggle_mute()
		return
	if state == "menu" and Rect2(66,672,408,72).has_point(pos):
		start_run()
	elif state == "gameover" and Rect2(66,675,408,72).has_point(pos):
		start_run()
	elif state == "playing":
		if Rect2(478,24,42,42).has_point(pos):
			state = "paused"
		else:
			dragging = true
			player.target_x = clampf(pos.x,65,475)
	elif state == "paused":
		if Rect2(66,540,408,68).has_point(pos):
			state = "playing"
		elif Rect2(66,624,408,60).has_point(pos):
			start_run()

func _toggle_mute() -> void:
	sound.muted = not sound.muted
	_save()

func _load_save() -> void:
	var config := ConfigFile.new()
	if config.load("user://dead_run.cfg") == OK:
		best_distance = int(config.get_value("run","best",0))

func _read_muted() -> bool:
	var config := ConfigFile.new()
	if config.load("user://dead_run.cfg") == OK:
		return bool(config.get_value("audio","muted",false))
	return false

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("run","best",best_distance)
	config.set_value("audio","muted",sound.muted if is_instance_valid(sound) else false)
	config.save("user://dead_run.cfg")

func _capture() -> void:
	await get_tree().create_timer(0.12).timeout
	var menu_image := get_viewport().get_texture().get_image()
	menu_image.save_png("res://menu-capture.png")
	start_run()
	for i in range(4):
		_spawn_zombie(245.0+i*70)
	_spawn_gate()
	gates[0].position.y = 405
	await get_tree().create_timer(1.3).timeout
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://capture.png")
	print("CAPTURE_SAVED ",ProjectSettings.globalize_path("res://capture.png"))
	get_tree().quit()

func _smoke_test() -> void:
	start_run()
	assert(state == "playing")
	assert(player.health == 100)
	var old_damage: float = player.damage
	player.apply_upgrade("damage")
	assert(player.damage > old_damage)
	player.target_x = 1000
	await get_tree().create_timer(0.2).timeout
	assert(player.position.x <= 475)
	var before: int = bullets.size()
	_spawn_zombie(500)
	_fire()
	assert(bullets.size() >= before+1)
	_spawn_gate()
	assert(gates.size() == 1)
	var choice: Dictionary = gates[0].choose(100)
	assert(choice.has("id"))
	_spawn_barrel()
	assert(barrels.size() == 1)
	_hurt_player(10)
	assert(player.health == 90)
	print("SMOKE_TEST_OK state=",state," bullets=",bullets.size()," gate=",choice.id," hp=",player.health)
	_clear_world()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

func _soak_test() -> void:
	start_run()
	player.damage = 180.0
	player.fire_interval = 0.07
	player.projectile_count = 3
	for frame in range(2100):
		player.health = 100.0
		player.target_x = 270.0 + sin(frame/95.0)*175.0
		await get_tree().process_frame
	assert(run_time > 30.0)
	assert(wave >= 2)
	assert(kills > 10)
	assert(new_gate_index >= 2)
	print("SOAK_TEST_OK time=",snappedf(run_time,0.1)," wave=",wave," kills=",kills," gates=",new_gate_index," actors=",zombies.size()+bullets.size()+effects.size())
	_clear_world()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
