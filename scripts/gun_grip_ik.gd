extends SkeletonModifier3D
## Holds the survivors' arms in a straight-armed two-hand gun stance on top of the run clip.
## Their meshes have almost no forearm skin weights, so any strong elbow bend collapses the
## forearm ("short arm") and the bent clip pressed flat palms together ("seal hands").
## This modifier places both hands on the weapon with near-straight elbows and straight wrists.

## Where the support (left) hand sits relative to the firing hand, along the barrel (metres).
@export var support_forward:=0.03
@export var support_side:=0.11     # gap between the two hands so they don't overlap/cross
@export var support_drop:=0.03
@export var grip_drop:=0.10       # how far below shoulder height the gun is held
@export var straightness:=0.965   # fraction of full arm length used to reach the grip
@export var palm_roll_r:=0.0     # wrist roll around the forearm (0 = palm down under the gun)
@export var palm_roll_l:=0.0
@export var weight:=1.0
## Character-specific posture trim: Mason, Riley, Darius, Maya. The shared run clip
## pushes the chest and clavicles too far forward; correct it before solving the arms.
@export var character:=0
## One-handed stance: only the firing arm is solved, the support arm keeps its clip pose.
@export var single_hand:=false

var b:={}
var lengths:={}
var forward:=Vector3(0,0,1)
var grip_point:=Vector3.ZERO      # skeleton space, last computed visible firing-hand position
var support_point:=Vector3.ZERO   # visible support-hand position; weapon sits at the midpoint
## Offset from each hand bone to where that hand's mesh actually is (bone space). The female
## survivor shares the male skeleton but has shorter arms, so her visible hands sit short of
## the hand bones; IK aims the *visible* hands at the grip and the gun mounts there.
var hand_offset:={"r":Vector3.ZERO,"l":Vector3.ZERO}
var _ready_bones:=false

## The shared Run_Gun clip bakes a hunched upper body into the pose: neck_01 carries
## +15 deg head-down pitch and +13 deg yaw, spine_03 +18 deg chest yaw and +9 deg pitch.
## Left alone that reads as a hunchback on the female rigs and as a bent spine on all of
## them. These keep-rates flatten it after the clip has played (1.0 = untouched).
const NECK_PITCH_KEEP:=0.30
const NECK_TWIST_KEEP:=0.12
const SPINE_TWIST_KEEP:=0.22

func _setup(sk: Skeleton3D) -> void:
	for n in ["upperarm_r","lowerarm_r","hand_r","upperarm_l","lowerarm_l","hand_l","spine_01","spine_02","spine_03","neck_01","Head","clavicle_r","clavicle_l","foot_l","ball_l"]:
		b[n]=sk.find_bone(n)
	for side in ["r","l"]:
		var u:=sk.get_bone_global_rest(b["upperarm_"+side]).origin
		var lo:=sk.get_bone_global_rest(b["lowerarm_"+side]).origin
		var h:=sk.get_bone_global_rest(b["hand_"+side]).origin
		lengths[side]=[u.distance_to(lo),lo.distance_to(h)]
	if b.foot_l>=0 and b.ball_l>=0:
		var toe:=sk.get_bone_global_rest(b.ball_l).origin-sk.get_bone_global_rest(b.foot_l).origin
		forward=Vector3(0,0,signf(toe.z) if absf(toe.z)>0.001 else 1.0)
	_ready_bones=true

func _trim_euler(sk: Skeleton3D,bone: int,pitch_keep: float,twist_keep: float) -> void:
	var e:=sk.get_bone_pose(bone).basis.get_euler()
	e.x*=pitch_keep
	e.y*=twist_keep
	e.z*=twist_keep
	sk.set_bone_pose_rotation(bone,Quaternion.from_euler(e))

func _relax_to_rest(sk: Skeleton3D,bone: int,amount: float) -> void:
	var pose:=sk.get_bone_pose(bone).basis.get_rotation_quaternion()
	var rest:=sk.get_bone_rest(bone).basis.get_rotation_quaternion()
	sk.set_bone_pose_rotation(bone,pose.slerp(rest,amount).normalized())

