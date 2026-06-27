extends Node2D

@export var leaf1_amplitude: float = 8.0
@export var leaf1_speed: float = 2.6
@export var leaf2_amplitude: float = 6.0
@export var leaf2_speed: float = 3.4
@export var influence_radius: float = 60.0
@export var max_push: float = 35.0
@export var push_smooth: float = 8.0
@onready var pivot1: Node2D = $LeafPivot1
@onready var pivot2: Node2D = $LeafPivot2
@onready var sprite1: AnimatedSprite2D = $LeafPivot1/LeafSprite1
@onready var sprite2: AnimatedSprite2D = $LeafPivot2/LeafSprite2

var _t: float = 0.0
var _push: float = 0.0
var _player: Node2D = null

func _ready() -> void:
	_t = randf() * 10.0
	_anchor_to_base(sprite1)
	_anchor_to_base(sprite2)

func _anchor_to_base(spr: AnimatedSprite2D) -> void:
	var frames := spr.sprite_frames
	if frames == null:
		return
	var tex := frames.get_frame_texture(spr.animation, spr.frame)
	if tex == null:
		return
	var h := tex.get_height()
	spr.offset.y = -h * 0.5

func _process(delta: float) -> void:
	_t += delta

	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		_player = players[0] if players.size() > 0 else null

	var target_push := 0.0
	if _player != null and is_instance_valid(_player):
		var offset := global_position - _player.global_position
		var dist := offset.length()
		if dist < influence_radius:
			var strength := 1.0 - (dist / influence_radius)
			target_push = signf(offset.x) * max_push * strength

	_push = lerpf(_push, target_push, clampf(push_smooth * delta, 0.0, 1.0))

	# Wind fades out as the player bends the grass over.
	var bent := clampf(absf(_push) / max_push, 0.0, 1.0)
	var wind_mix := 1.0 - bent

	var wind1 := leaf1_amplitude * sin(_t * leaf1_speed) * wind_mix
	var wind2 := leaf2_amplitude * sin(_t * leaf2_speed + 1.0) * wind_mix

	pivot1.rotation_degrees = wind1 + _push
	pivot2.rotation_degrees = wind2 + _push
