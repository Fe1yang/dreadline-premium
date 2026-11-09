extends SceneTree
## DSH: why does GunGripIK.mesh_offset() return zero for Jian?

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for pair in [["mason", "survivor_male_universal"], ["jian", "survivor_jian_scout_universal"]]:
		var label: String = pair[0]
		var path: String = "res://assets/models/actors/%s.glb" % pair[1]
		print("=== ", label)
		var inst: Node = (load(path) as PackedScene).instantiate()
		var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false)
		if sk != null:
			print("   bones=", sk.get_bone_count(), " hand_r=", sk.find_bone("hand_r"))
		var meshes: Array = inst.find_children("*", "MeshInstance3D", true, false)
		print("   meshes=", meshes.size())
		for m in meshes:
			var mi: MeshInstance3D = m as MeshInstance3D
			var binds: int = -1
			var has_hand: bool = false
			var sample: String = "none"
			if mi.skin != null:
				binds = mi.skin.get_bind_count()
				var collected: Array = []
				for i in binds:
					var bn: String = String(mi.skin.get_bind_name(i))
					if bn == "hand_r":
						has_hand = true
					if i < 4:
						collected.append(bn)
				sample = str(collected)
			print("   mesh=", String(mi.name), " skin_binds=", binds, " has_hand_r=", has_hand, " sample=", sample)
		inst.free()
	print("DSH_SKIN_DONE")
	quit()
