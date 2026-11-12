extends Node3D

var velocity := Vector3(0,0,-28)
var damage := 20.0
var life := 3.5
var pierce := 0
var hit_targets: Array[Node3D] = []
## The tracer only appears once the round is clear of the gun. Seen from behind the survivor a
## fresh tracer is end-on -- a bright dot on the muzzle -- and a shotgun's eight overlap into a
## glowing wedge. Nothing is drawn at the muzzle now; the streak starts a step ahead of it.
const TRACER_CLEAR := 1.3
var tracer_mesh: MeshInstance3D
static var shared_mesh: BoxMesh
static var shared_material: StandardMaterial3D
var flown := 0.0

func _ready() -> void:
	# One mesh and one material for every round ever fired. Each bullet used to make its own, and
	# when the last bullet in flight disappeared the engine dropped the shader, so the first shot
	# of the next burst had to build it again: a small stall at the start of every burst.
	if shared_mesh==null:
		shared_mesh=BoxMesh.new(); shared_mesh.size=Vector3(0.045,0.045,0.7)
		shared_material=StandardMaterial3D.new(); shared_material.albedo_color=Color("ffe292"); shared_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		shared_material.emission_enabled=true; shared_material.emission=Color("ffae42"); shared_material.emission_energy_multiplier=2.5
	var tracer := MeshInstance3D.new()
	tracer.mesh=shared_mesh
	tracer.position.z=0.25
	tracer.material_override=shared_material
	tracer.visible=false; tracer_mesh=tracer
	add_child(tracer)
	if velocity.length()>0: look_at(global_position+velocity.normalized(),Vector3.UP)

func tick(delta: float) -> void:
	position+=velocity*delta
	flown+=velocity.length()*delta
	if tracer_mesh!=null and not tracer_mesh.visible and flown>=TRACER_CLEAR: tracer_mesh.visible=true
	life-=delta
