extends CharacterBody3D
class_name TrainPlayer

signal footstep

var camera: Camera3D
var ray: RayCast3D
var flashlight: SpotLight3D
var enabled := false
var mouse_look_enabled := true
var look_warmup_frames := 0
var pitch := 0.0
var walk_time := 0.0
var step_distance := 0.0
var sensitivity := 0.0018

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.65
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.65
	camera.fov = 69.0
	camera.near = 0.05
	camera.far = 180.0
	add_child(camera)
	camera.make_current()
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -3.15)
	ray.collision_mask = 3
	ray.collide_with_areas = true
	camera.add_child(ray)
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color("d8e9ed")
	flashlight.light_energy = 2.0
	flashlight.spot_range = 13.0
	flashlight.spot_angle = 31.0
	flashlight.spot_angle_attenuation = 0.65
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.16, -0.17, -0.08)
	flashlight.visible = false
	camera.add_child(flashlight)

func _unhandled_input(event: InputEvent) -> void:
	if enabled and mouse_look_enabled and look_warmup_frames == 0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.25, 1.25)
		camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	look_warmup_frames = maxi(look_warmup_frames - 1, 0)
	if not enabled:
		velocity = Vector3.ZERO
		return
	var movement := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (basis * Vector3(movement.x, 0, movement.y)).normalized()
	var speed := 3.4 if Input.is_action_pressed("walk_fast") else 2.25
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 13.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 13.0)
	if not is_on_floor():
		velocity.y -= delta * 15.0
	else:
		velocity.y = -0.1
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length()
	walk_time += delta * moving * 2.7
	camera.position.y = lerpf(camera.position.y, 1.65 + sin(walk_time * 2.0) * minf(moving * 0.006, 0.014), delta * 10)
	camera.rotation.z = lerpf(camera.rotation.z, -movement.x * 0.007, delta * 5)
	if moving > 0.3 and is_on_floor():
		step_distance += delta * moving
		if step_distance > 1.32:
			step_distance = 0.0
			footstep.emit()

func target() -> TrainInteractable:
	if not ray.is_colliding():
		return null
	var object := ray.get_collider()
	if object is TrainInteractable and object.active:
		return object
	return null

func place(where: Vector3, yaw: float = 0.0) -> void:
	position = where
	rotation.y = yaw
	pitch = -0.015
	if camera:
		camera.rotation = Vector3(pitch, 0, 0)
	velocity = Vector3.ZERO
