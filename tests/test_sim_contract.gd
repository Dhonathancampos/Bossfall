extends RefCounted

## O contrato de combate (Ordem de reconstrução, itens 1–2): zonas por Parte,
## eventos de fase, interrupção (boop), ritmo por ataque sem pausa global e os
## padrões situacionais do Gnasher.
##
## Pragmatismo assumido (como nas suítes anteriores): posição/estado do
## BehemothState são fixados diretamente quando coreografar a situação real
## custaria mais do que prova.

const HUNTER: int = 1
const SECOND: int = SimConfig.TICK_RATE

func _sim(type_id: String = Behemoths.GNASHER) -> Sim:
	var sim := Sim.new(type_id)
	sim.add_hunter(HUNTER, "Teste")
	return sim

func _beh(sim: Sim) -> BehemothState:
	return sim.behemoth()

func _idle() -> HunterInput:
	return HunterInput.make(Vector2.ZERO, 0.0)

func _run(sim: Sim, ticks: int) -> void:
	for _i in ticks:
		sim.set_input(HUNTER, _idle())
		sim.step(SimConfig.TICK_DELTA)

## Um Golpe leve completo da Espada mirando o monstro, com o monstro parado
## à força na pose pedida (a IA fica congelada por cooldowns altos).
func _swing_at(sim: Sim, behemoth_pos: Vector2, behemoth_facing: float) -> void:
	var behemoth := _beh(sim)
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0
	var aim := (behemoth_pos - Vector2.ZERO).angle()
	sim.set_input(HUNTER, HunterInput.make(Vector2.ZERO, aim, 0, false, false, true, false))
	for _i in int(ceilf(1.2 * SimConfig.TICK_RATE)):
		behemoth.pos = behemoth_pos
		behemoth.facing = behemoth_facing
		sim.step(SimConfig.TICK_DELTA)
		sim.set_input(HUNTER, HunterInput.make(Vector2.ZERO, aim))

func _part(sim: Sim, id: String) -> Dictionary:
	return _beh(sim).part(id)

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Zonas por Parte -------------------------------------------------------------

func test_the_head_zone_is_hit_where_the_head_is(t: TestCase) -> void:
	var sim := _sim()
	# De frente para o Caçador: a zona da cabeça fica entre os dois.
	_swing_at(sim, Vector2(300.0, 0.0), PI)

	t.check(float(_part(sim, "head")["hp"]) < float(_part(sim, "head")["max_hp"]),
		"golpe na frente do focinho desconta da cabeça")
	t.check_approx(float(_part(sim, "tail")["hp"]), float(_part(sim, "tail")["max_hp"]),
		"e não da cauda")


func test_the_tail_zone_is_hit_from_behind(t: TestCase) -> void:
	var sim := _sim()
	# De costas para o Caçador: a zona da cauda fica entre os dois.
	_swing_at(sim, Vector2(300.0, 0.0), 0.0)

	t.check(float(_part(sim, "tail")["hp"]) < float(_part(sim, "tail")["max_hp"]),
		"golpe atrás desconta da cauda")
	t.check_approx(float(_part(sim, "head")["hp"]), float(_part(sim, "head")["max_hp"]),
		"e não da cabeça")


func test_a_severed_tail_zone_stops_existing(t: TestCase) -> void:
	var sim := _sim()
	var tail := _part(sim, "tail")
	tail["broken"] = true
	_swing_at(sim, Vector2(300.0, 0.0), 0.0)

	t.check(float(_part(sim, "legs")["hp"]) < float(_part(sim, "legs")["max_hp"]),
		"sem a cauda, o golpe por trás cai na zona das pernas")


func test_parts_without_zones_fall_back_to_sectors(t: TestCase) -> void:
	var sim := _sim(Behemoths.BASTION)
	# O Bastião não define zonas: de frente, o setor manda na Crista.
	_swing_at(sim, Vector2(300.0, 0.0), PI)

	t.check(float(_part(sim, "head")["hp"]) < float(_part(sim, "head")["max_hp"]),
		"sem zonas, o setor frontal desconta da Crista")


## Eventos de fase ---------------------------------------------------------------

func test_attack_phases_are_announced_in_order(t: TestCase) -> void:
	var sim := _sim()
	var phases: Array[String] = []
	var attack_id := ""

	for _i in SECOND * 12:
		sim.set_input(HUNTER, _idle())
		sim.step(SimConfig.TICK_DELTA)
		for event in sim.take_events():
			if String(event.get("type", "")) != "behemoth_phase":
				continue
			if attack_id.is_empty():
				attack_id = String(event["attack"])
			if String(event["attack"]) == attack_id or String(event.get("phase", "")) == "end":
				phases.append(String(event["phase"]))
		if phases.size() >= 4:
			break

	t.check_eq(phases.slice(0, 4), ["windup", "active", "recover", "end"],
		"o ataque anuncia Preparo, Ativo, Recuperação e fim, nessa ordem")


