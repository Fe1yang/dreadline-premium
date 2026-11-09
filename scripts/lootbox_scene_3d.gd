extends Node3D
const ModelFix := preload("res://scripts/model_fix.gd")
## Animated field-issue case on a stocked armourer’s workbench. The GLB keeps the lid
## and latches on separate pivots; rewards are real models already used by the game.

var case_model: Node3D
var lid: Node3D
var lock_core: Node3D
var reward: Node3D
var elapsed:=0.0
var opening:=false
var revealed:=false
var time:=0.0
var glow: OmniLight3D
var sparks: Array[MeshInstance3D]=[]

func _ready() -> void:
	_build_environment()
	# Reuse the finished DF-07 model from the earlier armoury preview.
	case_model=ModelFix.spawn("res://assets/models/props/supply_case.glb")
	if case_model==null: return
	case_model.scale=Vector3.ONE*1.55; case_model.position=Vector3(0,0.62,0); add_child(case_model)
	lid=case_model.find_child("CrateLid",true,false) as Node3D
	lock_core=case_model.find_child("CrateCore",true,false) as Node3D
	reward=Node3D.new(); reward.position=Vector3(0,0.66,0); add_child(reward)
	glow=OmniLight3D.new(); glow.light_color=Color("ffc46c"); glow.light_energy=0.0; glow.omni_range=2.8
	glow.position=Vector3(0,1.0,.25); add_child(glow)
	_make_sparks()

func _mat(color: Color,rough:=.75,metal:=0.0) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new(); m.resource_name="Case table · "+color.to_html(); m.albedo_color=color; m.roughness=rough; m.metallic=metal
	return m

func _box(size: Vector3,pos: Vector3,mat: Material,parent: Node=null) -> MeshInstance3D:
	var mi:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=size; mi.mesh=mesh; mi.material_override=mat; mi.position=pos; (parent if parent else self).add_child(mi); return mi

func _cylinder(radius: float,height: float,pos: Vector3,mat: Material) -> MeshInstance3D:
	var mi:=MeshInstance3D.new(); var mesh:=CylinderMesh.new(); mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=height; mesh.radial_segments=24
	mi.mesh=mesh; mi.material_override=mat; mi.position=pos; add_child(mi); return mi

func _build_environment() -> void:
	var we:=WorldEnvironment.new(); var env:=Environment.new(); env.background_mode=Environment.BG_COLOR; env.background_color=Color("131c20")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("a7b9c5"); env.ambient_light_energy=.48
	env.tonemap_mode=Environment.TONE_MAPPER_ACES; env.tonemap_exposure=.9; we.environment=env; add_child(we)
	var wood:=_mat(Color("35332d"),.83); var steel:=_mat(Color("303b3d"),.42,.7); var wall:=_mat(Color("283235"),.95)
	_box(Vector3(7.5,.16,4.4),Vector3(0,.34,0),wood)
	for x in [-3.35,3.35]:
		for z in [-1.8,1.8]: _box(Vector3(.14,.9,.14),Vector3(x,-.15,z),steel)
	_box(Vector3(11,6,.18),Vector3(0,2.4,-4),wall)
	_box(Vector3(12,.15,10),Vector3(0,-.66,0),wall)
	# Rear pegboard rails, a spare ammunition tin and hand tools make this a used workspace.
	for y in [1.25,2.05,2.85]: _box(Vector3(6,.045,.09),Vector3(0,y,-3.87),steel)
	var tin:=_box(Vector3(1.0,.58,.67),Vector3(-2.2,.72,-.45),_mat(Color("424b38"),.66,.35))
	for x in [-2.54,-1.86]: _box(Vector3(.06,.60,.69),Vector3(x,.73,-.45),steel)
	for i in range(4):
		var cartridge:=_cylinder(.045,.40,Vector3(1.75+i*.17,.62,-.5),_mat(Color("aa8146"),.32,.75)); cartridge.rotation.x=PI/2
	_box(Vector3(1.0,.045,.68),Vector3(1.9,.445,-.45),_mat(Color("242b29"),.92))
	var tool:=_box(Vector3(.07,.055,.85),Vector3(1.8,.47,.55),steel); tool.rotation.y=.42
	var grip:=_box(Vector3(.13,.075,.30),Vector3(1.63,.48,.91),_mat(Color("813a27"),.74)); grip.rotation.y=.42
	var key:=SpotLight3D.new(); key.position=Vector3(-2.2,4.2,2.8); key.light_color=Color("ffe3bc"); key.light_energy=3.0; key.spot_range=9; key.spot_angle=48; key.shadow_enabled=true; add_child(key); key.look_at(Vector3(0,.65,0))
	var fill:=OmniLight3D.new(); fill.position=Vector3(2.4,2.4,1.2); fill.light_color=Color("b9d9e5"); fill.light_energy=1.15; fill.omni_range=6; add_child(fill)
	var rim:=OmniLight3D.new(); rim.position=Vector3(0,2.6,-2.0); rim.light_color=Color("e6b35e"); rim.light_energy=1.4; rim.omni_range=4; add_child(rim)

