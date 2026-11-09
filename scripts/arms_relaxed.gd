extends SkeletonModifier3D
## Lobby pose fix: the retargeted idle clip bends the survivors' elbows so their hands rest on
## their hips, and bending the forearm/wrist stretches the mesh (the survivors' forearms carry
## almost no skin weights). Here the forearm and hand are locked to the mesh's own bind pose,
## so the arm moves as one rigid piece with no stretching. The upper arm then swings the arm
## down beside the thigh and twists it so the palm faces the body.

@export var outward:=0.12   # how far the arms angle away from the thighs
@export var forward:=0.04
@export var weight:=1.0
## Extra roll (degrees) about the arm for meshes whose hands are not modelled the way the shared
## skeleton expects (the female mesh). Mirrored for the left arm.
@export var palm_twist_deg:=0.0
## Lowering the arm only at the shoulder joint bunches the shoulder up (a shrug); dropping the
## collarbone this many degrees first lets the shoulders sit low and level.
@export var clavicle_drop:=0.0
## Base elbow bend (degrees) for stances that should never hang the arms straight:
## the T-pose sculpted shoulder rips when the arm drops vertically, so the female
## idle keeps the elbows bent and the hands hovering in front of the hips.
@export var base_bend:=0.0
## Half-fist finger curl (degrees at the proximal phalanx): no hand hangs with
## fingers perfectly straight -- a relaxed hand is a natural half-fist. Applied
## to index/middle/ring/pinky; the thumb tucks ~60% as much.
## Per-side extras for idle actions (set every frame by IdleLife): forward lift of the arm
## (same units as `forward`) and a forward elbow bend in degrees.
var lift:={"r":0.0,"l":0.0}
var bend:={"r":0.0,"l":0.0}
## Half-fist curl in degrees (proximal phalanx); middle knuckle curls ~1.3x as much.
## Default 0: bone-space finger curl tears the low-poly male glove (see Mason right hand).
## Half-fist is baked into the mesh in Blender instead (tools/fix_riley_hand.py).
var finger_curl:=0.0
## extra roll of the whole arm about its own axis (degrees, mirrored per side), so a bent
## forearm swings in across the body instead of out to the side
var roll:={"r":0.0,"l":0.0}

var body: Node3D # the character root; its +Z is the way the character faces
## Bone-space offset from each hand bone to where its mesh hand really is (see GunGripIK.mesh_offset).
var hand_offset:={"r":Vector3.ZERO,"l":Vector3.ZERO}

var bones:={}
var bind_local:={}   # bone -> local bind-pose rotation (relative to its parent)
var chain:={}        # side -> names of every bone below the upper arm
var palm_axis:={}    # side -> palm normal in hand-bone space (from the bind pose)

func setup_from_model(model: Node,sk: Skeleton3D) -> void:
	var skin: Skin=null
	for m in model.find_children("*","MeshInstance3D",true,false):
		if (m as MeshInstance3D).skin: skin=(m as MeshInstance3D).skin; break
	if skin==null: return
	var global_bind:={}
	for i in range(skin.get_bind_count()):
		var name:=str(skin.get_bind_name(i))
		if name=="": name=sk.get_bone_name(skin.get_bind_bone(i))
		global_bind[name]=skin.get_bind_pose(i).affine_inverse()
	for side in ["r","l"]:
		for n in ["clavicle_"+side,"upperarm_"+side,"lowerarm_"+side,"hand_"+side]:
			bones[n]=sk.find_bone(n)
		# Every bone below the upper arm (forearm, twist bones, wrist, fingers) gets its bind pose.
		var below: Array=[]
		var stack: Array=[bones["upperarm_"+side]]
		while not stack.is_empty():
			var cur_bone: int=stack.pop_back()
			for child in sk.get_bone_children(cur_bone):
				below.append(sk.get_bone_name(child)); stack.append(child)
		chain[side]=below
		for n in below:
			var bi: int=sk.find_bone(n); var parent:=sk.get_bone_parent(bi)
			if bi<0 or parent<0 or not global_bind.has(n): continue
			var pname:=sk.get_bone_name(parent)
			var pg: Transform3D=global_bind[pname] if global_bind.has(pname) else sk.get_bone_global_rest(parent)
			bind_local[n]=(pg.affine_inverse()*global_bind[n]).basis.get_rotation_quaternion()
		# Palm direction measured on the mesh itself: the female mesh's hands are not oriented
		# like the shared skeleton's hand bones, so the bone axes can't be trusted for this.
		var hand_name: String="hand_"+side
		if global_bind.has(hand_name):
			var palm_mesh:=_mesh_palm_normal(model,side)
			if palm_mesh==Vector3.ZERO: palm_mesh=Vector3.DOWN
			palm_axis[side]=(global_bind[hand_name] as Transform3D).basis.inverse()*palm_mesh
	bones["ok"]=bones.values().all(func(v): return int(v)>=0)

