extends CharacterBody2D

@export var speed: float = 320.0
@export var dash_speed: float = 950.0
@export var dash_time: float = 0.15
@export var dash_cooldown: float = 0.6

@export var max_health: float = 100.0
@export var max_mana: float = 100.0
@export var mana_regen: float = 20.0

@export var attack_range: float = 70.0
@export var attack_arc_degrees: float = 120.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 0.35
@export var slash_duration: float = 0.12
@export var slash_hit_linger: float = 0.06

@export var slash_start_distance: float = 8.0
@export var slash_travel: float = 40.0

@export var knockback_force: float = 600.0

@export var hitstop_duration: float = 0.08
@export var hitstop_scale: float = 0.05

@export var impact_scene: PackedScene
@export var impact_count: int = 4
@export var impact_spread_degrees: float = 70.0
@export var impact_distance: float = 18.0

@export var centipede_scene: PackedScene
const CENTIPEDE_FALLBACK := preload("res://centipede.tscn")
const IMPACT_FALLBACK := preload("res://impact.tscn")

@export var path_width: float = 6.0
@export var path_color: Color = Color(0.4, 0.9, 1.0, 0.9)
@export var path_min_dist: float = 16.0
@export var double_click_ms: int = 350

@export var slash_self_knockback: float = 320.0
@export var self_kb_friction: float = 2000.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var slash: Node2D = get_node_or_null("Slash")

var health: float
var mana: float

var _hud: Node = null

var _drawing: bool = false
var _draw_active: bool = false
var _path: Array[Vector2] = []
var _path_line: Line2D = null
var _last_left_ms: int = -100000

var _dash_t: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _attack_cd: float = 0.0
var _slash_t: float = 0.0
var _slash_dir: Vector2 = Vector2.RIGHT
var _slash_frozen: bool = false
var _self_kb: Vector2 = Vector2.ZERO
var _in_hitstop: bool = false

func _ready() -> void:
	add_to_group("player")
	Engine.time_scale = 1.0
	health = max_health
	mana = max_mana
	if slash != null:
		slash.visible = false

func _physics_process(delta: float) -> void:
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	mana = minf(max_mana, mana + mana_regen * delta)

	if _slash_t > 0.0:
		_slash_t -= delta
		if slash != null and not _slash_frozen:
			var progress: float = 1.0 - clampf(_slash_t / slash_duration, 0.0, 1.0)
			var dist: float = lerpf(slash_start_distance, slash_travel, progress)
			slash.position = _slash_dir * dist
		if _slash_t <= 0.0 and slash != null:
			slash.visible = false

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if _dash_t > 0.0:
		_dash_t -= delta
		velocity = _dash_dir * dash_speed
	elif _self_kb.length() > 5.0:
		velocity = _self_kb
		_self_kb = _self_kb.move_toward(Vector2.ZERO, self_kb_friction * delta)
	else:
		_self_kb = Vector2.ZERO
		velocity = input_dir * speed

	move_and_slide()
	_update_animation(input_dir)

func _update_animation(dir: Vector2) -> void:
	if dir.length() > 0.1:
		anim.play("Run")
		if dir.x != 0.0:
			anim.flip_h = dir.x < 0.0
	else:
		anim.play("Idle")

func _process(_delta: float) -> void:
	if _drawing and _draw_active:
		var p := get_global_mouse_position()
		if _path.is_empty() or _path[_path.size() - 1].distance_to(p) >= path_min_dist:
			_path.append(p)
			if _path_line != null:
				_path_line.add_point(p)

func _unhandled_input(event: InputEvent) -> void:
	if _drawing:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			print("left btn: pressed=", event.pressed, " double=", event.double_click)
			if event.double_click:
				_launch_path()
			else:
				_draw_active = event.pressed
		elif event.is_action_pressed("secondary"):
			_cancel_draw()
		return

	if event.is_action_pressed("dash"):
		_start_dash()
	if event.is_action_pressed("secondary"):
		var hud := _get_hud()
		if hud != null and hud.has_method("is_selected") and hud.is_selected():
			_begin_draw()
	if event.is_action_pressed("attack"):
		var hud := _get_hud()
		if hud != null and hud.has_method("is_selected") and hud.is_selected():
			_summon_centipede()
		else:
			_attack()

func _begin_draw() -> void:
	_drawing = true
	_draw_active = false
	_path.clear()
	Engine.time_scale = 0.0
	_path_line = Line2D.new()
	_path_line.width = path_width
	_path_line.default_color = path_color
	get_parent().add_child(_path_line)

