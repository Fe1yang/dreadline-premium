extends Node3D

var velocity := Vector3(0,0,-28)
var damage := 20.0
var life := 3.5
var pierce := 0
var hit_targets: Array[Node3D] = []

func _ready() -> void:
	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size=Vector3(0.045,0.045,0.7); tracer.mesh=mesh
	tracer.position.z=0.25
	var m := StandardMaterial3D.new(); m.albedo_color=Color("ffe292"); m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled=true; m.emission=Color("ffae42"); m.emission_energy_multiplier=2.5
	tracer.material_override=m
	add_child(tracer)
	if velocity.length()>0: look_at(global_position+velocity.normalized(),Vector3.UP)

func tick(delta: float) -> void:
	position+=velocity*delta
	life-=delta
