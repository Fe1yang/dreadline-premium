extends Node3D

const REAL_SCALE := 0.62

var health := 1.0
var dead := false
var radius := 0.28
var height := 0.91
var model: Node3D

func _ready() -> void:
	model = load("res://assets/models/barrel.glb").instantiate() as Node3D
	model.scale = Vector3.ONE*REAL_SCALE
	add_child(model)

func tick(delta: float) -> void:
	# main advances barrels with world_speed instead; scrolling here fought it
	pass

func take_hit(amount: float) -> bool:
	health-=amount
	if health<=0: dead=true
	return dead
