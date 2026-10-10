extends RefCounted

## Interrupção (boop) em TODOS os Behemoths.
##
## O contrato já existia e o Gnasher o usava; esta suíte fixa o critério de
## design do Bastião (lento e comprometido é interrompível; o que ele faz
## colado, não), prova que a Rajada do Martelo, a explosão do Magma e a Salva
## das Repetidoras passam pelo caminho de boop, e cobra o aviso que a
## apresentação consome (`interrupt_window` no Instantâneo).

const HUNTER: int = 1
const SECOND: int = SimConfig.TICK_RATE


func _sim(type_id: String, weapon: String = Weapons.SWORD) -> Sim:
	var sim := Sim.new(type_id)
	sim.add_hunter(HUNTER, "Teste", weapon)
	return sim


func _beh(sim: Sim) -> BehemothState:
	return sim.behemoth()


func _wind_up(behemoth: BehemothState, attack_id: String, elapsed: float) -> void:
	behemoth.attack_id = attack_id
	behemoth.state = BehemothState.State.WINDUP
	behemoth.state_time = elapsed


func _hunter(sim: Sim) -> Dictionary:
	return sim.snapshot()["hunters"][0]


func _run(sim: Sim, input: HunterInput, ticks: int, events: Array = [], distance: float = 300.0) -> void:
	for _i in ticks:
		var behemoth := _beh(sim)
		behemoth.pos = Vector2(distance, 0.0)
		behemoth.facing = PI
		sim.set_input(HUNTER, input)
		sim.step(SimConfig.TICK_DELTA)
		events.append_array(sim.take_events())


func _in(
	light: bool = false, heavy: bool = false, heavy_held: bool = false,
	special: bool = false
) -> HunterInput:
	return HunterInput.make(Vector2.ZERO, 0.0, 0, false, false, light, heavy, special, heavy_held)


## Critério de design do Bastião -------------------------------------------

func test_the_bastion_slow_committed_attacks_are_interruptible(t: TestCase) -> void:
	for attack_id in ["roll", "quake"]:
		var sim := _sim(Behemoths.BASTION)
		var behemoth := _beh(sim)
		_wind_up(behemoth, attack_id, 0.2)
		t.check(behemoth.is_interruptible_now(), "%s abre janela de boop" % attack_id)
		t.check(
			BehemothStep.try_interrupt(behemoth, 200.0, []),
			"%s é cancelado por um impacto forte" % attack_id
		)
		t.check_eq(int(behemoth.state), int(BehemothState.State.INTERRUPTED), "e o Bastião recua exposto")


func test_what_the_bastion_does_up_close_never_boops(t: TestCase) -> void:
	for attack_id in ["headbutt", "mace"]:
		var sim := _sim(Behemoths.BASTION)
		var behemoth := _beh(sim)
		_wind_up(behemoth, attack_id, 0.1)
		t.check(not behemoth.is_interruptible_now(), "%s não declara janela" % attack_id)
		t.check(
			not BehemothStep.try_interrupt(behemoth, 999.0, []),
			"%s é colado e curto: a resposta é a esquiva, não o boop" % attack_id
		)


func test_the_bastion_is_harder_to_boop_than_the_gnasher(t: TestCase) -> void:
	var bastion := _sim(Behemoths.BASTION)
	_wind_up(_beh(bastion), "roll", 0.2)
	var gnasher := _sim(Behemoths.GNASHER)
	_wind_up(_beh(gnasher), "charge", 0.2)
	t.check(
		_beh(bastion).interrupt_threshold() > _beh(gnasher).interrupt_threshold(),
		"o limiar do Bastião é mais alto"
	)
	t.check(not BehemothStep.try_interrupt(_beh(bastion), 95.0, []),
		"um impacto que boopa o Gnasher não boopa o Bastião")
	t.check(BehemothStep.try_interrupt(_beh(gnasher), 95.0, []), "o mesmo impacto boopa o Gnasher")


## O aviso que a apresentação consome --------------------------------------

func test_the_snapshot_announces_the_interrupt_window(t: TestCase) -> void:
	var sim := _sim(Behemoths.BASTION)
	var behemoth := _beh(sim)
	_wind_up(behemoth, "roll", 0.2)
	var payload: Dictionary = sim.snapshot()["behemoth"]
	t.check(bool(payload["interrupt_window"]), "durante a janela, o Instantâneo avisa")
	t.check(float(payload["interrupt_threshold"]) > 0.0, "e diz quanto precisa")

	# Fora da janela (a do Rolamento fecha em 0,65 s) o aviso apaga.
	_wind_up(behemoth, "roll", 0.9)
	var late: Dictionary = sim.snapshot()["behemoth"]
	t.check(not bool(late["interrupt_window"]), "passada a janela, o aviso some")
	t.check_approx(float(late["interrupt_threshold"]), 0.0, "e o limiar zera")

	# Fora do Preparo também.
	behemoth.state = BehemothState.State.ACTIVE
	t.check(not bool((sim.snapshot()["behemoth"] as Dictionary)["interrupt_window"]),
		"só o Preparo é interrompível")


