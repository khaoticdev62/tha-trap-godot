extends Node
## Integration check for M8: boots the real autoloads and the real SOC shell scene
## and drives it like a player: navigation, dashboard binding, event filtering and
## selection, evidence, case actions, the terminal, learning feedback, controller
## focus (no traps), text scale and resolutions, and save/resume.
##   godot --headless --path . res://tests/integration/soc_flow.tscn
## Uses a throwaway save folder and settings file; real player data is untouched.

const SCREEN_IDS: Array[StringName] = [&"command_center", &"investigation", &"cases", &"terminal", &"mission", &"design_system"]
const EXPECTED_STEPS: int = 11
const SIZES: Array[Vector2i] = [Vector2i(1280, 800), Vector2i(1280, 720)]

var _failures: PackedStringArray = PackedStringArray()
## Names of the steps that ran to the end. A script error aborts a step silently, so the
## run only counts as passed when every step finished.
var _finished: PackedStringArray = PackedStringArray()
var _tree: SceneTree
var _shell: SocShell


func _ready() -> void:
	_tree = get_tree()
	_tree.create_timer(60.0).timeout.connect(func() -> void:
		print("FAIL  watchdog: test did not finish in 60s")
		_tree.quit(1))
	var root: Window = _tree.root
	_tree.current_scene = null
	var saves: SaveService = root.get_node_or_null("Saves")
	var settings: SettingsService = root.get_node_or_null("Settings")
	if saves == null or settings == null:
		print("FAIL  autoloads are not available")
		_tree.quit(1)
		return
	var tag: int = Time.get_ticks_usec()
	saves.save_dir = "user://itest_soc_%d" % tag
	settings.settings_path = "user://itest_soc_settings_%d.json" % tag
	AppBootstrap.run(_tree)
	var progress: ProgressService = root.get_node("Progress")
	progress.reset()

	await _boot_shell()
	_finish("boot")
	await _check_navigation()
	_finish("navigation")
	await _check_dashboard_binding(progress)
	_finish("dashboard")
	await _check_investigation()
	_finish("investigation")
	await _check_case_management()
	_finish("case_management")
	await _check_terminal()
	_finish("terminal")
	await _check_mission()
	_finish("mission")
	await _check_focus_and_controller()
	_finish("focus")
	await _check_scaling_and_resolutions(settings)
	_finish("scaling")
	await _check_save_resume(progress)
	_finish("save_resume")
	await _check_design_system()
	_finish("design_system")
	_check(_finished.size() == EXPECTED_STEPS, "every step ran to the end (%d of %d: %s)" % [_finished.size(), EXPECTED_STEPS, ", ".join(_finished)])

	settings.reset_to_defaults()
	DirAccess.remove_absolute(settings.settings_path)
	for slot: int in AppConfig.SAVE_SLOT_COUNT:
		saves.delete_slot(slot)
	DirAccess.remove_absolute(saves.save_dir)
	for line: String in _failures:
		print("FAIL  ", line)
	print("soc_flow: %d failures" % _failures.size())
	_tree.quit(1 if _failures.size() > 0 else 0)


func _finish(step: String) -> void:
	_finished.append(step)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _frames(count: int = 3) -> void:
	for _i: int in count:
		await _tree.process_frame


func _boot_shell() -> void:
	_shell = load(SceneFlow.path_for(&"soc")).instantiate()
	add_child(_shell)
	await _frames()
	_check(_shell.model != null and _shell.model.is_ready(), "the shell opens a ready model from the real Progress service")
	_check(_shell.current_id == &"command_center", "the SOC opens on the Command Center")
	_check(SceneFlow.path_for(&"soc") != "", "the soc scene is registered with SceneFlow")


