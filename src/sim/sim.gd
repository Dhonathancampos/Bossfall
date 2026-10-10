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
##
## ## Fases (lobby)
##
## A Caçada tem três fases explícitas: LOBBY (todo mundo se arruma e declara
## "pronto"), HUNT (o Behemoth está na Arena) e RESULT (acabou, com o resumo
## por Caçador). O caminho antigo — hospedar já entra na Caçada — continua
## valendo: só quem pede `start_in_lobby` nasce em LOBBY.

## Chave usada em `hit_ids` para o Behemoth. Negativa para nunca colidir com
## o id de um alvo de treino.
const _BEHEMOTH_HIT_KEY: int = -1

## Entradas ficam numa fila e são consumidas uma por Tique, em ordem. É o que
## garante que o Anfitrião aplique exatamente a mesma sequência que o Cliente
## previu — e, em especial, que uma Esquiva nunca se perca nem vire duas.
const MAX_QUEUED_INPUTS: int = 6

enum Phase {
	## Antes da Caçada: ninguém leva dano, cada Caçador marca "pronto".
	LOBBY,
	## A Caçada em si.
	HUNT,
	## Acabou. `result()` traz o resumo por Caçador.
	RESULT,
}

var _tick: int = 0

var _phase: Phase = Phase.HUNT

## O Behemoth escolhido para quando a Caçada começar (modo lobby).
var _pending_behemoth: String = ""
var _pending_element: Elements.Element = Elements.Element.NEUTRAL

## Resumo da Caçada, preenchido ao entrar em RESULT.
var _result: Dictionary = {}

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

## Projéteis vivos. Todos trazem `kind`, que é o que a Apresentação usa para
## desenhar machado girando, míssil, bala, salva, magma ou onda.
var _projectiles: Array[Dictionary] = []


## Sem tipo de Behemoth, a Arena fica vazia. Quem abre a Caçada escolhe o
## monstro — e uma Arena vazia é o que os testes de movimento precisam para
## medir o que estão medindo em vez de medir uma mordida.
##
## `start_in_lobby` segura o nascimento do Behemoth até `start_hunt()`.
func _init(
	behemoth_type: String = "",
	behemoth_element: Elements.Element = Elements.Element.NEUTRAL,
	start_in_lobby: bool = false
) -> void:
	_rng.seed = 20251009
	_pending_behemoth = behemoth_type
	_pending_element = behemoth_element
	if start_in_lobby:
		_phase = Phase.LOBBY
	elif not behemoth_type.is_empty():
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
	set_aether(id, SimConfig.AETHER_MAX)


## O medidor num valor exato. Existe pelo mesmo motivo de `fill_aether`: os
## limiares da Conversão Aetérica (10/33/66/90%) precisam ser verificáveis sem
## coreografar minutos de acertos.
func set_aether(id: int, amount: float) -> void:
	if _hunters.has(id):
		(_hunters[id] as HunterState).aether = clampf(amount, 0.0, SimConfig.AETHER_MAX)


func set_weapon(id: int, weapon_id: String, element: Elements.Element = Elements.Element.NEUTRAL) -> void:
	if not _hunters.has(id):
		return
	var hunter := _hunters[id] as HunterState
	if Weapons.exists(weapon_id):
		hunter.weapon_id = weapon_id
		# Trocar de arma zera a posição no grafo de combo e os recursos da
		# arma anterior: nenhum nó vaza de uma arma para outra.
		hunter.combo_from = -1
		hunter.combo_grace = 0.0
		hunter.combo_effect_used = false
		hunter.attack_kind = int(Weapons.Kind.LIGHT)
		hunter.attack_index = 0
		hunter.mag = SimConfig.REPEATER_MAG
		hunter.empowered_shots = 0
		hunter.fire_cooldown = 0.0
		hunter.pike_ammo = 0
		hunter.brio = 0
		hunter.axe_out = false
	hunter.element = element


