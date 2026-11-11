extends Node3D
## Weapon crate: a locked supply case in a lane with a hit counter on its face and the
## weapon it holds spinning above it. Shoot it down to 0 and the weapon flies to the player.

const TRUCK_PATH := "res://assets/models/supply_truck.glb"
## When the truck crate mesh cannot be found, the case is an ammo can (the model the game
## already ships) instead of a plain green block.
const AMMO_CAN_PATH := "res://assets/models/ammo_pickup.glb"
## false = the crate sits on the green supply-truck pedestal again; the ammo can used to
## replace that pedestal and the user wants the green base back.
const USE_AMMO_CAN := false
## true = the whole supply truck stands on the road as the pedestal and the crate body
## sits on it, which is how the green boxes used to arrive.
const USE_FULL_TRUCK := false
const CRATE_SCALE := 2.9
## The item floating over a crate/barrel reads too small on a phone: scale it up.
const ITEM_BOOST := 1.75
const CRATE_ITEM_SCALE := 1.5   # helmets keep their size
## Height of the concrete platform the drop stands on (the two platforms the crates
## have always been placed on, left and right of the lane).
const PLATFORM_H := 0.42
const FLIGHT_TIME := 0.55
const WEAPON_SCALES := {"ARMOR":0.6,"HELMET":0.95,"PISTOL":0.62,"SMG":1.43,"SHOTGUN":1.43,"SNIPER":1.43,"LAUNCHER":1.43,"RIFLE":1.43,"SUOMI":1.43,"BIKE":1.55,"SPORT":1.55,"CRUISER":1.55,"FUEL":0.82}
const WEAPON_NAMES := {"ARMOR":"ARMOR: SHIELD +50","HELMET":"HELMET: +20% PROTECTION","PISTOL":"PISTOL","SMG":"SMG","SHOTGUN":"SHOTGUN","SNIPER":"SNIPER","LAUNCHER":"GRENADE LAUNCHER","RIFLE":"RIFLE","FUEL":"FUEL: REFILL","SUOMI":"SUOMI","MAKAROV":"MAKAROV","FLAME":"FLAMETHROWER"}
const GLOW := Color("49b8ff")
const PET_GLOW := Color("ffbf4a")
# Dogs can stand on a platform too ("PET_<index>"); English names for the pop-up.
const PET_NAMES := ["DOBERMAN","GERMAN SHEPHERD","CZECH WOLFDOG","TIBETAN MASTIFF"]
const LobbyScene := preload("res://scripts/lobby_scene_3d.gd")
const ModelFix := preload("res://scripts/model_fix.gd")

static var crate_mesh: Mesh
static var latch_mesh: Mesh

var weapon_id := "SMG"
var hits_left := 10
var max_hits := 10
var half_extents := Vector2(0.72,0.64) # x / z, same convention as road obstacles
var broken := false
var dead := false # aim code treats targets uniformly
var arrived := false
var flight := 0.0
var spin := 0.0
var punch := 0.0
var flight_start := Vector3.ZERO

var body: Node3D
var weapon_pivot: Node3D
var weapon_model: Node3D
var glow_ring: MeshInstance3D
var light: OmniLight3D
var counter: Label3D

static func _cache_meshes() -> void:
	if crate_mesh != null: return
	var truck := (load(TRUCK_PATH) as PackedScene).instantiate()
	var crate := truck.find_child("Crate",true,false) as MeshInstance3D
	var latch := truck.find_child("CrateLatch",true,false) as MeshInstance3D
	if crate: crate_mesh = crate.mesh
	if latch: latch_mesh = latch.mesh
	truck.free()

## AABB of every mesh under `node`, in that node's own space.
static func _bounds_of(node: Node3D) -> AABB:
	var box := AABB(); var first := true
	var inv := node.global_transform.affine_inverse()
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m == null or m.mesh == null: continue
		var b: AABB = (inv * m.global_transform) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func setup(id: String,hits: int) -> void:
	weapon_id = id
	hits_left = maxi(1,hits)
	max_hits = hits_left

