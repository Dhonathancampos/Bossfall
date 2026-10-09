class_name NetGame
extends Node

## Adaptador de rede. Fica entre a Simulação e a Apresentação, e é a única
## parte do jogo que sabe que existe rede.
##
## Quem Hospeda roda a Sim e é a verdade final. Quem Entra não roda Sim
## nenhuma: manda Entrada, recebe Instantâneo, e prevê só o próprio movimento
## livre para não sentir o atraso da ida e volta.
##
## Trocar ENet por outro transporte deve mexer só neste arquivo.

signal started
signal stopped(reason: String)
signal roster_changed

## O que aconteceu num Tique e a Apresentação precisa desenhar: acertos,
## faíscas, números de dano. Chega junto com o Instantâneo, para que Anfitrião
## e Clientes vejam a mesma coisa.
signal events_happened(events: Array)

const DEFAULT_PORT: int = 7777
const MAX_HUNTERS: int = 4

## O Anfitrião manda Instantâneo a cada 2 Tiques (30 por segundo). O Cliente
## interpola entre eles, então mandar 60 só gastaria banda.
const SNAPSHOT_EVERY_TICKS: int = 2

## O Cliente desenha os outros Caçadores um pouco no passado, para sempre ter
## dois Instantâneos entre os quais interpolar mesmo com jitter.
const INTERPOLATION_DELAY: float = 0.12

## Quantos Instantâneos guardar. Mais que isso é memória à toa.
const SNAPSHOT_HISTORY: int = 8

const MAX_STEPS_PER_FRAME: int = 8

var is_host: bool = false
var local_id: int = 1
var is_training: bool = false

## Só existe no Anfitrião.
var sim: Sim = null

var _running: bool = false
var _accumulator: float = 0.0
var _tick_count: int = 0

## Entrada do quadro atual, alimentada pela Apresentação.
var _input_move: Vector2 = Vector2.ZERO
var _input_aim: float = 0.0
var _input_sprint: bool = false
var _input_heavy_held: bool = false

## Pedidos armados pela Apresentação, cada um consumido por um Tique só.
var _dodge_armed: bool = false
var _light_armed: bool = false
var _heavy_armed: bool = false
var _special_armed: bool = false
var _reload_armed: bool = false
var _seq: int = 0

## Cliente: Entradas mandadas e ainda não confirmadas pelo Anfitrião.
var _pending: Array[HunterInput] = []

## Cliente: o próprio Caçador, previsto localmente. Parte do último
## Instantâneo e repete por cima as Entradas que o Anfitrião ainda não
## confirmou, com a mesma HunterStep que a Sim usa.
var _predicted: HunterState = HunterState.new()

## Cliente: histórico de Instantâneos, com a hora local de chegada.
var _snapshots: Array[Dictionary] = []

## Anfitrião: nome de cada Caçador, por id.
var _names: Dictionary = {}

## Nome e arma de cada Caçador, por id. Estáticos, então chegam pela lista de
## Caçadores (confiável, só quando muda) em vez de dentro de cada Instantâneo.
var _roster: Dictionary = {}


## Ciclo de vida -----------------------------------------------------------

func host(
	display_name: String,
	weapon_id: String = Weapons.SWORD,
	weapon_element: Elements.Element = Elements.Element.NEUTRAL,
	behemoth_element: Elements.Element = Elements.Element.NEUTRAL,
	behemoth_type: String = Behemoths.GNASHER,
	port: int = DEFAULT_PORT
) -> String:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_HUNTERS - 1)
	if error != OK:
		return "Não foi possível abrir a porta %d (erro %d)." % [port, error]

	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	is_host = true
	is_training = false
	local_id = multiplayer.get_unique_id()
	sim = Sim.new(behemoth_type, behemoth_element)
	sim.add_hunter(local_id, display_name, weapon_id)
	sim.set_weapon(local_id, weapon_id, weapon_element)
	_names[local_id] = display_name
	_begin()
	_roster = sim.roster()
	started.emit()
	return ""


## A área de treinamento roda localmente, mas usa a mesma Sim de uma Caçada.
## Assim combos, recursos e movimentação são testados no caminho real do jogo.
func start_training(
	display_name: String,
	weapon_id: String = Weapons.SWORD,
	weapon_element: Elements.Element = Elements.Element.NEUTRAL
) -> String:
	if _running:
		leave()

	is_host = true
	is_training = true
	local_id = 1
	sim = Sim.new()
	sim.add_hunter(local_id, display_name, weapon_id)
	sim.set_weapon(local_id, weapon_id, weapon_element)
	_names[local_id] = display_name
	_begin()
	_roster = sim.roster()
	started.emit()
	return ""


