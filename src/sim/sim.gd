class_name Sim
extends RefCounted

## A Simulação autoritativa.
##
## Recebe Entradas, avança por Tiques de tamanho fixo e devolve Instantâneos.
## Não sabe desenhar e não sabe falar em rede: quem hospeda roda uma destas,
## quem entra só recebe o que ela produz.
##
## Regra de ouro: nenhum tipo de cena entra aqui. Sem Node, sem Node2D, sem
## CharacterBody2D, sem move_and_slide. Ver
## docs/adr/0001-sim-independente-da-apresentacao.md.

## Chave usada em `hit_ids` para o Behemoth. Negativa para nunca colidir com
## o id de um alvo de treino.
const _BEHEMOTH_HIT_KEY: int = -1

## Entradas ficam numa fila e são consumidas uma por Tique, em ordem. É o que
## garante que o Anfitrião aplique exatamente a mesma sequência que o Cliente
## previu — e, em especial, que uma Esquiva nunca se perca nem vire duas.
const MAX_QUEUED_INPUTS: int = 6

var _tick: int = 0

## id -> HunterState
var _hunters: Dictionary = {}

## id -> Array[HunterInput], ainda não consumidas
var _queues: Dictionary = {}

## id -> HunterInput, a última consumida. Se a fila secar (pacote atrasado), o
## Caçador continua fazendo o que fazia em vez de congelar.
var _last: Dictionary = {}

## Ordem estável de iteração. Dictionary não garante ordem entre máquinas, e a
## Sim precisa ser determinística para que Anfitrião e Cliente concordem.
var _order: Array[int] = []

## Alvos que recebem dano. O boneco de treino some no ticket 11.
var _targets: Array[TargetState] = []

## O Behemoth da Caçada.
var _behemoth: BehemothState = null

## Semente fixa: a IA sorteia o próximo ataque, e um sorteio com semente
## mantém a Caçada reproduzível entre duas execuções iguais.
var _rng := RandomNumberGenerator.new()

## O que aconteceu neste Tique e a Apresentação precisa saber para desenhar
## (números de dano, faíscas). São consumidos: quem lê, esvazia.
var _events: Array[Dictionary] = []

## Projéteis vivos (Câmara de Magma):
## {pos, dir, speed, traveled, max_range, radius, blast, damage, stagger, owner}
var _projectiles: Array[Dictionary] = []


## Sem tipo de Behemoth, a Arena fica vazia. Quem abre a Caçada escolhe o
## monstro — e uma Arena vazia é o que os testes de movimento precisam para
## medir o que estão medindo em vez de medir uma mordida.
func _init(
	behemoth_type: String = "",
	behemoth_element: Elements.Element = Elements.Element.NEUTRAL
) -> void:
	_rng.seed = 20251009
	if not behemoth_type.is_empty():
		_behemoth = BehemothState.spawn(1, behemoth_type, SimConfig.BEHEMOTH_SPAWN, behemoth_element)
	# O alvo de treino também permanece nas Sims de teste/caçada por
	# compatibilidade enquanto a apresentação só o desenha no modo treinamento.
	_targets.append(TargetState.make(
		1,
		"Boneco de treino",
		SimConfig.DUMMY_POS,
		SimConfig.DUMMY_RADIUS,
		SimConfig.DUMMY_HP
	))


func add_hunter(id: int, display_name: String = "", weapon_id: String = Weapons.SWORD) -> void:
	if _hunters.has(id):
		return
	var hunter := HunterState.new()
	hunter.id = id
	hunter.display_name = display_name
	if Weapons.exists(weapon_id):
		hunter.weapon_id = weapon_id
	_hunters[id] = hunter
	_queues[id] = []
	_last[id] = HunterInput.new()
	_order.append(id)
	_order.sort()


func remove_hunter(id: int) -> void:
	_hunters.erase(id)
	_queues.erase(id)
	_last.erase(id)
	_order.erase(id)


func rename_hunter(id: int, display_name: String) -> void:
	if _hunters.has(id):
		(_hunters[id] as HunterState).display_name = display_name