func _launch_path() -> void:
	Engine.time_scale = 1.0
	_drawing = false
	_draw_active = false
	print("launch: points=", _path.size(), " scene=", centipede_scene)
	var cscene: PackedScene = centipede_scene if centipede_scene != null else CENTIPEDE_FALLBACK
	if cscene != null and _path.size() >= 2:
		var cent := cscene.instantiate() as Node2D
		cent.global_position = _path[0]
		get_parent().add_child(cent)
		if cent.has_method("follow_path"):
			cent.follow_path(_path)
	if _path_line != null:
		_path_line.queue_free()
		_path_line = null

func _cancel_draw() -> void:
	Engine.time_scale = 1.0
	_drawing = false
	_draw_active = false
	_path.clear()
	if _path_line != null:
		_path_line.queue_free()
		_path_line = null

func _get_hud() -> Node:
	if _hud == null or not is_instance_valid(_hud):
		var huds := get_tree().get_nodes_in_group("hud")
		_hud = huds[0] if huds.size() > 0 else null
	return _hud

func _summon_centipede() -> void:
	var cscene: PackedScene = centipede_scene if centipede_scene != null else CENTIPEDE_FALLBACK
	if cscene == null:
		return
	var cent := cscene.instantiate() as Node2D
	cent.global_position = global_position
	get_parent().add_child(cent)
	if cent.has_method("launch"):
		cent.launch(get_global_mouse_position())

func _attack() -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = attack_cooldown

	var dir := get_global_mouse_position() - global_position
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	dir = dir.normalized()

	if dir.x != 0.0:
		anim.flip_h = dir.x < 0.0

	_show_slash(dir)

	var half_arc := deg_to_rad(attack_arc_degrees) * 0.5
	var hit_count := 0
	var hit_center := Vector2.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var to_e: Vector2 = e.global_position - global_position
		if to_e.length() > attack_range:
			continue
		if absf(dir.angle_to(to_e)) <= half_arc:
			if e.has_method("take_damage"):
				e.take_damage(attack_damage, to_e.normalized() * knockback_force)
			_spawn_impact(e.global_position, dir)
			hit_center += e.global_position
			hit_count += 1

	if hit_count > 0:
		hit_center /= hit_count
		var away := global_position - hit_center
		if away == Vector2.ZERO:
			away = -dir
		_self_kb = away.normalized() * slash_self_knockback
		_slash_frozen = true
		_slash_t = slash_hit_linger
		_hitstop()
	print("attack fired. hit_count=", hit_count, " time_scale=", Engine.time_scale)

func _spawn_impact(pos: Vector2, dir: Vector2) -> void:
	var iscene: PackedScene = impact_scene if impact_scene != null else IMPACT_FALLBACK
	if iscene == null:
		return
	var base_angle := dir.angle()
	var spread := deg_to_rad(impact_spread_degrees)
	for i in impact_count:
		var frac := 0.0
		if impact_count > 1:
			frac = float(i) / float(impact_count - 1) - 0.5
		var a := base_angle + frac * spread + randf_range(-0.12, 0.12)
		var off := Vector2.RIGHT.rotated(a)
		var fx := iscene.instantiate() as Node2D
		fx.rotation = a
		get_parent().add_child(fx)
		fx.global_position = pos + off * randf_range(impact_distance * 0.2, impact_distance)

func _hitstop() -> void:
	if _in_hitstop:
		print("hitstop blocked (already in hitstop)")
		return
	_in_hitstop = true
	print("hitstop START scale=", hitstop_scale)
	Engine.time_scale = hitstop_scale
	var t := get_tree().create_timer(hitstop_duration, true, false, true)
	await t.timeout
	Engine.time_scale = 1.0
	_in_hitstop = false
	print("hitstop END")

func _show_slash(dir: Vector2) -> void:
	if slash == null:
		return
	_slash_dir = dir
	_slash_frozen = false
	slash.rotation = dir.angle()
	slash.position = dir * slash_start_distance
	slash.visible = true
	if slash is AnimatedSprite2D:
		slash.frame = 0
		slash.play("Slash")
	_slash_t = slash_duration

func _start_dash() -> void:
	if _dash_cd > 0.0:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir == Vector2.ZERO:
		dir = (get_global_mouse_position() - global_position).normalized()
	if dir == Vector2.ZERO:
		return
	_dash_dir = dir
	_dash_t = dash_time
	_dash_cd = dash_cooldown

func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		_die()

func spend_mana(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	return true

func _die() -> void:
	get_tree().reload_current_scene()