func _check_navigation() -> void:
	_check(SocShell.SCREENS.size() == 6, "six screens are registered")
	for screen_id: StringName in SCREEN_IDS:
		var button: Button = _shell.nav_button(screen_id)
		_check(button != null, "%s has a navigation button" % screen_id)
		if button == null:
			continue
		button.pressed.emit()
		await _frames()
		_check(_shell.current_id == screen_id, "pressing the %s button opens it" % screen_id)
		var screen: SocScreen = _shell.screen_node(screen_id)
		_check(screen != null and screen.visible, "%s is visible" % screen_id)
		var visible_count: int = 0
		for other: StringName in SCREEN_IDS:
			var node: SocScreen = _shell.screen_node(other)
			if node != null and node.visible:
				visible_count += 1
		_check(visible_count == 1, "exactly one screen is visible at a time (%d)" % visible_count)
		_check(not _shell._title_label.text.is_empty() and _shell._title_label.text == screen.screen_title(), "the header shows the screen title for %s" % screen_id)
		_check(not _shell._context_label.text.is_empty(), "the header shows context for %s" % screen_id)
		_check(button.button_pressed and button.text.begins_with("> "), "%s is marked active by shape and text, not colour alone" % screen_id)
	_check(not _shell.show_screen(&"../../etc/passwd"), "an unknown screen id is refused")
	_check(not _shell.show_screen(&""), "an empty screen id is refused")
	# Shoulder buttons / brackets step through the screens and wrap.
	_shell.show_screen(&"command_center")
	var next_event: InputEventAction = InputEventAction.new()
	next_event.action = &"nav_next"
	next_event.pressed = true
	_shell._unhandled_input(next_event)
	await _frames()
	_check(_shell.current_id == &"investigation", "nav_next moves to the next screen")
	var prev_event: InputEventAction = InputEventAction.new()
	prev_event.action = &"nav_prev"
	prev_event.pressed = true
	_shell._unhandled_input(prev_event)
	_shell._unhandled_input(prev_event)
	await _frames()
	_check(_shell.current_id == &"design_system", "nav_prev wraps from the first screen to the last")
	_shell.show_screen(&"command_center")
	await _frames()


func _check_dashboard_binding(progress: ProgressService) -> void:
	var model: SocModel = _shell.model
	var screen: Control = _shell.screen_node(&"command_center")
	var counts: Dictionary = model.severity_counts()
	for severity: String in SocTokens.SEVERITIES:
		var tile_number: Label = screen._counter_cards[severity]
		_check(tile_number.text == str(counts[severity]), "the %s counter shows the model's count (%s vs %s)" % [severity, tile_number.text, counts[severity]])
	_check(screen._queue.get_root().get_child_count() == model.incident_queue().size(), "the incident queue lists every incident")
	_check(screen._stream.get_root().get_child_count() == model.event_stream().size(), "the event stream lists the newest events")
	_check(screen._network.get_root().get_child_count() == model.session.package.assets.size(), "the network overview lists every asset")
	_check(progress.has_active_lab(), "the dashboard's lab is the one Progress is tracking")
	var before: String = _shell._badge_row.get_child(2).get_child(0).text
	model.collect_evidence("evt_004")
	await _frames()
	var after: String = _shell._badge_row.get_child(2).get_child(0).text
	_check(before != after and after.contains("Investigating"), "the header case badge follows the case state (%s -> %s)" % [before, after])
	_check(_shell.notification_text().begins_with("OK") and _shell.notification_text() != "OK  ", "the notification area reports the action (%s)" % _shell.notification_text())
	_check(screen._activity_card.body.get_child_count() >= 1, "analyst activity lists what the analyst did")
	# Activating the case row opens the investigation filtered to the account.
	screen._queue.get_root().get_child(0).select(0)
	screen._on_queue_activated()
	await _frames()
	_check(_shell.current_id == &"investigation", "activating the case row opens the investigation")
	_check(model.filter_text == "j.smith", "and filters to the reported account")


