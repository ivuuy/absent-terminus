extends Node3D
class_name NightTrainWorld

const FONT = preload("res://assets/fonts/InterfaceFont.tres")
const HOTSPOT = preload("res://scripts/interactable.gd")
const TEMPORAL = preload("res://scripts/temporal_object.gd")

var materials: Dictionary = {}
var geometry: Dictionary = {}
var hotspots: Dictionary = {}
var car: Node3D
var platform: Node3D
var abandoned: Node3D
var modern: Node3D
var key_prop: Node3D
var cabinet_door: Node3D
var maintenance: Node3D
var roof_space: Node3D
var memory_space: Node3D
var conductor_figure: Node3D
var anomaly_overlay: Node3D
var latch_lever: Node3D
var valve_wheel: Node3D
var repair_leaf: Node3D
var hatch_leaf: Node3D
var memory_portal: Node3D
var foreign_prop: Node3D
var check_prop: Node3D
var reflection_figure: Node3D
var anomaly_seats: Array[Node3D] = []
var last_flags: Dictionary = {}
var temporal_objects: Dictionary = {}
var hidden_lights: Array[OmniLight3D] = []
var env: Environment
var warm_lights: Array[OmniLight3D] = []
var red_lights: Array[OmniLight3D] = []
var window_lights: Array[SpotLight3D] = []
var trees: Array[Node3D] = []
var snow: Array[GPUParticles3D] = []
var era := 0
var on_platform := false
var active_location := "carriage"
var elapsed := 0.0
var clock_hands: Array[Node3D] = []

func _ready() -> void:
	_make_materials()
	_make_environment()
	_make_landscape()
	car = Node3D.new()
	car.name = "Carriage07"
	add_child(car)
	modern = Node3D.new()
	modern.name = "IntactWallPanel"
	car.add_child(modern)
	abandoned = Node3D.new()
	abandoned.name = "AbandonedDetails"
	car.add_child(abandoned)
	_make_shell()
	_make_booths()
	_make_ends()
	_make_details()
	_make_hidden_spaces()
	_make_platform()
	set_era(0, {})

func material(color: String, roughness: float = 0.6, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = roughness
	m.metallic = metallic
	return m

func _make_materials() -> void:
	for name_key in ["walnut", "velvet", "carpet", "plaster", "brass"]:
		var m := material("ffffff")
		m.albedo_texture = load("res://assets/textures/" + name_key + ".png")
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 1.25
		materials[name_key] = m
	materials.walnut.roughness = 0.48
	materials.velvet.roughness = 0.94
	materials.brass.metallic = 0.72
	materials.brass.roughness = 0.3
	materials["dark_wood"] = material("211b18", 0.36)
	materials["green"] = material("163e37", 0.46)
	materials["leather"] = material("342a23", 0.68)
	materials["curtain"] = material("514236", 0.95)
	materials["black"] = material("0c1215", 0.8)
	materials["steel"] = material("3f4c50", 0.28, 0.75)
	materials["paper"] = material("c9bb98", 0.95)
	materials["ink"] = material("35494a", 0.8)
	materials["snow"] = material("a8bdca", 0.94)
	materials["land"] = material("334e60", 1)
	materials["mountain"] = material("1f3345", 1)
	materials["pine"] = material("102c34", 0.95)
	materials["red"] = material("903828", 0.4)
	var lamp := material("ffe0a0", 0.4)
	lamp.emission_enabled = true
	lamp.emission = Color("ffbd65")
	lamp.emission_energy_multiplier = 2.6
	materials["lamp"] = lamp
	var emergency := material("a02719")
	emergency.emission_enabled = true
	emergency.emission = Color("f24821")
	emergency.emission_energy_multiplier = 1.4
	materials["emergency"] = emergency
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://shaders/glass.gdshader")
	materials["glass"] = glass

func _make_environment() -> void:
	var environment := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("102238")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("94b5ce")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 0.65
	env.ssao_intensity = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.48
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color("27425a")
	env.fog_light_energy = 0.5
	env.fog_density = 0.005
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.009
	env.volumetric_fog_albedo = Color("91a3b0")
	env.volumetric_fog_length = 45.0
	environment.environment = env
	add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-32, -48, 0)
	moon.light_color = Color("87b9e5")
	moon.light_energy = 0.65
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 55.0
	add_child(moon)

func rounded_mesh(size: Vector3, radius: float) -> ArrayMesh:
	var cache_key := str(size) + "_" + str(radius)
	if geometry.has(cache_key):
		return geometry[cache_key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	var r := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.9)
	var inner := half - Vector3.ONE * r
	var axes := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for normal: Vector3 in axes:
		var u := Vector3.RIGHT if absf(normal.y) > 0.5 else Vector3.UP
		var v := normal.cross(u)
		var hu := absf(u.dot(half))
		var hv := absf(v.dot(half))
		var hn := absf(normal.dot(half))
		var us := [-hu, -hu + r * 0.3, -hu + r, hu - r, hu - r * 0.3, hu]
		var vs := [-hv, -hv + r * 0.3, -hv + r, hv - r, hv - r * 0.3, hv]
		for i in range(5):
			for j in range(5):
				for ij: Vector2i in [Vector2i(i,j), Vector2i(i+1,j+1), Vector2i(i+1,j), Vector2i(i,j), Vector2i(i,j+1), Vector2i(i+1,j+1)]:
					var point: Vector3 = normal * hn + u * us[ij.x] + v * vs[ij.y]
					var nearest := point.clamp(-inner, inner)
					var n := (point - nearest).normalized()
					st.set_normal(n)
					st.set_uv(Vector2(us[ij.x] / size.length(), vs[ij.y] / size.length()))
					st.add_vertex(nearest + n * r)
	var mesh := st.commit()
	geometry[cache_key] = mesh
	return mesh

