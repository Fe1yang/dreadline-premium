extends Node3D
## Pets run in formation around the survivor (front-left, front-right, left side, right side;
## the road runs -Z) and pounce on zombies in front of him.
##
## Facing and animation rules, so nobody has to guess again:
##  * Every pet GLB shares the Labrador pack skeleton and its hand-made clips (Idle, Walk, Trot,
##    Gallop, Bite, Bite_Up, Attack, Bark), and every GLB is authored nose-along-+Z.
##  * `model` is turned half a circle once in setup(), so this node's own -Z is the nose.
##    rotation.y is therefore the heading: 0 runs down the road, +left / -right.
##  * Nothing measures bones at runtime and nothing rewrites animation tracks.

const LobbyScene=preload("res://scripts/lobby_scene_3d.gd")
const ModelFix=preload("res://scripts/model_fix.gd")
## Bite damage by index into LobbyScene.PETS: doberman 16, shepherd 26, wolfdog 40, mastiff 72,
## labrador 33 (between the shepherd and the wolfdog), white tiger and lion kill in one bite.
## Only the mastiff of the dogs takes a fresh walker down in one bite, and no bite ever finishes
## a Juggernaut ("brute"): the pet wears it down and the survivor has to shoot it dead.
const BITE_DAMAGE_BY_BREED:=[16.0,26.0,40.0,72.0,33.0,1000000.0,1000000.0]
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

## All pet models are authored nose-along-+Z; the game runs toward -Z.
const MODEL_YAW:=PI
## The pack's Gallop covers 4.14 m/s on the Labrador at its authored size (1.94 units long).
const GALLOP_CLIP_SPEED:=4.14
const RUN_CLIP:="Gallop"
const IDLE_CLIP:="Idle"
const BITE_CLIPS:=["Bite","Attack"]
const BITE_ANIM_TIME:=0.46   # how long the bite clip owns the body
const BITE_ANIM_RATE:=2.6    # the clip is 1.46 s; the snap has to land inside the window
const LOOPING:=["Idle","Walk","Trot","Gallop"]

## Barking: only now and then, so it never nags. Near the survivor the close bark plays (one or
## two barks cut from the clip); once the dog has run off after a zombie, the distant one.
# Lazy paths: preloading imported audio also aborts the first import pass on a clean checkout.
const BARK_NEAR_PATH:="res://assets/audio/dog_bark.mp3"
const BARK_FAR_PATH:="res://assets/audio/dog_bark_distant.mp3"
const BARK_SEGMENTS:=[[0.0,0.78],[0.0,1.36],[2.19,2.95],[3.36,3.92],[4.38,4.98]]  # seconds in BARK_NEAR
const BARK_GAP:=Vector2(10.0,18.0)
## The lion is a pet too, but it growls on its own slow clock.
const LION_BREED:=6
const LION_GAP:=Vector2(22.0,40.0)
## The tiger and the lion share one voice pool: any of the clips may play.
const TIGER_BREED:=5
## ambience: roars and growls only
const BIG_CAT_SOUNDS:=["res://assets/audio/lion_roar.mp3","res://assets/audio/lion_growl.mp3","res://assets/audio/tiger_roar.mp3"]
## the attack clip fires on the bite itself, not on the ambience timer
const TIGER_ATTACK_PATH:="res://assets/audio/tiger_attack.mp3"
const BITE_VOICE_CHANCE:=0.35
const FAR_DISTANCE:=3.2  # further than this from the survivor counts as "far away"
## Formation slots around the survivor (the road runs -Z, so -Z is ahead): the two front
## slots first, then the two flanks. slot 0 = front-left, 1 = front-right, 2 = left side,
## 3 = right side. Position does not depend on the breed, so duplicate breeds can stack.
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
var heading:=0.0       # where the nose points: 0 = down the road (-Z)
var stride_rate:=1.0   # smoothed playback rate of the gallop
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
	# Generated pet GLBs import with shadows off: turn casting on so the animal has a shadow.
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m != null:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	base_y=ModelFix.fit_pet(model,float(LobbyScene.PETS[breed].get("length",1.1)))
	model.position=Vector3(0,base_y,0)
	model.rotation=Vector3(0,MODEL_YAW,0)
	heading=0.0; rotation=Vector3.ZERO
	# The player that carries the clips (some imports leave an empty one ahead of it).
	anim=null
	for ap in model.find_children("*","AnimationPlayer",true,false):
		var player := ap as AnimationPlayer
		if player != null and player.has_animation(RUN_CLIP):
			anim = player
			break
	if anim!=null:
		for clip_name in LOOPING:
			if anim.has_animation(clip_name):
				anim.get_animation(clip_name).loop_mode=Animation.LOOP_LINEAR
		anim.play(RUN_CLIP)
		anim.seek(randf()*anim.get_animation(RUN_CLIP).length,true)  # pack mates do not stride in sync
	else:
		push_error("pet has no %s clip: %s" % [RUN_CLIP, String(LobbyScene.PETS[breed].asset)])
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