func _process_modification() -> void:
	var sk:=get_skeleton()
	if sk==null or weight<=0.0: return
	if not _ready_bones: _setup(sk)
	var pitch: float=[0.60,0.42,0.52,0.46][clampi(character,0,3)]
	# Shoulder relaxation stays at the value the grip was tuned against: pulling the
	# clavicles further toward rest swings the upper arms inward and buries them in the chest.
	var shoulder: float=[0.58,0.68,0.60,0.64][clampi(character,0,3)]
	_trim_euler(sk,b.spine_01,1.0,0.30)
	_trim_euler(sk,b.spine_02,1.0,SPINE_TWIST_KEEP)
	_trim_euler(sk,b.spine_03,pitch,SPINE_TWIST_KEEP)
	# Flatten the baked-in head-down / head-turn of the shared run clip: this is what made
	# the survivors look hunched (worst on the female rigs, whose neck is longer).
	if b.neck_01>=0: _trim_euler(sk,b.neck_01,NECK_PITCH_KEEP,NECK_TWIST_KEEP)
	if b.Head>=0: _trim_euler(sk,b.Head,0.55,0.35)
	_relax_to_rest(sk,b.clavicle_r,shoulder)
	_relax_to_rest(sk,b.clavicle_l,shoulder)
	# Darius' bare right biceps/triceps fan out under the shared run twist. Trim only
	# the upper-arm radial axes; cancel it on the forearm so its length and hands stay put.
	var upper_r:=0.86 if character==2 else 1.0
	sk.set_bone_pose_scale(b.upperarm_r,Vector3(upper_r,1.0,upper_r))
	sk.set_bone_pose_scale(b.lowerarm_r,Vector3(1.0/upper_r,1.0,1.0/upper_r))
	sk.set_bone_pose_scale(b.upperarm_l,Vector3.ONE)
	sk.set_bone_pose_scale(b.lowerarm_l,Vector3.ONE)
	var sr:=_g(sk,b.upperarm_r).origin
	var sl:=_g(sk,b.upperarm_l).origin
	if character==4:
		# His bind pose keeps the shoulder joints inside the chest, so the arm mesh reads as
		# growing out of the sternum no matter how the clavicle is relaxed. Slide both
		# upper-arm roots outward along the shoulder line before anything is measured.
		var out_dir:=(sr-sl).normalized()
		var gr:=_g(sk,b.upperarm_r)
		var glf:=_g(sk,b.upperarm_l)
		_set_g(sk,b.upperarm_r,Transform3D(gr.basis,gr.origin+out_dir*0.05))
		_set_g(sk,b.upperarm_l,Transform3D(glf.basis,glf.origin-out_dir*0.05))
		sr=_g(sk,b.upperarm_r).origin
		sl=_g(sk,b.upperarm_l).origin
	var chest:=(sr+sl)*0.5
	var side_axis:=(sl-sr).normalized() # points from right shoulder to left shoulder
	var fwd:=(forward-side_axis*forward.dot(side_axis)).normalized()
	var down:=(Vector3.DOWN-fwd*Vector3.DOWN.dot(fwd)).normalized()
	# Mason must retain a slight elbow bend. Pushing his wrist beyond the natural reach
	# made the right forearm look stretched; his gun already has a forward mount offset.
	var arm_reach:=0.91 if character==0 else straightness
	var reach_r:=(float(lengths.r[0])+float(lengths.r[1]))*arm_reach
	var lateral:=sr.distance_to(chest)-0.02
	var depth:=sqrt(maxf(0.01,reach_r*reach_r-lateral*lateral-grip_drop*grip_drop))
	# Separate Mason's broad palms. The support hand is slightly ahead and lower so
	# his fingers do not cross from the chase view, without moving either wrist farther out.
	var hand_gap:=0.24 if character==0 else 0.13
	var forward_push:=0.0 if character==0 else 0.025
	var firing_side:=0.025
	var support_reach:=support_forward+(0.035 if character==0 else 0.0)
	var support_level:=support_drop+(0.025 if character==0 else 0.0)
	# Yuhang's rig carries a long hand offset (0.206 m ahead of the wrist) and a short, wide
	# torso, so the shared numbers fold his arms against the chest. Hold him wider and a
	# little further forward so the pair of arms reads extended instead of tucked in.
	if character==4:
		# His shoulders sit gathered toward the sternum in the shared run clip; relax the
		# clavicles a second time so the upper arms start at the actual shoulder joints
		# instead of appearing to grow out of the chest.
		_relax_to_rest(sk,b.clavicle_r,0.60)
		_relax_to_rest(sk,b.clavicle_l,0.60)
		# His forearms have almost no skin weights, so a bent elbow collapses the forearm and
		# the hands end up sitting on the chest. Use the straight-armed stance (same idea as
		# Mason) instead: near-full extension hides the missing forearm deformation.
		hand_gap=0.24
		forward_push=0.02
		firing_side=0.03
		arm_reach=0.96
		reach_r=(float(lengths.r[0])+float(lengths.r[1]))*arm_reach
		depth=sqrt(maxf(0.01,reach_r*reach_r-lateral*lateral-grip_drop*grip_drop))
	var want_r:=chest+fwd*(depth+forward_push)+down*grip_drop-side_axis*firing_side
	var want_l:=want_r+fwd*support_reach+down*support_level+side_axis*hand_gap
	grip_point=_reach(sk,"r",want_r,-side_axis*0.8+down*0.6,palm_roll_r,fwd)
	if single_hand:
		# the support hand keeps whatever the animation is doing, and the weapon only rides the
		# firing hand, so the gun ends up exactly in the visible palm
		support_point=grip_point
		return
	support_point=_reach(sk,"l",want_l,side_axis*0.8+down*0.6,palm_roll_l,fwd)

