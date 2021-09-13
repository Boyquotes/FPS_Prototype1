extends KinematicBody

# ----------------------------------
# Physics

export (float) var GRAVITY;

# Kinematic
export (int) var MAX_SPEED;
export (int) var JUMP_SPEED;
export (int) var MAX_SPRINT_SPEED;
export (float) var ACCEL;
export (float) var DEACCEL;
export (float) var SPRINT_ACCEL;
var vel = Vector3()
var dir = Vector3()
var is_sprinting : bool = false
# ----------------------------------

# ----------------------------------
# Others

const MAX_SLOPE_ANGLE = 45

var camera
var rotation_helper

# Mouse
var MOUSE_SENSITIVITY = 0.05
var mouse_scroll_value = 0
const MOUSE_SENSITIVITY_SCROLL_WHEEL = 0.08


var flashlight

var animation_manager

var globals
# ----------------------------------

# ----------------------------------
# Weapons

var curr_weap_name = "UNARMED"
var weapons = {"UNARMED":null, "KNIFE":null, "PISTOL":null, "RIFLE":null}
const WEAPON_NUMBER_TO_NAME = {0:"UNARMED", 1:"KNIFE", 2:"PISTOL", 3:"RIFLE"}
const WEAPON_NAME_TO_NUMBER = {"UNARMED":0, "KNIFE":1, "PISTOL":2, "RIFLE":3}
var changing_weapon = false
var changing_weapon_name = "UNARMED"
var reloading_weapon = false
# ----------------------------------

# ----------------------------------
# Health

export (int) var MAX_HEALTH;
var health : int = 100

# Respawn
const RESPAWN_TIME = 4
var dead_time = 0
var is_dead = false
# ----------------------------------

# ----------------------------------
# UI

var UI_status_label
# ----------------------------------

# ----------------------------------
# Audio

var simple_audio_player = preload("res://scenes/Audio/Simple_Audio_Player.tscn")
# ----------------------------------


func _ready():
	camera = $Rotation_Helper/Camera
	rotation_helper = $Rotation_Helper

	animation_manager = $Rotation_Helper/Model/Animation_Player
	animation_manager.callback_function = funcref(self, "fire_bullet")

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	weapons["KNIFE"] = $Rotation_Helper/Gun_Fire_Points/Knife_Point
	weapons["PISTOL"] = $Rotation_Helper/Gun_Fire_Points/Pistol_Point
	weapons["RIFLE"] = $Rotation_Helper/Gun_Fire_Points/Rifle_Point

	# This seems to be useless. Check "Part 2 - FPS Tutorial"
	#var gun_aim_point_pos = $Rotation_Helper/Gun_Aim_Point.global_transform.origin

	for weapon in weapons:
		var weapon_node = weapons[weapon]
		if weapon_node != null:
			weapon_node.player_node = self
			# This seems to be useless. Check "Part 2 - FPS Tutorial"
			#weapon_node.look_at(gun_aim_point_pos, Vector3(0, 1, 0))
			weapon_node.rotate_object_local(Vector3(0, 1, 0), deg2rad(180))

	curr_weap_name = "UNARMED"
	changing_weapon_name = "UNARMED"

	UI_status_label = $HUD/Panel/Gun_label
	flashlight = $Rotation_Helper/Flashlight
	
	globals = get_node("/root/Globals")
	global_transform.origin = globals.get_respawn_position()

func _physics_process(delta):

	if !is_dead:
		process_input(delta)
	#	process_view_input(delta)
		process_movement(delta)
		
#	if (grabbed_object == null):
		process_changing_weapons(delta)
		process_reloading(delta)

	process_UI(delta)
	process_respawn(delta)

