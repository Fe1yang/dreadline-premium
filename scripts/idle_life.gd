extends SkeletonModifier3D
## Lobby idle life, layered on the static standing pose.
## Always on: breathing in the chest and a slow weight shift; head that looks around.
## Each survivor has a distinct procedural idle personality (see PROFILES):
##   0 Mason  - steady veteran: heavy slow breath, shoulder roll, belt rest
##   1 Riley  - fidgety female: frequent neck tilt, head down, belt rest
##   2 Darius - calm medic: deep slow breath, bowed head nod, minimal sway
##   3 Maya   - alert tracker: quick look-backs, shoulder roll, scanning
##   4 Jian   - scout: horizon scan, slight crouch, look-back
## No character wears a watch, so the old "watch" wrist-glance is gone.
## Every few seconds one one-sided action plays from the character's pool.
## Arm actions drive ArmsRelaxed's per-side `lift` / `bend` / `roll`; spine,
## clavicle, neck, head and pelvis are rotated by a few degrees. Runs before ArmsRelaxed.

var arms: Node # ArmsRelaxed of the same skeleton
var bones:={}
var up:=Vector3.UP
var right:=Vector3.RIGHT
var forward:=Vector3.BACK
var lids: Array=[] # two skin-colored flattened spheres that close over the eyes on blink
var lid_timer:=1.4
var lid_t:=-1.0
var sk_ref: Skeleton3D
var t:=0.0
var last_ms:=0
var rng:=RandomNumberGenerator.new()
# head look (yaw, pitch, roll in degrees): +yaw = toward the character's left, +pitch = up
var look:=Vector3.ZERO
var look_target:=Vector3.ZERO
var look_timer:=1.5
# current action
var action:=""
var side:="l"
var action_t:=0.0
var action_len:=0.0
var rest_timer:=3.0
var last_action:=""
var profile: Dictionary={}

const ACTIONS:={
	"belt":1.9,        # hand rests at belt
	"shoulder":2.2,    # roll one shoulder
	"look_back":2.8,   # turn upper body, look over shoulder
	"neck":2.6,        # tilt head side to side
	"nod":2.2,         # slow head nod (calm / reflective)
	"down":2.4,        # bow head down, then lift
	"scan":3.0,        # horizon sweep: yaw left->right
	"shake":1.6,       # small head shake (no)
}

# Per-character idle personality. All angles in degrees.
# breath_amp/breath_period: chest breathing; sway_amp/sway_period: weight shift.
# base_lean: constant spine forward tilt (crouch/readiness), base_turn: constant yaw.
# head_yaw_range/head_pitch_range: idle glance spread; head_rate: how fast glances
# are re-picked. pool: which micro-actions this character performs.
const PROFILES:=[
	{"name":"MASON","breath_amp":1.2,"breath_period":4.4,"sway_amp":1.0,"sway_period":9.0,"base_lean":0.8,"base_turn":0.0,"head_yaw":14.0,"head_pitch":5.0,"head_top":2.0,"head_rate":0.9,"rest_min":3.5,"rest_max":7.0,"pool":["shoulder","belt","look_back","neck","nod"]},
	{"name":"RILEY","breath_amp":0.9,"breath_period":3.8,"sway_amp":0.9,"sway_period":8.5,"base_lean":0.8,"base_turn":0.0,"head_yaw":12.0,"head_pitch":6.0,"head_top":2.0,"head_rate":1.2,"rest_min":3.0,"rest_max":6.0,"pool":["neck","down","belt","shoulder"]},
	{"name":"DARIUS","breath_amp":1.4,"breath_period":5.2,"sway_amp":0.5,"sway_period":11.0,"base_lean":1.5,"base_turn":0.0,"head_yaw":8.0,"head_pitch":4.0,"head_top":1.0,"head_rate":0.5,"rest_min":4.5,"rest_max":8.0,"pool":["nod","down","shoulder","neck"]},
	{"name":"MAYA","breath_amp":0.9,"breath_period":4.0,"sway_amp":0.9,"sway_period":8.0,"base_lean":0.8,"base_turn":0.0,"head_yaw":16.0,"head_pitch":5.0,"head_top":2.0,"head_rate":1.3,"rest_min":2.8,"rest_max":5.5,"pool":["look_back","neck","shoulder","scan"]},
]

