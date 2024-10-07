extends Node

const ButtonAction = {
	EMIT_SIGNAL = "games.boyne.godot.emitsignal",
	SWITCH_SCENE = "games.boyne.godot.switchscene",
	RELOAD_SCENE = "games.boyne.godot.reloadscene",
}

const ButtonEvent = {
	KEY_UP = "keyUp",
	KEY_DOWN = "keyDown"
}

signal on_key_up
signal on_key_down

const PLUGIN_NAME = "games.boyne.godot.sdPlugin"
const WEBSOCKET_URL = "127.0.0.1:%s/ws"

var _socket := WebSocketClient.new()
var _config := ConfigFile.new()

func _ready() -> void:
	_config.load(_get_config_path())
	
	# https://docs.godotengine.org/en/3.5/tutorials/networking/websocket.html#minimal-client-example
	_socket.connect("connection_closed", self, "_on_connection_closed")
	_socket.connect("connection_error", self, "_on_connection_error")
	_socket.connect("connection_established", self, "_on_connection_established")
	_socket.connect("data_received", self, "_on_data_received")
	
	_socket.connect_to_url(_get_websocket_url())

func _physics_process(delta):
	_socket.poll()

func _on_connection_closed(was_clean_close: bool):
	print("connection closed")

func _on_connection_error():
	print("connection error")
	
func _on_connection_established(protocol: String):
	print("connection established with protocol", protocol)

func _on_data_received():
	var data_str = _socket.get_peer(1).get_packet().get_string_from_utf8()
	print("got data: ", data_str)
	var parse = JSON.parse(data_str)
	if parse.error != OK:
		print("error parsing")
		return
	
	var data = parse.result
	if !(data.event == ButtonEvent.KEY_DOWN || data.event == ButtonEvent.KEY_UP):
		return
	
	if data != null && data.has("action") && data.has("payload"):
		match data.action:
			ButtonAction.EMIT_SIGNAL:
				var signalInput = ""
				
				if data.payload.settings.has("signalInput"):
					signalInput = data.payload.settings.signalInput
				
				match data.event:
					ButtonEvent.KEY_UP:
						#on_key_up.emit(signalInput) #godot4
						emit_signal("on_key_up", signalInput) #godot3
					ButtonEvent.KEY_DOWN:
						#on_key_down.emit(signalInput) #godot4
						emit_signal("on_key_down", signalInput) #godot3
			ButtonAction.SWITCH_SCENE:
				if data.payload.settings.has("scenePath"):
					var scenePath = data.payload.settings.scenePath
					get_tree().change_scene(scenePath)
			ButtonAction.RELOAD_SCENE:
				get_tree().reload_current_scene()

func _get_websocket_url() -> String:
	return WEBSOCKET_URL % _config.get_value("bridge", "port", "8080")
	
func _get_config_path() -> String:
	match OS.get_name():
		"Windows":
			return "%s/Elgato/StreamDeck/Plugins/%s/plugin.ini" % [OS.get_config_dir(), PLUGIN_NAME]
		"macOS":
			return "%s/com.elgato.StreamDeck/Plugins/%s/plugin.ini" % [OS.get_config_dir(), PLUGIN_NAME]
	return ""
