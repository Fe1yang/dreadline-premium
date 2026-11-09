extends RefCounted
## Persistent disaster storytelling on every city block. Nothing here depends on a
## player kill: dried blood, drag marks, filth and rubble already cover the street.

static var materials: Dictionary={}

static var _blood_tex: Array=[]

# Procedural splatter decals: 4 hand-drawn shapes (burst, smear, spray, drip) so dried
# blood keeps its spattered silhouette instead of a fan blob.
static func _blood_textures() -> Array:
	if not _blood_tex.is_empty(): return _blood_tex
	var rng:=RandomNumberGenerator.new(); rng.seed=20261107
	for t in range(4):
		var W:=256; var H:=256
		var img:=Image.create(W,H,false,Image.FORMAT_RGBA8)
		img.fill(Color(0,0,0,0))
		var cx:=W/2; var cy:=H/2
		var base:=Color(0.42,0.08,0.07,0.85)
		var dark:=Color(0.28,0.05,0.05,0.9)
		if t==0: # burst: central pool + long spikes + droplets
			_blot(img,cx,cy,52,base,5)
			for s in range(16):
				var a:=rng.randf_range(0,TAU); var len:=rng.randf_range(40,100)
				var ex:=int(cx+cos(a)*len); var ey:=int(cy+sin(a)*len)
				_line(img,cx,cy,ex,ey,dark,2)
				_drop(img,ex,ey,int(rng.randf_range(3,7)),base)
			for d in range(40):
				var a2:=rng.randf_range(0,TAU); var r:=rng.randf_range(55,115)
				_drop(img,int(cx+cos(a2)*r),int(cy+sin(a2)*r),int(rng.randf_range(1,4)),base)
		elif t==1: # smear: horizontal wipe
			_blot(img,cx,cy,38,base,4)
			for s in range(10):
				var y:=cy+int(rng.randf_range(-30,30))
				var x0:=cx-int(rng.randf_range(30,90)); var x1:=cx+int(rng.randf_range(30,95))
				_line(img,x0,y,x1,y+int(rng.randf_range(-8,8)),dark,3)
			for d in range(16):
				_drop(img,int(rng.randf_range(20,236)),int(cy+rng.randf_range(-45,45)),int(rng.randf_range(2,5)),base)
		elif t==2: # upward spray: fan with fine mist
			_blot(img,cx,cy+30,30,dark,3)
			for s in range(22):
				var a:=rng.randf_range(-PI,0); var len:=rng.randf_range(50,110)
				var ex:=int(cx+cos(a)*len); var ey:=int(cy+30+sin(a)*len)
				_line(img,cx,cy+30,ex,ey,base,1)
				_drop(img,ex,ey,int(rng.randf_range(1,3)),base)
			for d in range(60):
				var a2:=rng.randf_range(-PI,0); var r:=rng.randf_range(30,115)
				_drop(img,int(cx+cos(a2)*r),int(cy+30+sin(a2)*r),int(rng.randf_range(1,3)),dark)
		else: # drip trail: pool + staggered drops + thin neck
			_blot(img,cx,cy+40,26,base,3)
			var px:=cx; var py:=cy+40
			for s in range(6):
				px+=int(rng.randf_range(-14,14)); py-=int(rng.randf_range(16,30))
				_drop(img,px,py,int(rng.randf_range(8,15)),dark)
			for d in range(12):
				_drop(img,px+int(rng.randf_range(-28,28)),py+int(rng.randf_range(-28,28)),int(rng.randf_range(2,5)),base)
		_blood_tex.append(ImageTexture.create_from_image(img))
	return _blood_tex

static func _blot(img: Image,cx: int,cy: int,r: int,col: Color,jitter: int) -> void:
	var rng:=RandomNumberGenerator.new(); rng.seed=cx*7+cy*13+r
	for dy in range(-r,r+1):
		for dx in range(-r,r+1):
			var d: float=Vector2(dx,dy).length()
			var edge: float=r+int(rng.randf_range(-jitter,jitter))
			if d<edge:
				var a: float=clampf(1.0-(d/r)*0.35,0.0,1.0)*col.a
				_px(img,cx+dx,cy+dy,Color(col.r,col.g,col.b,a))

static func _drop(img: Image,cx: int,cy: int,r: int,col: Color) -> void:
	for dy in range(-r,r+1):
		for dx in range(-r,r+1):
			if dx*dx+dy*dy<=r*r:
				_px(img,cx+dx,cy+dy,col)

