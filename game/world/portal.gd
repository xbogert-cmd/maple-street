class_name Portal
extends Node3D
## An outside door or a window of a house. Doors swing open; windows are climbed through.

var house: House
var is_window := false
var tag := ""            # "front", "back" or "" for windows
var locked := true
var open := false
var key_copied := false
var picked := false       # opened by the player and not locked again
var forced := false       # window latch forced: leaves marks
var inside_pos: Vector3
var outside_pos: Vector3
var leaf: Node3D         # door only
var body: StaticBody3D   # door only


func set_open(on: bool) -> void:
	if is_window or on == open:
		return
	open = on
	Sfx.play("door_open" if on else "door_close", global_position, -4.0)
	leaf.rotation.y = -PI * 0.5 if on else 0.0
	body.collision_layer = 0 if on else Build.L_DOOR


func label() -> String:
	if is_window:
		return "Window"
	return "Front door" if tag == "front" else "Back door"