## Nome e arma de cada Caçador. Estáticos, então viajam fora do Instantâneo.
func roster() -> Dictionary:
	var entries: Dictionary = {}
	for id in _order:
		var hunter: HunterState = _hunters[id]
		entries[id] = {
			"name": hunter.display_name,
			"weapon": hunter.weapon_id,
			"ready": hunter.ready,
		}
	return entries


func has_hunter(id: int) -> bool:
	return _hunters.has(id)


## Fases da Caçada ---------------------------------------------------------

func phase() -> Phase:
	return _phase


## O "pronto" de um Caçador no lobby. Fora do LOBBY é mudo.
func set_ready(id: int, value: bool) -> void:
	if _phase != Phase.LOBBY or not _hunters.has(id):
		return
	(_hunters[id] as HunterState).ready = value


func is_ready(id: int) -> bool:
	return _hunters.has(id) and (_hunters[id] as HunterState).ready


func all_ready() -> bool:
	if _order.is_empty():
		return false
	for id in _order:
		if not (_hunters[id] as HunterState).ready:
			return false
	return true


## Começa a Caçada: o Behemoth nasce e a fase vira HUNT. Quem pode chamar
## isto é decisão da REDE (só o Anfitrião); a Sim só recusa fora do LOBBY.
## Devolve verdadeiro quando a Caçada de fato começou.
func start_hunt(behemoth_type: String = "", behemoth_element: int = -1) -> bool:
	if _phase != Phase.LOBBY:
		return false
	if not behemoth_type.is_empty():
		_pending_behemoth = behemoth_type
	if behemoth_element >= 0:
		_pending_element = behemoth_element as Elements.Element
	if not _pending_behemoth.is_empty():
		_behemoth = BehemothState.spawn(
			1, _pending_behemoth, SimConfig.BEHEMOTH_SPAWN, _pending_element
		)
	for id in _order:
		var hunter: HunterState = _hunters[id]
		hunter.damage_dealt = 0.0
		hunter.parts_broken = 0
		hunter.interrupts = 0
	_phase = Phase.HUNT
	_events.append({"type": "phase", "phase": "hunt"})
	return true


## O resumo da Caçada: vazio enquanto ela não acabou.
func result() -> Dictionary:
	return _result


func _finish_hunt(outcome: String) -> void:
	if _phase == Phase.RESULT:
		return
	_phase = Phase.RESULT
	var summary: Array = []
	for id in _order:
		var hunter: HunterState = _hunters[id]
		summary.append({
			"id": hunter.id,
			"name": hunter.display_name,
			"weapon": hunter.weapon_id,
			"damage": hunter.damage_dealt,
			"parts_broken": hunter.parts_broken,
			"interrupts": hunter.interrupts,
		})
	_result = {"outcome": outcome, "hunters": summary}
	_events.append({"type": "phase", "phase": "result", "outcome": outcome})


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
	# do Behemoth, para o Gancho e para os predicados de distância do grafo.
	# Só o Anfitrião tem isto; a predição passa vazio e o Instantâneo corrige.
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
		if _phase == Phase.LOBBY:
			continue
		# O acerto é resolvido depois do passo, com o Golpe já na fase em que
		# de fato está. Só o Anfitrião roda isto: o Cliente nunca decide dano.
		if hunter.is_attack_active():
			_resolve_attack(hunter)
		if hunter.spin_strike:
			# O mesmo relógio de pulsos serve à Dança da Ceifadora e aos
			# Golpes multi-hit/canal; o estado diz qual dos dois é.
			if hunter.state == HunterState.State.SPECIAL_SPIN:
				_resolve_spin(hunter)
			elif hunter.state == HunterState.State.ATTACK:
				_resolve_attack(hunter)
		if not hunter.pending_projectile.is_empty():
			_spawn_projectile(hunter, hunter.pending_projectile)
			hunter.pending_projectile = ""
		if hunter.wants_shot:
			hunter.wants_shot = false
			_spawn_bullet(hunter)
		if hunter.wants_axe_recall:
			hunter.wants_axe_recall = false
			_recall_axe(hunter)
		if hunter.just_empowered:
			hunter.just_empowered = false
			_events.append({"type": "empowered", "hunter": hunter.id})
		if hunter.special_fired:
			hunter.special_fired = false
			_events.append({"type": "special", "hunter": hunter.id, "weapon": hunter.weapon_id})

	if _phase == Phase.LOBBY:
		_tick += 1
		return

	_step_projectiles(dt)

	if _behemoth != null:
		_step_wounds(dt)
		var was_alive := _behemoth.is_alive()
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
		if was_alive and not _behemoth.is_alive():
			_finish_hunt("victory")

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
		"phase": int(_phase),
		"hunters": hunters,
		"targets": targets,
	}
	if _phase == Phase.RESULT:
		payload["result"] = _result
	if not _projectiles.is_empty():
		var shots: Array = []
		for projectile in _projectiles:
			shots.append({
				"pos": projectile["pos"],
				"radius": projectile["radius"],
				"kind": String(projectile.get("kind", "magma")),
			})
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

		var amount := Combat.damage(move) * HunterStep.charge_multiplier(hunter)
		target.take_damage(amount)
		hunter.damage_dealt += amount
		_gain_aether(hunter, move)
		_events.append({
			"type": "hit",
			"pos": Combat.impact_point(hunter.pos, target.pos, target.radius),
			"amount": amount,
			"hunter": hunter.id,
			"move": move["name"],
		})
		_on_hit_connected(hunter, move)


