extends SceneTree

## Confere a rede de verdade, com dois processos.
##
##     godot --headless --path . --script res://tools/netcheck.gd -- host 14
##     godot --headless --path . --script res://tools/netcheck.gd -- join 127.0.0.1 10
##
## Monta a mesma árvore que o jogo (/root/App/NetGame), porque é o caminho que
## as chamadas de rede usam para se encontrar nas duas pontas.
##
## Usa o sinal process_frame em vez de sobrescrever _process: sobrescrever
## trocaria o processamento nativo da SceneTree e os nós parariam de rodar.

var _net: NetGame
var _mode: String = "host"
var _address: String = "127.0.0.1"
var _seconds: float = 12.0
var _started_at: float = 0.0
var _last_report: float = 0.0
var _frames: int = 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
	if _mode == "host":
		if args.size() > 1:
			_seconds = float(args[1])
	else:
		if args.size() > 1:
			_address = args[1]
		if args.size() > 2:
			_seconds = float(args[2])

	var app := Node.new()
	app.name = "App"
	root.add_child(app)

	_net = NetGame.new()
	_net.name = "NetGame"
	app.add_child(_net)

	_net.stopped.connect(func(reason: String) -> void: print("[%s] parou: %s" % [_mode, reason]))
	_net.roster_changed.connect(func() -> void: print("[%s] lista mudou" % _mode))

	process_frame.connect(_on_frame)


func _start() -> void:
	# Só no primeiro quadro: `multiplayer` ainda é nulo durante _initialize().
	var error := _net.host("Anfitriao") if _mode == "host" else _net.join(_address, "Cliente")
	if error.is_empty():
		print("[%s] iniciado" % _mode)
	else:
		print("[%s] ERRO: %s" % [_mode, error])


func _on_frame() -> void:
	_frames += 1
	if _frames == 1:
		_started_at = _now()
		_last_report = _started_at
		_start()
		return

	# Os dois vão até o boneco de treino e batem nele. Se a Vida do boneco só
	# cair na tela de um dos dois, o dano não está sendo replicado.
	var to_dummy: Vector2 = SimConfig.DUMMY_POS - _net.local_pos()
	var close := to_dummy.length() < 110.0
	_net.set_local_input(Vector2.ZERO if close else to_dummy.normalized(), to_dummy.angle(), true)
	if close and _frames % 20 == 0:
		_net.request_light()
	# Uma Esquiva de vez em quando: exercita o canal confiável de Entrada e a
	# reconciliação da predição no Cliente.
	if _frames % 150 == 0:
		_net.request_dodge()

	var now := _now()
	if now - _last_report >= 2.0:
		_last_report = now
		var seen: Array[String] = []
		for hunter in _net.view_hunters():
			# Só o Caçador local carrega Fôlego: os outros vêm com o mínimo
			# para serem desenhados.
			var stamina: float = hunter.get("stamina", -1.0)
			seen.append("%s@%.0f,%.0f folego=%s" % [
				hunter["name"], hunter["pos"].x, hunter["pos"].y,
				"-" if stamina < 0.0 else "%.0f" % stamina,
			])
		var targets := _net.view_targets()
		var dummy_hp := float(targets[0]["hp"]) if not targets.is_empty() else -1.0
		print("[%s] t=%.0fs cacadores=%d boneco_vida=%.0f  %s"
			% [_mode, now - _started_at, seen.size(), dummy_hp, " | ".join(seen)])

	if now - _started_at >= _seconds:
		quit(0)


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
