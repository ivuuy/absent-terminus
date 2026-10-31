extends CanvasLayer
class_name TrainHUD

signal ui_action(action: String, value: String)

const FONT = preload("res://assets/fonts/InterfaceFont.tres")
const GOLD := Color("cbb58c")
const WHITE := Color("eee9dc")
const MUTED := Color("91a19e")

var root: Control
var menu: Control
var game_ui: Control
var modal: Control
var modal_panel: Panel
var modal_content: VBoxContainer
var film: ColorRect
var blackout: ColorRect
var objective: Label
var era_label: Label
var loop_label: Label
var clock_label: Label
var inventory: Label
var records_label: Label
var repair_label: Label
var stage_label: Label
var navigation: Label
var device_id := 0
var location_label: Label
var interaction: Panel
var interaction_title: Label
var interaction_hint: Label
var crosshair: Label
var subtitle: Label
var toast_label: Label
var toast_time := 0.0
var subtitle_time := 0.0
var continue_button: Button
var restart_button: Button
var modal_kind := ""

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 18
	root.theme = theme
	add_child(root)
	film = ColorRect.new()
	film.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://shaders/film.gdshader")
	film.material = shader
	root.add_child(film)
	_make_menu()
	_make_game_ui()
	_make_modal()
	blackout = ColorRect.new()
	blackout.color = Color(0.012, 0.018, 0.022, 0)
	blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(blackout)

func label(parent: Node, value: String, point: Vector2, font_size: int = 18, color: Color = WHITE, dimensions: Vector2 = Vector2.ZERO) -> Label:
	var item := Label.new()
	item.text = value
	item.position = point
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dimensions != Vector2.ZERO:
		item.size = dimensions
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

func line(parent: Node, point: Vector2, dimensions: Vector2, color: Color = Color("81765d")) -> ColorRect:
	var item := ColorRect.new()
	item.position = point
	item.size = dimensions
	item.color = color
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func style(bg: Color, border: Color = Color.TRANSPARENT, width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func button(parent: Node, value: String, action: String, payload: String = "", accent: bool = false) -> Button:
	var item := Button.new()
	item.text = value
	item.set_meta("action", action)
	item.set_meta("payload", payload)
	item.custom_minimum_size = Vector2(0, 53)
	item.add_theme_stylebox_override("normal", style(Color("c9b68e") if accent else Color("152629"), Color("c9b68e") if accent else Color("465551")))
	item.add_theme_stylebox_override("hover", style(Color("e1cba0") if accent else Color("233a3d"), GOLD))
	item.add_theme_stylebox_override("pressed", style(Color("a99370") if accent else Color("0f1e22"), GOLD))
	item.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, Color("f2e1bc"), 2))
	item.add_theme_color_override("font_color", Color("142328") if accent else WHITE)
	item.add_theme_color_override("font_hover_color", Color("142328") if accent else Color.WHITE)
	item.add_theme_color_override("font_pressed_color", Color("142328") if accent else WHITE)
	item.add_theme_color_override("font_focus_color", Color("142328") if accent else WHITE)
	item.add_theme_font_size_override("font_size", 18)
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.pressed.connect(func(): ui_action.emit(action, payload))
	parent.add_child(item)
	return item

func full_control(parent: Node) -> Control:
	var item := Control.new()
	item.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func anchor(item: Control, preset: Control.LayoutPreset, point: Vector2, dimensions: Vector2) -> void:
	item.set_anchors_preset(preset)
	item.offset_left = point.x
	item.offset_top = point.y
	item.offset_right = point.x + dimensions.x
	item.offset_bottom = point.y + dimensions.y

