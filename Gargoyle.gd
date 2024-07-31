extends CharacterBody3D

var CURRENT_STANCE = "Idle"
var NEXT_STANCE = "Idle"
var PREVIOUS_STANCE
var CHASE_TIME = 10.0
var CHASE_TIME_RESET = 0.0
var AGRO_TIME = 10.0
var PREY = false
var ATTACKING = false
var JUMPING = false
var JUMP_STRENGTH = 2.0
var VERTICAL_JUMP = 6.0
var GRAVITY = ProjectSettings.get_setting("physics/3d/default_gravity") * 3

@onready var BOSS_INJURY = preload("res://Enviornment/boss_injury.tscn")
@onready var ALERTED = $Alert
@onready var SLEEPY = $Idle
@onready var PLAYER
@onready var NAV = $NavigationAgent3D
@onready var SPEED = 50.0
@onready var TURN_SPEED = 0.5
@onready var MELEE_ATTACK_RANGE = 2.0
@onready var MELEE_DAMAGE = 20.0
@onready var RANGED_ATTACK_RANGE = 20.0
@onready var RANGED_DAMAGE = 50.0
@onready var HEALTH = 200.0


func _ready():
	PLAYER = get_tree().get_first_node_in_group("player")
	print(PLAYER)

func _physics_process(delta):
	PREVIOUS_STANCE = CURRENT_STANCE
	CURRENT_STANCE = NEXT_STANCE
	
	match CURRENT_STANCE:
		"Idle":
			idle()
		"Patrol":
			patrol()
		"Chase":
			chase(delta)
		"Boss Chase":
			boss_chase(delta)
		"Slash":
			slash()
		"Ranged Attack":
			ranged_attack()
		"Death":
			death()
		"Recoil":
			recoil(delta)
	#Apply gravity check only if jumping.
	if JUMPING:
		velocity.y = velocity.y - GRAVITY * delta #Gravity
	move_and_slide()
	if not is_on_floor():
		velocity.y = velocity.y - GRAVITY * delta
#		move_and_slide()
#	else:
#		move_and_slide()

func _on_gargoyle_anim_animation_finished(anim_name): #Linked to 'animation_finished' signal
	if anim_name == "Attack":
		ATTACKING = false
		print("Attempting ANIM end / Jumping!")
		jump_away()
		NEXT_STANCE = "Chase"
		print("Returning to chase after Jump.")
		
func recoil(delta):
	velocity = -(NAV.get_next_path_position() - position).normalized() * SPEED * delta
	move_and_collide(velocity)
	$Gargoyle2/GargoyleAnim.play("Recoil")
	
func take_damage(num):
	$GargoyleHurt.play()
	NEXT_STANCE = "Recoil"
	var INJURY = BOSS_INJURY.instantiate()
	INJURY.emitting = true
	var OFFSET = Vector3(0,1,0)
	INJURY.position = INJURY.position + OFFSET
	add_child(INJURY)
	print("Gargoyle took: ", num, "dmg")
	
func idle():
	$Gargoyle2/GargoyleAnim.play("Idle")
	#print("Currently Idle")
	ALERTED.visible = false
	SLEEPY.visible = true
	await get_tree().create_timer(4.0).timeout

func patrol():
	print("Currently On Patrol")

func chase(delta):
#	if CHASE_TIME_RESET > 0:
	if PREY:
		$Gargoyle2/GargoyleAnim.play("Walk")
		CHASE_TIME_RESET = CHASE_TIME_RESET - delta
		velocity = (NAV.get_next_path_position() - position).normalized() * SPEED * delta
		$FaceDirection.look_at(PLAYER.position, Vector3.UP)
		#print("Currently Chasing Mwahaha!")
		SLEEPY.visible = false
		if PLAYER.position.distance_to(self.position) > MELEE_ATTACK_RANGE:
			NAV.target_position = PLAYER.position
			rotate_y(deg_to_rad($FaceDirection.rotation.y * TURN_SPEED))
			if NAV.is_navigation_finished():
				#print("Reached the Lost Soul!")
				velocity = Vector3.ZERO
			else:
				#print("Chasing!")
				SPEED = 100.0
				print("Gargoyle 'Chasing': ",SPEED)
				move_and_collide(velocity * delta)
		else:
			NEXT_STANCE = "Slash"
			#print("CHOMP!")
	else:
		NEXT_STANCE = "Idle"
		#print("ZZZzzzz")

