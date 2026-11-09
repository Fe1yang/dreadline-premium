extends SkeletonModifier3D
## Seated riding pose for the motorcycle: on top of the frozen run frame, both thighs swing
## forward onto the tank, calves drop to the pegs, boots level. Same aiming helper as
## legs_out.gd (the ground-sitting zombie pose), with bike-specific directions.

var body: Node3D # the character model root; its +Z is the way the survivor faces
var bones:={}

func _g(sk: Skeleton3D,bone: int) -> Transform3D:
	var t:=sk.get_bone_pose(bone)
	var p:=sk.get_bone_parent(bone)
	while p>=0:
		t=sk.get_bone_pose(p)*t; p=sk.get_bone_parent(p)
	return t

func _aim(sk: Skeleton3D,bone: int,child: int,dir: Vector3) -> void:
	var g:=_g(sk,bone); var cur:=_g(sk,child).origin-g.origin
	if cur.length()<0.0001: return
	var rot:=Quaternion(cur.normalized(),dir.normalized())
	var parent:=sk.get_bone_parent(bone)
	var pb:=_g(sk,parent).basis if parent>=0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(bone,(pb.inverse()*(Basis(rot)*g.basis)).get_rotation_quaternion())

func _process_modification() -> void:
	var sk:=get_skeleton()
	if sk==null: return
	if bones.is_empty():
		for n in ["thigh_l","calf_l","foot_l","thigh_r","calf_r","foot_r"]: bones[n]=sk.find_bone(n)
	if bones.values().any(func(v): return int(v)<0): return
	var to_skel:=sk.global_transform.basis.orthonormalized().inverse()
	var root: Node3D=body if is_instance_valid(body) else sk
	var fwd:=(to_skel*root.global_transform.basis.z.normalized()).normalized()
	var down:=(to_skel*Vector3.DOWN).normalized()
	var right:=(to_skel*root.global_transform.basis.x.normalized()).normalized()
	for side in ["l","r"]:
		var s:=1.0 if side=="l" else -1.0
		var out:=right*s
		# Determine which way is "outward" for this leg from where the hip actually is.
		var hip:=_g(sk,bones["thigh_"+side]).origin
		if hip.dot(right)*s<0.0: out=-out
		# Knees OUTSIDE the tank (not through it): thighs forward, barely down, wide out.
		# Old fwd+down*0.28+out*0.26 drove the thigh through the tank top (scrambler ~0.90 / cruiser ~1.03).
		_aim(sk,bones["thigh_"+side],bones["calf_"+side],fwd+down*0.06+out*0.50)
		# Calves drop to the pegs, more vertical now that knees sit high and wide.
		_aim(sk,bones["calf_"+side],bones["foot_"+side],down+fwd*0.04-out*0.04)
		# Boots flat on the pegs.
		var foot: int=bones["foot_"+side]
		var fg:=_g(sk,foot)
		var level:=Quaternion(fg.basis.z.normalized(),(fwd*0.9+down*0.15).normalized())
		var fparent:=sk.get_bone_parent(foot)
		var fpb:=_g(sk,fparent).basis if fparent>=0 else Basis.IDENTITY
		sk.set_bone_pose_rotation(foot,(fpb.inverse()*(Basis(level)*fg.basis)).get_rotation_quaternion())
