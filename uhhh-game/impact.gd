extends AnimatedSprite2D

@export var speed: float = 240.0
@export var friction: float = 700.0
@export var lifetime: float = 0.3

var _vel: Vector2 = Vector2.ZERO
var _life: float = 0.0

func _ready() -> void:
	_vel = Vector2.RIGHT.rotated(rotation) * speed
	_life = lifetime
	rotation = 0.0
	if sprite_frames != null:
		play()

func _process(delta: float) -> void:
	position += _vel * delta
	_vel = _vel.move_toward(Vector2.ZERO, friction * delta)
	_life -= delta
	modulate.a = clampf(_life / lifetime, 0.0, 1.0)
	if _life <= 0.0:
		queue_free()
