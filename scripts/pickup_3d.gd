extends Node3D
const RunText=preload("res://scripts/run_text.gd")

# Paths, not preloads. A preload of a .glb makes the very first import pass on a clean
# checkout fail ("Could not preload resource file"), which aborted the import queue and
# shipped iOS packages with no models at all. Load lazily, and survive a missing model.
const MODEL_PATHS := {
	"medkit": "res://assets/models/medkit.glb",
	"armor": "res://assets/models/armor.glb",
	"helmet": "res://assets/models/helmet.glb",
	"ammo": "res://assets/models/ammo_pickup.glb",
	"grenade": "res://assets/models/frag_grenade.glb",
	"flashbang": "res://assets/models/flashbang.glb",
	"launcher": "res://assets/models/weapons/launcher.glb",
	"fire_round": "res://assets/models/fire_round.glb",
	"coin": "res://assets/models/coin_stack.glb",
	"silver_coin": "res://assets/models/coin_stack.glb"
}
var _model_cache := {}

func _model(kind_id: String) -> PackedScene:
	if _model_cache.has(kind_id):
		return _model_cache[kind_id]
	var packed: PackedScene = load(MODEL_PATHS[kind_id]) as PackedScene
	if packed != null:
		_model_cache[kind_id] = packed
	return packed
# One coin mesh, two metals: gold stays gold, silver reuses the same pile tinted.
const GOLD_ALBEDO:=Color(1.0,0.80,0.32)
const SILVER_ALBEDO:=Color(0.52,0.58,0.66)
const DISPLAY_SCALES := {"medkit": 1.35, "armor": 0.55, "helmet": 0.33, "ammo": 1.25, "grenade": 2.0, "flashbang": 2.0, "launcher": 0.9, "fire_round": 2.4, "coin": 0.55, "silver_coin": 0.55}
const GROUND_OFFSETS := {"medkit": 0.0, "armor": -0.535, "helmet": 0.0, "ammo": 0.0, "grenade": 0.02, "flashbang": 0.02, "launcher": 0.12, "fire_round": 0.03, "coin": 0.0, "silver_coin": 0.0}
const LABELS := {"medkit": "MED", "armor": "ARMOR", "helmet": "HELMET", "ammo": "AMMO", "grenade": "FRAG", "flashbang": "FLASH", "launcher": "LAUNCHER", "fire_round": "INCENDIARY", "coin": "COINS", "silver_coin": "SILVER"}
const COLORS := {"medkit": Color("ff7668"), "armor": Color("72d9e5"), "helmet": Color("b6d38a"), "ammo": Color("ffd275"), "grenade": Color("b6d38a"), "flashbang": Color("bdefff"), "launcher": Color("ff9b55"), "fire_round": Color("ff6547"), "coin": Color("d6b265"), "silver_coin": Color("9ea8b4")}

var kind := "ammo"
var value := 1
var source_kind := ""
var visual: Node3D
var model_instance: Node3D
var time := 0.0
var base_yaw := 0.0
var scatter_elapsed := 0.0
var coin_pieces: Array[Dictionary]=[]
var coin_light: OmniLight3D

## Largest axis of the instantiated model, in its own space.
func _model_span(node: Node3D) -> float:
	var box := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var a: AABB = mi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	if first:
		return 0.0
	return maxf(box.size.x, maxf(box.size.y, box.size.z))


