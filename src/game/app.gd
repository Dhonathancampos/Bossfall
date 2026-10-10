extends Node

## Raiz do jogo. Troca entre as telas (menu, busca, sala, Aprenda) e a Arena,
## e é dona do NetGame.
##
## O NetGame precisa existir no mesmo caminho da árvore em todas as máquinas
## para que as chamadas de rede se encontrem, por isso ele é filho fixo daqui
## e nunca é recriado entre partidas.
##
## Cada tela é criada ao entrar e destruída ao sair: uma só viva por vez,
## menos o Aprenda, que é empilhado por cima e sabe para onde voltar.

var _net: NetGame
var _menu: MenuScreen
var _browse: BrowseScreen
var _lobby: LobbyScreen
var _learn: LearnScreen
var _arena: Arena3D
var _audio: AudioFx

## Nome digitado no menu, levado para a sala e para o treinamento.
var _display_name: String = "Caçador"

## Para onde o Aprenda volta quando fecha.
var _learn_return: String = "menu"


func _ready() -> void:
	_net = NetGame.new()
	_net.name = "NetGame"
	add_child(_net)
	_net.started.connect(_on_started)
	_net.stopped.connect(_on_stopped)
	_net.phase_changed.connect(_on_phase_changed)
	_show_menu()


## Telas --------------------------------------------------------------------

func _clear_screens() -> void:
	for screen in [_menu, _browse, _lobby, _learn]:
		if screen != null:
			(screen as Node).queue_free()
	_menu = null
	_browse = null
	_lobby = null
	_learn = null


func _show_menu(message: String = "") -> void:
	if _arena != null:
		_arena.queue_free()
		_arena = null
	_clear_screens()

	_menu = MenuScreen.new()
	_menu.search_requested.connect(_on_search_requested)
	_menu.training_requested.connect(_on_training_requested)
	_menu.learn_requested.connect(func() -> void: _show_learn("menu"))
	_menu.quit_requested.connect(func() -> void: get_tree().quit())
	add_child(_menu)
	_menu.set_hunter_name(_display_name)
	_menu.set_message(message)


func _show_browse(message: String = "") -> void:
	_clear_screens()
	_browse = BrowseScreen.new()
	_browse.host_requested.connect(_on_host_requested)
	_browse.join_requested.connect(_on_join_requested)
	_browse.back_requested.connect(func() -> void: _show_menu())
	add_child(_browse)
	_browse.set_room_name("Sala de %s" % _display_name)
	_browse.set_message(message)


func _show_lobby() -> void:
	if _arena != null:
		_arena.queue_free()
		_arena = null
	_clear_screens()
	_lobby = LobbyScreen.new()
	_lobby.setup(_net)
	_lobby.start_requested.connect(_on_start_requested)
	_lobby.learn_requested.connect(func() -> void: _show_learn("lobby"))
	_lobby.leave_requested.connect(_on_leave_lobby)
	add_child(_lobby)


func _show_learn(return_to: String) -> void:
	if _learn != null:
		return
	_learn_return = return_to
	# A tela de baixo some e para de ouvir teclado: senão o Esc que fecha o
	# Aprenda também sairia da sala. O _process dela continua — é ele que
	# mantém o anúncio da sala na rede local enquanto você lê.
	for screen in [_menu, _browse, _lobby]:
		if screen != null:
			(screen as Control).visible = false
			(screen as Control).set_process_unhandled_input(false)
	_learn = LearnScreen.new()
	_learn.back_requested.connect(_on_learn_closed)
	add_child(_learn)


func _on_learn_closed() -> void:
	if _learn != null:
		_learn.queue_free()
		_learn = null
	for screen in [_menu, _browse, _lobby]:
		if screen != null:
			(screen as Control).visible = true
			(screen as Control).set_process_unhandled_input(true)
	# A sala pode ter mudado enquanto o Aprenda estava aberto.
	if _lobby != null:
		_lobby.refresh()


## Pedidos das telas --------------------------------------------------------

func _on_search_requested(display_name: String) -> void:
	_display_name = display_name
	_show_browse()


func _on_host_requested(room_name: String) -> void:
	var error := _net.host_lobby(
		_display_name, Weapons.SWORD, Elements.Element.NEUTRAL, room_name
	)
	if not error.is_empty():
		_browse.set_message(error)
		return
	_show_lobby()


func _on_join_requested(address: String, port: int) -> void:
	_browse.set_message("Conectando a %s…" % address)
	var error := _net.join_lobby(
		address, _display_name, Weapons.SWORD, Elements.Element.NEUTRAL, port
	)
	if not error.is_empty():
		_browse.set_message(error)


func _on_start_requested() -> void:
	var error := _net.start_hunt()
	if not error.is_empty() and _lobby != null:
		_lobby.set_message(error)


func _on_leave_lobby() -> void:
	_net.leave()
	_show_menu()


func _on_training_requested(display_name: String) -> void:
	_display_name = display_name
	var error := _net.start_training(display_name, Weapons.SWORD, Elements.Element.NEUTRAL)
	if not error.is_empty():
		_menu.set_message(error)


## Sinais do NetGame --------------------------------------------------------

## Entrar numa sala é assíncrono: a tela só troca quando a conexão deu certo,
## e é a fase que avisa.
func _on_phase_changed(phase: int) -> void:
	if phase == NetGame.Phase.LOBBY and _lobby == null:
		_show_lobby()


func _on_started() -> void:
	_clear_screens()
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


## TODO(fase): com as fases na Sim, sair da Arena deve cair na tela de
## RESULTADO e dali voltar para a sala (o Anfitrião encadeia Caçadas sem
## reabrir a porta). Hoje sair da Arena encerra a sessão inteira.
func _on_leave_requested() -> void:
	_net.leave()
	_show_menu()


func _on_stopped(reason: String) -> void:
	_show_menu(reason)