## Enche o Éter de uma vez. Existe para os testes e para futuros consumíveis;
## em jogo o Éter só vem de acertar Golpes.
func fill_aether(id: int) -> void:
	if _hunters.has(id):
		(_hunters[id] as HunterState).aether = SimConfig.AETHER_MAX


func set_weapon(id: int, weapon_id: String, element: Elements.Element = Elements.Element.NEUTRAL) -> void:
	if not _hunters.has(id):
		return
	var hunter := _hunters[id] as HunterState
	if Weapons.exists(weapon_id):
		hunter.weapon_id = weapon_id
	hunter.element = element


## Nome e arma de cada Caçador. Estáticos, então viajam fora do Instantâneo.
func roster() -> Dictionary:
	var entries: Dictionary = {}
	for id in _order:
		var hunter: HunterState = _hunters[id]
		entries[id] = {"name": hunter.display_name, "weapon": hunter.weapon_id}
	return entries


func has_hunter(id: int) -> bool:
	return _hunters.has(id)


## Enfileira uma Entrada. A fila tem teto: um Cliente adiantado não acumula
## vantagem, só perde as Entradas mais velhas.
func set_input(id: int, input: HunterInput) -> void:
	if not _hunters.has(id):
		return
	var queue: Array = _queues[id]
	queue.append(input)
	while queue.size() > MAX_QUEUED_INPUTS:
		queue.pop_front()


func step(dt: float) -> void:
	for target in _targets:
		target.step(dt)

	# O pouco do mundo que a máquina de estados do Caçador enxerga: a posição
	# do Behemoth, para o Gancho. Só o Anfitrião tem isto; a predição passa
	# vazio e o Instantâneo corrige.
	var world := {}
	if _behemoth != null and _behemoth.is_alive():
		world = {
			"has_behemoth": true,
			"behemoth_pos": _behemoth.pos,
			"behemoth_radius": _behemoth.radius,
		}

	for id in _order:
		var hunter: HunterState = _hunters[id]
		_step_hunter(hunter, _next_input(id), dt, world)
		# O acerto é resolvido depois do passo, com o Golpe já na fase em que
		# de fato está. Só o Anfitrião roda isto: o Cliente nunca decide dano.
		if hunter.is_attack_active():
			_resolve_attack(hunter)
		if hunter.spin_strike:
			_resolve_spin(hunter)
		if hunter.wants_projectile:
			hunter.wants_projectile = false
			_spawn_projectile(hunter)
		if hunter.special_fired:
			hunter.special_fired = false
			_events.append({"type": "special", "hunter": hunter.id, "weapon": hunter.weapon_id})

	_step_projectiles(dt)

	if _behemoth != null:
		BehemothStep.step(_behemoth, _hunter_list(), _rng, dt, _events)
		# A IA também desloca o corpo (perseguição/investida). Reaplicar a
		# separação depois dela impede o Behemoth de atravessar um caçador parado.
		if _behemoth.is_alive():
			var collision_world := {
				"has_behemoth": true,
				"behemoth_pos": _behemoth.pos,
				"behemoth_radius": _behemoth.radius,
			}
			for id in _order:
				HunterStep.keep_outside_behemoth(_hunters[id] as HunterState, collision_world)
		if BehemothStep.is_attack_active(_behemoth):
			_resolve_behemoth_attack()

	_tick += 1


## O Behemoth da Caçada, ou nulo.
func behemoth() -> BehemothState:
	return _behemoth


func _hunter_list() -> Array:
	var list: Array = []
	for id in _order:
		list.append(_hunters[id])
	return list


## Devolve o que aconteceu desde a última vez e esvazia a lista. Chamado uma
## vez por Instantâneo enviado, para que nenhum evento se perca nem se repita.
func take_events() -> Array:
	var events := _events
	_events = []
	return events


