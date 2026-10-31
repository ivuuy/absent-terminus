extends SceneTree

var failures: Array[String] = []
var checks := 0
var game: Node3D
const POS := {
	"photo": Vector3(0, 0.09, -9.1), "anchor_1": Vector3(0, 0.09, -9.5),
	"radio": Vector3(0, 0.09, -11.6), "door_front": Vector3(0, 0.09, -10.65), "door_back": Vector3(0, 0.09, 1.2),
	"maintenance_entry": Vector3(0, 0.09, -4.1), "key": Vector3(0, 0.09, -4.1),
	"service_notes": Vector3(120, 0.09, 0.9), "ticket_punch": Vector3(120, 0.09, -1.2),
	"wall_marks": Vector3(119, 0.09, -0.2), "pressure_valve": Vector3(120, 0.09, 0.8),
	"anchor_2": Vector3(120, 0.09, -0.6), "service_clock": Vector3(120, 0.09, 1.2),
	"truth_log_1": Vector3(120, 0.09, -0.7), "roof_hatch": Vector3(120, 0.09, -0.6),
	"relay": Vector3(140, 0.09, 0.4), "roof_marks": Vector3(140, 0.09, -0.7), "truth_log_2": Vector3(140, 0.09, -0.7),
	"roof_exit": Vector3(140, 0.09, 0.8), "maintenance_exit": Vector3(120, 0.09, 1),
	"route": Vector3(0, 0.09, -11.6), "postcard": Vector3(0, 0.09, -3.1),
	"memory_entry": Vector3(0, 0.09, -7.9), "badge": Vector3(160, 0.09, 0.8),
	"memory_clock": Vector3(160, 0.09, 1), "memory_exit": Vector3(160, 0.09, 1),
	"truth_log_3": Vector3(160, 0.09, 1.1), "ending": Vector3(80, 0.09, -9.5),
	"foreign_ticket": Vector3(0, 0.09, -6.2), "check_record": Vector3(0, 0.09, -8.8), "conductor": Vector3(0, 0.09, -9.5)
}

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition: print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

func frames(count: int = 3) -> void:
	for i in range(count): await physics_frame

func settle() -> void:
	for i in range(300):
		if game.mode != "transition": return
		await frames()
	check(false, "Transition completes")

# Move to reachable floor positions, aim the real player ray and send E.
func use(id: String) -> void:
	if game.mode != "play":
		check(false, "Cannot use %s while %s/%s" % [id, game.mode, game.hud.modal_kind])
		return
	game.player.place(POS[id])
	await frames(12)
	game.player.camera.look_at(game.world.hotspots[id].global_position)
	game.player.ray.force_raycast_update()
	var target: TrainInteractable = game.player.target()
	var reached := target != null and target.interaction_id == id
	check(reached, "Physical E interaction: " + id)
	if not reached:
		print("RAY DEBUG ", id, " position=", game.player.position, " hit=", game.player.ray.get_collider())
		return
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	game._unhandled_input(event)
	await frames(5)

func ui_button(action: String, value: String = "") -> Button:
	for node in game.hud.modal_content.get_children():
		if node is Button and node.get_meta("action", "") == action and node.get_meta("payload", "") == value: return node
	return null

func click(action: String, value: String = "") -> void:
	var item := ui_button(action, value)
	check(item != null and not item.disabled, "Available UI action: %s %s" % [action, value])
	if item != null and not item.disabled: item.pressed.emit()
	await frames(5)

func close_panel() -> void:
	if game.mode == "modal": await click("close")

func read_note(id: String) -> void:
	await use(id)
	check(game.mode == "modal" and game.hud.modal_kind == "note", "Readable clue: " + id)
	await close_panel()

func travel(era: int, source: String = "door_front") -> void:
	var before: int = game.era
	await use(source)
	check(game.hud.modal_kind == "eras" and game.era == before, "Opening a time doorway does not change era")
	var position: Vector3 = game.player.position
	await click("era", str(era))
	await settle()
	check(game.era == era and game.player.position.distance_to(position) < 0.03, "Player selects an era and stays in place")

func new_game() -> void:
	game.start_journey(false)
	check(game.hud.modal_kind == "help" and not game.player.enabled, "New game teaches the rules before movement")
	await click("guide_start")
	await frames(15)
	check(game.flags.guide_seen and game.player.enabled and game.player.is_on_floor(), "Tutorial starts an actionable journey")

