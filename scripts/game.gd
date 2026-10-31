extends Node3D

const WORLD = preload("res://scripts/train_world.gd")
const PLAYER = preload("res://scripts/player.gd")
const HUD = preload("res://scripts/hud.gd")
const SAVE_PATH := "user://journey_v3.cfg"
const PREVIOUS_SAVE_PATH := "user://journey_v2.cfg"
const LEGACY_SAVE_PATH := "user://journey_v1.cfg"
const DEFAULT_FLAGS := {
	"photo": false, "key": false, "cabinet": false, "route": false, "postcard": false,
	"solved": false, "arrived": false, "finished": false,
	"anchors": 0, "anchor_1_bound": false, "anchor_2_bound": false, "anchor_3_bound": false,
	"anchor_1_era": 0, "anchor_2_era": 0, "anchor_3_era": 0,
	"anchor_1_state": "", "anchor_2_state": "", "anchor_3_state": "",
	"latch_open": false, "valve_vented": false, "pressure_valve": false,
	"maintenance_unlocked": false, "roof_unlocked": false, "memory_unlocked": false,
	"ticket_punch": false, "ticket_code": false, "badge": false, "relay": false,
	"relay_ready": false, "relay_assembled": false, "circuit_ready": false, "service_notes": false,
	"mark_0": false, "mark_1": false, "mark_2": false,
	"truth_1": false, "truth_2": false, "truth_3": false, "truth_fragments": 0,
	"foreign_ticket": false, "check_record": false, "conductor_met": false,
	"conductor_trust": false, "repair_signal": false, "ending_id": 0, "ending_pending": 0,
	"guide_seen": false, "investigating": false,
	"truth_anchor": false, "frequency": "", "anomaly_level": 0, "conductor_event": 0
}

var world: NightTrainWorld
var player: TrainPlayer
var hud: TrainHUD
var flags: Dictionary = DEFAULT_FLAGS.duplicate()
var era := 0
var loops := 7
var mode := "menu"
var volume := 0.72
var high_quality := true
var rail_audio: AudioStreamPlayer
var wind_audio: AudioStreamPlayer
var music_audio: AudioStreamPlayer
var effect_audio: AudioStreamPlayer
var step_audio: AudioStreamPlayer
var hint_timer := 0.0
var test_mode := false
var save_path := SAVE_PATH
var previous_save_path := PREVIOUS_SAVE_PATH
var legacy_save_path := LEGACY_SAVE_PATH
var location := "carriage"
var safe_era := 0
var safe_location := "carriage"
var safe_position := Vector3(0, 0.09, 1.4)
var event_clock := 0.0
var spatial_audio: AudioStreamPlayer3D

func _ready() -> void:
	_setup_input()
	world = WORLD.new()
	world.name = "NightTrain"
	add_child(world)
	player = PLAYER.new()
	player.name = "Passenger"
	add_child(player)
	player.place(Vector3(0.2, 0.09, 1.75), -0.035)
	player.camera.rotation.x = -0.015
	hud = HUD.new()
	hud.name = "Interface"
	add_child(hud)
	hud.ui_action.connect(_on_ui_action)
	_setup_audio()
	_load_settings()
	apply_quality()
	hud.show_menu(has_saved_journey())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.footstep.connect(_footstep)
	if OS.get_cmdline_user_args().has("--capture"):
		_capture_scenes.call_deferred()

func _setup_input() -> void:
	var bindings := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "walk_fast": KEY_SHIFT, "interact": KEY_E, "flashlight": KEY_F, "journal": KEY_TAB, "pause": KEY_ESCAPE, "fullscreen": KEY_F11, "help": KEY_H}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)

func _setup_audio() -> void:
	rail_audio = audio_player("rail", true)
	wind_audio = audio_player("wind", true)
	music_audio = audio_player("snow_lullaby", true)
	music_audio.name = "BackgroundMusic"
	music_audio.volume_db = -60.0
	spatial_audio = AudioStreamPlayer3D.new()
	spatial_audio.max_distance = 15.0
	spatial_audio.unit_size = 3.0
	add_child(spatial_audio)
	effect_audio = AudioStreamPlayer.new()
	add_child(effect_audio)
	step_audio = audio_player("step")
	step_audio.volume_db = -13
	rail_audio.volume_db = -13
	wind_audio.volume_db = -15
	rail_audio.play()
	wind_audio.play()
	music_audio.play()

func audio_player(file: String, looping: bool = false) -> AudioStreamPlayer:
	var audio := AudioStreamPlayer.new()
	var stream := load("res://assets/audio/" + file + ".wav") as AudioStreamWAV
	if looping:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	audio.stream = stream
	add_child(audio)
	return audio

func sound(name_key: String, db: float = -9.0) -> void:
	effect_audio.stream = load("res://assets/audio/" + name_key + ".wav")
	effect_audio.volume_db = db
	effect_audio.play()

func _footstep() -> void:
	step_audio.pitch_scale = randf_range(0.91, 1.07)
	step_audio.play()