func join(
	address: String,
	display_name: String,
	weapon_id: String = Weapons.SWORD,
	weapon_element: Elements.Element = Elements.Element.NEUTRAL,
	port: int = DEFAULT_PORT
) -> String:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		return "Endereço inválido ou inalcançável (erro %d)." % error

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(
		_on_connected_to_server.bind(display_name, weapon_id, int(weapon_element))
	)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	is_host = false
	return ""


func leave() -> void:
	_running = false
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	sim = null
	is_host = false
	is_training = false
	_pending.clear()
	_snapshots.clear()
	_names.clear()
	_tick_count = 0
	_accumulator = 0.0


func is_running() -> bool:
	return _running


func _begin() -> void:
	_running = true
	_accumulator = 0.0
	_tick_count = 0
	_seq = 0
	_pending.clear()
	_snapshots.clear()
	_predicted = HunterState.new()
	_roster = {}
	_dodge_armed = false
	_light_armed = false
	_heavy_armed = false
	_special_armed = false
	_reload_armed = false


## Entrada -----------------------------------------------------------------

## Chamado pela Apresentação a cada quadro. Guardar e usar no Tique mantém a
## Sim num passo fixo, independente da taxa de quadros.
func set_local_input(move: Vector2, aim: float, sprint: bool, heavy_held: bool = false) -> void:
	_input_move = move
	_input_aim = aim
	_input_sprint = sprint
	_input_heavy_held = heavy_held


## Os pedidos ficam armados até um Tique consumi-los. Sem isso, uma apertada
## entre dois Tiques se perderia, e uma apertada segurada viraria vários.
func request_dodge() -> void:
	_dodge_armed = true


func request_light() -> void:
	_light_armed = true


func request_heavy() -> void:
	_heavy_armed = true


func request_special() -> void:
	_special_armed = true


func request_reload() -> void:
	_reload_armed = true


## Passo ------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _running:
		return

	_accumulator += delta
	var steps: int = 0
	while _accumulator >= SimConfig.TICK_DELTA and steps < MAX_STEPS_PER_FRAME:
		_tick()
		_accumulator -= SimConfig.TICK_DELTA
		steps += 1

	# Descarta o tempo que não coube: melhor perder Tiques do que acumular
	# dívida que nunca será paga.
	if _accumulator >= SimConfig.TICK_DELTA:
		_accumulator = 0.0


func _tick() -> void:
	_seq += 1
	var input := HunterInput.make(
		_input_move, _input_aim, _seq,
		_input_sprint, _dodge_armed, _light_armed, _heavy_armed,
		_special_armed, _input_heavy_held, _reload_armed
	)
	_dodge_armed = false
	_light_armed = false
	_heavy_armed = false
	_special_armed = false
	_reload_armed = false

	if is_host:
		sim.set_input(local_id, input)
		sim.step(SimConfig.TICK_DELTA)
		_tick_count += 1
		if _tick_count % SNAPSHOT_EVERY_TICKS == 0:
			_broadcast()
	else:
		_pending.append(input)
		HunterStep.step(_predicted, input, SimConfig.TICK_DELTA, _prediction_world())
		_push_input.rpc_id(1, input.to_dict())


## Rede -------------------------------------------------------------------

## Os eventos são consumidos da Sim aqui, uma vez por Instantâneo: assim
## nenhum acerto se perde entre dois envios nem é contado duas vezes.
##
## Cada Cliente recebe um Instantâneo próprio, com o estado completo só do
## Caçador dele. Um envio único com tudo de todos passava do MTU do ENet com 4
## Caçadores e virava perda de pacote.
func _broadcast() -> void:
	var events := sim.take_events()
	for peer_id in multiplayer.get_peers():
		var payload := sim.snapshot(peer_id)
		payload["events"] = events
		_push_snapshot.rpc_id(peer_id, payload)
	if not events.is_empty():
		events_happened.emit(events)

