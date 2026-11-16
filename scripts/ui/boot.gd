extends Node
## Boot scene: wires services, then hands off to the title screen.


func _ready() -> void:
	AppBootstrap.run(get_tree())
	var flow: SceneFlow = get_node("/root/Scenes")
	# Deferred so the boot scene finishes entering the tree before it is replaced.
	flow.call_deferred("go_to", &"title")
