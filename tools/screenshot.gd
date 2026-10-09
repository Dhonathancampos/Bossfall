extends SceneTree

## Abre a cena principal, espera alguns quadros e salva uma captura.
##
##     godot --path . --script res://tools/screenshot.gd -- <caminho-de-saida>
##
## Serve para conferir o visual sem ficar abrindo o editor a cada mudança.

const WARMUP_FRAMES: int = 150

var _frames: int = 0
var _output: String = "shot.png"
var _mode: String = "menu"
var _app: Node

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_output = args[0]
	if args.size() > 1:
		_mode = args[1]
	_app = load("res://src/game/app.tscn").instantiate()
	root.add_child(_app)
	# process_frame em vez de sobrescrever _process: sobrescrever trocaria o
	# processamento nativo da SceneTree e os nós parariam de rodar.
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frames += 1

	if _mode == "arena" or _mode == "telegraph":
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
	var image := root.get_texture().get_image()
	var error := image.save_png(_output)
	if error != OK:
		printerr("Falha ao salvar a captura em %s (erro %d)" % [_output, error])
	else:
		print("Captura salva em %s" % _output)
	quit(0)


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
