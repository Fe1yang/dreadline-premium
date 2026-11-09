extends RefCounted
## Borrows clips from the Universal Animation Library for any character rigged to the same
## 65-bone UAL skeleton. Only the node path in front of "Skeleton3D" differs between files
## (the library uses "Armature", our actors use e.g. "UniversalRig"), so tracks are re-pathed.

const SOURCES:={
	"ual1":"res://assets/animation-library/ual1/UAL1_Standard.glb",
	"ual2":"res://assets/animation-library/ual2/UAL2_Standard.glb",
}
static var _cache: Dictionary={}
static var _skeletons: Dictionary={}

static func _source_player(source: String) -> AnimationPlayer:
	if _cache.has(source): return _cache[source]
	var scene: Node=load(SOURCES[source]).instantiate()
	var player:=scene.find_child("AnimationPlayer",true,false) as AnimationPlayer
	_cache[source]=player
	_skeletons[source]=scene.find_children("*","Skeleton3D",true,false)[0]
	return player

## Copies `clip` from the library into `target` (if not already there) and returns the name to play.
## `rest_blend` pulls chosen bones part of the way back toward this character's rest pose
## (e.g. {"upperarm_l":0.6}) — useful when a model's skinning tears in poses far from rest.
static func borrow(target: AnimationPlayer,clip: String,source:="ual1",rest_blend:={},strip_bones:=[]) -> String:
	if target==null: return ""
	var local_name:="ual_"+clip+("_adj" if not rest_blend.is_empty() or not strip_bones.is_empty() else "")
	if target.has_animation(local_name): return local_name
	var src:=_source_player(source)
	if src==null or not src.has_animation(clip): return ""
	var rig_path:=_rig_path(target)
	var anim:=src.get_animation(clip).duplicate(true) as Animation
	var src_skel:=_skeletons[source] as Skeleton3D
	var dst_skel:=target.get_node(target.root_node).get_node_or_null(rig_path+"Skeleton3D") as Skeleton3D
	# Rest-relative retarget: each key keeps its offset from the library's rest pose and is
	# re-applied on top of this character's own rest pose (fitted rigs have different rests).
	var height_ratio:=1.0
	if dst_skel and src_skel:
		var hs_i:=src_skel.find_bone("Head"); var hd_i:=dst_skel.find_bone("Head")
		if hs_i>=0 and hd_i>=0:
			var hs:=src_skel.get_bone_global_rest(hs_i).origin.y
			var hd:=dst_skel.get_bone_global_rest(hd_i).origin.y
			if hs>0.01: height_ratio=hd/hs
	for t in range(anim.get_track_count()):
		var path:=str(anim.track_get_path(t))
		var cut:=path.find("Skeleton3D:")
		if cut<0: continue
		anim.track_set_path(t,NodePath(rig_path+path.substr(cut)))
		if dst_skel==null or src_skel==null: continue
		var bone:=path.substr(cut+"Skeleton3D:".length())
		var si:=src_skel.find_bone(bone); var di:=dst_skel.find_bone(bone)
		if si<0 or di<0: continue
		var s_rest:=src_skel.get_bone_rest(si); var d_rest:=dst_skel.get_bone_rest(di)
		match anim.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				var sq:=s_rest.basis.get_rotation_quaternion(); var dq:=d_rest.basis.get_rotation_quaternion()
				for k in range(anim.track_get_key_count(t)):
					var q: Quaternion=anim.track_get_key_value(t,k)
					var out:=(dq*(sq.inverse()*q)).normalized()
					if rest_blend.has(bone): out=out.slerp(dq,float(rest_blend[bone]))
					anim.track_set_key_value(t,k,out)
			Animation.TYPE_POSITION_3D:
				for k in range(anim.track_get_key_count(t)):
					var v: Vector3=anim.track_get_key_value(t,k)
					anim.track_set_key_value(t,k,d_rest.origin+(v-s_rest.origin)*height_ratio)
	# Drop tracks for bones the caller wants to pose by hand (see pin_to_bind_pose).
	for t in range(anim.get_track_count()-1,-1,-1):
		var path:=str(anim.track_get_path(t)); var cut:=path.find("Skeleton3D:")
		if cut>=0 and path.substr(cut+"Skeleton3D:".length()) in strip_bones: anim.remove_track(t)
	anim.loop_mode=Animation.LOOP_LINEAR
	var lib:AnimationLibrary
	if target.has_animation_library(""): lib=target.get_animation_library("")
	else:
		lib=AnimationLibrary.new(); target.add_animation_library("",lib)
	lib.add_animation(local_name,anim)
	return local_name

static func _rig_path(target: AnimationPlayer) -> String:
	# Re-use the prefix the character's own clips already use, e.g. "UniversalRig/".
	for name in target.get_animation_list():
		var a:=target.get_animation(name)
		for t in range(a.get_track_count()):
			var path:=str(a.track_get_path(t))
			var cut:=path.find("Skeleton3D:")
			if cut>=0: return path.substr(0,cut)
	# No clips of its own (e.g. the boss): locate the skeleton under the player's root node.
	var root:=target.get_node_or_null(target.root_node)
	if root:
		var skels:=root.find_children("*","Skeleton3D",true,false)
		if not skels.is_empty(): return str(root.get_path_to(skels[0])).trim_suffix("Skeleton3D")
	return "UniversalRig/"

## Poses `bones` exactly as the mesh was skinned (from the Skin's bind matrices), so geometry
## weighted mostly to the torso stays attached. Returns the bones it managed to pose.
static func pin_to_bind_pose(model: Node,bones: Array) -> Array:
	var done:=[]
	var skel:=model.find_children("*","Skeleton3D",true,false)
	if skel.is_empty(): return done
	var sk:=skel[0] as Skeleton3D
	var skin: Skin=null
	for m in model.find_children("*","MeshInstance3D",true,false):
		if (m as MeshInstance3D).skin: skin=(m as MeshInstance3D).skin; break
	if skin==null: return done
	var global_bind:={}
	for i in range(skin.get_bind_count()):
		var name:=str(skin.get_bind_name(i))
		if name=="": name=sk.get_bone_name(skin.get_bind_bone(i))
		global_bind[name]=skin.get_bind_pose(i).affine_inverse()
	for bone in bones:
		var bi:=sk.find_bone(bone)
		if bi<0 or not global_bind.has(bone): continue
		var parent:=sk.get_bone_parent(bi)
		var parent_global:Transform3D=Transform3D.IDENTITY
		if parent>=0:
			var pname:=sk.get_bone_name(parent)
			parent_global=global_bind[pname] if global_bind.has(pname) else sk.get_bone_global_rest(parent)
		var local:Transform3D=parent_global.affine_inverse()*global_bind[bone]
		sk.set_bone_pose_rotation(bi,local.basis.get_rotation_quaternion())
		sk.set_bone_pose_position(bi,local.origin)
		done.append(bone)
	return done
