class_name BehemothStep
extends RefCounted

## A máquina de estados do Behemoth: perseguir, decidir, preparar, acertar,
## se recuperar — e, agora, ser interrompido.
##
## Só o Anfitrião roda isto. O Cliente recebe o resultado e interpola, então
## aqui não há nada de predição — mas também nada de cena, pelo mesmo motivo de
## sempre: na Onda 2 esta IA atravessa inteira para o 3D.
##
## CONTRATO DE COMBATE (Ordem de reconstrução, item 1):
## - Toda transição de fase de ataque vira um EVENTO da Sim (`behemoth_phase`
##   com windup/active/recover/end), além de `interrupt`, `staggered`,
##   `enraged` e `behemoth_died`. A apresentação reage a eventos; não adivinha
##   transições por polling.
## - Ataques podem declarar `interruptible` nos dados: uma janela no Preparo
##   em que um golpe de Atordoamento alto (a Rajada do Martelo é o caso
##   clássico) CANCELA o ataque e abre uma punição curta (INTERRUPTED).
## - Não existe mais pausa global entre ataques: o ritmo é POR ATAQUE
##   (`post_gap` nos dados) e POR BEHEMOTH (`decision_gap`), com sequências
##   encadeadas pelo cérebro de cada monstro.
##
## GNASHER DE REFERÊNCIA (item 2): `brain: "gnasher"` nos dados troca o
## sorteio ponderado por padrões situacionais — mordida dupla, investida que
## encadeia rabada em quem contorna, pisão como castigo de quem cola, e
## recuperação estendida quando a investida erra. O rng entra só para variar
## entre opções igualmente válidas (a segunda mordida).

## Ângulo (rad) a partir do qual o alvo conta como "atrás" para os padrões.
const BEHIND_ANGLE: float = PI - 0.9

## Quanto tempo colado (em alcance de pisão) transforma o pisão em castigo.
const STICKY_TIME_FOR_STOMP: float = 2.5

## Chance da mordida dupla (sobe em Fúria). Única decisão por sorteio do
## cérebro do Gnasher; o resto é situação.
const DOUBLE_BITE_CHANCE: float = 0.45
const DOUBLE_BITE_CHANCE_ENRAGED: float = 0.7

## Pausa entre passos de uma sequência encadeada (Fúria corta pela metade).
const PLAN_LINK_GAP: float = 0.3


static func step(
	behemoth: BehemothState,
	hunters: Array,
	rng: RandomNumberGenerator,
	dt: float,
	events: Array = []
) -> void:
	if not behemoth.is_alive():
		return

	behemoth.state_time += dt
	behemoth.hit_flash = maxf(0.0, behemoth.hit_flash - dt)
	behemoth.enrage_flash = maxf(0.0, behemoth.enrage_flash - dt)
	behemoth.decision_gap = maxf(0.0, behemoth.decision_gap - dt)
	behemoth.plan_gap = maxf(0.0, behemoth.plan_gap - dt)
	_tick_cooldowns(behemoth, dt)
	_check_enrage(behemoth, events)

	if behemoth.hp <= 0.0:
		behemoth.attack_id = ""
		behemoth.plan.clear()
		_enter(behemoth, BehemothState.State.DEAD)
		events.append({"type": "behemoth_died", "pos": behemoth.pos})
		return

	# O medidor esvazia sozinho (fora da queda): o Atordoamento precisa ser
	# acumulado com pressão constante, não juntado ao longo da luta inteira.
	if behemoth.state != BehemothState.State.STAGGERED:
		behemoth.stagger = maxf(0.0, behemoth.stagger - SimConfig.STAGGER_DECAY_PER_SECOND * dt)

	var target := _pick_target(behemoth, hunters, dt)
	_track_sticky_target(behemoth, target, dt)

	match behemoth.state:
		BehemothState.State.STAGGERED:
			_step_staggered(behemoth)
		BehemothState.State.INTERRUPTED:
			_step_interrupted(behemoth)
		BehemothState.State.WINDUP:
			_step_windup(behemoth, target, dt, events)
		BehemothState.State.ACTIVE:
			_step_active(behemoth, dt, events)
		BehemothState.State.RECOVER:
			_step_recover(behemoth, target, events)
		_:
			_step_chase(behemoth, target, rng, dt, events)


## Perseguir e decidir --------------------------------------------------------