func process_input(_delta):

	# ----------------------------------
	# Walking
	dir = Vector3()
	var cam_xform = camera.get_global_transform()

	var input_movement_vector = Vector2()

	if Input.is_action_pressed("movement_forward"):
		input_movement_vector.y += 1
	if Input.is_action_pressed("movement_backward"):
		input_movement_vector.y -= 1
	if Input.is_action_pressed("movement_left"):
		input_movement_vector.x -= 1
	if Input.is_action_pressed("movement_right"):
		input_movement_vector.x += 1

	input_movement_vector = input_movement_vector.normalized()

	# Basis vectors are already normalized.
	dir += -cam_xform.basis.z * input_movement_vector.y
	dir += cam_xform.basis.x * input_movement_vector.x
	# ----------------------------------

	# ----------------------------------
	# Jumping
	if is_on_floor():
		if Input.is_action_just_pressed("movement_jump"):
			vel.y = JUMP_SPEED
	# ----------------------------------
	
	# Capturing/Freeing cursor
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# ----------------------------------
	# Sprinting
	if Input.is_action_pressed("movement_sprint"):
		is_sprinting = true
	else:
		is_sprinting = false
	# ----------------------------------

	# ----------------------------------
	# Turning the flashlight on/off
	if Input.is_action_just_pressed("flashlight"):
		if flashlight.is_visible_in_tree():
			flashlight.hide()
		else:
			flashlight.show()
	# ----------------------------------
	
	# ----------------------------------
	# Changing weapons.
	var weapon_change_number = WEAPON_NAME_TO_NUMBER[curr_weap_name]

	if Input.is_key_pressed(KEY_1):
		weapon_change_number = 0
	if Input.is_key_pressed(KEY_2):
		weapon_change_number = 1
	if Input.is_key_pressed(KEY_3):
		weapon_change_number = 2
	if Input.is_key_pressed(KEY_4):
		weapon_change_number = 3

	if Input.is_action_just_pressed("shift_weapon_positive"):
		weapon_change_number += 1
	if Input.is_action_just_pressed("shift_weapon_negative"):
		weapon_change_number -= 1

	weapon_change_number = clamp(weapon_change_number, 0, WEAPON_NUMBER_TO_NAME.size() - 1)
	
	if changing_weapon == false:
		# New line of code here!
		if reloading_weapon == false:
			if WEAPON_NUMBER_TO_NAME[weapon_change_number] != curr_weap_name:
				changing_weapon_name = WEAPON_NUMBER_TO_NAME[weapon_change_number]
				changing_weapon = true
				mouse_scroll_value = weapon_change_number
	# ----------------------------------
	
	# ----------------------------------
	# Firing the weapons
	if Input.is_action_pressed("fire"):
		if reloading_weapon == false:
			if changing_weapon == false:
				var current_weapon = weapons[curr_weap_name]
				if current_weapon != null:
					if(current_weapon.is_usable()):
						if animation_manager.current_state == current_weapon.ANIM_IDLE():
							print("Shooting");
							animation_manager.set_animation(current_weapon.ANIM_USE())
					else:
						reloading_weapon = true
	# ----------------------------------
	
	# ----------------------------------
	# Reloading
	if reloading_weapon == false:
		if changing_weapon == false:
			if Input.is_action_just_pressed("reload"):
				var current_weapon = weapons[curr_weap_name]
				if current_weapon != null:
					print(current_weapon.get_class());
					if current_weapon.get_class() == "FireWeapon":
						var current_anim_state = animation_manager.current_state
						var is_reloading = false
						for weapon in weapons:
							var weapon_node = weapons[weapon]
							if weapon_node != null:
								if current_anim_state == weapon_node.ANIM_RELOAD():
									is_reloading = true
						if is_reloading == false:
							reloading_weapon = true
	# ----------------------------------


func process_movement(delta):
	dir.y = 0
	dir = dir.normalized()

	vel.y += delta * GRAVITY

	var hvel = vel
	hvel.y = 0

	var target = dir
	if is_sprinting:
		target *= MAX_SPRINT_SPEED
	else:
		target *= MAX_SPEED

	var accel
	if dir.dot(hvel) > 0:
		if is_sprinting:
			accel = SPRINT_ACCEL
		else:
			accel = ACCEL
	else:
		accel = DEACCEL

	hvel = hvel.linear_interpolate(target, accel * delta)
	vel.x = hvel.x
	vel.z = hvel.z
	vel = move_and_slide(vel, Vector3(0, 1, 0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))


func process_changing_weapons(_delta):
	if changing_weapon == true:

		var weapon_unequipped = false
		var current_weapon = weapons[curr_weap_name]

		if current_weapon == null:
			weapon_unequipped = true
		else:
			if current_weapon.is_weapon_enabled == true:
				weapon_unequipped = current_weapon.unequip_weapon()
			else:
				weapon_unequipped = true

		if weapon_unequipped == true:

			var weapon_equipped = false
			var weapon_to_equip = weapons[changing_weapon_name]

			if weapon_to_equip == null:
				weapon_equipped = true
			else:
				if weapon_to_equip.is_weapon_enabled == false:
					weapon_equipped = weapon_to_equip.equip_weapon()
				else:
					weapon_equipped = true

			if weapon_equipped == true:
				changing_weapon = false
				curr_weap_name = changing_weapon_name
				changing_weapon_name = ""


