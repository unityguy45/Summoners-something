extends CharacterBody2D

@export var speed: float = 130.0
@export var max_health: float = 30.0
@export var contact_damage: float = 10.0
@export var contact_interval: float = 0.8

@export var knockback_friction: float = 1200.0
@export var flash_time: float = 0.12

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var health: float
var _contact_t: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _flash_t: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	health = max_health

func _physics_process(delta: float) -> void:
	_contact_t = maxf(_contact_t - delta, 0.0)

	if _flash_t > 0.0:
		_flash_t -= delta
		var mat := anim.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("flash_amount", clampf(_flash_t / flash_time, 0.0, 1.0))

	if _knockback.length() > 5.0:
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, knockback_friction * delta)
	else:
		_knockback = Vector2.ZERO
		var player := _get_player()
		if player != null and is_instance_valid(player):
			var to_player: Vector2 = player.global_position - global_position
			if to_player.length() > 28.0:
				velocity = to_player.normalized() * speed
			else:
				velocity = Vector2.ZERO
				_try_hit_player(player)

	move_and_slide()
	_update_animation()

func _update_animation() -> void:
	if velocity.length() > 0.1:
		anim.play("Run")
		if velocity.x != 0.0:
			anim.flip_h = velocity.x < 0.0
	else:
		anim.play("Idle")

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null

func _try_hit_player(player: Node2D) -> void:
	if _contact_t > 0.0:
		return
	_contact_t = contact_interval
	if player.has_method("take_damage"):
		player.take_damage(contact_damage)

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	health -= amount
	_knockback = knockback
	_flash_t = flash_time
	var mat := anim.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("flash_amount", 1.0)
	if health <= 0.0:
		queue_free()