func box(parent: Node, pos: Vector3, size: Vector3, mat: String, bevel: float = 0.0, solid: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	if bevel > 0:
		node.mesh = rounded_mesh(size, bevel)
	else:
		var key := "box" + str(size)
		if not geometry.has(key):
			var cube := BoxMesh.new()
			cube.size = size
			geometry[key] = cube
		node.mesh = geometry[key]
	node.material_override = materials[mat]
	node.position = pos
	parent.add_child(node)
	if solid:
		collision(parent, pos, size)
	return node

func cylinder(parent: Node, pos: Vector3, radius: float, height: float, mat: String, top: float = -1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var key := "cyl_%s_%s_%s" % [radius, height, top]
	if not geometry.has(key):
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = radius
		mesh.top_radius = radius if top < 0 else top
		mesh.height = height
		mesh.radial_segments = 24
		geometry[key] = mesh
	node.mesh = geometry[key]
	node.material_override = materials[mat]
	node.position = pos
	parent.add_child(node)
	return node

func orb(parent: Node, pos: Vector3, radius: float, mat: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var key := "sphere" + str(radius)
	if not geometry.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2
		mesh.radial_segments = 16
		mesh.rings = 8
		geometry[key] = mesh
	node.mesh = geometry[key]
	node.material_override = materials[mat]
	node.position = pos
	parent.add_child(node)
	return node

func collision(parent: Node, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = size
	shape.shape = cube
	body.add_child(shape)
	parent.add_child(body)

func lettering(parent: Node, value: String, pos: Vector3, size: int = 36, color: String = "d3c09a", scale_px: float = 0.002) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.font = FONT
	label.font_size = size
	label.pixel_size = scale_px
	label.modulate = Color(color)
	label.outline_size = 0
	label.no_depth_test = false
	label.position = pos
	parent.add_child(label)
	return label

func hotspot(id: String, title: String, hint: String, pos: Vector3, size: Vector3, parent: Node = null) -> TrainInteractable:
	var area := HOTSPOT.new()
	area.name = "Interact_" + id
	area.configure(id, title, hint, size)
	area.position = pos
	(parent if parent != null else car).add_child(area)
	hotspots[id] = area
	return area

func _make_shell() -> void:
	box(car, Vector3(0, -0.15, -5), Vector3(4.5, 0.3, 16.6), "dark_wood", 0, true)
	for i in range(13):
		box(car, Vector3(-2.0 + i * 0.335, 0.018, -5), Vector3(0.325, 0.035, 16.2), "walnut")
	box(car, Vector3(0, 0.042, -5), Vector3(1.04, 0.025, 16.1), "carpet")
	for x in [-0.53, 0.53]:
		box(car, Vector3(x, 0.059, -5), Vector3(0.018, 0.01, 16.1), "brass")
	for side in [-1.0, 1.0]:
		box(car, Vector3(side * 2.18, 0.52, -5), Vector3(0.2, 1.05, 16.4), "walnut", 0, true)
		box(car, Vector3(side * 2.18, 2.64, -5), Vector3(0.2, 0.49, 16.4), "walnut", 0, true)
		collision(car, Vector3(side * 2.23, 1.7, -5), Vector3(0.12, 1.5, 16.4))
		for y in [0.13, 0.96, 1.035, 2.39, 2.48]:
			box(car, Vector3(side * 2.062, y, -5), Vector3(0.035, 0.027, 16.4), "brass")
		for z in [2.7, 1.6, -1.6, -4.8, -8.0, -11.2, -12.8]:
			box(car, Vector3(side * 2.12, 1.7, z), Vector3(0.2, 1.4, 0.42), "walnut", 0.025)
			for dz in [-0.17, 0.17]:
				box(car, Vector3(side * 2.007, 1.7, z + dz), Vector3(0.012, 1.37, 0.018), "brass")
		for z in [0.0, -3.2, -6.4, -9.6]:
			_make_window(side, z)
			for pz in [-0.62, 0.62]:
				box(car, Vector3(side * 2.063, 0.49, z + pz), Vector3(0.02, 0.65, 1.08), "dark_wood", 0.025)
				box(car, Vector3(side * 2.046, 0.49, z + pz), Vector3(0.016, 0.59, 1.02), "walnut", 0.02)
	# A curved barrel ceiling, assembled from twelve broad panels.
	for i in range(14):
		var angle := -PI / 2 + (i + 0.5) * PI / 14
		var x := sin(angle) * 2.2
		var y := 2.48 + cos(angle) * 0.7
		var segment := box(car, Vector3(x, y, -5), Vector3(0.52, 0.09, 16.6), "plaster")
		segment.rotation.z = -atan2(sin(angle) * 0.7, cos(angle) * 2.2)
	for z in [2.7, 1.6, -1.6, -4.8, -8.0, -11.2, -13.0]:
		for i in range(16):
			var angle := -PI / 2 + (i + 0.5) * PI / 16
			var beam := box(car, Vector3(sin(angle) * 2.17, 2.46 + cos(angle) * 0.69, z), Vector3(0.46, 0.045, 0.06), "walnut", 0.015)
			beam.rotation.z = -atan2(sin(angle) * 0.69, cos(angle) * 2.17)
	for z in [0.0, -3.2, -6.4, -9.6, -12.0]:
		_make_lamp(Vector3(0, 2.84, z))

func _make_window(side: float, z: float) -> void:
	for dz in [-1.37, 1.37]:
		box(car, Vector3(side * 2.02, 1.71, z + dz), Vector3(0.105, 1.47, 0.075), "dark_wood", 0.02)
	for y in [1.06, 2.38]:
		box(car, Vector3(side * 2.02, y, z), Vector3(0.105, 0.075, 2.82), "dark_wood", 0.02)
	box(car, Vector3(side * 2.03, 1.72, z), Vector3(0.028, 1.27, 2.65), "glass")
	box(car, Vector3(side * 2.0, 1.72, z), Vector3(0.065, 1.27, 0.028), "brass")
	box(car, Vector3(side * 1.94, 1.027, z), Vector3(0.32, 0.065, 2.88), "walnut", 0.025)
	# Pleated curtains leave the view unobstructed.
	for edge in [-1.0, 1.0]:
		for fold in range(5):
			var curtain := cylinder(car, Vector3(side * (1.96 - sin(fold * 1.5) * 0.025), 1.73, z + edge * (1.12 + fold * 0.043)), 0.048, 1.35, "curtain")
			curtain.scale.x = 0.55
		box(car, Vector3(side * 1.918, 1.5, z + edge * 1.23), Vector3(0.018, 0.055, 0.24), "brass", 0.008)
	var rod := cylinder(car, Vector3(side * 1.93, 2.435, z), 0.021, 2.98, "brass")
	rod.rotation.x = PI / 2
	var light := SpotLight3D.new()
	light.position = Vector3(side * 2.0, 1.95, z)
	light.rotation_degrees = Vector3(-15, 90 if side > 0 else -90, 0)
	light.light_color = Color("79afd6")
	light.light_energy = 1.2
	light.spot_range = 4.7
	light.spot_angle = 67
	light.shadow_enabled = false
	car.add_child(light)
	window_lights.append(light)

func _make_booths() -> void:
	for bay in range(4):
		var z := -bay * 3.2
		for side in [-1.0, 1.0]:
			var x: float = side * 1.37
			for facing in [-1.0, 1.0]:
				var seat := _make_seat(Vector3(x, 0, z + facing * 0.99), -facing)
				if facing > 0:
					# Mount the number on the outer backrest, in seat-local space.
					# It must follow the seat when an anomaly shifts the furniture.
					var plaque := box(seat, Vector3(side * 0.4, 1.19, -0.4), Vector3(0.23, 0.11, 0.023), "brass", 0.012)
					plaque.rotation.y = PI
					var seat_num := "%02d" % (bay * 2 + (1 if side < 0 else 2))
					lettering(plaque, seat_num, Vector3(0, 0, 0.014), 30, "182f30", 0.0022)
			box(car, Vector3(x, 0.79, z), Vector3(1.0, 0.065, 0.69), "walnut", 0.045, true)
			box(car, Vector3(x, 0.826, z), Vector3(0.93, 0.007, 0.62), "leather", 0.03)
			cylinder(car, Vector3(x, 0.4, z), 0.045, 0.76, "brass")
			cylinder(car, Vector3(x, 0.09, z), 0.21, 0.05, "dark_wood")
			# Long brass luggage racks above each booth.
			for rack_x in [side * 1.46, side * 1.88]:
				var rail := cylinder(car, Vector3(rack_x, 2.44, z), 0.018, 2.8, "brass")
				rail.rotation.x = PI / 2
			for step in range(14):
				var crossbar := cylinder(car, Vector3(side * 1.67, 2.44, z - 1.26 + step * 0.19), 0.009, 0.45, "brass")
				crossbar.rotation.z = PI / 2
			for dz in [-1.2, 1.2]:
				var support := cylinder(car, Vector3(side * 1.77, 2.55, z + dz), 0.019, 0.63, "brass")
				support.rotation.z = side * -0.44
			# Ceramic cups, saucers, and a reading light.
			cylinder(car, Vector3(x + side * 0.22, 0.842, z + 0.13), 0.082, 0.012, "paper")
			cylinder(car, Vector3(x + side * 0.22, 0.887, z + 0.13), 0.042, 0.075, "paper", 0.052)
			cylinder(car, Vector3(x + side * 0.22, 0.926, z + 0.13), 0.041, 0.002, "dark_wood")
			if bay % 2 == 0:
				_make_case(Vector3(side * 1.68, 2.57, z + 0.25), side * 0.04)

func _make_seat(pos: Vector3, facing: float) -> Node3D:
	var seat := Node3D.new()
	seat.position = pos
	if facing < 0:
		seat.rotation.y = PI
	car.add_child(seat)
	seat.set_meta("original_x", pos.x)
	anomaly_seats.append(seat)
	box(seat, Vector3(0, 0.26, 0), Vector3(1.24, 0.39, 0.65), "dark_wood", 0.045)
	box(seat, Vector3(0, 0.49, 0.02), Vector3(1.21, 0.19, 0.72), "velvet", 0.07)
	box(seat, Vector3(0, 0.97, -0.28), Vector3(1.25, 0.88, 0.22), "walnut", 0.07)
	box(seat, Vector3(0, 0.96, -0.142), Vector3(1.13, 0.74, 0.18), "velvet", 0.075)
	box(seat, Vector3(0, 1.367, -0.28), Vector3(1.16, 0.019, 0.13), "brass", 0.008)
	for x in [-0.6, 0.6]:
		box(seat, Vector3(x, 0.69, 0.015), Vector3(0.075, 0.07, 0.69), "walnut", 0.025)
		cylinder(seat, Vector3(x, 0.52, 0.28), 0.016, 0.32, "brass")
	for x in [-0.36, 0.0, 0.36]:
		for y in [0.83, 1.1]:
			orb(seat, Vector3(x, y, -0.043), 0.018, "green")
	collision(seat, Vector3(0, 0.69, -0.05), Vector3(1.3, 1.36, 0.82))
	return seat

func _make_case(pos: Vector3, yaw: float) -> void:
	var suitcase := Node3D.new()
	suitcase.position = pos
	suitcase.rotation.y = yaw
	car.add_child(suitcase)
	box(suitcase, Vector3.ZERO, Vector3(0.46, 0.22, 0.68), "leather", 0.045)
	for z in [-0.22, 0.22]:
		box(suitcase, Vector3(0, 0.005, z), Vector3(0.467, 0.228, 0.045), "dark_wood", 0.015)
		box(suitcase, Vector3(-0.236, 0.01, z), Vector3(0.012, 0.065, 0.055), "brass", 0.005)
	box(suitcase, Vector3(-0.26, 0.04, 0), Vector3(0.045, 0.035, 0.15), "leather", 0.012)

func _make_lamp(pos: Vector3) -> void:
	cylinder(car, pos + Vector3(0, 0.15, 0), 0.09, 0.14, "brass").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cylinder(car, pos, 0.29, 0.075, "brass", 0.19).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cylinder(car, pos + Vector3(0, -0.067, 0), 0.24, 0.09, "lamp", 0.27).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cylinder(car, pos + Vector3(0, -0.124, 0), 0.245, 0.022, "brass").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, -0.27, 0)
	light.light_color = Color("ffcf8d")
	light.light_energy = 1.55
	light.omni_range = 4.3
	light.omni_attenuation = 1.5
	light.shadow_enabled = true
	light.shadow_bias = 0.04
	car.add_child(light)
	warm_lights.append(light)

func _make_ends() -> void:
	for front in [true, false]:
		var end := Node3D.new()
		end.position.z = -13.1 if front else 3.1
		if not front:
			end.rotation.y = PI
		car.add_child(end)
		for x in [-1.42, 1.42]:
			box(end, Vector3(x, 1.45, 0), Vector3(1.38, 2.9, 0.18), "walnut", 0.025, true)
			box(end, Vector3(x, 0.63, 0.105), Vector3(1.13, 0.95, 0.025), "dark_wood", 0.025)
			box(end, Vector3(x, 0.63, 0.124), Vector3(1.04, 0.86, 0.02), "walnut", 0.025)
		box(end, Vector3(0, 2.67, 0), Vector3(1.6, 0.71, 0.2), "walnut", 0.01, true)
		for x in [-0.66, 0.66]:
			box(end, Vector3(x, 1.18, 0.08), Vector3(0.09, 2.35, 0.13), "brass", 0.02)
		box(end, Vector3(0, 2.32, 0.08), Vector3(1.39, 0.055, 0.13), "brass", 0.01)
		box(end, Vector3(0, 1.15, 0.045), Vector3(1.23, 2.29, 0.16), "green", 0.035, true)
		box(end, Vector3(0, 1.73, 0.138), Vector3(0.79, 0.8, 0.045), "brass", 0.065)
		box(end, Vector3(0, 1.73, 0.166), Vector3(0.71, 0.72, 0.03), "black", 0.055)
		box(end, Vector3(0, 1.73, 0.185), Vector3(0.7, 0.71, 0.014), "glass", 0.05)
		box(end, Vector3(0, 0.48, 0.138), Vector3(0.86, 0.48, 0.025), "walnut", 0.015)
		for j in range(7):
			box(end, Vector3(0, 0.32 + j * 0.052, 0.159), Vector3(0.71, 0.016, 0.015), "brass")
		cylinder(end, Vector3(0.44, 1.05, 0.235), 0.025, 0.32, "brass")
		lettering(end, "07", Vector3(0, 2.69, 0.12), 72, "d4c092", 0.003)
		lettering(end, "下一节车厢", Vector3(0, 2.45, 0.13), 28, "b9ab8c", 0.0018)
		hotspot("door_front" if front else "door_back", "穿过车门", "门后的铁轨声，似乎有些不同。", Vector3(0, 1.2, 0.28), Vector3(1.18, 2.25, 0.24), end)
		cylinder(end, Vector3(-0.99, 2.46, 0.14), 0.1, 0.14, "emergency").rotation.x = PI / 2
		var red := OmniLight3D.new()
		red.position = end.position + Vector3(-0.98, 2.42, 0.3 if front else -0.3)
		red.light_color = Color("ff4932")
		red.light_energy = 2.4
		red.omni_range = 4.2
		car.add_child(red)
		red_lights.append(red)
	# Radio cabinet at the front end, clear of the exit door.
	box(car, Vector3(1.36, 1.57, -12.9), Vector3(0.7, 0.86, 0.3), "dark_wood", 0.025)
	box(car, Vector3(1.36, 1.57, -12.722), Vector3(0.62, 0.78, 0.055), "steel", 0.018)
	box(car, Vector3(1.36, 1.77, -12.681), Vector3(0.45, 0.18, 0.02), "lamp", 0.008)
	lettering(car, "FM   7 1 . 7", Vector3(1.36, 1.77, -12.66), 30, "29302a", 0.0013)
	for x in [1.17, 1.55]:
		cylinder(car, Vector3(x, 1.42, -12.64), 0.056, 0.07, "brass").rotation.x = PI / 2
	for j in range(5):
		box(car, Vector3(1.36, 1.28 + j * 0.025, -12.671), Vector3(0.3, 0.009, 0.01), "black")
	cabinet_door = Node3D.new()
	cabinet_door.position = Vector3(1.0, 1.57, -12.64)
	car.add_child(cabinet_door)
	box(cabinet_door, Vector3(0.36, 0, 0), Vector3(0.7, 0.86, 0.065), "walnut", 0.023)
	box(cabinet_door, Vector3(0.36, 0, 0.039), Vector3(0.44, 0.14, 0.012), "brass", 0.007)
	lettering(cabinet_door, "广播控制", Vector3(0.36, 0, 0.051), 34, "28352f", 0.00165)
	hotspot("radio", "广播控制柜", "黄铜锁孔里积着薄薄的灰。", Vector3(1.36, 1.57, -12.55), Vector3(0.79, 0.9, 0.21))
	# Printed railway diagram with three physically readable station names.
	box(car, Vector3(-1.37, 1.72, -12.97), Vector3(0.98, 0.74, 0.04), "brass", 0.014)
	box(car, Vector3(-1.37, 1.72, -12.94), Vector3(0.91, 0.67, 0.022), "paper")
	lettering(car, "北 境 铁 路", Vector3(-1.37, 1.95, -12.918), 38, "35494a", 0.0016)
	lettering(car, "雾港  ─  北岭  ─  白桦", Vector3(-1.37, 1.72, -12.918), 30, "35494a", 0.00155)
	lettering(car, "WINTER SERVICE · 1987", Vector3(-1.37, 1.49, -12.918), 22, "6b7165", 0.0014)
	hotspot("route", "旧线路图", "最后一站的名字被划过，又重新写上。", Vector3(-1.37, 1.73, -12.85), Vector3(1.02, 0.81, 0.12))
	# Stationary clock above the rear door.
	var clock := cylinder(car, Vector3(1.32, 2.16, 2.98), 0.25, 0.06, "brass")
	clock.rotation.x = PI / 2
	var face := cylinder(car, Vector3(1.32, 2.16, 2.938), 0.224, 0.012, "paper")
	face.rotation.x = PI / 2
	for i in range(12):
		var angle := float(i) * TAU / 12
		var tick := box(car, Vector3(1.32 + sin(angle) * 0.182, 2.16 + cos(angle) * 0.182, 2.925), Vector3(0.012, 0.035, 0.005), "ink")
		tick.rotation.z = -angle
	var minute := box(car, Vector3(1.32 + 0.068, 2.16 - 0.015, 2.912), Vector3(0.014, 0.158, 0.008), "ink")
	minute.rotation.z = -1.78
	var hour := box(car, Vector3(1.32 - 0.025, 2.16 + 0.045, 2.9), Vector3(0.018, 0.106, 0.009), "ink")
	hour.rotation.z = 0.52

func _make_details() -> void:
	# Seat 07 photograph: a framed print lying on the table.
	var photo := Node3D.new()
	photo.position = Vector3(-1.4, 0.834, -9.72)
	photo.rotation.y = -0.22
	car.add_child(photo)
	box(photo, Vector3.ZERO, Vector3(0.31, 0.008, 0.23), "paper")
	box(photo, Vector3(0, 0.005, -0.016), Vector3(0.27, 0.003, 0.16), "ink")
	for i in range(4):
		box(photo, Vector3(-0.09 + i * 0.06, 0.008, -0.016), Vector3(0.007, 0.002, 0.13), "paper")
	lettering(photo, "1987 · 07", Vector3(0, 0.009, 0.09), 24, "364243", 0.0007).rotation.x = -PI / 2
	hotspot("photo", "07席 · 一张旧照片", "照片背后似乎写着字。", photo.position + Vector3(0, 0.05, 0), Vector3(0.42, 0.12, 0.32))
	# A postcard on the opposite table.
	box(car, Vector3(1.17, 0.84, -3.2), Vector3(0.32, 0.008, 0.22), "paper")
	lettering(car, "致：最后的乘客", Vector3(1.17, 0.849, -3.2), 26, "35494a", 0.0009).rotation.x = -PI / 2
	hotspot("postcard", "没有寄出的明信片", "纸角压在一只凉透的茶杯旁。", Vector3(1.17, 0.89, -3.2), Vector3(0.45, 0.15, 0.36))
	# A covered maintenance niche between the two middle windows.
	box(modern, Vector3(-1.987, 1.79, -4.8), Vector3(0.038, 0.7, 0.33), "walnut", 0.01)
	box(abandoned, Vector3(-2.014, 1.79, -4.8), Vector3(0.055, 0.7, 0.33), "black")
	for z in [-5.0, -4.6]:
		var splinter := box(abandoned, Vector3(-1.97, 1.74, z), Vector3(0.04, 0.81, 0.05), "walnut", 0.009)
		splinter.rotation.x = 0.15
	key_prop = Node3D.new()
	key_prop.position = Vector3(-1.86, 2.52, -4.8)
	abandoned.add_child(key_prop)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.038
	torus.outer_radius = 0.054
	ring.mesh = torus
	ring.material_override = materials.brass
	ring.rotation.z = PI / 2
	key_prop.add_child(ring)
	box(key_prop, Vector3(0, -0.1, 0), Vector3(0.019, 0.17, 0.016), "brass", 0.004)
	box(key_prop, Vector3(0, -0.17, 0.027), Vector3(0.021, 0.038, 0.065), "brass", 0.003)
	hotspot("key", "夹层里的黄铜钥匙", "维修门上方腐朽的横梁里，有一点金色。", Vector3(-1.78, 2.43, -4.8), Vector3(0.26, 0.25, 0.42))
	var glint := OmniLight3D.new()
	glint.position = Vector3(-1.68, 2.43, -4.8)
	glint.light_color = Color("c1a573")
	glint.light_energy = 0.6
	glint.omni_range = 0.65
	abandoned.add_child(glint)
	# Sparse snow and fallen boards in the abandoned state.
	for i in range(12):
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := 1.0 - float(i) * 1.04
		box(abandoned, Vector3(side * 1.86, 0.085, z), Vector3(0.38, 0.045, 0.65), "snow", 0.021)
	for i in range(5):
		var plank := box(abandoned, Vector3(-0.68 + i * 0.3, 0.09, -5.2 + i * 0.3), Vector3(0.13, 0.035, 0.73), "walnut", 0.01)
		plank.rotation.y = i * 0.76
	# Seat tags at the beginning of the aisle help navigation.
	lettering(car, "北 境 夜 行", Vector3(0, 2.89, -12.89), 32, "bdaa83", 0.0021)

func _make_temporal_device(parent: Node, id: String, pos: Vector3, caption: String) -> void:
	var object := TEMPORAL.new()
	object.name = "TemporalObject_" + id
	object.object_id = id
	object.era_states.assign({"anchor_1": ["关闭", "锁死", "腐朽"], "anchor_2": ["增压", "关闭", "锈死"], "anchor_3": ["未调谐", "17.7", "77.1"]}[id])
	parent.add_child(object)
	object.position = pos
	temporal_objects[id] = object
	var correct_location := "maintenance" if id == "anchor_2" else "carriage"
	hotspot(id, caption, "靠近按 E 查看操作说明。", pos + Vector3(0, 0.28, 0), Vector3(0.42, 0.6, 0.42), parent)

func _hidden_room(name_key: String, origin: Vector3, size: Vector3, mat: String) -> Node3D:
	var room := Node3D.new()
	room.name = name_key
	room.position = origin
	add_child(room)
	box(room, Vector3(0, -0.12, 0), Vector3(size.x, 0.25, size.z), mat, 0, true)
	box(room, Vector3(0, size.y, 0), Vector3(size.x, 0.15, size.z), "dark_wood")
	for side in [-1, 1]:
		box(room, Vector3(side * (size.x / 2 - 0.1), size.y / 2, 0), Vector3(0.18, size.y, size.z), mat, 0, true)
		box(room, Vector3(0, size.y / 2, side * (size.z / 2 - 0.1)), Vector3(size.x, size.y, 0.18), mat, 0, true)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, size.y - 0.3, 0)
	lamp.light_color = Color("e2b46e")
	lamp.light_energy = 1.6
	lamp.omni_range = 6.0
	room.add_child(lamp)
	hidden_lights.append(lamp)
	cylinder(room, Vector3(0, size.y - 0.15, 0), 0.2, 0.12, "lamp", 0.13)
	return room

func _service_clock(parent: Node, id: String, z: float) -> void:
	box(parent, Vector3(1.1, 1.65, z), Vector3(0.54, 0.72, 0.06), "brass", 0.03)
	lettering(parent, "23:17\n检修钟", Vector3(1.1, 1.67, z + 0.05), 25, "182f30", 0.0015)
	hotspot(id, "选择年代 · 检修钟", "按 E 选择年代；切换后留在原位。", Vector3(1.1, 1.65, z + 0.15), Vector3(0.65, 0.82, 0.3), parent)

func _paper_prop(parent: Node, id: String, title: String, pos: Vector3, hint: String, on_table: bool = false) -> Node3D:
	var prop := Node3D.new()
	prop.position = pos
	parent.add_child(prop)
	if not on_table:
		box(prop, Vector3(0, -0.32, 0), Vector3(1.2, 0.6, 0.7), "dark_wood", 0.025)
	box(prop, Vector3.ZERO, Vector3(0.3, 0.006, 0.2) if on_table else Vector3(0.9, 0.015, 0.56), "paper", 0.005)
	lettering(prop, title, Vector3(0, 0.005 if on_table else 0.02, 0), 24, "35494a", 0.00065 if on_table else 0.001).rotation.x = -PI / 2
	hotspot(id, title, hint, pos + Vector3(0, 0.065 if on_table else 0.13, 0), Vector3(0.42, 0.14, 0.3) if on_table else Vector3(1.1, 0.3, 0.7), parent)
	return prop

func _make_hidden_spaces() -> void:
	# Remote rooms are connected by inspectable thresholds. They cannot leak
	# through carriage windows, and each has a clock plus an unconditional exit.
	maintenance = _hidden_room("MaintenanceLayer", Vector3(120, 0, 0), Vector3(5.4, 2.7, 6.2), "steel")
	roof_space = _hidden_room("RoofInspection", Vector3(140, 0, 0), Vector3(5.4, 2.8, 5.2), "steel")
	memory_space = _hidden_room("MemorySpace", Vector3(160, 0, 0), Vector3(4.6, 2.7, 5.6), "walnut")
	for z in [-2.0, -0.7, 0.6, 1.9]:
		var pipe := cylinder(maintenance, Vector3(-2.32, 2.0, z), 0.055, 1.05, "brass")
		pipe.rotation.x = PI / 2
		box(maintenance, Vector3(-2.28, 1.55, z), Vector3(0.05, 0.4, 0.12), "red", 0.01)
	for room: Node3D in [maintenance, roof_space, memory_space]:
		box(room, Vector3(0, 1.1, 2.45), Vector3(0.95, 2.0, 0.08), "green", 0.02)
		lettering(room, "返回", Vector3(0, 1.55, 2.38), 30, "d9c99d", 0.0015).rotation.y = PI
	hotspot("maintenance_exit", "返回主车厢", "无论机械处于什么状态，都能沿原路返回。", Vector3(0, 1.1, 2.35), Vector3(1.1, 2.1, 0.3), maintenance)
	hotspot("roof_exit", "返回维修夹层", "检修梯还在身后。", Vector3(0, 1.1, 2.12), Vector3(1.1, 2.1, 0.3), roof_space)
	hotspot("memory_exit", "返回主车厢", "门外的广播正在等待。", Vector3(0, 1.1, 2.35), Vector3(1.1, 2.1, 0.3), memory_space)
	_service_clock(maintenance, "service_clock", 2.8)
	_service_clock(roof_space, "roof_clock", 2.35)
	_service_clock(memory_space, "memory_clock", 2.5)
	_make_temporal_device(car, "anchor_1", Vector3(-0.98, 0.83, -9.55), "07 席连杆")
	_make_temporal_device(maintenance, "anchor_2", Vector3(-1.4, 0.83, -0.95), "泄压连杆")
	_make_temporal_device(car, "anchor_3", Vector3(0.8, 1.0, -12.35), "广播调谐")
	# Give the remaining devices a floor stand and a wall-mounted shelf.
	cylinder(maintenance, Vector3(-1.4, 0.44, -0.95), 0.045, 0.77, "steel")
	cylinder(maintenance, Vector3(-1.4, 0.07, -0.95), 0.18, 0.05, "dark_wood")
	box(car, Vector3(0.8, 0.97, -12.6), Vector3(0.34, 0.06, 0.8), "walnut", 0.015)
	box(car, Vector3(0.8, 0.83, -12.97), Vector3(0.16, 0.3, 0.06), "brass", 0.01)
	latch_lever = box(car, Vector3(-0.98, 1.28, -9.55), Vector3(0.08, 0.4, 0.07), "steel", 0.015)
	valve_wheel = Node3D.new()
	valve_wheel.position = Vector3(-1.7, 1.35, 0.9)
	maintenance.add_child(valve_wheel)
	for angle in range(4):
		var spoke := box(valve_wheel, Vector3.ZERO, Vector3(0.52, 0.04, 0.04), "red", 0.01)
		spoke.rotation.z = angle * PI / 4
	orb(valve_wheel, Vector3.ZERO, 0.09, "brass")
	hotspot("pressure_valve", "红色泄压阀", "停电时转动一次，即可打开未来的检修口。", Vector3(-1.7, 1.35, 0.9), Vector3(0.65, 0.65, 0.4), maintenance)
	box(maintenance, Vector3(0, 1.25, -2.8), Vector3(1.2, 2.2, 0.1), "black", 0.03)
	lettering(maintenance, "车顶检修舱\n需保持泄压", Vector3(0, 1.6, -2.71), 28, "d9c99d", 0.0015)
	hatch_leaf = box(maintenance, Vector3(0, 1.1, -2.65), Vector3(1.1, 2.0, 0.06), "green", 0.02)
	hotspot("roof_hatch", "车顶检修口", "先在停电时刻转动红色泄压阀，再选择多年以后进入。", Vector3(0, 1.15, -2.52), Vector3(1.2, 2.1, 0.24), maintenance)
	_paper_prop(maintenance, "ticket_punch", "遗失的检票钳", Vector3(-1.45, 0.72, -2.0), "钳口排列着 △、○、× 三种印模。")
	_paper_prop(maintenance, "service_notes", "维修便笺", Vector3(1.4, 0.72, 1.0), "广播所需的三件物品，以及它们的位置。")
	_paper_prop(maintenance, "truth_log_1", "事故记录一", Vector3(1.4, 0.72, -0.9), "被禁止发出的警报。")
	lettering(maintenance, "○ 1", Vector3(-2.34, 1.55, -0.4), 48, "d9c99d", 0.002).rotation.y = PI / 2
	hotspot("wall_marks", "油漆下的符号", "只有应急灯能照出符号。", Vector3(-2.25, 1.55, -0.4), Vector3(0.2, 0.65, 0.65), maintenance)
	_paper_prop(roof_space, "relay", "车顶继电器", Vector3(-1.4, 0.72, 0.25), "底部有一封给检修员的纸条。")
	_paper_prop(roof_space, "truth_log_2", "事故记录二", Vector3(1.4, 0.72, -0.9), "黑匣子的最后七秒。")
	lettering(roof_space, "× 7", Vector3(0, 1.6, -2.38), 50, "c9bb98", 0.002)
	hotspot("roof_marks", "锈蚀铭牌", "防锈漆下面藏着另一行刻痕。", Vector3(0, 1.6, -2.23), Vector3(0.95, 0.7, 0.25), roof_space)
	for z in [-1.4, -0.4, 0.6, 1.6]:
		box(roof_space, Vector3(0, 2.0, z), Vector3(5.1, 0.055, 0.065), "brass")
		box(roof_space, Vector3(-2.3, 1.7, z), Vector3(0.02, 1.0, 0.55), "glass")
	_paper_prop(memory_space, "badge", "乘务员徽章", Vector3(0, 0.72, -0.65), "下一位乘客是谁？")
	_paper_prop(memory_space, "truth_log_3", "事故记录三", Vector3(-1.3, 0.72, 0.6), "整列车早已失踪。")
	lettering(memory_space, "所有人都在等你。", Vector3(0, 1.9, -2.57), 42, "d6c299", 0.0018)
	lettering(memory_space, "不要相信下一站。", Vector3(0, 1.5, -2.56), 27, "859b96", 0.0013)
	for i in range(7):
		box(memory_space, Vector3(2.0, 1.3, -1.9 + i * 0.55), Vector3(0.02, 0.5, 0.3), "paper", 0.01)
	# Both thresholds have a visible frame aligned to their interaction shapes.
	box(car, Vector3(-1.98, 1.7, -4.8), Vector3(0.09, 1.2, 0.66), "brass", 0.02)
	repair_leaf = box(car, Vector3(-1.91, 1.7, -4.8), Vector3(0.04, 1.08, 0.53), "walnut", 0.02)
	hotspot("maintenance_entry", "维修夹层入口", "座位 07 的连杆与这扇门相连。", Vector3(-1.85, 1.7, -4.8), Vector3(0.28, 1.1, 0.58))
	memory_portal = box(car, Vector3(1.97, 1.65, -8.0), Vector3(0.08, 1.7, 0.62), "black", 0.025)
	lettering(car, "08\n遗失物", Vector3(1.9, 1.65, -8.0), 27, "d9c99d", 0.0015).rotation.y = -PI / 2
	hotspot("memory_entry", "08 席后的记忆空间", "停电时，遗失物的门会出现。", Vector3(1.84, 1.65, -8.0), Vector3(0.28, 1.7, 0.6))
	foreign_prop = _paper_prop(car, "foreign_ticket", "不属于你的车票", Vector3(1.17, 0.834, -6.52), "上面也写着 07 席。", true)
	check_prop = _paper_prop(car, "check_record", "07 席检查记录", Vector3(-1.26, 0.834, -9.37), "第七次：身份可以转交。", true)
	conductor_figure = _make_conductor(car, Vector3(0, 0, -11.8))
	hotspot("conductor", "失踪乘务员", "帽檐下没有脸。可以出示车票或回答他。", Vector3(0, 1.05, -11.5), Vector3(0.75, 1.8, 0.55))
	_make_window_reflection()

func _make_window_reflection() -> void:
	# A reflection belongs to the glass plane. Flattening a rotated 3D figure
	# leaves its sign and limbs projecting into the cabin and below the sill.
	var reflection := MeshInstance3D.new()
	reflection.name = "WindowReflection"
	var pane := QuadMesh.new()
	pane.size = Vector2(0.68, 1.18)
	reflection.mesh = pane
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://shaders/window_reflection.gdshader")
	reflection.material_override = surface
	reflection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The glass's inner face is x=2.016; keep the entire silhouette between
	# its frame and sill, with a small offset to avoid z-fighting.
	reflection.position = Vector3(2.008, 1.72, -5.98)
	reflection.rotation.y = -PI / 2
	car.add_child(reflection)
	reflection_figure = reflection

func _make_conductor(parent: Node, pos: Vector3) -> Node3D:
	var figure := Node3D.new()
	figure.position = pos
	parent.add_child(figure)
	cylinder(figure, Vector3(0, 0.8, 0), 0.25, 1.15, "black", 0.19)
	orb(figure, Vector3(0, 1.55, 0), 0.15, "black")
	cylinder(figure, Vector3(0, 1.72, 0), 0.22, 0.06, "black")
	box(figure, Vector3(0, 1.05, 0.25), Vector3(0.48, 0.21, 0.02), "paper", 0.01)
	lettering(figure, "查票", Vector3(0, 1.05, 0.28), 28, "35494a", 0.0012)
	return figure

func set_temporal_state(flags: Dictionary) -> void:
	for index in range(1, 4):
		var id := "anchor_%d" % index
		var object: TemporalObject = temporal_objects[id]
		var local := ""
		if index == 1 and era == 0: local = "开启" if flags.get("latch_open", false) else "关闭"
		if index == 2 and era == 1: local = "泄压" if flags.get("valve_vented", false) else "关闭"
		if index == 3 and era == 0: local = flags.get("frequency", "")
		object.configure_era(era, local)
		if flags.get(id + "_bound", false):
			object.bind(int(flags.get(id + "_era", 0)), flags.get(id + "_state", ""))
		else:
			object.release()
		var correct_location := active_location == ("maintenance" if index == 2 else "carriage")
		hotspots[id].active = index == 1 and flags.get("photo", false) and correct_location and not on_platform
		hotspots[id].title = ["07 席维修连杆", "检修口泄压阀", "广播控制柜"][index - 1]
		hotspots[id].hint = "已修好 · 状态会一直保留" if object.is_bound() else ["出发之夜：拨动连杆，打开左墙维修门", "停电时刻：转动阀门，为车顶检修口泄压", "带齐钥匙、继电器和徽章后安装"][index - 1]
	latch_lever.rotation.z = -0.75 if temporal_objects.anchor_1.state_for(era) == "开启" else 0.15
	valve_wheel.rotation.z = PI / 2 if temporal_objects.anchor_2.state_for(era) == "泄压" else 0.0
	var open_maintenance: bool = era in [1, 2] and temporal_objects.anchor_1.state_for(era) == "开启"
	repair_leaf.visible = not open_maintenance
	hatch_leaf.visible = not (era == 2 and temporal_objects.anchor_2.state_for(era) == "泄压")

func set_hidden_visibility(flags: Dictionary, location: String = "carriage") -> void:
	active_location = location
	car.visible = location == "carriage" and not on_platform
	maintenance.visible = location == "maintenance" and not on_platform
	roof_space.visible = location == "roof" and not on_platform
	memory_space.visible = location == "memory" and not on_platform
	# Reset by physical parent, then apply era / inventory restrictions. Inactive
	# rooms never leave invisible interaction areas enabled.
	for area: TrainInteractable in hotspots.values():
		area.active = (car.is_ancestor_of(area) and location == "carriage") or (maintenance.is_ancestor_of(area) and location == "maintenance") or (roof_space.is_ancestor_of(area) and location == "roof") or (memory_space.is_ancestor_of(area) and location == "memory")
		if on_platform: area.active = area.interaction_id == "ending" and not flags.get("finished", false)
	if on_platform: return
	var in_car := location == "carriage"
	hotspots.key.active = in_car and era == 2 and flags.get("photo", false) and not flags.get("key", false)
	hotspots.postcard.active = in_car and era != 2
	hotspots.maintenance_entry.active = in_car and flags.get("photo", false)
	hotspots.memory_entry.active = in_car and era == 1 and flags.get("memory_unlocked", false)
	memory_portal.visible = flags.get("memory_unlocked", false) and era == 1
	hotspots.memory_entry.hint = "已解锁 · 按 E 进入，寻找乘务员徽章。" if era == 1 else "这扇门只存在于停电时刻。"
	hotspots.relay.active = location == "roof" and era == 2 and not flags.get("relay", false)
	hotspots.badge.active = location == "memory" and not flags.get("badge", false)
	hotspots.ticket_punch.active = location == "maintenance" and not flags.get("ticket_punch", false)
	# Optional records are deliberately distinct from mandatory service clues.
	hotspots.truth_log_1.active = location == "maintenance" and era == 2
	hotspots.truth_log_2.active = location == "roof" and era == 2
	hotspots.truth_log_3.active = location == "memory" and era == 2
	foreign_prop.visible = flags.get("conductor_event", 0) >= 2
	check_prop.visible = flags.get("conductor_event", 0) >= 3
	hotspots.foreign_ticket.active = in_car and foreign_prop.visible
	hotspots.check_record.active = in_car and check_prop.visible
	set_temporal_state(flags)

func set_location(value: String, flags: Dictionary) -> void:
	active_location = value
	last_flags = flags.duplicate()
	set_hidden_visibility(flags, value)
	set_anomaly_level(int(flags.get("anomaly_level", 0)))

func set_anomaly_level(level: int) -> void:
	var in_car := active_location == "carriage" and not on_platform
	conductor_figure.visible = in_car and (level >= 3 or last_flags.get("conductor_event", 0) >= 5)
	hotspots.conductor.active = conductor_figure.visible and not last_flags.get("finished", false)
	reflection_figure.visible = in_car and level >= 1
	for lamp in hidden_lights: lamp.light_energy = (0.9 if level >= 3 else 1.7) * (0.8 if era == 1 else 1.0)
	for i in range(anomaly_seats.size()):
		var seat: Node3D = anomaly_seats[i]
		var original_x: float = seat.get_meta("original_x")
		# Move inward on either side; right-hand seats must not enter the wall.
		seat.position.x = original_x - (signf(original_x) * 0.12 if level >= 2 and i % 3 == 0 else 0.0)
	if level >= 3:
		materials.lamp.albedo_color = Color("a4785d")
	else:
		materials.lamp.albedo_color = Color("ffe0a0") if era == 0 else Color("645d4c")

func _make_landscape() -> void:
	box(self, Vector3(0, -0.66, -10), Vector3(160, 0.3, 200), "land")
	for side in [-1.0, 1.0]:
		for i in range(13):
			var x: float = side * (24.0 + sin(i * 2.0) * 5)
			var height := 15.0 + sin(i * 1.7) * 6
			var peak := cylinder(self, Vector3(x, height * 0.5 - 1, -90 + i * 15), 16.0, height, "mountain", 0.0)
			peak.mesh = peak.mesh.duplicate()
			peak.mesh.radial_segments = 5
		for i in range(23):
			var tree := Node3D.new()
			tree.position = Vector3(side * (6.5 + fmod(i * 3.77, 14.0)), -0.5, -65 + i * 4.4)
			add_child(tree)
			var height := 3.0 + fmod(i * 1.7, 4.5)
			cylinder(tree, Vector3(0, height * 0.35, 0), 0.12, height * 0.7, "dark_wood")
			for level in range(3):
				var cone := cylinder(tree, Vector3(0, height * (0.36 + level * 0.22), 0), height * (0.25 - level * 0.055), height * 0.48, "pine", 0.0)
				cone.mesh = cone.mesh.duplicate()
				cone.mesh.radial_segments = 7
			trees.append(tree)
		_make_snow(Vector3(side * 8, 4, -5), Vector3(5, 4, 23), 850)
	var moon_mat := material("d6e8f2")
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materials["moon"] = moon_mat
	orb(self, Vector3(-42, 35, -85), 3.0, "moon")

func _make_snow(pos: Vector3, extent: Vector3, amount: int, parent: Node = null) -> void:
	var flakes := GPUParticles3D.new()
	flakes.position = pos
	flakes.amount = amount
	flakes.lifetime = 9
	flakes.preprocess = 5
	flakes.visibility_aabb = AABB(-extent * 2, extent * 4)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extent
	process.direction = Vector3(0.1, -0.5, 0.8)
	process.spread = 18
	process.initial_velocity_min = 1.5
	process.initial_velocity_max = 3.1
	process.gravity = Vector3(0.03, -0.15, 0.15)
	process.scale_min = 0.45
	process.scale_max = 1.4
	flakes.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.052, 0.052)
	var snow_mat := StandardMaterial3D.new()
	snow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	snow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	snow_mat.albedo_texture = preload("res://assets/textures/snow.png")
	snow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = snow_mat
	flakes.draw_pass_1 = quad
	(parent if parent else self).add_child(flakes)
	snow.append(flakes)

func _make_platform() -> void:
	platform = Node3D.new()
	platform.name = "BaihuaPlatform"
	platform.position.x = 80
	add_child(platform)
	box(platform, Vector3(0, -0.18, -7), Vector3(8, 0.35, 34), "snow", 0, true)
	box(platform, Vector3(0, -0.65, -7), Vector3(80, 0.25, 150), "land")
	# Tracks and sleepers disappear into the snow on both sides of the platform.
	for side in [-1.0, 1.0]:
		for track_x in [side * 4.9, side * 6.15]:
			box(platform, Vector3(track_x, -0.31, -9), Vector3(0.075, 0.1, 90), "steel")
		for i in range(62):
			box(platform, Vector3(side * 5.525, -0.36, -51 + i * 1.4), Vector3(2.2, 0.12, 0.18), "dark_wood")
		# Quiet white birch trunks give the clue a visual payoff.
		for i in range(10):
			var trunk_pos := Vector3(side * (9.0 + fmod(i * 2.7, 7)), 1.7, -30 + i * 5.0)
			var trunk := cylinder(platform, trunk_pos, 0.14, 5.6 + sin(i) * 1.0, "snow", 0.075)
			trunk.rotation.z = sin(i * 3.0) * 0.08
			for stripe in range(8):
				var mark := cylinder(trunk, Vector3(0, -2.0 + stripe * 0.54, 0), 0.144 - stripe * 0.006, 0.05, "dark_wood")
				mark.scale.x = 0.98
			for branch in [-1.0, 1.0]:
				var limb := cylinder(platform, trunk_pos + Vector3(branch * 0.45, 1.45, 0), 0.045, 1.4, "snow", 0.015)
				limb.rotation.z = branch * -0.7
	# A narrow canopy and two weathered benches frame the waiting passenger.
	box(platform, Vector3(0, 4.45, -16.7), Vector3(7.6, 0.15, 9.8), "green", 0.015)
	box(platform, Vector3(0, 4.55, -16.7), Vector3(7.65, 0.06, 9.85), "snow", 0.02)
	for side in [-1.0, 1.0]:
		for z in [-12.2, -20.9]:
			cylinder(platform, Vector3(side * 3.3, 2.2, z), 0.062, 4.4, "steel")
		for slat in range(4):
			box(platform, Vector3(side * 2.4, 0.48, -9.8 + slat * 0.15), Vector3(1.5, 0.06, 0.12), "walnut", 0.015)
		box(platform, Vector3(side * 2.4, 0.88, -9.98), Vector3(1.5, 0.56, 0.065), "walnut", 0.025)
		for dx in [-0.53, 0.53]:
			box(platform, Vector3(side * 2.4 + dx, 0.22, -9.55), Vector3(0.045, 0.44, 0.55), "steel", 0.012)
		collision(platform, Vector3(side * 2.4, 0.56, -9.7), Vector3(1.6, 1.1, 0.85))
	for z in [-23.8, 9.8]:
		collision(platform, Vector3(0, 1, z), Vector3(8, 2, 0.2))
		box(platform, Vector3(0, 0.9, z), Vector3(7.8, 0.075, 0.065), "steel")
		for x in [-3.8, -1.9, 0.0, 1.9, 3.8]:
			cylinder(platform, Vector3(x, 0.47, z), 0.035, 0.94, "steel")
	for side in [-1.0, 1.0]:
		box(platform, Vector3(side * 3.65, 0.025, -7), Vector3(0.12, 0.04, 34), "brass")
		collision(platform, Vector3(side * 4.05, 1, -7), Vector3(0.2, 2, 35))
		for z in [2.0, -6.0, -14.0]:
			cylinder(platform, Vector3(side * 3.0, 1.8, z), 0.08, 3.6, "black")
			cylinder(platform, Vector3(side * 3.0, 3.65, z), 0.24, 0.32, "lamp")
			cylinder(platform, Vector3(side * 3.0, 3.89, z), 0.36, 0.16, "black", 0.08)
			var light := OmniLight3D.new()
			light.position = Vector3(side * 3.0, 3.45, z)
			light.light_color = Color("ffd299")
			light.light_energy = 2.3
			light.omni_range = 6
			platform.add_child(light)
	box(platform, Vector3(0, 3.4, -16), Vector3(6, 0.12, 0.3), "black")
	for x in [-2.7, 2.7]:
		box(platform, Vector3(x, 1.7, -16), Vector3(0.16, 3.4, 0.16), "black")
	box(platform, Vector3(0, 2.65, -15.97), Vector3(4.2, 1.1, 0.12), "green", 0.025)
	lettering(platform, "白  桦", Vector3(0, 2.84, -15.89), 96, "dfd5b9", 0.005)
	lettering(platform, "B A I H U A   /   T E R M I N U S", Vector3(0, 2.4, -15.89), 28, "b8c0b5", 0.0025)
	# The person waiting is a restrained silhouette, seen through the snow.
	cylinder(platform, Vector3(0, 0.8, -12), 0.34, 1.05, "black", 0.22)
	orb(platform, Vector3(0, 1.5, -12), 0.155, "black")
	for x in [-0.14, 0.14]:
		box(platform, Vector3(x, 0.2, -12), Vector3(0.16, 0.4, 0.2), "black", 0.03)
	box(platform, Vector3(0, 1.05, -11.71), Vector3(0.82, 0.32, 0.035), "paper", 0.015)
	lettering(platform, "你终于到了", Vector3(0, 1.05, -11.685), 44, "35494a", 0.0022)
	hotspot("ending", "一直等你的人", "他手中的牌子上，写着一句熟悉的话。", Vector3(0, 1.0, -11.7), Vector3(1.1, 1.9, 0.8), platform)
	_make_snow(Vector3(0, 4, -7), Vector3(7, 3.5, 22), 1000, platform)
	platform.visible = false
	hotspots.ending.active = false

func set_era(value: int, flags: Dictionary) -> void:
	era = value
	modern.visible = era != 2
	abandoned.visible = era == 2
	key_prop.visible = not flags.get("key", false)
	hotspots.key.active = era == 2 and not flags.get("key", false)
	hotspots.postcard.active = era != 2
	cabinet_door.rotation.y = -1.72 if flags.get("cabinet", false) else 0.0
	for light in warm_lights:
		light.visible = era == 0
	for light in red_lights:
		light.visible = era == 1
	for light in window_lights:
		light.light_energy = [1.1, 0.4, 1.6][era]
	materials.lamp.emission_energy_multiplier = 2.6 if era == 0 else 0.03
	materials.lamp.albedo_color = Color("ffe0a0") if era == 0 else Color("645d4c")
	env.ambient_light_energy = [0.31, 0.13, 0.29][era]
	materials.velvet.albedo_color = Color("a0a3a0") if era == 2 else Color.WHITE
	env.fog_density = 0.01 if era == 2 else 0.005
	for id in ["door_front", "door_back"]:
		hotspots[id].title = "离开列车" if flags.get("ending_pending", 0) > 0 else "选择年代 · 车厢端门"
		hotspots[id].hint = "你的终点选择即将生效。" if flags.get("ending_pending", 0) > 0 else "按 E 自行选择年代，切换后留在原位。"
	if flags.get("cabinet", false):
		hotspots.radio.title = "调谐报站广播"
		hotspots.radio.hint = "一段旅程，还缺少最后一个站名。"
	else:
		hotspots.radio.title = "广播控制柜"
		hotspots.radio.hint = "黄铜锁孔里积着薄薄的灰。"
	last_flags = flags.duplicate()
	set_hidden_visibility(flags, active_location)
	set_anomaly_level(flags.get("anomaly_level", 0))

func reveal_platform() -> void:
	on_platform = true
	car.visible = false
	platform.visible = true
	for item: TrainInteractable in hotspots.values():
		item.active = item.interaction_id == "ending"
	set_hidden_visibility({"finished": false})
	conductor_figure.visible = false
	env.ambient_light_energy = 0.45
	env.fog_density = 0.026
	materials.lamp.emission_energy_multiplier = 2.4
	materials.lamp.albedo_color = Color("ffe0a0")

func _process(delta: float) -> void:
	elapsed += delta
	var speed := 8.0 if era == 0 else (3.5 if era == 1 else 0.0)
	if on_platform:
		speed = 0
	for tree in trees:
		tree.position.z += delta * speed
		if tree.position.z > 30:
			tree.position.z -= 105
	if era == 1:
		for i in range(red_lights.size()):
			red_lights[i].light_energy = 1.5 + sin(elapsed * 1.7 + i) * 0.22