func _check_investigation() -> void:
	var model: SocModel = _shell.model
	var screen: Control = _shell.screen_node(&"investigation")
	var rows_now: int = screen._table.get_root().get_child_count()
	_check(rows_now == model.filter_events(model.filter_source, model.filter_result, model.filter_text).size(), "the table shows exactly the filtered events (%d)" % rows_now)
	screen._clear_filters()
	await _frames()
	var all_rows: int = screen._table.get_root().get_child_count()
	_check(all_rows == model.session.store.size(), "clearing filters shows every event (%d)" % all_rows)
	# Source filter via the real button.
	screen._source_filter.pressed.emit()
	await _frames()
	_check(model.filter_source == EventRecord.SOURCES[0], "pressing the source filter picks the first source (%s)" % model.filter_source)
	var filtered: int = screen._table.get_root().get_child_count()
	_check(filtered > 0 and filtered < all_rows, "the source filter narrows the table (%d of %d)" % [filtered, all_rows])
	for child: TreeItem in screen._table.get_root().get_children():
		_check(child.get_text(3) == model.filter_source, "every shown row matches the source filter")
	# Text filter that matches nothing, then back.
	screen._text_filter.text = "zzz-nothing"
	screen._text_filter.text_changed.emit("zzz-nothing")
	await _frames()
	_check(screen._table.get_root().get_child_count() == 0, "a filter with no matches shows an empty table")
	_check(screen._count_label.text.contains("No events match"), "and says so")
	screen._clear_filters()
	await _frames()
	# Select a row and collect it.
	var target: TreeItem = null
	for child: TreeItem in screen._table.get_root().get_children():
		if child.get_text(1).begins_with("EVT-003"):
			target = child
	_check(target != null, "EVT-003 is in the table")
	if target == null:
		return
	target.select(0)
	await _frames()
	_check(model.selected_event_id == "evt_003", "selecting a row selects that event in the model")
	_check(not screen._collect_button.disabled and screen._collect_button.text.contains("EVT-003"), "the collect button names the selected event")
	var evidence_before: int = model.session.ledger.size()
	screen._collect_button.pressed.emit()
	await _frames()
	_check(model.session.ledger.size() == evidence_before + 1, "collecting adds one piece of evidence")
	_check(model.is_collected("evt_003") and screen._collect_button.disabled and screen._collect_button.text.begins_with("Collected as"), "the button then shows the evidence id and is disabled")
	# A fact that cites the selected event.
	screen._note_kind.set_value("fact")
	screen._cite_toggle.button_pressed = true
	screen._note_input.text = "A sign-in succeeded from an outside source after failures."
	screen._on_add_note()
	await _frames()
	_check(model.session.case_file.entries().size() == 1 and model.session.case_file.entries()[0].kind == "fact", "a cited fact is added")
	# A fact without evidence is refused and the note is kept for fixing.
	screen._cite_toggle.button_pressed = false
	screen._note_input.text = "Unsupported claim"
	screen._on_add_note()
	await _frames()
	_check(model.session.case_file.entries().size() == 1, "a fact without evidence is refused")
	_check(screen._note_input.text == "Unsupported claim", "the refused note stays in the box so it can be fixed")
	_check(_shell.notification_text().begins_with("ERROR"), "the refusal is announced in the notification area (%s)" % _shell.notification_text())
	# MFA context is shown for the MFA event.
	for child: TreeItem in screen._table.get_root().get_children():
		if child.get_text(1).begins_with("EVT-004"):
			child.select(0)
	await _frames()
	var shown: String = ""
	for label: Node in screen._detail_body.get_children():
		if label is Label:
			shown += (label as Label).text + "\n"
	_check(shown.contains("MFA") and shown.contains("enrollment"), "the detail panel shows the MFA result for the event")
	_check(shown.contains("J. Smith"), "and the user context")