func test_the_window_the_snapshot_shows_is_the_window_that_boops(t: TestCase) -> void:
	# Fonte única: desenhado = resolvido. Varre o Preparo inteiro comparando
	# o aviso com o resultado real do boop.
	for elapsed in [0.0, 0.2, 0.4, 0.6, 0.64, 0.7, 0.9]:
		var sim := _sim(Behemoths.BASTION)
		var behemoth := _beh(sim)
		_wind_up(behemoth, "roll", float(elapsed))
		var announced := bool((sim.snapshot()["behemoth"] as Dictionary)["interrupt_window"])
		var booped := BehemothStep.try_interrupt(behemoth, 999.0, [])
		t.check_eq(booped, announced, "em %s s, aviso e boop concordam" % elapsed)


## Os três caminhos de boop que o ticket cobra -----------------------------

func test_the_hammer_blast_boops_the_bastion(t: TestCase) -> void:
	var sim := _sim(Behemoths.BASTION, Weapons.HAMMER)
	var behemoth := _beh(sim)
	# Arma a Rajada com duas munições e solta com o Rolamento em Preparo.
	_run(sim, _in(false, true, true), 1, [], 300.0)
	_run(sim, _in(false, false, true), int(SECOND * 1.1), [], 300.0)
	_wind_up(behemoth, "roll", 0.1)
	var events: Array = []
	_run(sim, _in(), SECOND, events, 300.0)

	var booped := false
	for event in events:
		if event.get("type", "") == "interrupt":
			booped = true
	t.check(booped, "a Rajada do Martelo interrompe o Rolamento")
	t.check_eq(int(_hunter(sim)["interrupts"]), 1, "e a interrupção é creditada a quem boopou")


func test_the_magma_explosion_boops(t: TestCase) -> void:
	var sim := _sim(Behemoths.BASTION, Weapons.HAMMER)
	var behemoth := _beh(sim)
	sim.fill_aether(HUNTER)
	_run(sim, _in(false, false, false, true), 1, [], 400.0)
	_wind_up(behemoth, "quake", 0.1)
	var events: Array = []
	_run(sim, _in(), SECOND, events, 400.0)

	var booped := false
	for event in events:
		if event.get("type", "") == "interrupt":
			booped = true
	t.check(booped, "a explosão do Magma interrompe")


func test_the_repeater_salvo_boops(t: TestCase) -> void:
	var sim := _sim(Behemoths.BASTION, Weapons.REPEATERS)
	var behemoth := _beh(sim)
	sim.fill_aether(HUNTER)
	_run(sim, _in(false, false, false, true), 1, [], 500.0)
	_wind_up(behemoth, "quake", 0.1)
	var events: Array = []
	_run(sim, _in(), SECOND, events, 500.0)

	var booped := false
	for event in events:
		if event.get("type", "") == "interrupt":
			booped = true
	t.check(booped, "a Salva das Repetidoras também passa pelo caminho de boop")


func test_the_pike_missile_boops(t: TestCase) -> void:
	var sim := _sim(Behemoths.BASTION, Weapons.PIKE)
	var behemoth := _beh(sim)
	sim.set_aether(HUNTER, 95.0)
	_run(sim, _in(false, false, false, true), 1, [], 600.0)
	_run(sim, _in(false, false, false, true), 1, [], 600.0)
	_wind_up(behemoth, "roll", 0.1)
	var events: Array = []
	_run(sim, _in(), SECOND, events, 600.0)

	var booped := false
	for event in events:
		if event.get("type", "") == "interrupt":
			booped = true
	t.check(booped, "o míssil da Conversão Aetérica é o boop clássico da Lança")


func test_a_boop_does_not_also_fill_the_stagger_meter(t: TestCase) -> void:
	# Regra provisória do contrato: a energia do golpe vai no boop. Impedir
	# que boop e queda saiam do MESMO golpe.
	var sim := _sim(Behemoths.BASTION)
	var behemoth := _beh(sim)
	_wind_up(behemoth, "roll", 0.1)
	var before := behemoth.stagger
	BehemothStep.try_interrupt(behemoth, 400.0, [])
	t.check_approx(behemoth.stagger, before, "o golpe que boopa não soma no medidor")