func setup(sk: Skeleton3D, profile_index:int = 0) -> void:
	profile = PROFILES[clampi(profile_index,0,PROFILES.size()-1)]
	# Core bones (required) + legs (optional: micro weight-shift wiggle)
	for n in ["spine_01","spine_02","spine_03","clavicle_l","clavicle_r","neck_01","Head","upperarm_l","upperarm_r","pelvis"]:
		bones[n]=sk.find_bone(n)
	for n in ["thigh_l","thigh_r","calf_l","calf_r","foot_l","foot_r"]:
		var b:=sk.find_bone(n)
		if b>=0: bones[n]=b
	if int(bones.get("spine_01",-1))<0 or int(bones.get("Head",-1))<0 or int(bones.get("pelvis",-1))<0:
		bones.clear(); return
	# validity of required core set only
	for n in ["spine_01","spine_02","spine_03","clavicle_l","clavicle_r","neck_01","Head","upperarm_l","upperarm_r","pelvis"]:
		if int(bones.get(n,-1))<0: bones.clear(); return
	var head:=sk.get_bone_global_rest(bones.Head).origin
	var hip:=sk.get_bone_global_rest(bones.pelvis).origin
	up=(head-hip).normalized()
	right=(sk.get_bone_global_rest(bones.upperarm_r).origin-sk.get_bone_global_rest(bones.upperarm_l).origin)
	right=(right-up*right.dot(up)).normalized()
	forward=up.cross(right).normalized()
	rng.randomize(); t=rng.randf()*20.0; rest_timer=rng.randf_range(2.0,4.0)
	sk_ref=sk
	_make_lids(sk)

func _make_lids(sk: Skeleton3D) -> void:
	if not lids.is_empty(): return
	# Eye size in meters, flattened sphere lids in skin colour.
	var sph:=SphereMesh.new(); sph.radius=1.0; sph.height=2.0; sph.radial_segments=12; sph.rings=6
	var mat:=StandardMaterial3D.new(); mat.albedo_color=Color(0.94,0.84,0.74); mat.roughness=0.6
	for side in [-1.0,1.0]:
		var lid:=MeshInstance3D.new()
		lid.mesh=sph; lid.material_override=mat; lid.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lid.scale=Vector3(0.022,0.001,0.011)
		lid.set_meta("side",side)
		sk.add_child(lid) # skeleton space = same space as bone origins
		lids.append(lid)

var _blink_value:=0.0
func _update_lids(sk: Skeleton3D) -> void:
	if lids.is_empty(): return
	# eyes are centred ~6cm above head origin, ~7.5cm forward, ~3.2cm lateral (head-local)
	var head_o:=sk.get_bone_global_pose(bones.Head).origin
	var hb: Basis=sk.get_bone_global_pose(bones.Head).basis
	var eye_local:=Vector3(0,0.06,-0.075)
	for lid in lids:
		var s: float=float(lid.get_meta("side",-1.0))
		var offset: Vector3=eye_local + Vector3(0.032*s,0,0)
		lid.position=head_o + hb*offset
		# orient lid with the head so it tracks yaw/pitch
		lid.global_transform.basis=sk.global_transform.basis*hb if false else Basis(hb)
		lid.basis=hb
		# vertical closing: 0 = open (invisible line), 1 = shut (covers eye)
		var sy:=0.001+0.014*_blink_value
		lid.scale=Vector3(0.022,sy,0.011)

func _rot(sk: Skeleton3D,bone: int,axis: Vector3,deg: float) -> void:
	if absf(deg)<0.001: return
	var g:=sk.get_bone_global_pose(bone).basis.get_rotation_quaternion()
	var r:=Quaternion(axis.normalized(),deg_to_rad(deg))
	var l:=sk.get_bone_pose_rotation(bone)
	sk.set_bone_pose_rotation(bone,(l*(g.inverse()*r*g)).normalized())

## 0..1..0 over an action: eases in, holds, eases out.
func _env(x: float,length: float,ramp:=0.6) -> float:
	var a:=clampf(x/ramp,0.0,1.0); var b:=clampf((length-x)/ramp,0.0,1.0)
	var w:=minf(a,b)
	return w*w*(3.0-2.0*w)

func start_action(name: String,on_side:="") -> void:
	action=name; action_t=0.0; action_len=float(ACTIONS.get(name,2.0)); last_action=name
	side=on_side if on_side!="" else ("l" if rng.randf()<0.5 else "r")
	# arm actions use the left arm: the inward roll that
	# brings the forearm across the body only looks right on that side for both meshes
	if name in ["belt"]: side="l"