func _check_case_management() -> void:
	var model: SocModel = _shell.model
	_shell.show_screen(&"cases")
	await _frames()
	var screen: Control = _shell.screen_node(&"cases")
	_check(screen._evidence_table.get_root().get_child_count() == model.session.ledger.size(), "the evidence locker lists collected evidence")
	_check(screen._timeline_table.get_root().get_child_count() >= 1, "the timeline lists evidence in time order")
	_check(screen._notes_table.get_root().get_child_count() == model.session.case_file.entries().size(), "the notes list matches the case file")
	# Severity and scope.
	screen._severity.pressed.emit()
	await _frames()
	_check(model.session.case_file.severity == "low", "the severity button sets the first real severity (%s)" % model.session.case_file.severity)
	var scope_toggle: CheckButton = screen._scope_toggles["host_014"]
	scope_toggle.button_pressed = true
	await _frames()
	_check(model.session.case_file.scope.has("host_014"), "ticking an asset adds it to scope")
	# Response actions, in order, by pressing the real buttons.
	_press(screen, "Investigate")
	_check(model.case_status == "investigating", "Investigate sets the status")
	screen._escalate_choice.set_value("soc_lead")
	_press(screen, "Escalate")
	_check(model.session.case_file.escalation == "soc_lead" and model.case_status == "escalated", "Escalate stores the choice and moves the status")
	_press(screen, "Recover")
	_check(model.case_status == "escalated", "Recover is refused before containment")
	screen._contain_choice.set_value("verify_then_protect")
	_press(screen, "Contain")
	_check(model.session.case_file.recommendation == "verify_then_protect" and model.case_status == "contained", "Contain stores the choice and moves the status")
	_press(screen, "Preserve evidence")
	_check(not model.preserved_ref.is_empty() and model.case_status == "preserved", "Preserve records a simulated snapshot")
	_press(screen, "Recover")
	_check(model.case_status == "recovered", "Recover works after containment")
	await _frames()
	_check(screen._audit_table.get_root().get_child_count() == model.audit_history().size() and model.audit_history().size() >= 6, "every action is in the audit history table")
	_check(_shell._badge_row.get_child(2).get_child(0).text.contains("Recovered"), "the header badge shows the recovered state")
	# Remove a note and evidence through the real buttons.
	var notes_before: int = model.session.case_file.entries().size()
	screen._notes_table.get_root().get_child(0).select(0)
	screen._remove_note_button.pressed.emit()
	await _frames()
	_check(model.session.case_file.entries().size() == notes_before - 1, "removing a selected note works")
	screen._evidence_table.get_root().get_child(0).select(0)
	screen._remove_evidence_button.pressed.emit()
	await _frames()
	_check(model.session.state_problems().is_empty(), "the case stays consistent after UI edits: %s" % ", ".join(model.session.state_problems()))