func solve_broadcast(extra_checks: bool = false) -> void:
	if extra_checks:
		await use("radio")
		check(ui_button("install_radio").disabled, "Broadcast repair shows missing items and disables installation")
		game._on_ui_action("install_radio", "")
		check(not game.flags.circuit_ready, "Missing inventory cannot bypass contextual repair")
		await close_panel()
	await read_note("photo")
	check(game.current_goal().target == "anchor_1", "Photo points to the adjacent lever")
	await use("anchor_1")
	await click("repair_device", "1")
	check(game.flags.anchor_1_bound and game.flags.latch_open, "One action permanently opens the maintenance door")
	if extra_checks:
		await use("maintenance_entry")
		check(game.location == "carriage" and game.flags.anomaly_level == 0, "An early locked door explains the requirement without punishment")
	await travel(1)
	await use("maintenance_entry")
	check(game.location == "maintenance" and not game.world.hotspots.door_front.active, "Entering maintenance disables interactions in the carriage")
	await read_note("service_notes")
	if extra_checks:
		await read_note("ticket_punch")
		check(game.flags.ticket_code, "Ticket is punched automatically with the collected tool")
		await read_note("wall_marks")
		await travel(2, "service_clock")
		await use("pressure_valve")
		check(ui_button("repair_device", "2").disabled, "Wrong-era valve explains the correct era")
		game._on_ui_action("repair_device", "2")
		check(not game.flags.anchor_2_bound and game.flags.anomaly_level == 0, "Wrong-era operation preserves all progress")
		await close_panel()
		await use("roof_hatch")
		check(game.location == "maintenance", "Unvented roof cannot be entered early")
		await travel(1, "service_clock")
	await use("pressure_valve")
	await click("repair_device", "2")
	check(game.flags.anchor_2_bound and game.flags.valve_vented, "One valve operation unlocks the later inspection hatch")
	await travel(2, "service_clock")
	check(not game.world.hatch_leaf.visible, "Vent repair carries across eras visually")
	await use("roof_hatch")
	check(game.location == "roof", "Roof inspection room opens in the future")
	await read_note("relay")
	if extra_checks: await read_note("roof_marks")
	await use("roof_exit")
	await use("maintenance_exit")
	await read_note("key")
	await travel(1, "door_back")
	await use("memory_entry")
	check(game.location == "memory", "Relay reveals a usable memory room in the blackout")
	await read_note("badge")
	await use("memory_exit")
	await travel(0)
	await use("radio")
	await click("install_radio")
	check(game.flags.circuit_ready and game.flags.anchor_3_bound and game.hud.modal_kind == "radio", "Three collected items install together and automatically tune the radio")
	await close_panel()
	check(game.current_goal().target == "route", "Broadcast clue points to the route map before the final answer")
	await read_note("route")
	if extra_checks: await read_note("postcard")
	await use("radio")
	if extra_checks:
		var before: int = game.flags.anomaly_level
		await click("station", "雾港")
		check(game.hud.modal_kind == "radio" and not game.flags.repair_signal and game.flags.anomaly_level == before, "Wrong station gives an immediate retry without reset or penalty")
	await click("station", "白桦")
	check(game.flags.repair_signal and game.hud.modal_kind == "ending_choice", "Route reasoning restores the broadcast and opens the ending choice")

func optional_investigation() -> void:
	check(ui_button("ending_expose").disabled, "Truth ending explains its three-record requirement")
	await click("investigate")
	check(game.flags.investigating and game.flags.ending_pending == 0 and game.current_goal().target == "door_front", "Optional investigation gives a concrete next destination")
	await travel(2)
	await use("maintenance_entry")
	await read_note("truth_log_1")
	check(game.current_goal().target == "roof_hatch", "Investigation leads from record one to the roof")
	await use("roof_hatch")
	await read_note("truth_log_2")
	await use("roof_exit")
	await use("maintenance_exit")
	await travel(1)
	await use("memory_entry")
	check(game.current_goal().target == "memory_clock", "Memory record directs the player to change era inside the room")
	await travel(2, "memory_clock")
	await read_note("truth_log_3")
	check(game.flags.truth_fragments == 3, "All optional records are reachable by ordinary exploration")
	await use("memory_exit")
	await travel(0)
	await use("radio")
	check(not ui_button("ending_expose").disabled, "Complete investigation unlocks the third ending")

func journal_text() -> String:
	for item in game.hud.modal_content.get_children():
		if item is RichTextLabel: return item.text
	return ""

