extends Node3D

const EnvironmentMaterials=preload("res://scripts/environment_materials.gd")
var kind:="car"
var half_extents:=Vector2(1.02,2.08)
var damage:=22.0
var hit_cooldown:=0.0
var model: Node3D
var paint:=Color("71332f")
var rust_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var metal_material: StandardMaterial3D
var rubber_material: StandardMaterial3D
var glass_material: StandardMaterial3D
var random:=RandomNumberGenerator.new()
var police_phase:=0.0
var police_crosswise:=false
var police_red: OmniLight3D
var police_blue: OmniLight3D
var police_red_material: StandardMaterial3D
var police_blue_material: StandardMaterial3D

func _ready() -> void:
	random.randomize()
	_make_materials()
	model=Node3D.new()
	add_child(model)
	if kind=="fence":
		half_extents=Vector2(1.15,0.34)
		damage=12.0
		_make_fence()
	elif kind=="cone":
		# a pothole marker: small, so it never blocks a lane on its own
		half_extents=Vector2(0.22,0.22)
		damage=8.0
		var cone_packed: Resource=load("res://assets/models/props/traffic_cone.glb")
		if cone_packed!=null:
			var cone:=cone_packed.instantiate() as Node3D
			if cone!=null:
				cone.position=Vector3(0,0,0)
				# the generated cone GLB arrives with shadow casting off
				for mi in cone.find_children("*", "MeshInstance3D", true, false):
					var cm := mi as MeshInstance3D
					if cm != null:
						cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				model.add_child(cone)
		# the hole itself: a dark disc so the cones read as a warning, not random clutter
		var disc:=MeshInstance3D.new()
		var cyl:=CylinderMesh.new(); cyl.top_radius=0.55; cyl.bottom_radius=0.55; cyl.height=0.02
		var dm:=StandardMaterial3D.new(); dm.albedo_color=Color(0.05,0.05,0.055); dm.roughness=0.95
		cyl.material=dm; disc.mesh=cyl; disc.position=Vector3(0,0.012,0)
		model.add_child(disc)
	elif kind=="police":
		half_extents=Vector2(2.42,1.08) if police_crosswise else Vector2(1.08,2.42)
		damage=24.0
		var packed: Resource=load("res://assets/models/props/police_car.glb")
		var police: Node3D=null
		if packed!=null: police=packed.instantiate() as Node3D
		if police==null:
			# A missing prop model must never take the whole run down with it.
			push_warning("police_car.glb unavailable -- drawing an ordinary wreck instead")
			_make_car()
		else:
			model.add_child(police)
			EnvironmentMaterials.apply(police)
			_setup_police_lights(police)
		model.rotation.y=(PI*0.5 if police_crosswise else 0.0)+random.randf_range(-0.06,0.06)
	elif kind=="corpse_pile":
		half_extents=Vector2(0.92,1.16)
		damage=9.0
		_make_corpse_pile()
	else:
		half_extents=Vector2(1.02,2.08)
		damage=22.0
		paint=[Color("71332f"),Color("344b56"),Color("555b4b"),Color("6b6252")][random.randi_range(0,3)]
		_make_car()

func _make_corpse_pile() -> void:
	var corpses:=load("res://scripts/corpse_3d.gd").new() as Node3D
	corpses.seed_value=random.randi()
	corpses.body_count=3
	model.add_child(corpses)
	model.rotation.y=random.randf_range(-0.35,0.35)

