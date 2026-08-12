@abstract extends "navigatable_entity.gd"
## Base abstract class for tying physics and state together for all combat entities

## Name of the Bullet Detection Area child object
const BDA_NAME = "BulletDetectionArea"
## Name of the Guard Area child object
const GA_NAME = "GuardArea"
## Name of the Visibility Area child object
const VA_NAME = "VisibilityArea"
## Name of the Hitbox child object
const HB_NAME = "Hitbox"

## Signal sent when the entity wishes to call for backup
signal call_for_reinforcements

## Determines if the entity is currently attacking
var attacking: bool
## Determines whether the entity should dodge and oncoming attack
@export var dodging: bool
## For testing purposes, the color to use to show that the entity has been kicked
@export var kick_state_color: Color
## For testing purposes, the initial color of the sprite
var initial_state_color: Color

## Determines whether or not the sprite has been flipped due to negative velocity
var is_sprite_flipped := false
## Current scale to apply to sprite2D node and other nodes that point to a specific direction
var flip_scale = -1
## Determines whether a player is nearby. Must be used with AnimationTree StateMachine Node
var player_nearby := false
## Determines whether a bullet is nearby. Must be used with AnimationTree StateMachine Node
var bullet_nearby := false
## Determines whether the entity was kicked by the player
var kicked_by_player := false
## Determines whether the entity was footstooled by the player
var footstooled := false
## Determines whether the entity should dodge and oncoming attack
var dodge_orb := false
## Determines if the player's kick hitbox is detected
var player_about_to_kick
## Variable for the currently playing animation from the AnimationTree node
var current_animation : String
## Determines if the enemy is currently facing the player
var facing_player : bool
## Determines if the player is within the bounds of either the guard area or the visibility area
var player_within_vicinity
## Reference to a scene tree timer for when an entity is kicked
var kick_timer

## Reference to the CollisionShape2D node in the entity scene
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
## Reference to the Sprite2D node in the entity scene
@onready var sprite_2d: Sprite2D = $Sprite2D
## Reference to the PlayerAttackArea node in the entity scene
@onready var player_attack_area: Area2D = $PlayerAttackArea


## Adds to base implementation in ControlledEntity and also forces [b]is_sprite_flipped[/b] to false
func _ready() -> void:
	super()
	
	collider_init_pos = collision_shape_2d.position
	if has_child(HB_NAME): hitbox_init_pos = $Hitbox.position
	
	Performance.add_custom_monitor("Movement/X Velocity", fetch_velocity)
	Performance.add_custom_monitor("Movement/Direction", fetch_direction)
	Performance.add_custom_monitor("State/Player Nearby", fetch_player_nearby_status)
	Performance.add_custom_monitor("State/Player Within Vicinity", fetch_player_within_vicinity_status)
	
	initial_state_color = $Sprite2D.self_modulate
	
	$Hurtbox.area_entered.connect(area_entered_hurtbox)
	$Hurtbox.body_entered.connect(body_entered_hurtbox)


## Sets [b]is_sprite_flipped[/b] and [b]flip_scale[/b] based on current x velocity[br][br]
## Do [b]not[/b] override this function unless a very specific implementation is needed
func _process(_delta: float) -> void:
	if !kicked_by_player:
		if velocity.x < 0: 
			is_sprite_flipped = true
			flip_scale = -1
			#$Hitbox.position = Vector2(-18, 3)
		elif velocity.x > 0: 
			is_sprite_flipped = false
			flip_scale = 1
			#$Hitbox.position = Vector2(18, 3)
	
	update_node_scale()
	
	if kicked_by_player:
		$Sprite2D.self_modulate = kick_state_color
	else:
		$Sprite2D.self_modulate = initial_state_color


