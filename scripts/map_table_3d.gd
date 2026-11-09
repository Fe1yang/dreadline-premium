extends Node3D
## The war-room map table, rebuilt: a plank table on legs, an aged parchment map with
## real cartographic patterns (grid, roads, river, coast, city blocks, contours, compass,
## place icons, burn marks), polaroid photos pinned along a red-string route, a kerosene
## lantern and a hunting knife. The table is wider than a portrait screen: the camera
## fills the frame and a horizontal swipe pans across the table. Only the city photo is
## a real destination; every other photo answers "coming soon".

const CAMERA_FOV := 48.0
const PAN_MIN := -2.6
const PAN_MAX := 2.6
const MAP_W := 6.0
const MAP_H := 2.3

var lantern_light: OmniLight3D
var city_frame_mat: StandardMaterial3D
var pan_x := -2.0   # opens on the city; swipe right for the rest of the table
var _t := 0.0
var photos: Array = []  # {id, node, open}

func _ready() -> void:
	var we:=WorldEnvironment.new(); var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR; env.background_color=Color("050403")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("4a3826"); env.ambient_light_energy=0.75
	env.tonemap_mode=Environment.TONE_MAPPER_ACES; env.tonemap_exposure=1.0
	we.environment=env; add_child(we)
	_build_table()
	_build_map()
	_build_route()
	_build_photos()
	_build_lantern()
	_build_knife()
	_build_mug()
	# Dark shell so neither the road nor the sky can leak in around the table.
	var shell:=MeshInstance3D.new(); var sb:=BoxMesh.new(); sb.size=Vector3(40,20,40)
	shell.mesh=sb
	var sm:=StandardMaterial3D.new(); sm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color=Color("050303"); sm.cull_mode=BaseMaterial3D.CULL_FRONT; sm.disable_fog=true
	shell.material_override=sm; shell.position=Vector3(0,4,0); add_child(shell)
	position=Vector3(600,-500,0)

## ---- building blocks -----------------------------------------------------------------------

func _mat(albedo: String,rough: float,metallic: float=0.0) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new(); m.albedo_color=Color(albedo); m.roughness=rough; m.metallic=metallic
	return m

func _box(parent: Node,size: Vector3,pos: Vector3,mat: Material,rot_y: float=0.0) -> MeshInstance3D:
	var n:=MeshInstance3D.new(); var b:=BoxMesh.new(); b.size=size; n.mesh=b
	n.position=pos; n.rotation.y=rot_y; n.material_override=mat; parent.add_child(n)
	return n

func _cylinder(parent: Node,radius: float,height: float,pos: Vector3,mat: Material,rot: Vector3=Vector3.ZERO,segments: int=24) -> MeshInstance3D:
	var n:=MeshInstance3D.new(); var c:=CylinderMesh.new()
	c.top_radius=radius; c.bottom_radius=radius; c.height=height; c.radial_segments=segments; c.rings=2
	n.mesh=c; n.position=pos; n.rotation=rot; n.material_override=mat; parent.add_child(n)
	return n

func _sphere(parent: Node,radius: float,pos: Vector3,mat: Material,scale_v: Vector3=Vector3.ONE) -> MeshInstance3D:
	var n:=MeshInstance3D.new(); var s:=SphereMesh.new()
	s.radius=radius; s.height=radius*2.0; s.radial_segments=24; s.rings=16
	n.mesh=s; n.position=pos; n.scale=scale_v; n.material_override=mat; parent.add_child(n)
	return n

func _cylinder_between(a: Vector3,b: Vector3,radius: float,mat: Material) -> void:
	var d:=b-a; var mid:=(a+b)*0.5
	var n:=MeshInstance3D.new(); var c:=CylinderMesh.new()
	c.top_radius=radius; c.bottom_radius=radius; c.height=d.length(); c.radial_segments=16; c.rings=2; n.mesh=c
	n.position=mid
	n.quaternion=Quaternion(Vector3(0,1,0),d.normalized())
	n.material_override=mat; add_child(n)

