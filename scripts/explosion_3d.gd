extends Node3D

# Custom synchronized explosion: no prebuilt VFX scene or delayed emitter.
var life:=1.45
var total_life:=1.45
var radius_scale:=1.0
var age:=0.0
var label: Label3D
var core: MeshInstance3D
var core_material: StandardMaterial3D
var ring: MeshInstance3D
var ring_material: StandardMaterial3D
var flash_light: OmniLight3D
var fireballs: Array[Dictionary]=[]
var smoke_puffs: Array[Dictionary]=[]
var random:=RandomNumberGenerator.new()

func _ready() -> void:
	random.randomize()
	_build_core()
	_build_fire()
	_build_smoke()
	_build_ring()
	flash_light=OmniLight3D.new()
	flash_light.light_color=Color("ff9b45")
	flash_light.light_energy=4.2
	flash_light.omni_range=7.5*radius_scale
	flash_light.shadow_enabled=false
	add_child(flash_light)

func _material(color: Color,emission: float,unshaded: bool=false) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness=0.92
	if unshaded: material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission>0.0:
		material.emission_enabled=true
		material.emission=Color(color.r,color.g,color.b,1.0)
		material.emission_energy_multiplier=emission
	return material

func _sphere(radius: float,segments: int,rings: int) -> SphereMesh:
	var mesh:=SphereMesh.new()
	mesh.radius=radius*radius_scale
	mesh.height=radius*2.0*radius_scale
	mesh.radial_segments=segments
	mesh.rings=rings
	return mesh

func _build_core() -> void:
	core=MeshInstance3D.new()
	core.mesh=_sphere(0.58,32,16)
	core_material=_material(Color(1.0,0.83,0.38,0.96),3.2,true)
	core.material_override=core_material
	add_child(core)

func _build_fire() -> void:
	for i in range(8):
		var node:=MeshInstance3D.new()
		var base_radius:=random.randf_range(0.34,0.58)
		node.mesh=_sphere(base_radius,24,12)
		var color:=Color(1.0,random.randf_range(0.20,0.46),0.025,0.88)
		if i<2: color=Color(1.0,0.72,0.16,0.94)
		var material:=_material(color,1.8,true)
		node.material_override=material
		var start:=Vector3(random.randf_range(-0.30,0.30),random.randf_range(-0.18,0.30),random.randf_range(-0.30,0.30))*radius_scale
		var drift:=Vector3(random.randf_range(-0.70,0.70),random.randf_range(0.30,0.95),random.randf_range(-0.70,0.70))*radius_scale
		node.position=start
		add_child(node)
		fireballs.append({"node":node,"material":material,"start":start,"drift":drift})

func _build_smoke() -> void:
	for i in range(11):
		var node:=MeshInstance3D.new()
		node.mesh=_sphere(random.randf_range(0.34,0.62),20,10)
		var shade:=random.randf_range(0.085,0.17)
		var material:=_material(Color(shade,shade*1.04,shade*1.02,0.0),0.0)
		node.material_override=material
		var start:=Vector3(random.randf_range(-0.48,0.48),random.randf_range(0.0,0.58),random.randf_range(-0.48,0.48))*radius_scale
		var drift:=Vector3(random.randf_range(-0.38,0.38),random.randf_range(0.50,1.15),random.randf_range(-0.38,0.38))*radius_scale
		node.position=start
		add_child(node)
		smoke_puffs.append({"node":node,"material":material,"start":start,"drift":drift,"phase":random.randf_range(0.75,1.2)})

func _build_ring() -> void:
	ring=MeshInstance3D.new()
	var mesh:=TorusMesh.new()
	mesh.inner_radius=0.88*radius_scale
	mesh.outer_radius=1.0*radius_scale
	mesh.rings=64
	mesh.ring_segments=10
	ring.mesh=mesh
	ring.position.y=-0.42*radius_scale
	ring_material=_material(Color(1.0,0.53,0.16,0.65),1.2,true)
	ring.material_override=ring_material
	add_child(ring)

func tick(delta: float) -> void:
	life-=delta
	age+=delta
	var core_t:=clampf(age/0.20,0.0,1.0)
	core.scale=Vector3.ONE*(0.65+core_t*2.3)
	core_material.albedo_color.a=(1.0-core_t)*0.96
	flash_light.light_energy=4.2*(1.0-clampf(age/0.34,0.0,1.0))
	var ring_t:=clampf(age/0.46,0.0,1.0)
	ring.scale=Vector3.ONE*(0.22+ring_t*4.4)
	ring_material.albedo_color.a=(1.0-ring_t)*0.65
	for item in fireballs:
		var node: MeshInstance3D=item.node
		var material: StandardMaterial3D=item.material
		node.position=item.start+item.drift*age
		node.scale=Vector3.ONE*(0.72+age*2.0)
		material.albedo_color.a=pow(1.0-clampf(age/0.66,0.0,1.0),1.35)*0.88
	for item in smoke_puffs:
		var node: MeshInstance3D=item.node
		var material: StandardMaterial3D=item.material
		node.position=item.start+item.drift*age
		node.scale=Vector3.ONE*(0.65+age*1.65*float(item.phase))
		material.albedo_color.a=clampf(age/0.08,0.0,1.0)*(1.0-clampf(age/total_life,0.0,1.0))*0.48