static func _step_chase(
	behemoth: BehemothState,
	target: HunterState,
	rng: RandomNumberGenerator,
	dt: float,
	events: Array
) -> void:
	if target == null:
		return

	var to_target := target.pos - behemoth.pos
	var distance := to_target.length()
	# Alcances de ESCOLHA medidos da borda do corpo, não do centro: com o raio
	# fiel ao modelo (230), medir do centro deixava a mordida (215) literalmente
	# inalcançável — a separação de corpos impede chegar tão perto do centro.
	var edge := distance - behemoth.radius
	_turn_toward(behemoth, to_target.angle(), float(behemoth.data()["turn_speed"]), dt)

	# Sequência pendente: o próximo passo do plano sai assim que a pausa de
	# encadeamento vence — sem passar pela decisão de novo. É o que faz a
	# mordida dupla e o investida→rabada parecerem UM movimento, não dois.
	if not behemoth.plan.is_empty():
		if behemoth.plan_gap > 0.0:
			return
		var next_id: String = behemoth.plan.pop_front()
		var next_attack := Behemoths.attack(behemoth.type_id, next_id)
		var required: String = next_attack.get("requires_part", "")
		if next_attack.is_empty() or (not required.is_empty() and behemoth.is_severed(required)):
			behemoth.plan.clear()
			return
		_begin_attack(behemoth, next_id, events)
		return

	if behemoth.decision_gap > 0.0:
		_approach(behemoth, to_target, distance, dt)
		return

	var plan := _plan(behemoth, target, edge, rng)
	if not plan.is_empty():
		var first: String = plan.pop_front()
		behemoth.plan = plan
		_begin_attack(behemoth, first, events)
		return

	_approach(behemoth, to_target, distance, dt)


static func _approach(behemoth: BehemothState, to_target: Vector2, distance: float, dt: float) -> void:
	# Sem ataque escolhido, aproxima-se até a distância em que gosta de ficar.
	var gap := behemoth.radius + SimConfig.HUNTER_RADIUS + float(behemoth.data()["preferred_gap"])
	if distance <= gap:
		return
	var speed := float(behemoth.data()["move_speed"]) * _speed_multiplier(behemoth)
	behemoth.pos += to_target.normalized() * speed * dt
	_keep_inside_arena(behemoth)


## O plano de ataque: o cérebro do monstro escolhe uma SEQUÊNCIA pela situação.
## `edge` é a distância do alvo à BORDA do corpo (centro − raio).
static func _plan(
	behemoth: BehemothState,
	target: HunterState,
	edge: float,
	rng: RandomNumberGenerator
) -> Array[String]:
	if String(behemoth.data().get("brain", "generic")) == "gnasher":
		return gnasher_plan(behemoth, target, edge, rng)

	# Cérebro genérico (Bastião até ganhar o próprio): um ataque por vez,
	# sorteado por peso entre os válidos — como antes, mas sem pausa global.
	var chosen := _choose_weighted(behemoth, edge, rng)
	var plan: Array[String] = []
	if not chosen.is_empty():
		plan.append(String(chosen["id"]))
	return plan


## Os padrões do Gnasher, público para os testes dirigirem com rng próprio.
##
## Regras em ordem de prioridade (primeira que casa vence); o sorteio só
## decide a VARIAÇÃO dentro de uma regra (mordida simples ou dupla):
## 1. Alvo atrás com a cauda inteira → Rabada.
## 2. Alvo colado há tempo demais → Pisão (o castigo de quem abraça).
## 3. Alvo no alcance da boca → Mordida (às vezes dupla; mais vezes em Fúria).
## 4. Alvo longe → Investida.
static func gnasher_plan(
	behemoth: BehemothState,
	target: HunterState,
	edge: float,
	rng: RandomNumberGenerator
) -> Array[String]:
	var plan: Array[String] = []
	var angle := absf(angle_difference(behemoth.facing, (target.pos - behemoth.pos).angle()))

	var tail := Behemoths.attack(behemoth.type_id, "tail")
	if angle > BEHIND_ANGLE and _usable(behemoth, tail, edge):
		plan.append("tail")
		return plan

	var stomp := Behemoths.attack(behemoth.type_id, "stomp")
	if behemoth.sticky_time >= STICKY_TIME_FOR_STOMP and _usable(behemoth, stomp, edge):
		plan.append("stomp")
		return plan

	var bite := Behemoths.attack(behemoth.type_id, "bite")
	if _usable(behemoth, bite, edge):
		plan.append("bite")
		var chance := DOUBLE_BITE_CHANCE_ENRAGED if behemoth.enraged else DOUBLE_BITE_CHANCE
		if rng.randf() < chance:
			plan.append("bite")
		return plan

	var charge := Behemoths.attack(behemoth.type_id, "charge")
	if _usable(behemoth, charge, edge):
		plan.append("charge")
		return plan

	return plan