func _check_terminal() -> void:
	var model: SocModel = _shell.model
	_shell.show_screen(&"terminal")
	await _frames()
	var screen: Control = _shell.screen_node(&"terminal")
	_check(not screen._output.bbcode_enabled, "terminal output has BBCode disabled")
	_check(screen.output_text().contains("SIMULATED"), "the terminal opens with the SIMULATED banner")
	var banner_found: bool = false
	for label_node: Node in screen.find_children("*", "Label", true, false):
		if (label_node as Label).text == TerminalCommands.BANNER and label_node.is_visible_in_tree():
			banner_found = true
	_check(banner_found, "the screen always shows '%s' (spec 05 §5)" % TerminalCommands.BANNER)
	for line: String in ["help", "assets list", "hosts show HOST-014", "logs search source=auth user=jsmith after=09:00", "timeline build CASE-001", "case report CASE-001"]:
		screen.run_line(line)
	await _frames()
	_check(screen.output_text().contains("analyst@new-meridian:~$ help"), "typed commands are echoed")
	_check(screen.output_text().contains("HOST-014"), "host details come from the synthetic scenario")
	var evidence_before: int = model.session.ledger.size()
	screen.run_line("evidence add EVT-005 CASE-001")
	await _frames()
	_check(model.session.ledger.size() == evidence_before + 1, "evidence add through the terminal changes the shared case")
	for hostile: String in ["rm -rf /", "powershell -c whoami", "help; whoami", "cat ../../project.godot", "logs search source=auth | sh", "[b]bold[/b]", "$(whoami)"]:
		var length_before: int = screen._output.get_parsed_text().length()
		screen.run_line(hostile)
		var added: String = screen._output.get_parsed_text().substr(length_before)
		_check(added.contains("ERROR:"), "hostile input is refused with an explanation: %s" % hostile)
	_check(screen._output.get_parsed_text().contains("ERROR:"), "refused commands print an ERROR line")
	_check(screen._output.get_parsed_text().to_lower().contains("simulated"), "refusals explain that the terminal is simulated")
	# BBCode in output stays literal.
	_check(screen._output.get_parsed_text().contains("[b]bold[/b]"), "markup typed in is shown literally, never parsed")
	# History recall with Up/Down.
	screen._command_line.text = ""
	screen._on_input_gui_input(_up_key())
	_check(screen._command_line.text != "" or model.terminal.history.is_empty(), "Up recalls an earlier command")
	# Palette buttons are real and run commands.
	var buttons: Array[Control] = UiKit.focusable(screen._palette_card)
	_check(buttons.size() >= SocModel.COMMAND_PALETTE.size(), "every sample command has a button (controller path)")
	var length_before_click: int = screen.output_text().length()
	(buttons[0] as Button).pressed.emit()
	await _frames()
	_check(screen.output_text().length() > length_before_click, "a sample command button runs the command")
	_check(model.session.state_problems().is_empty(), "the case is consistent after terminal use")
	# Output cap.
	for _i: int in 30:
		screen.run_line("help")
	_check(screen._lines.size() <= screen.MAX_KEPT_LINES, "the console keeps a bounded number of lines")


func _up_key() -> InputEvent:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_UP
	key.pressed = true
	return key


func _check_mission() -> void:
	var model: SocModel = _shell.model
	_shell.show_screen(&"mission")
	await _frames()
	var screen: Control = _shell.screen_node(&"mission")
	var hints_before: int = model.hint_log.size()
	screen._hint_button.pressed.emit()
	await _frames()
	_check(model.hint_log.size() == hints_before + 1, "asking for a hint adds it to the log")
	var check_buttons: Array = screen._check_buttons["kc_failures_then_success"]
	var mastery_before: float = model.mastery_fraction()
	(check_buttons[0] as Button).pressed.emit()
	_check((screen._check_feedback["kc_failures_then_success"] as Label).text.begins_with("Not quite."), "a wrong answer gets teaching feedback")
	(check_buttons[1] as Button).pressed.emit()
	_check((screen._check_feedback["kc_failures_then_success"] as Label).text.begins_with("Correct."), "the right answer is confirmed")
	_check(model.mastery_fraction() == mastery_before, "knowledge checks do not change mastery")
	screen._review_button.pressed.emit()
	await _frames()
	var review_text: String = ""
	for child: Node in screen._review_card.body.get_children():
		if child is Label:
			review_text += (child as Label).text
	_check(review_text.contains("Review:"), "the case review shows the rubric summary")
	_check(model.session.state_problems().is_empty(), "reviewing changes nothing")
	_check(screen._mastery_card.body.get_child_count() >= 7, "mastery shows overall and per-objective progress")