func _make_menu() -> void:
	menu = full_control(root)
	var badge := Panel.new()
	badge.position = Vector2(82, 56)
	badge.size = Vector2(50, 50)
	badge.add_theme_stylebox_override("panel", style(Color.TRANSPARENT, Color("8d8269")))
	menu.add_child(badge)
	label(badge, "07", Vector2(10, 5), 27, GOLD)
	label(menu, "北 境 铁 路", Vector2(148, 56), 18, GOLD)
	label(menu, "NORTHBOUND NIGHT SERVICE", Vector2(148, 84), 11, MUTED)
	line(menu, Vector2(86, 197), Vector2(38, 2), GOLD)
	label(menu, "一 段 未 抵 达 的 旅 程", Vector2(140, 184), 15, GOLD)
	var title := label(menu, "终点站\n不存在", Vector2(78, 224), 76, WHITE)
	title.add_theme_constant_override("line_spacing", -10)
	label(menu, "T H E   A B S E N T   T E R M I N U S", Vector2(86, 420), 14, GOLD)
	label(menu, "雪还在下。列车还在行驶。\n而你，已经第七次经过同一节车厢。", Vector2(86, 470), 19, Color("adb6af"), Vector2(470, 75))
	continue_button = button(menu, "登 上 列 车     →", "start", "", true)
	continue_button.position = Vector2(86, 585)
	continue_button.size = Vector2(330, 61)
	restart_button = button(menu, "重新开始", "confirm_restart")
	restart_button.position = Vector2(86, 662)
	restart_button.size = Vector2(156, 48)
	restart_button.visible = false
	var small := label(menu, "第一章  /  引导探索模式", Vector2.ZERO, 15, MUTED)
	anchor(small, Control.PRESET_BOTTOM_LEFT, Vector2(86, -87), Vector2(370, 30))
	var foot := label(menu, "建议佩戴耳机   ·   自动保存旅程", Vector2.ZERO, 12, Color("738784"))
	anchor(foot, Control.PRESET_BOTTOM_LEFT, Vector2(86, -51), Vector2(370, 25))
	var route := label(menu, "雾港   ───   北岭   ───   · · ·", Vector2.ZERO, 15, Color("c0c3b7"))
	anchor(route, Control.PRESET_TOP_RIGHT, Vector2(-390, 65), Vector2(340, 32))
	var chapter := label(menu, "01  /  THE LAST PASSENGER", Vector2.ZERO, 12, Color("b3bbb0"))
	anchor(chapter, Control.PRESET_BOTTOM_RIGHT, Vector2(-315, -52), Vector2(285, 26))