func _ready() -> void:
	_cache_meshes()
	body = Node3D.new(); body.name = "Body"; add_child(body)
	var s := CRATE_SCALE # all three bikes are full-size drops in the same crate
	# The case is the game's own ammo can, not the green truck crate (user's call).
	var can_used := false
	if USE_AMMO_CAN and ResourceLoader.exists(AMMO_CAN_PATH):
		var can := (load(AMMO_CAN_PATH) as PackedScene).instantiate() as Node3D
		if can != null:
			body.add_child(can)
			var span := _bounds_of(can)
			var k := 1.26 / maxf(span.size.x, maxf(span.size.y, span.size.z))
			can.scale = Vector3.ONE * k
			can.position = Vector3(-span.get_center().x * k, -span.position.y * k, -span.get_center().z * k)
			can_used = true
			s = 1.0
	if can_used:
		pass
	elif crate_mesh:
		# Exactly the build-3 rig: the green case itself is the platform, at CRATE_SCALE.
		var c := MeshInstance3D.new(); c.mesh = crate_mesh; c.scale = Vector3.ONE*s
		c.position = Vector3(0,0.15*s,0); body.add_child(c)
		if latch_mesh:
			var l := MeshInstance3D.new(); l.mesh = latch_mesh; l.scale = Vector3.ONE*s
			l.position = Vector3(0,0.15*s,0.22*s); body.add_child(l)
	else:
		var can_height := 0.78
	var band := MeshInstance3D.new(); var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(0.48*s+0.02,0.075*s,0.42*s+0.02); band.mesh = band_mesh
	var band_mat := StandardMaterial3D.new(); band_mat.albedo_color = Color("b3241c"); band_mat.roughness = 0.7
	band.material_override = band_mat; band.position = Vector3(0,0.255*s,0); body.add_child(band)
	# Hit counter on the face that looks at the chase camera.
	counter = Label3D.new(); counter.font_size = 150; counter.pixel_size = 0.0054
	counter.outline_size = 26; counter.modulate = Color("fbfbf6"); counter.outline_modulate = Color("1a0d0b")
	counter.position = Vector3(0,0.17*s,0.21*s+0.03); counter.double_sided = false
	var font = load("res://assets/fonts/hud_condensed_bold.otf")
	if font: counter.font = font
	# Always drawn on top so the floating gun can never hide a digit.
	counter.no_depth_test = true; counter.render_priority = 10; counter.outline_render_priority = 9
	body.add_child(counter)
	# Weapon on display above the crate, lit blue like a loot drop.
	weapon_pivot = Node3D.new(); weapon_pivot.position = Vector3(0,1.85,0); add_child(weapon_pivot)
	if weapon_pivot: weapon_pivot.rotation.y = PI*0.5 if weapon_id in ["BIKE","SPORT","CRUISER"] else 0.0
	var path := "res://assets/models/rifle.glb" if weapon_id=="RIFLE" else "res://assets/models/weapons/"+weapon_id.to_lower()+".glb"
	if weapon_id in ["ARMOR","HELMET"]: path = "res://assets/models/"+weapon_id.to_lower()+".glb"
	if weapon_id=="BIKE": path = "res://assets/models/vehicles/bike_paid.glb"
	if weapon_id=="SPORT": path = "res://assets/models/vehicles/bike_paid2.glb"
	if weapon_id=="CRUISER": path = "res://assets/models/vehicles/bike_paid3.glb"
	if is_pet():
		var pi := pet_index()
		weapon_model = (load(LobbyScene.PETS[pi].asset) as PackedScene).instantiate() as Node3D
		weapon_pivot.add_child(weapon_model)
		var lion_fix := 0.8 if String(LobbyScene.PETS[pi].asset).contains("lion") else 1.0
		var lift := ModelFix.fit_pet(weapon_model,float(LobbyScene.PETS[pi].get("length",1.1))*1.3*ITEM_BOOST*lion_fix)
		weapon_model.position.y = lift-0.75
		ModelFix.play_animation(weapon_model,"Dog_Idle")
		path = ""
	if path!="" and not ResourceLoader.exists(path):
		weapon_model = _fallback_marker()
		weapon_pivot.add_child(weapon_model)
		path = ""
	if path!="" and ResourceLoader.exists(path):
		var packed_model:=load(path) as PackedScene
		if packed_model==null:
			push_error("crate: missing model for "+String(weapon_id)+" -> "+path)
			weapon_model = _fallback_marker()
			weapon_pivot.add_child(weapon_model)
			return
		weapon_model = packed_model.instantiate() as Node3D
		var raw_span := _model_span(weapon_model)
		if raw_span > 2.0:
			# authored in centimetres or metres: bring it to ~1 m before the table scale
			weapon_model.scale = Vector3.ONE * (1.0 / raw_span)
		# every drop is half again bigger than before, except the helmet which already reads well
		var boost: float = 1.0 if weapon_id=="HELMET" else CRATE_ITEM_SCALE
		weapon_model.scale *= Vector3.ONE*(float(WEAPON_SCALES.get(weapon_id,0.6))*boost)
		if weapon_id!="HELMET":
			# a small prop (a vest, a can) otherwise reads as an empty barrel from a few metres away
			var shown := _model_span(weapon_model) * weapon_model.scale.x
			if shown > 0.01 and shown < 0.85:
				weapon_model.scale *= 0.85 / shown
		# Bike/Car models are already upright; no X tilt (that laid them on their side).
		weapon_pivot.add_child(weapon_model)
		_center_model(weapon_model)
		# The cruiser ships in its own units, which left it about five centimetres wide on the
		# platform: normalise every vehicle drop to a readable size.
		if weapon_id in ["BIKE", "SPORT", "CRUISER", "SEDAN", "CAR"]:
			var real := _world_span(weapon_model)
			if real > 0.001:
				weapon_model.scale *= 1.25 / real
	glow_ring = MeshInstance3D.new(); var torus := TorusMesh.new()
	torus.inner_radius = 0.56; torus.outer_radius = 0.68; torus.rings = 32; torus.ring_segments = 8; glow_ring.mesh = torus
	var glow_mat := StandardMaterial3D.new(); glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var g := PET_GLOW if is_pet() else GLOW
	glow_mat.albedo_color = Color(g.r,g.g,g.b,0.75); glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_ring.material_override = glow_mat; glow_ring.position = Vector3(0,-0.42,0); weapon_pivot.add_child(glow_ring)
	light = OmniLight3D.new(); light.light_color = PET_GLOW if is_pet() else GLOW; light.light_energy = 1.6; light.omni_range = 2.6
	light.position = Vector3(0,0.1,0.35); weapon_pivot.add_child(light)
	_refresh_counter()

