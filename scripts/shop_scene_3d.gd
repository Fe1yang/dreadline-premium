extends Node3D
## The supply-truck shop: truck shell and a fully stocked cargo interior. No shopkeeper:
## each upgrade belongs to a piece of gear hanging in the truck, and picking one glides the
## camera into a close-up of that gear under a spotlight.

const TRUCK_PATH:="res://assets/models/supply_truck.glb"

# Cargo box interior (truck space): x -0.76..2.53, z -1.04..1.04, floor top y 1.01, roof y 3.0.
const FLOOR_Y:=1.01
const COUNTER_TOP:=1.50

# Overview shot of the stocked truck.
const CAMERA_POS:=Vector3(0.80,2.05,4.55)
const CAMERA_TARGET:=Vector3(0.80,1.92,0.10)
const CAMERA_FOV:=40.0
const CLOSE_FOV:=50.0
const MAX_CAMERA_Z:=0.80 # stay behind the truck's front sign board
# The HUD covers the top 118px and everything below y=594 of the 960px screen, so subjects are
# framed at the centre of the open window (y≈356), not the centre of the screen.
const WINDOW_CENTER_Y:=356.0

# Gear in the truck that each shop item zooms to. "from" is the direction the camera looks from;
# the distance is worked out from the prop's size so the whole thing fits the window.
const FOCUS:={
	"medical":{"prop":"armor","from":Vector3(1.0,0.10,0.25)},     # vest hanging on the left wall
	"ammo":{"prop":"ammo","from":Vector3(0.25,0.55,1.0),"pad":2.2},          # military ammo crate on the counter
	"w_pistol":{"prop":"pistol","from":Vector3(0.0,0.08,1.0)},
	"w_smg":{"prop":"smg","from":Vector3(0.0,0.08,1.0)},
	"w_shotgun":{"prop":"shotgun","from":Vector3(0.0,0.06,1.0)},
	"w_rifle":{"prop":"rifle","from":Vector3(0.0,0.06,1.0)},
	"w_sniper":{"prop":"sniper","from":Vector3(0.0,0.06,1.0)},
	"w_launcher":{"prop":"launcher","from":Vector3(0.0,0.08,1.0)}}
const RACK_KEYS:={"shotgun.glb":"shotgun","sniper.glb":"sniper","rifle.glb":"rifle","smg.glb":"smg","launcher.glb":"launcher","pistol.glb":"pistol"}

var truck: Node3D
var time:=0.0
var props: Dictionary={} # key -> holder node of a gear prop the camera can focus on
var centers: Dictionary={} # key -> world-space centre of that prop
var extents: Dictionary={} # key -> world-space AABB size of that prop
var pop:=0.0
var focus_id:=""
var cam_pos:=CAMERA_POS
var cam_target:=CAMERA_TARGET
var cam_fov:=CAMERA_FOV
var spot: SpotLight3D
var flash: OmniLight3D
var celebrate:=0.0
var auto_focus_timer:=-1.0

func _ready() -> void:
	var packed:=load(TRUCK_PATH) as PackedScene
	if packed==null:
		push_error("supply truck missing: "+TRUCK_PATH)
		return
	truck=packed.instantiate() as Node3D
	if truck==null:
		push_error("supply truck failed to instantiate")
		return
	add_child(truck)
	# The truck model's baked shopkeeper statue stays hidden.
	for hide in ["Merchant_HD","Crate.001","CrateLatch.001","Crate.002","CrateLatch.002"]:
		var n:=truck.find_child(hide,true,false)
		if n: n.visible=false
	_build_lighting()
	_build_back_wall()
	_build_shelves()
	_build_side_walls()
	_build_floor_clutter()
	_build_counter()
	_build_focus_lights()
	_register("ammo",truck.find_child("Crate_002",true,false) as Node3D)

## Called when the shop opens: start on the overview, then glide to the first item.
func reset_view(first_id: String) -> void:
	focus_id=""; cam_pos=CAMERA_POS; cam_target=CAMERA_TARGET; cam_fov=CAMERA_FOV; celebrate=0.0
	for key in props: props[key].scale=Vector3.ONE
	auto_focus_timer=-1.0 # stay on the overview until the player picks an item
	set_meta("first_id",first_id)

