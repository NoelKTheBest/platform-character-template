@abstract extends "controlled_entity.gd"
## This class is meant to provide functions and some basic implementation to 
## allow the entity to choose a position to go towards

## Determines if entity should walk from position to position in an area and
## waiting to see if the player enters their FOV. Overrides [b]monitor_player_position[/b]
@export var on_patrol = true
## Determines if entity should stay in position as part of a squadron. Overrides [b]on_patrol[/b]
@export var on_guard := true
@export_group("Patrol")
## Amount of time to wait at end of the patrol area before changing direction (Not implemented yet)
@export var patrol_wait := 1.0
@export_subgroup("Patrol Bounds")
## Start position for patrol area
@export var patrol_start := Vector2.ZERO
## End position for patrol area
@export var patrol_end := Vector2.ZERO
@export_group("Guard Bounds")
## Start position for guard bounds
@export var guard_bound_start: float
## End position for guard bounds
@export var guard_bound_end: float

## Internal variable for checking if the entity should pursue the player
var monitor_player_position = false
## Internal variable for player's position
var player_position = Vector2.ZERO
## Determines whether the player is seen by a patrolling entity
var player_is_seen: bool
## Last known player position when patrolling
var patrolling_last_known_pos: Vector2
## Determines if player was just lost on this frame when patrolling
var player_was_just_lost
## Not in use
var camera_position := Vector2.ZERO
## Not in use
var sound_source_position := Vector2.ZERO
## Position of nearest door that gets the entity closer to player
var nearest_door_position := Vector2.ZERO
## Number of the floor the entity is currently on
var current_floor : int
## Determines whether the entity is trying to use a door or not
var using_door: bool = false
## Number of the destination floor the entity wants to reach
var destination_floor: int

## Initial position of entity if [b]on_guard[/b] is true
var squad_position
## Determines whether the entity was initially on guard at the start of the scene
var initially_guarding := false
## Determines whether the entity was initially patrolling at the start of the scene
var initially_patrolling := false
## The target position of the entity on patrol
var patrol_target_position: Vector2
## Determines whether the entity is waiting to turn around
var waiting_to_turn_around := false

## Not in use
var player_out_of_range: bool = true

#region CopiedVars
## Array used in determining whether to enter or exist the patrol state based on
## if a character body has been detected
var bodies = []
## The scale at which to change visibility area based on how close the player gets to the entity
@export var vision_scale: float = 1.5
#endregion


## Sets [b]squad_position[/b] to current position if [b]on_guard[/b] is set to true
func _ready() -> void:
	super()
	
	if on_patrol and !on_guard:
		initially_patrolling = true
		# Make sure patrol bounds are set
		# Add in a wait period so the entity, stays at a location for a bit and then turns around and walks the other way
		# default bounds to keep the enemies understanding their position and state
		patrol_start = position - Vector2(40, 0)
		patrol_end = position + Vector2(40, 0)
		choose_initial_direction()
		
		# Add a VisibilityArea node as default. If added manually, I can change the shape and size of the area if needed
		var visibility_area = load("res://game/scenes/visibility_area.tscn")
		var new_visibility_area = visibility_area.instantiate()
		add_child(new_visibility_area)
		# we need to make sure that the scale of visibility area is reversed so it goes where the player thinks the enemy is going to go 
	
	# guard state should overrride patrol state
	if on_guard:
		squad_position = position
		initially_guarding = true
		# use magic numbers for now to make the logic easier to understand and implement
		# default bounds to keep the enemies understanding their position and state
		guard_bound_start = position.x - 75
		guard_bound_end = position.x + 75
		
		# Add GuardArea node as default. If added manually, I can change slightly the size or shape of the area if i so choose
		var guard_area = load("res://game/scenes/guard_area.tscn")
		var new_guard_area = guard_area.instantiate()
		add_child(new_guard_area)


