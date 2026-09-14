extends Camera3D
## Points this camera at a fixed target on _ready(). Safer than hand-authoring
## a Transform3D basis matrix in a .tscn file -- that's exactly the kind of
## thing that silently produces a plausible-looking but wrong rotation.

@export var target: Vector3 = Vector3(12, 1.15, 8)

func _ready() -> void:
	look_at(target, Vector3.UP)