## Largest axis of a model as it would appear in the world, scale included.
func _world_span(node: Node3D) -> float:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m == null or m.mesh == null:
			continue
		var a: AABB = m.global_transform * m.get_aabb()
		box = a if first else box.merge(a)
		first = false
	if first:
		return 0.0
	return maxf(box.size.x, maxf(box.size.y, box.size.z))

## Largest axis of a freshly instantiated model, before any scaling.
## Something visible for a drop whose model is missing: a small glowing diamond.
func _fallback_marker() -> Node3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.45, 0.85, 1.0, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	mi.mesh = mesh
	return mi


func _model_span(node: Node3D) -> float:
	var box := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var a: AABB = mi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	if first:
		return 0.0
	return maxf(box.size.x, maxf(box.size.y, box.size.z))


func _center_model(m: Node3D) -> void:
	# Weapon glbs are authored around the grip; shift so the spin axis runs through the middle.
	var box := AABB(); var first := true
	for mi in m.find_children("*","MeshInstance3D",true,false):
		var local: Transform3D = m.transform.affine_inverse()*_relative(mi as Node3D,m.get_parent())
		var b: AABB = local*(mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b); first = false
	if not first: m.position = -(m.transform.basis*box.get_center())

func _relative(n: Node3D,ancestor: Node) -> Transform3D:
	var t := Transform3D.IDENTITY; var cur: Node = n
	while cur != null and cur != ancestor:
		if cur is Node3D: t = (cur as Node3D).transform*t
		cur = cur.get_parent()
	return t


## Pool support. A crate builds its body and its floating item in _ready(), which measured ~66 ms
## per instance, so crates are parked per weapon id and reused with the same id only.
func park() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	broken = true
	dead = true
	arrived = false

