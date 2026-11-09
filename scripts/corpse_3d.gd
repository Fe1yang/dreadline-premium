extends Node3D
const ModelFix := preload("res://scripts/model_fix.gd")
## Motionless corpses use the final frame of the authored Death01 clip, not a rotated walk pose.
## The same component serves isolated pavement bodies and physical road-blocking piles.

var seed_value: int=0
var body_count: int=1
var bodies: Array[Node3D]=[]
var _rng:=RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed=seed_value
	for i in range(body_count):
		_add_body(i)
	_make_blood()

const BloodPoolC := preload("res://scripts/blood_pool_3d.gd")

func _make_blood() -> void:
	# Same wet pool look as kill blood, not flat paint.
	for i in range(2 if body_count>1 else 1):
		var pool: Node3D = BloodPoolC.new()
		add_child(pool)
		pool.setup(1.4 if body_count>1 else 0.9,_rng.randi(),9999.0,true)
		pool.position=Vector3(0,0.014,0)
		pool.scale=Vector3.ONE*(1.4 if body_count>1 else 0.9)
		pool.rotation.y=_rng.randf_range(0,TAU)
	var extra: Node3D = BloodPoolC.new()
	add_child(extra)
	extra.setup(_rng.randf_range(0.35,0.6),_rng.randi(),9999.0,false)
	extra.position=Vector3(_rng.randf_range(-0.6,0.6),0.016,_rng.randf_range(-0.6,0.6))
	extra.scale=Vector3.ONE*0.5
	extra.rotation.y=_rng.randf_range(0,TAU)

func _add_blood_pool(st: SurfaceTool,center: Vector3,rx: float,rz: float,points: int) -> void:
	var ring: Array[Vector3]=[]
	for i in range(points):
		var angle: float=TAU*i/points
		var radius: float=_rng.randf_range(0.72,1.13)
		ring.append(center+Vector3(cos(angle)*rx*radius,0,sin(angle)*rz*radius))
	for i in range(points):
		st.set_normal(Vector3.UP); st.add_vertex(center)
		st.set_normal(Vector3.UP); st.add_vertex(ring[(i+1)%points])
		st.set_normal(Vector3.UP); st.add_vertex(ring[i])

func _add_body(index: int) -> void:
	var female: bool=_rng.randf()<0.42
	var path: String="res://assets/models/actors/zombie_female_universal.glb" if female else "res://assets/models/actors/zombie_walker_universal.glb"
	var body:=Node3D.new()
	body.name="Corpse_%d"%index
	add_child(body)
	var model: Node3D=ModelFix.spawn(path)
	if model==null: return
	body.add_child(model)
	var anim:=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if anim and anim.has_animation("Death01"):
		var clip:=anim.get_animation("Death01")
		anim.play("Death01")
		anim.seek(maxf(0.0,clip.length-0.002),true)
		anim.pause()
	else:
		push_error("Corpse death pose missing: "+path)
	var yaw: float=_rng.randf_range(0.0,TAU)
	var offset:=Vector3.ZERO
	if body_count>1:
		# Offset and alternate the bodies so the pile reads as limbs and torsos, not cloned stacks.
		var pile_offsets: Array=[Vector3(-0.34,0.0,0.12),Vector3(0.36,0.10,-0.16),Vector3(0.02,0.22,0.18),Vector3(0.16,0.30,-0.28)]
		offset=pile_offsets[index%pile_offsets.size()]
		yaw=(index%2)*PI+_rng.randf_range(-0.75,0.75)+index*0.38
	body.position=offset
	body.rotation.y=yaw
	body.rotation.z=_rng.randf_range(-0.035,0.035)
	bodies.append(body)
