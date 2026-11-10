extends Node3D
## Dogs run in formation around the survivor — front-left, front-right, left side, right
## side (road runs -Z) — and pounce on zombies in front of him. The legs are posed every
## frame by dog_gallop.gd (the baked Dog_Run clip hardly moves them); Dog_Bite plays for
## the bite. Scaled to real size. Duplicates of the same breed can fill different slots.

const LobbyScene=preload("res://scripts/lobby_scene_3d.gd")
const ModelFix=preload("res://scripts/model_fix.gd")
const DogGallop=preload("res://scripts/dog_gallop.gd")
## Bite damage climbs with the breed (doberman, shepherd, wolfdog, mastiff). Only the mastiff
## takes a fresh walker down in one bite, and no bite ever finishes a Juggernaut ("brute"):
## the dog wears it down and the survivor has to shoot it dead.
const BITE_DAMAGE_BY_BREED:=[16.0,26.0,40.0,72.0,1000000.0,1000000.0]  # 4 = white tiger, 5 = lion: one bite kills
static func bite_damage(breed_index: int) -> float:
	return BITE_DAMAGE_BY_BREED[clampi(breed_index,0,BITE_DAMAGE_BY_BREED.size()-1)]
const BITE_INTERVAL:=1.35
const FOLLOW_SPEED:=7.0
const ATTACK_SPEED:=9.5
const ACQUIRE_RANGE:=10.0
## The road runs -Z and scrolls toward the camera. Zombies the survivor has already run past
## (behind him, sliding off the bottom of the screen) are left alone.
const AHEAD_MARGIN:=0.3   # a new target must be at least this far in front of the survivor
const GIVE_UP_BEHIND:=0.6  # drop a target once it falls this far behind him
const GALLOP_RATE:=1.25
## Per-breed gait overrides; breeds not listed use the dog tuning.
const GAIT_OVERRIDES:={
	4: {"amp":0.92, "spine":1.10},   # white tiger: slightly gentler swing, springier spine
	5: {"amp":0.88, "spine":1.18},   # lion: same, a touch more spring (stride is speed-derived)
}  # stride speed matched to how fast the street scrolls past (Kimi's tuning)
## Barking: only now and then, so it never nags. Near the survivor the close bark plays (one or
## two barks cut from the clip); once the dog has run off after a zombie, the distant one.
# Lazy paths: preloading imported audio also aborts the first import pass on a clean checkout.
const BARK_NEAR_PATH:="res://assets/audio/dog_bark.mp3"
const BARK_FAR_PATH:="res://assets/audio/dog_bark_distant.mp3"
const BARK_SEGMENTS:=[[0.0,0.78],[0.0,1.36],[2.19,2.95],[3.36,3.92],[4.38,4.98]]  # seconds in BARK_NEAR
const BARK_GAP:=Vector2(10.0,18.0)
## The lion is a pet too, but it growls on its own slow clock.
const LION_BREED:=5
const LION_ROAR_PATH:="res://assets/audio/lion_roar.mp3"
const LION_GROWL_PATH:="res://assets/audio/lion_growl.mp3"
const LION_GAP:=Vector2(22.0,40.0)
## The tiger and the lion share one voice pool: any of the four clips may play.
const TIGER_BREED:=4
## ambience: roars and growls only
const BIG_CAT_SOUNDS:=["res://assets/audio/lion_roar.mp3","res://assets/audio/lion_growl.mp3","res://assets/audio/tiger_roar.mp3"]
## the attack clip fires on the bite itself, not on the ambience timer
const TIGER_ATTACK_PATH:="res://assets/audio/tiger_attack.mp3"
const BITE_VOICE_CHANCE:=0.35  # random wait between barks
const FAR_DISTANCE:=3.2  # further than this from the survivor counts as "far away"
## Formation slots around the survivor (the road runs -Z, so -Z is ahead): the two front
## slots first, then the two flanks. slot 0 = front-left, 1 = front-right, 2 = left side,
## 3 = right side. Position no longer depends on the breed, so duplicate breeds can stack.
const FORMATION_OFFSETS:=[Vector3(-1.1,0,-1.6),Vector3(1.1,0,-1.6),Vector3(-1.5,0,-0.2),Vector3(1.5,0,-0.2)]
static func follow_offset(slot_index: int) -> Vector3:
	return FORMATION_OFFSETS[clampi(slot_index,0,FORMATION_OFFSETS.size()-1)]