func _physics_process(delta: float) -> void:
	super(delta)
	
	if on_patrol and !initially_guarding:
		monitor_player_position = false
		
		velocity.x = (patrol_target_position - position).normalized().x * (speed / 4.0)
		if abs(patrol_target_position.x - position.x) < 1: velocity.x = 0.0
		if !waiting_to_turn_around: check_for_end_of_area()
	
	if initially_patrolling:
		set_monitor_player_status()
	
	if initially_guarding:
		# if we are on guard, we should stay that way for the entire frame so everything that needs to happen bc of it is predictable
		if on_guard:
			monitor_player_position = false # do not pursue player
			on_patrol = false # do not patrol area
			
			# return to squad_position
			velocity.x = (squad_position - position).normalized().x * speed
			if abs(squad_position.x - position.x) < 1: velocity.x = 0.0
		else:
			monitor_player_position = true # pursue player if they get too close
			# We need to check to make sure that entities that are on gaurd will 
			# return to their gaurd position if the player moves out of their guard range
	
	if !on_guard and !on_patrol:
		player_position = SceneVariables.player_position
		velocity.x = get_target_position().x * speed
	
	# move to basic entity if we need to make sure basic entity doesn't override this code
	# If entity is outside of guard bounds
	if (position.x < guard_bound_start or position.x > guard_bound_end):
		# and was initially guarding and not on_guard
		if initially_guarding and !on_guard:
			on_guard = true # Go back to guard position (squad_position)


## Function to implement to set the target position of the entity based on position relative to player
func get_target_position() -> Vector2:
	var target_position: Vector2 = position
	
	if monitor_player_position: # and number_of_enemies < min_req_for_helping:
		if nearest_door_position != Vector2.ZERO:
			if !using_door: using_door = true
			target_position = (nearest_door_position - position).normalized()
		else:
			if using_door: using_door = false
			target_position = (player_position - position).normalized()
			#print_rich("[color=green]:)")
			#print(target_position, "; ", player_position)
	#else:
		#velocity.x = move_toward(velocity.x, 0, speed) # remove lines
		# We should be setting target position to something that will force the enemy to stay in place and then not move
	
	return target_position.normalized()


## Automatically changes [b]patrol_target_position[/b] to whatever direction the entity is facing
func choose_initial_direction():
	if $Sprite2D.flip_h:
		patrol_target_position = patrol_start
	else:
		patrol_target_position = patrol_end


## If [b]on_patrol[/b] is set to true, checks if the entity has reached the end of the patrolling area
func check_for_end_of_area():
	# If position surpasses the bounds of the area, 
	# 	set target position to opposite side of area
	if position.x > patrol_end.x - 1:
		waiting_to_turn_around = true
		await get_tree().create_timer(patrol_wait).timeout
		waiting_to_turn_around = false
		patrol_target_position.x = patrol_start.x
	elif position.x < patrol_start.x + 1:
		waiting_to_turn_around = true
		await get_tree().create_timer(patrol_wait).timeout
		waiting_to_turn_around = false
		patrol_target_position.x = patrol_end.x


## Send the position the enemy should move to if the player is out of reach of the entity
func return_to_squad_position() -> Vector2:
	if player_out_of_range: return squad_position
	else: return Vector2.ZERO # Will be used to check if the entity should continue pursuing the player


## Set the status of the variable [b]monitor_player_position[/b] when setting the entity to patrol
func set_monitor_player_status():
	#print(monitor_player_position, " s:smps")
	# Check if area 2d representing vision space has
	#	overlapping bodies (player)
	if initially_patrolling:
		if player_is_seen:
			monitor_player_position = true
			player_position = SceneVariables.player_position
			$VisibilityArea.scale.y = 1/abs(position.x - player_position.x) * vision_scale
		else:
			player_position = patrolling_last_known_pos
			
			if abs(position.x - patrolling_last_known_pos.x) < 5:
				on_patrol = true
				monitor_player_position = false
			
			$VisibilityArea.scale.y = 1
		
		
