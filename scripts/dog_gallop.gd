extends RefCounted
## Procedural gallop for the generated dog rigs. Their baked Dog_Run clip barely moves the legs
## (the dog just glides and sways its hips), so the run is posed here every frame instead.
## The rig's bones all lie in the dog's side plane, so every swing is a rotation about the
## bone's local X axis. Legs: +angle swings the bone's far end backward (relative to its
## parent). Spine: +angle lifts the nose.
##
## Each leg follows keyframed joint angles through one stride instead of plain sine waves, so
## the knees, hocks, elbows and wrists only ever bend the way a real dog's do:
## reach forward -> plant -> push back -> lift and tuck -> reach again.

const STRIDE:=0.42  # seconds per full gallop stride

# Key poses: [stride fraction, upper, lower, paw] in degrees, relative to the rest pose.
# Hind: stifle flexes by swinging the shin back (+), the hock flexes by bringing the foot
# forward (-). Front: the elbow folds the forearm back (+) and the wrist curls the paw back (+).
const HIND_KEYS:=[
	[0.00,-20.0, 2.0,-4.0],   # touchdown, leg reaching under the belly
	[0.22,  0.0, 4.0,-2.0],   # mid stance, hip passes over the paw
	[0.42, 18.0,-4.0, 8.0],   # push-off, leg straight out behind
	[0.58,  8.0,16.0,-22.0],  # lift: hock and stifle snap shut, foot tucked
	[0.80,-12.0,16.0,-18.0],  # swing forward, still folded
]
const FRONT_KEYS:=[
	[0.00,-26.0,-4.0,-6.0],   # touchdown, foreleg reaching far ahead
	[0.20, -4.0, 0.0, 0.0],   # mid stance
	[0.40, 20.0, 2.0,18.0],   # push-off, paw peeling back off the ground
	[0.58,  6.0,48.0,40.0],   # lift: elbow and wrist fold up tight
	[0.80,-18.0,30.0,14.0],   # swing forward, unfolding
]
# Which keyframe set each leg uses and where in the stride it touches down: a rotary gallop,
# hind pair first, front pair half a stride later, each with a short lead/trail split.
const LEGS:={
	"H_L":[HIND_KEYS,0.00],"H_R":[HIND_KEYS,0.08],
	"F_L":[FRONT_KEYS,0.48],"F_R":[FRONT_KEYS,0.56]}

var sk: Skeleton3D
## Per-breed tuning. Big cats have longer legs and a springier spine than the dogs the
## original key poses were tuned on, so they get a faster stride and a smaller swing:
##   stride  seconds per stride (smaller = quicker)
##   amp     multiplies every joint angle (smaller = shorter reach, no over-swing)
##   spine   multiplies the body/chest/neck flex
var stride:=STRIDE
var amp:=1.0
var spine:=1.0
var ids:={}
var rest_rot:={}
var body_rest:=Vector3.ZERO
var phase:=0.0
const BITE_TIME:=0.45
var bite_t:=0.0

func _init(skeleton: Skeleton3D,opts:={}) -> void:
	sk=skeleton
	stride=maxf(0.12,float(opts.get("stride",STRIDE)))
	amp=float(opts.get("amp",1.0))
	spine=float(opts.get("spine",1.0))
	var names:=["body","chest","neck","head","tail_1","tail_2"]
	for leg in LEGS: names.append_array([leg+"_upper",leg+"_lower",leg+"_paw"])
	for bone_name in names:
		var i:=sk.find_bone(bone_name)
		if i<0: continue
		ids[bone_name]=i; rest_rot[bone_name]=sk.get_bone_rest(i).basis.get_rotation_quaternion()
	if ids.has("body"): body_rest=sk.get_bone_rest(ids["body"]).origin


