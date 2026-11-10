extends Node3D
## The opening pursuer: an original high-detail muscular abomination, not the old
## Juggernaut or BossSculpt. Its fitted skeleton and custom heavy run are embedded
## together so runtime retargeting cannot tear the skin.

const MODEL_PATH:="res://assets/models/actors/pursuer_abomination.glb"
const SCALE:=1.95
const ModelFix=preload("res://scripts/model_fix.gd")

var model: Node3D
var anim: AnimationPlayer
var stomp_time:=0.0

func _ready() -> void:
	var pursuer: Resource=load(MODEL_PATH)
	if pursuer==null:
		push_error("pursuer model missing: "+MODEL_PATH)
		return
	model=pursuer.instantiate() as Node3D
	if model==null:
		push_error("pursuer scene failed to instantiate")
		return
	model.scale=Vector3.ONE*SCALE
	model.rotation.y=PI # faces -Z, down the road after the survivor
	add_child(model)
	ModelFix.double_sided(model) # no white see-through specks on the skin
	# Matte out the abomination: lightened skin + close rim stay, but roughness high so
	# the sun / rim / fill never turns wet-leather highlights. Keep metallic / specular low.
	for m in model.find_children("*","MeshInstance3D",true,false):
		var mi:=m as MeshInstance3D
		var src: Material=mi.material_override
		if src==null and mi.mesh: src=mi.mesh.surface_get_material(0)
		if src is StandardMaterial3D:
			var bright: StandardMaterial3D=(src as StandardMaterial3D).duplicate() as StandardMaterial3D
			bright.albedo_color=bright.albedo_color.lightened(0.30)
			bright.roughness=clampf(maxf(bright.roughness,0.92),0.92,1.0)
			bright.metallic=0.0
			bright.metallic_specular=0.15
			bright.specular_mode=BaseMaterial3D.SPECULAR_SCHLICK_GGX
			mi.material_override=bright
	var glow:=OmniLight3D.new()
	glow.light_color=Color("ffe0b8"); glow.light_energy=0.35; glow.omni_range=6.0; glow.omni_attenuation=1.1
	glow.position=Vector3(0,2.2,-1.5); add_child(glow)
	# The GLB may park its clips on a nested player, and the clip name is not guaranteed to
	# survive every re-export: take the first player that actually has animation data and
	# play its first clip, preferring the named run loop when present.
	for ap in model.find_children("*","AnimationPlayer",true,false):
		var player:=ap as AnimationPlayer
		if player==null: continue
		var list:=player.get_animation_list()
		if list.is_empty(): continue
		anim=player
		break
	if is_instance_valid(anim):
		var clip_name:="Pursuer_Run"
		if not anim.has_animation(clip_name): clip_name=String(anim.get_animation_list()[0])
		var clip:=anim.get_animation(clip_name)
		clip.loop_mode=Animation.LOOP_LINEAR
		anim.speed_scale=0.90 # slowed for the opening: heavy stride, no ice-skate slide
		anim.play(clip_name)
		# The clip's first frames have the arms up (looks like it surrenders); start mid-stride
		# instead so the beast charges with its arms down.
		anim.seek(0.62, true)
	else:
		push_error("Pursuer custom run animation is missing")
	for m in model.find_children("*","MeshInstance3D",true,false):
		(m as MeshInstance3D).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Use the game's voice pool so the supplied roar follows the existing mute setting.
	# BossChaser is created for both the opening pursuit and mid-run ambushes.
	var sound=get_parent().get("sound")
	if is_instance_valid(sound): sound.play("pursuer_roar")

func height() -> float:
	return 1.84*SCALE
