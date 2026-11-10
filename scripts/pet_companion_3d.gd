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
## Breeds whose rigs do not survive the procedural gallop: they play their own
## run clip instead (the czech wolfdog comes from a different import and its legs
## folded into each other when the gallop drove them).
# Every pet rig here carries the same leg bones (F_L/H_R ...), and the procedural gallop
# swings them 45 deg per stride against the baked clip's 28, so all six use it.
const GALLOP_DISABLED:=[0, 1, 2, 3]   # dogs walk on their own clips; only the cats gallop
const GAIT_OVERRIDES:={
   0: {"amp":0.50, "spine":0.80},
   1: {"amp":0.50, "spine":0.80},
   2: {"amp":0.45, "spine":0.75},
   3: {"amp":0.50, "spine":0.80},
   5: {"amp":0.42, "spine":0.75, "leg_phases":{"H_L":0.00,"F_R":0.00,"H_R":0.50,"F_L":0.50}},
   6: {"amp":0.40, "spine":0.70, "leg_phases":{"H_L":0.00,"F_R":0.00,"H_R":0.50,"F_L":0.50}},
   }  # stride speed matched to how fast the street scrolls past (Kimi's tuning)
## Barking: only now and then, so it never nags. Near the survivor the close bark plays (one or
## two barks cut from the clip); once the dog has run off after a zombie, the distant one.
# Lazy paths: preloading imported audio also aborts the first import pass on a clean checkout.
const BARK_NEAR_PATH:="res://assets/audio/dog_bark.mp3"
const BARK_FAR_PATH:="res://assets/audio/dog_bark_distant.mp3"
const BARK_SEGMENTS:=[[0.0,0.78],[0.0,1.36],[2.19,2.95],[3.36,3.92],[4.38,4.98]]  # seconds in BARK_NEAR
const BARK_GAP:=Vector2(10.0,18.0)
## The lion is a pet too, but it growls on its own slow clock.
const LION_BREED:=6
const LION_ROAR_PATH:="res://assets/audio/lion_roar.mp3"
const LION_GROWL_PATH:="res://assets/audio/lion_growl.mp3"
const LION_GAP:=Vector2(22.0,40.0)
## The tiger and the lion share one voice pool: any of the four clips may play.
const TIGER_BREED:=5
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
var is_moving := false
var held_yaw := 0.0   # smoothed heading, kept between frames
var last_pos := Vector3.ZERO   # drives idle vs run clip selection
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
	if breed==LION_BREED:
		yaw_offset += PI   # rebuilt lion rig faces backwards against the run direction
	elif breed in GALLOP_DISABLED:
		# the dog scans are authored nose-towards-camera: the NODE turns, not the mesh, so the
		# bite still happens at the head and the pack runs away from the player
		yaw_offset += PI
	# Some of these scans are authored nose-along-X and some nose-along-Z, so half the pack ran
	# sideways. Measure the head against the body and turn the model onto the travel axis.
	var sk_probe := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk_probe != null:
		var hb := sk_probe.find_bone("head")
		var bb := sk_probe.find_bone("body")
		if hb >= 0 and bb >= 0:
			var d := sk_probe.get_bone_global_rest(hb).origin - sk_probe.get_bone_global_rest(bb).origin
			if absf(d.x) > absf(d.z) * 1.2:
				model.rotation.y = -signf(d.x) * PI * 0.5

	base_y=ModelFix.fit_pet(model,float(LobbyScene.PETS[breed].get("length",1.1)))
	model.position.y=base_y
	anim=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if anim != null:
		_strip_root_motion(anim)
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
	rotation.y=lerp_angle(rotation.y,atan2(Vector3.FORWARD.x,Vector3.FORWARD.z)+yaw_offset,1.0-exp(-delta*12.0))
	_animate(delta)

## First animation name from `names` that this model actually has.
func _first_clip(player: AnimationPlayer, names: Array) -> String:
	for n in names:
		if player.has_animation(String(n)):
			return String(n)
	return ""


