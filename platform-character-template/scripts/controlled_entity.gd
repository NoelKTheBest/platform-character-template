@abstract extends CharacterBody2D
## A class meant for providing base implementation for an entity affected by gravity
## and that can move at a specified [b]speed[/b]

## Base speed of enemy
@export var speed := 2
@export_group("Random Speed Increase")
## Low end of range for random speed increasing 
@export var range_bottom := 0.1
## High end of range for random speed increasing
@export var range_top := 1.0

var debug = false

## amount to increase speed by to differentiate it this body's speed slightly from similar entities of the same type 
var random_speed_inc
## Used to check for sudden changes in x velocity
var prev_x_velocity = 0.0
## Used to check for sudden changes in y velocity
var prev_y_velocity = 0.0
## Initial position for player hitboxes
var hitbox_init_pos : Vector2
## Initial position for collider
var collider_init_pos: Vector2
## Initial position for hurtbox
var hurtbox_init_pos: Vector2


## Sets random_speed_inc for entity
func _ready() -> void:
	random_speed_inc = randf_range(range_bottom, range_top)
	speed += random_speed_inc
	


func _physics_process(delta: float) -> void:
	
	#print(i, "; 1st; ", velocity.x)
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Set default behaviour to not move
	velocity.x = move_toward(velocity.x, 0, speed)
	
	# Move and slide applied to set gravity of character body
	move_and_slide()
	
	# Detect change in x velocity to play impact sounds and vfx
	if velocity.x == 0 and prev_x_velocity != 0:
		impact()
	
	# Detect change in y velocity to play impact sounds and vfx
	if velocity.y == 0 and prev_y_velocity != 0:
		land_on_ground()
	
	prev_x_velocity = velocity.x
	prev_y_velocity = velocity.y


## Use to play an impact sound effect
func impact():
	#print("Play sfx and vfx")
	pass


## Use to play sfx and vfx and set any necessary variables
func land_on_ground():
	#print("Play sfx")
	pass


## Detects whether the current object the script is attached to has a child by a certain name
## Useful for making modular behaviour
func has_child(child_name: StringName):
	var children = get_children()
	
	for c in children:
		if c.name == child_name:
			return true
	
	return false


## Prints the current velocity
func print_velocity():
	if debug: print(velocity.x, "; ", speed, "; ", name)
