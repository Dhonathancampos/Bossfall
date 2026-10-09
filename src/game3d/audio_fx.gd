class_name AudioFx
extends Node

## Os sons do jogo. Lê os mesmos eventos e Instantâneos que a Apresentação e
## toca o som certo — não decide nada, como toda a camada de apresentação.
##
## Cada .wav nasce de tools/sfx/generate.py (asset é código). Os sons chegam
## por dois caminhos: eventos da Sim (acertos, quebras, Aflições) e transições
## de estado observadas nos Instantâneos (Fúria, queda, morte, Esquiva).

## Volume por som, em dB. Moderados de propósito: som alto cansa rápido.
const VOLUMES: Dictionary = {
	"swing": -14.0,
	"hit": -8.0,
	"hit_blunt": -7.0,
	"hurt": -7.0,
	"dodge": -12.0,
	"roar": -6.0,
	"stagger_fall": -6.0,
	"part_break": -6.0,
	"affliction": -9.0,
	"special": -8.0,
	"death": -6.0,
	"click": -10.0,
}

## Vários tocadores para os sons se sobreporem (um combo não engole o rugido).
const POOL_SIZE: int = 10

var _net: NetGame
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0

## Último estado local visto, para detectar transições do próprio Caçador.
var _hunter_state: int = -1

## O golpe em si, não só o estado: num combo o estado fica em ATTACK e cada
## golpe encadeado também merece o seu swing (achado da revisão).
var _hunter_attack: Vector2i = Vector2i(-1, -1)


func setup(net: NetGame) -> void:
	_net = net
	_net.events_happened.connect(_on_events)


func _ready() -> void:
	for key in VOLUMES:
		var path := "res://assets/sfx/%s.wav" % key
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
	for _i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## Toca um som com uma variação leve de tom, para repetição não soar robótica.
func play_sound(key: String, pitch_jitter: float = 0.06) -> void:
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.volume_db = float(VOLUMES.get(key, -10.0))
	player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	player.play()


## Eventos da Sim ------------------------------------------------------------

func _on_events(events: Array) -> void:
	for event in events:
		match String(event.get("type", "")):
			"hit":
				# O Martelo soa fundo; o resto, carnudo.
				var blunt := _weapon_of(int(event.get("hunter", 0))) == Weapons.HAMMER
				play_sound("hit_blunt" if blunt else "hit")
			"hurt":
				play_sound("hurt")
			"part_break":
				play_sound("part_break", 0.03)
			"affliction":
				play_sound("affliction", 0.03)
			"special":
				play_sound("special", 0.02)
			# Contrato de combate: o Behemoth agora ANUNCIA as viradas — a
			# apresentação reage a eventos em vez de adivinhar por polling.
			"enraged":
				play_sound("roar", 0.02)
			"staggered":
				play_sound("stagger_fall", 0.02)
			"interrupt":
				play_sound("stagger_fall", 0.06)
			"behemoth_died":
				play_sound("death", 0.0)


func _weapon_of(id: int) -> String:
	for hunter in _net.view_hunters():
		if int(hunter.get("id", 0)) == id:
			return String(hunter.get("weapon", Weapons.SWORD))
	return Weapons.SWORD


## Transições de estado -------------------------------------------------------

func _process(_delta: float) -> void:
	if _net == null or not _net.is_running():
		return

	# Fúria, queda e morte do Behemoth chegam por evento (contrato de
	# combate); aqui sobra só o que é local e previsto: o próprio Caçador.

	# Só o próprio Caçador: ouvir o swing dos outros de longe confundiria
	# mais do que informaria enquanto não há som posicional.
	for hunter in _net.view_hunters():
		if int(hunter.get("id", 0)) != _net.local_id:
			continue
		var hunter_state := int(hunter.get("state", -1))
		var attack := Vector2i(int(hunter.get("attack_kind", -1)), int(hunter.get("attack_index", -1)))
		var attacking := hunter_state == int(HunterState.State.ATTACK)
		if hunter_state != _hunter_state:
			if hunter_state == int(HunterState.State.DODGE):
				play_sound("dodge")
			elif attacking:
				play_sound("swing")
			_hunter_state = hunter_state
		elif attacking and attack != _hunter_attack:
			# Mesmo estado, golpe novo: o combo encadeou.
			play_sound("swing")
		_hunter_attack = attack if attacking else Vector2i(-1, -1)
		break