## O Instantâneo do mundo.
##
## `full_for_id` recebe o estado completo; todos os outros recebem só o que é
## preciso para desenhá-los. Quem roda a predição precisa do seu próprio
## estado inteiro, e de mais ninguém — mandar tudo de todos estourava o MTU.
##
## Zero significa "todos completos". Nenhum Caçador tem id zero (ids de rede
## começam em 1), então o valor é livre para servir de atalho aos testes e a
## quem quiser o estado inteiro do mundo.
func snapshot(full_for_id: int = 0) -> Dictionary:
	var hunters: Array = []
	for id in _order:
		var hunter: HunterState = _hunters[id]
		var full := full_for_id == 0 or id == full_for_id
		hunters.append(hunter.to_dict() if full else hunter.to_view_dict())
	var targets: Array = []
	for target in _targets:
		targets.append(target.to_dict())
	var payload := {
		"tick": _tick,
		"hunters": hunters,
		"targets": targets,
	}
	if not _projectiles.is_empty():
		var shots: Array = []
		for projectile in _projectiles:
			shots.append({"pos": projectile["pos"], "radius": projectile["radius"]})
		payload["projectiles"] = shots
	if _behemoth != null:
		payload["behemoth"] = _behemoth.to_dict()
	return payload


func _resolve_attack(hunter: HunterState) -> void:
	var move := hunter.current_move()

	if _behemoth != null and _behemoth.is_alive() and not hunter.hit_ids.has(_BEHEMOTH_HIT_KEY):
		if Combat.hits(hunter.pos, hunter.facing, move, _behemoth.pos, _behemoth.radius):
			hunter.hit_ids.append(_BEHEMOTH_HIT_KEY)
			_hit_behemoth(hunter, move)

	for target in _targets:
		if not target.is_alive() or hunter.hit_ids.has(target.id):
			continue
		if not Combat.hits(hunter.pos, hunter.facing, move, target.pos, target.radius):
			continue

		# Um Golpe acerta cada alvo no máximo uma vez, por mais quadros que a
		# fase Ativa dure. Sem isto, um Golpe lento tiraria dez vezes mais.
		hunter.hit_ids.append(target.id)

		var amount := Combat.damage(move)
		target.take_damage(amount)
		hunter.aether = minf(SimConfig.AETHER_MAX, hunter.aether + float(move["aether"]))
		_events.append({
			"type": "hit",
			"pos": Combat.impact_point(hunter.pos, target.pos, target.radius),
			"amount": amount,
			"hunter": hunter.id,
			"move": move["name"],
		})
		_on_hit_connected(hunter)