func reuse(id: String, hits: int) -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	weapon_id = id
	hits_left = maxi(1, hits)
	max_hits = hits_left
	broken = false
	dead = false
	arrived = false
	flight = 0.0
	punch = 0.0
	spin = 0.0
	if body != null:
		body.visible = true
		body.scale = Vector3.ONE
	if weapon_pivot != null:
		weapon_pivot.top_level = false
		weapon_pivot.scale = Vector3.ONE
		weapon_pivot.rotation = Vector3.ZERO
		weapon_pivot.position = Vector3(0.0, 1.85, 0.0)
	if light != null:
		light.light_energy = 1.4
	_refresh_counter()

func _refresh_counter() -> void:
	if counter: counter.text = str(hits_left)

func overlaps(point: Vector3) -> bool:
	return not broken and absf(point.x-position.x)<half_extents.x+0.40 and absf(point.z-position.z)<half_extents.y+0.25

func bullet_hits(point: Vector3) -> bool:
	return not broken and point.y<2.4 and absf(point.x-position.x)<half_extents.x+0.22 and absf(point.z-position.z)<half_extents.y+0.22

## Returns true on the hit that breaks the crate.
func take_hit(amount: int=1) -> bool:
	if broken: return false
	hits_left = maxi(0,hits_left-maxi(1,amount))
	punch = 1.0
	_refresh_counter()
	if hits_left<=0:
		broken = true; dead = true
		body.visible = false
		flight_start = weapon_pivot.global_position
		weapon_pivot.top_level = true
		weapon_pivot.global_position = flight_start
		return true
	return false

func tick(delta: float,player_target: Vector3) -> void:
	spin += delta
	if not broken:
		position.z += 3.5*delta
		punch = maxf(0.0,punch-delta*7.0)
		body.scale = Vector3.ONE*(1.0+0.08*punch)
		counter.modulate = Color("fbfbf6").lerp(Color("ff4a3a"),punch)
		weapon_pivot.position.y = 1.85+sin(spin*2.6)*0.07
		if weapon_pivot: weapon_pivot.rotation.y = spin*1.9+(PI*0.5 if weapon_id in ["BIKE","SPORT","CRUISER"] else 0.0) if not is_pet() else spin*0.6
		if glow_ring: glow_ring.rotation.x = 0.0
		if light: light.light_energy = 1.4+0.4*sin(spin*5.0)
		return
	# Broken: the weapon arcs into the player's hands, but the wreck itself still rides the
	# scrolling road - freezing it made the road slide past and read as rolling backwards.
	position.z += 3.5*delta
	flight += delta
	var t := clampf(flight/FLIGHT_TIME,0.0,1.0)
	var e := t*t*(3.0-2.0*t)
	var peak := flight_start.lerp(player_target,0.5)+Vector3(0,1.6,0)
	var a := flight_start.lerp(peak,e); var b := peak.lerp(player_target,e)
	weapon_pivot.global_position = a.lerp(b,e)
	if weapon_pivot: weapon_pivot.rotation.y = spin*9.0
	weapon_pivot.scale = Vector3.ONE*lerpf(1.0,0.55,e)
	if light: light.light_energy = 2.4*(1.0-e)+0.4
	if t>=1.0: arrived = true

func is_pet() -> bool:
	return weapon_id.begins_with("PET_")

func pet_index() -> int:
	return clampi(int(weapon_id.trim_prefix("PET_")),0,LobbyScene.PETS.size()-1)

func display_name() -> String:
	var RT=load("res://scripts/run_text.gd")
	if is_pet(): return RT.text("dog_%d"%pet_index())
	if weapon_id=="BIKE": return RT.text("l_bike")
	if weapon_id=="SPORT" or weapon_id=="CRUISER":
		var SC=load("res://scripts/store_catalog.gd")
		return SC.text(RT.lang,"sport" if weapon_id=="SPORT" else "cruiser")
	if weapon_id=="ARMOR": return RT.fmt("shield",50)
	if weapon_id=="HELMET": return RT.text("helmet")
	var ST=load("res://scripts/shop_text.gd")
	return ST.text(RT.lang,"n_"+weapon_id.to_lower())