## O Éter que um acerto rende.
##
## Regra do Machado: só golpe CARREGADO enche o medidor, e o ganho escala com
## a carga. Nas outras armas o ganho é o do Golpe, como sempre. A regra mora
## num lugar só para não haver duas contas de Éter.
func _gain_aether(hunter: HunterState, move: Dictionary) -> void:
	var gain := float(move.get("aether", 0.0))
	if move.get("chargeable", false):
		if hunter.charge_locked < SimConfig.AXE_CHARGE_METER_MIN:
			return
		gain *= HunterStep.charge_multiplier(hunter)
	hunter.aether = minf(SimConfig.AETHER_MAX, hunter.aether + gain)


## Um Golpe conectou no Behemoth: Vida, Parte, Atordoamento e Ferimento são
## medidores separados, todos alimentados pelo mesmo acerto — e a Parte
## atingida depende de onde o Caçador estava em relação à frente do monstro.
func _hit_behemoth(hunter: HunterState, move: Dictionary) -> void:
	# Golpes com escala travada no estado: a Rajada/Estouro multiplicam por
	# munição engolida; o Golpe de Corrente soma por pip gasto; o Golpe
	# carregado do Machado multiplica pela carga.
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
	elif move.get("chargeable", false) and hunter.charge_locked > 0.0:
		move_eff = move.duplicate()
		var charge := HunterStep.charge_multiplier(hunter)
		move_eff["damage"] = float(move["damage"]) * charge
		move_eff["stagger"] = float(move["stagger"]) * charge

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
	hunter.damage_dealt += to_body
	_gain_aether(hunter, move)

	if not part.is_empty():
		_apply_wound(hunter, part, damage_type, dealt)

	if not part.is_empty() and not part["broken"]:
		part["hp"] = maxf(0.0, float(part["hp"]) - dealt * float(move["part"]))
		if float(part["hp"]) <= 0.0:
			part["broken"] = true
			hunter.parts_broken += 1
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
	if BehemothStep.try_interrupt(_behemoth, stagger_gain, _events):
		hunter.interrupts += 1
	else:
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

	_on_hit_connected(hunter, move)