func _setup_police_lights(police: Node3D) -> void:
	for node in police.find_children("*","MeshInstance3D",true,false):
		var mesh_node:=node as MeshInstance3D
		for surface in range(mesh_node.mesh.get_surface_count()):
			var source:=mesh_node.get_active_material(surface) as StandardMaterial3D
			if source==null: continue
			var key:=source.resource_name.split(".",true,1)[0]
			if key not in ["light_red","light_blue"]: continue
			var flashing:=source.duplicate() as StandardMaterial3D
			flashing.emission_enabled=true
			flashing.emission=Color("ff2d25") if key=="light_red" else Color("2588ff")
			flashing.emission_energy_multiplier=2.0
			mesh_node.set_surface_override_material(surface,flashing)
			if key=="light_red": police_red_material=flashing
			else: police_blue_material=flashing
	police_red=OmniLight3D.new(); police_red.name="Alternating red emergency light"
	police_red.position=Vector3(-0.43,1.94,0.15); police_red.light_color=Color("ff3028")
	police_red.omni_range=4.8; police_red.omni_attenuation=1.3; police_red.shadow_enabled=false
	model.add_child(police_red)
	police_blue=OmniLight3D.new(); police_blue.name="Alternating blue emergency light"
	police_blue.position=Vector3(0.43,1.94,0.15); police_blue.light_color=Color("2788ff")
	police_blue.omni_range=4.8; police_blue.omni_attenuation=1.3; police_blue.shadow_enabled=false
	model.add_child(police_blue)
	_tick_police_lights(0.0)

func _tick_police_lights(delta: float) -> void:
	if kind!="police" or not is_instance_valid(police_red): return
	police_phase=fmod(police_phase+delta*9.0,TAU)
	var red_on: bool=sin(police_phase)>0.0
	police_red.light_energy=3.0 if red_on else 0.08
	police_blue.light_energy=0.08 if red_on else 3.0
	if police_red_material: police_red_material.emission_energy_multiplier=3.4 if red_on else 0.22
	if police_blue_material: police_blue_material.emission_energy_multiplier=0.22 if red_on else 3.4

func _make_materials() -> void:
	rust_material=_material(Color("633a28"),0.92,0.18)
	dark_material=_material(Color("171b1c"),0.72,0.38)
	metal_material=_material(Color("8b9290"),0.34,0.72)
	rubber_material=_material(Color("111313"),0.96,0.0)
	glass_material=_material(Color(0.12,0.23,0.26,0.64),0.16,0.30)
	glass_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA

func _material(color: Color,roughness: float,metallic: float) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=roughness
	material.metallic=metallic
	return material

func _rounded_box(size: Vector3,bevel: float=0.06,steps: int=4) -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half:=size*0.5
	var inner:=Vector3(maxf(0.01,half.x-bevel),maxf(0.01,half.y-bevel),maxf(0.01,half.z-bevel))
	var faces:=[
		[Vector3(0,0,1),Vector3(1,0,0),Vector3(0,1,0)],
		[Vector3(0,0,-1),Vector3(-1,0,0),Vector3(0,1,0)],
		[Vector3(1,0,0),Vector3(0,0,-1),Vector3(0,1,0)],
		[Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,1,0)],
		[Vector3(0,1,0),Vector3(1,0,0),Vector3(0,0,-1)],
		[Vector3(0,-1,0),Vector3(1,0,0),Vector3(0,0,1)]
	]
	for face in faces:
		var normal_axis: Vector3=face[0]
		var u_axis: Vector3=face[1]
		var v_axis: Vector3=face[2]
		var face_half:=Vector3(absf(normal_axis.x)*half.x,absf(normal_axis.y)*half.y,absf(normal_axis.z)*half.z)
		var u_half:=Vector3(absf(u_axis.x)*half.x,absf(u_axis.y)*half.y,absf(u_axis.z)*half.z)
		var v_half:=Vector3(absf(v_axis.x)*half.x,absf(v_axis.y)*half.y,absf(v_axis.z)*half.z)
		var first: int=faces.find(face)*(steps+1)*(steps+1)
		for y in range(steps+1):
			for x in range(steps+1):
				var point:=normal_axis*face_half+u_axis*u_half*(float(x)/steps*2.0-1.0)+v_axis*v_half*(float(y)/steps*2.0-1.0)
				var clamped:=Vector3(clampf(point.x,-inner.x,inner.x),clampf(point.y,-inner.y,inner.y),clampf(point.z,-inner.z,inner.z))
				var normal:=(point-clamped).normalized()
				st.set_normal(normal)
				st.set_uv(Vector2(float(x)/steps,float(y)/steps))
				st.add_vertex(clamped+normal*bevel)
		for y in range(steps):
			for x in range(steps):
				var a: int=first+y*(steps+1)+x
				var b: int=a+1
				var c: int=a+steps+2
				var d: int=a+steps+1
				for index in [a,b,c,a,c,d]: st.add_index(index)
	return st.commit()