func _exit_tree() -> void:
	for audio in [rail_audio, wind_audio, music_audio, effect_audio, step_audio, spatial_audio]:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
		return
	if mode == "transition":
		return
	if event.is_action_pressed("pause"):
		if mode == "play":
			pause_game()
		elif mode == "modal":
			close_modal()
		elif mode == "menu" and hud.modal.visible:
			hud.hide_modal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("help"):
		if mode == "play":
			open_help()
		elif mode == "modal" and hud.modal_kind == "help" and flags.guide_seen:
			close_modal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal"):
		if mode == "play":
			open_journal()
		elif mode == "modal" and hud.modal_kind == "journal":
			close_modal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("flashlight") and mode == "play":
		player.flashlight.visible = not player.flashlight.visible
		sound("touch", -16)
		hud.toast("手电筒已打开" if player.flashlight.visible else "手电筒已关闭", 1.8)
	elif event.is_action_pressed("interact"):
		if mode == "play":
			var target := player.target()
			if target:
				interact(target.interaction_id)
		elif mode == "modal" and hud.modal_kind == "note":
			close_modal()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_instance_valid(hud):
		return
	if mode == "play":
		if player.position.y < -3.0:
			player.place(safe_position)
		hud.set_target(player.target())
		hint_timer += delta
		event_clock += delta
		_maybe_trigger_conductor_event()
		var goal := current_goal()
		if world.hotspots.has(goal.target):
			hud.set_navigation(player.camera, world.hotspots[goal.target].global_position, world.hotspots[goal.target].title)
		if hint_timer > 75 and not flags.finished:
			hint_timer = 0
			hud.toast("H 查看当前步骤的提示 · Tab 回看已找到的线索", 6)
	else:
		hud.set_target(null)
		hud.navigation.visible = false
	var quiet: bool = flags.arrived or flags.finished
	var rail_target: float = -65.0 if quiet else [-13.0, -20.0, -65.0][era]
	rail_audio.volume_db = lerpf(rail_audio.volume_db, rail_target, delta * 1.7)
	wind_audio.volume_db = lerpf(wind_audio.volume_db, -9.0 if era == 2 or quiet else -20.0, delta)
	# Keep the lullaby continuous across eras, menus and clues, with gentle fades.
	var music_target: float = [-13.0, -16.0, -14.0][era]
	if quiet or location == "memory":
		music_target = -12.0
	if mode == "menu":
		music_target = -12.0
	elif mode == "modal":
		music_target -= 2.0
	elif mode == "transition":
		music_target -= 3.0
	music_audio.volume_db = lerpf(music_audio.volume_db, music_target, 1.0 - exp(-delta * 0.8))

func start_journey(continue_saved: bool) -> void:
	flags = DEFAULT_FLAGS.duplicate()
	era = 0
	loops = 7
	location = "carriage"
	event_clock = 0.0
	hint_timer = 0.0
	hud.subtitle_time = 0
	hud.toast_time = 0
	if continue_saved:
		_load_journey()
	world.on_platform = false
	world.platform.visible = false
	world.car.visible = true
	world.car.scale = Vector3.ONE
	world.platform.scale = Vector3.ONE
	world.set_location(location, flags)
	world.set_era(era, flags)
	player.place(spawn_for(location))
	player.flashlight.visible = era != 0
	hud.enter_game()
	hud.blackout.color.a = 0.0
	mode = "play"
	player.enabled = true
	_capture_mouse()
	if flags.arrived:
		world.reveal_platform()
		player.place(Vector3(80, 0.09, 1.5))
	update_safe_checkpoint()
	_refresh_status()
	_save_journey()
	if flags.finished:
		_open_modal()
		hud.show_ending_variant(flags.ending_id)
	elif not flags.guide_seen:
		open_help(true)
	else:
		hud.toast("旅程已恢复。跟随金色菱形探索；H 可查看玩法。", 6)

func _on_ui_action(action: String, value: String) -> void:
	if action != "volume":
		sound("touch", -16)
	match action:
		"start": start_journey(has_saved_journey())
		"new": start_journey(false)
		"confirm_restart": hud.show_restart_confirm()
		"cancel_restart": hud.hide_modal()
		"close": close_modal()
		"journal": open_journal()
		"station": choose_station(value)
		"help": open_help()
		"guide_start":
			flags.guide_seen = true
			close_modal()
			_save_journey()
		"era": select_era(value.to_int())
		"repair_device": repair_device(value.to_int())
		"install_radio": install_radio()
		"investigate":
			flags.ending_pending = 0
			flags.investigating = true
			close_modal()
			_refresh_status()
			_save_journey()
		"terminal": open_ending_choice()
		"trust":
			flags.conductor_trust = value == "yes"
			close_modal()
			_save_journey()
		"ticket_check":
			close_modal()
			if flags.ticket_code:
				flags.anomaly_level = maxi(0, int(flags.anomaly_level) - 1)
				world.set_anomaly_level(flags.anomaly_level)
				hud.speak("乘务员：打孔有效。请保管好你的名字。", 6)
			else:
				increase_anomaly(1, "空白车票没有通过检查。")
		"ending_leave": choose_ending(1)
		"ending_takeover": choose_ending(2)
		"ending_expose": choose_ending(3)
		"menu": return_to_menu()
		"quality":
			high_quality = not high_quality
			apply_quality()
			_save_settings()
			hud.show_pause(volume, high_quality)
		"volume":
			volume = clampf(value.to_float(), 0, 1)
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
			AudioServer.set_bus_mute(0, volume <= 0.001)
			_save_settings()