func _make_game_ui() -> void:
	game_ui = full_control(root)
	game_ui.visible = false
	label(game_ui, "终点站不存在", Vector2(42, 28), 22, WHITE)
	loop_label = label(game_ui, "07 号车厢  /  第 07 次经过", Vector2(44, 65), 12, MUTED)
	line(game_ui, Vector2(44, 94), Vector2(195, 1), Color("50605b"))
	clock_label = label(game_ui, "23 : 17", Vector2.ZERO, 31, WHITE)
	anchor(clock_label, Control.PRESET_TOP_RIGHT, Vector2(-170, 27), Vector2(140, 45))
	era_label = label(game_ui, "出 发 之 夜", Vector2.ZERO, 13, GOLD)
	anchor(era_label, Control.PRESET_TOP_RIGHT, Vector2(-160, 77), Vector2(140, 28))
	records_label = label(game_ui, "事故记录  0 / 3  ·  可选", Vector2.ZERO, 13, Color("b9c9bf"))
	anchor(records_label, Control.PRESET_TOP_RIGHT, Vector2(-260, 116), Vector2(235, 28))
	repair_label = label(game_ui, "广播待修复", Vector2.ZERO, 13, MUTED)
	anchor(repair_label, Control.PRESET_TOP_RIGHT, Vector2(-260, 145), Vector2(235, 28))
	navigation = label(game_ui, "◇ 当前目标", Vector2.ZERO, 15, GOLD, Vector2(360, 52))
	navigation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	navigation.add_theme_color_override("font_shadow_color", Color.BLACK)
	navigation.add_theme_constant_override("shadow_offset_x", 1)
	navigation.add_theme_constant_override("shadow_offset_y", 2)
	navigation.visible = false
	location_label = label(game_ui, "车厢", Vector2.ZERO, 12, MUTED)
	anchor(location_label, Control.PRESET_TOP_LEFT, Vector2(44, 101), Vector2(260, 24))
	crosshair = label(game_ui, "·", Vector2.ZERO, 30, Color(0.9, 0.92, 0.87, 0.7))
	anchor(crosshair, Control.PRESET_CENTER, Vector2(-5, -23), Vector2(10, 36))
	var objective_group := Control.new()
	objective_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.add_child(objective_group)
	anchor(objective_group, Control.PRESET_BOTTOM_LEFT, Vector2(44, -163), Vector2(600, 110))
	line(objective_group, Vector2(0, 4), Vector2(2, 63), GOLD)
	stage_label = label(objective_group, "第一幕 · 失踪的门", Vector2(17, 0), 13, GOLD)
	objective = label(objective_group, "寻找车票上的 07 号座位", Vector2(17, 26), 18, WHITE, Vector2(570, 65))
	inventory = label(game_ui, "随身物品  /  一张残缺的车票", Vector2.ZERO, 13, MUTED)
	anchor(inventory, Control.PRESET_BOTTOM_LEFT, Vector2(44, -45), Vector2(760, 25))
	var controls := label(game_ui, "W A S D  移动     E  交互\nF 手电  ·  TAB 手记  ·  H 提示  ·  ESC 暂停", Vector2.ZERO, 13, Color("bac2b8"))
	anchor(controls, Control.PRESET_BOTTOM_RIGHT, Vector2(-381, -93), Vector2(350, 80))
	controls.add_theme_constant_override("line_spacing", 9)
	interaction = Panel.new()
	interaction.add_theme_stylebox_override("panel", style(Color(0.03, 0.065, 0.072, 0.91), Color("65736a")))
	interaction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.add_child(interaction)
	anchor(interaction, Control.PRESET_CENTER, Vector2(-222, 110), Vector2(444, 89))
	label(interaction, "E", Vector2(24, 24), 26, GOLD)
	line(interaction, Vector2(62, 21), Vector2(1, 45), Color("65736a"))
	interaction_title = label(interaction, "查看", Vector2(80, 13), 20)
	interaction_hint = label(interaction, "", Vector2(80, 48), 12, MUTED, Vector2(350, 35))
	interaction.visible = false
	subtitle = label(game_ui, "", Vector2.ZERO, 21, WHITE)
	anchor(subtitle, Control.PRESET_CENTER_BOTTOM, Vector2(-410, -227), Vector2(820, 66))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_shadow_color", Color.BLACK)
	subtitle.add_theme_constant_override("shadow_offset_x", 1)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	toast_label = label(game_ui, "", Vector2.ZERO, 15, GOLD)
	anchor(toast_label, Control.PRESET_CENTER_TOP, Vector2(-340, 90), Vector2(680, 60))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _make_modal() -> void:
	modal = full_control(root)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.022, 0.027, 0.76)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	modal_panel = Panel.new()
	modal_panel.add_theme_stylebox_override("panel", style(Color("102125"), Color("687064")))
	modal.add_child(modal_panel)
	anchor(modal_panel, Control.PRESET_CENTER, Vector2(-375, -310), Vector2(750, 620))
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margins.add_theme_constant_override("margin_" + edge, 40)
	for edge in ["top", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 32)
	modal_panel.add_child(margins)
	modal_content = VBoxContainer.new()
	modal_content.add_theme_constant_override("separation", 16)
	margins.add_child(modal_content)
	modal.visible = false

func begin_modal(kind: String, eyebrow: String, title: String) -> void:
	modal_kind = kind
	for child in modal_content.get_children():
		modal_content.remove_child(child)
		child.queue_free()
	modal.visible = true
	label(modal_content, eyebrow, Vector2.ZERO, 12, GOLD)
	label(modal_content, title, Vector2.ZERO, 32, WHITE)
	var separator := HSeparator.new()
	var divider := StyleBoxLine.new()
	divider.color = Color("465650")
	divider.thickness = 1
	separator.add_theme_stylebox_override("separator", divider)
	separator.custom_minimum_size.y = 1
	modal_content.add_child(separator)

