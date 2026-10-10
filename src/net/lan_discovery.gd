class_name LanDiscovery
extends Node

## Descoberta de salas na rede local, por UDP broadcast.
##
## Não existe servidor de matchmaking neste projeto e não vamos inventar um: o
## Anfitrião grita na rede local "tem sala aqui" uma vez por segundo, e quem
## está procurando escuta. Fora da rede local isso não alcança — por isso a
## entrada manual por endereço continua sempre visível na tela de busca.
##
## Mora fora do NetGame de propósito: o NetGame fala ENet e é o adaptador da
## Caçada; este arquivo fala UDP solto e só serve para ACHAR o Anfitrião. Um
## não precisa saber do outro.
##
## O anúncio é dado puro (JSON): nome da sala, quantos Caçadores, qual Behemoth
## e a porta do jogo. Nada do estado da Caçada viaja aqui.

signal rooms_changed

## Porta só da descoberta. Diferente da porta do jogo (NetGame.DEFAULT_PORT)
## para o anúncio e a partida nunca disputarem o mesmo socket.
const DISCOVERY_PORT: int = 7778

## Assinatura do pacote. Sem ela, qualquer broadcast perdido na rede viraria
## uma sala fantasma na lista.
const MAGIC: String = "dauntless-lite"
const PROTOCOL: int = 1

const BEACON_INTERVAL: float = 1.0

## Uma sala que parou de anunciar some da lista depois disso. Três batidas
## perdidas: tolera um pacote caído sem deixar sala morta na tela.
const ROOM_TIMEOUT: float = 3.5

## Para onde o anúncio vai. O endereço de loopback entra junto porque o
## caminho mais comum de teste é Anfitrião e Cliente na MESMA máquina, e nem
## todo sistema entrega o broadcast a si mesmo.
const BEACON_TARGETS: Array[String] = ["255.255.255.255", "127.0.0.1"]

var _beacon: PacketPeerUDP = null
var _listener: PacketPeerUDP = null
var _announcement: Dictionary = {}
var _countdown: float = 0.0

## Identidade sorteada da sala. O MESMO anúncio chega por dois caminhos (o
## broadcast da rede e o atalho de loopback), com endereços de origem
## diferentes; sem uma identidade própria a mesma sala apareceria duas vezes
## na lista de quem está na máquina do Anfitrião.
var _session: int = 0

## "ip:porta" -> dados da sala, com a hora local da última batida.
var _rooms: Dictionary = {}


## Anfitrião ---------------------------------------------------------------

## Começa (ou atualiza) o anúncio desta sala. Chamar de novo com dados novos
## é como se muda o nome da sala ou a contagem de Caçadores.
func advertise(announcement: Dictionary) -> void:
	_announcement = announcement.duplicate()
	if _beacon != null:
		return
	_session = randi() & 0x7fffffff
	_beacon = PacketPeerUDP.new()
	# Precisa de uma porta local para poder enviar; 0 = qualquer uma livre.
	_beacon.bind(0)
	_beacon.set_broadcast_enabled(true)
	_countdown = 0.0


func stop_advertising() -> void:
	if _beacon == null:
		return
	_beacon.close()
	_beacon = null
	_announcement = {}


func is_advertising() -> bool:
	return _beacon != null


## Quem busca --------------------------------------------------------------

## Abre o ouvido na porta de descoberta. Devolve texto de erro, ou vazio.
func listen() -> String:
	if _listener != null:
		return ""
	var socket := PacketPeerUDP.new()
	var error := socket.bind(DISCOVERY_PORT, "*")
	if error != OK:
		return "Não foi possível escutar a rede local na porta %d (erro %d)." % [
			DISCOVERY_PORT, error
		]
	_listener = socket
	_rooms.clear()
	return ""


func stop_listening() -> void:
	if _listener == null:
		return
	_listener.close()
	_listener = null
	_rooms.clear()


func is_listening() -> bool:
	return _listener != null


## As salas vistas agora, da mais recente para a mais antiga.
func rooms() -> Array:
	var found: Array = []
	for key in _rooms.keys():
		found.append(_rooms[key])
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("room", "")) < String(b.get("room", ""))
	)
	return found


## Passo -------------------------------------------------------------------

func _process(delta: float) -> void:
	if _beacon != null:
		_countdown -= delta
		if _countdown <= 0.0:
			_send_beacon()
			_countdown = BEACON_INTERVAL
	if _listener != null:
		var changed := _drain()
		if _expire():
			changed = true
		if changed:
			rooms_changed.emit()


func _send_beacon() -> void:
	var payload := _announcement.duplicate()
	payload["magic"] = MAGIC
	payload["protocol"] = PROTOCOL
	payload["session"] = _session
	var bytes := JSON.stringify(payload).to_utf8_buffer()
	for target in BEACON_TARGETS:
		_beacon.set_dest_address(target, DISCOVERY_PORT)
		_beacon.put_packet(bytes)


func _drain() -> bool:
	var changed := false
	while _listener.get_available_packet_count() > 0:
		var bytes := _listener.get_packet()
		var address := _listener.get_packet_ip()
		var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if not (parsed is Dictionary):
			continue
		var data: Dictionary = parsed
		if String(data.get("magic", "")) != MAGIC:
			continue
		if int(data.get("protocol", 0)) != PROTOCOL:
			continue

		var port := int(data.get("port", 0))
		if port <= 0:
			continue
		# A identidade da sala manda; o endereço é só por onde ela chegou.
		var session := int(data.get("session", 0))
		var key := "s%d" % session if session != 0 else "%s:%d" % [address, port]
		var room: Dictionary = data.duplicate()
		room["address"] = address
		room["seen"] = _now()

		# O mesmo anúncio chega pelo broadcast e pelo loopback. Fica valendo o
		# endereço que um amigo consegue usar, não o 127.0.0.1.
		var known: Dictionary = _rooms.get(key, {})
		var old_address := String(known.get("address", ""))
		if address == "127.0.0.1" and not old_address.is_empty() and old_address != "127.0.0.1":
			room["address"] = old_address

		if known.is_empty() or not _same_room(known, room):
			changed = true
		_rooms[key] = room
	return changed


func _expire() -> bool:
	var deadline := _now() - ROOM_TIMEOUT
	var dead: Array = []
	for key in _rooms.keys():
		if float((_rooms[key] as Dictionary).get("seen", 0.0)) < deadline:
			dead.append(key)
	for key in dead:
		_rooms.erase(key)
	return not dead.is_empty()


## Duas batidas da mesma sala só mudam a tela se algo visível mudou; assim a
## lista não se reconstrói uma vez por segundo embaixo do clique do jogador.
func _same_room(old: Dictionary, fresh: Dictionary) -> bool:
	for field in ["room", "hunters", "max", "behemoth", "behemoth_name", "variant", "address"]:
		if old.get(field, null) != fresh.get(field, null):
			return false
	return true


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