func focus(id: String) -> void:
	if FOCUS.has(id) and props.has(FOCUS[id].prop): focus_id=id; auto_focus_timer=-1.0

func celebrate_purchase(id: String) -> void:
	focus(id); celebrate=1.0

func _process(delta: float) -> void:
	if not visible: return
	time+=delta
	if auto_focus_timer>0.0:
		auto_focus_timer-=delta
		if auto_focus_timer<=0.0 and focus_id=="": focus(String(get_meta("first_id","medical")))
	var want_pos:=CAMERA_POS+Vector3(sin(time*0.45)*0.03,sin(time*0.7)*0.015,0)
	var want_target:=CAMERA_TARGET; var want_fov:=CAMERA_FOV
	if focus_id!="":
		var key: String=FOCUS[focus_id].prop
		var center: Vector3=centers[key]
		want_fov=CLOSE_FOV
		want_pos=center+_focus_offset(focus_id)+Vector3(sin(time*0.35)*0.02,sin(time*0.5)*0.01,0)
		# Aim below the subject so it sits in the middle of the window between the HUD panels.
		var drop: float=(480.0-WINDOW_CENTER_Y)/480.0*tan(deg_to_rad(want_fov*0.5))*want_pos.distance_to(center)
		want_target=center-Vector3(0,drop,0)
	# Critically damped glide: fast start, soft landing, no snapping.
	var k:=1.0-exp(-delta*4.2)
	cam_pos=cam_pos.lerp(want_pos,k); cam_target=cam_target.lerp(want_target,k); cam_fov=lerpf(cam_fov,want_fov,k)
	# Purchase: the gear gives a small bounce and catches a warm flash.
	celebrate=maxf(0.0,celebrate-delta*1.8)
	for key in props:
		var holder: Node3D=props[key]
		var focused: bool=focus_id!="" and FOCUS[focus_id].prop==key
		holder.scale=Vector3.ONE*(1.0+0.12*sin(celebrate*PI) if focused else 1.0)
	if spot and focus_id!="":
		var c: Vector3=centers[FOCUS[focus_id].prop]
		spot.position=spot.position.lerp(c+_focus_offset(focus_id)*0.8+Vector3(0,0.45,0),k)
		spot.look_at(c,Vector3.UP)
		spot.light_energy=lerpf(spot.light_energy,2.6,k)
	if flash:
		flash.light_energy=celebrate*3.5
		if focus_id!="": flash.position=centers[FOCUS[focus_id].prop]+_focus_offset(focus_id)*0.4

func _focus_offset(id: String) -> Vector3:
	var info: Dictionary=FOCUS[id]; var size: Vector3=extents[info.prop]
	var dir: Vector3=(info.from as Vector3).normalized()
	# Width seen by the camera is the extent across the view direction; fit ~78% of the frame.
	var across: float=absf(dir.z)*size.x+absf(dir.x)*size.z
	var half_h: float=tan(deg_to_rad(CLOSE_FOV*0.5))
	var half_w: float=half_h*540.0/960.0
	var window_h: float=half_h*(476.0/960.0) # visible 3D window between the HUD panels
	var dist: float=maxf(maxf(across*0.5/(half_w*0.78),size.y*0.5/(window_h*0.80)),0.45)
	dist*=float(info.get("pad",1.0))
	var center: Vector3=centers[info.prop]
	if dir.z>0.01 and center.z<MAX_CAMERA_Z-0.3: dist=minf(dist,(MAX_CAMERA_Z-center.z)/dir.z)
	return dir*dist

func camera_position() -> Vector3:
	return cam_pos

func camera_target() -> Vector3:
	return cam_target

func camera_fov() -> float:
	return cam_fov

func _register(key: String,holder: Node3D) -> void:
	if holder==null: return
	props[key]=holder
	var box:=_aabb(holder)
	if holder is MeshInstance3D: box=(holder as MeshInstance3D).get_aabb() if box.size==Vector3.ZERO else box.merge((holder as MeshInstance3D).get_aabb())
	var basis: Basis=holder.global_transform.basis if holder.is_inside_tree() else holder.transform.basis
	centers[key]=holder.global_transform*box.get_center() if holder.is_inside_tree() else holder.position+box.get_center()
	var world:=Transform3D(basis,Vector3.ZERO)*box
	extents[key]=world.size

