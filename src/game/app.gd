extends Node

## Raiz do jogo. Troca entre a tela de menu e a Arena, e é dona do NetGame.
##
## O NetGame precisa existir no mesmo caminho da árvore em todas as máquinas
## para que as chamadas de rede se encontrem, por isso ele é filho fixo daqui
## e nunca é recriado entre partidas.

var _net: NetGame
var _menu: MenuScreen
var _arena: Arena3D
var _audio: AudioFx

func _ready() -> void:
	_net = NetGame.new()
	_net.name = "NetGame"
	add_child(_net)
	_net.started.connect(_on_started)
	_net.stopped.connect(_on_stopped)
	_show_menu()


func _show_menu(message: String = "") -> void:
	if _arena != null:
		_arena.queue_free()
		_arena = null
	if _menu == null:
		_menu = MenuScreen.new()
		_menu.host_requested.connect(_on_host_requested)
		_menu.join_requested.connect(_on_join_requested)
		_menu.training_requested.connect(_on_training_requested)
		add_child(_menu)
	_menu.set_message(message)
	_menu.visible = true


func _on_host_requested(display_name: String, weapon_id: String, weapon_element: int, behemoth_element: int, behemoth_type: String) -> void:
	_menu.set_message("")
	var error := _net.host(
		display_name, weapon_id,
		weapon_element as Elements.Element, behemoth_element as Elements.Element,
		behemoth_type
	)
	if not error.is_empty():
		_menu.set_message(error)


func _on_join_requested(address: String, display_name: String, weapon_id: String, weapon_element: int) -> void:
	_menu.set_message("Conectando…")
	var error := _net.join(address, display_name, weapon_id, weapon_element as Elements.Element)
	if not error.is_empty():
		_menu.set_message(error)


func _on_training_requested(display_name: String, weapon_id: String, weapon_element: int) -> void:
	_menu.set_message("")
	var error := _net.start_training(display_name, weapon_id, weapon_element as Elements.Element)
	if not error.is_empty():
		_menu.set_message(error)


func _on_started() -> void:
	if _menu != null:
		_menu.visible = false
	_arena = Arena3D.new()
	_arena.setup(_net)
	_arena.leave_requested.connect(_on_leave_requested)
	add_child(_arena)

	# O som nasce com a partida e morre com ela, para uma partida nova não
	# acumular tocadores nem sinais duplicados.
	if _audio != null:
		_audio.queue_free()
	_audio = AudioFx.new()
	_audio.setup(_net)
	add_child(_audio)


func _on_leave_requested() -> void:
	_net.leave()
	_show_menu()


func _on_stopped(reason: String) -> void:
	_show_menu(reason)