func interact(id: String) -> void:
	if mode != "play" or flags.finished or not world.hotspots.has(id) or not world.hotspots[id].active:
		return
	sound("touch", -14)
	hint_timer = 0.0
	match id:
		"door_front", "door_back", "service_clock", "roof_clock", "memory_clock":
			open_era_selector(id)
		"photo":
			flags.photo = true
			flags.mark_0 = true
			_recount_anchors()
			note("第七次经过", "照片里，左侧木墙后藏着一道维修门。07 号座椅旁的黄铜连杆控制着它。\n\n[color=#d7bd8c]下一步：在「出发之夜」操作座椅旁的连杆，打开维修门。[/color]\n\n修好的机关会一直保持有效。走到车厢任一端的门前，可以自行选择年代。\n\n照片背面的座位标记：△ 07。")
		"anchor_1", "anchor_2", "anchor_3":
			show_device(int(id.trim_prefix("anchor_")))
		"key":
			flags.key = true
			note("广播控制 · 07", "腐朽木板后落下一把黄铜钥匙。上面刻着“广播控制”。\n\n[color=#d7bd8c]它能打开车厢前端右侧的广播柜。使用时会自动取出。[/color]")
		"maintenance_entry": enter_location("maintenance")
		"maintenance_exit", "memory_exit": enter_location("carriage")
		"memory_entry": enter_location("memory")
		"roof_hatch": enter_location("roof")
		"roof_exit": enter_location("maintenance")
		"pressure_valve": show_device(2)
		"ticket_punch":
			flags.ticket_punch = true
			flags.ticket_code = true
			note("失踪乘务员的检票钳", "钳身刻着 07 席。你按照座位号在车票上补了一枚孔。\n\n[color=#d7bd8c]已获得：打孔车票。[/color]\n\n检票时会自动出示。检票钳和车票已一起收进手记。")
		"service_notes":
			flags.service_notes = true
			note("维修员留下的便笺", "[color=#d7bd8c]修复广播需要三件东西：黄铜钥匙、车顶继电器、乘务员徽章。[/color]\n\n1. 在「停电时刻」转动维修夹层里的红色泄压阀。\n2. 切换到「多年以后」，经前方检修口进入车顶，取走继电器。\n3. 黄铜钥匙藏在多年以后的主车厢左墙上方；徽章在「停电时刻」的 08 席门后。\n\n带齐物品后，到出发之夜的广播柜安装即可。房间里的检修钟也能选择年代。")
		"wall_marks":
			if era == 1:
				flags.mark_1 = true
				note("停电后显现的墙记", "应急灯照出被油漆掩盖的一行字：\n\n[color=#d7bd8c]○ 1[/color]\n\n旁边写着：“不是事故前，也不是事故后。只有这一刻，圆环还没有合上。”")
			else:
				note("旧漆下的痕迹", "一层油漆盖住了符号。维修说明提到，应急灯的斜光能照出它。", false)
		"roof_marks":
			if era == 2:
				flags.mark_2 = true
				note("锈蚀之后的刻痕", "多年腐蚀剥去了金属表层。\n\n[color=#d7bd8c]× 7[/color]\n\n背面的小字属于另一种笔迹：“把三个符号接起来；广播只认事故之前的声音。”")
			else:
				note("覆盖着防锈漆的铭牌", "表层仍然完整。也许很多年之后，下面的字才会显露。", false)
		"relay":
			flags.relay = true
			flags.memory_unlocked = true
			note("车顶继电器", "这是广播缺失的继电器。底部贴着一张纸条：\n\n[color=#d7bd8c]“带回广播柜安装。还需要一把黄铜钥匙和一枚乘务员徽章。徽章在停电时刻的 08 席门后。”[/color]\n\n你听见主车厢 08 席旁传来一次开锁声。返回主车厢后，选「停电时刻」寻找那扇门。")
		"badge":
			flags.badge = true
			note("遗失的乘务员徽章", "正面：乘务员 林照。背面：1987.12.07。\n\n[color=#d7bd8c]“请把下一位乘客送到终点。”[/color]\n\n出发记录说他是乘务员；停电记录称他为 07 号乘客；未来的失踪名单却查无此人。徽章上的铜触点仍与广播柜匹配。")
		"truth_log_1":
			record_truth_fragment(1)
			note("事故记录一 · 未发出的警报", "1987.12.07，23:17。北岭隧道出口雪崩。列车警报被人工切断。\n\n[color=#d7bd8c]07 号车厢无人下车。最后一次无线呼叫：“不要再报白桦。”[/color]\n\n背面盖着“乘务员林照”的章，出发之夜的值班表却没有他的名字。")
		"truth_log_2":
			record_truth_fragment(2)
			note("事故记录二 · 接替者", "车顶黑匣子的最后七秒里，没有列车运行声。\n\n林照反复报出同一个站名，声音逐渐变成另一名乘客。\n\n[color=#d7bd8c]所谓检票，是在为下一次循环寻找会相信广播的人。记录中每次“接替”，都多了一位失踪乘客。[/color]")
		"truth_log_3":
			record_truth_fragment(3)
			note("事故记录三 · 不存在的终点", "铁路档案：整列车于七天前失踪。白桦站早在事故前已经撤销。\n\n[color=#d7bd8c]修好广播只会修复循环。三份完整记录能定位事故发生的时刻。回到广播柜，选择“公开事故记录”，让所有人离开。[/color]\n\n档案最后一行是你的座位号。")
		"foreign_ticket":
			flags.foreign_ticket = true
			note("一张不属于你的车票", "07 席 · 林照 · 目的地：接替。\n\n你的车票背面多了一个孔，而这张票上正好少了一个。出发之夜他是乘务员，停电之后他成了最后一名乘客。")
		"check_record":
			flags.check_record = true
			note("07 席检查记录", "第一次：乘客未醒。\n第三次：乘客听见广播。\n第七次：[color=#d7bd8c]身份可以转交。[/color]\n\n页脚写着：广播会说谎，已经记下的符号不会。")
		"conductor":
			flags.conductor_met = true
			_open_modal()
			hud.show_conductor(flags.ticket_code, flags.conductor_trust)
		"route":
			flags.route = true
			note("北境铁路 · 冬季线路", "[color=#d7bd8c]雾港 → 北岭 → 白桦[/color]\n\n广播录音从“北岭站已过”开始。最后一站被墨水划去，又用铅笔写回。线路图用箭头标出先后顺序。\n\n广播停在“北岭站已过”。应该填写北岭之后的站名。")
		"postcard":
			flags.postcard = true
			note("致最后一位乘客", "“越过北岭，再坐一站。\n\n[color=#d7bd8c]请在那片白色树干的地方下车。[/color]\n\n我会拿着牌子，在灯光底下等你。无论多晚。”\n\n邮戳的日期是今天，收件人却是失踪乘务员。")
		"radio": open_radio()
		"ending":
			if flags.arrived:
				complete_ending(1)
	_sync_world()
	_refresh_status()
	_save_journey()

