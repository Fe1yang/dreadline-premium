extends "res://scripts/weapon_crate_3d.gd"
## A barrel that rolls down the road with a pet / weapon / vehicle turning slowly above it.
##
## It behaves like the supply platform (same hit counter, same "shoot it down and the
## reward flies into your hands"), with three differences:
##   * the body is a real barrel, lying on its side and rolling,
##   * it rolls along the road toward the survivor instead of standing still,
##   * it hurts on contact, like a wreck or a crater.
## The counter and the item above it are NOT part of the rolling body, so they stay
## upright no matter how fast the barrel turns.
##
## The road is 6.3 m wide and the barrel is 0.9 m, so three of them in the three lanes
## still leave ~1.5 m between each pair: never a wall, always a gap.

const MODEL_PATH := "res://assets/models/props/barrel_roll.glb"
const TARGET_DIAMETER := 0.96     # metres: a 200 litre drum, big enough to read at speed
const EXTRA_SPEED := 1.0          # m/s on top of the 3.5 m/s the road already moves
## The barrel used to turn once per 0.7 s, which strobes on a phone. Travel speed
## is unchanged; the visible roll is slowed so the wood grain stays readable.
const ROLL_SPIN_SCALE := 0.4
const ITEM_HEIGHT := 1.42
const CONTACT_DAMAGE := 20.0
const CONTACT_COOLDOWN := 1.2

var barrel_spin: Node3D
var roll_axis: Node3D
var roll_radius := 0.4
var hit_cooldown := 0.0
var contact_damage := CONTACT_DAMAGE

func is_roller() -> bool:
	return true

func _ready() -> void:
	super._ready()
	# the crate look goes away, the counter and the floating item stay
	for child in body.get_children():
		if child is MeshInstance3D:
			child.visible = false
			if child == counter:
				child.visible = true
	counter.font_size = 96; counter.pixel_size = 0.0045; counter.outline_size = 18
	counter.position = Vector3(0, 0.46, 0.52)
	weapon_pivot.position.y = ITEM_HEIGHT
	_build_barrel()

func _build_barrel() -> void:
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		push_error("barrel_roll: missing model " + MODEL_PATH)
		return
	roll_axis = Node3D.new()
	roll_axis.rotation.z = -PI * 0.5          # lay the barrel on its side: axis along X
	add_child(roll_axis)
	barrel_spin = Node3D.new()
	roll_axis.add_child(barrel_spin)
	# The glb keeps its own node transform (the generator writes centimetres and hangs a
	# scale on the root), so the fit lives in its own parent and the model is left alone.
	var fit := Node3D.new()
	barrel_spin.add_child(fit)
	var model := packed.instantiate() as Node3D
	fit.add_child(model)
	# The generated wood carries a hard specular that reads as plastic in the sun:
	# flatten it so the barrel looks like timber.
	for _mi in model.find_children("*","MeshInstance3D",true,false):
		var _m:=_mi as MeshInstance3D
		if _m==null or _m.mesh==null: continue
		for _s in range(_m.mesh.get_surface_count()):
			var _mat: Material=_m.mesh.surface_get_material(_s)
			if _mat is BaseMaterial3D:
				var _b:=_mat as BaseMaterial3D
				_b.metallic=0.0; _b.roughness=0.95
				_b.specular_mode=BaseMaterial3D.SPECULAR_DISABLED
	# Measure what is really drawn, then correct the scale once: node scales in these
	# generated glbs are not what the accessor bounds suggest.
	var w := _drawn_diameter()
	if w <= 0.0:
		push_error("barrel_roll: model has no geometry")
		return
	fit.scale = Vector3.ONE * (TARGET_DIAMETER / w)
	# centre it on the spin axis and drop it onto the road
	var box := _local_box(fit)
	var s: float = fit.scale.x
	fit.position = Vector3(-box.get_center().x * s, -box.get_center().y * s, -box.get_center().z * s)
	roll_radius = TARGET_DIAMETER * 0.5
	roll_axis.position.y = roll_radius
	# a soft contact shadow so it reads as touching the road
	var shadow := MeshInstance3D.new(); var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 1.5); shadow.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = mat
	shadow.rotation.x = -PI * 0.5
	shadow.position.y = 0.02
	add_child(shadow)

## Bounding box of the barrel meshes in the model's own space.
func _local_box(root: Node3D) -> AABB:
	var box := AABB(); var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D(); var n: Node = mi
		while n != null and n != root:
			if n is Node3D: xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b: AABB = xf * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## Diameter of the barrel as it is actually drawn (Y/Z spread after the lay-down).
func _drawn_diameter() -> float:
	var box := AABB(); var first := true
	for mi in barrel_spin.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first: return 0.0
	return maxf(box.size.y, box.size.z)
func _roll(distance: float) -> void:
	if barrel_spin == null:
		return
	barrel_spin.rotation.y += distance * ROLL_SPIN_SCALE / maxf(0.05, roll_radius)

func tick(delta: float, player_target: Vector3) -> void:
	if broken:
		# The base class moves the wreck with the road; keep the tu mble going too.
		_roll(3.5*delta)
		super.tick(delta, player_target)   # the reward keeps flying to the survivor
		return
	spin += delta
	punch = maxf(0.0, punch - delta * 7.0)
	counter.modulate = Color("fbfbf6").lerp(Color("ff4a3a"), punch)
	var travel := (3.5 + EXTRA_SPEED) * delta
	position.z += travel
	_roll(travel)
	weapon_pivot.position.y = ITEM_HEIGHT + sin(spin * 2.4) * 0.07
	weapon_pivot.rotation.y = spin * (0.7 if is_pet() else 1.7)
	if glow_ring:
		glow_ring.rotation.x = 0.0
	if light:
		light.light_energy = 1.4 + 0.4 * sin(spin * 5.0)

func contact_tick(delta: float) -> void:
	hit_cooldown = maxf(0.0, hit_cooldown - delta)

## The survivor is inside the barrel's footprint (used for the contact damage).
func touches(point: Vector3) -> bool:
	return not broken and absf(point.x - position.x) < 0.58 and absf(point.z - position.z) < 0.66