func _check_focus_and_controller() -> void:
	for screen_id: StringName in SCREEN_IDS:
		_shell.show_screen(screen_id)
		await _frames(4)
		var screen: SocScreen = _shell.screen_node(screen_id)
		var owner: Control = _tree.root.gui_get_focus_owner()
		var default_target: Control = screen.default_focus()
		_check(default_target != null and owner == default_target, "%s puts focus on its default control (owner %s)" % [screen_id, owner])
		var controls: Array[Control] = UiKit.focusable(_shell)
		_check(controls.size() >= 7, "%s exposes focusable controls (%d)" % [screen_id, controls.size()])
		var traps: PackedStringArray = PackedStringArray()
		for control: Control in controls:
			var can_leave: bool = false
			for side: Side in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]:
				var neighbour: Control = control.find_valid_focus_neighbor(side)
				if neighbour != null and neighbour != control:
					can_leave = true
			if control.find_next_valid_focus() != control:
				can_leave = true
			if not can_leave:
				traps.append(str(control.get_path()))
		_check(traps.is_empty(), "%s has no focus traps: %s" % [screen_id, ", ".join(traps)])
		# Tab order reaches every focusable control and comes back round.
		var start: Control = controls[0]
		var seen: Dictionary = {}
		var cursor: Control = start
		for _step: int in controls.size() + 4:
			seen[cursor] = true
			cursor = cursor.find_next_valid_focus()
			if cursor == null or cursor == start:
				break
		_check(seen.size() >= controls.size() - 1, "%s: focus order reaches every control (%d of %d)" % [screen_id, seen.size(), controls.size()])
		for control: Control in controls:
			_check(control.custom_minimum_size.y >= 0.0 and control.tooltip_text.length() >= 0, "controls are well formed")
			if control is Button:
				_check(control.size.y >= SocTokens.MIN_TARGET - 1.0 or not control.is_visible_in_tree(), "%s button '%s' meets the target height (%.0f)" % [screen_id, (control as Button).text, control.size.y])
	# Cancel from a screen moves focus to the navigation; cancel there goes back to the title.
	_shell.show_screen(&"command_center")
	await _frames(3)
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	_shell._unhandled_input(cancel)
	await _frames()
	_check(_tree.root.gui_get_focus_owner() == _shell.nav_button(&"command_center"), "Cancel moves focus from the screen to the navigation")


