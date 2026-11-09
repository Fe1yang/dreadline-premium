extends Node3D

var velocity := Vector3.ZERO
var life := 0.5
var total_life := 0.5
var gravity := 0.0
var spin := Vector3.ZERO
var mode := "spark"
var visual: Node3D
var label: Label3D
var effect_material: StandardMaterial3D

## The effects are pooled by main_3d: the first call builds the node, every later one
## just re-arms it (arm/disarm below), so a fight allocates nothing.
func make_text(text: String,color: Color) -> void:
	mode="text"
	if label==null:
		label=Label3D.new()
		label.font=load("res://scripts/run_text.gd").font()
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
	label.text=text; label.font_size=52; label.pixel_size=0.009; label.outline_size=10
	label.modulate=color; visual=label

func make_spark(color: Color,size: float) -> void:
	mode="spark"
	if visual==null:
		var n:=MeshInstance3D.new(); var mesh:=SphereMesh.new(); mesh.radius=size; mesh.height=size*2; n.mesh=mesh
		effect_material=StandardMaterial3D.new(); effect_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		n.material_override=effect_material; add_child(n); visual=n
	effect_material.albedo_color=color

func make_drop(color: Color,size: float) -> void:
	mode="drop"
	if visual==null:
		var n:=MeshInstance3D.new(); var mesh:=SphereMesh.new(); mesh.radius=size; mesh.height=size*2.4
		mesh.radial_segments=8; mesh.rings=4; n.mesh=mesh
		effect_material=StandardMaterial3D.new(); effect_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		n.material_override=effect_material; add_child(n); visual=n
	effect_material.albedo_color=color
	if velocity.length()>0.01: visual.look_at(global_position+velocity.normalized(),Vector3.UP)

func make_shockwave(color: Color,size: float) -> void:
	mode="shockwave"
	var n:=MeshInstance3D.new(); var mesh:=TorusMesh.new(); mesh.inner_radius=size*0.78; mesh.outer_radius=size
	mesh.rings=32; mesh.ring_segments=8; n.mesh=mesh
	effect_material=StandardMaterial3D.new(); effect_material.albedo_color=color
	effect_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; effect_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	n.material_override=effect_material; add_child(n); visual=n

func make_blast(color: Color,size: float,smoke:=false) -> void:
	mode="smoke" if smoke else "blast"
	var n:=MeshInstance3D.new(); var mesh:=SphereMesh.new(); mesh.radius=size; mesh.height=size*2
	mesh.radial_segments=16; mesh.rings=8; n.mesh=mesh
	effect_material=StandardMaterial3D.new(); effect_material.albedo_color=color
	effect_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	effect_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED if not smoke else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	n.material_override=effect_material; add_child(n); visual=n

func make_part(source: Node3D,names: Array) -> void:
	mode="part"; visual=Node3D.new(); add_child(visual)
	_copy_named(source,names)

func _copy_named(node: Node,names: Array) -> void:
	var matched:=false
	if node is MeshInstance3D:
		for prefix in names:
			if node.name.begins_with(str(prefix)): matched=true; break
	if matched:
		var copy:=node.duplicate() as MeshInstance3D
		visual.add_child(copy); copy.global_transform=node.global_transform; copy.material_overlay=null
		return
	if node==null or not is_instance_valid(node): return
	for child in node.get_children(): _copy_named(child,names)

## Pool support: arm() brings a parked effect back, disarm() puts it away.
func arm(seconds: float) -> void:
	life=seconds; total_life=maxf(0.01,seconds); visible=true
	if label: label.visible=true
	elif visual: visual.visible=true; visual.scale=Vector3.ONE

func disarm() -> void:
	life=0.0; visible=false
	if label: label.visible=false
	elif visual: visual.visible=false

func tick(delta: float) -> void:
	life-=delta; position+=velocity*delta; velocity.y+=gravity*delta
	var a:=clampf(life/total_life,0,1)
	if label: label.modulate.a=a
	elif mode in ["blast","smoke","shockwave"] and visual:
		var growth: float=3.8 if mode=="shockwave" else (1.6 if mode=="smoke" else 3.0)
		visual.scale=Vector3.ONE*(1.0+(1.0-a)*growth)
		effect_material.albedo_color.a=a*(0.38 if mode=="smoke" else 0.78)
	elif mode=="drop" and visual:
		visual.scale=Vector3(0.65,0.65,2.8)*a
	elif mode=="part" and visual:
		visual.rotation+=spin*delta
		if a<0.18: visual.scale=Vector3.ONE*(a/0.18)
	elif visual: visual.scale=Vector3.ONE*a
