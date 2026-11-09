extends Node3D

var kind := "frag"
var velocity := Vector3.ZERO
var fuse := 1.2
var gravity := -11.5
var detonate_requested := false
var age := 0.0
var bounces := 0
var visual: Node3D

# Lazy paths for the same reason as pickup_3d.gd: preloads of .glb abort the first import.
const MODEL_PATHS := {
	"frag": "res://assets/models/frag_grenade.glb",
	"flash": "res://assets/models/flashbang.glb",
	"launcher": "res://assets/models/frag_grenade.glb",
	"fire": "res://assets/models/fire_round.glb",
	"molotov": "res://assets/models/weapons/molotov.glb"
}
const SCALES := {"frag": 1.8, "flash": 1.8, "launcher": 1.35, "fire": 2.0}

func _ready() -> void:
	var path: String = MODEL_PATHS.get(kind, MODEL_PATHS["frag"])
	var packed: PackedScene = load(path) as PackedScene
	visual = packed.instantiate() as Node3D if packed != null else null
	if visual == null:
		push_error("ordnance model missing or broken: " + path)
		visual = Node3D.new() # invisible placeholder: the projectile still flies
	visual.scale = Vector3.ONE * float(SCALES.get(kind, 1.8))
	add_child(visual)
	if kind == "flash": fuse = 0.9
	elif kind in ["launcher", "fire"]: fuse = 2.4
	elif kind == "molotov": fuse = 1.7
	var light := OmniLight3D.new()
	light.position.y = 0.08
	light.omni_range = 0.85
	light.light_energy = 0.28
	light.light_color = Color("ff7138") if kind == "fire" else (Color("bdefff") if kind == "flash" else Color("ffd275"))
	add_child(light)

func tick(delta: float) -> void:
	if detonate_requested: return
	age += delta
	fuse -= delta
	velocity.y += gravity * delta
	position += velocity * delta
	visual.rotate_x(delta * 7.5)
	visual.rotate_z(delta * 4.0)
	if position.y <= 0.10:
		position.y = 0.10
		if kind in ["launcher", "fire"]:
			detonate_requested = true
		elif velocity.y < 0.0 and bounces < 3:
			velocity.y = -velocity.y * 0.30
			velocity.x *= 0.68
			velocity.z *= 0.68
			bounces += 1
		else:
			velocity = Vector3.ZERO
	if fuse <= 0.0: detonate_requested = true