## Solves so the visible hand (bone + mesh offset) lands on `want`; returns where it landed.
func _reach(sk: Skeleton3D,side: String,want: Vector3,pole: Vector3,roll: float,fwd: Vector3) -> Vector3:
	var target:=want
	var ih:int=b["hand_"+side]
	var off: Vector3=hand_offset[side]
	for i in range(3):
		_solve(sk,side,target,pole,roll,fwd)
		var visible:=_g(sk,ih)*off
		target+=want-visible
	return _g(sk,ih)*off

## Bone-space centre of the vertices skinned mostly to the hand (palm + fingers + thumb),
## i.e. where the hand mesh really is relative to the hand bone.
static func mesh_offset(model: Node,bone: String) -> Vector3:
	var suffix:=bone.substr(bone.length()-2) # "_r" / "_l"
	for m in model.find_children("*","MeshInstance3D",true,false):
		var mi:=m as MeshInstance3D
		if mi.skin==null: continue
		var hand_index:=-1; var group:={}
		for i in range(mi.skin.get_bind_count()):
			var name:=str(mi.skin.get_bind_name(i))
			if name==bone: hand_index=i
			if name==bone or (name.ends_with(suffix) and (name.begins_with("thumb") or name.begins_with("index") or name.begins_with("middle") or name.begins_with("ring") or name.begins_with("pinky"))): group[i]=true
		if hand_index<0: continue
		var arrays:=mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		var per:=bones.size()/maxi(1,verts.size())
		var sum:=Vector3.ZERO; var count:=0
		for v in range(verts.size()):
			var w:=0.0
			for k in range(per):
				if group.has(bones[v*per+k]): w+=weights[v*per+k]
			if w>0.6: sum+=verts[v]; count+=1
		if count>0:
			return mi.skin.get_bind_pose(hand_index)*(sum/count)
		continue
	return Vector3.ZERO

func _solve(sk: Skeleton3D,side: String,target: Vector3,pole: Vector3,roll: float,fwd: Vector3) -> void:
	var iu:int=b["upperarm_"+side]; var il:int=b["lowerarm_"+side]; var ih:int=b["hand_"+side]
	var root:=_g(sk,iu).origin
	var l1: float=lengths[side][0]; var l2: float=lengths[side][1]
	var to_t:=target-root
	var d:=clampf(to_t.length(),0.05,(l1+l2)*0.999)
	var n:=to_t.normalized()
	var along:=(l1*l1-l2*l2+d*d)/(2.0*d)
	var h:=sqrt(maxf(0.0,l1*l1-along*along))
	var p:=pole-n*pole.dot(n)
	if p.length()<0.001: p=Vector3.DOWN
	var elbow:=root+n*along+p.normalized()*h
	var hinge:=n.cross(p).normalized()
	_aim(sk,iu,il,elbow,hinge)
	_aim(sk,il,ih,root+n*d,hinge)
	# Straight wrist: hand continues the forearm, then roll so the palm wraps the grip.
	var lg:=_g(sk,il)
	var hg:=_g(sk,ih)
	var forearm_axis:=(hg.origin-lg.origin).normalized()
	var hand_basis:=Basis(forearm_axis,roll)*lg.basis
	_set_g(sk,ih,Transform3D(hand_basis,hg.origin))

func _aim(sk: Skeleton3D,bone: int,child: int,point: Vector3,hinge: Vector3) -> void:
	var g:=_g(sk,bone)
	var cur:=_g(sk,child).origin-g.origin
	var want:=point-g.origin
	if cur.length()<0.0001 or want.length()<0.0001: return
	var y:=want.normalized()
	var x:=(hinge-y*hinge.dot(y)).normalized()
	if x.length()<0.001 or x.dot(g.basis.x)<0.0: x=-x
	if x.length()<0.001:
		var q:=Quaternion(cur.normalized(),y)
		_set_g(sk,bone,Transform3D(Basis(q)*g.basis,g.origin))
		return
	var z:=x.cross(y).normalized()
	_set_g(sk,bone,Transform3D(Basis(x,y,z),g.origin))

# Global poses from current local poses (the skeleton's global cache is stale mid-modifier).
func _g(sk: Skeleton3D,bone: int) -> Transform3D:
	var parent:=sk.get_bone_parent(bone)
	var local:=sk.get_bone_pose(bone)
	return local if parent<0 else _g(sk,parent)*local

func _set_g(sk: Skeleton3D,bone: int,global: Transform3D) -> void:
	var parent:=sk.get_bone_parent(bone)
	var local:=global if parent<0 else _g(sk,parent).affine_inverse()*global
	sk.set_bone_pose_position(bone,local.origin)
	sk.set_bone_pose_rotation(bone,local.basis.get_rotation_quaternion())