func _sync_world() -> void:
	world.set_location(location, flags)
	world.set_era(era, flags)

func spawn_for(place: String) -> Vector3:
	match place:
		"maintenance": return world.maintenance.position + Vector3(0, 0.09, 1.9)
		"roof": return world.roof_space.position + Vector3(0, 0.09, 1.15)
		"memory": return world.memory_space.position + Vector3(0, 0.09, 1.6)
	return Vector3(0, 0.09, 1.4)

func location_name() -> String:
	return {"carriage": "主车厢", "maintenance": "维修夹层", "roof": "车顶检修舱", "memory": "记忆空间"}.get(location, "主车厢")

func enter_location(next: String) -> void:
	if mode != "play" or next == location:
		return
	var allowed := next == "carriage" or (next == "maintenance" and location == "roof")
	allowed = allowed or (next == "maintenance" and location == "carriage" and era in [1, 2] and _anchor_holds(1, "开启"))
	allowed = allowed or (next == "roof" and location == "maintenance" and era == 2 and _anchor_holds(2, "泄压"))
	allowed = allowed or (next == "memory" and location == "carriage" and era == 1 and flags.memory_unlocked)
	if not allowed:
		hud.toast(current_goal().tip, 7)
		return
	var previous := location
	location = next
	if next == "maintenance": flags.maintenance_unlocked = true
	if next == "roof": flags.roof_unlocked = true
	player.place(spawn_for(location))
	if next == "carriage":
		player.place(Vector3(0, 0.09, -8.0 if previous == "memory" else -4.2))
	_sync_world()
	update_safe_checkpoint()
	_refresh_status()
	_save_journey()
	hud.speak({"maintenance": "车厢外还有一层车厢。铁轨声从墙里传来。", "roof": "所有雪花都停在玻璃外，仿佛在等一场事故。", "memory": "这里挂着所有曾经坐过 07 席的人的车票。", "carriage": "广播还在呼叫最后一位乘客。"}[location], 6)

func _anchor_holds(id: int, state: String) -> bool:
	return flags.get("anchor_%d_bound" % id, false) and flags.get("anchor_%d_state" % id, "") == state

func _recount_anchors() -> void:
	flags.anchors = 3 if flags.photo else 0
	for id in range(1, 4):
		if flags.get("anchor_%d_bound" % id, false): flags.anchors -= 1
	flags.anchors = clampi(int(flags.anchors), 0, 3)

# Repairs are permanent contextual actions. The old anchor fields remain only
# as the world-state representation and for migration of existing saves.
func show_device(id: int) -> void:
	if id == 3:
		open_radio()
		return
	_open_modal()
	hud.show_device(id, era, flags)

func repair_device(id: int) -> void:
	if mode != "modal" or hud.modal_kind != "device" or id not in [1, 2]: return
	if hud.device_id != id or not flags.photo: return
	if (id == 1 and era != 0) or (id == 2 and era != 1): return
	if flags["anchor_%d_bound" % id]: return
	flags["anchor_%d_bound" % id] = true
	flags["anchor_%d_era" % id] = era
	flags["anchor_%d_state" % id] = "开启" if id == 1 else "泄压"
	flags.latch_open = flags.anchor_1_bound
	flags.valve_vented = flags.anchor_2_bound
	flags.pressure_valve = flags.anchor_2_bound
	_recount_anchors()
	close_modal()
	_sync_world()
	update_safe_checkpoint()
	_refresh_status()
	_save_journey()
	hud.toast("维修门已打开。到车厢端门，选择「停电时刻」进入左墙夹层。" if id == 1 else "已泄压。用身后的检修钟选择「多年以后」，再进入前方车顶检修口。", 8)

func open_radio() -> void:
	if flags.repair_signal:
		open_ending_choice()
		return
	_open_modal()
	if not flags.circuit_ready:
		hud.show_radio_repair(era, flags)
	elif era != 0:
		hud.show_note("广播需要电源", "请到车厢端门选择「出发之夜」，再回到这里。")
	else:
		hud.show_radio(flags.truth_fragments >= 3, flags.route, flags.postcard)

func install_radio() -> void:
	if mode != "modal" or hud.modal_kind != "radio_repair" or era != 0: return
	if not flags.key or not flags.relay or not flags.badge: return
	flags.cabinet = true
	flags.relay_ready = true
	flags.relay_assembled = true
	flags.circuit_ready = true
	flags.frequency = "71.7"
	flags.anchor_3_bound = true
	flags.anchor_3_era = 0
	flags.anchor_3_state = "71.7"
	_recount_anchors()
	_sync_world()
	_refresh_status()
	_save_journey()
	hud.show_radio(flags.truth_fragments >= 3, flags.route, flags.postcard)

func choose_station(station: String) -> void:
	if mode != "modal" or hud.modal_kind != "radio" or era != 0 or not flags.circuit_ready or not _anchor_holds(3, "71.7"): return
	if station != "白桦":
		hud.show_station_retry(station, flags.route, flags.postcard)
		return
	close_modal()
	flags.solved = true
	flags.repair_signal = true
	_sync_world()
	update_safe_checkpoint()
	hud.speak("广播：下一站，白桦。请最后一位乘客准备下车。", 8)
	open_ending_choice()
	_refresh_status()
	_save_journey()

func open_ending_choice() -> void:
	if not flags.repair_signal and not (flags.circuit_ready and flags.truth_fragments == 3 and _anchor_holds(3, "71.7")): return
	_open_modal()
	hud.show_ending_choice(flags.truth_fragments, flags.conductor_trust, flags.repair_signal, flags.badge)