func _box(parent: Node3D,size: Vector3,pos: Vector3,material: Material,bevel: float=0.05) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	node.mesh=_rounded_box(size,bevel)
	node.material_override=material
	node.position=pos
	parent.add_child(node)
	return node

func _cylinder(parent: Node3D,radius: float,height: float,pos: Vector3,material: Material,rotation_value: Vector3=Vector3.ZERO,segments: int=24) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var mesh:=CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=segments
	mesh.rings=2
	node.mesh=mesh
	node.material_override=material
	node.position=pos
	node.rotation=rotation_value
	parent.add_child(node)
	return node

func _quad(parent: Node3D,size: Vector2,pos: Vector3,rotation_value: Vector3,material: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var mesh:=QuadMesh.new()
	mesh.size=size
	node.mesh=mesh
	node.material_override=material
	node.position=pos
	node.rotation=rotation_value
	parent.add_child(node)
	return node

# 0: battered, 1: missing wheel, 2: stripped panels, 3: burnt-out shell.
# Collision bounds deliberately remain those of the complete car in every tier.
var damage_tier: int=0

func _car_wheel(x: float,z: float,missing: bool,flattened: bool=false) -> void:
	if missing:
		# A missing wheel exposes a brake disc and axle, not a floating intact hub.
		_cylinder(model,0.235,0.075,Vector3(x,0.34,z),rust_material,Vector3(0,0,PI/2),32)
		_cylinder(model,0.07,0.27,Vector3(x,0.34,z),metal_material,Vector3(0,0,PI/2),20)
		_box(model,Vector3(0.09,0.19,0.11),Vector3(x,0.42,z+0.18),dark_material,0.018)
		return
	var wheel:=MeshInstance3D.new()
	var tire:=TorusMesh.new()
	tire.inner_radius=0.21; tire.outer_radius=0.39
	tire.rings=40; tire.ring_segments=14
	wheel.mesh=tire; wheel.material_override=rubber_material
	wheel.position=Vector3(x,0.43,z); wheel.rotation.z=PI/2
	if flattened:
		wheel.scale=Vector3(1.0,0.72,1.0); wheel.position.y=0.33; wheel.rotation.y=0.20
	model.add_child(wheel)
	_cylinder(model,0.20,0.13,Vector3(x,wheel.position.y,z),metal_material,Vector3(0,0,PI/2),32)
	_cylinder(model,0.075,0.15,Vector3(x,wheel.position.y,z),dark_material,Vector3(0,0,PI/2),24)

func _make_car() -> void:
	damage_tier=clampi(damage_tier,0,3)
	var burnt: bool=damage_tier==3
	var body_color:=Color("292b28") if burnt else paint
	var paint_material:=_material(body_color,0.90 if burnt else 0.48,0.12 if burnt else 0.48)
	var faded_paint:=_material(body_color.lightened(0.08),0.88 if burnt else 0.66,0.16 if burnt else 0.34)
	var upholstery:=_material(Color("24231f") if burnt else Color("3e3830"),0.96,0.0)
	# Keep the chassis and recognizable sedan silhouette even on the bare shell.
	_box(model,Vector3(1.84,0.44,3.94),Vector3(0,0.61,0),paint_material,0.13)
	_box(model,Vector3(1.48,0.12,1.58),Vector3(0,0.91,0.30),dark_material,0.035)
	for x in [-0.43,0.43]:
		_box(model,Vector3(0.58,0.43,0.50),Vector3(x,1.01,0.47),upholstery,0.07)
		var seat_back:=_box(model,Vector3(0.57,0.58,0.16),Vector3(x,1.22,0.73),upholstery,0.05)
		seat_back.rotation.x=-0.12
	# The engine is always modeled; removing the hood reveals it rather than a hole.
	_box(model,Vector3(1.24,0.30,0.82),Vector3(0,0.99,-1.16),dark_material,0.04)
	for x in [-0.42,0.0,0.42]:
		_cylinder(model,0.11,0.64,Vector3(x,1.18,-1.12),rust_material if burnt else metal_material,Vector3(PI/2,0,0),20)
	var hood_missing: bool=damage_tier>=2
	if not hood_missing:
		var hood:=_box(model,Vector3(1.68,0.12,1.12),Vector3(0,1.42,-1.13),faded_paint,0.055)
		hood.rotation.x=-0.83; hood.rotation.z=0.055
	elif damage_tier==2:
		# The removed hood lies beside the car instead of simply vanishing.
		var loose_hood:=_box(model,Vector3(1.22,0.07,0.83),Vector3(-1.35,0.055,-0.82),faded_paint,0.035)
		loose_hood.rotation.y=0.38; loose_hood.rotation.z=0.035
	var trunk_missing: bool=damage_tier>=2 and random.randf()<0.72
	if not trunk_missing:
		_box(model,Vector3(1.74,0.20,1.26),Vector3(0,0.98,1.20),faded_paint,0.07)
	else:
		_box(model,Vector3(1.45,0.08,0.98),Vector3(0,0.88,1.25),dark_material,0.025)
		for x in [-0.78,0.78]:
			_box(model,Vector3(0.12,0.19,1.20),Vector3(x,0.99,1.20),rust_material,0.025)
	# Burnt shells lose the roof, all glazing and both side doors.
	if not burnt:
		_box(model,Vector3(1.52,0.15,1.72),Vector3(0,1.60,0.32),paint_material,0.07)
	for x in [-0.70,0.70]:
		for z in [-0.47,1.03]:
			if burnt and z>0.0: continue
			var pillar:=_box(model,Vector3(0.11,0.72,0.12),Vector3(x,1.24,z),paint_material,0.025)
			pillar.rotation.x=0.12 if z<0 else -0.08
		_box(model,Vector3(0.09,0.11,1.55),Vector3(x,1.00,0.30),paint_material,0.025)
		var door_missing: bool=burnt or (damage_tier==2 and (x<0.0 or random.randf()<0.4))
		if not door_missing:
			_box(model,Vector3(0.075,0.39,1.38),Vector3(x*1.31,0.80,0.32),faded_paint,0.025)
			var side_window:=_quad(model,Vector2(1.30,0.50),Vector3(x,1.30,0.32),Vector3(0,PI/2,0),glass_material)
			if x>0 and damage_tier>0: side_window.visible=false
			for z in [-0.10,0.73]:
				_box(model,Vector3(0.055,0.045,0.20),Vector3(signf(x)*0.945,1.01,z),metal_material,0.012)
		else:
			# Dark inner door frame makes the opening readable from the game camera.
			_box(model,Vector3(0.055,0.10,1.37),Vector3(x*1.26,0.58,0.32),rust_material,0.018)
	if not burnt:
		var windshield:=_quad(model,Vector2(1.30,0.55),Vector3(0,1.29,-0.50),Vector3(-0.12,PI,0),glass_material)
		windshield.scale.x=0.73 if damage_tier>0 else 1.0
		if damage_tier<2:
			_quad(model,Vector2(1.26,0.49),Vector3(0,1.29,1.04),Vector3(0.08,0,0),glass_material)
	# Bumpers and lamps: severe wrecks retain only bent metal and empty lamp buckets.
	_box(model,Vector3(1.82,0.16,0.18),Vector3(0,0.54,-2.00),rust_material if burnt else metal_material,0.04)
	if damage_tier<3:
		_box(model,Vector3(1.82,0.15,0.16),Vector3(0,0.55,2.00),dark_material,0.035)
	_box(model,Vector3(0.70,0.25,0.06),Vector3(0,0.77,-2.00),dark_material,0.02)
	for x in [-0.26,-0.13,0.0,0.13,0.26]:
		_box(model,Vector3(0.035,0.22,0.065),Vector3(x,0.78,-2.035),metal_material,0.008)
	for x in [-0.65,0.65]:
		var lamp_color:=Color("282c29") if burnt or x>0 else Color("c8bb8d")
		_box(model,Vector3(0.36,0.19,0.08),Vector3(x,0.88,-1.99),_material(lamp_color,0.55,0.18),0.04)
		if not burnt:
			_box(model,Vector3(0.30,0.14,0.07),Vector3(x,0.83,1.99),_material(Color("6e1917"),0.32,0.15),0.03)
	# Different corners lose wheels; heavy wrecks may lose two.
	var missing_corner: int=random.randi_range(0,3)
	var wheel_index: int=0
	for x in [-0.94,0.94]:
		for z in [-1.28,1.28]:
			var missing: bool=(damage_tier==1 and wheel_index==missing_corner) or (damage_tier>=2 and (wheel_index==missing_corner or (burnt and wheel_index==(missing_corner+2)%4)))
			_car_wheel(x,z,missing,damage_tier==0 and x>0 and z<0)
			wheel_index+=1
	for i in range(13 if not burnt else 20):
		var side: float=1.0 if i%2==0 else -1.0
		var patch:=_box(model,Vector3(0.025,random.randf_range(0.07,0.18),random.randf_range(0.12,0.38)),Vector3(side*0.927,random.randf_range(0.48,0.80),random.randf_range(-1.72,1.72)),rust_material,0.008)
		patch.rotation.x=random.randf_range(-0.45,0.45)
	for i in range(5 if not burnt else 9):
		var debris:=_box(model,Vector3(random.randf_range(0.12,0.30),0.035,random.randf_range(0.18,0.42)),Vector3(random.randf_range(-1.25,1.25),0.035,random.randf_range(-2.15,2.15)),rust_material,0.01)
		debris.rotation.y=random.randf_range(0,TAU)
	model.rotation.y=random.randf_range(-0.09,0.09)

func _make_fence() -> void:
	var orange:=_material(Color("c65b2c"),0.60,0.25)
	var white:=_material(Color("ddd7c5"),0.48,0.28)
	# Tubular barricade with a reflective upper board and splayed feet.
	for y in [0.30,1.10]:
		_cylinder(model,0.045,2.30,Vector3(0,y,0),metal_material,Vector3(0,0,PI/2),24)
	for x in [-1.10,1.10]:
		_cylinder(model,0.05,1.12,Vector3(x,0.61,0),metal_material,Vector3.ZERO,24)
		_cylinder(model,0.045,0.82,Vector3(x,0.09,0),dark_material,Vector3(PI/2,0,0),20)
	for i in range(9):
		_cylinder(model,0.023,0.77,Vector3(-0.88+i*0.22,0.69,0),metal_material,Vector3.ZERO,16)
	_box(model,Vector3(2.26,0.30,0.09),Vector3(0,1.04,-0.025),orange,0.025)
	for i in range(6):
		var stripe:=_box(model,Vector3(0.19,0.29,0.012),Vector3(-0.91+i*0.365,1.04,-0.078),white,0.006)
		stripe.rotation.z=-0.34
	for x in [-0.82,0.82]:
		var lamp:=_box(model,Vector3(0.16,0.12,0.10),Vector3(x,1.29,0),orange,0.035)
		lamp.material_override=_material(Color("ef7b35"),0.32,0.10)
	model.rotation.y=random.randf_range(-0.06,0.06)

func tick(delta: float) -> void:
	position.z+=3.5*delta
	hit_cooldown=maxf(0.0,hit_cooldown-delta)
	_tick_police_lights(delta)

func overlaps(point: Vector3,radius: float=0.40) -> bool:
	return absf(point.x-position.x)<half_extents.x+radius and absf(point.z-position.z)<half_extents.y+radius