func _build_focus_lights() -> void:
	spot=SpotLight3D.new(); spot.light_color=Color("fff1dc"); spot.light_energy=0.0; spot.spot_range=3.0
	spot.spot_angle=26.0; spot.position=Vector3(0.8,2.6,1.2); add_child(spot)
	flash=OmniLight3D.new(); flash.light_color=Color("ffd27a"); flash.light_energy=0.0; flash.omni_range=1.6; add_child(flash)

# ---------------------------------------------------------------- helpers

func _mat(color: Color,rough:=0.85,metal:=0.0) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new(); m.albedo_color=color; m.roughness=rough; m.metallic=metal
	return m

func _box(size: Vector3,pos: Vector3,color: Color,rough:=0.85,metal:=0.0,parent: Node=null) -> MeshInstance3D:
	var n:=MeshInstance3D.new(); var b:=BoxMesh.new(); b.size=size; n.mesh=b
	n.material_override=_mat(color,rough,metal); n.position=pos
	(parent if parent else self).add_child(n); return n

func _cyl(radius: float,height: float,pos: Vector3,color: Color,rough:=0.8,metal:=0.0) -> MeshInstance3D:
	var n:=MeshInstance3D.new(); var c:=CylinderMesh.new(); c.top_radius=radius; c.bottom_radius=radius; c.height=height
	n.mesh=c; n.material_override=_mat(color,rough,metal); n.position=pos; add_child(n); return n

func _aabb(node: Node3D) -> AABB:
	var box:=AABB(); var first:=true
	for m in node.find_children("*","MeshInstance3D",true,false):
		var mi:=m as MeshInstance3D
		var local:Transform3D=node.global_transform.affine_inverse()*mi.global_transform if node.is_inside_tree() else _relative(node,mi)
		var a:=local*mi.get_aabb()
		if first: box=a; first=false
		else: box=box.merge(a)
	return box

func _relative(root: Node3D,child: Node3D) -> Transform3D:
	var t:=Transform3D.IDENTITY; var n:Node=child
	while n and n!=root:
		if n is Node3D: t=(n as Node3D).transform*t
		n=n.get_parent()
	return t

## Places a model so its longest side is `length` metres, centred at `pos`, with its long axis
## along X (for things hung on the back wall) and resting with its bottom at pos.y when `rest`.
func _prop(path: String,length: float,pos: Vector3,yaw:=0.0,lay_long_axis_on_x:=false,rest:=true,stand_off:=false) -> Node3D:
	if not ResourceLoader.exists(path): return null
	# A stale import (the .glb is on disk but its imported scene is broken) used to crash the
	# whole shop with "instantiate on a null instance".
	var packed:=load(path) as PackedScene
	if packed==null:
		push_warning("shop prop failed to load: "+path)
		return null
	var holder:=Node3D.new(); add_child(holder)
	var model:=packed.instantiate() as Node3D
	if model==null:
		holder.queue_free()
		return null
	holder.add_child(model)
	var box:=_aabb(model)
	if lay_long_axis_on_x and box.size.z>box.size.x and box.size.z>=box.size.y:
		model.rotation.y=PI*0.5; box=_aabb_rotated(model)
	var longest:=maxf(box.size.x,maxf(box.size.y,box.size.z))
	var s:=length/maxf(longest,0.001)
	model.scale=model.scale*s
	box=_aabb_rotated(model)
	var offset:=-box.get_center()
	if rest: offset.y=-box.position.y
	model.position+=offset
	if stand_off:
		# hung on the wall: keep the whole body in front of the pegboard
		model.position.z += box.size.z * 0.5 + 0.02
	holder.position=pos; holder.rotation.y=yaw
	return holder

func _aabb_rotated(model: Node3D) -> AABB:
	var box:=AABB(); var first:=true
	for m in model.find_children("*","MeshInstance3D",true,false):
		var mi:=m as MeshInstance3D
		var t:=model.transform*_relative(model,mi)
		var a:=t*mi.get_aabb()
		if first: box=a; first=false
		else: box=box.merge(a)
	return box