func _build_table() -> void:
	# Five planks with slight tone shifts and thin gaps, like a salvaged workbench,
	# on four legs with a stretcher — the table must read as furniture, not a slab.
	var tones:=["2a1a0e","241609","2d1d10","201307","281a0c"]
	for i in range(5):
		var z:=-1.44+0.72*i
		_box(self,Vector3(7.0,0.14,0.68),Vector3(0,-0.07,z),_mat(tones[i],0.93))
	# End rails + legs + stretcher.
	for sx in [-3.3,3.3]:
		_box(self,Vector3(0.14,0.5,2.9),Vector3(sx,-0.32,-0.1),_mat("1d130b",0.9))
		for sz in [-1.35,1.15]:
			_box(self,Vector3(0.14,0.5,0.14),Vector3(sx,-0.32,sz),_mat("20150c",0.9))
	_box(self,Vector3(6.6,0.08,0.10),Vector3(0,-0.42,-1.35),_mat("1d130b",0.9))
	_box(self,Vector3(6.6,0.08,0.10),Vector3(0,-0.42,1.15),_mat("1d130b",0.9))

func _build_map() -> void:
	var map:=MeshInstance3D.new(); var pm:=PlaneMesh.new(); pm.size=Vector2(MAP_W,MAP_H)
	map.mesh=pm; map.position=Vector3(0,0.004,-0.1)
	var mm:=StandardMaterial3D.new(); mm.albedo_texture=_parchment_texture()
	mm.roughness=0.88; mm.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	map.material_override=mm; add_child(map)
	# Faint typed place names scattered across the paper.
	for spot in [["GREENVALE",-1.7,-0.72],["PINEWOOD",1.05,-0.85],["RIVERSIDE",0.0,-0.2],["MILLERTON",-1.05,0.42],["ASHFORD",2.3,0.5],["BLACKWOOD",2.65,-0.75],["FORT DIXON",-2.4,0.3]]:
		var lab:=Label3D.new(); lab.text=spot[0]; lab.pixel_size=0.0016
		lab.modulate=Color(0.29,0.23,0.15,0.55); lab.outline_size=0
		lab.rotation_degrees=Vector3(-90,0,0); lab.position=Vector3(spot[1],0.009,-0.1+spot[2])
		add_child(lab)
	# A small compass "N" in the corner of the paper.
	var north:=Label3D.new(); north.text="N"; north.pixel_size=0.0028
	north.modulate=Color(0.29,0.23,0.15,0.7); north.outline_size=0
	north.rotation_degrees=Vector3(-90,0,0); north.position=Vector3(2.45,0.009,0.78)
	add_child(north)

func _px(img: Image,px: int,py: int,col: Color) -> void:
	if px>=0 and py>=0 and px<img.get_width() and py<img.get_height():
		img.set_pixel(px,py,col)

func _hline(img: Image,a: Vector2,b: Vector2,col: Color,w: int) -> void:
	var steps:=int(a.distance_to(b)*700.0)+1
	for s in range(steps+1):
		var p: Vector2=a.lerp(b,float(s)/steps)
		var cx: int=int(p.x*img.get_width()); var cy: int=int(p.y*img.get_height())
		for dx in range(-w,w+1):
			for dy in range(-w,w+1):
				var cur: Color=img.get_pixel(clampi(cx+dx,0,img.get_width()-1),clampi(cy+dy,0,img.get_height()-1))
				_px(img,cx+dx,cy+dy,cur.lerp(col,0.55))

func _circle(img: Image,center: Vector2,rad: float,col: Color,fill: bool) -> void:
	var cx: int=int(center.x*img.get_width()); var cy: int=int(center.y*img.get_height())
	var r: int=int(rad*img.get_width())
	var r2: int=int(rad*img.get_height()*0.5)
	for dy in range(-r2,r2+1):
		for dx in range(-r,r+1):
			var d: float=Vector2(float(dx)/r,float(dy)/maxf(1.0,r2)).length()
			if fill and d<=1.0:
				_px(img,cx+dx,cy+dy,img.get_pixel(clampi(cx+dx,0,img.get_width()-1),clampi(cy+dy,0,img.get_height()-1)).lerp(col,0.4))
			elif not fill and absf(d-1.0)<0.08:
				_px(img,cx+dx,cy+dy,img.get_pixel(clampi(cx+dx,0,img.get_width()-1),clampi(cy+dy,0,img.get_height()-1)).lerp(col,0.5))

func _rect(img: Image,corner: Vector2,size: Vector2,col: Color,fill: bool) -> void:
	var cx: int=int(corner.x*img.get_width()); var cy: int=int(corner.y*img.get_height())
	var w: int=int(size.x*img.get_width()); var h: int=int(size.y*img.get_height())
	for dy in range(h):
		for dx in range(w):
			if fill or dx==0 or dy==0 or dx==w-1 or dy==h-1:
				_px(img,cx+dx,cy+dy,img.get_pixel(clampi(cx+dx,0,img.get_width()-1),clampi(cy+dy,0,img.get_height()-1)).lerp(col,0.45))

