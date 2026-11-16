extends SceneTree
## Content validator CLI: loads every registered document and reports all
## problems. Exits 1 on any problem, so CI and the pre-push gate can use it.
##   godot --headless --path . -s tools/content_validator/validate.gd
##   ... -- --root=<data folder>      (testing: validate another folder)


func _init() -> void:
	var root: String = ContentLoader.DEFAULT_ROOT
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--root="):
			root = arg.trim_prefix("--root=")
	var registry: ContentRegistry = ContentCatalog.build_registry()
	var result: ContentResult = ContentLoader.new(registry, root).validate_all()
	for message: String in result.errors:
		print("FAIL  ", message)
	print("content: %d documents checked, %d problems" % [registry.ids().size(), result.errors.size()])
	quit(0 if result.ok() else 1)
