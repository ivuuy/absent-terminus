extends SceneTree

var game: Node3D
var horror: Node
var checks := 0
var failures := 0
var capture_enabled := false

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition: print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func capture(name_key: String) -> void:
	if not capture_enabled: return
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/horror/" + name_key + ".png"
	check(root.get_texture().get_image().save_png(path) == OK, "Capture " + name_key)

func run() -> void:
	capture_enabled = OS.get_cmdline_user_args().has("--capture-horror")
	if capture_enabled: DirAccess.make_dir_recursive_absolute("res://artifacts/horror")
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	horror = game.get_node("QuietHorror")
	check(horror.initialized, "Director initializes after the world and HUD")
	horror.set_process(false)
	game.set_process(false)
	game.world.set_process(false)
	check(not horror.trigger_event("jumpscare"), "Title screen cannot trigger a scare")
	game.start_journey(false)
	game._on_ui_action("guide_start", "")
	game.player.enabled = false
	game.player.mouse_look_enabled = false
	game.hud.subtitle_time = 0.0
	game.spatial_audio.stop()
	horror._process(0.1)
	check(not horror.trigger_event("jumpscare"), "First scare waits until the photograph has been found")
	game.flags.photo = true
	var before: Dictionary = game.flags.duplicate(true)
	var camera_before: Transform3D = game.player.camera.transform
	var normal_energy: float = game.world.warm_lights[0].light_energy
	var normal_hidden_energy: float = game.world.hidden_lights[0].light_energy
	check(horror.trigger_event("power"), "Power dip starts during exploration")
	horror._process(1.65)
	check(game.world.warm_lights[0].light_energy < normal_energy * 0.5, "Warm lights dim visibly")
	check(game.world.window_lights[0].light_energy > 0.7, "Window light keeps the route visible")
	await capture("power_dip")
	game.pause_game()
	horror._process(0.1)
	check(horror.event_kind == "" and not horror.cue.playing and not horror.drone.playing, "Pause stops incidental audio and events")
	check(is_equal_approx(game.world.warm_lights[0].light_energy, normal_energy), "Pause restores lamp brightness")
	check(not horror.overlay.visible and not horror.face.visible, "Pause clears visual overlays")
	game.close_modal()
	game.player.enabled = false
	check(horror.trigger_event("steps"), "Spatial footsteps start")
	var offset: Vector3 = horror.cue.position - game.player.position
	check(offset.dot(game.player.global_basis.z) > 0.0, "Footsteps are behind the player")
	game.hud.speak("测试中的剧情广播", 5.0)
	horror._process(0.1)
	check(horror.event_kind == "" and not horror.trigger_event("power"), "Narrative subtitles suppress incidental scares")
	game.hud.subtitle_time = 0.0
	game.player.place(Vector3(0, 0.09, -3.2))
	check(horror.trigger_event("reflection") and horror.apparition.visible, "A fleeting figure appears on a nearby window")
	horror._process(1.0)
	game.player.camera.look_at(horror.apparition.global_position)
	await capture("window_presence")
	horror._process(0.3)
	horror._process(0.6)
	check(not horror.apparition.visible, "Looking directly at the figure makes it dissolve")
	game.player.place(Vector3(0, 0.09, 0.8))
	check(horror.trigger_event("jumpscare"), "A close face scare starts after finding the photograph")
	horror._process(0.60)
	check(not horror.face.visible, "Face stays hidden during the brief light dip")
	horror._process(0.45)
	check(horror.face.visible and horror.sting.playing, "The face and sting appear together")
	await capture("jumpscare")
	horror._process(0.85)
	check(not horror.face.visible and not horror.sting.playing, "Scare clears in under two seconds")
	check(not horror.trigger_event("jumpscare"), "Jump scares cannot repeat during the cooldown")
	check(game.flags == before, "Scares preserve inventory, story flags and anomaly level")
	check(game.player.camera.transform == camera_before, "Scares do not change the camera pose")
	horror.jump_cooldown = 0.0
	horror.trigger_event("jumpscare")
	horror._process(1.0)
	game.open_journal()
	horror._process(0.1)
	check(not horror.face.visible and not horror.sting.playing and not horror.trigger_event("jumpscare"), "Opening a clue or journal immediately clears the face and audio")
	game.close_modal()
	game.player.enabled = false
	horror.trigger_event("power")
	horror._process(1.6)
	game.era = 2
	game._sync_world()
	horror._process(0.1)
	check(horror.event_kind == "" and is_equal_approx(game.world.window_lights[0].light_energy, 1.6), "Changing eras clears the dip without restoring stale lighting")
	check(is_equal_approx(game.world.materials.lamp.emission_energy_multiplier, 0.03), "Abandoned lamps retain their new era emission")
	game.location = "maintenance"
	game._sync_world()
	game.player.place(game.spawn_for("maintenance"))
	horror._process(0.1)
	horror.trigger_event("reflection")
	check(not horror.apparition.visible and horror.event_kind == "power", "Hidden rooms use light effects without a misplaced window figure")
	horror._process(1.6)
	check(game.world.hidden_lights[0].light_energy < 1.6, "Hidden-room lighting also supports the dip")
	game.flags.arrived = true
	game.world.reveal_platform()
	horror._process(0.1)
	check(not horror.overlay.visible and not horror.trigger_event("power"), "The ending platform stays free of incidental scares")
	game.start_journey(false)
	horror._process(0.1)
	check(horror.event_index == 0 and horror.jump_cooldown == 0.0 and not horror.face.visible, "New journeys reset all temporary scare state")
	check(is_equal_approx(game.world.hidden_lights[0].light_energy, normal_hidden_energy), "Restart leaves hidden lamps restored")
	game._on_ui_action("guide_start", "")
	game.hud.subtitle_time = 0.0
	game.spatial_audio.stop()
	game.flags.photo = true
	# Exercise the real scheduler without running the game loop or saving.
	game.test_mode = false
	horror.event_index = 1
	horror.cooldown = 0.01
	horror._process(0.1)
	check(horror.event_kind == "jumpscare" and horror.event_index == 2, "The automatic exploration schedule reaches a jump scare")
	game.test_mode = true
	var remaining: float = horror.jump_cooldown
	game.pause_game()
	horror._process(40.0)
	check(is_equal_approx(remaining, horror.jump_cooldown), "Pausing does not advance the jump-scare cooldown")
	game.close_modal()
	game.flags.finished = true
	horror._process(0.1)
	check(not horror.trigger_event("jumpscare") and not horror.drone.playing, "Completed endings stop the horror ambience")
	game.queue_free()
	game = null
	horror = null
	for i in range(3): await physics_frame
	# Give the audio mixer time to release stopped playbacks in headless runs.
	await create_timer(0.25).timeout
	print("HORROR RESULT: %d checks, %d failures" % [checks, failures])
	quit.call_deferred(0 if failures == 0 else 1)
