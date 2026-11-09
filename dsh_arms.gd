extends SceneTree
## DSH: per-character arm metrics, to see why Jian's two-hand stance collapses.
## Prints visible-hand mesh offset, upper/lower arm bone lengths and shoulder width.

const ASSETS := [
	["mason", "survivor_male_universal"],
	["riley", "survivor_riley_universal"],
	["darius", "survivor_medic_universal"],
	["maya", "survivor_maya_universal"],
	["jian", "survivor_jian_scout_universal"],
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var grip_script = load("res://scripts/gun_grip_ik.gd")
	for entry in ASSETS:
		var label: String = entry[0]
		var path: String = "res://assets/models/actors/%s.glb" % entry[1]
		if not ResourceLoader.exists(path):
			print("%-7s MISSING" % label)
			continue
		var inst: Node = (load(path) as PackedScene).instantiate()
		var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false)
		if sk == null:
			print("%-7s no skeleton" % label)
			inst.free()
			continue
		var off_r: Vector3 = grip_script.mesh_offset(inst, "hand_r")
		var off_l: Vector3 = grip_script.mesh_offset(inst, "hand_l")
		var u: Vector3 = sk.get_bone_global_rest(sk.find_bone("upperarm_r")).origin
		var lo: Vector3 = sk.get_bone_global_rest(sk.find_bone("lowerarm_r")).origin
		var h: Vector3 = sk.get_bone_global_rest(sk.find_bone("hand_r")).origin
		var sl: Vector3 = sk.get_bone_global_rest(sk.find_bone("upperarm_l")).origin
		print("%-7s upper=%.3f  fore=%.3f  reach=%.3f  shoulder_w=%.3f  hand_off_r=(%.3f,%.3f,%.3f) L=(%.3f,%.3f,%.3f)" % [
			label, u.distance_to(lo), lo.distance_to(h), u.distance_to(lo) + lo.distance_to(h),
			u.distance_to(sl), off_r.x, off_r.y, off_r.z, off_l.x, off_l.y, off_l.z])
		inst.free()
	print("DSH_ARM_METRICS_DONE")
	quit()