## Adds to the base _physics_process implementation by calling state update functions and updating other physics based variables within the physics loop
func _physics_process(delta: float) -> void:
	super(delta) # on guard variable can change during this call
	
	# Find out if the entity is currently facing the player
	is_facing_player()
	#if kicked_by_player and has_child(KICK_AREA_NAME):
	
	
	# Call function to update player_nearby and other states
	update_state()
	# Update velocity if entity was kicked or dominoed
	update_velocity()
	# Change properties of node based on state
	change_properties()
	
	# if the player is currently in attack or dodge state, pause movement
	if !attacking and !dodging:
		move_and_slide()
	
	#for i in get_slide_collision_count():
		#var collision = get_slide_collision(i)
		#print("I collided with ", collision.get_collider().name)


## Returns true if the entity is currently facing the player, returns false otherwise
func is_facing_player():
	if player_position.x > position.x and SceneVariables.player_facing_left and !is_sprite_flipped:
		facing_player = true
	elif player_position.x < position.x and !SceneVariables.player_facing_left and is_sprite_flipped:
		facing_player = true
	# If none of the above conditions are true, set to false
	else:
		facing_player = false


## Change properties of scene based on current state
func change_properties():
	sprite_2d.flip_h = is_sprite_flipped


## Function to override when changing any state variables for the entity
func update_state():
	# if entity is kicked from the front and there is an entity that is behind the current entity, 
	# the enemy that was also kicked behind doesn't seem to move as well 
	# Remove the domino effect
	
	if !kicked_by_player:
		# This is used to transition to attack state if player is close enough
		player_nearby = true if player_attack_area.has_overlapping_bodies() else false
		if has_child(BDA_NAME):
			bullet_nearby = true if $BulletDetectionArea.has_overlapping_bodies() else false
		if has_child(GA_NAME):
			player_within_vicinity = true if $GuardArea.has_overlapping_bodies() else false
		
		if has_child(VA_NAME):
			player_within_vicinity = true if $VisibilityArea.has_overlapping_bodies() else false
		
		# If the entity is kicked, essentially they are mostly helpless and cannot do anything else
		if initially_guarding:
			# GuardArea surrounds the entity and the player needs to get past it in order to be close enough to be attacked
			if player_within_vicinity:
				on_guard = false
				call_for_reinforcements.emit() # Called whenever guard state changes. parent can ignore if needed
			elif !player_nearby and !bullet_nearby: on_guard = true
		elif initially_patrolling:
			if player_is_seen and !player_within_vicinity: 
				#print("player")
				patrolling_last_known_pos = SceneVariables.player_position
			player_is_seen = true if player_within_vicinity else false
			
			if player_nearby or player_within_vicinity:
				on_patrol = false
				call_for_reinforcements.emit() # Called whenever patrol state changes. parent can ignore if needed


## Function to override when state must change velocity
func update_velocity():
	pass


## Use to update scale and/or position for optional custom nodes such as VisibilityArea
func update_node_scale():
	collision_shape_2d.position.x = collider_init_pos.x * -1 if is_sprite_flipped else collider_init_pos.x * 1
	if has_child(VA_NAME): $VisibilityArea.scale.x = -1 if is_sprite_flipped else 1
	if has_child(HB_NAME): $Hitbox.position.x = hitbox_init_pos.x * -1 if is_sprite_flipped else hitbox_init_pos.x * 1


## Function to override with a custom implementation for areas detected
@abstract func area_entered_hurtbox(area: Area2D)


## Function to override with a custom implementation for kinematic or rigidbodies detected
@abstract func body_entered_hurtbox(body: Node2D)


## Queues the entity to be freed from memory and plays vfx and sfx. Also sets is_dead for 
## AnimationTree. Override this method and call super() if needed to make create a custom implementation
func die():
	#SfxSpawner.set_player(position, 1)
	#VfxSpawner.set_player(position)
	queue_free()

## Fetches the x velocity value
func fetch_velocity():
	return abs(velocity.x)


## Fetches the direction the entity is facing
func fetch_direction():
	return 1 if is_sprite_flipped else 0


## Fetches the detected status of player bodies within the PlayerDetectionArea
func fetch_player_nearby_status():
	return 1 if player_nearby else 0


## Fetches the detected status of player bodies within the GuardArea or VisibilityArea
func fetch_player_within_vicinity_status():
	return 1 if player_within_vicinity else 0
