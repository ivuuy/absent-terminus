extends Node
## Brief, low-intensity scares. No puzzle flags, camera transforms or saves are
## changed here. All timing uses active play time, never background timers.

const FILM = preload("res://shaders/horror_film.gdshader")
const PRESENCE = preload("res://shaders/horror_presence.gdshader")
const FACE = preload("res://shaders/horror_face.gdshader")
const EVENT_ORDER := ["power", "jumpscare", "steps", "reflection"]

var game: Node3D
var overlay: ColorRect
var apparition: MeshInstance3D
var drone: AudioStreamPlayer
var cue: AudioStreamPlayer3D
var face: ColorRect
var sting: AudioStreamPlayer
var jump_cooldown := 0.0
var jump_started := false
var rng := RandomNumberGenerator.new()
var initialized := false
var cooldown := 16.0
var event_kind := ""
var event_age := 0.0
var event_index := 0
var tension := 0.0
var active_time := 0.0
var gaze_time := 0.0
var dissolve_age := -1.0
var previous_era := -1
var previous_location := ""
var journey_flags: Dictionary
var light_overrides: Array[Dictionary] = []
var lamp_original := 0.0
var lamp_applied := -1.0

func _ready() -> void:
	game = get_parent()
	# Children become ready before the game builds its world and HUD.
	game.ready.connect(_setup, CONNECT_ONE_SHOT)
	process_priority = 10

func _setup() -> void:
	rng.randomize()
	var layer := CanvasLayer.new()
	layer.layer = 8 # Under the HUD: clues, menus and interaction text stay crisp.
	add_child(layer)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var film := ShaderMaterial.new()
	film.shader = FILM
	overlay.material = film
	overlay.visible = false
	layer.add_child(overlay)
	var scare_layer := CanvasLayer.new()
	scare_layer.layer = 11
	add_child(scare_layer)
	face = ColorRect.new()
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face_material := ShaderMaterial.new()
	face_material.shader = FACE
	face.material = face_material
	face.visible = false
	scare_layer.add_child(face)
	sting = AudioStreamPlayer.new()
	sting.stream = load("res://assets/audio/horror_sting.wav")
	sting.volume_db = -13.0
	add_child(sting)
	apparition = MeshInstance3D.new()
	apparition.name = "FleetingWindowPassenger"
	var pane := QuadMesh.new()
	pane.size = Vector2(0.68, 1.17)
	apparition.mesh = pane
	var surface := ShaderMaterial.new()
	surface.shader = PRESENCE
	apparition.material_override = surface
	apparition.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	apparition.visible = false
	add_child(apparition)
	drone = AudioStreamPlayer.new()
	var stream := load("res://assets/audio/horror_drone.wav") as AudioStreamWAV
	stream = stream.duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	drone.stream = stream
	drone.volume_db = -60.0
	add_child(drone)
	cue = AudioStreamPlayer3D.new()
	cue.max_distance = 12.0
	cue.unit_size = 3.0
	cue.volume_db = -13.0
	add_child(cue)
	initialized = true
	reset()

func reset() -> void:
	_cancel_event()
	cooldown = 16.0
	event_index = 0
	active_time = 0.0
	jump_cooldown = 0.0
	tension = 0.0
	journey_flags = game.flags
	previous_era = game.era
	previous_location = game.location
	drone.stop()
	drone.volume_db = -60.0
	overlay.visible = false

func _can_play() -> bool:
	return game.mode == "play" and not game.flags.arrived and not game.flags.finished and not game.world.on_platform