## Some pet clips carry the walk cycle as root translation. Played in place that reads as the
## animal sliding forward while its skin stretches, so the horizontal part of every root track is
## flattened and only the vertical bob is kept.
func _strip_root_motion(player: AnimationPlayer) -> void:
	for name in player.get_animation_list():
		var clip := player.get_animation(String(name))
		if clip == null:
			continue
		for track in range(clip.get_track_count()):
			if clip.track_get_type(track) != Animation.TYPE_POSITION_3D:
				continue
			var path := String(clip.track_get_path(track))
			var lower := path.to_lower()
			if lower.find("root") < 0 and lower.find("hips") < 0 and lower.find("pelvis") < 0:
				continue
			var keys := clip.track_get_key_count(track)
			var base_y := 0.0
			if keys > 0:
				base_y = (clip.track_get_key_value(track, 0) as Vector3).y
			for k in range(keys):
				var v: Vector3 = clip.track_get_key_value(track, k)
				clip.track_set_key_value(track, k, Vector3(0.0, v.y - base_y, 0.0))


func _animate(delta: float) -> void:
	# The clip follows the body: whatever path moved the pet this frame, standing still plays the
	# idle and any real displacement plays the run. Absolute ground speed, not intent.
	var moved: float = position.distance_to(last_pos)
	last_pos = position
	is_moving = moved > 0.0015
	if bite_time>0.0:
		var bite_clip := ""
		if anim != null:
			bite_clip = _first_clip(anim, ["Bite", "Bite_Up", "Dog_Bite", "Attack"])
		if bite_clip != "":
			anim.play(bite_clip, 0.08)
		else:
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
		var idle := _first_clip(anim, ["Idle", "Dog_Idle", "Lion_Idle", "Tiger_Idle", "idle"])
		if breed in GALLOP_DISABLED:
			# the dogs keep their baked cycle; "moving" has to include the scrolling road,
			# otherwise a dog that has caught up plays its idle while the ground races past
			var dog_moving: bool = is_moving or (game != null and (float(game.get("world_speed")) > 0.05 or String(game.get("state")) in ["playing", "intro"]))
			var own_run := _first_clip(anim, ["Gallop", "Gallop_001", "Dog_Run", "Run"])
			var own_idle := "" if dog_moving else idle
			var pick := own_idle if own_idle != "" else own_run
			if pick != "":
				if anim.current_animation != pick or not anim.is_playing():
					anim.play(pick, 0.15)
				# Gallop at its authored rate: it is already the fast cycle, no need to over-clock it
				anim.speed_scale = 1.0
				return
		# The road scrolls under the animal, so a pet that has caught up sits still in world space
		# while the ground races past: that still counts as running.
		# While a run is live the pet is always moving relative to the road, so it always needs the
		# gallop: the lion used to catch up, read as "not moving" and play its idle instead.
		var in_run: bool = game != null and String(game.get("state")) in ["playing", "intro"]
		var scrolling: bool = game != null and float(game.get("world_speed")) > 0.05
		var moving_now: bool = is_moving or scrolling or in_run
		if not moving_now and idle != "":
			# standing: the baked idle reads well on every breed
			if anim.current_animation != idle or not anim.is_playing():
				anim.play(idle, 0.15)
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
		if breed==LION_BREED:
			gallop.stride=maxf(want*1.9,0.30)   # longer stride, unhurried cadence
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
	var want_yaw: float = held_yaw
	if flat_delta.length() > 0.30 and (attacking or distance > 2.4):
		want_yaw = atan2(flat_delta.x, flat_delta.z)
	elif distance <= 1.6 and not attacking:
		want_yaw = 0.0
	# deadband: ignore small swings so the model cannot twitch between two headings
	if absf(angle_difference(held_yaw, want_yaw)) > 0.35:
		held_yaw = want_yaw
	rotation.y = lerp_angle(rotation.y, held_yaw + yaw_offset, 1.0-exp(-delta*6.0))
	model.position.y=base_y
	# The run is always moving forward, so the dog gallops except during a bite.
	_animate(delta)
	_tick_bark(delta)