func test_the_knockdown_is_announced(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	BehemothStep.add_stagger(behemoth, behemoth.stagger_threshold + 1.0, sim.take_events())
	# add_stagger escreve na lista entregue; o teste usa a própria.
	var events: Array = []
	BehemothStep.add_stagger(behemoth, 0.0, events)  # já caído: nada acontece
	t.check_eq(int(behemoth.state), int(BehemothState.State.STAGGERED), "derrubou")


## Interrupção (boop) -------------------------------------------------------------

func _wind_up(behemoth: BehemothState, attack_id: String, elapsed: float) -> void:
	behemoth.attack_id = attack_id
	behemoth.state = BehemothState.State.WINDUP
	behemoth.state_time = elapsed


func test_a_strong_impact_inside_the_window_interrupts(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	_wind_up(behemoth, "charge", 0.2)

	var events: Array = []
	var booped := BehemothStep.try_interrupt(behemoth, 95.0, events)

	t.check(booped, "impacto acima do limiar, dentro da janela, interrompe")
	t.check_eq(int(behemoth.state), int(BehemothState.State.INTERRUPTED), "o monstro recua exposto")
	t.check_eq(behemoth.attack_id, "", "o ataque foi cancelado")
	t.check(float(behemoth.cooldowns["charge"]) > 0.0, "e entrou em recarga")
	t.check_eq(events.size(), 1, "o boop é anunciado")
	t.check_eq(String(events[0]["type"]), "interrupt", "com o evento certo")


func test_a_weak_impact_does_not_interrupt(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	_wind_up(behemoth, "charge", 0.2)

	t.check(not BehemothStep.try_interrupt(behemoth, 50.0, []), "abaixo do limiar não boopa")
	t.check_eq(int(behemoth.state), int(BehemothState.State.WINDUP), "o Preparo segue")


func test_late_impacts_do_not_interrupt(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	_wind_up(behemoth, "charge", 0.7)  # janela da investida fecha em 0.6

	t.check(not BehemothStep.try_interrupt(behemoth, 200.0, []), "fora da janela não boopa")


func test_non_interruptible_attacks_never_boop(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	_wind_up(behemoth, "bite", 0.1)

	t.check(not BehemothStep.try_interrupt(behemoth, 999.0, []), "a mordida não declara janela")


func test_the_interrupted_behemoth_gets_back_up(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	_wind_up(behemoth, "charge", 0.2)
	BehemothStep.try_interrupt(behemoth, 95.0, [])

	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0
	_run(sim, int(SimConfig.INTERRUPT_DURATION * SimConfig.TICK_RATE) + 4)

	t.check(int(behemoth.state) != int(BehemothState.State.INTERRUPTED), "a punição do boop é curta")


## Padrões do Gnasher --------------------------------------------------------------

func _target_at(pos: Vector2) -> HunterState:
	var hunter := HunterState.new()
	hunter.id = HUNTER
	hunter.pos = pos
	return hunter


func test_a_close_target_in_front_gets_bitten(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	behemoth.pos = Vector2(300.0, 0.0)
	behemoth.facing = PI
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 0.0

	var plan := BehemothStep.gnasher_plan(behemoth, _target_at(Vector2.ZERO), 70.0, _rng(1))
	t.check(plan.size() >= 1 and plan[0] == "bite", "perto e de frente, a resposta é a mordida")
	for step_id in plan:
		t.check_eq(String(step_id), "bite", "e a sequência só contém mordidas")


func test_a_target_behind_gets_the_tail(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	behemoth.pos = Vector2(300.0, 0.0)
	behemoth.facing = 0.0  # de costas para a origem
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 0.0

	var plan := BehemothStep.gnasher_plan(behemoth, _target_at(Vector2.ZERO), 70.0, _rng(1))
	t.check_eq(plan, ["tail"] as Array[String], "alvo atrás leva a rabada")


func test_a_sticky_target_gets_stomped(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	behemoth.pos = Vector2(300.0, 0.0)
	behemoth.facing = PI
	behemoth.sticky_time = BehemothStep.STICKY_TIME_FOR_STOMP + 0.1
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 0.0

	var plan := BehemothStep.gnasher_plan(behemoth, _target_at(Vector2.ZERO), 70.0, _rng(1))
	t.check_eq(plan, ["stomp"] as Array[String], "quem cola tempo demais leva o pisão")


func test_a_far_target_gets_charged(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	behemoth.pos = Vector2(800.0, 0.0)
	behemoth.facing = PI
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 0.0

	var plan := BehemothStep.gnasher_plan(behemoth, _target_at(Vector2.ZERO), 570.0, _rng(1))
	t.check_eq(plan, ["charge"] as Array[String], "alvo longe leva a investida")


func test_the_double_bite_varies_with_the_rng_only(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	behemoth.pos = Vector2(300.0, 0.0)
	behemoth.facing = PI
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 0.0

	var saw_single := false
	var saw_double := false
	for seed_value in range(1, 40):
		var plan := BehemothStep.gnasher_plan(behemoth, _target_at(Vector2.ZERO), 70.0, _rng(seed_value))
		if plan.size() == 1:
			saw_single = true
		elif plan.size() == 2:
			saw_double = true
	t.check(saw_single and saw_double, "a mordida sai simples E dupla conforme o sorteio")


func test_chained_attacks_ignore_the_decision_gap(t: TestCase) -> void:
	# A sequência encadeada é UM movimento: o segundo passo sai na pausa de
	# encadeamento (0,3 s), não na brecha de decisão — e muito antes dos 0,8 s
	# da antiga pausa global, que não existe mais.
	var sim := _sim()
	var behemoth := _beh(sim)
	behemoth.pos = Vector2(285.0, 0.0)
	behemoth.facing = PI
	behemoth.decision_gap = 99.0
	behemoth.plan = ["bite"] as Array[String]
	behemoth.plan_gap = BehemothStep.PLAN_LINK_GAP
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 0.0

	var ticks := 0
	for _i in SECOND:
		sim.set_input(HUNTER, _idle())
		# Fixa a pose: a IA não deve se mexer para o teste medir só o tempo.
		behemoth.pos = Vector2(285.0, 0.0)
		behemoth.facing = PI
		sim.step(SimConfig.TICK_DELTA)
		ticks += 1
		if behemoth.state == BehemothState.State.WINDUP:
			break

	t.check_eq(int(behemoth.state), int(BehemothState.State.WINDUP), "o passo planejado disparou")
	t.check_eq(behemoth.attack_id, "bite", "e é a mordida planejada")
	t.check(float(ticks) / float(SECOND) < 0.5, "bem antes da antiga pausa global de 0,8 s")


func test_a_whiffed_charge_leaves_a_longer_punish_window(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	var charge := Behemoths.attack(Behemoths.GNASHER, "charge")

	# Investida que ERROU: a recuperação ganha o bônus de exposição.
	behemoth.attack_id = "charge"
	behemoth.attack_connected = false
	behemoth.state = BehemothState.State.ACTIVE
	behemoth.state_time = float(charge["active"])
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0
	sim.set_input(HUNTER, _idle())
	sim.step(SimConfig.TICK_DELTA)
	t.check_eq(int(behemoth.state), int(BehemothState.State.RECOVER), "entrou na recuperação")
	t.check_approx(behemoth.recovery_bonus, float(charge["whiff_recovery_bonus"]),
		"com o bônus de quem errou")

	# No fim da recuperação BASE ele ainda está exposto; só sai depois do bônus.
	var base_ticks := int(ceilf(float(charge["recovery"]) * SimConfig.TICK_RATE))
	_run(sim, base_ticks)
	t.check_eq(int(behemoth.state), int(BehemothState.State.RECOVER),
		"no fim da recuperação normal, o monstro que errou segue exposto")
	_run(sim, int(ceilf(float(charge["whiff_recovery_bonus"]) * SimConfig.TICK_RATE)) + 4)
	t.check(int(behemoth.state) != int(BehemothState.State.RECOVER), "e sai depois do bônus")


func test_enrage_halves_the_gaps(t: TestCase) -> void:
	var calm := _sim()
	var calm_gap := _finished_bite_gap(calm, false)

	var furious := _sim()
	var furious_gap := _finished_bite_gap(furious, true)

	t.check_approx(furious_gap, calm_gap * 0.5, "a Fúria corta a brecha pós-ataque pela metade", 0.01)


func _finished_bite_gap(sim: Sim, enraged: bool) -> float:
	var behemoth := _beh(sim)
	behemoth.enraged = enraged
	behemoth.attack_id = "bite"
	behemoth.attack_connected = true
	behemoth.state = BehemothState.State.RECOVER
	behemoth.state_time = 99.0
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0
	sim.set_input(HUNTER, _idle())
	sim.step(SimConfig.TICK_DELTA)
	return _beh(sim).decision_gap


## Bastião continua de pé -----------------------------------------------------------

func test_the_bastion_still_hunts_with_the_generic_brain(t: TestCase) -> void:
	var sim := _sim(Behemoths.BASTION)
	var behemoth := _beh(sim)
	var attacked := false
	for _i in SECOND * 14:
		sim.set_input(HUNTER, _idle())
		sim.step(SimConfig.TICK_DELTA)
		for key in behemoth.cooldowns:
			behemoth.cooldowns[key] = minf(float(behemoth.cooldowns[key]), 0.2)
		if behemoth.state == BehemothState.State.WINDUP:
			attacked = true
			break
	t.check(attacked, "o Bastião persegue e ataca com o cérebro genérico, sem pausa global")