func _parchment_texture() -> ImageTexture:
	var W:=1024; var H:=512
	var img:=Image.create(W,H,false,Image.FORMAT_RGB8)
	var noise:=FastNoiseLite.new(); noise.seed=93; noise.frequency=1.0
	var grain:=FastNoiseLite.new(); grain.seed=41; grain.frequency=1.0
	# A few old stains.
	var stains:=[[0.22,0.30,0.10],[0.66,0.62,0.13],[0.82,0.22,0.07],[0.45,0.80,0.09],[0.10,0.72,0.06],[0.92,0.55,0.08]]
	for y in range(H):
		for x in range(W):
			var u:=float(x)/W; var v:=float(y)/H
			var blotch: float=noise.get_noise_2d(x*0.008,y*0.008)*0.5+0.5
			var g: float=grain.get_noise_2d(x*0.11,y*0.11)*0.5+0.5
			var c:=Color("c6b184").lerp(Color("8d7954"),blotch*0.55).lerp(Color("a08a60"),g*0.22)
			var edge:=minf(minf(u,1.0-u)*W/MAP_W,minf(v,1.0-v)*H/MAP_H)  # metres from the paper edge
			# burnt, darkened rim
			c=c.lerp(Color("5a4630"),clampf(1.0-edge/0.12,0.0,1.0)*0.75)
			for s in stains:
				var d: float=Vector2((u-s[0])*MAP_W,(v-s[1])*MAP_H).length()
				if d<s[2]: c=c.lerp(Color("7d6743"),(1.0-d/s[2])*0.5)
			img.set_pixel(x,y,c)
	# Faint survey grid.
	var grid:=Color("8a744e")
	for i in range(1,12):
		_hline(img,Vector2(float(i)/12.0,0.0),Vector2(float(i)/12.0,1.0),grid,1)
	for j in range(1,6):
		_hline(img,Vector2(0.0,float(j)/6.0),Vector2(1.0,float(j)/6.0),grid,1)
	# Meandering sepia roads.
	_road(img,[[0.05,0.62],[0.2,0.5],[0.36,0.56],[0.5,0.42],[0.66,0.47],[0.83,0.36],[0.97,0.4]],Color("6f5a3d"),2)
	_road(img,[[0.12,0.12],[0.25,0.24],[0.42,0.2],[0.55,0.3],[0.72,0.24],[0.9,0.3]],Color("6f5a3d"),2)
	_road(img,[[0.3,0.95],[0.4,0.78],[0.58,0.7],[0.7,0.78],[0.85,0.68]],Color("6f5a3d"),2)
	_road(img,[[0.06,0.30],[0.16,0.38],[0.24,0.34],[0.34,0.42]],Color("6f5a3d"),2)
	_road(img,[[0.62,0.06],[0.68,0.16],[0.8,0.14],[0.9,0.2]],Color("6f5a3d"),2)
	# A river winding down from the hills, wider and greener than the roads.
	_road(img,[[0.55,0.0],[0.6,0.14],[0.54,0.3],[0.62,0.46],[0.56,0.62],[0.64,0.8],[0.6,1.0]],Color("7d8a86"),4)
	# Coast: hatched shoreline along the bottom edge.
	for i in range(W):
		var u:=float(i)/W
		var y:=H-8-int(6.0*sin(u*9.0))
		_px(img,i,y,Color("5d6b60"))
		if i%14==0:
			_hline(img,Vector2(u,float(y)/H),Vector2(u,float(y+5)/H),Color("5d6b60"),1)
	# City blocks: stamped squares around the city node.
	for bx in range(5):
		for by in range(3):
			_rect(img,Vector2(0.30+bx*0.035,0.42+by*0.05),Vector2(0.022,0.032),Color("7a6748"),true)
	# Farm fields: ruled strips top-left.
	for f in range(5):
		_hline(img,Vector2(0.06,0.10+f*0.035),Vector2(0.20,0.10+f*0.035),Color("7a6748"),1)
	# Contour rings around two rises.
	_contours(img,Vector2(0.80,0.78),5)
	_contours(img,Vector2(0.16,0.16),4)
	# Compass rose top-right.
	_circle(img,Vector2(0.90,0.12),0.045,Color("6f5a3d"),false)
	_circle(img,Vector2(0.90,0.12),0.010,Color("6f5a3d"),true)
	_hline(img,Vector2(0.90,0.075),Vector2(0.90,0.165),Color("6f5a3d"),1)
	_hline(img,Vector2(0.855,0.12),Vector2(0.945,0.12),Color("6f5a3d"),1)
	# Fold creases.
	for fx in [0.25,0.5,0.75]:
		_hline(img,Vector2(fx,0.0),Vector2(fx,1.0),Color("6e5a3c"),1)
	_hline(img,Vector2(0.0,0.52),Vector2(1.0,0.52),Color("6e5a3c"),1)
	# X marks the spots.
	_xmark(img,Vector2(0.36,0.50))
	_xmark(img,Vector2(0.72,0.30))
	_xmark(img,Vector2(0.50,0.84))
	# A few crossed-out supply ticks near the coast.
	for t in range(4):
		_hline(img,Vector2(0.10+t*0.04,0.88),Vector2(0.10+t*0.04+0.02,0.93),Color("7c2a1c"),1)
	return ImageTexture.create_from_image(img)

