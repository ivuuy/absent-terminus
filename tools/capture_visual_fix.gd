extends SceneTree

# Render the affected seats and window through the real game camera. Test mode
# keeps captures isolated from the player's save and leaves the mouse free.
var game: Node3D

func _initialize() -> void:
	run.call_deferred()

func capture(file: String, from: Vector3, toward: Vector3) -> void:
	game.player.place(from)
	game.player.camera.look_at(toward)
	game.player.flashlight.visible = true
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(file)
	print("CAPTURE ", file)

func run() -> void:
	var output := "res://artifacts/visual_fix"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.start_journey(false)
	game.hud.hide_modal()
	game.player.enabled = false
	game.player.mouse_look_enabled = false
	game.set_process(false)
	game.world.set_process(false)
	game.flags.photo = true
	game._recount_anchors()
	game.era = 2
	game.loops = 9
	game.hud.subtitle_time = 0
	game.hud.toast_time = 0
	for level in range(4):
		game.flags.anomaly_level = level
		game._sync_world()
		game._refresh_status()
		await capture(output + "/window_%d.png" % level, Vector3(0.15, 0.09, -5.92), Vector3(2.01, 1.48, -6.0))
		if level == 1:
			await capture(output + "/window_oblique.png", Vector3(0.1, 0.09, -4.95), Vector3(2.01, 1.4, -6.0))
		if level in [1, 2]:
			await capture(output + "/seats_%d.png" % level, Vector3(0.05, 0.09, 1.8), Vector3(0.7, 1.1, -1.0))
			await capture(output + "/plaque_%d.png" % level, Vector3(0, 0.09, 2.8), Vector3(1.3, 1.15, 1.35))
	game.flags.conductor_event = 3
	game._sync_world()
	await capture(output + "/records.png", Vector3(0, 0.09, -8.9), Vector3(-1.3, 0.86, -9.6))
	game.queue_free()
	await process_frame
	quit()
