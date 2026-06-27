extends Node2D

@export var grass_scene: PackedScene     
@export var count: int = 80              
@export var area_size: Vector2 = Vector2(100, 100) 
@export var min_scale: float = 0.8
@export var max_scale: float = 1.3
@export var random_seed: int = 0   

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	if random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()

	for i in count:
		if grass_scene == null:
			return
		var g := grass_scene.instantiate() as Node2D
		# Random position within the area, centered on this node.
		g.position = Vector2(
			rng.randf_range(-area_size.x * 0.5, area_size.x * 0.5),
			rng.randf_range(-area_size.y * 0.5, area_size.y * 0.5)
		)
		# Slight random size so it doesn't look like clones.
		var s := rng.randf_range(min_scale, max_scale)
		g.scale = Vector2(s, s)
		add_child(g)
