class_name PortfolioExporter
extends RefCounted
## Writes a rendered portfolio report to the game's own export folder. The
## player never supplies a path: the folder is fixed, the file name is built
## from a validated lab id and a number, and the write goes to a temporary file
## that is renamed into place so a crash cannot leave half a report.

const EXPORT_DIR: String = "user://exports"
const MAX_REPORT_BYTES: int = 64 * 1024
const MAX_SAME_STAMP_FILES: int = 99


## `stamp` is any non-negative number that makes the name unique, normally the
## current Unix time. `export_dir` exists for tests and must stay under user://.
static func write(report_text: String, lab_id: String, stamp: int, export_dir: String = EXPORT_DIR) -> ActionResult:
	if not export_dir.begins_with("user://") or export_dir.contains(".."):
		return ActionResult.failure("Reports can only be saved inside the game's own folder.")
	if not SchemaValidator.validate(lab_id, {"type": "id"}).ok():
		return ActionResult.failure("That lab name cannot be used for a file.")
	if stamp < 0:
		return ActionResult.failure("That report number is not valid.")
	if report_text.to_utf8_buffer().size() > MAX_REPORT_BYTES:
		return ActionResult.failure("That report is too large to save.")
	if DirAccess.make_dir_recursive_absolute(export_dir) != OK:
		return ActionResult.failure("Could not create the reports folder.")

	var file_name: String = "%s_report_%d.md" % [lab_id, stamp]
	var suffix: int = 1
	while FileAccess.file_exists(export_dir.path_join(file_name)):
		suffix += 1
		if suffix > MAX_SAME_STAMP_FILES:
			return ActionResult.failure("Too many reports were saved at the same moment.")
		file_name = "%s_report_%d_%d.md" % [lab_id, stamp, suffix]

	var final_path: String = export_dir.path_join(file_name)
	var temp_path: String = final_path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return ActionResult.failure("Could not write the report.")
	file.store_string(report_text)
	file.flush()
	file = null
	if DirAccess.rename_absolute(temp_path, final_path) != OK:
		DirAccess.remove_absolute(temp_path)
		return ActionResult.failure("Could not finish saving the report.")
	return ActionResult.success(file_name, "Saved %s" % file_name)
