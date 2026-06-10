extends CharacterBody2D
#Hi to whoever is looking at this
@export var speed: float = 320.0
@export var dash_speed: float = 950.0
@export var dash_time: float = 0.15
@export var dash_cooldown: float = 0.6
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
var _dash_t: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
func _physics_process(delta: float) -> void:
	_dash_cd = maxf(_dash_cd - delta, 0.0)

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _dash_t > 0.0:
		_dash_t -= delta
		velocity = _dash_dir * dash_speed
	else:
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
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dash"):
		_start_dash()
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
