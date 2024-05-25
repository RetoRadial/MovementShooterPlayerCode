extends CharacterBody3D

#basic movement
const SPEED = 5.0
const SPRINT_SPEED = 9.0
const JUMP_VELOCITY = 4.5
const DOUBLE_JUMP_VELOCITY = 6.0
const JUMP_FROM_SLIDE_VELOCITY = 3.5
var speed = 0.0

var health = 100


#Fancy gun rotation
@export var camera : Node3D
var camera_speed : float = 0.001
var cam_rotation_amount : float = 0.01
@export var weapon_holder : Node3D
var weapon_sway_amount : float = 0.01
var weapon_rotation_amount : float = 0.0015
var mouse_input : Vector2
var def_weapon_holder_pos : Vector3


#radical movement
var wall_running = false
var wall_normal
var has_double_jump = true
var can_wall_run = true
var currentlyWallrunning = false
var sliding = false
var slide_movement_bonus = 1.0
var initial_slide_velocity = 5.0
var can_slide = true
var register_input = true
var sprinting = false
var is_on_ground = false
var most_recent_wallrun_object = self
var most_recent_wallrun_jump


#super radical head movement
const BOB_FREQ = 1.8
const BOB_AMP = .05
var t_bob = 0.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _input(event):
	if event is InputEventMouseMotion:
		camera.rotation.x -= event.relative.y * camera_speed
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
		self.rotation.y -= event.relative.x * camera_speed
		mouse_input = event.relative

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	def_weapon_holder_pos = weapon_holder.position

func _physics_process(delta):
	speed = SPRINT_SPEED
	
	
	if not is_on_floor():
		velocity.y -= gravity * delta
			

	if Input.is_action_just_pressed("Jump"):
		if sliding:
			velocity.y = JUMP_FROM_SLIDE_VELOCITY
			$HolderAnim.play("jump")
			$Jump.play()
		elif is_on_floor() or is_on_wall() and !can_wall_run:
			velocity.y = JUMP_VELOCITY
			$HolderAnim.play("jump")
			$Jump.play()
			$WallrunTimer.play("timer")
		elif has_double_jump and !is_on_wall():
			has_double_jump = false
			#velocity += ($CamHolder/WallrunStuff/AddVelL.global_transform.origin - $CamHolder/WallrunStuff.global_transform.origin).normalized()*50
			velocity.y = DOUBLE_JUMP_VELOCITY
			$CamHolder/CameraWallrunTilt/Camera3D.trauma = 0.4
			$DoubleJump.play()
			#$CamHolder/CameraWallrunTilt/Camera3D.add_trauma(0.3)
	
	if is_on_floor():
		if !is_on_ground:
			$FallThud.play()
			$CamHolder/CameraWallrunTilt/Camera3D.trauma = 0.4
		has_double_jump = true
		is_on_ground = true
		most_recent_wallrun_object = self
	else:
		is_on_ground = false
		
	#if Input.is_action_pressed("Sprint"):
		#speed = SPRINT_SPEED
	#else:
		#speed = SPEED

	var input_dir = Input.get_vector("Left", "Right", "Forward", "Backward")
	var direction
	if !sliding:
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	else:
		direction = (transform.basis * Vector3(0, 0, -1)).normalized()
	if !register_input:
		direction = (transform.basis * Vector3(0, 0, 0)).normalized()
	if is_on_floor():
		if sliding:
			velocity.x = direction.x * initial_slide_velocity * 1.5
			velocity.z = direction.z * initial_slide_velocity * 1.5
		elif direction:
			velocity.x = lerp(velocity.x, direction.x*speed, delta*10.0)
			velocity.z = lerp(velocity.z, direction.z*speed, delta*10.0)
		elif register_input:
			velocity.x = lerp(velocity.x, 0.0, delta*10)
			velocity.z = lerp(velocity.z, 0.0, delta*10)
	else:
		if !direction:
			velocity.x = lerp(velocity.x, direction.x*speed, delta*0.1)
			velocity.z = lerp(velocity.z, direction.z*speed, delta*0.1)
		elif can_wall_run and direction:
			velocity.x = lerp(velocity.x, direction.x*speed*1.2, delta*2.0)
			velocity.z = lerp(velocity.z, direction.z*speed*1.2, delta*2.0)
		elif can_wall_run:
			velocity.x = lerp(velocity.x, direction.x*speed, delta*2.0)
			velocity.z = lerp(velocity.z, direction.z*speed, delta*2.0)

	wall_run_logic(direction, delta)
	slide_logic(velocity, direction, velocity.length(), delta)
	#determineSprintStuff(direction)
	move_and_slide()
	fancyMovements(input_dir.x, velocity.length(), delta)
	footstep_logic(direction, delta)
	set_speedlines()