## Um Golpe conectou no Behemoth: Vida, Parte e Atordoamento são medidores
## separados, todos alimentados pelo mesmo acerto — e a Parte atingida depende
## de onde o Caçador estava em relação à frente do monstro.
func _hit_behemoth(hunter: HunterState, move: Dictionary) -> void:
	# Golpes com escala travada no estado: a Rajada/Estouro multiplicam por
	# munição engolida; o Golpe de Corrente soma por pip gasto.
	var move_eff := move
	if move.get("blast", false):
		move_eff = move.duplicate()
		var shots := maxi(1, hunter.blast_ammo)
		move_eff["damage"] = float(move["damage"]) * shots
		move_eff["stagger"] = float(move["stagger"]) * shots
	elif move.get("chain", false):
		move_eff = move.duplicate()
		move_eff["damage"] = float(move["damage"]) + SimConfig.CHAIN_SLAM_DAMAGE_PER_PIP * hunter.slam_pips
		move_eff["stagger"] = float(move["stagger"]) + SimConfig.CHAIN_SLAM_STAGGER_PER_PIP * hunter.slam_pips

	var damage_type := Weapons.damage_type(hunter.weapon_id)
	var part := Combat.part_hit(_behemoth, hunter.pos)
	var staggered := BehemothStep.is_staggered(_behemoth)
	var buff := HunterStep.buff_multiplier(hunter)
	var dealt := Combat.damage_against(
		move_eff, damage_type, hunter.element, _behemoth.element, part, staggered, buff
	)

	# Armadura (Bastião): a placa inteira segura o grosso do dano à Vida, mas
	# sempre VAZA uma fração — nunca zero, por decisão do usuário. A Parte (a
	# própria placa) apanha cheio.
	var to_body := dealt
	if not part.is_empty() and part.get("armored", false) and not part["broken"]:
		to_body = dealt * SimConfig.ARMOR_LEAK

	_behemoth.take_damage(to_body)
	BehemothStep.add_threat(_behemoth, hunter.id, to_body)
	hunter.aether = minf(SimConfig.AETHER_MAX, hunter.aether + float(move["aether"]))

	if not part.is_empty() and not part["broken"]:
		part["hp"] = maxf(0.0, float(part["hp"]) - dealt * float(move["part"]))
		if float(part["hp"]) <= 0.0:
			part["broken"] = true
			# A quebra premia o foco com um empurrão enorme no medidor.
			BehemothStep.add_stagger(
				_behemoth,
				_behemoth.stagger_threshold * SimConfig.PART_BREAK_STAGGER_FRACTION,
				_events
			)
			# Algumas quebras pioram um ataque do monstro para sempre (a Carapaça
			# do Bastião atrasa o Rolamento). Dado, não código.
			var penalty: Dictionary = part.get("break_penalty", {})
			if not penalty.is_empty():
				_behemoth.cooldown_penalty[penalty["attack"]] = float(penalty["extra"])
			_events.append({
				"type": "part_break",
				"pos": _behemoth.pos,
				"part": part["name"],
				"severed": part["severable"],
				"hunter": hunter.id,
			})

	# Contrato de interrupção: um impacto de Atordoamento alto na janela
	# interrompível do Preparo CANCELA o ataque (boop). Quando o boop acontece,
	# a energia do golpe vai nele — essa pancada não soma no medidor (regra
	# provisória, para boop e queda não saírem juntos do mesmo golpe).
	var stagger_gain := Combat.stagger_from(move_eff, damage_type)
	if not BehemothStep.try_interrupt(_behemoth, stagger_gain, _events):
		BehemothStep.add_stagger(_behemoth, stagger_gain, _events)

	# O número mostrado é o que entrou na VIDA: contra a armadura ele despenca,
	# e é assim que o jogador descobre a placa sem ler manual.
	_events.append({
		"type": "hit",
		"pos": Combat.impact_point(hunter.pos, _behemoth.pos, _behemoth.radius),
		"amount": to_body,
		"hunter": hunter.id,
		"move": move["name"],
		"part": part.get("id", ""),
		"element": int(hunter.element),
	})

	_on_hit_connected(hunter)


## O ataque do Behemoth contra os Caçadores. Invulnerável não leva, e cada
## Caçador leva no máximo uma vez por ataque.
func _resolve_behemoth_attack() -> void:
	var attack := _behemoth.current_attack()
	if attack.is_empty():
		return
	var shape: Dictionary = attack["shape"]
	var amount := float(attack["damage"]) * BehemothStep.damage_multiplier(_behemoth)

	for id in _order:
		var hunter: HunterState = _hunters[id]
		if _behemoth.hit_ids.has(id):
			continue
		if not Combat.shape_hits(
			_behemoth.pos, _behemoth.facing, shape, _behemoth.radius,
			hunter.pos, SimConfig.HUNTER_RADIUS
		):
			continue

		# Marcado mesmo quando a Invulnerabilidade segura o dano: um rolamento
		# bem no tempo atravessa o ataque inteiro, não só um quadro dele.
		_behemoth.hit_ids.append(id)
		if not HunterStep.take_hit(hunter, amount, _behemoth.pos, float(attack["knockback"])):
			continue
		# Conectar e machucar de verdade: quem atravessou com a Esquiva deixa
		# o ataque como erro — e erro abre a janela de punição estendida.
		_behemoth.attack_connected = true

		# O Elemento do ataque (o do Behemoth, salvo ataque que diga outro)
		# acumula Aflição em quem foi atingido de verdade.
		var element := int(attack.get("element", int(_behemoth.element))) as Elements.Element
		var triggered := Afflictions.add_buildup(hunter, element)
		if not triggered.is_empty():
			_events.append({
				"type": "affliction",
				"pos": hunter.pos,
				"hunter": hunter.id,
				"name": triggered,
				"element": int(element),
			})

		_events.append({
			"type": "hurt",
			"pos": hunter.pos,
			"amount": amount,
			"hunter": hunter.id,
			"move": attack["name"],
		})