## FERIMENTO — o modelo FIEL ao rework de abr/2021 -------------------------
##
## Só Perfuração acumula. Ao estourar o limiar, a Parte fica FERIDA por
## WOUND_DURATION com éter vazando — e a Ferida NÃO dá bônus de dano a
## ninguém. Quem EXPLORA a ferida (tira WOUND_HARVEST_TARGET de dano dela
## enquanto está aberta) leva um buff PESSOAL. Decisão registrada no
## MEMORY.md; o híbrido "Ferida dá bônus para o grupo" foi descartado.
func _apply_wound(
	hunter: HunterState,
	part: Dictionary,
	damage_type: Weapons.DamageType,
	dealt: float
) -> void:
	if bool(part.get("wounded", false)):
		# Ferida aberta: todo dano nela conta para quem está colhendo.
		var claim: Dictionary = part["wound_claim"]
		var total := float(claim.get(hunter.id, 0.0)) + dealt
		claim[hunter.id] = total
		if total >= SimConfig.WOUND_HARVEST_TARGET and hunter.wound_buff_time <= 0.0:
			hunter.wound_buff_time = SimConfig.WOUND_BUFF_DURATION
			claim[hunter.id] = 0.0
			_events.append({
				"type": "wound_harvest",
				"pos": _behemoth.pos,
				"hunter": hunter.id,
				"part": part["id"],
			})
		return

	if damage_type != Weapons.DamageType.PIERCE:
		return

	# A perfuração fere a carne POR BAIXO da placa: o acúmulo usa o dano
	# cheio, antes do vazamento de armadura.
	part["wound"] = float(part["wound"]) + dealt * SimConfig.PIERCE_WOUND_RATE
	if float(part["wound"]) < SimConfig.WOUND_THRESHOLD:
		return
	part["wound"] = 0.0
	part["wounded"] = true
	part["wound_time"] = SimConfig.WOUND_DURATION
	part["wound_claim"] = {}
	_events.append({
		"type": "part_wound",
		"pos": _behemoth.pos,
		"part": part["name"],
		"part_id": part["id"],
		"hunter": hunter.id,
	})


## O relógio das Feridas: a aberta fecha no tempo, a parcial decai sozinha.
## Quebrar a Parte NÃO encerra a Ferida (fiel ao rework).
func _step_wounds(dt: float) -> void:
	for part in _behemoth.parts:
		if bool(part.get("wounded", false)):
			part["wound_time"] = maxf(0.0, float(part["wound_time"]) - dt)
			if float(part["wound_time"]) <= 0.0:
				part["wounded"] = false
				part["wound_claim"] = {}
			continue
		if float(part.get("wound", 0.0)) > 0.0:
			part["wound"] = maxf(0.0, float(part["wound"]) - SimConfig.WOUND_DECAY_PER_SECOND * dt)


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
	# (Esquiva, Golpes, Especial). `heavy_held` e `light_held` são contínuos
	# como o `sprint` e persistem — senão a carga do Machado e o tiro contínuo
	# das Repetidoras engasgariam a cada pacote atrasado.
	var previous: HunterInput = _last[id]
	return HunterInput.make(
		previous.move, previous.aim, previous.seq, previous.sprint,
		false, false, false, false, previous.heavy_held, false, previous.light_held
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
func _on_hit_connected(hunter: HunterState, move: Dictionary) -> void:
	if hunter.weapon_id == Weapons.BLADES and hunter.state == HunterState.State.ATTACK \
			and hunter.attack_kind == int(Weapons.Kind.LIGHT) \
			and hunter.pips < SimConfig.MOMENTUM_MAX_PIPS:
		# O nó pode declarar o próprio ganho (a Lâmina Dupla fecha a cadeia
		# com o melhor ganho da arma); sem declaração, o ganho padrão.
		hunter.momentum += float(move.get("momentum", SimConfig.MOMENTUM_PER_HIT))
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
			"name": "Onda de Valor",
			"owner": hunter.id,
		})


## Projéteis ---------------------------------------------------------------

