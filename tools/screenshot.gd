extends SceneTree

## Abre a cena principal, espera alguns quadros e salva uma captura.
##
##     godot --path . --script res://tools/screenshot.gd -- <saída> [modo] [arg]
##
## Modos:
##   menu       tela inicial (padrão)
##   arena      Caçada em andamento, no quadro do Golpe Ativo
##   telegraph  Caçada no fim do Preparo do Behemoth
##   browse     tela de Buscar partida
##   lobby      a sala, já hospedada
##   interrupt  Caçada no quadro em que a JANELA DE INTERRUPÇÃO está aberta
##   learn <n>  a página n do Aprenda (índice na lista do LearnScreen)
##
## Serve para conferir o visual sem ficar abrindo o editor a cada mudança.

const WARMUP_FRAMES: int = 150

## As telas 2D não precisam de aquecimento de 3D, mas a tela de busca precisa
## de tempo para o anúncio UDP ir e voltar — por isso o número é generoso.
const UI_FRAMES: int = 120

## Sala falsa anunciada no modo `browse demo`, para a captura mostrar uma
## lista com linha de verdade em vez de uma lista vazia.
const DEMO_ROOM: Dictionary = {
	"room": "Sala do Vizinho", "hunters": 2, "max": 4,
	"behemoth": "gnasher", "behemoth_name": "Gnasher", "variant": "Fogo",
	"port": 7777,
}

var _frames: int = 0
var _output: String = "shot.png"
var _mode: String = "menu"
var _argument: String = ""
var _app: Node
var _ui_ready: bool = false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_output = args[0]
	if args.size() > 1:
		_mode = args[1]
	if args.size() > 2:
		_argument = args[2]
	_app = load("res://src/game/app.tscn").instantiate()
	root.add_child(_app)
	# process_frame em vez de sobrescrever _process: sobrescrever trocaria o
	# processamento nativo da SceneTree e os nós parariam de rodar.
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frames += 1

	if _is_ui_mode():
		if _frames == 5:
			_open_ui_screen()
		if _frames < UI_FRAMES:
			return
		_save()
		return

	if _mode == "arena" or _mode == "telegraph" or _mode == "interrupt":
		var net: NetGame = _app.get_node("NetGame")
		if _frames == 5:
			# Variante Flamejante: a captura confere a tinta elemental e, com
			# sorte, uma Queimadura ativa no HUD.
			net.host("Caçador", Weapons.SWORD, Elements.Element.NEUTRAL, Elements.Element.BLAZE)
		elif _frames > 5:
			# Corre até o Behemoth e bate nele, para a captura mostrar a cena
			# 3D com combate de verdade acontecendo.
			var beast := net.view_behemoth()
			var anchor: Vector2 = beast["pos"] if not beast.is_empty() else Vector2.ZERO
			# Para a uns 4 m do monstro: perto o bastante para a ação, longe o
			# bastante para a câmera não entrar dentro do corpo dele.
			var to_target: Vector2 = anchor - net.local_pos()
			var close := to_target.length() < 420.0
			net.set_local_input(Vector2.ZERO if close else to_target.normalized(), to_target.angle(), true)
			if close and _frames % 30 == 0:
				net.request_light()

	if _frames < WARMUP_FRAMES:
		return

	# No modo arena, espera o Golpe estar na fase Ativa: é o quadro que mostra
	# o arco de acerto, que é o que se quer conferir.
	if _mode == "arena" and _frames < WARMUP_FRAMES + 200 and not _is_attack_active():
		return

	# No modo telegrafia, espera o Behemoth estar no fim do Preparo: é o
	# quadro em que a área do ataque está pintada e cheia no chão.
	if _mode == "telegraph" and _frames < WARMUP_FRAMES + 900 and not _is_telegraphing():
		return

	# No modo interrupção, espera a JANELA de boop estar aberta: é o quadro em
	# que o HUD mostra o aviso que o Aprenda ensina a usar.
	if _mode == "interrupt" and _frames < WARMUP_FRAMES + 1800 and not _is_interrupt_window():
		return
	_save()


## Verdadeiro enquanto o Behemoth está dentro da janela interrompível de um
## ataque — a mesma conta que o HUD faz.
func _is_interrupt_window() -> bool:
	var net: NetGame = _app.get_node("NetGame")
	var beast := net.view_behemoth()
	if beast.is_empty() or int(beast["state"]) != int(BehemothState.State.WINDUP):
		return false
	var attack := Behemoths.attack(beast["type"], beast["attack"])
	var window: Dictionary = attack.get("interruptible", {})
	if window.is_empty():
		return false
	return float(beast["state_time"]) <= float(window.get("until", 0.0))


func _save() -> void:
	var image := root.get_texture().get_image()
	var error := image.save_png(_output)
	if error != OK:
		printerr("Falha ao salvar a captura em %s (erro %d)" % [_output, error])
	else:
		print("Captura salva em %s" % _output)
	quit(0)


func _is_ui_mode() -> bool:
	return _mode == "menu" or _mode == "browse" or _mode == "lobby" or _mode == "learn"


## Leva o App até a tela pedida chamando os mesmos caminhos que os botões
## chamam — a captura mostra a tela de verdade, não uma montagem só dela.
func _open_ui_screen() -> void:
	match _mode:
		"browse":
			_app.call("_on_search_requested", "Caçador")
			if _argument == "demo":
				var beacon := LanDiscovery.new()
				root.add_child(beacon)
				beacon.advertise(DEMO_ROOM)
		"lobby":
			_app.call("_on_search_requested", "Caçador")
			_app.call("_on_host_requested", "Sala de Teste")
			# Uma variante COM Oposição e uma arma certa contra ela, para a
			# captura mostrar a dica e a marca de vantagem funcionando.
			var net: NetGame = _app.get_node("NetGame")
			net.set_hunt_settings(Behemoths.GNASHER, Elements.Element.BLAZE)
			net.set_loadout(Weapons.HAMMER, Elements.Element.FROST)
			net.set_ready(true)
		"learn":
			_app.call("_show_learn", "menu")
			var learn: Node = _app.get("_learn")
			if learn != null and not _argument.is_empty():
				learn.call("_open", int(_argument))


func _is_attack_active() -> bool:
	var net: NetGame = _app.get_node("NetGame")
	for hunter in net.view_hunters():
		if hunter["id"] != net.local_id:
			continue
		if int(hunter["state"]) != int(HunterState.State.ATTACK):
			return false
		var move := Weapons.move(
			hunter["weapon"],
			int(hunter["attack_kind"]) as Weapons.Kind,
			int(hunter["attack_index"])
		)
		var elapsed: float = hunter["state_time"]
		var windup := float(move["windup"])
		return elapsed > windup and elapsed <= windup + float(move["active"])
	return false


## Verdadeiro no finalzinho do Preparo do Behemoth, quando a Telegrafia já
## está cheia no chão.
func _is_telegraphing() -> bool:
	var net: NetGame = _app.get_node("NetGame")
	var beast := net.view_behemoth()
	if beast.is_empty() or int(beast["state"]) != int(BehemothState.State.WINDUP):
		return false
	var attack := Behemoths.attack(beast["type"], beast["attack"])
	if attack.is_empty():
		return false
	return float(beast["state_time"]) > float(attack["windup"]) * 0.75