## Palm normal (mesh/bind space) from vertex groups: fingers give the hand's length, the thumb
## gives its width; palm = finger x thumb, signed per side so it points out of the palm.
func _mesh_palm_normal(model: Node,side: String) -> Vector3:
	var suffix:="_"+side
	for m in model.find_children("*","MeshInstance3D",true,false):
		var mi:=m as MeshInstance3D
		if mi.skin==null: continue
		var groups:={} # bind index -> "hand" / "finger" / "thumb"
		for i in range(mi.skin.get_bind_count()):
			var name:=str(mi.skin.get_bind_name(i))
			if not name.ends_with(suffix): continue
			if name=="hand"+suffix: groups[i]="hand"
			elif name.begins_with("thumb"): groups[i]="thumb"
			elif name.begins_with("index") or name.begins_with("middle") or name.begins_with("ring") or name.begins_with("pinky"): groups[i]="finger"
		if groups.is_empty(): continue
		var arrays:=mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var vb: PackedInt32Array=arrays[Mesh.ARRAY_BONES]; var vw: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		var per:=vb.size()/maxi(1,verts.size())
		var sums:={"hand":Vector3.ZERO,"finger":Vector3.ZERO,"thumb":Vector3.ZERO}; var counts:={"hand":0,"finger":0,"thumb":0}
		for v in range(verts.size()):
			for k in range(per):
				var bi: int=vb[v*per+k]
				if vw[v*per+k]>0.6 and groups.has(bi):
					var g: String=groups[bi]; sums[g]+=verts[v]; counts[g]+=1
		if counts.hand==0 or counts.finger==0 or counts.thumb==0: continue
		var hand_c: Vector3=sums.hand/counts.hand
		var finger: Vector3=(sums.finger/counts.finger-hand_c).normalized()
		var thumb: Vector3=(sums.thumb/counts.thumb-hand_c); thumb-=finger*thumb.dot(finger)
		var n: Vector3=finger.cross(thumb.normalized()).normalized()
		return -n if side=="r" else n
	return Vector3.ZERO

## Global (skeleton-space) pose computed from local poses: the global cache is stale mid-modifier.
func _g(sk: Skeleton3D,bone: int) -> Transform3D:
	var t:=sk.get_bone_pose(bone)
	var p:=sk.get_bone_parent(bone)
	while p>=0:
		t=sk.get_bone_pose(p)*t; p=sk.get_bone_parent(p)
	return t

func _rotate_global(sk: Skeleton3D,bone: int,rot: Quaternion) -> void:
	var g:=_g(sk,bone)
	var new_global:=Basis(rot)*g.basis
	var parent:=sk.get_bone_parent(bone)
	var parent_basis:=_g(sk,parent).basis if parent>=0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(bone,(parent_basis.inverse()*new_global).get_rotation_quaternion())