func _spawn_projectile(hunter: HunterState, kind: String) -> void:
	var special := Weapons.special(hunter.weapon_id)
	var dir := Vector2.RIGHT.rotated(hunter.facing)
	match kind:
		"magma":
			_projectiles.append({
				"kind": "magma",
				"pos": hunter.pos, "dir": dir,
				"speed": float(special["speed"]),
				"traveled": 0.0,
				"max_range": float(special["range"]),
				"radius": 18.0,
				"blast": float(special["radius"]),
				"damage": float(special["damage"]),
				"stagger": float(special["stagger"]),
				"name": "Câmara de Magma",
				"owner": hunter.id,
			})
		"brio_wave":
			# A Onda de Brio reusa a infra da Onda de Valor, mas bate forte o
			# bastante para INTERROMPER — é o boop à distância da Espada.
			_projectiles.append({
				"kind": "wave",
				"pos": hunter.pos, "dir": dir,
				"speed": SimConfig.BRIO_WAVE_SPEED,
				"traveled": 0.0,
				"max_range": SimConfig.BRIO_WAVE_RANGE,
				"radius": 14.0,
				"damage": SimConfig.BRIO_WAVE_DAMAGE,
				"stagger": SimConfig.BRIO_WAVE_STAGGER,
				"element": int(hunter.element),
				"name": "Onda de Brio",
				"owner": hunter.id,
			})
		"ruin":
			# Voo da Ruína: vai, acerta uma vez na ida, volta perseguindo o
			# dono e acerta uma vez na volta. Apanhar dá pilha de Determinação.
			_projectiles.append({
				"kind": "ruin",
				"pos": hunter.pos, "dir": dir,
				"speed": float(special["speed"]),
				"traveled": 0.0,
				"max_range": float(special["range"]),
				"radius": float(special["radius"]),
				"damage": float(special["damage"]),
				"stagger": float(special["stagger"]),
				"part": float(special["part"]),
				"name": String(special["name"]),
				"refund": float(special["catch_refund"]),
				"returning": false,
				"connected": false,
				"hit_out": false,
				"hit_back": false,
				"owner": hunter.id,
			})
		"pike_shot":
			var level := maxi(1, hunter.pike_ammo)
			hunter.pike_ammo = 0
			_projectiles.append({
				"kind": "pike_shot",
				"pos": hunter.pos, "dir": dir,
				"speed": float(special["speed"]),
				"traveled": 0.0,
				"max_range": float(special["range"]),
				"radius": float(special["radius"]),
				"damage": float(special["damage_base"]) + float(special["damage_per_level"]) * level,
				"stagger": float(special["stagger_base"]) + float(special["stagger_per_level"]) * level,
				"element": int(hunter.element),
				"name": String(special["name"]),
				"owner": hunter.id,
			})
		"salvo":
			# Empoderada, a Salva sai em leque de três. O empoderamento NÃO é
			# consumido pelo Especial: só os tiros o gastam.
			var count := 1
			var spread := 0.0
			if hunter.empowered_shots > 0:
				count = int(special.get("empowered_count", 3))
				spread = float(special.get("empowered_spread", 0.25))
			for index in count:
				var offset := 0.0
				if count > 1:
					offset = (float(index) - float(count - 1) * 0.5) * spread
				_projectiles.append({
					"kind": "salvo",
					"pos": hunter.pos,
					"dir": Vector2.RIGHT.rotated(hunter.facing + offset),
					"speed": float(special["speed"]),
					"traveled": 0.0,
					"max_range": float(special["range"]),
					"radius": 14.0,
					"blast": float(special["radius"]),
					"damage": float(special["damage"]),
					"stagger": float(special["stagger"]),
					"name": String(special["name"]),
					"owner": hunter.id,
				})


## O tiro das Repetidoras. Empoderado bate mais; o dano cai com a distância,
## e a queda é resolvida no impacto, pelo tanto que o projétil viajou.
func _spawn_bullet(hunter: HunterState) -> void:
	var move := Weapons.move(hunter.weapon_id, Weapons.Kind.LIGHT, 0)
	var damage := float(move["damage"])
	if hunter.empowered_shots > 0:
		hunter.empowered_shots -= 1
		damage *= SimConfig.REPEATER_EMPOWER_MULT
	_projectiles.append({
		"kind": "bullet",
		"pos": hunter.pos,
		"dir": Vector2.RIGHT.rotated(hunter.facing),
		"speed": float(move["projectile_speed"]),
		"traveled": 0.0,
		"max_range": float(move["range"]),
		"radius": float(move["projectile_radius"]),
		"damage": damage,
		"stagger": float(move["stagger"]),
		"part_mult": float(move["part"]),
		"falloff_start": float(move["falloff_start"]),
		"falloff_min": float(move["falloff_min"]),
		"aether": float(move["aether"]),
		"name": String(move["name"]),
		"owner": hunter.id,
	})


