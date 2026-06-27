extends Node2D

@export var segment_count: int = 8
@export var speed: float = 260.0
@export var segment_spacing: float = 4.0
@export var turn_speed: float = 6.0
@export var sprite_angle_offset: float = 90.0

@export var vision_range: float = 400.0
@export var vision_angle_degrees: float = 20.0
@export var lock_turn_speed: float = 4.0

@export var coil_delay: float = 0.5
@export var coil_turn_speed: float = 110.0

@export var path_point_reach: float = 18.0

@export var contact_damage: float = 12.0
@export var contact_range: float = 26.0
@export var contact_knockback: float = 400.0
@export var hit_cooldown: float = 0.4
@export var lifetime: float = 6.0

@onready var head: Node2D = $Head
@onready var body_template: Node2D = $Body

var _direction: Vector2 = Vector2.RIGHT
var _moving: bool = false
var _target: Node2D = null
var _locked: bool = false
var _life: float = 0.0
var _search_t: float = 0.0
var _hit_cd: float = 0.0

var _path: Array[Vector2] = []
var _path_index: int = 0
var _following_path: bool = false

var _segments: Array[Node2D] = []
var _history: Array[Vector2] = []

func _ready() -> void:
	_spawn_segments()
	for i in 200:
		_history.append(head.global_position)

func _spawn_segments() -> void:
	for i in segment_count:
		var seg := body_template.duplicate() as Node2D
		add_child(seg)
		seg.global_position = head.global_position
		seg.visible = true
		_segments.append(seg)
	body_template.visible = false

func launch(target: Vector2) -> void:
	_direction = (target - head.global_position).normalized()
	if _direction == Vector2.ZERO:
		_direction = Vector2.RIGHT
	_moving = true
	_life = lifetime

func follow_path(points: Array) -> void:
	_path.clear()
	for p in points:
		_path.append(p)
	_path_index = 0
	_following_path = _path.size() > 0
	_moving = true
	_life = lifetime
	if _following_path:
		var to0: Vector2 = _path[0] - head.global_position
		if to0.length() > 0.001:
			_direction = to0.normalized()

func _physics_process(delta: float) -> void:
	if not _moving:
		return

	_life -= delta
	if _life <= 0.0:
		queue_free()
		return

	_hit_cd = maxf(_hit_cd - delta, 0.0)

	if _following_path:
		_steer_along_path()
	else:
		_steer_hunt(delta)

	_do_contact()

	head.global_position += _direction * speed * delta
	_face(head, _direction, delta)

	_history.push_front(head.global_position)
	var needed := int(segment_spacing * segment_count) + 5
	while _history.size() > needed:
		_history.pop_back()

	for i in _segments.size():
		var idx := int((i + 1) * segment_spacing)
		if idx < _history.size():
			var seg := _segments[i]
			var target_pos: Vector2 = _history[idx]
			var dir := target_pos - seg.global_position
			if dir.length() > 0.5:
				_face(seg, dir, delta)
			seg.global_position = target_pos

func _steer_along_path() -> void:
	var to_point: Vector2 = _path[_path_index] - head.global_position
	while to_point.length() <= path_point_reach and _path_index < _path.size() - 1:
		_path_index += 1
		to_point = _path[_path_index] - head.global_position
	if _path_index >= _path.size() - 1 and to_point.length() <= path_point_reach:
		_following_path = false
		return
	if to_point.length() > 0.001:
		_direction = to_point.normalized()

func _steer_hunt(delta: float) -> void:
	if _locked and not is_instance_valid(_target):
		_locked = false
		_target = null

	if not _locked:
		var found := _find_target()
		if found != null:
			_target = found
			_locked = true
			_search_t = 0.0
		else:
			_search_t += delta
			if _search_t > coil_delay:
				_direction = _direction.rotated(deg_to_rad(coil_turn_speed) * delta)

	if _locked and is_instance_valid(_target):
		var desired := (_target.global_position - head.global_position).angle()
		var cur := _direction.angle()
		var diff := wrapf(desired - cur, -PI, PI)
		var step := clampf(diff, -lock_turn_speed * delta, lock_turn_speed * delta)
		_direction = _direction.rotated(step)

func _do_contact() -> void:
	if _hit_cd > 0.0:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if head.global_position.distance_to(e.global_position) <= contact_range:
			if e.has_method("take_damage"):
				e.take_damage(contact_damage, _direction * contact_knockback)
			_hit_cd = hit_cooldown
			return

func _find_target() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	var max_angle := deg_to_rad(vision_angle_degrees)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var to_e: Vector2 = e.global_position - head.global_position
		var dist := to_e.length()
		if dist > vision_range or dist < 0.001:
			continue
		if absf(_direction.angle_to(to_e)) <= max_angle and dist < best_dist:
			best_dist = dist
			best = e
	return best

func _face(node: Node2D, dir: Vector2, delta: float) -> void:
	var target_angle := dir.angle() + deg_to_rad(sprite_angle_offset)
	node.rotation = lerp_angle(node.rotation, target_angle, turn_speed * delta)