var game: Node
var model: Node3D
var target: Node3D
var cooldown:=0.35
var age:=0.0
var bite_time:=0.0
var breed:=0
var slot_index:=0
var base_y:=0.0
var gallop: RefCounted
var is_moving := false   # drives idle vs run clip selection
var yaw_offset := 0.0   # the model's own forward axis, per breed
var anim: AnimationPlayer
var bark_player: AudioStreamPlayer
var bark_wait:=0.0
var bark_stop:=0.0

func setup(index: int, slot:=0) -> void:
	breed=clampi(index,0,LobbyScene.PETS.size()-1)
	slot_index=clampi(slot,0,FORMATION_OFFSETS.size()-1)
	model=ModelFix.spawn(String(LobbyScene.PETS[breed].asset))
	if model==null: return
	add_child(model); ModelFix.double_sided(model)
	# Generated pet GLBs import with shadows off (or the shadow never lands on the road):
	# turn casting on for every surface so the animal has a shadow like the survivor does.
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m != null:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	yaw_offset=float(LobbyScene.PETS[breed].get("yaw",0.0))
	base_y=ModelFix.fit_pet(model,float(LobbyScene.PETS[breed].get("length",1.1)))
	model.position.y=base_y
	anim=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if anim: anim.stop()
	# find the skeleton by TYPE: generated rigs name it after the armature (TigerArm),
	# so the old name lookup silently skipped the gallop and the pet slid along.
	var skeleton:=model.find_child("Skeleton3D",true,false) as Skeleton3D
	if skeleton==null:
		for n in model.find_children("*","Skeleton3D",true,false):
			skeleton=n as Skeleton3D
			break
	if skeleton:
		# Big cats (white tiger 4, lion 5) get their own stride: longer legs, faster cadence,
		# slightly shorter reach so the paws do not over-swing, and a springier spine.
		gallop=DogGallop.new(skeleton,GAIT_OVERRIDES.get(breed,{}))
	bark_player=AudioStreamPlayer.new(); add_child(bark_player)
	bark_wait=randf_range(LION_GAP.x,LION_GAP.y) if breed==LION_BREED else randf_range(4.0,8.0)  # first bark a few seconds into the run

## Count down to the next bark and pick near/far by how far the dog is from the survivor.
func _tick_bark(delta: float) -> void:
	if bark_stop>0.0:
		bark_stop-=delta
		if bark_stop<=0.0: bark_player.stop()
	bark_wait-=delta
	if bark_wait>0.0 or bark_player.playing: return
	var is_lion:=breed==LION_BREED or breed==TIGER_BREED
	var gap:=LION_GAP if is_lion else BARK_GAP
	bark_wait=randf_range(gap.x,gap.y)
	if game==null or (game.get("sound")!=null and game.sound.muted): return
	var away:=Vector2(position.x-game.player.position.x,position.z-game.player.position.z).length()
	if away>FAR_DISTANCE:
		var far_path:=String(BIG_CAT_SOUNDS[randi()%BIG_CAT_SOUNDS.size()]) if is_lion else BARK_FAR_PATH
		var far:=load(far_path) as AudioStream
		if far==null: return
		bark_player.stream=far; bark_player.volume_db=-9.0; bark_player.pitch_scale=randf_range(0.95,1.05)
		bark_player.play(); bark_stop=0.0
	else:
		var seg: Array=BARK_SEGMENTS[randi()%BARK_SEGMENTS.size()]
		var near_path:=String(BIG_CAT_SOUNDS[randi()%BIG_CAT_SOUNDS.size()]) if is_lion else BARK_NEAR_PATH
		var near:=load(near_path) as AudioStream
		if near==null: return
		bark_player.stream=near; bark_player.volume_db=-9.0 if is_lion else -7.0; bark_player.pitch_scale=randf_range(0.94,1.06)
		bark_player.play(float(seg[0])); bark_stop=(float(seg[1])-float(seg[0]))/bark_player.pitch_scale

## Gallop (or finish a bite) without any chasing logic; used while the opening intro plays.
func run_beside(target_position: Vector3,delta: float) -> void:
	position=position.lerp(target_position,1.0-exp(-delta*4.0)); position.y=0.0
	rotation.y=lerp_angle(rotation.y,atan2(Vector3.FORWARD.x,Vector3.FORWARD.z),1.0-exp(-delta*12.0))
	_animate(delta)

## First animation name from `names` that this model actually has.
func _first_clip(player: AnimationPlayer, names: Array) -> String:
	for n in names:
		if player.has_animation(String(n)):
			return String(n)
	return ""