func choose_ending(id: int) -> void:
	if mode != "modal" or hud.modal_kind != "ending_choice" or id < 1 or id > 3: return
	if id == 1 and not flags.repair_signal: return
	if id == 2 and not flags.badge: return
	if id == 3 and (flags.truth_fragments != 3 or not flags.circuit_ready): return
	close_modal()
	if id == 3:
		# The third anchor is deliberately transferred from the repaired broadcast
		# to the moment before the accident; the other two stay on their objects.
		flags.anchor_3_bound = true
		flags.anchor_3_era = 0
		flags.anchor_3_state = "事故前一瞬"
		flags.truth_anchor = true
		flags.repair_signal = false
		_recount_anchors()
		complete_ending(3)
		return
	flags.investigating = false
	flags.ending_pending = id
	if id == 2: flags.conductor_trust = true
	_sync_world()
	hud.toast("走向任一端车门。你的选择将在离开时生效。", 7)
	_refresh_status()
	_save_journey()

func complete_ending(id: int) -> void:
	if mode == "transition": return
	mode = "transition"
	player.enabled = false
	hud.hide_modal()
	hud.set_target(null)
	flags.ending_id = id
	flags.ending_pending = 0
	flags.finished = true
	flags.arrived = id == 1
	if id == 1:
		world.hotspots.ending.active = false
		var figure := world.platform.get_node_or_null("WaitingPassenger")
		if figure:
			var disappear := create_tween()
			disappear.tween_property(figure, "scale", Vector3.ONE * 0.001, 1.8 if not test_mode else 0.001)
	if id == 3:
		hud.speak("广播停止了。所有曾经等待的身影，在雪里同时转过身。", 7)
		var dissolve := create_tween()
		dissolve.tween_property(world.car, "scale", Vector3.ONE * 0.01, 2.8 if not test_mode else 0.001)
	await hud.fade(1.0, 2.5 if not test_mode else 0.001).finished
	if id == 2:
		hud.speak("下一站，即将到达终点。请最后一位乘客准备查票。", 9)
	_sync_world()
	_refresh_status()
	_save_journey()
	_open_modal()
	hud.show_ending_variant(id)
	await hud.fade(0.0, 0.8 if not test_mode else 0.001).finished

func increase_anomaly(amount: int, reason: String = "") -> void:
	# Atmosphere only: exploration and wrong answers never erase progress.
	if flags.finished: return
	flags.anomaly_level = clampi(int(flags.anomaly_level) + amount, 0, 3)
	if reason != "": hud.toast(reason, 6)
	_sync_world()
	_refresh_status()
	_save_journey()

func update_safe_checkpoint() -> void:
	safe_era = era
	safe_location = location
	safe_position = player.position

func record_truth_fragment(id: int) -> void:
	flags["truth_%d" % id] = true
	flags.truth_fragments = int(flags.truth_1) + int(flags.truth_2) + int(flags.truth_3)

func _play_conductor_sound(sample: String, where: Vector3) -> void:
	spatial_audio.position = where
	spatial_audio.stream = load("res://assets/audio/" + sample + ".wav")
	spatial_audio.volume_db = -8
	spatial_audio.pitch_scale = 0.7 if sample == "chime" else 0.84
	spatial_audio.play()

func _maybe_trigger_conductor_event() -> void:
	if flags.arrived or flags.finished or not flags.photo: return
	var next := int(flags.conductor_event) + 1
	var gates := [true, flags.maintenance_unlocked, flags.relay, flags.badge, flags.circuit_ready]
	var delays := [12.0, 45.0, 50.0, 50.0, 35.0]
	if next <= 5 and gates[next - 1] and event_clock >= delays[next - 1]: handle_conductor_event(next)

func handle_conductor_event(index: int) -> void:
	if index != int(flags.conductor_event) + 1 or index > 5: return
	flags.conductor_event = index
	event_clock = 0.0
	match index:
		1:
			hud.speak("广播：所有乘客请留在座位上。07 号，林照先生，请不要回头。", 9)
			_play_conductor_sound("chime", Vector3(0, 2, -12))
		2:
			hud.speak("07 席桌上多出一张车票。你不记得自己买过第二张。", 7)
			increase_anomaly(1)
		3:
			hud.speak("07 席检查记录：身份可以转交。请准备最后一次查票。", 7)
			_play_conductor_sound("touch", Vector3(0, 1.5, -10))
		4:
			hud.speak("车门外：查票。\n脚步却从你的身后响起。", 8)
			_play_conductor_sound("step", player.position + Vector3(0, 0, 2.5))
			increase_anomaly(1)
		5:
			hud.speak("乘务员：把徽章放回广播柜，替我送走最后一位乘客。", 9)
			_play_conductor_sound("chime", Vector3(0, 1.5, -11.5))
	_sync_world()
	_refresh_status()
	_save_journey()

func era_control() -> String:
	if location == "carriage":
		return "door_front" if player.position.z < -5 else "door_back"
	return {"maintenance": "service_clock", "roof": "roof_clock", "memory": "memory_clock"}.get(location, "door_front")

func open_era_selector(source: String) -> void:
	if flags.ending_pending > 0 and location == "carriage":
		change_era(source != "door_back")
		return
	_open_modal()
	hud.show_eras(era, current_goal().text)

func select_era(destination: int) -> void:
	if mode != "modal" or hud.modal_kind != "eras" or destination not in [0, 1, 2]: return
	if destination == era: return
	close_modal()
	change_era(true, destination)

