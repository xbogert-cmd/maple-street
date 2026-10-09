class_name Walker
extends Node3D
## A person who walks the navmesh along a path. Base for neighbours, police and the investigator.

var street: Street
var figure: Figure
var speed := 1.5
var arrived := true
var _path: PackedVector3Array
var _pi := 0
var _on_arrive: Callable


func make_figure(look: Dictionary) -> void:
	figure = Figure.new()
	add_child(figure)
	figure.build(look)


func go_to(target: Vector3, on_arrive := Callable()) -> void:
	_path = street.path(global_position, target)
	_pi = 0
	arrived = _path.is_empty()
	_on_arrive = on_arrive
	if arrived:
		# no route (target off the mesh): go straight there so nobody gets stuck forever
		global_position = target
		_finish()


func stop() -> void:
	arrived = true
	_path = PackedVector3Array()
	_on_arrive = Callable()


func facing() -> Vector3:
	return Vector3(sin(figure.rotation.y), 0, cos(figure.rotation.y))


func face(target: Vector3, delta := 1.0) -> void:
	var to := target - global_position
	if to.length() > 0.05:
		figure.rotation.y = lerp_angle(figure.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 8.0))


func walk(delta: float) -> void:
	if arrived:
		figure.animate(0.0, delta)
		return
	var target := _path[_pi]
	target.y = 0.0
	var to := target - global_position
	var step := speed * delta
	if to.length() <= step:
		global_position = target
		_pi += 1
		if _pi >= _path.size():
			arrived = true
			_finish()
	else:
		global_position += to.normalized() * step
		face(target, delta)
	figure.animate(speed, delta)


func _finish() -> void:
	if _on_arrive.is_valid():
		var cb := _on_arrive
		_on_arrive = Callable()
		cb.call()


func can_see(target: Vector3, light: float, sneaking: bool) -> bool:
	var from := global_position + Vector3.UP * 1.5
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > Rules.sight_range(light, sneaking):
		return false
	if dist > (1.2 if sneaking else 2.2) and facing().dot(to.normalized()) < 0.34:
		return false
	var q := PhysicsRayQueryParameters3D.create(from, target + Vector3.UP * (0.7 if sneaking else 1.2), Build.L_WALL | Build.L_DOOR)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