func _contours(img: Image,center: Vector2,rings: int) -> void:
	for r in range(1,rings+1):
		var rad: int=r*14
		var col:=Color("8a744e")
		for deg in range(360):
			var a: float=deg*TAU/360.0
			var px: int=int(center.x*img.get_width()+cos(a)*rad)
			var py: int=int(center.y*img.get_height()+sin(a)*rad*0.5)
			_px(img,px,py,img.get_pixel(clampi(px,0,img.get_width()-1),clampi(py,0,img.get_height()-1)).lerp(col,0.35))

func _xmark(img: Image,center: Vector2) -> void:
	var col:=Color("7c2a1c")
	var cx: int=int(center.x*img.get_width()); var cy: int=int(center.y*img.get_height())
	for d in range(-6,7):
		for s in [[d,d],[d,-d]]:
			_px(img,cx+int(s[0]),cy+int(s[1]),col)

func _road(img: Image,pts: Array,col: Color,w: int) -> void:
	for i in range(pts.size()-1):
		var a:=Vector2(pts[i][0],pts[i][1]); var b:=Vector2(pts[i+1][0],pts[i+1][1])
		_hline(img,a,b,col,w)

func _build_route() -> void:
	# Red string pinned from the city across the map toward the locked districts.
	var pts:=[Vector2(-2.0,-0.3),Vector2(-0.75,0.25),Vector2(0.45,-0.35),Vector2(1.5,0.2),Vector2(2.5,-0.3)]
	var string_mat:=_mat("7c1f16",0.7)
	var pin_mat:=_mat("3a3a3d",0.35,0.85)
	for i in range(pts.size()-1):
		var a:=Vector3(pts[i].x,0.007,-0.1+pts[i].y)
		var b:=Vector3(pts[i+1].x,0.007,-0.1+pts[i+1].y)
		# A slight sag: two segments per span with the middle dropped a hair.
		var mid:=(a+b)*0.5+Vector3(0,-0.0015,0)
		_cylinder_between(a,mid,0.004,string_mat)
		_cylinder_between(mid,b,0.004,string_mat)
	for p in pts:
		_sphere(self,0.016,Vector3(p.x,0.014,-0.1+p.y),pin_mat)

## ---- photos --------------------------------------------------------------------------------

func _build_photos() -> void:
	# id, x, z (table space; the map's centre is z=-0.1), rotation, open
	var defs:=[
		["city",-2.15,-0.85,0.10,true],
		["farm",-0.6,0.6,-0.08,false],
		["coast",0.55,-0.8,0.10,false],
		["winter",1.6,0.55,-0.12,false],
		["graveyard",2.6,-0.7,0.08,false],
	]
	for d in defs:
		_photo(d[0],d[1],d[2],d[3],d[4])
	# The open destination gets a soft pulsing brass frame so players know photos are tappable.
	var city: Dictionary=photos[0]
	city_frame_mat=StandardMaterial3D.new(); city_frame_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	city_frame_mat.albedo_color=Color(1.0,0.72,0.25,0.55); city_frame_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var frame:=Node3D.new(); frame.position=city.node.position+Vector3(0,0.008,0)
	var hw:=0.21; var hh:=0.25
	for seg in [[Vector3(0,0,-hh),Vector3(hw*2,0.008,0.02)],[Vector3(0,0,hh),Vector3(hw*2,0.008,0.02)],[Vector3(-hw,0,0),Vector3(0.02,0.008,hh*2)],[Vector3(hw,0,0),Vector3(0.02,0.008,hh*2)]]:
		_box(frame,seg[1],seg[0],city_frame_mat)
	add_child(frame)

