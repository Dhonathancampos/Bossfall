extends RefCounted

## Elementos (tabela de Oposição no dano) e as seis Aflições.

const HUNTER: int = 1
const SECOND: int = SimConfig.TICK_RATE

func _sim(
	weapon_element: Elements.Element = Elements.Element.NEUTRAL,
	behemoth_element: Elements.Element = Elements.Element.NEUTRAL
) -> Sim:
	var sim := Sim.new(Behemoths.GNASHER, behemoth_element)
	sim.add_hunter(HUNTER, "Teste")
	sim.set_weapon(HUNTER, Weapons.SWORD, weapon_element)
	return sim

func _beh(sim: Sim) -> BehemothState:
	return sim.behemoth()

func _hunter_state(sim: Sim) -> HunterState:
	# As Aflições são alimentadas pelo Anfitrião mas vivem no HunterState;
	# os testes de efeito chamam Afflictions direto nele, como a Sim faz.
	var snapshot := sim.snapshot()
	var state := HunterState.new()
	state.apply_dict(snapshot["hunters"][0])
	return state

func _hunter(sim: Sim) -> Dictionary:
	return sim.snapshot()["hunters"][0]

func _park_and_swing(sim: Sim) -> float:
	var behemoth := _beh(sim)
	behemoth.pos = Vector2(130.0, 0.0)
	behemoth.facing = PI
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0
	var hp_before := behemoth.hp

	var aim := behemoth.pos.angle()
	sim.set_input(HUNTER, HunterInput.make(Vector2.ZERO, aim, 0, false, false, true, false))
	for _i in SECOND:
		behemoth.pos = Vector2(130.0, 0.0)
		behemoth.facing = PI
		sim.step(SimConfig.TICK_DELTA)
		sim.set_input(HUNTER, HunterInput.make(Vector2.ZERO, aim))
	return hp_before - behemoth.hp

func _idle(sim: Sim, ticks: int) -> void:
	for _i in ticks:
		sim.set_input(HUNTER, HunterInput.make(Vector2.ZERO, 0.0))
		sim.step(SimConfig.TICK_DELTA)


## Tabela de Oposição ---------------------------------------------------------

func test_the_full_opposition_table(t: TestCase) -> void:
	var pairs := [
		[Elements.Element.BLAZE, Elements.Element.FROST],
		[Elements.Element.SHOCK, Elements.Element.TERRA],
		[Elements.Element.RADIANT, Elements.Element.UMBRAL],
	]
	for pair in pairs:
		var a: Elements.Element = pair[0]
		var b: Elements.Element = pair[1]
		t.check_approx(Elements.damage_multiplier(a, b), Elements.OPPOSITION_BONUS,
			"%s é forte contra %s" % [Elements.display_name(a), Elements.display_name(b)])
		t.check_approx(Elements.damage_multiplier(b, a), Elements.OPPOSITION_BONUS,
			"%s é forte contra %s" % [Elements.display_name(b), Elements.display_name(a)])
		t.check_approx(Elements.damage_multiplier(a, a), Elements.SAME_ELEMENT_PENALTY,
			"%s contra si mesmo é punido" % Elements.display_name(a))

	t.check_approx(Elements.damage_multiplier(Elements.Element.NEUTRAL, Elements.Element.BLAZE), 1.0,
		"Neutro atacando nunca recebe bônus nem penalidade")
	t.check_approx(Elements.damage_multiplier(Elements.Element.BLAZE, Elements.Element.NEUTRAL), 1.0,
		"Neutro defendendo também não")
	t.check_approx(Elements.damage_multiplier(Elements.Element.BLAZE, Elements.Element.SHOCK), 1.0,
		"Elementos sem relação ficam em 1")


func test_opposite_element_deals_more_damage_in_the_hunt(t: TestCase) -> void:
	var neutral_taken := _park_and_swing(_sim(Elements.Element.NEUTRAL, Elements.Element.FROST))
	var opposed_taken := _park_and_swing(_sim(Elements.Element.BLAZE, Elements.Element.FROST))
	var same_taken := _park_and_swing(_sim(Elements.Element.FROST, Elements.Element.FROST))

	t.check(opposed_taken > neutral_taken * 1.1, "arma de Incêndio machuca mais o Behemoth Gélido")
	t.check(same_taken < neutral_taken * 0.9, "arma Gélida machuca menos o Behemoth Gélido")


## Acúmulo e disparo -----------------------------------------------------------

func test_buildup_triggers_only_after_the_threshold(t: TestCase) -> void:
	var state := HunterState.new()
	var hits_needed := int(ceilf(SimConfig.AFFLICTION_THRESHOLD / SimConfig.AFFLICTION_BUILDUP_PER_HIT))

	var triggered := ""
	for i in hits_needed:
		t.check(triggered.is_empty(), "antes de encher, nada dispara")
		triggered = Afflictions.add_buildup(state, Elements.Element.BLAZE)

	t.check_eq(triggered, "Queimadura", "ao encher, a Aflição dispara com o nome certo")
	t.check(state.has_affliction(Elements.Element.BLAZE), "e fica ativa")


func test_neutral_attacks_never_afflict(t: TestCase) -> void:
	var state := HunterState.new()
	for _i in 10:
		Afflictions.add_buildup(state, Elements.Element.NEUTRAL)
	t.check(state.afflictions.is_empty(), "Neutro não aflige nunca")