@rpc("any_peer", "call_remote", "reliable", 1)
func _push_input(data: Dictionary) -> void:
	if not is_host or sim == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	sim.set_input(sender, HunterInput.from_dict(data))


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _push_snapshot(data: Dictionary) -> void:
	if is_host:
		return
	_snapshots.append({"at": _now(), "data": data})
	while _snapshots.size() > SNAPSHOT_HISTORY:
		_snapshots.pop_front()
	_reconcile(data)
	var events: Array = data.get("events", [])
	if not events.is_empty():
		events_happened.emit(events)


## A lista de Caçadores muda raramente, então vai confiável e só quando muda.
func _publish_roster() -> void:
	_roster = sim.roster()
	_push_roster.rpc(_roster)
	roster_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _push_roster(entries: Dictionary) -> void:
	if is_host:
		return
	_roster = entries
	roster_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _announce_name(display_name: String, weapon_id: String = Weapons.SWORD, weapon_element: int = 0) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	_names[sender] = display_name
	if sim != null and sim.has_hunter(sender):
		sim.rename_hunter(sender, display_name)
		sim.set_weapon(sender, weapon_id, weapon_element as Elements.Element)
	_publish_roster()


func _on_peer_connected(id: int) -> void:
	if not is_host or sim == null:
		return
	sim.add_hunter(id, _names.get(id, "Caçador %d" % id))
	_publish_roster()


func _on_peer_disconnected(id: int) -> void:
	if not is_host or sim == null:
		return
	# A Caçada continua sem ele. Nada de pausar nem encerrar.
	sim.remove_hunter(id)
	_names.erase(id)
	_publish_roster()


func _on_connected_to_server(display_name: String, weapon_id: String, weapon_element: int) -> void:
	local_id = multiplayer.get_unique_id()
	_begin()
	_announce_name.rpc_id(1, display_name, weapon_id, weapon_element)
	started.emit()


func _on_connection_failed() -> void:
	leave()
	stopped.emit("Não foi possível conectar ao Anfitrião.")


func _on_server_disconnected() -> void:
	leave()
	stopped.emit("O Anfitrião saiu da partida.")


## Predição e reconciliação ------------------------------------------------

func _reconcile(snapshot: Dictionary) -> void:
	var mine := _find_by_id(snapshot.get("hunters", []), local_id)
	if mine.is_empty():
		return

	# Volta para a verdade do Anfitrião...
	_predicted.apply_dict(mine)

	# ...descarta o que ele já aplicou...
	var acked: int = mine.get("seq", 0)
	while not _pending.is_empty() and _pending[0].seq <= acked:
		_pending.pop_front()

	# ...e repete o que ainda está no caminho. Como HunterStep é a mesma
	# máquina de estados que a Sim usa, o resultado bate.
	for input in _pending:
		HunterStep.step(_predicted, input, SimConfig.TICK_DELTA, _prediction_world(snapshot))


## A predição usa o Behemoth mais recente que o cliente conhece para manter o
## corpo local fora dele imediatamente. A autoridade continua no Anfitrião;
## qualquer pequena diferença de rede é corrigida na próxima reconciliação.
func _prediction_world(snapshot: Dictionary = {}) -> Dictionary:
	var source := snapshot
	if source.is_empty() and not _snapshots.is_empty():
		source = _snapshots[_snapshots.size() - 1]["data"]
	var behemoth: Dictionary = source.get("behemoth", {})
	if behemoth.is_empty():
		return {}
	return {
		"has_behemoth": true,
		"behemoth_pos": behemoth["pos"],
		"behemoth_radius": behemoth["radius"],
	}


## Leitura para a Apresentação ---------------------------------------------

## Os Caçadores prontos para desenhar: o local já previsto, os outros já
## interpolados. A Apresentação não precisa saber de onde vieram.
func view_hunters() -> Array:
	if not is_host:
		return _interpolated_hunters()
	if sim == null:
		return []
	var hunters: Array = []
	for hunter in sim.snapshot(local_id).get("hunters", []):
		hunters.append(_with_roster(hunter))
	return hunters


func local_pos() -> Vector2:
	if is_host:
		var mine := _find_by_id(view_hunters(), local_id)
		return mine.get("pos", Vector2.ZERO)
	return _predicted.pos


func hunter_count() -> int:
	return view_hunters().size()