func _animate(delta: float) -> void:
	if bite_time>0.0:
		ModelFix.play_animation(model,"Dog_Bite",false)
		if gallop!=null and gallop.has_method("bite"): gallop.bite()
		# bite voice: occasional, and never layered over a roar that is still playing
		if (breed==TIGER_BREED or breed==LION_BREED) and not bark_player.playing and randf()<BITE_VOICE_CHANCE:
			var atk:=load(TIGER_ATTACK_PATH) as AudioStream
			if atk!=null:
				bark_player.stream=atk
				bark_player.volume_db=-8.0
				bark_player.pitch_scale=randf_range(0.96,1.06)
				bark_player.play()
		return
	# Every four legged pet runs on the rig's own run cycle: the baked clip reads as a real
	# gallop, the procedural version only wiggled the legs in place.
	if anim:
		var idle := _first_clip(anim, ["Dog_Idle", "Lion_Idle", "Tiger_Idle", "Idle", "idle"])
		var run := _first_clip(anim, ["Dog_Run", "Lion_Run", "Tiger_Run", "Run", "run"])
		var want := "" if is_moving else idle
		if want == "":
			want = run
		if want != "":
			if anim.current_animation != want or not anim.is_playing():
				anim.play(want, 0.15)
			anim.speed_scale = 1.0
			return
	if anim and anim.is_playing():
		anim.stop(); (gallop.sk as Skeleton3D).reset_bone_poses()
	if gallop:
		# Cadence follows the road: the planted paw must travel backwards exactly as fast as
		# the ground moves under the animal, so the rate is speed-driven instead of a constant.
		var spd:=3.5
		if game!=null and is_instance_valid(game.get("player")):
			spd=3.5*float(game.player.effective_move_mult())
		var want:float=gallop.stride_for_speed(spd)
		gallop.stride=want
		gallop.step(delta,1.0)

func _valid_target() -> bool:
	return is_instance_valid(target) and not target.dead and game.zombies.has(target) \
		and target.position.z<game.player.position.z+GIVE_UP_BEHIND

func _acquire_target() -> void:
	target=null
	var best:=ACQUIRE_RANGE
	for z in game.zombies:
		if not is_instance_valid(z) or z.dead: continue
		# Protect the immediate running lane, prioritising zombies close to the survivor.
		if z.position.z>game.player.position.z-AHEAD_MARGIN: continue  # passed already: ignore
		var d: float=z.position.distance_to(game.player.position)
		if d<best:
			best=d; target=z

func tick(delta: float) -> void:
	if not is_instance_valid(model): return
	age+=delta; cooldown=maxf(0.0,cooldown-delta); bite_time=maxf(0.0,bite_time-delta)
	if not _valid_target(): _acquire_target()
	var follow: Vector3=game.player.position+follow_offset(slot_index)
	var desired: Vector3=follow
	var attacking: bool=false
	if _valid_target():
		desired=target.position
		attacking=true
	var flat_delta: Vector3=desired-position; flat_delta.y=0
	var distance: float=flat_delta.length()
	var bite_range: float=0.72+(float(target.radius) if attacking else 0.0)
	if attacking and distance<=bite_range:
		is_moving = false
		if cooldown<=0.0:
			cooldown=BITE_INTERVAL; bite_time=0.28
			var hit_at: Vector3=target.global_position+Vector3(0,0.82 if target.kind!="brute" else 1.35,0)
			var dmg: float=bite_damage(breed)
			if target.kind=="brute": dmg=minf(dmg,maxf(0.0,float(target.health)-1.0))
			if dmg>0.0: game._hit_zombie(target,dmg,"torso",hit_at)
			if game.has_method("_progress"): game._progress("bites",1)
			target=null
	else:
		var speed: float=ATTACK_SPEED if attacking else FOLLOW_SPEED
		# Catch up smoothly after a lunge without overtaking the survivor when no target exists.
		is_moving = distance > 0.12
		position+=flat_delta.normalized()*minf(distance,speed*delta)
		position.x=clampf(position.x,-3.25,3.25)
		position.y=0.0
	# Facing: turn toward the target when attacking or when catching up from behind
	# (recruited far ahead/behind on the road). Otherwise nose down the road.
	var facing: Vector3
	if flat_delta.length()>0.05 and (attacking or distance>2.0):
		facing=flat_delta
	else:
		facing=Vector3.FORWARD
	var yaw: float=atan2(facing.x,facing.z)
	rotation.y=lerp_angle(rotation.y,yaw,1.0-exp(-delta*12.0))
	model.position.y=base_y
	# The run is always moving forward, so the dog gallops except during a bite.
	_animate(delta)
	_tick_bark(delta)