## Um ataque está pronto E faz sentido a esta distância da borda do corpo?
static func _usable(behemoth: BehemothState, attack: Dictionary, edge: float) -> bool:
	if attack.is_empty():
		return false
	var required: String = attack.get("requires_part", "")
	if not required.is_empty() and behemoth.is_severed(required):
		return false
	if float(behemoth.cooldowns.get(attack["id"], 0.0)) > 0.0:
		return false
	return edge >= float(attack["min_range"]) and edge <= float(attack["max_range"])


## O sorteio ponderado de antes, para Behemoths sem cérebro próprio.
static func _choose_weighted(
	behemoth: BehemothState,
	edge: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	var ready: Array = []
	var total := 0.0
	for attack in Behemoths.attacks(behemoth.type_id):
		if not _usable(behemoth, attack, edge):
			continue
		ready.append(attack)
		total += float(attack["weight"])

	if ready.is_empty():
		return {}

	var roll := rng.randf() * total
	for attack in ready:
		roll -= float(attack["weight"])
		if roll <= 0.0:
			return attack
	return ready[ready.size() - 1]


## Quanto tempo o alvo está colado (alcance de pisão). Alimenta a regra do
## castigo de quem abraça o monstro.
static func _track_sticky_target(behemoth: BehemothState, target: HunterState, dt: float) -> void:
	if target == null:
		behemoth.sticky_time = 0.0
		return
	var stomp := Behemoths.attack(behemoth.type_id, "stomp")
	var reach := float(stomp.get("max_range", 160.0)) if not stomp.is_empty() else 160.0
	if behemoth.pos.distance_to(target.pos) - behemoth.radius <= reach:
		behemoth.sticky_time += dt
	else:
		behemoth.sticky_time = 0.0


## Fases do ataque ------------------------------------------------------------

static func _begin_attack(behemoth: BehemothState, attack_id: String, events: Array) -> void:
	behemoth.attack_id = attack_id
	behemoth.hit_ids.clear()
	behemoth.attack_connected = false
	behemoth.recovery_bonus = 0.0
	_enter(behemoth, BehemothState.State.WINDUP)
	_emit_phase(events, behemoth, "windup")


static func _step_windup(behemoth: BehemothState, target: HunterState, dt: float, events: Array) -> void:
	var attack := behemoth.current_attack()
	if attack.is_empty():
		_enter(behemoth, BehemothState.State.CHASE)
		return

	# Vira devagar enquanto prepara. É o que permite contornar pelo lado em vez
	# de só andar para trás — e o que faz a leitura do Preparo valer a pena.
	if target != null:
		_turn_toward(behemoth, (target.pos - behemoth.pos).angle(), float(attack["turn_rate"]), dt)

	if behemoth.state_time >= float(attack["windup"]):
		_enter(behemoth, BehemothState.State.ACTIVE)
		_emit_phase(events, behemoth, "active")


static func _step_active(behemoth: BehemothState, dt: float, events: Array) -> void:
	var attack := behemoth.current_attack()
	if attack.is_empty():
		_enter(behemoth, BehemothState.State.CHASE)
		return

	var advance := float(attack["advance"])
	if advance > 0.0:
		behemoth.pos += Vector2.RIGHT.rotated(behemoth.facing) * advance * _speed_multiplier(behemoth) * dt
		_keep_inside_arena(behemoth)

	if behemoth.state_time >= float(attack["active"]):
		# A investida que não acertou NINGUÉM deixa o monstro exposto por mais
		# tempo: a janela de punição clara que o ritmo por Behemoth promete.
		if not behemoth.attack_connected:
			behemoth.recovery_bonus = float(attack.get("whiff_recovery_bonus", 0.0))
		_enter(behemoth, BehemothState.State.RECOVER)
		_emit_phase(events, behemoth, "recover")


static func _step_recover(behemoth: BehemothState, target: HunterState, events: Array) -> void:
	var attack := behemoth.current_attack()
	if attack.is_empty():
		_enter(behemoth, BehemothState.State.CHASE)
		return
	if behemoth.state_time < float(attack["recovery"]) + behemoth.recovery_bonus:
		return

	_emit_phase(events, behemoth, "end")
	_finish_attack(behemoth, attack)

	# Investida que terminou com o alvo nas costas: o Gnasher emenda a Rabada.
	# É padrão, não sorteio — quem contorna a investida aprende a esperar isso.
	if String(behemoth.data().get("brain", "generic")) == "gnasher" \
			and String(attack["id"]) == "charge" and target != null:
		var angle := absf(angle_difference(behemoth.facing, (target.pos - behemoth.pos).angle()))
		var tail := Behemoths.attack(behemoth.type_id, "tail")
		var edge := behemoth.pos.distance_to(target.pos) - behemoth.radius
		if angle > BEHIND_ANGLE and _usable(behemoth, tail, edge):
			behemoth.plan = ["tail"] as Array[String]

	_enter(behemoth, BehemothState.State.CHASE)


## Fecha a contabilidade de um ataque que chegou ao fim (ou foi cancelado):
## recarga individual, penalidades permanentes e o ritmo pós-golpe.
static func _finish_attack(behemoth: BehemothState, attack: Dictionary) -> void:
	var cooldown := float(attack.get("cooldown", 2.0))
	if behemoth.enraged:
		cooldown *= float(behemoth.data()["enrage_cooldown"])
	# Quebras que pioram o ataque para sempre (Carapaça → Rolamento).
	cooldown += float(behemoth.cooldown_penalty.get(behemoth.attack_id, 0.0))
	behemoth.cooldowns[behemoth.attack_id] = cooldown
	behemoth.attack_id = ""

	# O ritmo é por ataque: uma mordida deixa brecha curta, um pisão deixa
	# longa. Em Fúria as brechas encurtam — a pressão tem que ser sentida.
	var gap := float(attack.get("post_gap", float(behemoth.data().get("decision_gap", 0.5))))
	var link := PLAN_LINK_GAP
	if behemoth.enraged:
		gap *= 0.5
		link *= 0.5
	behemoth.decision_gap = gap
	behemoth.plan_gap = link if not behemoth.plan.is_empty() else 0.0


## Interrupção (boop) ----------------------------------------------------------

## Tenta interromper o ataque em Preparo com um impacto de Atordoamento alto.
## Só funciona se o ataque declara `interruptible` nos dados, dentro da janela
## e acima do limiar. Devolve true quando o boop aconteceu.
static func try_interrupt(behemoth: BehemothState, impact_stagger: float, events: Array) -> bool:
	# Fonte ÚNICA da janela: a mesma função que o Instantâneo publica como
	# `interrupt_window` para o HUD e a tela "Aprenda". A janela que a
	# apresentação avisa é literalmente a janela que resolve o boop.
	if not behemoth.is_interruptible_now():
		return false
	var attack := behemoth.current_attack()
	if impact_stagger < behemoth.interrupt_threshold():
		return false

	events.append({
		"type": "interrupt",
		"pos": behemoth.pos,
		"attack": behemoth.attack_id,
		"name": attack.get("name", ""),
	})
	behemoth.plan.clear()
	_finish_attack(behemoth, attack)
	_enter(behemoth, BehemothState.State.INTERRUPTED)
	return true


static func _step_interrupted(behemoth: BehemothState) -> void:
	if behemoth.state_time >= SimConfig.INTERRUPT_DURATION:
		_enter(behemoth, BehemothState.State.CHASE)


## Atordoamento ----------------------------------------------------------------

static func _step_staggered(behemoth: BehemothState) -> void:
	if behemoth.state_time >= SimConfig.STAGGER_DOWN_DURATION:
		_enter(behemoth, BehemothState.State.CHASE)


## Soma Atordoamento. Cheio, derruba: o ataque em andamento é interrompido e o
## próximo limiar fica mais caro, para a luta não virar corrente de quedas.
static func add_stagger(behemoth: BehemothState, amount: float, events: Array = []) -> void:
	if behemoth.state == BehemothState.State.STAGGERED or not behemoth.is_alive():
		return
	behemoth.stagger += amount
	if behemoth.stagger < behemoth.stagger_threshold:
		return

	behemoth.stagger = 0.0
	behemoth.stagger_threshold *= SimConfig.STAGGER_ESCALATION
	behemoth.plan.clear()
	if not behemoth.attack_id.is_empty():
		_finish_attack(behemoth, behemoth.current_attack())
	_enter(behemoth, BehemothState.State.STAGGERED)
	events.append({"type": "staggered", "pos": behemoth.pos})


static func is_staggered(behemoth: BehemothState) -> bool:
	return behemoth.state == BehemothState.State.STAGGERED


## Verdadeiro só durante a fase Ativa, a única que machuca.
static func is_attack_active(behemoth: BehemothState) -> bool:
	return behemoth.state == BehemothState.State.ACTIVE and not behemoth.attack_id.is_empty()


## Ameaça -----------------------------------------------------------------------

## Quem mais bate puxa a atenção. Sem isto o Behemoth ficaria colado em quem
## chegou primeiro, e trocar de alvo é o que faz o grupo funcionar.
static func add_threat(behemoth: BehemothState, hunter_id: int, amount: float) -> void:
	behemoth.threat[hunter_id] = float(behemoth.threat.get(hunter_id, 0.0)) + amount


static func _pick_target(behemoth: BehemothState, hunters: Array, dt: float) -> HunterState:
	behemoth.retarget_in -= dt

	var current := _find_hunter(hunters, behemoth.target_id)
	var must_switch := current == null or behemoth.retarget_in <= 0.0
	if not must_switch:
		return current

	behemoth.retarget_in = SimConfig.BEHEMOTH_RETARGET_EVERY

	var best: HunterState = null
	var best_score := -1.0
	for hunter in hunters:
		var state: HunterState = hunter
		# Quem está Abatido sai da conta: perseguir quem está no chão não é
		# ameaça nenhuma, é só frustrante.
		if state.state == HunterState.State.DOWNED:
			continue
		# A Ameaça decide, e a distância desempata.
		var score := float(behemoth.threat.get(state.id, 0.0))
		score += maxf(0.0, 400.0 - behemoth.pos.distance_to(state.pos)) * 0.1
		if score > best_score:
			best_score = score
			best = state

	behemoth.target_id = best.id if best != null else 0
	return best


static func _find_hunter(hunters: Array, id: int) -> HunterState:
	for hunter in hunters:
		var state: HunterState = hunter
		if state.id == id and state.state != HunterState.State.DOWNED:
			return state
	return null


## Fúria -------------------------------------------------------------------------

static func _check_enrage(behemoth: BehemothState, events: Array) -> void:
	if behemoth.enraged or behemoth.max_hp <= 0.0:
		return
	if behemoth.hp / behemoth.max_hp > float(behemoth.data()["enrage_at"]):
		return
	behemoth.enraged = true
	behemoth.enrage_flash = SimConfig.ENRAGE_FLASH_DURATION
	events.append({"type": "enraged", "pos": behemoth.pos})
	# A Fúria encurta todas as recargas na hora: a virada tem que ser sentida,
	# não esperada.
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = float(behemoth.cooldowns[key]) * 0.4


static func damage_multiplier(behemoth: BehemothState) -> float:
	return float(behemoth.data()["enrage_damage"]) if behemoth.enraged else 1.0


static func _speed_multiplier(behemoth: BehemothState) -> float:
	return float(behemoth.data()["enrage_speed"]) if behemoth.enraged else 1.0


## Auxiliares ---------------------------------------------------------------------

static func _emit_phase(events: Array, behemoth: BehemothState, phase: String) -> void:
	events.append({
		"type": "behemoth_phase",
		"phase": phase,
		"attack": behemoth.attack_id,
		"pos": behemoth.pos,
	})


static func _tick_cooldowns(behemoth: BehemothState, dt: float) -> void:
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = maxf(0.0, float(behemoth.cooldowns[key]) - dt)


static func _turn_toward(behemoth: BehemothState, target_angle: float, rate: float, dt: float) -> void:
	var difference := angle_difference(behemoth.facing, target_angle)
	behemoth.facing = behemoth.facing + clampf(difference, -rate * dt, rate * dt)


static func _keep_inside_arena(behemoth: BehemothState) -> void:
	var limit := SimConfig.ARENA_RADIUS - behemoth.radius
	if behemoth.pos.length() > limit:
		behemoth.pos = behemoth.pos.normalized() * limit


static func _enter(behemoth: BehemothState, state: BehemothState.State) -> void:
	behemoth.state = state
	behemoth.state_time = 0.0
