extends SkeletonModifier3D
## Lobby posture pass for models whose own idle clip is nearly static:
##  - lifts the spine out of the slouch the sculpted idle sits in
##  - adds breathing and a slow weight shift so the figure never looks frozen
## Applied after the AnimationPlayer each frame, so it works on any rig that has the bones.

@export var slouch_fix_deg := 7.0   ## backward pitch on the lower spine (negative slouch)
@export var chest_lift_deg := 3.0
@export var breathing_deg := 1.6
@export var sway_deg := 1.4
@export var head_drift_deg := 2.2

var _t := 0.0

func _ready() -> void:
	_t = randf() * 10.0

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var delta := get_process_delta_time()
	_t += delta
	var breathe := sin(_t * 1.9)
	var sway := sin(_t * 0.55)
	var drift := sin(_t * 0.37)

	_bend(sk, "spine_01", Vector3(slouch_fix_deg * 0.45, 0, sway * sway_deg * 0.35))
	_bend(sk, "spine_02", Vector3(slouch_fix_deg * 0.35 + breathing_deg * breathe, 0, sway * sway_deg * 0.3))
	_bend(sk, "spine_03", Vector3(chest_lift_deg * 0.6 + breathing_deg * 0.6 * breathe, 0, sway * sway_deg * 0.2))
	_bend(sk, "neck_01", Vector3(-chest_lift_deg * 0.4 + head_drift_deg * 0.4 * drift, drift * head_drift_deg, 0))
	_bend(sk, "head", Vector3(-chest_lift_deg * 0.3, drift * head_drift_deg * 0.7, 0))
	_bend(sk, "pelvis", Vector3(0, 0, sway * sway_deg * 0.25))

## Rotate a bone about its own local axes on top of whatever the clip produced.
func _bend(sk: Skeleton3D, bone: String, deg: Vector3) -> void:
	var i := sk.find_bone(bone)
	if i < 0:
		return
	var q := Quaternion.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)) * 0.06)
	sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * q)
