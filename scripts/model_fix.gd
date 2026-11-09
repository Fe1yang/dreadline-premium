extends RefCounted
## Runtime fixes for the generated GLB characters (survivors, zombies, the pursuer, dogs).

## The generated meshes contain stray back-facing triangles. With back-face culling those
## faces vanish and the background shows through as little white dots, so draw both sides.
static func double_sided(root: Node) -> void:
	if root==null or not is_instance_valid(root): return
	for node in root.find_children("*","MeshInstance3D",true,false):
		var mesh_node:=node as MeshInstance3D
		if mesh_node.mesh==null: continue
		for s in range(mesh_node.mesh.get_surface_count()):
			var mat: Material=mesh_node.get_surface_override_material(s)
			if mat==null: mat=mesh_node.mesh.surface_get_material(s)
			if mat is BaseMaterial3D: (mat as BaseMaterial3D).cull_mode=BaseMaterial3D.CULL_DISABLED

## Remove the plastic shine from generated skin: high roughness, no GGX specular streak.
static func matte(root: Node) -> void:
	if root==null or not is_instance_valid(root): return
	for node in root.find_children("*","MeshInstance3D",true,false):
		var mesh_node:=node as MeshInstance3D
		if mesh_node.mesh==null: continue
		for s in range(mesh_node.mesh.get_surface_count()):
			var mat: Material=mesh_node.get_surface_override_material(s)
			if mat==null: mat=mesh_node.mesh.surface_get_material(s)
			if mat is BaseMaterial3D:
				var b:=mat as BaseMaterial3D
				b.roughness=0.88
				b.metallic=0.0
				b.specular_mode=BaseMaterial3D.SPECULAR_DISABLED

## The dog GLBs come out of the generator about 8 units tall (a survivor is about 1.8), so each
## one is scaled to a real nose-to-tail length. Returns the lift that puts its paws on the floor.
static func fit_pet(model: Node3D,length: float) -> float:
	if model==null or not is_instance_valid(model): return 0.0
	var box:=AABB(); var first:=true
	for node in model.find_children("*","MeshInstance3D",true,false):
		var mesh_node:=node as MeshInstance3D
		if mesh_node.mesh==null: continue
		var xf:=Transform3D(); var n: Node=mesh_node
		while n!=null and n!=model:
			if n is Node3D: xf=(n as Node3D).transform*xf
			n=n.get_parent()
		var b:=xf*mesh_node.get_aabb()
		box=b if first else box.merge(b); first=false
	if first: return 0.0
	var s:=length/maxf(0.001,maxf(box.size.x,box.size.z))
	model.scale=Vector3.ONE*s
	return -box.position.y*s

## The dogs are rigged with Dog_Idle / Dog_Run / Dog_Bite clips.
static func play_animation(model: Node3D,clip: String,loop:=true) -> void:
	var player:=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if player==null or not player.has_animation(clip): return
	if loop: player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	if player.current_animation!=clip or not player.is_playing(): player.play(clip,0.15)

## Paths that failed to load this session. Surfaced on the summary screen so a device
## without a console can still tell us WHICH asset is missing.
static var missing: Array = []
const LOG_PATH := "user://missing_models.log"


## Loads a scene and returns null instead of crashing when the asset is missing.
static func spawn(path: String) -> Node3D:
	var packed: Resource = load(path)
	if packed == null:
		note_missing(path)
		return null
	var node: Node3D = packed.instantiate() as Node3D
	if node == null:
		note_missing(path)
	return node


static func note_missing(path: String) -> void:
	push_error("model missing: " + path)
	BootTrace.mark("MISSING: " + path)
	if missing.has(path):
		return
	missing.append(path)
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f != null:
		for p in missing:
			f.store_line(String(p))
		f.close()