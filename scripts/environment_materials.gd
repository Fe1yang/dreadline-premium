extends RefCounted

const ROOT:="res://assets/textures/polyhaven/"
const ASSETS:={"asphalt":"asphalt_01","brick":"red_brick_plaster_patch_02","concrete":"concrete_wall_neutral","plaster":"plastered_wall","pavement":"concrete_pavement"}
# Building colours are authored independently per building in build_city_districts.py.
# Only PBR road/pavement materials need runtime texture and filtering upgrades; the
# imported realwall_* colours must pass through untouched instead of entering a palette loop.
const GLASS_KEYS:=["glass","glass_dark","shop_glass","office_glass","station_glass"]
const TRIM_KEYS:=["frame","office_frame","trim","blind","recess","modern_panel","storefront","station_frame","station_roof"]
static var cache: Dictionary={}

static func apply(root: Node,_variant: int=0) -> void:
	# A model that failed to load hands us a null root. Walking it used to be an
	# instant segfault on iOS: crash 92E6252A was Node::get_children on a null object.
	if root==null or not is_instance_valid(root): return
	if root is MeshInstance3D and is_instance_valid(root.mesh):
		for surface in range(root.mesh.get_surface_count()):
			var source: Material=root.get_surface_override_material(surface)
			if source==null: source=root.mesh.surface_get_material(surface)
			if source==null: continue
			var base_key:=source.resource_name.split(".",true,1)[0]
			if base_key in GLASS_KEYS or base_key in TRIM_KEYS:
				var key: String="matte:"+base_key
				if not cache.has(key): cache[key]=_matte_architecture(source as StandardMaterial3D,base_key)
				root.set_surface_override_material(surface,cache[key])
			elif base_key.begins_with("PBR_"):
				if not cache.has(base_key): cache[base_key]=_make_material(base_key)
				root.set_surface_override_material(surface,cache[base_key])
	for child in root.get_children(): apply(child,_variant)

static func _matte_architecture(source: StandardMaterial3D,key: String) -> StandardMaterial3D:
	var m:=source.duplicate() as StandardMaterial3D
	m.resource_name=key+"_MATTE"; m.metallic_specular=0.12
	if key in GLASS_KEYS:
		# Dark architectural glazing, not a field of tiny sun/moon mirror highlights.
		m.roughness=0.68; m.metallic=0.02
	else:
		m.roughness=maxf(0.72,m.roughness); m.metallic=minf(0.16,m.metallic)
	return m

static func _texture(asset: String,map: String) -> Texture2D:
	var path:=ROOT+asset+"/"+asset+"_"+map+"_2k.jpg"
	return load(path) if ResourceLoader.exists(path) else null

static func _make_material(key: String) -> StandardMaterial3D:
	var asset: String=ASSETS.get(key.trim_prefix("PBR_"),key.trim_prefix("PBR_"))
	var m:=StandardMaterial3D.new(); m.resource_name=key+"_LIVE"
	# Roads and pavements retain their detailed PBR maps and stable mipmapped filtering.
	m.albedo_texture=_texture(asset,"diff"); m.roughness=0.96; m.metallic_specular=0.12
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.normal_enabled=true; m.normal_texture=_texture(asset,"nor_gl"); m.normal_scale=0.20
	var rough:=_texture(asset,"rough")
	if rough!=null: m.roughness_texture=rough
	var ao:=_texture(asset,"ao")
	if ao!=null:
		m.ao_enabled=true; m.ao_texture=ao; m.ao_light_affect=0.35
	if asset=="concrete_pavement":
		var arm:=_texture(asset,"arm")
		m.roughness_texture=arm; m.roughness_texture_channel=1
		m.ao_enabled=true; m.ao_texture=arm; m.ao_texture_channel=0; m.ao_light_affect=0.3
	return m