func change_era(front: bool = true, destination: int = -1) -> void:
	if mode != "play" or flags.finished or flags.arrived: return
	mode = "transition"
	player.enabled = false
	hud.set_target(null)
	await hud.fade(1.0, 0.55 if not test_mode else 0.001).finished
	if flags.ending_pending == 2 and location == "carriage":
		mode = "play"
		complete_ending(2)
		return
	if flags.ending_pending == 1 and location == "carriage":
		flags.arrived = true
		location = "carriage"
		world.reveal_platform()
		player.place(Vector3(80, 0.09, 1.5))
		player.flashlight.visible = false
	else:
		era = destination if destination in [0, 1, 2] else era
		loops += 1
		_sync_world()
		player.velocity = Vector3.ZERO
		player.flashlight.visible = era != 0
	_refresh_status()
	update_safe_checkpoint()
	_save_journey()
	await hud.fade(0.0, 0.85 if not test_mode else 0.001).finished
	mode = "play"
	player.enabled = true
	_capture_mouse()
	hud.speak("没有铁轨声了。站牌下还有一个人。" if flags.arrived else ["灯又亮了。这里还没有发生事故。", "灯灭了。只有应急灯照见墙上的字。", "木板已经腐朽。现在能找到当年藏起来的东西。"][era], 7)

func _open_modal() -> void:
	mode = "modal"
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func note(title: String, text: String, collected: bool = true) -> void:
	_open_modal()
	hud.show_note(title, text, "旅 途 拾 遗  /  已记入手记" if collected else "07 号 车 厢  /  观察")

func close_modal() -> void:
	hud.hide_modal()
	mode = "play"
	player.enabled = true
	_capture_mouse()

func _capture_mouse() -> void:
	player.look_warmup_frames = 3
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if test_mode else Input.MOUSE_MODE_CAPTURED

func pause_game() -> void:
	_open_modal()
	hud.show_pause(volume, high_quality)

func open_help(introduction: bool = false) -> void:
	_open_modal()
	hud.show_help(current_goal(), introduction)

func open_journal() -> void:
	_open_modal()
	var goal := current_goal()
	var text: String = "[color=#d7bd8c]现在要做[/color]\n" + goal.text + "\n\n" + goal.tip + "\n\n"
	text += "[color=#d7bd8c]广播修复清单[/color]\n"
	for entry in [["key", "黄铜钥匙"], ["relay", "车顶继电器"], ["badge", "乘务员徽章"]]:
		text += ("[已找到] " if flags[entry[0]] else "[未找到] ") + entry[1] + "\n"
	text += "\n[color=#d7bd8c]探索记录[/color]\n"
	var entries := {
		"photo": "07 席照片：左墙后藏有维修门；出发之夜可以拨动座椅旁连杆。",
		"anchor_1_bound": "维修门已打开，停电时刻和多年以后都能进入。",
		"service_notes": "维修便笺：停电时转动泄压阀；多年以后去车顶找继电器；修复需要钥匙、继电器、徽章。",
		"anchor_2_bound": "泄压阀已转动，多年以后的车顶检修口可以通过。",
		"ticket_punch": "检票钳：车票已打孔，检查时自动出示。",
		"mark_0": "照片符号：△07。", "mark_1": "停电墙记：○1。", "mark_2": "腐蚀铭牌：×7。",
		"key": "黄铜钥匙：打开广播柜。", "relay": "车顶继电器：08 席门已解锁，停电时可进入。",
		"badge": "乘务员徽章：林照的身份，在三个年代的记录中互相矛盾。",
		"route": "冬季线路：雾港 → 北岭 → 白桦。广播已过北岭。",
		"postcard": "明信片：过了北岭再坐一站，在白色树干的地方下车。",
		"truth_1": "事故记录一：23:17，北岭出口雪崩；列车警报被人工切断。",
		"truth_2": "事故记录二：检票是在寻找接替者，每次循环都会多一位失踪乘客。",
		"truth_3": "事故记录三：整列车已经失踪。公开三份记录，才能让所有人离开。",
		"foreign_ticket": "陌生车票：07 席，林照；目的地为“接替”。",
		"check_record": "检查记录：第七次，身份可以转交。",
		"conductor_met": "失踪乘务员要求你把徽章放回广播柜，替他完成查票。",
		"circuit_ready": "广播零件已安装，已自动调谐到维修频率 71.7。",
		"repair_signal": "广播恢复：下一站，白桦。返回广播柜可选择结局或继续找事故记录。"
	}
	for key: String in entries:
		if flags[key]: text += "• " + entries[key] + "\n\n"
	text += "[color=#809893]事故记录 %d / 3 · 道具到对应机关会自动使用。\n按 H 可随时查看玩法与当前步骤。[/color]" % flags.truth_fragments
	hud.show_journal(text)

func _goal(text: String, target: String, stage: String, tip: String) -> Dictionary:
	return {"text": text, "target": target, "stage": stage, "tip": tip}

func _toward(place: String, when: int, target: String, text: String, stage: String, tip: String) -> Dictionary:
	if location == place:
		if era != when: return _era_goal(when, stage)
		return _goal(text, target, stage, tip)
	if location == "roof": return _goal("从身后的检修梯返回维修夹层", "roof_exit", stage, tip)
	if location == "memory": return _goal("从身后的门返回主车厢", "memory_exit", stage, tip)
	if location == "maintenance":
		if place == "roof":
			if era != 2: return _era_goal(2, stage)
			return _goal("进入前方打开的车顶检修口", "roof_hatch", stage, tip)
		return _goal("从身后的门返回主车厢", "maintenance_exit", stage, tip)
	if place == "memory":
		if era != 1: return _era_goal(1, stage)
		return _goal("进入右侧 08 席后的记忆空间", "memory_entry", stage, tip)
	if place in ["maintenance", "roof"]:
		if era != when: return _era_goal(when, stage)
		return _goal("进入左墙的维修夹层", "maintenance_entry", stage, tip)
	return _goal(text, target, stage, tip)

func _era_goal(when: int, stage: String) -> Dictionary:
	var name_text: String = ["出发之夜", "停电时刻", "多年以后"][when]
	var control := "车厢端门" if location == "carriage" else "身后的检修钟"
	return _goal("到%s，选择「%s」" % [control, name_text], era_control(), stage, "靠近%s按 E，然后点击「%s」。选择年代后，你仍留在原来的位置。" % [control, name_text])