## O segundo F com o machado no ar: ele vira e volta antes da hora.
func _recall_axe(hunter: HunterState) -> void:
	for projectile in _projectiles:
		if String(projectile.get("kind", "")) == "ruin" and int(projectile["owner"]) == hunter.id:
			projectile["returning"] = true


func _step_projectiles(dt: float) -> void:
	var alive: Array[Dictionary] = []
	for projectile in _projectiles:
		if String(projectile.get("kind", "")) == "ruin":
			if _step_ruin(projectile, dt):
				alive.append(projectile)
			continue

		var advance: float = float(projectile["speed"]) * dt
		projectile["pos"] = (projectile["pos"] as Vector2) + (projectile["dir"] as Vector2) * advance
		projectile["traveled"] = float(projectile["traveled"]) + advance

		var hit := false
		if _behemoth != null and _behemoth.is_alive():
			var reach: float = _behemoth.radius + float(projectile["radius"])
			hit = (_behemoth.pos - (projectile["pos"] as Vector2)).length_squared() <= reach * reach

		if hit or float(projectile["traveled"]) >= float(projectile["max_range"]):
			match String(projectile.get("kind", "magma")):
				"wave", "pike_shot":
					# Acertam direto e morrem; expirando no ar, só somem.
					if hit:
						_direct_hit(projectile)
				"bullet":
					if hit:
						_bullet_hit(projectile)
				_:
					# Magma e Salva sempre estouram, mesmo sem alvo.
					_explode_projectile(projectile)
			continue
		alive.append(projectile)
	_projectiles = alive


## Voo da Ruína: ida em linha reta, volta perseguindo o dono. Acerta no
## máximo uma vez em cada perna. Apanhar devolve Éter e, se o machado
## conectou, concede uma pilha de Determinação.
## Devolve falso quando o projétil deixa de existir (foi apanhado).
func _step_ruin(projectile: Dictionary, dt: float) -> bool:
	var thrower: HunterState = _hunters.get(int(projectile["owner"]), null)
	var advance: float = float(projectile["speed"]) * dt
	var returning: bool = bool(projectile["returning"])

	if returning and thrower != null:
		var home := thrower.pos - (projectile["pos"] as Vector2)
		projectile["dir"] = home.normalized() if home.length() > 0.001 else Vector2.RIGHT
		if home.length() <= advance + SimConfig.HUNTER_RADIUS + float(projectile["radius"]):
			_catch_axe(projectile, thrower)
			return false

	projectile["pos"] = (projectile["pos"] as Vector2) + (projectile["dir"] as Vector2) * advance
	projectile["traveled"] = float(projectile["traveled"]) + advance

	if _behemoth != null and _behemoth.is_alive():
		var reach: float = _behemoth.radius + float(projectile["radius"])
		var leg := "hit_back" if returning else "hit_out"
		if not bool(projectile[leg]) \
				and (_behemoth.pos - (projectile["pos"] as Vector2)).length_squared() <= reach * reach:
			projectile[leg] = true
			projectile["connected"] = true
			_ruin_hit(projectile)

	if not returning and float(projectile["traveled"]) >= float(projectile["max_range"]):
		projectile["returning"] = true
	# Dono sumiu no meio do voo: o machado some junto, em vez de ficar órfão.
	return thrower != null


func _catch_axe(projectile: Dictionary, thrower: HunterState) -> void:
	thrower.axe_out = false
	thrower.aether = minf(SimConfig.AETHER_MAX, thrower.aether + float(projectile["refund"]))
	if bool(projectile["connected"]):
		HunterStep.grant_determination(thrower)
	_events.append({
		"type": "axe_catch",
		"pos": thrower.pos,
		"hunter": thrower.id,
		"stacks": thrower.det_stacks,
	})