func _process(delta: float) -> void:
	if not initialized: return
	_restore_lighting()
	if not is_same(journey_flags, game.flags): reset()
	if previous_era != game.era or previous_location != game.location:
		_cancel_event()
		cooldown = maxf(cooldown, 12.0)
		previous_era = game.era
		previous_location = game.location
	if not _can_play():
		_cancel_event()
		cooldown = maxf(cooldown, 8.0)
		drone.stop()
		drone.volume_db = -60.0
		overlay.visible = false
		tension = 0.0
		return
	active_time += delta
	jump_cooldown = maxf(0.0, jump_cooldown - delta)
	overlay.visible = true
	# Give narrative broadcasts and subtitles priority over incidental scares.
	var narrative_busy: bool = game.hud.subtitle_time > 0.1 or game.spatial_audio.playing
	if narrative_busy and event_kind != "": _cancel_event()
	if event_kind != "":
		_tick_event(delta)
	elif not narrative_busy:
		cooldown = maxf(0.0, cooldown - delta)
		if cooldown <= 0.0 and not game.test_mode:
			if not trigger_event(EVENT_ORDER[event_index % EVENT_ORDER.size()]):
				trigger_event("steps")
			event_index += 1
	var base: float = [0.10, 0.23, 0.28][game.era] + float(game.flags.anomaly_level) * 0.035
	var pulse := sin(clampf(event_age / 7.0, 0.0, 1.0) * PI) * 0.32 if event_kind != "" else 0.0
	tension = move_toward(tension, base + pulse, delta * 0.28)
	overlay.material.set_shader_parameter("tension", tension)
	overlay.material.set_shader_parameter("breath", sin(active_time * 1.4))
	if not drone.playing: drone.play()
	var drone_target := -25.0 + tension * 9.0 - (9.0 if narrative_busy else 0.0)
	drone.volume_db = move_toward(drone.volume_db, drone_target, delta * 7.0)

func trigger_event(kind: String) -> bool:
	if not initialized or not _can_play() or kind not in EVENT_ORDER: return false
	if game.hud.subtitle_time > 0.1 or game.spatial_audio.playing: return false
	if kind == "jumpscare" and (jump_cooldown > 0.0 or not game.flags.photo): return false
	_cancel_event()
	event_kind = kind
	event_age = 0.0
	gaze_time = 0.0
	dissolve_age = -1.0
	jump_started = false
	cooldown = rng.randf_range(26.0, 42.0)
	if kind == "reflection" and not _place_apparition(): event_kind = "power"
	if event_kind == "jumpscare":
		jump_cooldown = 110.0
	elif event_kind == "steps":
		_play_cue("horror_steps", _behind_player(), -11.0)
	elif event_kind == "power":
		_play_cue("horror_creak", game.player.position + Vector3(0, 2.3, 0), -17.0)
	else:
		_play_cue("horror_creak", apparition.position, -21.0)
	return true

func _behind_player() -> Vector3:
	var behind: Vector3 = game.player.position + game.player.global_basis.z * 2.6
	if game.location == "carriage":
		behind.x = clampf(behind.x, -0.36, 0.36)
		behind.z = clampf(behind.z, -11.7, 2.1)
	else:
		var origin: Vector3 = game.spawn_for(game.location)
		behind.x = clampf(behind.x, origin.x - 1.7, origin.x + 1.7)
		behind.z = clampf(behind.z, -1.8, 1.8)
	behind.y = 0.24
	return behind

func _play_cue(sample: String, where: Vector3, db: float) -> void:
	cue.position = where
	cue.stream = load("res://assets/audio/" + sample + ".wav")
	cue.volume_db = db
	cue.pitch_scale = rng.randf_range(0.94, 1.03)
	cue.play()

func _place_apparition() -> bool:
	if game.location != "carriage": return false
	var camera: Camera3D = game.player.camera
	var best_score := INF
	var chosen := Vector3.ZERO
	for light: SpotLight3D in game.world.window_lights:
		var side := signf(light.position.x)
		# Keep the silhouette on one pane, clear of the sill and centre mullion.
		var spot := Vector3(side * 2.007, 1.72, light.position.z - 0.53)
		var offset := spot - camera.global_position
		var alignment := (-camera.global_basis.z).dot(offset.normalized())
		if offset.length() < 1.7 or offset.length() > 7.0 or alignment < 0.25 or alignment > 0.97: continue
		var score := absf(alignment - 0.78) + offset.length() * 0.025
		if score < best_score:
			best_score = score
			chosen = spot
	if is_inf(best_score): return false
	apparition.position = chosen
	apparition.rotation.y = -signf(chosen.x) * PI / 2
	apparition.material_override.set_shader_parameter("presence", 0.0)
	apparition.visible = true
	return true