## Os dois Instantâneos entre os quais desenhar, e onde estamos entre eles.
## Desenhar um pouco no passado é o que garante que sempre exista um par.
func _interpolation_pair() -> Dictionary:
	var render_time := _now() - INTERPOLATION_DELAY
	var from: Dictionary = _snapshots[0]
	var to: Dictionary = _snapshots[_snapshots.size() - 1]
	for i in range(_snapshots.size() - 1):
		if _snapshots[i]["at"] <= render_time and _snapshots[i + 1]["at"] >= render_time:
			from = _snapshots[i]
			to = _snapshots[i + 1]
			break

	var span: float = float(to["at"]) - float(from["at"])
	return {
		"from": from["data"],
		"to": to["data"],
		"alpha": 0.0 if span <= 0.0 else clampf((render_time - float(from["at"])) / span, 0.0, 1.0),
	}


## O Behemoth pronto para desenhar, ou vazio. Interpolado como todo o resto —
## o Cliente nunca prevê nada do Behemoth, só o desenha um pouco no passado.
func view_behemoth() -> Dictionary:
	if is_host:
		return sim.snapshot().get("behemoth", {}) if sim != null else {}
	if _snapshots.is_empty():
		return {}

	var pair := _interpolation_pair()
	var to: Dictionary = pair["to"].get("behemoth", {})
	if to.is_empty():
		return {}

	var from: Dictionary = pair["from"].get("behemoth", {})
	var drawn: Dictionary = to.duplicate()
	if not from.is_empty():
		var alpha: float = pair["alpha"]
		drawn["pos"] = (from["pos"] as Vector2).lerp(to["pos"], alpha)
		drawn["facing"] = lerp_angle(from["facing"], to["facing"], alpha)
	return drawn


## Os projéteis prontos para desenhar (posições no plano da Sim).
func view_projectiles() -> Array:
	if is_host:
		return sim.snapshot().get("projectiles", []) if sim != null else []
	if _snapshots.is_empty():
		return []
	# Projéteis são rápidos e curtos: desenhar o Instantâneo mais novo basta.
	return (_snapshots[_snapshots.size() - 1]["data"] as Dictionary).get("projectiles", [])


## Os alvos prontos para desenhar.
func view_targets() -> Array:
	if is_host:
		return sim.snapshot().get("targets", []) if sim != null else []
	if _snapshots.is_empty():
		return []

	var pair := _interpolation_pair()
	var alpha: float = pair["alpha"]
	var result: Array = []
	for target in pair["to"].get("targets", []):
		var earlier := _find_by_id(pair["from"].get("targets", []), target["id"])
		var drawn: Dictionary = target.duplicate()
		if not earlier.is_empty():
			drawn["pos"] = (earlier["pos"] as Vector2).lerp(target["pos"], alpha)
		result.append(drawn)
	return result


func _interpolated_hunters() -> Array:
	if _snapshots.is_empty():
		return []

	var pair := _interpolation_pair()
	var from_data: Dictionary = pair["from"]
	var alpha: float = pair["alpha"]

	var result: Array = []
	for hunter in pair["to"].get("hunters", []):
		var id: int = hunter["id"]
		if id == local_id:
			# O meu não é interpolado: é previsto, senão eu sentiria o atraso
			# do meu próprio teclado em tudo que faço.
			result.append(_with_roster(_predicted.to_dict()))
			continue

		var earlier := _find_by_id(from_data.get("hunters", []), id)
		var drawn: Dictionary = hunter.duplicate()
		if not earlier.is_empty():
			drawn["pos"] = (earlier["pos"] as Vector2).lerp(hunter["pos"], alpha)
			drawn["facing"] = lerp_angle(earlier["facing"], hunter["facing"], alpha)
		result.append(_with_roster(drawn))
	return result


## Devolve o Caçador com nome e arma colados de volta, vindos da lista.
func _with_roster(hunter: Dictionary) -> Dictionary:
	var entry: Dictionary = _roster.get(hunter["id"], {})
	hunter["name"] = entry.get("name", "")
	hunter["weapon"] = entry.get("weapon", Weapons.SWORD)
	return hunter


func _find_by_id(entries: Array, id: int) -> Dictionary:
	for entry in entries:
		if entry["id"] == id:
			return entry
	return {}


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


## Endereços ---------------------------------------------------------------

## Os endereços IPv4 desta máquina na rede local, para o Anfitrião passar aos
## amigos.
static func local_addresses() -> Array[String]:
	var found: Array[String] = []
	for address in IP.get_local_addresses():
		var text := String(address)
		if text.contains(":"):
			continue  # IPv6
		if text.begins_with("127."):
			continue  # loopback
		found.append(text)
	return found