static func _line(img: Image,x0: int,y0: int,x1: int,y1: int,col: Color,w: int) -> void:
	var steps: int=maxi(absi(x1-x0),absi(y1-y0))+1
	for s in range(steps+1):
		var t: float=float(s)/steps
		var px: int=int(lerpf(x0,x1,t)); var py: int=int(lerpf(y0,y1,t))
		for dy in range(-w,w+1):
			for dx in range(-w,w+1):
				_px(img,px+dx,py+dy,col)

static func _px(img: Image,x: int,y: int,col: Color) -> void:
	if x>=0 and y>=0 and x<img.get_width() and y<img.get_height():
		img.set_pixel(x,y,col)

const BloodPoolDM := preload("res://scripts/blood_pool_3d.gd")

static func _blood_decal(parent: Node3D,pos: Vector3,size: float,rng: RandomNumberGenerator) -> void:
	# Same look as kill blood: noise-edged pool + satellite drops, dark centre, wet sheen.
	var pool: Node3D = BloodPoolDM.new()
	parent.add_child(pool)
	pool.setup(size,rng.randi(),9999.0,true)
	pool.position=pos
	pool.scale=Vector3.ONE*size
	pool.rotation.y=rng.randf_range(0,TAU)

static func apply(road: Node3D,index: int,zombie_script: GDScript) -> void:
	var root:=Node3D.new(); root.name="DisasterDressing"; road.add_child(root)
	var rng:=RandomNumberGenerator.new(); rng.seed=741103+index*7919
	# Dried blood, spatter silhouettes. Density varies by block (some heavy, some clean)
	# and each decal sits at its own height so overlapping stains never z-fight.
	var density: int
	match index%6:
		0: density=2
		1: density=0
		2: density=1
		3: density=3
		4: density=0
		_: density=1
	for i in range(density):
		var pos:=Vector3(rng.randf_range(-2.8,2.8),0.019+0.0008*(index%12)+0.0004*i,rng.randf_range(-6.8,6.8))
		_blood_decal(root,pos,rng.randf_range(3.0,5.2),rng)
	# Sidewalk decals: random per block, both sides possible.
	if rng.randf()<0.7:
		var sside2: int=1 if rng.randf()<0.5 else -1
		var sp2:=Vector3(sside2*rng.randf_range(4.7,6.4),0.159+0.0008*(index%8),rng.randf_range(-6.0,6.0))
		_blood_decal(root,sp2,rng.randf_range(1.2,2.0),rng)
	# Wall blood + bullet holes + occasional blast crater (sparse).
	if rng.randf()<0.6:
		var wside: float=1.0 if rng.randf()<0.5 else -1.0
		for w in range(rng.randi_range(1,3)):
			var wp:=Vector3(wside*rng.randf_range(6.6,7.4),rng.randf_range(0.35,1.5),rng.randf_range(-6.5,6.5))
			_wall_patch(root,wp,Color(0.30,0.07,0.07,0.75),rng.randf_range(0.18,0.45),wside)
	# Bullet impacts on the wall: small dark chips.
	if rng.randf()<0.8:
		var bside: float=1.0 if rng.randf()<0.5 else -1.0
		for b in range(rng.randi_range(3,9)):
			var bp2:=Vector3(bside*rng.randf_range(6.6,7.3),rng.randf_range(0.4,2.2),rng.randf_range(-6.8,6.8))
			_wall_patch(root,bp2,Color(0.05,0.05,0.05,0.8),rng.randf_range(0.04,0.09),bside)
	# Rare explosion crater on the wall: dark scorch, never dense.
	if rng.randf()<0.15:
		var eside: float=1.0 if rng.randf()<0.5 else -1.0
		var ep:=Vector3(eside*rng.randf_range(6.6,7.2),rng.randf_range(0.3,0.9),rng.randf_range(-6.0,6.0))
		_wall_patch(root,ep,Color(0.04,0.04,0.04,0.55),rng.randf_range(0.5,0.9),eside)
	# No drag stains: user rejected the dark diagonal smears as fake. Blood pools only.
	# No fake blast scorch — user rejected it as fake. Blood only.
	if index%3==0:
		var side2:=-1 if index%2==0 else 1
		var pos2:=Vector3(side2*rng.randf_range(4.8,6.7),0.158,rng.randf_range(-6.5,6.5))
		_irregular_patch(root,pos2,.30,.52,Color(0.20,0.18,0.15,0.20),rng,20)
	# One small, grouped debris site every few blocks, not a continuous carpet.
	if index%4==2:
		_scatter_debris(root,-1 if index%8==2 else 1,rng)
	# An occasional real death pose on the pavement; these are scenery, never shootable targets.
	if index%5==2:
		var corpse:=load("res://scripts/corpse_3d.gd").new() as Node3D
		corpse.seed_value=9817+index*3571
		corpse.body_count=1
		corpse.position=Vector3((-1.0 if index%2==0 else 1.0)*rng.randf_range(4.85,5.65),0.17,rng.randf_range(-5.6,5.6))
		root.add_child(corpse)
	# Ambient watchers on the pavement: some stand and sway, some sit slumped on a crate, all
	# watching the road. They can be shot (kills and coins count) and travel with the city loop.
	if index%2==0:
		spawn_watcher(road,index,zombie_script,rng)
	_merge_quads(root)

