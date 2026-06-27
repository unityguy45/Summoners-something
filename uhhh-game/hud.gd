extends CanvasLayer

@export var ability_icon_scene: PackedScene
@export var icon_scale: float = 2.0
@export var bottom_margin: float = 48.0

var _icon: Node2D
var _selected: bool = false

func _ready() -> void:
	add_to_group("hud")
	if ability_icon_scene != null:
		_icon = ability_icon_scene.instantiate() as Node2D
		add_child(_icon)
		_icon.scale = Vector2(icon_scale, icon_scale)
	_position_icon()
	get_viewport().size_changed.connect(_position_icon)
	_update()

func _position_icon() -> void:
	if _icon == null:
		return
	var screen := get_viewport().get_visible_rect().size
	_icon.position = Vector2(screen.x * 0.5, screen.y - bottom_margin)

func _update() -> void:
	if _icon != null and _icon.has_method("set_selected"):
		_icon.set_selected(_selected)

func select() -> void:
	_selected = not _selected
	_update()

func is_selected() -> bool:
	return _selected

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			select()