func _tick_event(delta: float) -> void:
	event_age += delta
	if event_kind == "jumpscare":
		_dim_lights(exp(-pow((event_age - 0.65) / 0.28, 2.0)) * 0.9)
		if event_age >= 0.82 and event_age < 1.85:
			if not jump_started:
				jump_started = true
				sting.play()
			face.visible = true
			face.material.set_shader_parameter("age", event_age - 0.82)
		if event_age >= 1.85:
			_cancel_event()
			return
	elif event_kind == "power":
		# Two broad, smooth dips, with emergency/window illumination retained.
		var dip := exp(-pow((event_age - 1.65) / 0.85, 2.0))
		dip += 0.35 * exp(-pow((event_age - 3.8) / 0.6, 2.0))
		_dim_lights(dip)
	elif event_kind == "reflection":
		var camera: Camera3D = game.player.camera
		var alignment := (-camera.global_basis.z).dot((apparition.global_position - camera.global_position).normalized())
		if event_age > 0.7 and alignment > 0.975: gaze_time += delta
		if dissolve_age < 0.0 and (gaze_time > 0.23 or event_age > 5.8 or alignment < 0.05):
			dissolve_age = event_age
		var opacity := smoothstep(0.0, 0.9, event_age)
		if dissolve_age >= 0.0: opacity *= 1.0 - smoothstep(0.0, 0.55, event_age - dissolve_age)
		apparition.material_override.set_shader_parameter("presence", opacity)
		if dissolve_age >= 0.0 and event_age - dissolve_age > 0.55: apparition.visible = false
	if event_age >= 7.0: _cancel_event()

func _dim_lights(amount: float) -> void:
	var world: NightTrainWorld = game.world
	var lamps: Array = world.warm_lights + world.red_lights + world.window_lights + world.hidden_lights
	for light: Light3D in lamps:
		if not light.is_visible_in_tree(): continue
		var base := light.light_energy
		var strength := 0.30 if light is SpotLight3D or light in world.red_lights else 0.70
		var applied := base * (1.0 - amount * strength)
		light_overrides.append({"light": light, "base": base, "applied": applied})
		light.light_energy = applied
	lamp_original = world.materials.lamp.emission_energy_multiplier
	lamp_applied = lamp_original * (1.0 - amount * 0.80)
	world.materials.lamp.emission_energy_multiplier = lamp_applied

func _restore_lighting() -> void:
	# Restore only values we still own: era changes may have set new values.
	for entry in light_overrides:
		if is_instance_valid(entry.light) and is_equal_approx(entry.light.light_energy, entry.applied):
			entry.light.light_energy = entry.base
	light_overrides.clear()
	if lamp_applied >= 0.0 and is_instance_valid(game.world):
		if is_equal_approx(game.world.materials.lamp.emission_energy_multiplier, lamp_applied):
			game.world.materials.lamp.emission_energy_multiplier = lamp_original
	lamp_applied = -1.0

func _cancel_event() -> void:
	_restore_lighting()
	event_kind = ""
	event_age = 0.0
	if is_instance_valid(apparition): apparition.visible = false
	if is_instance_valid(cue): cue.stop()
	if is_instance_valid(face): face.visible = false
	if is_instance_valid(sting): sting.stop()

func _exit_tree() -> void:
	if not initialized: return
	_cancel_event()
	drone.stop()
	drone.stream = null
	cue.stream = null
	sting.stream = null
