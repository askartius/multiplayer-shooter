extends Node


const PORT = 2048

@export var kill_count = {}

var peer = ENetMultiplayerPeer.new()
var player_src = preload("res://scenes/player.tscn")
var player_stats_container_src = preload("res://scenes/player_stats_container.tscn")

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_input = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressInput
@onready var nickname_input = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/NicknameInput
@onready var hud = $CanvasLayer/HUD
@onready var health_bar = $CanvasLayer/HUD/TopContainer/VBoxContainer/HealthBar
@onready var ammo_label = $CanvasLayer/HUD/AmmoLabel
@onready var help_menu = $CanvasLayer/HelpMenu
@onready var sun = $Sun
@onready var color_picker = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/ColorSelectionContainer/ColorPicker
@onready var death_screen = $CanvasLayer/DeathScreen
@onready var killer_label = $CanvasLayer/DeathScreen/MarginContainer/VBoxContainer/KillerInfoContainer/KillerLabel
@onready var damage_dealt_label = $CanvasLayer/DeathScreen/MarginContainer/VBoxContainer/DamageInfoContainer/DamageDealtLabel
@onready var animation_player = $CanvasLayer/AnimationPlayer
@onready var overview_camera = $OverviewCameraPivotPoint/OverviewCamera
@onready var kill_count_container = $CanvasLayer/HUD/TopContainer/VBoxContainer/KillCountContainer


func _unhandled_input(_event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func _on_host_button_pressed():
	main_menu.hide()
	hud.show()
	
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	add_player(multiplayer.get_unique_id())

func _on_join_button_pressed():
	main_menu.hide()
	hud.show()
	
	peer.create_client(address_input.text, PORT)
	multiplayer.multiplayer_peer = peer
	
	multiplayer.server_disconnected.connect(get_tree().quit)

func add_player(peer_id): # Runs on the server
	# Add player to the kill count
	kill_count[str(peer_id)] = 0
	var player_stats_container = player_stats_container_src.instantiate()
	player_stats_container.name = str(peer_id)
	kill_count_container.add_child(player_stats_container)
	
	# Add player character
	var player = player_src.instantiate()
	player.name = str(peer_id)
	player.position = Vector3(0, 5, 0)
	print(player.position)
	add_child(player)
	
	# Connect HUD and transfer data to the character if it's the local player
	if player.is_multiplayer_authority():
		player.health_changed.connect(update_health)
		player.ammo_changed.connect(update_ammo)
		player.death.connect(die)
		player.respawned.connect(respawn)
		
		var nickname = ""
		if nickname_input.text == "":
			randomize()
			nickname = "Unknown" + str(randi_range(0, 1000)) # Set the nickname to Unknown% if empty
		else:
			nickname = nickname_input.text
		
		player.set_nickname(nickname)
		player.set_color(Color(color_picker.color).to_html())
		
		# Show nickname in the kill count
		update_player_nickname.rpc(str(peer_id), nickname)

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		# Remove player from the kill count
		kill_count.erase(str(peer_id))
		kill_count_container.get_node(str(peer_id)).queue_free()
		# Remove player's character
		player.queue_free()

func update_health(health):
	# Make screen reddish
	if health_bar.value > health:
		animation_player.stop()
		animation_player.play("hit")
	
	health_bar.value = health
	if health <= 0:
		hud.hide()
		death_screen.show()

func update_ammo(ammo):
	if ammo != INF:
		ammo_label.text = str(ammo)
	else:
		ammo_label.text = "∞"

func die(killer_id, damage_dealt):
	update_kill_count.rpc(killer_id)
	
	hud.hide()
	death_screen.show()
	overview_camera.make_current()
	
	killer_label.text = get_node_or_null(str(killer_id)).nickname
	damage_dealt_label.text = str(damage_dealt)

func respawn():
	hud.show()
	death_screen.hide()

func _on_multiplayer_spawner_spawned(node): # Runs on clients
	# Connect HUD and transfer data to the character if it's the local player
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health)
		node.ammo_changed.connect(update_ammo)
		node.death.connect(die)
		node.respawned.connect(respawn)
		
		var nickname = ""
		if nickname_input.text == "":
			randomize()
			nickname = "Unknown" + str(randi_range(0, 1000)) # Set the nickname to Unknown% if empty
		else:
			nickname = nickname_input.text
		
		node.set_nickname(nickname)
		node.set_color(Color(color_picker.color).to_html())
		
		# Show nickname in the kill count
		update_player_nickname.rpc(str(node.name), nickname)

func _on_help_button_pressed():
	main_menu.hide()
	help_menu.show()

func _on_close_button_pressed():
	main_menu.show()
	help_menu.hide()

func _on_time_button_item_selected(index):
	match index:
		0:
			sun.visible = true
		1:
			sun.visible = false

@rpc("call_local", "any_peer")
func update_kill_count(player_id):
	kill_count[player_id] += 1
	for player in kill_count:
		kill_count_container.get_node(player).get_node("KillCountLabel").text = str(kill_count[player])

@rpc("call_local", "any_peer")
func update_player_nickname(player_id, nickname):
	kill_count_container.get_node(player_id).get_node("NicknameLabel").text = nickname