func _photo(id: String,x: float,z: float,rot: float,open: bool) -> void:
	var card:=Node3D.new(); card.position=Vector3(x,0.008,z); card.rotation.y=rot
	add_child(card)
	_box(card,Vector3(0.36,0.008,0.44),Vector3(0,0,0),_mat("d8d0bc",0.82))   # polaroid border
	var pic:=MeshInstance3D.new(); var pq:=PlaneMesh.new(); pq.size=Vector2(0.30,0.30)
	pic.mesh=pq; pic.position=Vector3(0,0.006,-0.04)
	var pm:=StandardMaterial3D.new(); pm.albedo_texture=_photo_texture(id,open); pm.roughness=0.55
	pic.material_override=pm; card.add_child(pic)
	# Caption on the bottom band, like marker on the white border; small enough to stay inside it.
	var cap:=Label3D.new(); cap.text="THE BLOCKS" if open else id.to_upper()
	cap.pixel_size=0.0022; cap.modulate=Color(0.16,0.13,0.10,0.9); cap.outline_size=0
	cap.rotation_degrees=Vector3(-90,0,0); cap.position=Vector3(0,0.007,0.155)
	card.add_child(cap)
	# The pin holding it down.
	_sphere(card,0.016,Vector3(0,0.016,-0.19),_mat("8e2a1e" if open else "3a3a3d",0.4,0.6))
	if not open:
		# A small padlock: shackle ring plus the body.
		var body:=MeshInstance3D.new(); var bb:=BoxMesh.new(); bb.size=Vector3(0.062,0.012,0.07)
		body.mesh=bb; body.position=Vector3(0,0.012,-0.01); body.material_override=_mat("9aa0a4",0.35,0.9)
		card.add_child(body)
		var shackle:=MeshInstance3D.new(); var tm:=TorusMesh.new(); tm.inner_radius=0.02; tm.outer_radius=0.034
		shackle.mesh=tm; shackle.position=Vector3(0,0.014,-0.052)
		shackle.material_override=_mat("8a9094",0.3,0.9); card.add_child(shackle)
	photos.append({"id":id,"node":card,"open":open})