func body(value: String, expand: bool = true) -> RichTextLabel:
	var item := RichTextLabel.new()
	item.bbcode_enabled = true
	item.text = value
	item.add_theme_font_size_override("normal_font_size", 18)
	item.add_theme_color_override("default_color", Color("c3ccc3"))
	item.add_theme_constant_override("line_separation", 6)
	item.size_flags_vertical = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_FILL
	item.fit_content = not expand
	item.scroll_active = true
	modal_content.add_child(item)
	return item

func show_note(title: String, text: String, eyebrow: String = "旅 途 拾 遗  /  已记入手记") -> void:
	begin_modal("note", eyebrow, title)
	body(text)
	button(modal_content, "收起     [ E / ESC ]", "close", "", true).grab_focus()

func show_journal(text: String) -> void:
	begin_modal("journal", "PASSENGER 07  /  JOURNAL", "乘客手记")
	body(text)
	button(modal_content, "玩法与当前步骤提示     [ H ]", "help")
	button(modal_content, "继续探索     [ TAB / ESC ]", "close", "", true).grab_focus()

func show_help(goal: Dictionary, introduction: bool = false) -> void:
	begin_modal("help", "引导探索模式  /  随时按 H 回看", "找到线索，让列车停下来")
	body("[color=#d7bd8c]目标：找齐三件广播零件，补全终点站名。[/color]\n\n1. 跟随金色 ◇ 找物件，对准后按 E 查看或操作。\n2. 在端门或检修钟前按 E，自行选择年代。\n3. 道具到机关使用；修好的机关一直有效。\n\n[color=#d7bd8c]现在要做：[/color]" + goal.text + "\n" + goal.tip + "\n\n[color=#809893]WASD 移动 · 鼠标环顾 · E 交互 · F 手电\nTab 手记 · H 提示 · Esc 暂停\n广播可能说谎，请以左下角目标为准。选错可重试。[/color]")
	button(modal_content, "明白了，开始探索" if introduction else "继续探索", "guide_start", "", true).grab_focus()

func show_eras(current: int, task: String) -> void:
	begin_modal("eras", "时间入口  /  选择后留在原位", "你想去哪个年代？")
	body("当前：%s\n[color=#d7bd8c]目标：%s[/color]\n\n三个年代是同一个地方的不同样子。已经修好的机关、找到的道具都会保留。" % [["出发之夜", "停电时刻", "多年以后"][current], task])
	var descriptions := ["出发之夜  ·  拨动座椅连杆 / 使用广播", "停电时刻  ·  转动泄压阀 / 进入记忆空间", "多年以后  ·  找继电器、钥匙与事故记录"]
	for index in range(3):
		var option := button(modal_content, descriptions[index] + ("  （当前）" if current == index else ""), "era", str(index))
		option.disabled = index == current
	button(modal_content, "留在这里", "close", "", true).grab_focus()

func show_device(id: int, era: int, flags: Dictionary) -> void:
	device_id = id
	begin_modal("device", "机械操作  /  修好后持续有效", "07 席维修连杆" if id == 1 else "检修口泄压阀")
	var done: bool = flags["anchor_%d_bound" % id]
	var correct_era := era == (0 if id == 1 else 1)
	var explanation := "连杆连接左墙的维修门。出发之夜拨动一次，其他年代的维修门也会保持开启。" if id == 1 else "管道压力顶住了车顶检修口。停电时转动轮盘泄压，多年以后的门就能打开。"
	body(explanation + ("\n\n[color=#d7bd8c]已完成，无需重复操作。[/color]" if done else ("\n\n可以操作。" if correct_era else "\n\n[color=#d7bd8c]请先选择「%s」。[/color]" % ("出发之夜" if id == 1 else "停电时刻"))))
	if not done:
		var operate := button(modal_content, "拨动连杆，打开维修门" if id == 1 else "转动阀门，为检修口泄压", "repair_device", str(id), true)
		operate.disabled = not correct_era
	button(modal_content, "继续探索", "close").grab_focus()

