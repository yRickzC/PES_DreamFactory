extends CharacterBody2D
class_name PlayerSystem

@onready var movement_component: MovementComponent = $MovementComponent


func _physics_process(_delta: float) -> void:
	velocity = movement_component.get_velocity()
	move_and_slide()
