extends "res://scripts/basic_entity.gd"

## A constant to use for setting names of animations to use when detecting when an animation starts or finishes
const BLANK_ANIMATION_NAME = "blank_animation"


func _ready() -> void:
	super()
	
	$AnimationTree.active = true
	$AnimationTree.animation_finished.connect(animation_finished)
	
	monitor_player_position = true


@warning_ignore("unused_parameter")
## A function called by the [b]area_entered[/b] signal
func area_entered_hurtbox(area: Area2D):
	pass


@warning_ignore("unused_parameter")
## A function called by the [b]body_entered[/b] signal
func body_entered_hurtbox(body: Node2D):
	pass


@warning_ignore("unused_parameter")
## A function called by the [b]animation_finished[/b] signal
func animation_finished(anim_name: StringName):
	pass