func show_radio_repair(era: int, flags: Dictionary) -> void:
	begin_modal("radio_repair", "广播控制柜  /  道具在这里自动使用", "安装广播零件")
	var text := "带齐三件物品，在「出发之夜」一次安装：\n\n"
	for item in [["key", "黄铜钥匙", "多年以后，主车厢左墙入口上方"], ["relay", "车顶继电器", "多年以后，维修夹层内"], ["badge", "乘务员徽章", "停电时刻，主车厢右侧 08 席后"]]:
		text += ("[color=#d7bd8c]✓ 已有：" if flags[item[0]] else "[color=#91a19e]○ 缺少：") + item[1] + " · " + item[2] + "[/color]\n"
	text += "\n电源：" + ("可用。安装后自动完成接线和调谐。" if era == 0 else "无电。先到车厢端门选择「出发之夜」。")
	body(text)
	var install := button(modal_content, "使用三件物品，修复广播", "install_radio", "", true)
	install.disabled = era != 0 or not flags.key or not flags.relay or not flags.badge
	button(modal_content, "继续寻找", "close").grab_focus()

func show_radio(has_truth: bool = false, has_route: bool = false, has_postcard: bool = false) -> void:
	begin_modal("radio", "广播已通电  /  维修频率 71.7", "补全下一站的名字")
	var clue := "线索在广播柜对面的线路图上。也可以查看车厢右侧桌上的明信片。"
	if has_route: clue = "[color=#d7bd8c]你已记录线路：雾港 → 北岭 → 白桦。[/color]"
	elif has_postcard: clue = "[color=#d7bd8c]明信片：越过北岭，再坐一站，在白色树干的地方下车。[/color]"
	body("录音停在这里：\n[color=#d7bd8c]“北岭站已过。下一站，________。”[/color]\n\n" + clue + "\n\n选择北岭之后的站名。选错可以再次尝试。")
	for station in ["雾港", "北岭", "白桦"]:
		button(modal_content, "播放  ·  " + station + "站", "station", station)
	button(modal_content, "先查看线索", "close").grab_focus()

func show_station_retry(station: String, has_route: bool, has_postcard: bool) -> void:
	show_radio(false, has_route, has_postcard)
	var message := "“%s”没有接上录音。北岭已经经过，请找它后面的一站。" % station
	for child in modal_content.get_children():
		if child is RichTextLabel:
			child.text = "[color=#d7bd8c]" + message + "[/color]\n\n" + child.text
			break

func show_pause(volume: float, quality: bool) -> void:
	begin_modal("pause", "THE JOURNEY IS WAITING", "列车暂时停靠")
	button(modal_content, "继续旅程", "close", "", true).grab_focus()
	button(modal_content, "玩法与当前步骤提示", "help")
	button(modal_content, "画面模式：" + ("电影" if quality else "流畅") + "    /    点击切换", "quality")
	var audio_label := label(modal_content, "主音量 · 音乐与音效", Vector2.ZERO, 14, MUTED)
	audio_label.custom_minimum_size.y = 22
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = volume
	slider.custom_minimum_size.y = 30
	slider.value_changed.connect(func(value: float): ui_action.emit("volume", str(value)))
	modal_content.add_child(slider)
	body("WASD 移动 · 鼠标环顾 · Shift 快走\nE 查看 / 使用 · F 手电筒 · Tab 手记\nH 玩法提示 · Esc 暂停 · F11 全屏\n\n物品与时间变化会自动保存。", true)
	button(modal_content, "返回标题", "menu")

