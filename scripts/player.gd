extends CharacterBody3D


signal health_changed(health)
signal ammo_changed(ammo)
signal death(killer, damage_dealt)
signal respawned

const SPEED = 10.0
const JUMP_VELOCITY = 10.0
const GRAVITY = 20.0

var health = 100
var weapon = 0
var damage = 50
var ammos = [INF, 10, 50]
var ammo_sizes = [INF, 10, 50]
var nickname = ""
var damage_dealt = 0

@onready var camera = $Camera3D
@onready var ray_cast = $Camera3D/RayCast3D
@onready var nickname_label = $NicknameLabel
@onready var animation_player = $AnimationPlayer
@onready var baton = $Camera3D/Baton
@onready var pistol = $Camera3D/Pistol
@onready var uzi = $Camera3D/Uzi
@onready var mesh_instance = $MeshInstance3D


func _enter_tree():
	set_multiplayer_authority(int(str(name)))

func _ready():
	# Enable the controls for the local player
	if is_multiplayer_authority():
		camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		set_process_unhandled_input(false)
		set_physics_process(false)
	
	randomize()
	set_color(Color(randf_range(0, 1), randf_range(0, 1), randf_range(0, 1)).to_html())

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * 0.005)
		camera.rotate_x(-event.relative.y * 0.005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _physics_process(delta):
	# Add the gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Handle shooting
	if Input.is_action_pressed("shoot") and weapon == 2 and \
		not animation_player.current_animation == "uzi_shoot" and \
		not animation_player.current_animation == "reload":
		if not ammos[weapon] == 0:
			shoot.rpc()
			if ray_cast.is_colliding():
				var hit_player = ray_cast.get_collider()
				hit_player.take_damage.rpc_id(hit_player.get_multiplayer_authority(), damage, nickname)
				damage_dealt += damage
	elif Input.is_action_just_pressed("shoot") and \
		not animation_player.current_animation == "shoot" and \
		not animation_player.current_animation == "reload":
		if not ammos[weapon] == 0:
			shoot.rpc()
			if ray_cast.is_colliding():
				var hit_player = ray_cast.get_collider()
				hit_player.take_damage.rpc_id(hit_player.get_multiplayer_authority(), damage, nickname)
				damage_dealt += damage
	
	# Handle reload
	if Input.is_action_just_pressed("reload") and weapon > 0 and not animation_player.current_animation == "reload":
		reload.rpc()
	
	# Handle switching weapons
	if Input.is_action_just_pressed("switch_weapons") and not animation_player.current_animation == "shoot":
		switch_weapons.rpc()

	# Get the input direction and handle the movement/deceleration
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

@rpc("call_local")
func shoot():
	animation_player.stop()
	if weapon < 2:
		animation_player.play("shoot")
	else:
		animation_player.play("uzi_shoot")
	
	if weapon > 0:
		var muzzle_flash
		if weapon == 1:
			muzzle_flash = pistol.find_child("MuzzleFlash")
		elif weapon == 2:
			muzzle_flash = uzi.find_child("MuzzleFlash")
		muzzle_flash.restart()
		muzzle_flash.emitting = true
	
	ammos[weapon] -= 1
	ammo_changed.emit(ammos[weapon])

@rpc("any_peer")
func take_damage(damage_taken, damage_from):
	health -= damage_taken
	if health <= 0:
		camera.clear_current(false)
		death.emit(damage_from, damage_dealt)
		die.rpc()
	health_changed.emit(health)

func set_nickname(user_nickname):
	nickname_label.text = user_nickname
	nickname = user_nickname

@rpc("any_peer", "call_local")
func set_color(color):
	mesh_instance.mesh.material.albedo_color = Color(color)

@rpc("call_local")
func switch_weapons():
	animation_player.stop()
	match weapon:
		0:
			weapon = 1
			baton.hide()
			pistol.show()
			ray_cast.target_position = Vector3(0, 0, -50)
			damage = 20
		1:
			weapon = 2
			pistol.hide()
			uzi.show()
			ray_cast.target_position = Vector3(0, 0, -75)
			damage = 4
		2:
			weapon = 0
			uzi.hide()
			baton.show()
			ray_cast.target_position = Vector3(0, 0, -2)
			damage = 50
	
	ammo_changed.emit(ammos[weapon])

@rpc("call_local")
func reload():
	animation_player.stop()
	animation_player.play("reload")

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "reload":
		ammos[weapon] = ammo_sizes[weapon]
		ammo_changed.emit(ammos[weapon])
	if anim_name == "death":
		if is_multiplayer_authority():
			camera.make_current()
		health = 100
		randomize()
		position = Vector3(randi_range(-12, 12), 5, randi_range(-12, 12))
		rotation = Vector3.ZERO
		respawned.emit()

@rpc("call_local")
func die():
	animation_player.stop()
	animation_player.play("death")