func _next_input(id: int) -> HunterInput:
	var queue: Array = _queues[id]
	if not queue.is_empty():
		var input: HunterInput = queue.pop_front()
		_last[id] = input
		return input

	# Fila vazia: repete a última Entrada, mas sem os pedidos de um Tique
	# (Esquiva, Golpes, Especial) — repeti-los viraria rajada. `heavy_held` é
	# contínuo como o `sprint` e persiste, para a carga não cair com a rede.
	var previous: HunterInput = _last[id]
	return HunterInput.make(
		previous.move, previous.aim, previous.seq, previous.sprint,
		false, false, false, false, previous.heavy_held, false
	)


func _step_hunter(hunter: HunterState, input: HunterInput, dt: float, world: Dictionary) -> void:
	HunterStep.step(hunter, input, dt, world)
	hunter.last_input_seq = input.seq


## Um tick da Dança da Ceifadora: acerta tudo em volta, uma vez por tick — o
## limite de um-acerto-por-Golpe não se aplica, o giro é feito de muitos ticks.
func _resolve_spin(hunter: HunterState) -> void:
	var special := Weapons.special(hunter.weapon_id)
	if special.get("type", "") != "reaper":
		return
	var spin_move := {
		"name": special["name"],
		"damage": float(special["damage"]),
		"stagger": float(special["stagger"]),
		"part": float(special["part"]),
		"aether": 0.0,
		"range": float(special["range"]),
		"arc": TAU,
	}
	if _behemoth != null and _behemoth.is_alive():
		if Combat.hits(hunter.pos, hunter.facing, spin_move, _behemoth.pos, _behemoth.radius):
			_hit_behemoth(hunter, spin_move)


## Efeitos "ao conectar" das armas: o Momentum das Lâminas e a Onda de Valor
## da Espada. Só o Anfitrião roda isto — conectar é decisão dele.
func _on_hit_connected(hunter: HunterState) -> void:
	if hunter.weapon_id == Weapons.BLADES and hunter.state == HunterState.State.ATTACK \
			and hunter.attack_kind == int(Weapons.Kind.LIGHT) \
			and hunter.pips < SimConfig.MOMENTUM_MAX_PIPS:
		hunter.momentum += SimConfig.MOMENTUM_PER_HIT
		while hunter.momentum >= SimConfig.MOMENTUM_PIP and hunter.pips < SimConfig.MOMENTUM_MAX_PIPS:
			hunter.momentum -= SimConfig.MOMENTUM_PIP
			hunter.pips += 1
		if hunter.pips >= SimConfig.MOMENTUM_MAX_PIPS:
			hunter.momentum = 0.0

	# Overdrive clássico: durante o Valor, cada Golpe que conecta emite uma
	# onda com o Elemento da arma.
	if hunter.weapon_id == Weapons.SWORD and hunter.valor_time > 0.0:
		_projectiles.append({
			"kind": "wave",
			"pos": hunter.pos,
			"dir": Vector2.RIGHT.rotated(hunter.facing),
			"speed": SimConfig.VALOR_WAVE_SPEED,
			"traveled": 0.0,
			"max_range": SimConfig.VALOR_WAVE_RANGE,
			"radius": 12.0,
			"damage": SimConfig.VALOR_WAVE_DAMAGE,
			"stagger": SimConfig.VALOR_WAVE_STAGGER,
			"element": int(hunter.element),
			"owner": hunter.id,
		})