# ---------------------------------------------------------------- interior dressing

func _build_lighting() -> void:
	# Warm work-lamp inside the cargo box plus a soft key light on the counter.
	var bulb_pos:=Vector3(1.85,2.86,-0.35)
	# (The hanging shade was removed: it blocked the close-ups of the top rack.)
	var lamp:=OmniLight3D.new(); lamp.position=bulb_pos-Vector3(0,0.12,0); lamp.light_color=Color("ffc887")
	lamp.light_energy=2.4; lamp.omni_range=4.2; add_child(lamp)
	var key:=OmniLight3D.new(); key.position=Vector3(0.80,2.35,2.30); key.light_color=Color("ffe6c4")
	key.light_energy=1.35; key.omni_range=3.2; add_child(key)
	var rim:=OmniLight3D.new(); rim.position=Vector3(2.2,2.3,-0.6); rim.light_color=Color("9fb7c8")
	rim.light_energy=0.7; rim.omni_range=2.6; add_child(rim)

func _build_back_wall() -> void:
	# Pegboard with the weapon rack above the shelves.
	var board:=_box(Vector3(3.05,0.82,0.03),Vector3(0.88,2.55,-1.01),Color("4a4136"),0.95)
	for row in range(5):
		for col in range(26):
			_box(Vector3(0.018,0.018,0.006),Vector3(-0.55+col*0.115,2.22+row*0.16,-0.993),Color("2a241e"),1.0,0.0,board.get_parent())
	var rack:=[["res://assets/models/weapons/shotgun.glb",0.92,Vector3(-0.05,2.78,-0.94)],
		["res://assets/models/weapons/sniper.glb",1.10,Vector3(1.05,2.80,-0.94)],
		["res://assets/models/rifle.glb",0.90,Vector3(2.05,2.78,-0.94)],
		["res://assets/models/weapons/smg.glb",0.55,Vector3(-0.15,2.40,-0.94)],
		["res://assets/models/weapons/launcher.glb",0.85,Vector3(0.75,2.42,-0.92)],
		["res://assets/models/weapons/pistol.glb",0.26,Vector3(1.55,2.40,-0.95)],
		["res://assets/models/weapons/pistol.glb",0.26,Vector3(1.90,2.40,-0.95)]]
	for item in rack:
		# Same lay-flat as every other gun, then half a turn so the pistol presents the face
		# the player reads instead of the mirror of the rest of the rack.
		var is_pistol:=String(item[0]).ends_with("pistol.glb")
		var held:=_prop(item[0],item[1],item[2],PI if is_pistol else 0.0,true,false,true)
		var file: String=String(item[0]).get_file()
		if held!=null and RACK_KEYS.has(file) and not props.has(RACK_KEYS[file]): _register(RACK_KEYS[file],held)
		# two pegs under each weapon
		_cyl(0.008,0.06,item[2]+Vector3(-0.12,-0.07,-0.02),Color("9a9a92"),0.4,0.8).rotation.x=PI*0.5
		_cyl(0.008,0.06,item[2]+Vector3(0.12,-0.07,-0.02),Color("9a9a92"),0.4,0.8).rotation.x=PI*0.5

func _build_shelves() -> void:
	# Upper shelf (top surface y≈2.10): medical, helmets, grenades.
	var top:=2.10
	_prop("res://assets/models/medkit.glb",0.30,Vector3(-0.35,top+0.07,-0.55),0.15)
	_prop("res://assets/models/medkit.glb",0.30,Vector3(0.00,top+0.07,-0.57),-0.1)
	_prop("res://assets/models/helmet.glb",0.30,Vector3(0.45,top+0.07,-0.55),0.6)
	_prop("res://assets/models/helmet.glb",0.30,Vector3(0.82,top+0.07,-0.57),-0.4)
	_box(Vector3(0.46,0.06,0.22),Vector3(1.32,top+0.03,-0.70),Color("3d4a33"),0.9)
	for i in range(4):
		_prop("res://assets/models/frag_grenade.glb",0.10,Vector3(1.15+i*0.11,top+0.06,-0.70),i*0.7)
	for i in range(3):
		_prop("res://assets/models/flashbang.glb",0.13,Vector3(1.72+i*0.12,top,-0.70),i*0.4)
	_prop("res://assets/models/fire_round.glb",0.16,Vector3(2.18,top,-0.70),0.3)
	# Lower shelf already carries the truck's ammo boxes; add loose ammo cans at the ends.
	_prop("res://assets/models/ammo_pickup.glb",0.28,Vector3(2.32,1.64,-0.52),0.2)