func fancyMovements(input_x, vel : float, delta):
	camera.rotation.z = lerp(camera.rotation.z, -input_x * cam_rotation_amount, 10 * delta)
	weapon_holder.rotation.z = lerp(weapon_holder.rotation.z, -input_x * weapon_rotation_amount * 10, 10*delta)
	mouse_input = lerp(mouse_input, Vector2.ZERO, 10 * delta)
	weapon_holder.rotation.x = lerp(weapon_holder.rotation.x, mouse_input.y * weapon_rotation_amount, 10 * delta)
	weapon_holder.rotation.y = lerp(weapon_holder.rotation.y, mouse_input.x * weapon_rotation_amount, 10 * delta)
	weapon_holder.position.y = lerp(weapon_holder.position.y, velocity.y / -50, 2 * delta)
	weapon_holder.position.y = clamp(weapon_holder.position.y, -0.03, 0.03)
	if vel > 1.0 and is_on_floor() and !sliding:
		var bob_amount : float = 0.01
		var bob_freq : float = 0.015
		weapon_holder.position.y = lerp(weapon_holder.position.y, def_weapon_holder_pos.y + sin(Time.get_ticks_msec() * bob_freq) * bob_amount, 10 * delta)
		weapon_holder.position.x = lerp(weapon_holder.position.x, def_weapon_holder_pos.x + sin(Time.get_ticks_msec() * bob_freq * 0.5) * bob_amount, 10 * delta)
	else:
		weapon_holder.position.y = lerp(weapon_holder.position.y, def_weapon_holder_pos.y, 10 * delta)
		weapon_holder.position.x = lerp(weapon_holder.position.x, def_weapon_holder_pos.x, 10 * delta)
	

func wall_run_logic(direction, delta):
	print(most_recent_wallrun_object)
	if can_wall_run and !$WallrunTimer.is_playing(): #could remove forward check  and Input.is_action_pressed("Forward")
		if $CamHolder/WallrunStuff/CheckL.is_colliding() or $CamHolder/WallrunStuff/CheckR.is_colliding():
			if is_on_wall() and !is_on_floor():
				if $CamHolder/WallrunStuff/CheckL.get_collider() == most_recent_wallrun_object or $CamHolder/WallrunStuff/CheckR.get_collider() == most_recent_wallrun_object:
					return
				wall_normal = get_slide_collision(0)
				if Input.is_action_just_pressed("Jump"):
					if $CamHolder/WallrunStuff/CheckL.is_colliding():
						most_recent_wallrun_jump = global_position.y
						most_recent_wallrun_object = $CamHolder/WallrunStuff/CheckL.get_collider()
						has_double_jump = true
						velocity.y = JUMP_VELOCITY #prevent infinite jump, make into jump function eventually
						$HolderAnim.play("jump")
						$Jump.play()
						#has_double_jump = true
						can_wall_run = false
						velocity += ($CamHolder/WallrunStuff/AddVelL.global_transform.origin - $CamHolder/WallrunStuff.global_transform.origin).normalized()*8
						gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
						await get_tree().create_timer(0.2).timeout
						can_wall_run = true
					elif $CamHolder/WallrunStuff/CheckR.is_colliding():
						most_recent_wallrun_jump = global_position.y
						most_recent_wallrun_object = $CamHolder/WallrunStuff/CheckR.get_collider()
						has_double_jump = true
						velocity.y = JUMP_VELOCITY
						$HolderAnim.play("jump")
						$Jump.play()
						#has_double_jump = true
						can_wall_run = false
						velocity += ($CamHolder/WallrunStuff/AddVelR.global_transform.origin - $CamHolder/WallrunStuff.global_transform.origin).normalized()*8
						gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
						await get_tree().create_timer(0.2).timeout
						can_wall_run = true
				else:
					if $CamHolder/WallrunStuff/CheckL.is_colliding():
						$CamHolder/CameraWallrunTilt.rotation.z = lerp($CamHolder/CameraWallrunTilt.rotation.z, -PI/18, 10*delta)
					elif $CamHolder/WallrunStuff/CheckR.is_colliding():
						$CamHolder/CameraWallrunTilt.rotation.z = lerp($CamHolder/CameraWallrunTilt.rotation.z, PI/18, 10*delta)
					else:
						$CamHolder/CameraWallrunTilt.rotation.z = lerp($CamHolder/CameraWallrunTilt.rotation.z, 0.0, 10*delta)
					gravity = 10.01
					#velocity.y = lerp(0.0, -20.0, 5 * delta)
					velocity.y = -1
					print(velocity.y)
					#velocity.y = clamp(velocity.y, -3.0, 999)
					#velocity.x = 0
					velocity += -wall_normal.get_normal()
					if !$Wallrun.playing:
						$Wallrun.playing = true
					#has_double_jump = true
					#direction = -wall_normal.get_normal() * 100.0
			else:
				gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
				$CamHolder/CameraWallrunTilt.rotation.z = lerp($CamHolder/CameraWallrunTilt.rotation.z, 0.0, 10*delta)
				$Wallrun.playing = false
		else:
			gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
			$CamHolder/CameraWallrunTilt.rotation.z = lerp($CamHolder/CameraWallrunTilt.rotation.z, 0.0, 10*delta)
			$Wallrun.playing = false
	else:
		gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
		$CamHolder/CameraWallrunTilt.rotation.z = lerp($CamHolder/CameraWallrunTilt.rotation.z, 0.0, 10*delta)
		$Wallrun.playing = false


	