func _process_modification() -> void:
	var sk:=get_skeleton()
	if sk==null or not bones.get("ok",false): return
	var to_skel:=sk.global_transform.basis.orthonormalized().inverse()
	var root: Node3D=body if is_instance_valid(body) else sk
	var fwd_w:=root.global_transform.basis.z.normalized()
	var down:=(to_skel*Vector3.DOWN).normalized()
	var fwd:=(to_skel*fwd_w).normalized()
	for side in ["r","l"]:
		var up: int=bones["upperarm_"+side]; var lo: int=bones["lowerarm_"+side]; var hd: int=bones["hand_"+side]
		# 0. Collarbone down a little so the shoulder doesn't bunch up when the arm hangs.
		if absf(clavicle_drop)>0.01:
			var cl: int=bones["clavicle_"+side]
			var d: Vector3=_g(sk,up).origin-_g(sk,cl).origin
			var ax: Vector3=d.cross(down)
			if ax.length()>0.0001: _rotate_global(sk,cl,Quaternion(ax.normalized(),deg_to_rad(clavicle_drop)))
		# 1. Rigid forearm + wrist straight from the mesh's bind pose: no stretching.
		for n in chain.get(side,[]):
			if bind_local.has(n): sk.set_bone_pose_rotation(sk.find_bone(n),bind_local[n])
		# 2. Swing the arm so the visible hand hangs beside the thigh.
		var shoulder_w:=sk.global_transform*_g(sk,up).origin
		var side_w:=shoulder_w-root.global_transform.origin; side_w-=fwd_w*side_w.dot(fwd_w); side_w.y=0
		var out:=(to_skel*side_w.normalized()).normalized() if side_w.length()>0.001 else Vector3.ZERO
		var want:=(down+out*outward+fwd*(forward+float(lift[side]))).normalized()
		for pass_i in range(2):
			var g:=_g(sk,up); var tip: Vector3=_g(sk,hd)*(hand_offset[side] as Vector3)
			var cur: Vector3=tip-g.origin
			if cur.length()<0.001: break
			_rotate_global(sk,up,Quaternion.IDENTITY.slerp(Quaternion(cur.normalized(),want),weight))
		# 3. Twist the whole arm about its own axis so the palm faces the body.
		if palm_axis.has(side):
			var axis: Vector3=(_g(sk,hd)*(hand_offset[side] as Vector3)-_g(sk,up).origin).normalized()
			var palm: Vector3=(_g(sk,hd).basis*(palm_axis[side] as Vector3)).normalized()
			var inward:=-out
			var p0: Vector3=palm-axis*palm.dot(axis); var p1: Vector3=inward-axis*inward.dot(axis)
			if p0.length()>0.01 and p1.length()>0.01:
				var angle: float=p0.normalized().signed_angle_to(p1.normalized(),axis)
				angle+=deg_to_rad(palm_twist_deg)*(1.0 if side=="r" else -1.0)
				_rotate_global(sk,up,Quaternion(axis,angle*weight))
		var rl: float=float(roll[side])
		if absf(rl)>0.5:
			var rax: Vector3=(_g(sk,hd).origin-_g(sk,up).origin).normalized()
			_rotate_global(sk,up,Quaternion(rax,deg_to_rad(rl)*(1.0 if side=="r" else -1.0)*weight))
		# 4. Optional forward elbow bend for idle actions (the forearm skin holds up to ~90°).
		var b: float=float(bend[side])+base_bend
		if b>0.5:
			var arm_dir: Vector3=(_g(sk,hd).origin-_g(sk,lo).origin).normalized()
			var bax: Vector3=arm_dir.cross(fwd)
			if bax.length()>0.0001: _rotate_global(sk,lo,Quaternion(bax.normalized(),deg_to_rad(b)*weight))
		# 5. Half-fist: curl every finger toward the palm (bind fingers are dead straight).
		if absf(finger_curl)>0.5 and palm_axis.has(side):
			var palm_n: Vector3=(_g(sk,hd).basis*(palm_axis[side] as Vector3)).normalized()
			var hand_o: Vector3=_g(sk,hd).origin
			for finger in ["index","middle","ring","pinky"]:
				for ph in [1,2,3]:
					var fname: String="%s_%02d_%s"%[finger,ph,side]
					var fb: int=sk.find_bone(fname)
					if fb<0: continue
					var fdir: Vector3=(_g(sk,fb).origin-hand_o)
					if fdir.length()<0.001: continue
					# curl axis = palm normal x finger direction (sign chosen so the tip moves toward the palm)
					var ax2: Vector3=palm_n.cross(fdir.normalized())
					if ax2.length()<0.001: continue
					var deg: float=finger_curl*(1.3 if ph==2 else (1.0 if ph==1 else 0.8))
					# finger tips curl toward the palm normal: +rotation about palm x finger moves the
					# tip away from the palm, so apply negative angle.
					_rotate_global(sk,fb,Quaternion(ax2.normalized(),-deg_to_rad(deg)*weight))
			# thumb: lighter curl, tucks across the front of the fist
			for ph in [1,2,3]:
				var tname: String="thumb_%02d_%s"%[ph,side]
				var tb: int=sk.find_bone(tname)
				if tb<0: continue
				var tdir: Vector3=(_g(sk,tb).origin-hand_o)
				if tdir.length()<0.001: continue
				var tax: Vector3=palm_n.cross(tdir.normalized())
				if tax.length()<0.001: continue
				_rotate_global(sk,tb,Quaternion(tax.normalized(),-deg_to_rad(finger_curl*0.6)*weight))