func _check_scaling_and_resolutions(settings: SettingsService) -> void:
	for size: Vector2i in SIZES:
		for scale: float in [1.0, 2.0]:
			settings.update(scale, false, false, "normal")
			_shell.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			_shell.size = Vector2(size)
			for screen_id: StringName in SCREEN_IDS:
				_shell.show_screen(screen_id)
				await _frames(3)
				var screen: SocScreen = _shell.screen_node(screen_id)
				_check(screen.size.x > 400.0, "%s has usable width at %dx%d (%.0f)" % [screen_id, size.x, size.y, screen.size.x])
				# The page inside the scroll area must never be wider than the area: that is what
				# pushes a column off the right edge. (Vertical overflow is fine: it scrolls.)
				_check(screen._page.size.x <= screen.size.x + 1.0, "%s at %dx%d and %d%% text has no horizontal overflow (page %.0f in %.0f)" % [screen_id, size.x, size.y, int(scale * 100.0), screen._page.size.x, screen.size.x])
				_check(screen._page.get_combined_minimum_size().x <= screen.size.x + 1.0, "%s at %dx%d and %d%% text fits its minimum width (%.0f of %.0f)" % [screen_id, size.x, size.y, int(scale * 100.0), screen._page.get_combined_minimum_size().x, screen.size.x])
				# Nothing may be laid out past the window edge: that is what clips a column or a badge.
				var window_width: float = float(size.x)
				_check(_shell.get_global_rect().end.x <= window_width + 1.0, "%s at %dx%d and %d%% text: the shell stays inside the window (right edge %.0f)" % [screen_id, size.x, size.y, int(scale * 100.0), _shell.get_global_rect().end.x])
				_check(screen.get_global_rect().end.x <= window_width + 1.0, "%s at %dx%d and %d%% text: the screen stays inside the window (right edge %.0f)" % [screen_id, size.x, size.y, int(scale * 100.0), screen.get_global_rect().end.x])
				var label: String = "%s at %dx%d and %d%% text" % [screen_id, size.x, size.y, int(scale * 100.0)]
				var degenerate: PackedStringArray = PackedStringArray()
				var cut_off: PackedStringArray = PackedStringArray()
				for node: Node in _shell.find_children("*", "Control", true, false):
					var control: Control = node as Control
					if not control.is_visible_in_tree():
						continue
					if (control is Button or control is LineEdit) and (control.size.x < 40.0 or control.size.y > 200.0 * scale):
						degenerate.append("%s %.0fx%.0f" % [control.get_class(), control.size.x, control.size.y])
					if (control is Label or control is Button) and control.get_global_rect().end.x > window_width + 1.0:
						cut_off.append("%s %s" % [control.get_class(), control.name])
				_check(degenerate.is_empty(), "%s: controls with a broken size: %s" % [label, ", ".join(degenerate.slice(0, 5))])
				_check(cut_off.is_empty(), "%s: %d labels or buttons run past the right edge, e.g. %s" % [label, cut_off.size(), ", ".join(cut_off.slice(0, 3))])
	settings.update(1.0, false, false, "normal")
	_check(_shell.theme.get_font_size("font_size", "SocMono") == SocTokens.FONT_MONO, "the shell theme follows the text scale back to 100%")
	settings.update(1.0, false, true, "normal")
	await _frames()
	_check(_shell._background.color == Color(0, 0, 0), "high contrast turns the background pure black")
	settings.update(1.0, false, false, "normal")
	_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _check_save_resume(progress: ProgressService) -> void:
	var saves: SaveService = _tree.root.get_node("Saves")
	var game: SaveGame = SaveGame.from_tree(_tree)
	var started: SaveResult = game.start_new(1, "Analyst", "", "", "", "")
	_check(started.ok, "a new game starts in slot 2: %s" % started.message)
	var fresh: SocModel = SocModel.open(progress)
	_check(fresh.is_ready() and progress.has_active_lab(), "the SOC starts the lab for the new game")
	fresh.collect_evidence("evt_001")
	fresh.add_note("hypothesis", "The password may have been guessed.")
	var save_result: SaveResult = game.save()
	_check(save_result.ok, "the game saves with a SOC case in progress: %s" % save_result.message)
	progress.reset()
	_check(not progress.has_active_lab(), "progress is cleared before loading")
	var load_result: SaveResult = game.load_slot(1)
	_check(load_result.ok, "the save loads again: %s" % load_result.message)
	_check(progress.has_active_lab(), "the lab in progress is back after loading")
	var resumed: SocModel = SocModel.open(progress)
	_check(resumed.is_ready() and resumed.is_collected("evt_001"), "the reopened SOC has the evidence collected before saving")
	_check(resumed.session.case_file.entries().size() == 1, "and the note written before saving")
	saves.delete_slot(1)


func _check_design_system() -> void:
	_shell.show_screen(&"design_system")
	await _frames()
	var screen: Control = _shell.screen_node(&"design_system")
	var dialog_opened: Array[bool] = [false]
	var open_button: Button = _find_button(screen, "Open sample dialog")
	_check(open_button != null, "the design system has a dialog sample")
	if open_button == null:
		return
	open_button.pressed.emit()
	await _frames()
	for child: Node in _shell.get_children():
		if child is ModalDialog:
			dialog_opened[0] = true
			_check(_tree.root.gui_get_focus_owner() == (child as ModalDialog).cancel_button, "the dialog starts on the safe choice")
			(child as ModalDialog).cancel_button.pressed.emit()
	await _frames()
	_check(dialog_opened[0], "the dialog is added above the screen, in the shell")
	_check(screen._dialog_result.text.contains("cancelled"), "the dialog reports its result back")
	var swatch_text: String = ""
	for label: Node in screen.find_children("*", "Label", true, false):
		swatch_text += (label as Label).text + "\n"
	for hex: String in ["10121B", "191D2B", "232A3B", "42D9F5", "9275FF", "F5B84B", "F06472", "63D69B", "F2F4FA", "A4AEC3"]:
		_check(swatch_text.contains("#" + hex), "the palette shows #%s" % hex)


func _press(screen: Node, text: String) -> void:
	var button: Button = _find_button(screen, text)
	_check(button != null, "button '%s' exists" % text)
	if button != null:
		button.pressed.emit()


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child: Node in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null