func verify_saves() -> void:
	game.test_mode = false
	game._save_journey()
	game.test_mode = true
	var saved := ConfigFile.new()
	saved.load(game.save_path)
	check(saved.get_value("journey", "version") == 3 and saved.get_value("journey", "gameplay") == "guided_story", "New save records the guided mode and schema v3")
	game.start_journey(true)
	check(game.flags.guide_seen and game.mode == "play", "Returning player resumes without repeating onboarding")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))

	var old := ConfigFile.new()
	old.set_value("journey", "version", 2)
	old.set_value("journey", "era", 2)
	old.set_value("journey", "flags", {"photo": true, "relay": true, "truth_1": true, "truth_fragments": 1, "anomaly_level": 4})
	old.save(game.previous_save_path)
	game.test_mode = false
	game.start_journey(true)
	game.test_mode = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	saved.load(game.save_path)
	check(saved.get_value("journey", "version") == 3, "Loading v2 automatically writes an independent v3 save")
	check(game.flags.anchor_1_bound and game.flags.anchor_2_bound and game.flags.memory_unlocked, "v2 partial saves restore permanent repairs and accessible rooms")
	check(game.flags.truth_1 and game.flags.relay and game.flags.truth_fragments == 1 and game.flags.anomaly_level == 3, "v2 migration preserves discovered clues and inventory")
	check(game.hud.modal_kind == "help", "Old saves explain the changed gameplay on first load")
	await click("guide_start")
	check(game.current_goal().target == "key", "Migrated progress leads to the next missing item")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.previous_save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))

	old = ConfigFile.new()
	old.set_value("journey", "version", 1)
	old.set_value("journey", "flags", {"photo": true, "solved": true, "arrived": true})
	old.save(game.legacy_save_path)
	game.start_journey(true)
	check(game.flags.repair_signal and game.flags.key and game.flags.anchor_1_bound and game.world.on_platform, "v1 completed broadcast remains a valid arrival")
	await click("guide_start")
	await use("ending")
	await settle()
	check(game.flags.ending_id == 1 and game.flags.finished, "Migrated v1 arrival still reaches its ending")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.legacy_save_path))

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	var suffix := str(OS.get_process_id())
	game.save_path = "user://guided_test_v3_" + suffix + ".cfg"
	game.previous_save_path = "user://guided_test_v2_" + suffix + ".cfg"
	game.legacy_save_path = "user://guided_test_v1_" + suffix + ".cfg"
	root.add_child(game)
	await frames(8)
	check(game.mode == "menu", "Boot opens title screen")
	await new_game()
	check(game.current_goal().target == "photo" and game.hud.navigation.visible, "First objective and world marker point to the photo")
	var help_key := InputEventKey.new()
	help_key.pressed = true
	help_key.physical_keycode = KEY_H
	game._unhandled_input(help_key)
	check(game.hud.modal_kind == "help" and journal_text().contains("现在要做"), "H help includes the current actionable step")
	await click("guide_start")
	await solve_broadcast(true)
	await click("ending_leave")
	await use("radio")
	await optional_investigation()
	await click("ending_expose")
	await settle()
	check(game.flags.ending_id == 3 and game.flags.finished, "Truth ending completes through the guided investigation")

	await new_game()
	check(not game.flags.investigating and not game.flags.anchor_1_bound and game.flags.anomaly_level == 0, "Restart clears investigation, repairs and atmosphere")
	await solve_broadcast()
	await click("ending_takeover")
	await use("door_front")
	await settle()
	check(game.flags.ending_id == 2 and game.flags.finished and game.flags.conductor_trust, "Takeover ending completes through the physical door")

	await new_game()
	await solve_broadcast()
	await click("ending_leave")
	await use("door_back")
	await settle()
	check(game.world.on_platform and game.flags.arrived, "Leave ending opens the snow platform")
	await use("ending")
	await settle()
	check(game.flags.ending_id == 1 and game.flags.finished, "Leave ending completes at the waiting passenger")

	await new_game()
	await read_note("photo")
	game.handle_conductor_event(3)
	check(game.flags.conductor_event == 0, "Conductor event sequence cannot skip forward")
	for index in range(1, 6): game.handle_conductor_event(index)
	check(game.world.conductor_figure.visible and game.world.reflection_figure.visible, "Story events preserve conductor horror and reflections")
	await read_note("foreign_ticket")
	await read_note("check_record")
	await use("conductor")
	await click("trust", "yes")
	var position: Vector3 = game.player.position
	game.increase_anomaly(20)
	check(game.flags.photo and game.flags.foreign_ticket and game.flags.conductor_trust and game.player.position.distance_to(position) < 0.01, "High atmosphere never resets exploration or teleports the player")
	game.open_journal()
	check(journal_text().contains("广播修复清单") and journal_text().contains("陌生车票") and journal_text().contains("07 席照片"), "Journal retains collected story clues and repair checklist")
	await close_panel()
	await verify_saves()
	await new_game()
	check(not game.flags.finished and game.flags.ending_id == 0 and not game.flags.conductor_trust, "Restart after migrated ending clears outcome state")
	for path in [game.save_path, game.previous_save_path, game.legacy_save_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("INTEGRATION RESULT: %d checks, %d failures" % [checks, failures.size()])
	game.queue_free()
	game = null
	await frames(3)
	quit.call_deferred(0 if failures.is_empty() else 1)