func current_goal() -> Dictionary:
	if flags.finished: return _goal("第一章完成", "", "旅程结束", "可以返回标题，重新体验其他选择。")
	if flags.arrived: return _goal("走近站牌下等待的人，按 E", "ending", "第四幕 · 抵达", "沿站台向前走，和站牌下的人互动，完成旅程。")
	if flags.ending_pending > 0: return _toward("carriage", era, era_control(), "到任一端车门，按 E 离开", "第四幕 · 最后选择", "你已经作出选择。穿过车门后，故事将继续。")
	if flags.investigating:
		for record in [[1, "maintenance", "维修夹层的事故记录"], [2, "roof", "车顶黑匣子旁的事故记录"], [3, "memory", "记忆空间的铁路档案"]]:
			if not flags["truth_%d" % record[0]]:
				return _toward(record[1], 2, "truth_log_%d" % record[0], "阅读" + record[2], "可选调查 · 事故记录 %d/3" % flags.truth_fragments, "三份记录都只在「多年以后」留下痕迹。记忆空间需要先在停电时刻进入，再用里面的钟选择多年以后。")
		return _toward("carriage", 0, "radio", "回到广播柜，公开完整事故记录", "可选调查 · 3/3", "三份记录已齐。广播柜里的第三个选择已经解锁。")
	if flags.repair_signal: return _toward("carriage", 0, "radio", "回到广播柜，选择结局或继续调查", "第四幕 · 最后选择", "广播已恢复。可以离开、接班，或继续寻找事故记录；三个选项都在广播柜。")
	if not flags.photo: return _toward("carriage", era, "photo", "沿走道找到左侧 07 席，查看旧照片", "第一幕 · 失踪的门", "中央走道前方左侧的桌上有一张照片。对准它，按 E 阅读；再按 E 收起。")
	if not flags.anchor_1_bound: return _toward("carriage", 0, "anchor_1", "操作 07 席旁的黄铜连杆，打开维修门", "第一幕 · 失踪的门", "在照片旁找到黄铜连杆，按 E，再点击「拨动连杆，打开维修门」。打开后会一直有效。")
	if not flags.service_notes and not flags.anchor_2_bound: return _toward("maintenance", 1, "service_notes", "阅读桌上的维修便笺", "第二幕 · 车顶的零件", "先读便笺，了解要找的三件零件。左侧红色轮盘是泄压阀。")
	if not flags.anchor_2_bound: return _toward("maintenance", 1, "pressure_valve", "转动左侧红色泄压阀", "第二幕 · 车顶的零件", "对准红色轮盘按 E，再点击「转动阀门，为检修口泄压」。之后用身后的钟选择多年以后。")
	if not flags.relay: return _toward("roof", 2, "relay", "拿走桌上的车顶继电器", "第二幕 · 车顶的零件", "检修口在维修夹层的正前方。必须先泄压，再在多年以后进入。")
	if not flags.key: return _toward("carriage", 2, "key", "抬头拿取维修入口上方的黄铜钥匙", "第三幕 · 乘务员的身份", "钥匙在主车厢左墙，维修入口上方的腐朽横梁里。站在走道上抬头按 E。")
	if not flags.badge: return _toward("memory", 1, "badge", "拿走桌上的乘务员徽章", "第三幕 · 乘务员的身份", "拿到继电器后，主车厢右侧 08 席后的门会在停电时刻出现。")
	if not flags.circuit_ready: return _toward("carriage", 0, "radio", "在前端右侧广播柜安装三件零件", "第四幕 · 遗失的站名", "钥匙、继电器、徽章已经齐全。按 E 打开广播柜，点击安装，物品会自动使用。")
	if not flags.route and not flags.postcard: return _toward("carriage", 0, "route", "查看广播柜对面的旧线路图", "第四幕 · 遗失的站名", "录音说「北岭站已过」。线路图的箭头指出下一站；右侧桌上的明信片也有提示。")
	return _toward("carriage", 0, "radio", "回到广播柜，选择终点站或结局", "第四幕 · 最后选择", "按线路图补全站名。广播恢复后，可离开、接班，或选择继续寻找三份事故记录。")

func _refresh_status() -> void:
	var goal := current_goal()
	var items := "车票"
	for entry in [["key", "黄铜钥匙"], ["relay", "继电器"], ["badge", "徽章"], ["ticket_punch", "检票钳"]]:
		if flags[entry[0]]: items += " · " + entry[1]
	hud.status(era, loops, goal.text, items, flags.arrived, flags.truth_fragments, flags.circuit_ready, location_name(), goal.stage)

func has_saved_journey() -> bool:
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(previous_save_path) or FileAccess.file_exists(legacy_save_path)

func return_to_menu() -> void:
	_save_journey()
	mode = "menu"
	player.enabled = false
	player.flashlight.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world.car.visible = true
	world.platform.visible = false
	world.on_platform = false
	world.set_era(0, flags)
	player.place(Vector3(0.2, 0.09, 1.75), -0.035)
	hud.show_menu(true)

func _save_journey() -> void:
	if test_mode:
		return
	var config := ConfigFile.new()
	config.set_value("journey", "version", 3)
	config.set_value("journey", "gameplay", "guided_story")
	config.set_value("journey", "era", era)
	config.set_value("journey", "loops", loops)
	config.set_value("journey", "location", location)
	config.set_value("journey", "event_clock", event_clock)
	config.set_value("journey", "flags", flags)
	var error := config.save(save_path)
	if error != OK:
		hud.toast("暂时无法保存旅程；本次游玩可以继续。", 5)
		push_warning("Save failed: %s" % error)