## Gallop without any chasing logic; used while the opening intro plays.
func run_beside(target_position: Vector3,delta: float) -> void:
	if not is_instance_valid(model): return
	position=position.lerp(target_position,1.0-exp(-delta*4.0)); position.y=0.0
	_turn_to(0.0,delta)
	_animate(delta,false)

## Heading for a ground direction: 0 = -Z (down the road), positive turns left (-X).
static func heading_for(dir: Vector3) -> float:
	return atan2(-dir.x,-dir.z)

func _turn_to(want: float,delta: float) -> void:
	heading=lerp_angle(heading,want,1.0-exp(-delta*7.0))
	rotation=Vector3(0,heading,0)
	model.position=Vector3(0,base_y,0)
	model.rotation=Vector3(0,MODEL_YAW,0)

## One driver only: the baked Gallop loops for the whole run, a bite clip takes over briefly.
func _animate(delta: float,sprinting: bool) -> void:
	if anim==null: return
	if bite_time>0.0: return   # the bite clip started in _start_bite() is still playing
	# Feet match the ground: the road passes at world_speed, the clip covers GALLOP_CLIP_SPEED
	# at the model's authored size, and the model has been scaled by model.scale.
	var ground:=3.5
	if game!=null and game.get("world_speed")!=null: ground=maxf(float(game.get("world_speed")),3.5)
	var want:=clampf(ground/(GALLOP_CLIP_SPEED*maxf(model.scale.x,0.05)),0.9,1.7)
	if sprinting: want=minf(want*1.2,1.9)
	stride_rate=lerpf(stride_rate,want,1.0-exp(-delta*5.0))
	if anim.current_animation!=RUN_CLIP:
		anim.play(RUN_CLIP,0.12)
	anim.speed_scale=stride_rate

func _start_bite() -> void:
	bite_time=BITE_ANIM_TIME
	if anim!=null:
		for clip_name in BITE_CLIPS:
			if anim.has_animation(clip_name):
				anim.speed_scale=1.0
				anim.play(clip_name,0.06,BITE_ANIM_RATE)
				anim.seek(0.18,true)   # skip the wind-up so the snap lands with the damage
				break
	# bite voice: occasional, and never layered over a roar that is still playing
	if (breed==TIGER_BREED or breed==LION_BREED) and not bark_player.playing and randf()<BITE_VOICE_CHANCE:
		var atk:=load(TIGER_ATTACK_PATH) as AudioStream
		if atk!=null:
			bark_player.stream=atk
			bark_player.volume_db=-8.0
			bark_player.pitch_scale=randf_range(0.96,1.06)
			bark_player.play()

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
	var desired: Vector3=game.player.position+follow_offset(slot_index)
	var attacking: bool=_valid_target()
	if attacking: desired=target.position
	var flat_delta: Vector3=desired-position; flat_delta.y=0
	var distance: float=flat_delta.length()
	var bite_range: float=0.72+(float(target.radius) if attacking else 0.0)
	if attacking and distance<=bite_range:
		if cooldown<=0.0:
			cooldown=BITE_INTERVAL
			_start_bite()
			var hit_at: Vector3=target.global_position+Vector3(0,0.82 if target.kind!="brute" else 1.35,0)
			var dmg: float=bite_damage(breed)
			if target.kind=="brute": dmg=minf(dmg,maxf(0.0,float(target.health)-1.0))
			if dmg>0.0: game._hit_zombie(target,dmg,"torso",hit_at)
			if game.has_method("_progress"): game._progress("bites",1)
			target=null
	else:
		var speed: float=ATTACK_SPEED if attacking else FOLLOW_SPEED
		if distance>0.001:
			position+=flat_delta/distance*minf(distance,speed*delta)
		position.x=clampf(position.x,-3.25,3.25)
		position.y=0.0
	# Heading: straight down the road in formation. Whenever it really has somewhere to go --
	# a target, or its slot when it is more than a couple of steps away (a freshly recruited pet
	# running back from its crate) -- it turns its nose toward where it is running, all the way
	# round if need be, and swings forward again once it has arrived.
	var want:=0.0
	if distance>0.35 and (attacking or distance>1.6):
		want=heading_for(flat_delta)
	_turn_to(want,delta)
	_animate(delta,attacking)
	_tick_bark(delta)