func fire_bullet():
	if changing_weapon == true:
		return

	weapons[curr_weap_name].fire_weapon()


func process_UI(_delta):
	if curr_weap_name == "UNARMED" or curr_weap_name == "KNIFE":
		UI_status_label.text = "HEALTH: " + str(health)
	else:
		var current_weapon = weapons[curr_weap_name]
		UI_status_label.text = "HEALTH: " + str(health) + \
				"\nAMMO: " + str(current_weapon.ammo_in_mag) + "/" + str(current_weapon.spare_ammo)


func process_reloading(_delta):
	if reloading_weapon == true:
		var current_weapon = weapons[curr_weap_name]
		if current_weapon != null:
			current_weapon.reload_weapon()
		reloading_weapon = false


func create_sound(sound_name, position=null):
	globals.play_sound(sound_name, false, position)


func add_health(additional_health):
	health += additional_health
	health = clamp(health, 0, MAX_HEALTH)


func add_ammo(additional_ammo):
	if (curr_weap_name != "UNARMED"):
		if (weapons[curr_weap_name].CAN_REFILL == true):
			weapons[curr_weap_name].spare_ammo += weapons[curr_weap_name].AMMO_IN_MAG * additional_ammo


func bullet_hit(damage, _bullet_hit_pos):
	health -= damage


func process_respawn(delta):

	# If we've just died
	if health <= 0 and !is_dead:
		$Body_CollisionShape.disabled = true
		$Feet_CollisionShape.disabled = true

		changing_weapon = true
		changing_weapon_name = "UNARMED"

		$HUD/Death_Screen.visible = true

		$HUD/Panel.visible = false
		$HUD/Crosshair.visible = false

		dead_time = RESPAWN_TIME
		is_dead = true

#		if grabbed_object != null:
#			grabbed_object.mode = RigidBody.MODE_RIGID
#			grabbed_object.apply_impulse(Vector3(0, 0, 0), -camera.global_transform.basis.z.normalized() * OBJECT_THROW_FORCE / 2)
#
#			grabbed_object.collision_layer = 1
#			grabbed_object.collision_mask = 1
#
#			grabbed_object = null

	if is_dead:
		dead_time -= delta

		var dead_time_pretty = str(dead_time).left(3)
		$HUD/Death_Screen/Label.text = "You died\n" + dead_time_pretty + " seconds till respawn"

		if dead_time <= 0:
			global_transform.origin = globals.get_respawn_position()

			$Body_CollisionShape.disabled = false
			$Feet_CollisionShape.disabled = false

			$HUD/Death_Screen.visible = false

			$HUD/Panel.visible = true
			$HUD/Crosshair.visible = true

			for weapon in weapons:
				var weapon_node = weapons[weapon]
				if weapon_node != null:
					weapon_node.reset_weapon()

			health = 100
#			grenade_amounts = {"Grenade":2, "Sticky Grenade":2}
#			current_grenade = "Grenade"

			is_dead = false


func _input(event):
	if is_dead:
		return
		
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY * 1))
		self.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))

		var camera_rot = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		rotation_helper.rotation_degrees = camera_rot
		
	if event is InputEventMouseButton and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN:
			if event.button_index == BUTTON_WHEEL_UP:
				mouse_scroll_value += MOUSE_SENSITIVITY_SCROLL_WHEEL
			elif event.button_index == BUTTON_WHEEL_DOWN:
				mouse_scroll_value -= MOUSE_SENSITIVITY_SCROLL_WHEEL
				
			mouse_scroll_value = clamp(mouse_scroll_value, 0, WEAPON_NUMBER_TO_NAME.size() - 1)
			
			if changing_weapon == false:
				if reloading_weapon == false:
					var round_mouse_scroll_value = int(round(mouse_scroll_value))
					if WEAPON_NUMBER_TO_NAME[round_mouse_scroll_value] != curr_weap_name:
						changing_weapon_name = WEAPON_NUMBER_TO_NAME[round_mouse_scroll_value]
						changing_weapon = true
						mouse_scroll_value = round_mouse_scroll_value