func _load_journey() -> void:
	var config := ConfigFile.new()
	var loaded_path := save_path
	var load_error := config.load(loaded_path)
	if load_error != OK:
		loaded_path = previous_save_path
		load_error = config.load(loaded_path)
	var legacy := false
	if load_error != OK:
		loaded_path = legacy_save_path
		load_error = config.load(loaded_path)
		legacy = load_error == OK
	if load_error != OK:
		return
	era = clampi(int(config.get_value("journey", "era", 0)), 0, 2)
	loops = clampi(int(config.get_value("journey", "loops", 7)), 7, 9999)
	event_clock = maxf(0.0, float(config.get_value("journey", "event_clock", 0.0)))
	var loaded: Variant = config.get_value("journey", "flags", {})
	if loaded is Dictionary:
		for key: String in DEFAULT_FLAGS:
			if loaded.has(key):
				flags[key] = loaded[key]
	# v1 had no temporal state. A completed old radio puzzle remains a valid
	# first ending and can still be explored from the platform.
	if legacy or int(config.get_value("journey", "version", 1)) < 2:
		if flags.get("solved", false):
			flags.repair_signal = true
			flags.ending_id = 1
			flags.finished = flags.get("finished", false)
		if flags.get("photo", false) and int(flags.anchors) == 0:
			flags.anchors = 3
	if flags.get("truth_fragments", 0) is bool:
		flags.truth_fragments = int(flags.truth_1) + int(flags.truth_2) + int(flags.truth_3)
	flags.anchors = clampi(int(flags.anchors), 0, 3)
	flags.truth_fragments = clampi(int(flags.truth_fragments), 0, 3)
	flags.anomaly_level = clampi(int(flags.anomaly_level), 0, 4)
	# Repair partial or older checkpoints rather than creating an unwinnable state.
	if flags.finished and int(flags.ending_id) == 1:
		flags.arrived = true
	if flags.arrived:
		flags.solved = true
	if flags.solved:
		flags.cabinet = true
	if flags.cabinet:
		flags.key = true
	location = "carriage"
	event_clock = 0.0
	# v1 saves never had the chapter expansion state; preserve the old route and
	# start the new investigation with a fresh set of anchors.
	if legacy:
		flags.maintenance_unlocked = flags.get("photo", false)
		flags.memory_unlocked = false
		flags.roof_unlocked = false
		flags.pressure_valve = false
		flags.relay = false
		flags.relay_assembled = false
		flags.anchor_1_bound = false
		flags.anchor_2_bound = false
		flags.anchor_3_bound = false
		flags.anchors = 3 if flags.get("photo", false) else 0
	# Convert old manual anchor / combination progress to permanent repairs.
	if flags.circuit_ready or flags.repair_signal:
		flags.key = true
		flags.relay = true
		flags.badge = true
		flags.circuit_ready = true
		flags.anchor_3_bound = true
		flags.anchor_3_era = 0
		flags.anchor_3_state = "71.7"
		flags.frequency = "71.7"
	if flags.roof_unlocked or flags.relay or flags.badge:
		flags.maintenance_unlocked = true
		flags.anchor_2_bound = true
	if flags.maintenance_unlocked or flags.anchor_2_bound:
		flags.anchor_1_bound = true
	if flags.anchor_1_bound:
		flags.anchor_1_era = 0
		flags.anchor_1_state = "开启"
		flags.photo = true
		flags.latch_open = true
	if flags.anchor_2_bound:
		flags.anchor_2_era = 1
		flags.anchor_2_state = "泄压"
		flags.valve_vented = true
		flags.pressure_valve = true
	if flags.relay: flags.memory_unlocked = true
	if flags.ticket_punch: flags.ticket_code = true
	if flags.finished and flags.ending_id == 3: flags.anchor_3_state = "事故前一瞬"
	flags.anomaly_level = mini(int(flags.anomaly_level), 3)
	_recount_anchors()
	_save_journey()

func apply_quality() -> void:
	world.env.ssao_enabled = high_quality
	world.env.volumetric_fog_enabled = high_quality
	get_viewport().msaa_3d = Viewport.MSAA_2X if high_quality else Viewport.MSAA_DISABLED
	for light in world.warm_lights:
		light.shadow_enabled = high_quality

func _save_settings() -> void:
	if test_mode:
		return
	var config := ConfigFile.new()
	config.set_value("settings", "volume", volume)
	config.set_value("settings", "high_quality", high_quality)
	config.save("user://settings.cfg")

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		volume = clampf(float(config.get_value("settings", "volume", 0.72)), 0, 1)
		high_quality = config.get_value("settings", "high_quality", true) == true
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)

func _capture_frame(file: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/" + file + ".png")

func _capture_scenes() -> void:
	test_mode = true
	player.mouse_look_enabled = false
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	await get_tree().create_timer(2.0).timeout
	await _capture_frame("title")
	start_journey(false)
	await _capture_frame("gameplay_guide")
	_on_ui_action("guide_start", "")
	player.place(Vector3(0.04, 0.09, 0.8), -0.08)
	for index in range(3):
		era = index
		_sync_world()
		_refresh_status()
		hud.subtitle_time = 0
		hud.toast_time = 0
		await get_tree().create_timer(1.0).timeout
		await _capture_frame("carriage_%d" % index)
		print("CAPTURE era=%d fps=%d draw_calls=%d" % [index, Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	era = 0
	_sync_world()
	interact("photo")
	await _capture_frame("clue")
	close_modal()
	open_era_selector("door_front")
	await _capture_frame("era_select")
	close_modal()
	open_radio()
	await _capture_frame("guided_repair")
	close_modal()
	open_journal()
	await _capture_frame("journal")
	close_modal()
	flags.key = true
	flags.relay = true
	flags.badge = true
	flags.route = true
	open_radio()
	install_radio()
	await _capture_frame("radio")
	choose_station("白桦")
	await _capture_frame("ending_choices")
	close_modal()
	flags.arrived = true
	world.reveal_platform()
	player.place(Vector3(80, 0.09, -4))
	_refresh_status()
	await get_tree().create_timer(1.0).timeout
	await _capture_frame("platform")
	get_tree().quit()
