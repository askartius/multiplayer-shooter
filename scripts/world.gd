extends Node


const PORT = 2048

var peer = ENetMultiplayerPeer.new()
var player_src = preload("res://scenes/player.tscn")

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_input = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressInput
@onready var nickname_input = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/NicknameInput
@onready var hud = $CanvasLayer/HUD
@onready var health_bar = $CanvasLayer/HUD/HealthBar
@onready var ammo_label = $CanvasLayer/HUD/AmmoLabel
@onready var help_menu = $CanvasLayer/HelpMenu
@onready var sun = $Sun
@onready var color_picker = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/ColorSelectionContainer/ColorPicker


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

func add_player(peer_id):
	randomize()
	
	var player = player_src.instantiate()
	player.name = str(peer_id)
	player.position = Vector3(randi_range(-15, 15), 5, randi_range(-15, 15))
	add_child(player)
	
	if player.is_multiplayer_authority():
		# Connect signal for changes in HUD
		player.health_changed.connect(update_health_bar)
		player.ammo_changed.connect(update_ammo_bar)
		
		player.set_nickname(nickname_input.text)
		#player.set_color.rpc_id(peer_id, Color(color_picker.color).to_html())

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func update_health_bar(health):
	health_bar.value = health

func update_ammo_bar(ammo):
	if ammo != INF:
		ammo_label.text = str(ammo)
	else:
		ammo_label.text = "∞"

func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		# Connect signal for changes in HUD
		node.health_changed.connect(update_health_bar)
		node.ammo_changed.connect(update_ammo_bar)
		
		node.set_nickname(nickname_input.text)
		#node.set_color.rpc_id(int(str(node.name)), Color(color_picker.color).to_html())


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