func slash():
	if not ATTACKING:
		velocity = Vector3.ZERO #Freezes movement for attack
		$Gargoyle2/GargoyleAnim.play("Attack")
		await get_tree().create_timer(2.4).timeout #Time for attack animation
		print("Currently Slashing!") #Debug Line
		SLEEPY.visible = false
		ALERTED.visible = true
#		NEXT_STANCE = "Chase" #Ai change. Up with animation node

func jump_away():
	print("Attempting Jump")
	#Calc jump direction and impulse (going to launch this fucker backwards)
	#Note these need to be nested var's, or they will call the position all the time.
	var JUMP_DIRECTION = (position - PLAYER.position).normalized()
	var JUMP_IMPULSE = JUMP_DIRECTION * JUMP_STRENGTH
	JUMP_IMPULSE.y = VERTICAL_JUMP #This is the upward angel for the jump
	velocity = velocity + JUMP_IMPULSE
	JUMPING = true
	$Gargoyle2/GargoyleAnim.play("Jump")
	await get_tree().create_timer(2.0).timeout #Time for jump animation
	print("Making Disance for another attack!") #Debug Line
	JUMPING = false
	velocity = Vector3.ZERO #Reset after jump.

func ranged_attack():
	$Gargoyle2/GargoyleAnim.play("Idle")
	print("Charging Ranged Attack")
	await get_tree().create_timer(6.0).timeout #Timer for animation

func death():
	$Gargoyle2/GargoyleAnim.play("Death")
	#print("Et Tu Brute?")

func boss_chase(delta):
	if CHASE_TIME_RESET > 0:
		$Gargoyle2/GargoyleAnim.play("Run")
		CHASE_TIME_RESET = CHASE_TIME_RESET - delta
		velocity = (NAV.get_next_path_position() - position).normalized() * SPEED * delta
		$FaceDirection.look_at(PLAYER.position, Vector3.UP)
		SLEEPY.visible = false
		if PLAYER.position.distance_to(self.position) > MELEE_ATTACK_RANGE:
			NAV.target_position = PLAYER.position
			rotate_y(deg_to_rad($FaceDirection.rotation.y * (TURN_SPEED / 2)))
			if NAV.is_navigation_finished():
				velocity = Vector3.ZERO
			else:
				SPEED = 200.0
				print("COME BACK HERE!",SPEED) #Debug Line
				move_and_collide(velocity * delta)
		else:
			NEXT_STANCE = "Slash"
	else:
		NEXT_STANCE = "Idle"

func _on_area_3d_body_entered(body): #Linked to 'body_entered' signal.
	if body.is_in_group("player"):
		PREY = true
		NEXT_STANCE = "Chase"
		CHASE_TIME_RESET = CHASE_TIME
		SPEED = 50.0
		print("Gargoyle 'EnterBody': ",SPEED) #Debug Line
#		hunting_prey()
		#print("Food!")
	
	if body.is_in_group("NPC"):
		pass
	if body.is_in_group("Summon"):
		pass
	
func _on_area_3d_body_exited(body): #Linked to 'body_existed' signal.
	if body.is_in_group("player"):
		PREY = false
		NEXT_STANCE = "Boss Chase"
		CHASE_TIME_RESET = CHASE_TIME
		SPEED = 300.0
		print("COME BACK HERE! I CAN ONLY MOVE AT: ",SPEED) #Debug Line
		await get_tree().create_timer(AGRO_TIME).timeout
		if CURRENT_STANCE == "Boss Chase":
			NEXT_STANCE = "Idle"
			print("Tired of Chasing :(")

	
#	if body.is_in_group("player"):
#		print("Gargoyle 'ExitBody': ",SPEED)
#		await get_tree().create_timer(AGRO_TIME).timeout
#		if CURRENT_STANCE == "Chase":
#			NEXT_STANCE = "Idle"
#			print("Tired of Chasing :(")


