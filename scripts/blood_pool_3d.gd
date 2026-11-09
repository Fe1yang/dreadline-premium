extends MeshInstance3D
## A blood pool left on the road where a zombie dies (smaller splats on hits). It spreads out
## quickly, rides along with the scrolling road, then dries and fades away after a while.

const VARIANTS := 4
const SPLASH_VARIANTS := 8
const SPREAD_TIME := 0.45
static var textures: Array[Texture2D] = []
static var splash_textures: Array[Texture2D] = []

var age := 0.0
var lifetime := 9.0
var full_scale := 1.0
var mat: StandardMaterial3D

static func _make_texture(seed_value: int) -> Texture2D:
	var size := 128
	var img := Image.create(size,size,false,Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new(); noise.seed = seed_value; noise.frequency = 0.045
	noise.fractal_octaves = 4
	var drops := []
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	for i in range(9):
		var a := rng.randf()*TAU; var d := rng.randf_range(0.42,0.78)
		drops.append([Vector2(cos(a),sin(a))*d,rng.randf_range(0.035,0.09)])
	for y in range(size):
		for x in range(size):
			var p := Vector2(x,y)/float(size)*2.0-Vector2.ONE
			var r := p.length()
			# Main pool: lumpy edge from noise; satellite drops thrown around it.
			var edge := 0.60+noise.get_noise_2d(x,y)*0.30
			var v := clampf((edge-r)*9.0,0.0,1.0)
			for dr in drops:
				var dd: float = p.distance_to(dr[0])
				v = maxf(v,clampf((dr[1]-dd)*40.0,0.0,1.0))
			if v <= 0.0: continue
			# Darker, thicker centre; brighter thin rim.
			var depth := clampf(1.0-r*1.2,0.0,1.0)
			var col := Color("7a0d10").lerp(Color("3a0306"),depth)
			col.a = v*(0.88+0.12*depth)
			img.set_pixel(x,y,col)
	return ImageTexture.create_from_image(img)

## Directional splatter: an off-centre blob with tapered streaks and flung droplets thrown
## toward +U (the texture's x axis), the way blood sprays away from a bullet impact.
static func _make_splash(seed_value: int) -> Texture2D:
	var size := 160
	var img := Image.create(size,size,false,Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var noise := FastNoiseLite.new(); noise.seed = seed_value; noise.frequency = 0.06; noise.fractal_octaves = 3
	var blob_c := Vector2(rng.randf_range(-0.45,-0.25),rng.randf_range(-0.08,0.08))
	var blob_r := rng.randf_range(0.20,0.30)
	var streaks := []
	for i in range(rng.randi_range(5,9)):
		var ang := rng.randf_range(-0.85,0.85)
		var length := rng.randf_range(0.35,0.95)
		streaks.append([ang,length,rng.randf_range(0.022,0.06)])
	var drops := []
	for i in range(rng.randi_range(14,26)):
		var ang := rng.randf_range(-1.1,1.1); var d := rng.randf_range(0.25,0.95)
		drops.append([blob_c+Vector2(cos(ang),sin(ang))*d,rng.randf_range(0.008,0.035)])
	for y in range(size):
		for x in range(size):
			var p := Vector2(x,y)/float(size)*2.0-Vector2.ONE
			# Main blob with a lumpy edge.
			var edge := blob_r*(1.0+noise.get_noise_2d(x,y)*0.55)
			var v := clampf((edge-p.distance_to(blob_c))*30.0,0.0,1.0)
			# Streaks: capsules from the blob outward, tapering to a point, ending in a bead.
			var rel := p-blob_c
			for st in streaks:
				var dir := Vector2(cos(st[0]),sin(st[0]))
				var along := rel.dot(dir)
				if along < 0.0 or along > st[1]+0.05: continue
				var across := absf(rel.dot(Vector2(-dir.y,dir.x)))
				var t: float = clampf(along/st[1],0.0,1.0)
				var width: float = st[2]*(1.0-t*0.85)
				v = maxf(v,clampf((width-across)*160.0,0.0,1.0))
				var bead: Vector2 = blob_c+dir*float(st[1])
				v = maxf(v,clampf((st[2]*0.75-p.distance_to(bead))*120.0,0.0,1.0))
			for dr in drops:
				v = maxf(v,clampf((dr[1]-p.distance_to(dr[0]))*160.0,0.0,1.0))
			if v <= 0.0: continue
			var depth := clampf(1.0-p.distance_to(blob_c)/maxf(blob_r,0.01),0.0,1.0)
			var col := Color("8a1014").lerp(Color("3d0407"),depth)
			col.a = v*(0.86+0.12*depth)
			img.set_pixel(x,y,col)
	return ImageTexture.create_from_image(img)

static func _splash(index: int) -> Texture2D:
	if splash_textures.is_empty():
		for i in range(SPLASH_VARIANTS): splash_textures.append(_make_splash(5300+i*61))
	return splash_textures[index%SPLASH_VARIANTS]

static func _texture(index: int) -> Texture2D:
	if textures.is_empty():
		for i in range(VARIANTS): textures.append(_make_texture(9100+i*37))
	return textures[index%VARIANTS]

## The mesh and the material are built once (main_3d pools these pools), every later
## use only swaps the decal texture, so a kill no longer allocates a material.
func setup(size_m: float,variant: int,life: float,splash:=false) -> void:
	full_scale = size_m
	lifetime = life
	age = 0.0
	visible = true
	if mesh == null:
		var plane := PlaneMesh.new(); plane.size = Vector2.ONE
		mesh = plane
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.18   # wet sheen
		mat.metallic_specular = 0.7
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.render_priority = -1
		material_override = mat
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mat.albedo_texture = _splash(variant) if splash else _texture(variant)
	mat.albedo_color = Color(1,1,1,1)
	scale = Vector3.ONE*0.05

func disarm() -> void:
	visible = false
	age = lifetime

func tick(delta: float) -> bool:
	age += delta
	position.z += 3.5*delta
	var spread := clampf(age/SPREAD_TIME,0.0,1.0)
	spread = 1.0-pow(1.0-spread,3.0)
	scale = Vector3.ONE*maxf(0.05,full_scale*spread)
	# Dries darker, then fades out over the last 2.5 s.
	var fade := clampf((lifetime-age)/2.5,0.0,1.0)
	mat.albedo_color = Color(1,1,1,fade).lerp(Color(0.75,0.7,0.7,fade),clampf(age/lifetime,0.0,1.0))
	mat.roughness = lerpf(0.18,0.75,clampf(age/lifetime,0.0,1.0))
	return age >= lifetime or position.z > 14.0