func _ready() -> void:
	visual = Node3D.new()
	add_child(visual)
	var packed:=_model(kind)
	model_instance = packed.instantiate() as Node3D if packed != null else null
	if model_instance == null:
		push_error("pickup model missing or broken: " + str(MODEL_PATHS.get(kind, "?")))
		model_instance = Node3D.new() # invisible placeholder: the run continues
	model_instance.scale = Vector3.ONE * float(DISPLAY_SCALES[kind])
	# The armour GLB is authored at ~120 m, so a fixed display scale made a 60 m vest spin over the
	# road. Normalise every pickup to its own footprint instead: at most half a metre across.
	var span := _model_span(model_instance)
	if span > 1.0:
		model_instance.scale *= 0.55 / span
	model_instance.position.y = float(GROUND_OFFSETS[kind])
	visual.add_child(model_instance)
	base_yaw = -0.35 if kind=="armor" else 0.12
	visual.rotation.y = base_yaw
	if kind in ["coin","silver_coin"]:
		_tint_coin_metal(SILVER_ALBEDO if kind=="silver_coin" else GOLD_ALBEDO)
		_prepare_coin_scatter()
	var _is_coin: bool = kind in ["coin","silver_coin"]
	# NO GLOW for coins in match (gold + silver): no OmniLight, no emission, no twinkle.
	if not _is_coin:
		var light:=OmniLight3D.new(); light.position=Vector3(0,0.58,0)
		light.light_color=COLORS[kind]; light.light_energy=0.38
		light.omni_range=1.55
		add_child(light)
	_label(LABELS[kind],COLORS[kind])

## Reuses the gold pile mesh for silver: retints every coin material in place.
## The skull relief keeps its shape — only metalness/roughness/tint change.
## NO GLOW (user request): emission OFF for both gold and silver coins in match.
func _tint_coin_metal(albedo: Color) -> void:
	for mi in model_instance.find_children("*","MeshInstance3D",true,false):
		var mesh_inst:=mi as MeshInstance3D
		if mesh_inst.mesh==null: continue
		var src: Material=mesh_inst.material_override
		if src==null: src=mesh_inst.mesh.surface_get_material(0)
		if not (src is StandardMaterial3D): continue
		var mat: StandardMaterial3D=(src as StandardMaterial3D).duplicate() as StandardMaterial3D
		mat.albedo_color=albedo
		mat.metallic=0.9
		mat.metallic_specular=1.0
		mat.roughness=0.48 if kind=="silver_coin" else 0.24
		mat.emission_enabled=false
		mat.emission=Color(0,0,0,1)
		mat.emission_energy_multiplier=0.0
		mesh_inst.material_override=mat

func _prepare_coin_scatter() -> void:
	if model_instance==null or not is_instance_valid(model_instance): return
	for node in model_instance.get_children():
		if not node is Node3D or not String(node.name).begins_with("CoinAssembly"): continue
		var piece:=node as Node3D
		coin_pieces.append({"node":piece,"position":piece.position,"rotation":piece.rotation})
		piece.position=Vector3(0,0.12,0); piece.rotation=Vector3(0,0,float(coin_pieces.size())*0.4)

func _label(text: String,color: Color) -> void:
	var label:=Label3D.new(); label.text=RunText.text("l_"+kind) if RunText.text("l_"+kind)!="l_"+kind else text
	var _is_coin:=kind in ["coin","silver_coin"]
	label.font=RunText.font(); label.font_size=32 if _is_coin else 42; label.pixel_size=0.0032 if _is_coin else 0.004
	label.modulate=color; label.outline_modulate=Color("101513"); label.outline_size=6 if _is_coin else 7
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.position=Vector3(0,0.34 if _is_coin else 0.82,0); add_child(label)

func tick(delta: float) -> void:
	time+=delta
	position.z+=3.5*delta
	if kind in ["coin","silver_coin"]:
		# NO GLOW: no twinkle / breathing light for coins (gold + silver).
		scatter_elapsed+=delta
		var t: float=clampf(scatter_elapsed/0.48,0.0,1.0); var spread: float=1.0-pow(1.0-t,3.0)
		for piece in coin_pieces:
			var node:=piece.node as Node3D; var final_position:=piece.position as Vector3; var final_rotation:=piece.rotation as Vector3
			node.position=final_position*spread+Vector3(0,0.22*(1.0-t)+sin(t*PI)*0.075,0)
			node.rotation=Vector3(final_rotation.x*spread,final_rotation.y*spread,lerp_angle(float(coin_pieces.find(piece)+1)*0.4,final_rotation.z,spread))
		visual.position.y=0.0
	else:
		visual.position.y=0.045+sin(time*3.0)*0.035
		visual.rotation.y=base_yaw+sin(time*1.2)*0.18