func slide_logic(velocity, direction, frontSpeed, delta):
	if !sliding and Input.is_action_pressed("Slide") and is_on_floor() and frontSpeed > 1.0 and can_slide:
		initial_slide_velocity = frontSpeed
		initial_slide_velocity = clamp(initial_slide_velocity, 0.0, 12.0)
		sliding = true
		$Slide.play("slide")
		await $Slide.animation_finished
		sliding = false
		can_slide = false
		await get_tree().create_timer(1.0).timeout
		can_slide = true
	if sliding and Input.is_action_just_pressed("Jump") or !is_on_floor() or !velocity:
		initial_slide_velocity *= 0
		sliding = false
		$Slide.stop()
	if sliding:
		$CamHolder.position.y =  lerp($CamHolder.position.y, 0.0, 10*delta)
		$CamHolder/CameraWallrunTilt.rotation.z = lerp($CamHolder/CameraWallrunTilt.rotation.z, PI/12, 5*delta)
		$CamHolder/CameraWallrunTilt/Camera3D.trauma = lerp($CamHolder/CameraWallrunTilt/Camera3D.trauma, 0.5, 10*delta)
		#gravity = 20
		
	else:
		gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
		$CamHolder.position.y =  lerp($CamHolder.position.y, 0.5, 10*delta)
		$CamHolder/CameraWallrunTilt.rotation.z = lerp($CamHolder/CameraWallrunTilt.rotation.z, 0.0, 5*delta)
		

func applyPowershotRecoil():
	can_wall_run = false
	register_input = false
	velocity = ($CamHolder/PowershotPoint.global_transform.origin - $CamHolder.global_transform.origin).normalized()*15
	await get_tree().create_timer(0.5).timeout
	register_input = true
	can_wall_run = true

func determineSprintStuff(direction):
	speed = SPEED if !sprinting else SPRINT_SPEED
	if Input.is_action_just_pressed("Sprint"):
		sprinting = true
	if is_on_floor() and !sliding and !direction:
		sprinting = false
	if $CamHolder/ArmsHolder/HolderForAnims/Node3D.playingAnimation and !sliding and is_on_floor():
		sprinting = false
	#if sprinting and is_on_floor() and !sliding and velocity.y < 1.0:
		#$HolderAnim.play("run")
	#else:
		#$HolderAnim.play("idle")

func applyShakestep():
	#$CamHolder/CameraWallrunTilt/Camera3D.add_trauma(0.3)
	pass

func footstep():
	$Footsteps/Footstep.play()

func footstep_logic(direction, delta):
	t_bob += delta * velocity.length() * float(is_on_floor())
	if direction and !sliding and is_on_floor() and velocity.length() > 1.0:
		$Footsteps.play("run")
		#$CamHolder.transform.origin = _bobbleHead(t_bob)
	else:
		$Footsteps.stop()
		#$CamHolder.transform.origin = lerp($CamHolder.transform.origin, Vector3(0, 0.5, 0), 10 * delta)

func _bobbleHead(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(t_bob * BOB_FREQ) * BOB_AMP * 0
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP * 0
	return pos + Vector3(0, 0.5, 0)

func set_speedlines():
	var opacity = float(velocity.length() > 12.0)
	print(opacity)
	$CanvasLayer/Speedlines.visible = float(velocity.length() > 12.0)
	if opacity == 1:
		#$CamHolder/CameraWallrunTilt/Camera3D.trauma = 0.3
		pass