func _photo_texture(id: String,open: bool) -> ImageTexture:
	# A tiny murky snapshot per district: gradient sky plus a dark silhouette skyline.
	var W:=128; var H:=128
	var img:=Image.create(W,H,false,Image.FORMAT_RGB8)
	var pal:={
		"city":["5d6b78","1c232b"], "farm":["4d4433","1a150c"], "coast":["5c6a70","222a2e"],
		"winter":["7d8a99","2a3038"], "graveyard":["4a4c48","191a17"],
	}
	var p: Array=pal.get(id,pal["farm"])
	for y in range(H):
		var c:=Color(p[0]).lerp(Color(p[1]),float(y)/H)
		for x in range(W): img.set_pixel(x,y,c)
	var rng:=RandomNumberGenerator.new(); rng.seed=hash(id)
	match id:
		"city":
			for i in range(9):
				var bw:=rng.randi_range(10,20); var bh:=rng.randi_range(30,76); var bx:=i*14
				img.fill_rect(Rect2i(bx,H-bh,bw,bh),Color("232c34"))
				for wy in range(3):   # a few windows still lit
					if rng.randf()<0.6:
						img.fill_rect(Rect2i(bx+rng.randi_range(1,maxi(1,bw-3)),H-rng.randi_range(8,bh-2),3,3),Color("c9a45c"))
			img.fill_rect(Rect2i(0,H-8,W,8),Color("11161b"))
		"farm":
			img.fill_rect(Rect2i(24,H-52,44,38),Color("0d0a07"))
			img.fill_rect(Rect2i(20,H-58,52,8),Color("080604"))
			img.fill_rect(Rect2i(82,H-66,13,52),Color("0b0906"))
			for f in range(4):
				img.fill_rect(Rect2i(8,H-16+f*6,112,2),Color("2a2416"))
		"coast":
			img.fill_rect(Rect2i(0,H-42,W,42),Color("2b3a40"))   # the sea along the bottom
			img.fill_rect(Rect2i(0,H-44,W,3),Color("151d21"))
			for i in range(4):   # pier posts wading into the water
				var bx:=14+i*26
				img.fill_rect(Rect2i(bx,H-70,6,32),Color("0d1113"))
			img.fill_rect(Rect2i(10,H-74,106,6),Color("0d1113"))
			for s in range(10):
				img.fill_rect(Rect2i(rng.randi_range(0,W-6),H-rng.randi_range(4,36),5,1),Color("4d5f66"))
		"winter":
			img.fill_rect(Rect2i(0,H-24,W,24),Color("6e7680"))   # snow field
			for i in range(8):   # dark pines against the white
				var bx:=8+i*16; var bh:=rng.randi_range(32,58)
				for k in range(bh):
					var wdt:=int(10.0*(1.0-float(k)/bh))+1
					img.fill_rect(Rect2i(bx-wdt/2,H-24-k,wdt,1),Color("10161a"))
			img.fill_rect(Rect2i(0,6,W,2),Color("dfe6ec"))
		"graveyard":
			for i in range(6):   # headstones
				var bx:=12+i*19
				img.fill_rect(Rect2i(bx,H-42,11,24),Color("0d0e0c"))
				img.fill_rect(Rect2i(bx+1,H-45,9,3),Color("0d0e0c"))
			img.fill_rect(Rect2i(58,H-70,5,30),Color("0a0b09"))  # a crooked cross
			img.fill_rect(Rect2i(50,H-64,20,4),Color("0a0b09"))
			img.fill_rect(Rect2i(0,H-10,W,10),Color("23251f"))
		_:
			img.fill_rect(Rect2i(0,H-28,W,28),Color("0b0d0f"))
			img.fill_rect(Rect2i(34,H-66,10,66),Color("080a0c"))
			img.fill_rect(Rect2i(80,H-56,10,56),Color("080a0c"))
	if not open:
		for y in range(H):   # locked districts sit deeper in the dark
			for x in range(W): img.set_pixel(x,y,img.get_pixel(x,y).darkened(0.15))
	return ImageTexture.create_from_image(img)

## ---- props -----------------------------------------------------------------------------------

func _build_lantern() -> void:
	var root:=Node3D.new(); root.position=Vector3(-2.78,0.004,-0.72); add_child(root)
	var metal:=_mat("3d3226",0.5,0.75)
	_cylinder(root,0.15,0.05,Vector3(0,0.025,0),metal)
	_sphere(root,0.13,Vector3(0,0.10,0),metal,Vector3(1,0.72,1))
	var glass:=MeshInstance3D.new(); var gc:=CylinderMesh.new()
	gc.top_radius=0.085; gc.bottom_radius=0.10; gc.height=0.16; gc.radial_segments=28; gc.rings=2
	glass.mesh=gc; glass.position=Vector3(0,0.22,0)
	var gm:=StandardMaterial3D.new(); gm.albedo_color=Color(1.0,0.8,0.5,0.22); gm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness=0.1; gm.shading_mode=BaseMaterial3D.SHADING_MODE_PER_PIXEL
	glass.material_override=gm; root.add_child(glass)
	_sphere(root,0.028,Vector3(0,0.19,0),_mat("ffd98a",0.4))
	var flame:=root.get_child(root.get_child_count()-1) as MeshInstance3D
	var fm:=StandardMaterial3D.new(); fm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color=Color("ffd98a"); fm.emission_enabled=true; fm.emission=Color("ffb45c"); fm.emission_energy_multiplier=3.0
	flame.material_override=fm
	_cylinder(root,0.05,0.09,Vector3(0,0.345,0),metal)
	root.get_child(root.get_child_count()-1).mesh.top_radius=0.05
	var chim:=MeshInstance3D.new(); var chc:=CylinderMesh.new()
	chc.top_radius=0.028; chc.bottom_radius=0.045; chc.height=0.08; chc.radial_segments=20
	chim.mesh=chc; chim.position=Vector3(0,0.42,0); chim.material_override=metal; root.add_child(chim)
	# Wire guards up the sides and the carry handle.
	for sx in [-1,1]:
		_cylinder_between(root.position+Vector3(0.11*sx,0.06,0),root.position+Vector3(0.07*sx,0.4,0),0.006,metal)
	var handle:=MeshInstance3D.new(); var ht:=TorusMesh.new(); ht.inner_radius=0.10; ht.outer_radius=0.115
	handle.mesh=ht; handle.position=Vector3(0,0.42,0); handle.rotation_degrees=Vector3(0,0,90)
	handle.scale=Vector3(1,1,1.35); handle.material_override=metal; root.add_child(handle)
	lantern_light=OmniLight3D.new()
	lantern_light.position=root.position+Vector3(0,0.30,0)
	lantern_light.light_color=Color("ffb45c"); lantern_light.light_energy=0.55
	lantern_light.omni_range=4.0; lantern_light.omni_attenuation=1.5; lantern_light.shadow_enabled=false
	add_child(lantern_light)