## Mean hip/shoulder-to-paw distance of the four legs, in metres. The stride length a leg can
## cover is this times the stance swing (38 deg for the hind keys, 46 for the front).
func leg_length() -> float:
	var total:=0.0
	var count:=0
	for leg in LEGS:
		var up:="%s_upper" % leg
		var paw:="%s_paw" % leg
		if not ids.has(up) or not ids.has(paw): continue
		# world space: the pet models are authored in centimetres and scaled by fit_pet, so a
		# skeleton-local measurement is ~2x too large and the cadence comes out far too slow
		var a:=sk.global_transform * sk.get_bone_global_rest(ids[up]).origin
		var b:=sk.global_transform * sk.get_bone_global_rest(ids[paw]).origin
		total+=(b-a).length()
		count+=1
	# The pet GLBs are authored in model units (~10x metres) and their scale lives on an
	# ancestor node, so the raw number is not metres. Clamp to a plausible pet leg instead of
	# letting the cadence collapse to the slowest allowed stride.
	return clampf(total/float(maxi(count,1)),0.25,1.05)

## Stride length in metres for the current amp (how far the paw travels backwards in stance).
func stride_length() -> float:
	return leg_length()*deg_to_rad(38.0)*amp

## Seconds per stride that keeps the planted paw still while the road moves at `speed`.
const STANCE_FRACTION:=0.41
func stride_for_speed(speed: float) -> float:
	var reach:=maxf(stride_length(),0.02)
	return clampf(reach/(STANCE_FRACTION*maxf(speed,0.1)),0.12,0.9)

func _rot(bone_name: String,angle_deg: float) -> void:
	if not ids.has(bone_name): return
	sk.set_bone_pose_rotation(ids[bone_name],rest_rot[bone_name]*Quaternion(Vector3.RIGHT,deg_to_rad(angle_deg)))

## Smooth cyclic interpolation (Catmull-Rom) of the key poses at stride fraction t.
static func _sample(keys: Array,t: float) -> Array:
	var n:=keys.size()
	var i:=n-1
	for k in n:
		if float(keys[k][0])<=t: i=k
	var j:=(i+1)%n
	var t0:=float(keys[i][0])
	var t1:=float(keys[j][0])+(1.0 if j==0 else 0.0)
	var u:=(t-t0)/maxf(t1-t0,0.0001)
	var a: Array=keys[(i-1+n)%n]
	var b: Array=keys[i]
	var c: Array=keys[j]
	var d: Array=keys[(j+1)%n]
	var out:=[]
	for ch in [1,2,3]:
		out.append(_catmull(float(a[ch]),float(b[ch]),float(c[ch]),float(d[ch]),u))
	return out

static func _catmull(p0: float,p1: float,p2: float,p3: float,u: float) -> float:
	var u2:=u*u
	return 0.5*((2.0*p1)+(-p0+p2)*u+(2.0*p0-5.0*p1+4.0*p2-p3)*u2+(-p0+3.0*p1-3.0*p2+p3)*u2*u)

## Advance the stride and pose the skeleton. rate scales the stride speed.
## Snap the head down and back: a bite with no baked clip.
func bite() -> void:
	bite_t=BITE_TIME

func step(delta: float,rate:=1.0) -> void:
	phase=fmod(phase+delta*rate/stride,1.0)
	for leg in LEGS:
		var cfg: Array=LEGS[leg]
		var pose:=_sample(cfg[0],fposmod(phase-float(cfg[1]),1.0))
		_rot(leg+"_upper",pose[0]*amp)
		_rot(leg+"_lower",pose[1]*amp)
		_rot(leg+"_paw",pose[2]*amp)
	# Spine flexes (collected) when all four paws gather under the body and extends in flight.
	var flex:=cos(TAU*(phase-0.25))
	_rot("body",5.0*flex*spine)
	_rot("chest",-9.0*flex*spine)
	_rot("neck",7.0*flex*spine)
	_rot("head",-5.0*flex*spine)
	if bite_t>0.0:
		bite_t=maxf(0.0,bite_t-delta)
		var swing:=sin((1.0-bite_t/BITE_TIME)*PI)
		_rot("neck",26.0*swing)
		_rot("head",20.0*swing)
	_rot("tail_1",12.0*sin(TAU*phase))
	_rot("tail_2",10.0*sin(TAU*phase-1.2))
	if ids.has("body"):
		# One airborne lift per stride, after the front pair pushes off.
		sk.set_bone_pose_position(ids["body"],body_rest+Vector3(0,0.28*maxf(0.0,sin(TAU*(phase-0.05))),0))