func test_buildup_decays_when_not_fed(t: TestCase) -> void:
	var state := HunterState.new()
	Afflictions.add_buildup(state, Elements.Element.BLAZE)
	var before := float(state.affliction_buildup[int(Elements.Element.BLAZE)])

	for _i in SECOND * 2:
		Afflictions.step(state, SimConfig.TICK_DELTA)

	t.check(
		float(state.affliction_buildup[int(Elements.Element.BLAZE)])
			< before - SimConfig.AFFLICTION_BUILDUP_DECAY,
		"o acúmulo escorre com o tempo"
	)


func test_afflictions_expire(t: TestCase) -> void:
	var state := HunterState.new()
	state.afflictions[int(Elements.Element.FROST)] = 0.2
	for _i in 30:
		Afflictions.step(state, SimConfig.TICK_DELTA)
	t.check(not state.has_affliction(Elements.Element.FROST), "a Aflição expira sozinha")


## Efeitos ----------------------------------------------------------------------

func test_burn_drains_health_over_time(t: TestCase) -> void:
	var state := HunterState.new()
	state.afflictions[int(Elements.Element.BLAZE)] = 3.0
	for _i in SECOND:
		Afflictions.step(state, SimConfig.TICK_DELTA)
	t.check_approx(state.hp, SimConfig.HUNTER_MAX_HP - SimConfig.BURN_DPS,
		"um segundo de Queimadura tira um segundo de dano", 0.5)


func test_frost_slows_movement(t: TestCase) -> void:
	var fast := HunterState.new()
	var slow := HunterState.new()
	slow.afflictions[int(Elements.Element.FROST)] = 5.0

	var input := HunterInput.make(Vector2.RIGHT, 0.0)
	for _i in SECOND:
		HunterStep.step(fast, input, SimConfig.TICK_DELTA)
		HunterStep.step(slow, input, SimConfig.TICK_DELTA)

	t.check(slow.pos.x < fast.pos.x * 0.7, "o Congelamento corta a velocidade")


func test_shock_interrupts_the_attack_and_drains_stamina(t: TestCase) -> void:
	var state := HunterState.new()
	HunterStep.step(state, HunterInput.make(Vector2.ZERO, 0.0, 0, false, false, true, false), SimConfig.TICK_DELTA)
	t.check_eq(int(state.state), int(HunterState.State.ATTACK), "o Golpe começou")
	var stamina_before := state.stamina

	# Enche de uma vez para disparar o Choque.
	for _i in 3:
		Afflictions.add_buildup(state, Elements.Element.SHOCK)

	t.check_eq(int(state.state), int(HunterState.State.FREE), "o Choque quebra o Comprometimento")
	t.check(state.stamina < stamina_before - 20.0, "e drena Fôlego")


func test_root_blocks_the_dodge(t: TestCase) -> void:
	var state := HunterState.new()
	state.afflictions[int(Elements.Element.TERRA)] = 5.0

	HunterStep.step(state, HunterInput.make(Vector2.RIGHT, 0.0, 0, false, true), SimConfig.TICK_DELTA)

	t.check(int(state.state) != int(HunterState.State.DODGE), "Enraizado não rola")
	t.check_approx(state.stamina, SimConfig.STAMINA_MAX, "e o Fôlego não é cobrado", 0.6)


func test_drain_blocks_regen_and_drains_aether(t: TestCase) -> void:
	var state := HunterState.new()
	state.stamina = 40.0
	state.aether = 50.0
	state.afflictions[int(Elements.Element.UMBRAL)] = 5.0

	var input := HunterInput.make(Vector2.ZERO, 0.0)
	for _i in SECOND * 2:
		HunterStep.step(state, input, SimConfig.TICK_DELTA)

	t.check_approx(state.stamina, 40.0, "o Dreno trava a regeneração de Fôlego", 1.0)
	t.check(state.aether < 50.0 - 15.0, "e esvazia o Éter")


func test_burn_can_down_a_hunter(t: TestCase) -> void:
	var state := HunterState.new()
	state.hp = 1.0
	state.afflictions[int(Elements.Element.BLAZE)] = 5.0

	var input := HunterInput.make(Vector2.ZERO, 0.0)
	for _i in SECOND:
		HunterStep.step(state, input, SimConfig.TICK_DELTA)

	t.check_eq(int(state.state), int(HunterState.State.DOWNED), "a Queimadura derruba como dano comum")


## Através da Caçada -------------------------------------------------------------

func test_an_elemental_behemoth_afflicts_the_hunter(t: TestCase) -> void:
	var sim := _sim(Elements.Element.NEUTRAL, Elements.Element.BLAZE)
	var behemoth := _beh(sim)

	var afflicted := false
	for _i in SECOND * 40:
		sim.set_input(HUNTER, HunterInput.make(Vector2.ZERO, 0.0))
		sim.step(SimConfig.TICK_DELTA)
		for key in behemoth.cooldowns:
			behemoth.cooldowns[key] = minf(float(behemoth.cooldowns[key]), 0.2)
		var afflictions: Dictionary = _hunter(sim).get("afflictions", {})
		if not afflictions.is_empty():
			afflicted = true
			break

	t.check(afflicted, "apanhar do Gnasher Flamejante acende a Queimadura no Instantâneo")