func show_restart_confirm() -> void:
	begin_modal("restart", "A NEW JOURNEY", "重新登上列车？")
	body("当前旅程的存档将被新的旅程替代。\n\n你会回到出发之夜，重新寻找遗失的站名。")
	button(modal_content, "开始新的旅程", "new", "", true)
	button(modal_content, "保留当前旅程", "cancel_restart").grab_focus()

func show_ending() -> void:
	begin_modal("ending", "CHAPTER 01  /  COMPLETE", "你终于到了。")
	body("列车的声音渐渐远去。\n\n那个人把一张完整的车票递给你。\n目的地的空白处，终于出现了两个字：\n\n[color=#d7bd8c]白桦。[/color]\n\n“我以为你再也不会记得。”\n\n[color=#809893]第一章 · 遗失的站名　完[/color]")
	button(modal_content, "再看看这座站台", "close", "", true).grab_focus()
	button(modal_content, "返回标题", "menu")

func show_ending_variant(ending_id: int) -> void:
	var titles := {1: "你终于抵达白桦。", 2: "请最后一位乘客留下。", 3: "终点站不存在。"}
	var bodies := {
		1: "列车终于停下。\n\n站台上的乘务员把一张完整车票递给你，随后在风雪中消失。\n\n目的地一栏仍然写着：\n[color=#d7bd8c]下一站[/color]\n\n广播再次响起，但这一次没有叫出你的座位号。\n\n[color=#809893]结局一 · 离站[/color]",
		2: "你把徽章放回广播柜。\n\n乘务员第一次抬起头，帽檐下仍然没有脸。\n\n广播：\n[color=#d7bd8c]“下一站，即将到达终点。请最后一位乘客准备查票。”[/color]\n\n车门在你身后合上。\n\n[color=#809893]结局二 · 接班[/color]",
		3: "三份事故记录拼在一起，终于形成完整日期。\n\n列车早在七天前就已经消失。白桦站台从未存在。\n\n你把三份记录送入广播。事故发生前的最后一秒被公开，整列车在雪里折叠成一张完整车票。\n\n[color=#d7bd8c]终点站：不存在[/color]\n\n[color=#809893]结局三 · 不存在的终点[/color]"
	}
	begin_modal("ending", "CHAPTER 01  /  COMPLETE", titles.get(ending_id, "旅程结束"))
	body(bodies.get(ending_id, "旅程结束。"))
	button(modal_content, "返回标题", "menu", "", true).grab_focus()

func show_ending_choice(truth_fragments: int, trust: bool, repair_signal: bool = true, badge: bool = true) -> void:
	begin_modal("ending_choice", "THE LAST INSPECTION  /  终点选择", "你准备怎样结束旅程？")
	body("广播已经恢复。\n\n你可以独自下车，也可以相信乘务员，留下接班。\n\n想让所有人离开，需要找齐三份事故记录。\n[color=#d7bd8c]已找到事故记录：%d / 3[/color]" % truth_fragments)
	var leave := button(modal_content, "修复广播，离开列车", "ending_leave", "", true)
	leave.disabled = not repair_signal
	var takeover := button(modal_content, "相信乘务员，留下接班", "ending_takeover")
	takeover.disabled = not badge
	var expose := button(modal_content, "公开三份事故记录，让所有人离开", "ending_expose")
	expose.disabled = truth_fragments < 3
	if truth_fragments < 3:
		button(modal_content, "继续寻找事故记录（%d / 3，可选）" % truth_fragments, "investigate")
	button(modal_content, "暂时离开广播柜", "close").grab_focus()

func show_conductor(ticket_valid: bool, trusted: bool) -> void:
	begin_modal("conductor", "失踪乘务员  /  最后一次查票", "他把空白车票递给你")
	body("帽檐下没有脸。声音却来自广播柜。\n\n“把徽章放回去，替我送走最后一位乘客。”\n\n打孔车票有效：%s\n你是否相信他：%s" % ["是" if ticket_valid else "否", "是" if trusted else "否"])
	button(modal_content, "相信乘务员", "trust", "yes", true)
	button(modal_content, "拒绝并记录异常", "trust", "no")
	button(modal_content, "离开", "close").grab_focus()