## Câmara de Magma: nasce no Caçador, viaja na direção da mira e explode no
## primeiro impacto ou no fim do alcance.
func _spawn_projectile(hunter: HunterState) -> void:
	var special := Weapons.special(hunter.weapon_id)
	if special.get("type", "") != "magma":
		return
	_projectiles.append({
		"pos": hunter.pos,
		"dir": Vector2.RIGHT.rotated(hunter.facing),
		"speed": float(special["speed"]),
		"traveled": 0.0,
		"max_range": float(special["range"]),
		"radius": 18.0,
		"blast": float(special["radius"]),
		"damage": float(special["damage"]),
		"stagger": float(special["stagger"]),
		"owner": hunter.id,
	})


func _step_projectiles(dt: float) -> void:
	var alive: Array[Dictionary] = []
	for projectile in _projectiles:
		var advance: float = float(projectile["speed"]) * dt
		projectile["pos"] = (projectile["pos"] as Vector2) + (projectile["dir"] as Vector2) * advance
		projectile["traveled"] = float(projectile["traveled"]) + advance

		var hit := false
		if _behemoth != null and _behemoth.is_alive():
			var reach: float = _behemoth.radius + float(projectile["radius"])
			hit = (_behemoth.pos - (projectile["pos"] as Vector2)).length_squared() <= reach * reach

		if hit or float(projectile["traveled"]) >= float(projectile["max_range"]):
			# A Onda de Valor acerta direto e morre; expirando no ar, só some.
			# O Magma sempre estoura, mesmo sem alvo.
			if String(projectile.get("kind", "magma")) == "wave":
				if hit:
					_wave_hit(projectile)
			else:
				_explode_projectile(projectile)
			continue
		alive.append(projectile)
	_projectiles = alive


## A Onda de Valor: dano direto pequeno com o Elemento da arma — entra na
## Oposição, então a preparação do lobby também vale à distância.
func _wave_hit(projectile: Dictionary) -> void:
	if _behemoth == null or not _behemoth.is_alive():
		return
	var element := int(projectile["element"]) as Elements.Element
	var amount := float(projectile["damage"]) * Elements.damage_multiplier(element, _behemoth.element)
	if BehemothStep.is_staggered(_behemoth):
		amount *= SimConfig.STAGGERED_DAMAGE_MULT
	_behemoth.take_damage(amount)
	BehemothStep.add_threat(_behemoth, int(projectile["owner"]), amount)
	BehemothStep.add_stagger(_behemoth, float(projectile["stagger"]), _events)
	_events.append({
		"type": "hit",
		"pos": _behemoth.pos,
		"amount": amount,
		"hunter": int(projectile["owner"]),
		"move": "Onda de Valor",
		"part": "",
		"element": int(element),
	})


func _explode_projectile(projectile: Dictionary) -> void:
	var center: Vector2 = projectile["pos"]
	_events.append({"type": "explosion", "pos": center, "radius": float(projectile["blast"])})

	if _behemoth == null or not _behemoth.is_alive():
		return
	var reach: float = _behemoth.radius + float(projectile["blast"])
	if (_behemoth.pos - center).length_squared() > reach * reach:
		return

	# A explosão é crua de propósito: sem Parte, sem Tipo, sem Oposição — um
	# estouro de Impacto puro que existe para derrubar, não para decepar.
	var amount: float = float(projectile["damage"])
	if BehemothStep.is_staggered(_behemoth):
		amount *= SimConfig.STAGGERED_DAMAGE_MULT
	_behemoth.take_damage(amount)
	BehemothStep.add_threat(_behemoth, int(projectile["owner"]), amount)
	# A explosão é o boop clássico à distância: tenta interromper antes de
	# alimentar o medidor.
	var blast_stagger: float = float(projectile["stagger"])
	if not BehemothStep.try_interrupt(_behemoth, blast_stagger, _events):
		BehemothStep.add_stagger(_behemoth, blast_stagger, _events)
	_events.append({
		"type": "hit",
		"pos": _behemoth.pos,
		"amount": amount,
		"hunter": int(projectile["owner"]),
		"move": "Câmara de Magma",
		"part": "",
		"element": int(Elements.Element.NEUTRAL),
	})