## ---- Static merge ---------------------------------------------------------------------
## The wall stains and bullet chips above are one MeshInstance (and one material) each:
## 20-30 draw calls per block for a few splinters of paint. Quads that share a material
## are baked into one mesh instead, which changes no pixel but a lot of draw calls.
static func _merge_quads(root: Node3D) -> void:
	var groups: Dictionary={}
	for child in root.get_children():
		var mi:=child as MeshInstance3D
		if mi==null or mi.mesh==null or mi.get("full_scale")!=null: continue  # blood decals animate
		if not (mi.mesh is PlaneMesh): continue
		var m:=mi.material_override as BaseMaterial3D
		if m==null: continue
		var key: String="%d_%d_%d_%d" % [m.albedo_color.r8, m.albedo_color.g8, m.albedo_color.b8, m.albedo_color.a8]
		if not groups.has(key): groups[key]=[m,[]]
		groups[key][1].append(mi)
	for key in groups.keys():
		var list: Array=groups[key][1]
		if list.size()<2: continue
		var st:=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi in list: st.append_from(mi.mesh,0,mi.transform)
		var merged:=MeshInstance3D.new(); merged.mesh=st.commit(); merged.material_override=groups[key][0]
		merged.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(merged)
		for mi in list: mi.queue_free()

const AnimLibrary=preload("res://scripts/anim_library.gd")
const LegsOut=preload("res://scripts/legs_out.gd")

static func spawn_watcher(road: Node3D,index: int,zombie_script: GDScript,rng: RandomNumberGenerator,meta_key: String="watcher") -> Node3D:
	var side:=-1 if ((index/2)+RoadSeedOffset(meta_key))%2==0 else 1
	var watcher: Node3D=zombie_script.new()
	# Mixed crowd: male walkers and female runners watching from the pavement.
	var kind: String="walker" if rng.randf()<0.5 else "runner"
	watcher.configure(kind,1.0)
	watcher.set_meta("watcher",true)
	watcher.speed=0.0
	watcher.position=Vector3(side*rng.randf_range(5.0,5.6),0.16,rng.randf_range(-5.8,5.8))
	watcher.model.rotation.y=-side*PI/2+rng.randf_range(-0.35,0.35) # facing the road
	var anim: AnimationPlayer=watcher.animation_player
	var sitting:=rng.randf()<0.5
	if sitting and is_instance_valid(anim):
		var clip:=AnimLibrary.borrow(anim,"Sitting_Idle")
		var skel:=watcher.model.find_child("Skeleton3D",true,false) as Skeleton3D
		if clip!="" and skel:
			# Slumped on the pavement: seated upper body, legs laid out along the ground.
			var legs:=LegsOut.new(); legs.body=watcher.model; skel.add_child(legs)
			watcher.model.position.y-=0.40
			anim.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
			anim.play(clip); anim.speed_scale=rng.randf_range(0.8,1.0); anim.seek(rng.randf()*3.0,true)
		else: sitting=false
	if not sitting and is_instance_valid(anim):
		# Standing upright and swaying (the zombie pack's own idle is a half-crouch).
		var idle:=AnimLibrary.borrow(anim,"Idle")
		if idle=="" and anim.has_animation("Zombie_Idle"): idle="Zombie_Idle"
		if idle!="":
			anim.get_animation(idle).loop_mode=Animation.LOOP_LINEAR
			anim.play(idle); anim.speed_scale=rng.randf_range(0.7,0.9); anim.seek(rng.randf()*2.0,true)
	watcher.set_meta("sitting",sitting)
	watcher.set_meta("base_yaw",watcher.model.rotation.y)
	watcher.set_meta("next_act",rng.randf_range(1.0,4.0))
	if is_instance_valid(anim):
		# Extra clips for the little routines in main_3d._tick_watchers.
		for clip_name in (["Sitting_Talking"] if sitting else ["Walk","Idle_Talking"]):
			var c:=AnimLibrary.borrow(anim,clip_name)
			if c!="": anim.get_animation(c).loop_mode=Animation.LOOP_LINEAR
	road.add_child(watcher)
	road.set_meta(meta_key,watcher)
	return watcher