func show_menu(saved: bool) -> void:
	menu.visible = true
	game_ui.visible = false
	modal.visible = false
	film.material.set_shader_parameter("menu_shade", 1.0)
	continue_button.text = "继 续 旅 程     →" if saved else "登 上 列 车     →"
	restart_button.visible = saved
	continue_button.grab_focus()

func enter_game() -> void:
	menu.visible = false
	game_ui.visible = true
	modal.visible = false
	film.material.set_shader_parameter("menu_shade", 0.0)

func hide_modal() -> void:
	modal.visible = false
	modal_kind = ""

func status(era: int, loops: int, task: String, items: String, platform_active: bool, records: int, repaired: bool, location: String, stage: String) -> void:
	loop_label.text = "白桦站台  /  旅程的尽头" if platform_active else "07 号车厢  /  引导探索模式"
	era_label.text = "终 于 抵 达" if platform_active else ["出 发 之 夜", "停 电 时 刻", "多 年 以 后"][era]
	clock_label.text = "00 : 00" if platform_active else ["23 : 17", "23 : 17", "— : —"][era]
	objective.text = task
	stage_label.text = stage
	inventory.text = "随身物品  /  " + items
	records_label.text = "事故记录  %d / 3  ·  可选" % records
	repair_label.text = "广播已修复" if repaired else "广播零件待收集"
	location_label.text = "位置  /  " + location

func set_navigation(camera: Camera3D, point: Vector3, caption: String) -> void:
	if modal.visible or not game_ui.visible:
		navigation.visible = false
		return
	navigation.visible = true
	var size := root.size
	var behind := camera.is_position_behind(point)
	var screen := camera.unproject_position(point) if not behind else Vector2(size.x * 0.5, 185)
	var outside := behind or screen.x < 70 or screen.x > size.x - 70 or screen.y < 180 or screen.y > size.y - 260
	if outside:
		var local := camera.to_local(point)
		var direction := "← 转身寻找" if local.x < 0 else "→ 转身寻找"
		if not behind:
			if screen.x < 70: direction = "← 向左寻找"
			elif screen.x > size.x - 70: direction = "→ 向右寻找"
			elif screen.y < 180: direction = "↑ 抬头寻找"
			else: direction = "↓ 低头寻找"
		navigation.text = direction + " · " + caption
		navigation.position = Vector2(size.x * 0.5 - 180, 185)
	else:
		navigation.text = "◇ " + caption + "  ·  %d 米" % maxi(1, int(camera.global_position.distance_to(point)))
		navigation.position = Vector2(clampf(screen.x - 180, 35, size.x - 395), clampf(screen.y - 50, 185, size.y - 300))

func set_target(target: TrainInteractable) -> void:
	interaction.visible = target != null and not modal.visible and game_ui.visible
	crosshair.modulate = GOLD if target else Color(0.9, 0.92, 0.87, 0.6)
	if target:
		interaction_title.text = target.title
		interaction_hint.text = target.hint

func toast(value: String, seconds: float = 3.5) -> void:
	toast_label.text = value
	toast_time = seconds
	toast_label.modulate.a = 1.0

func speak(value: String, seconds: float = 6.0) -> void:
	subtitle.text = value
	subtitle_time = seconds
	subtitle.modulate.a = 1.0

func fade(to: float, duration: float = 0.6) -> Tween:
	var tween := create_tween()
	tween.tween_property(blackout, "color:a", to, duration)
	return tween

func _process(delta: float) -> void:
	toast_time = maxf(0, toast_time - delta)
	subtitle_time = maxf(0, subtitle_time - delta)
	toast_label.modulate.a = minf(toast_time, 1.0)
	subtitle.modulate.a = minf(subtitle_time, 1.0)
