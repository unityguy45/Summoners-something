extends AnimatedSprite2D

@export var anim_selected: String = "abilty selected"
@export var anim_unselected: String = "abilty unselected"

func set_selected(selected: bool) -> void:
	if selected:
		play(anim_selected)
	else:
		play(anim_unselected)

func _ready() -> void:
	set_selected(false)