func _make_sparks() -> void:
	var mat:=_mat(Color("ffce74"),.35,.1); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(20):
		var spark:=MeshInstance3D.new(); var mesh:=SphereMesh.new(); mesh.radius=.012; mesh.height=.024; mesh.radial_segments=6; mesh.rings=3
		spark.mesh=mesh; spark.material_override=mat; spark.visible=false; add_child(spark); sparks.append(spark)

func reset_case() -> void:
	elapsed=0; opening=false; revealed=false
	if lid: lid.rotation.x=0
	if lock_core: lock_core.rotation=Vector3.ZERO
	if reward!=null and is_instance_valid(reward):
		for child in reward.get_children(): child.queue_free()
	glow.light_energy=0
	for spark in sparks: spark.visible=false

func open_case(reward_id: String) -> void:
	reset_case(); opening=true
	var path: String="res://assets/models/armor.glb" if reward_id=="medical" else "res://assets/models/ammo_pickup.glb"
	if reward_id.begins_with("w_"):
		var id:=reward_id.trim_prefix("w_").to_upper(); path="res://assets/models/rifle.glb" if id=="RIFLE" else "res://assets/models/weapons/"+id.to_lower()+".glb"
	if reward_id.begins_with("pet_"):
		# a dog won from the case: owned for good
		var pets: Array=(load("res://scripts/lobby_scene_3d.gd") as GDScript).PETS
		var pi:=clampi(int(reward_id.trim_prefix("pet_")),0,pets.size()-1)
		var dog: Node3D=(load(pets[pi].asset) as PackedScene).instantiate() as Node3D
		reward.add_child(dog)
		var mf:=load("res://scripts/model_fix.gd")
		dog.position.y=mf.fit_pet(dog,0.9)-0.35; mf.play_animation(dog,"Dog_Idle"); return
	if reward_id.begins_with("char_"):
		# a paid survivor won from the case: owned for good, shown standing in the box
		var chars: Array=(load("res://scripts/lobby_scene_3d.gd") as GDScript).CHARACTERS
		var ci:=clampi(int(reward_id.trim_prefix("char_")),0,chars.size()-1)
		var actor: Node3D=(load(chars[ci].asset) as PackedScene).instantiate() as Node3D
		reward.add_child(actor)
		actor.position.y=-0.35; actor.scale=Vector3.ONE*0.62
	if ResourceLoader.exists(path):
		var model: Node3D=(load(path) as PackedScene).instantiate() as Node3D
		model.scale=Vector3.ONE*(1.35 if reward_id.begins_with("w_") else 1.1); reward.add_child(model)

func _process(delta: float) -> void:
	if not visible: return
	time+=delta
	if opening:
		elapsed+=delta
		var charge:=smoothstep(.18,.70,elapsed)
		if lock_core: lock_core.rotation.z=sin(elapsed*28)*.08*charge if elapsed<.85 else 0
		var lid_t:=smoothstep(.72,1.75,elapsed)
		if lid: lid.rotation.x=-deg_to_rad(78)*lid_t
		var rise:=smoothstep(1.15,2.05,elapsed)
		reward.position.y=.66+rise*1.05; reward.scale=Vector3.ONE*maxf(.001,rise)
		glow.light_energy=sin(clampf(elapsed/2.2,0,1)*PI)*2.0+rise*.65
		for i in range(sparks.size()):
			var phase:=fposmod(elapsed*.52+i*.071,1.0); var angle:=i*2.39996
			sparks[i].visible=elapsed>.85 and elapsed<2.65
			sparks[i].position=Vector3(cos(angle)*(.35+phase*.65),.65+phase*1.4,sin(angle)*(.28+phase*.5))
			sparks[i].scale=Vector3.ONE*(1.0-phase)
		if elapsed>=2.25: opening=false; revealed=true
	elif revealed:
		reward.rotation.y=sin(time*.65)*.28
		reward.position.y=1.71+sin(time*1.7)*.035

func camera_position() -> Vector3:
	return Vector3(2.7,2.6,5.0)
func camera_target() -> Vector3:
	return Vector3(0,1.0,0)
func camera_fov() -> float:
	return 39.0