## O machado acertando: passa pelo caminho completo de Parte/Tipo/Oposição,
## como um Golpe — e, portanto, pelo caminho de boop.
func _ruin_hit(projectile: Dictionary) -> void:
	var thrower: HunterState = _hunters.get(int(projectile["owner"]), null)
	if thrower == null:
		return
	_hit_behemoth(thrower, {
		"name": String(projectile["name"]),
		"damage": float(projectile["damage"]),
		"stagger": float(projectile["stagger"]),
		"part": float(projectile["part"]),
		"aether": 0.0,
		"range": 0.0,
		"arc": TAU,
	})


## Acerto direto de projétil (Onda de Valor/Brio, míssil da Lança): dano com
## Elemento, sem Parte e sem Tipo — e passando pelo caminho de boop antes de
## alimentar o medidor, como manda o contrato de combate.
func _direct_hit(projectile: Dictionary) -> void:
	if _behemoth == null or not _behemoth.is_alive():
		return
	var element := int(projectile["element"]) as Elements.Element
	var amount := float(projectile["damage"]) * Elements.damage_multiplier(element, _behemoth.element)
	if BehemothStep.is_staggered(_behemoth):
		amount *= SimConfig.STAGGERED_DAMAGE_MULT
	_behemoth.take_damage(amount)
	var owner_id := int(projectile["owner"])
	BehemothStep.add_threat(_behemoth, owner_id, amount)
	if _hunters.has(owner_id):
		(_hunters[owner_id] as HunterState).damage_dealt += amount

	var stagger := float(projectile["stagger"])
	if BehemothStep.try_interrupt(_behemoth, stagger, _events):
		if _hunters.has(owner_id):
			(_hunters[owner_id] as HunterState).interrupts += 1
	else:
		BehemothStep.add_stagger(_behemoth, stagger, _events)

	_events.append({
		"type": "hit",
		"pos": _behemoth.pos,
		"amount": amount,
		"hunter": owner_id,
		"move": String(projectile.get("name", "")),
		"part": "",
		"element": int(element),
	})


## A bala: queda por distância e, aí sim, o caminho completo de um Golpe —
## Parte, Oposição, armadura do Bastião e Ferimento (Balístico não fere).
func _bullet_hit(projectile: Dictionary) -> void:
	var thrower: HunterState = _hunters.get(int(projectile["owner"]), null)
	if thrower == null:
		return
	var travel := float(projectile["traveled"])
	var fade := 1.0
	var start := float(projectile["falloff_start"])
	if travel > start:
		var span := float(projectile["max_range"]) - start
		fade = lerpf(1.0, float(projectile["falloff_min"]), clampf((travel - start) / span, 0.0, 1.0))
	_hit_behemoth(thrower, {
		"name": String(projectile["name"]),
		"damage": float(projectile["damage"]) * fade,
		"stagger": float(projectile["stagger"]),
		"part": float(projectile["part_mult"]),
		"aether": float(projectile["aether"]),
		"range": 0.0,
		"arc": TAU,
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
	var owner_id := int(projectile["owner"])
	BehemothStep.add_threat(_behemoth, owner_id, amount)
	if _hunters.has(owner_id):
		(_hunters[owner_id] as HunterState).damage_dealt += amount
	# A explosão é o boop clássico à distância: tenta interromper antes de
	# alimentar o medidor. Vale para o Magma e para a Salva das Repetidoras.
	var blast_stagger: float = float(projectile["stagger"])
	if BehemothStep.try_interrupt(_behemoth, blast_stagger, _events):
		if _hunters.has(owner_id):
			(_hunters[owner_id] as HunterState).interrupts += 1
	else:
		BehemothStep.add_stagger(_behemoth, blast_stagger, _events)
	_events.append({
		"type": "hit",
		"pos": _behemoth.pos,
		"amount": amount,
		"hunter": owner_id,
		"move": String(projectile.get("name", "Câmara de Magma")),
		"part": "",
		"element": int(Elements.Element.NEUTRAL),
	})