func _process_modification() -> void:
	var sk:=get_skeleton()
	if sk==null or bones.is_empty(): return
	var now:=Time.get_ticks_msec()
	var dt:=clampf((now-last_ms)/1000.0,0.0,0.1) if last_ms>0 else 0.016
	last_ms=now; t+=dt
	var s:=1.0 if side=="l" else -1.0 # mirror: +1 toward the character's left
	var rest_min:=float(profile.get("rest_min",3.5)); var rest_max:=float(profile.get("rest_max",7.0))
	# --- pick the next action from this character's pool ---
	if action=="":
		rest_timer-=dt
		if rest_timer<=0.0:
			var pool: Array=profile.get("pool",["neck"])
			var names:=pool.filter(func(n): return n!=last_action)
			if names.is_empty(): names=pool
			start_action(names[rng.randi()%names.size()])
	else:
		action_t+=dt
		if action_t>=action_len: action=""; rest_timer=rng.randf_range(rest_min,rest_max)
	var w:=_env(action_t,action_len) if action!="" else 0.0
	# --- breathing (chest only) and a slow weight shift (per character) ---
	var breath_period:=float(profile.get("breath_period",4.2))
	var breath_amp:=float(profile.get("breath_amp",1.3))
	var sway_period:=float(profile.get("sway_period",9.0))
	var sway_amp:=float(profile.get("sway_amp",1.4))
	var breath:=sin(t*TAU/breath_period)
	var sway:=sin(t*TAU/sway_period)
	var lean:=sway*sway_amp + float(profile.get("base_lean",0.0))
	var turn:=sway*sway_amp*0.6 + float(profile.get("base_turn",0.0))
	var arm_lift:={"l":0.0,"r":0.0}; var arm_bend:={"l":0.0,"r":0.0}; var arm_roll:={"l":0.0,"r":0.0}
	var head:=Vector3.ZERO
	match action:
		"belt":
			arm_lift[side]=0.08*w; arm_bend[side]=45.0*w; arm_roll[side]=-30.0*w
			lean+=-1.0*s*w; head=Vector3(-4.0*s,-2.0,0)*w
		"shoulder":
			var ph:=clampf(action_t/action_len,0.0,1.0)*TAU
			_rot(sk,bones["clavicle_"+side],forward,4.0*sin(ph)*s*-1.0*w)
			_rot(sk,bones["clavicle_"+side],up,2.5*cos(ph)*s*w)
		"look_back":
			turn+=6.0*s*w; head=Vector3(16.0*s,-2.0,0)*w
		"neck":
			var ph2:=sin(clampf(action_t/action_len,0.0,1.0)*TAU)
			head=Vector3(0,-2.0,7.0*ph2)*w
		"nod":
			# slow down-up-down nod: two pitch dips over the action
			var ph3t:=clampf(action_t/action_len,0.0,1.0)*PI*2.0
			head=Vector3(0,-6.0+4.0*maxf(0.0,sin(ph3t)),2.0*sin(action_t*TAU/action_len))*w
		"down":
			var ph4:=sin(clampf(action_t/action_len,0.0,1.0)*PI)
			head=Vector3(0,-7.0*ph4,3.0*s*ph4)*w
			lean+=1.5*ph4
		"scan":
			var ph5:=sin(clampf(action_t/action_len,0.0,1.0)*TAU)
			head=Vector3(16.0*ph5,2.0,0)*w
			turn+=3.0*ph5*w
		"shake":
			var ph6:=sin(clampf(action_t/action_len,0.0,1.0)*TAU*2.0)
			head=Vector3(4.0*ph6,0,0)*w
	if arms:
		arms.lift=arm_lift; arms.bend=arm_bend; arms.roll=arm_roll
	# pelvis weight shift only. Leg bones stay in the bind standing pose on purpose:
	# rotating thigh/calf here bends the knees and reads as bow legs in the lobby.
	var shift:=sway*sway_amp*0.5
	_rot(sk,bones.pelvis,up,turn*0.20)
	_rot(sk,bones.pelvis,forward,shift*0.2)
	_rot(sk,bones.spine_01,forward,lean)
	_rot(sk,bones.spine_01,up,turn)
	_rot(sk,bones.spine_02,right,-breath_amp*breath)
	_rot(sk,bones.spine_03,right,-breath_amp*0.8*breath)
	# --- head: idle glances when no action is steering it ---
	look_timer-=dt
	if look_timer<=0.0:
		var yaw_range:=float(profile.get("head_yaw",16.0)); var pitch_range:=float(profile.get("head_pitch",6.0)); var top:=float(profile.get("head_top",3.0))
		var roll:=rng.randf()
		if roll<0.40: look_target=Vector3.ZERO
		elif roll<0.80: look_target=Vector3(rng.randf_range(yaw_range*0.5,yaw_range)*(1 if rng.randf()<0.5 else -1),rng.randf_range(-pitch_range*0.6,top),0)
		else: look_target=Vector3(rng.randf_range(-6.0,6.0),-pitch_range,0)
		var rate:=float(profile.get("head_rate",1.0))
		look_timer=rng.randf_range(2.2,4.8)/maxf(0.4,rate)
	look=look.lerp(look_target*(1.0-w),1.0-exp(-dt*2.6))
	var h:=look+head
	var counter:=-turn # keep the head facing where it looks while the spine turns
	for pair in [[bones.neck_01,0.45],[bones.Head,0.55]]:
		_rot(sk,pair[0],up,(h.x+counter)*pair[1])
		_rot(sk,pair[0],right,(h.y+0.4*breath)*pair[1])
		_rot(sk,pair[0],forward,(h.z-lean)*pair[1])
	# --- fake eyelid blink: 0.15s shut every 2.5-5s, no head squash ---
	if lid_t<0.0:
		lid_timer-=dt
		if lid_timer<=0.0:
			lid_t=0.0
	else:
		lid_t+=dt
	_blink_value=0.0
	if lid_t>=0.0:
		var bt:=lid_t/0.15
		if bt>=1.0:
			lid_t=-1.0; lid_timer=rng.randf_range(2.5,5.0)
		else:
			_blink_value=sin(bt*PI)
	_update_lids(sk)
