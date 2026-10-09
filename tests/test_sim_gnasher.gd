extends RefCounted

## O Gnasher: perseguição, escolha de ataque por distância, dano no Caçador,
## Invulnerabilidade, Ameaça, Fúria e morte.

const HUNTER: int = 1
const OTHER: int = 2
const SECOND: int = SimConfig.TICK_RATE

func _sim() -> Sim:
	var sim := Sim.new(Behemoths.GNASHER)
	sim.add_hunter(HUNTER, "Teste")
	return sim

func _idle() -> HunterInput:
	return HunterInput.make(Vector2.ZERO, 0.0)

func _run(sim: Sim, ticks: int, input: HunterInput = null) -> void:
	for _i in ticks:
		if input != null:
			sim.set_input(HUNTER, input)
		sim.step(SimConfig.TICK_DELTA)

func _beh(sim: Sim) -> BehemothState:
	return sim.behemoth()

func _hunter(sim: Sim, id: int = HUNTER) -> Dictionary:
	for hunter in sim.snapshot()["hunters"]:
		if hunter["id"] == id:
			return hunter
	return {}


## Existência e perseguição -------------------------------------------------

func test_the_hunt_starts_with_a_gnasher(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	t.check(behemoth != null, "a Caçada tem um Behemoth")
	t.check_eq(behemoth.type_id, Behemoths.GNASHER, "e ele é o Gnasher")
	t.check(behemoth.hp > 0.0, "com Vida cheia")
	t.check(sim.snapshot().has("behemoth"), "e ele aparece no Instantâneo")


func test_the_gnasher_closes_in_on_the_hunter(t: TestCase) -> void:
	var sim := _sim()
	var before := _beh(sim).pos.distance_to(Vector2.ZERO)
	_run(sim, SECOND, _idle())
	var after := _beh(sim).pos.distance_to(Vector2.ZERO)

	t.check(after < before, "o Gnasher anda em direção ao Caçador")


func test_the_gnasher_turns_to_face_the_hunter(t: TestCase) -> void:
	var sim := _sim()
	_run(sim, SECOND, _idle())
	var behemoth := _beh(sim)
	var to_hunter := (Vector2.ZERO - behemoth.pos).angle()

	t.check(
		absf(angle_difference(behemoth.facing, to_hunter)) < 0.3,
		"o Gnasher vira para o alvo"
	)


func test_the_gnasher_stops_at_its_preferred_gap(t: TestCase) -> void:
	var sim := _sim()
	_run(sim, SECOND * 8, _idle())
	var distance := _beh(sim).pos.distance_to(Vector2.ZERO)

	t.check(distance > SimConfig.HUNTER_RADIUS, "o Gnasher não entra por dentro do Caçador")


func test_hunter_body_is_kept_outside_the_behemoth(t: TestCase) -> void:
	var hunter := HunterState.new()
	var radius := 104.0
	HunterStep.step(hunter, _idle(), SimConfig.TICK_DELTA, {
		"has_behemoth": true,
		"behemoth_pos": Vector2.ZERO,
		"behemoth_radius": radius,
	})

	t.check_approx(
		hunter.pos.length(), radius + SimConfig.HUNTER_RADIUS,
		"a Sim separa os corpos mesmo se nascerem sobrepostos"
	)


## Ataques ------------------------------------------------------------------

func test_a_dash_hits_the_full_telegraphed_corridor(t: TestCase) -> void:
	var shape := {"type": Behemoths.SHAPE_DASH, "width": 130.0, "range": 480.0}
	t.check(
		Combat.shape_hits(Vector2.ZERO, 0.0, shape, 104.0, Vector2(420.0, 0.0), SimConfig.HUNTER_RADIUS),
		"a investida acerta um caçador dentro do corredor que ela desenha"
	)
	t.check(
		not Combat.shape_hits(Vector2.ZERO, 0.0, shape, 104.0, Vector2(420.0, 100.0), SimConfig.HUNTER_RADIUS),
		"a investida não acerta fora da largura telegrafada"
	)

func test_the_gnasher_eventually_attacks(t: TestCase) -> void:
	var sim := _sim()
	var saw_windup := false
	for _i in SECOND * 10:
		sim.set_input(HUNTER, _idle())
		sim.step(SimConfig.TICK_DELTA)
		if _beh(sim).state == BehemothState.State.WINDUP:
			saw_windup = true
			break

	t.check(saw_windup, "o Gnasher chega a preparar um ataque")


func test_an_attack_goes_through_all_three_phases(t: TestCase) -> void:
	var sim := _sim()
	var seen: Array[int] = []
	for _i in SECOND * 14:
		sim.set_input(HUNTER, _idle())
		sim.step(SimConfig.TICK_DELTA)
		var state := int(_beh(sim).state)
		if seen.is_empty() or seen[seen.size() - 1] != state:
			seen.append(state)
		if seen.size() >= 5:
			break

	var windup := int(BehemothState.State.WINDUP)
	var active := int(BehemothState.State.ACTIVE)
	var recover := int(BehemothState.State.RECOVER)
	var ordered := seen.find(windup) >= 0 \
		and seen.find(active) > seen.find(windup) \
		and seen.find(recover) > seen.find(active)

	t.check(ordered, "o ataque passa por Preparo, Ativo e Recuperação, nessa ordem")


func test_recovery_inserts_a_safe_pause_before_the_next_attack(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	var attack := Behemoths.attack(Behemoths.GNASHER, "bite")
	behemoth.state = BehemothState.State.RECOVER
	behemoth.attack_id = "bite"
	behemoth.state_time = float(attack["recovery"])
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 0.0

	sim.step(SimConfig.TICK_DELTA)
	sim.step(SimConfig.TICK_DELTA)

	t.check_eq(int(behemoth.state), int(BehemothState.State.CHASE),
		"a recuperação deixa uma janela segura antes do próximo ataque")


func test_an_attack_hurts_a_hunter_standing_still(t: TestCase) -> void:
	var sim := _sim()
	var hurt := false
	for _i in SECOND * 14:
		sim.set_input(HUNTER, _idle())
		sim.step(SimConfig.TICK_DELTA)
		if float(_hunter(sim)["hp"]) < SimConfig.HUNTER_MAX_HP:
			hurt = true
			break

	t.check(hurt, "quem fica parado leva dano")


func test_an_attack_hits_a_hunter_only_once(t: TestCase) -> void:
	var sim := _sim()
	var hits := 0
	for _i in SECOND * 14:
		sim.set_input(HUNTER, _idle())
		sim.step(SimConfig.TICK_DELTA)
		for event in sim.take_events():
			if event["type"] == "hurt":
				hits += 1
		if _beh(sim).state == BehemothState.State.RECOVER and hits > 0:
			break

	t.check_eq(hits, 1, "um ataque machuca o Caçador uma vez, não um por quadro")


func test_being_hurt_pushes_the_hunter_away(t: TestCase) -> void:
	var sim := _sim()
	for _i in SECOND * 14:
		sim.set_input(HUNTER, _idle())
		sim.step(SimConfig.TICK_DELTA)
		if float(_hunter(sim)["hp"]) < SimConfig.HUNTER_MAX_HP:
			break

	var hunter := _hunter(sim)
	t.check(
		(hunter["knockback"] as Vector2).length() > 0.0 or hunter["pos"] != Vector2.ZERO,
		"o acerto empurra o Caçador para longe"
	)


func test_invulnerability_blocks_the_damage(t: TestCase) -> void:
	# Sem Invulnerabilidade a Esquiva não serviria para nada, e o jogo viraria
	# uma troca de tapas.
	var sim := _sim()
	var behemoth := _beh(sim)
	var hunter_before := SimConfig.HUNTER_MAX_HP

	for _i in SECOND * 14:
		sim.set_input(HUNTER, _idle())
		sim.step(SimConfig.TICK_DELTA)
		if behemoth.state != BehemothState.State.WINDUP:
			continue
		# Rola logo antes do ataque sair.
		var attack := behemoth.current_attack()
		if behemoth.state_time < float(attack["windup"]) - 0.12:
			continue
		sim.set_input(HUNTER, HunterInput.make(Vector2.ZERO, 0.0, 0, false, true))
		for _j in int(SimConfig.DODGE_IFRAMES_END * SimConfig.TICK_RATE):
			sim.step(SimConfig.TICK_DELTA)
		break

	t.check_approx(float(_hunter(sim)["hp"]), hunter_before, "rolar no tempo certo atravessa o ataque", 0.01)


## Ameaça, Fúria e morte ----------------------------------------------------

func test_threat_decides_who_the_gnasher_follows(t: TestCase) -> void:
	var sim := _sim()
	sim.add_hunter(OTHER, "Outro")
	var behemoth := _beh(sim)

	BehemothStep.add_threat(behemoth, OTHER, 500.0)
	behemoth.retarget_in = 0.0
	sim.step(SimConfig.TICK_DELTA)

	t.check_eq(behemoth.target_id, OTHER, "quem mais irritou puxa a atenção")


func test_the_gnasher_enrages_below_the_threshold(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	t.check(not behemoth.enraged, "começa calmo")

	var threshold := float(behemoth.data()["enrage_at"])
	behemoth.hp = behemoth.max_hp * (threshold - 0.05)
	sim.step(SimConfig.TICK_DELTA)

	t.check(behemoth.enraged, "abaixo do limite entra em Fúria")
	t.check(behemoth.enrage_flash > 0.0, "e avisa na tela")


func test_enrage_raises_damage(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	t.check_approx(BehemothStep.damage_multiplier(behemoth), 1.0, "calmo bate normal")

	behemoth.enraged = true
	t.check(BehemothStep.damage_multiplier(behemoth) > 1.0, "em Fúria bate mais forte")


func test_the_gnasher_dies_when_its_health_runs_out(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	behemoth.hp = 0.0
	sim.step(SimConfig.TICK_DELTA)

	t.check_eq(int(behemoth.state), int(BehemothState.State.DEAD), "sem Vida, o Gnasher morre")
	t.check(not behemoth.is_alive(), "e deixa de estar vivo")

	var pos_before := behemoth.pos
	_run(sim, SECOND, _idle())
	t.check_eq(behemoth.pos, pos_before, "e para de se mexer")


## Abatido ------------------------------------------------------------------

func test_a_hunter_with_no_health_is_downed(t: TestCase) -> void:
	var sim := _sim()
	_down_the_hunter(sim)
	t.check_eq(int(_hunter(sim)["state"]), int(HunterState.State.DOWNED), "Vida zerada derruba o Caçador")


func test_a_downed_hunter_gets_back_up(t: TestCase) -> void:
	var sim := _sim()
	_down_the_hunter(sim)
	_run(sim, int(SimConfig.DOWNED_DURATION * SimConfig.TICK_RATE) + 4, _idle())

	var hunter := _hunter(sim)
	t.check_eq(int(hunter["state"]), int(HunterState.State.FREE), "o Caçador levanta sozinho")
	t.check(float(hunter["hp"]) > 0.0, "e volta com Vida")


## Bate no Caçador até derrubar, respeitando a Invulnerabilidade entre acertos.
func _down_the_hunter(sim: Sim) -> void:
	var behemoth := _beh(sim)
	for _i in SECOND * 40:
		sim.set_input(HUNTER, _idle())
		sim.step(SimConfig.TICK_DELTA)
		if int(_hunter(sim)["state"]) == int(HunterState.State.DOWNED):
			return
		# Acelera: a Fúria e a recarga curta já estão testadas em outro lugar.
		for key in behemoth.cooldowns:
			behemoth.cooldowns[key] = minf(float(behemoth.cooldowns[key]), 0.2)
