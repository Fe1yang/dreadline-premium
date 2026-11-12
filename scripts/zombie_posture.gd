extends SkeletonModifier3D
## Gives every shambling zombie its own posture on top of the one shared walk clip (the animation
## pack ships a single zombie walk): hunched, listing to a side, arms reaching, head lolling...
## It runs after the AnimationPlayer and turns a few bones by a fixed amount, so the legs keep
## walking on the clip and only the carriage of the body changes.

## Degrees per bone as (pitch forward, yaw to the zombie's left, roll to its left), applied in
## skeleton space parent-first. Index 0 is the plain clip.
const VARIANTS := [
	{},
	{"spine_02": Vector3(14, 0, 0), "spine_03": Vector3(14, 0, 0), "neck_01": Vector3(-10, 0, 0)},                      # hunchback
	{"spine_01": Vector3(0, 0, 11), "spine_03": Vector3(4, 0, 7), "Head": Vector3(6, 0, -20)},                          # lists left, head lolls right
	{"spine_01": Vector3(0, 0, -11), "spine_03": Vector3(4, 0, -7), "Head": Vector3(6, 0, 20)},                         # mirror of it
	{"spine_03": Vector3(8, 0, 0), "upperarm_l": Vector3(-58, 0, 0), "upperarm_r": Vector3(-50, 0, 0), "Head": Vector3(-8, 0, 0)},  # arms out, reaching
	{"spine_02": Vector3(6, 14, 0), "upperarm_r": Vector3(-64, 0, 0), "Head": Vector3(18, -10, 8)},                     # one arm clawing, head down
	{"spine_01": Vector3(-7, 0, 0), "spine_03": Vector3(-6, 0, 0), "neck_01": Vector3(-14, 0, 6), "Head": Vector3(-12, 0, 0)},      # leaning back, chin up
]
const ORDER := ["spine_01", "spine_02", "spine_03", "neck_01", "Head", "upperarm_l", "upperarm_r"]

var variant := 0
var _bones := {}
var _fwd := 1.0
var _ready_bones := false

static func count() -> int:
	return VARIANTS.size()

func _setup(sk: Skeleton3D) -> void:
	for n in ORDER:
		_bones[n] = sk.find_bone(n)
	var foot := sk.find_bone("foot_l"); var ball := sk.find_bone("ball_l")
	if foot >= 0 and ball >= 0:
		var toe: Vector3 = sk.get_bone_global_rest(ball).origin - sk.get_bone_global_rest(foot).origin
		if absf(toe.z) > 0.001: _fwd = signf(toe.z)
	_ready_bones = true

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or variant <= 0 or variant >= VARIANTS.size(): return
	if not _ready_bones: _setup(sk)
	var set: Dictionary = VARIANTS[variant]
	for n in ORDER:
		if not set.has(n): continue
		var bone: int = _bones[n]
		if bone < 0: continue
		var d: Vector3 = set[n]
		var turn := Basis(Vector3.UP, deg_to_rad(d.y)) * Basis(Vector3.RIGHT, deg_to_rad(d.x) * _fwd) * Basis(Vector3(0, 0, _fwd), deg_to_rad(d.z))
		var g := sk.get_bone_global_pose(bone)
		sk.set_bone_global_pose(bone, Transform3D(turn * g.basis, g.origin))