static func RoadSeedOffset(meta_key: String) -> int:
	match meta_key:
		"watcher_1": return 1
		"watcher_2": return 2
	return 0

static func _material(color: Color,roughness:=0.96) -> StandardMaterial3D:
	var key:=str(color)+str(roughness)
	if materials.has(key): return materials[key]
	var m:=StandardMaterial3D.new(); m.albedo_color=color; m.roughness=roughness
	m.metallic_specular=0.0
	if color.a<0.999: m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	materials[key]=m; return m

static func _wall_patch(parent: Node3D,pos: Vector3,col: Color,r: float,side: float) -> void:
	# Small vertical stain on a building face, facing the road.
	var node:=MeshInstance3D.new(); var pm:=PlaneMesh.new(); pm.size=Vector2(r*2,r*1.4)
	node.mesh=pm
	var m:=StandardMaterial3D.new(); m.albedo_color=col; m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness=0.7; m.cull_mode=BaseMaterial3D.CULL_DISABLED
	node.material_override=m
	node.position=pos
	node.rotation.y=-side*PI/2
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

static func _irregular_patch(parent: Node3D,pos: Vector3,rx: float,rz: float,color: Color,rng: RandomNumberGenerator,points: int) -> void:
	var st:=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[Vector3]=[]
	for i in range(points):
		var angle:=TAU*i/points
		var radius:=rng.randf_range(.68,1.12)
		ring.append(Vector3(cos(angle)*rx*radius,0,sin(angle)*rz*radius))
	for i in range(points):
		st.set_normal(Vector3.UP); st.add_vertex(pos)
		st.set_normal(Vector3.UP); st.add_vertex(pos+ring[(i+1)%points])
		st.set_normal(Vector3.UP); st.add_vertex(pos+ring[i])
	var node:=MeshInstance3D.new(); node.mesh=st.commit(); node.material_override=_material(color)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(node)

static func _drag_stain(parent: Node3D,pos: Vector3,direction: float,length: float,rng: RandomNumberGenerator) -> void:
	var color:=Color(0.35,0.08,0.07,0.65)
	for i in range(5):
		var t:=i/4.0
		var p:=pos+Vector3(direction*t*length,0,t*length)
		_irregular_patch(parent,p,.14*(1.0-t*.72),.48,color,rng,12)
		for side in [-1,1]:
			_irregular_patch(parent,p+Vector3(side*.15*(1.0-t*.5),.001,.10),.045,.30,color,rng,8)

const DEBRIS_PATHS:=[
	"res://assets/models/props/debris_concrete_00.glb",
	"res://assets/models/props/debris_concrete_01.glb",
	"res://assets/models/props/debris_brick.glb",
	"res://assets/models/props/debris_board.glb",
	"res://assets/models/props/debris_can.glb",
	"res://assets/models/props/debris_newspaper.glb"
]
static var debris_cache: Dictionary={}

static func _debris(parent: Node3D,pos: Vector3,index: int,rng: RandomNumberGenerator,scale:=1.0) -> void:
	if not debris_cache.has(index):
		var prototype:=load(DEBRIS_PATHS[index]).instantiate() as Node3D
		var meshes:=prototype.find_children("*","MeshInstance3D",true,false)
		var source:=meshes[0] as MeshInstance3D if not meshes.is_empty() else null
		if source==null:
			push_error("Detailed street debris mesh missing: "+DEBRIS_PATHS[index])
			prototype.free(); return
		debris_cache[index]=source.mesh
		prototype.free()
	var node:=MeshInstance3D.new(); node.mesh=debris_cache[index]
	node.position=pos; node.rotation.y=rng.randf_range(0,TAU); node.scale=Vector3.ONE*scale
	if index==4: node.rotation.z=PI/2 # discarded cans lie on their sides
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)

static func _scatter_debris(parent: Node3D,side: int,rng: RandomNumberGenerator) -> void:
	# A single small site: two chips and one paper, with an occasional board or can.
	var center_z:=rng.randf_range(-6.2,6.2)
	for i in range(2):
		var x:=side*rng.randf_range(4.65,5.75)
		_debris(parent,Vector3(x,.155,center_z+rng.randf_range(-.40,.40)),rng.randi_range(0,2),rng,rng.randf_range(.72,1.05))
	_debris(parent,Vector3(side*rng.randf_range(4.8,5.9),.158,center_z+rng.randf_range(-.55,.55)),5,rng,1.0)
	if rng.randf()<.35:
		_debris(parent,Vector3(side*5.25,.16,center_z+.65),3,rng,1.0)
	elif rng.randf()<.35:
		_debris(parent,Vector3(side*5.15,.205,center_z-.55),4,rng,1.0)