func _build_side_walls() -> void:
	# Left wall (behind the cab): armour vest on a hook, a city map and a hand-written price list.
	_register("armor",_prop("res://assets/models/armor.glb",0.62,Vector3(-0.58,1.95,-0.25),PI*0.5,false,true))
	_cyl(0.01,0.10,Vector3(-0.66,2.62,-0.25),Color("8f8f88"),0.4,0.8).rotation.z=PI*0.5
	var map:=_box(Vector3(0.01,0.42,0.58),Vector3(-0.67,2.35,0.55),Color("c9bb8f"),1.0)
	for i in range(5):
		_box(Vector3(0.004,0.006,0.5),Vector3(-0.663,2.20+i*0.07,0.55),Color("7b6a48"),1.0,0.0,map.get_parent())
	_box(Vector3(0.004,0.05,0.05),Vector3(-0.662,2.42,0.42),Color("b3262a"),1.0)
	_box(Vector3(0.004,0.05,0.05),Vector3(-0.662,2.28,0.66),Color("b3262a"),1.0)
	# Right wall (rear doors): hanging ammo belt and a fire extinguisher.
	_cyl(0.075,0.42,Vector3(2.38,1.24,0.55),Color("a51d1d"),0.45,0.3)
	_cyl(0.03,0.08,Vector3(2.38,1.49,0.55),Color("1f1f1f"),0.5,0.6)
	for i in range(9):
		_cyl(0.012,0.07,Vector3(2.44,2.55-i*0.06,-0.15+i*0.025),Color("c9a24a"),0.35,0.9).rotation.z=PI*0.5

func _build_floor_clutter() -> void:
	# Crates, a barrel and jerrycans on the cargo floor (mostly hidden behind the counter wall,
	# visible through the window edges for depth).
	var wood:=Color("6b5233")
	_box(Vector3(0.55,0.42,0.45),Vector3(-0.38,FLOOR_Y+0.21,-0.65),wood,0.95)
	_box(Vector3(0.45,0.36,0.40),Vector3(-0.40,FLOOR_Y+0.60,-0.66),wood.darkened(0.12),0.95)
	_box(Vector3(0.30,0.40,0.16),Vector3(2.25,FLOOR_Y+0.20,0.45),Color("8e2420"),0.6,0.2)
	_box(Vector3(0.30,0.40,0.16),Vector3(2.25,FLOOR_Y+0.20,0.25),Color("3f5a2c"),0.6,0.2)
	_prop("res://assets/models/barrel.glb",0.85,Vector3(2.15,FLOOR_Y,-0.62),0.4)

func _build_counter() -> void:
	# Counter top surface y≈1.50: goods laid out for the player.
	var top:=COUNTER_TOP
	_prop("res://assets/models/weapons/pistol.glb",0.24,Vector3(0.18,top,1.40),-0.5)
	_prop("res://assets/models/ammo_pickup.glb",0.22,Vector3(1.55,top,1.10),0.3)
	_prop("res://assets/models/medkit.glb",0.26,Vector3(1.62,top,1.38),-0.2)
	_prop("res://assets/models/frag_grenade.glb",0.10,Vector3(0.40,top,1.50),0.0)
	# Cash tin, radio and a coffee mug.
	_box(Vector3(0.22,0.08,0.15),Vector3(1.02,top+0.04,1.38),Color("2e5b50"),0.5,0.5)
	_box(Vector3(0.26,0.14,0.09),Vector3(-0.18,top+0.07,1.30),Color("2a2a27"),0.6,0.3)
	_cyl(0.035,0.12,Vector3(-0.12,top+0.20,1.30),Color("444440"),0.5,0.5).rotation.z=0.4
	_cyl(0.035,0.09,Vector3(0.95,top+0.045,1.52),Color("d8d2c3"),0.6)