func _build_knife() -> void:
	var root:=Node3D.new(); root.position=Vector3(-3.45,0.002,0.55); root.rotation.y=0.5; add_child(root)
	var steel:=_mat("9ba1a6",0.28,0.95)
	_box(root,Vector3(0.46,0.008,0.075),Vector3(0,0,0),steel)                       # blade
	var tip:=_box(root,Vector3(0.12,0.008,0.075),Vector3(0.28,0,0),steel,0.0); tip.rotation.y=-0.5 # clipped point
	_box(root,Vector3(0.05,0.018,0.095),Vector3(-0.26,0,0),_mat("2a2018",0.8))       # guard
	_box(root,Vector3(0.22,0.024,0.06),Vector3(-0.42,0,0),_mat("1d1712",0.85))       # handle
	for rx in [-0.36,-0.46]:
		_cylinder(root,0.009,0.028,Vector3(rx,0,0),steel,Vector3.ZERO,16)

func _build_mug() -> void:
	var root:=Node3D.new(); root.position=Vector3(3.5,0.0,-0.6); add_child(root)
	var ceramic:=_mat("2e3436",0.55)
	var cup:=MeshInstance3D.new(); var cc:=CylinderMesh.new()
	cc.top_radius=0.10; cc.bottom_radius=0.085; cc.height=0.17; cc.radial_segments=28; cc.rings=2
	cup.mesh=cc; cup.position=Vector3(0,0.085,0); cup.material_override=ceramic; root.add_child(cup)
	_cylinder(root,0.088,0.006,Vector3(0,0.165,0),_mat("140c06",0.25),Vector3.ZERO,28)
	var ear:=MeshInstance3D.new(); var et:=TorusMesh.new(); et.inner_radius=0.045; et.outer_radius=0.062
	ear.mesh=et; ear.position=Vector3(0.11,0.09,0); ear.material_override=ceramic; root.add_child(ear)

## ---- runtime ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t+=delta
	# Kerosene flame: two slow wobbles plus a fast shiver.
	lantern_light.light_energy=0.55+0.10*sin(_t*7.3)+0.06*sin(_t*13.1)+0.035*sin(_t*29.0)
	if city_frame_mat:
		city_frame_mat.albedo_color.a=0.48+0.32*(0.5+0.5*sin(_t*2.4))

## A horizontal swipe pans the camera across the table (dx is screen pixels).
func pan(dx: float) -> void:
	pan_x=clampf(pan_x+dx*0.0030,PAN_MIN,PAN_MAX)

func camera_fov() -> float:
	return CAMERA_FOV

func camera_position() -> Vector3:
	# Dead overhead, the map lying square in front of the survivor; only a faint breathing sway.
	return to_global(Vector3(pan_x+0.04*sin(_t*0.31),4.6,0.05))

func camera_target() -> Vector3:
	return to_global(Vector3(pan_x,0,0.05))

## Returns the photo id under the tap, or "" when the tap missed every photo.
func pick_photo(cam: Camera3D,screen_pos: Vector2) -> String:
	for p in photos:
		var c:=cam.unproject_position(p.node.global_position+Vector3(0,0.01,0))
		var ex:=cam.unproject_position(p.node.global_position+Vector3(0.20,0,0))
		var ey:=cam.unproject_position(p.node.global_position+Vector3(0,0,0.24))
		var rx:=absf(ex.x-c.x)+18.0
		var ry:=absf(ey.y-c.y)+18.0
		if Rect2(c.x-rx,c.y-ry,rx*2,ry*2).has_point(screen_pos): return p.id
	return ""

func is_open(id: String) -> bool:
	for p in photos:
		if p.id==id: return p.open
	return false
