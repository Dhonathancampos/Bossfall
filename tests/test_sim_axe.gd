extends RefCounted

## Ticket 11 — Machado: carga por golpe, medidor que só enche carregado,
## Determinação em pilhas e o Voo da Ruína (ida e volta).

const HUNTER: int = 1
const SECOND: int = SimConfig.TICK_RATE
const CLOSE: float = 130.0


func _sim(distance: float = CLOSE, with_behemoth: bool = true) -> Sim:
	var sim := Sim.new(Behemoths.GNASHER if with_behemoth else "")
	sim.add_hunter(HUNTER, "Teste", Weapons.AXE)
	if with_behemoth:
		_park(sim, distance)
	return sim


func _park(sim: Sim, distance: float) -> void:
	var behemoth := sim.behemoth()
	if behemoth == null:
		return
	behemoth.pos = Vector2(distance, 0.0)
	behemoth.facing = PI
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0


func _hunter(sim: Sim) -> Dictionary:
	return sim.snapshot()["hunters"][0]


func _run(sim: Sim, input: HunterInput, ticks: int, events: Array = [], distance: float = CLOSE) -> void:
	for _i in ticks:
		_park(sim, distance)
		sim.set_input(HUNTER, input)
		sim.step(SimConfig.TICK_DELTA)
		events.append_array(sim.take_events())


func _in(
	light: bool = false, heavy: bool = false,
	light_held: bool = false, heavy_held: bool = false,
	special: bool = false
) -> HunterInput:
	return HunterInput.make(
		Vector2.ZERO, 0.0, 0, false, false, light, heavy, special, heavy_held, false, light_held
	)


func _state(sim: Sim) -> int:
	return int(_hunter(sim)["state"])


func _hits_named(events: Array, move_name: String) -> Array:
	var found: Array = []
	for event in events:
		if event.get("type", "") == "hit" and event.get("move", "") == move_name:
			found.append(event)
	return found


## Carga -------------------------------------------------------------------

func test_pressing_light_enters_charge(t: TestCase) -> void:
	var sim := _sim()
	var hp_before := sim.behemoth().hp
	_run(sim, _in(true, false, true), 1)
	t.check_eq(_state(sim), int(HunterState.State.AXE_CHARGE), "o leve do Machado entra em carga")
	_run(sim, _in(false, false, true), SECOND)
	t.check_eq(_state(sim), int(HunterState.State.AXE_CHARGE), "e segue carregando enquanto segura")
	t.check_approx(sim.behemoth().hp, hp_before, "sem soltar, nada acerta", 0.01)


func test_releasing_fires_the_strike(t: TestCase) -> void:
	var sim := _sim()
	var events: Array = []
	_run(sim, _in(true, false, true), 1, events)
	_run(sim, _in(), SECOND, events)
	t.check(_hits_named(events, "Talho Amplo").size() >= 1, "soltar dispara o Golpe")


func test_charge_scales_damage_and_saturates(t: TestCase) -> void:
	var tap := _sim()
	var tap_events: Array = []
	_run(tap, _in(true, false, true), 1, tap_events)
	_run(tap, _in(), SECOND, tap_events)
	var tap_hits := _hits_named(tap_events, "Talho Amplo")

	var full := _sim()
	var full_events: Array = []
	_run(full, _in(true, false, true), 1, full_events)
	_run(full, _in(false, false, true), SECOND, full_events)
	_run(full, _in(), SECOND, full_events)
	var full_hits := _hits_named(full_events, "Talho Amplo")

	var over := _sim()
	var over_events: Array = []
	_run(over, _in(true, false, true), 1, over_events)
	_run(over, _in(false, false, true), SECOND * 2, over_events)
	_run(over, _in(), SECOND, over_events)
	var over_hits := _hits_named(over_events, "Talho Amplo")

	t.check(tap_hits.size() >= 1 and full_hits.size() >= 1 and over_hits.size() >= 1, "os três conectaram")
	if tap_hits.is_empty() or full_hits.is_empty() or over_hits.is_empty():
		return
	t.check(
		float(full_hits[0]["amount"]) > float(tap_hits[0]["amount"]) * 1.5,
		"a carga cheia bate muito mais que o toque"
	)
	t.check_approx(
		float(over_hits[0]["amount"]), float(full_hits[0]["amount"]),
		"segurar além do teto não rende mais: a escala satura", 0.5
	)


func test_charging_drains_stamina_and_zero_forces_release(t: TestCase) -> void:
	var sim := _sim()
	_run(sim, _in(true, false, true), 1)
	var before: float = _hunter(sim)["stamina"]
	_run(sim, _in(false, false, true), 30)
	t.check(float(_hunter(sim)["stamina"]) < before - 4.0, "segurar a carga drena vigor")

	# Vigor zerado solta a carga sozinho, mesmo com o botão ainda segurado.
	var drained := _sim()
	_run(drained, _in(true, false, true), 1)
	var guard := 0
	while guard < SECOND * 30 and _state(drained) == int(HunterState.State.AXE_CHARGE):
		guard += 1
		_run(drained, _in(false, false, true), 1)
	t.check(guard < SECOND * 30, "sem vigor, a carga sai sozinha")


func test_the_meter_fills_only_with_charged_hits(t: TestCase) -> void:
	var tap := _sim()
	_run(tap, _in(true, false, true), 1)
	_run(tap, _in(), SECOND)
	t.check_approx(float(_hunter(tap)["aether"]), 0.0, "acerto sem carga não enche o medidor")

	var full := _sim()
	_run(full, _in(true, false, true), 1)
	_run(full, _in(false, false, true), SECOND)
	_run(full, _in(), SECOND)
	t.check(float(_hunter(full)["aether"]) > 0.0, "acerto carregado enche")


func test_the_combo_continues_between_charges(t: TestCase) -> void:
	var sim := _sim()
	_run(sim, _in(true, false, true), 1)
	_run(sim, _in(), SECOND)
	_run(sim, _in(true, false, true), 1)
	t.check_eq(
		Weapons.node_name(Weapons.AXE, int(_hunter(sim)["attack_kind"]) as Weapons.Kind,
			int(_hunter(sim)["attack_index"])),
		"talho_retorno",
		"o combo avança através da carga"
	)


## Resolve -------------------------------------------------------------------

func test_a_perfect_charge_grants_resolve(t: TestCase) -> void:
	var sim := _sim()
	_run(sim, _in(false, true, false, true), 1)
	_run(sim, _in(false, false, false, true), SECOND)
	# Solta no topo da carga: janela perfeita.
	_run(sim, _in(), 1)
	t.check(float(_hunter(sim)["resolve_time"]) > 0.0, "soltar na carga perfeita dá Resolve")


func test_resolve_tanks_the_hit_without_breaking_the_strike(t: TestCase) -> void:
	var hunter := HunterState.new()
	hunter.weapon_id = Weapons.AXE
	hunter.state = HunterState.State.ATTACK
	hunter.resolve_time = 0.5
	var before := hunter.hp
	var took := HunterStep.take_hit(hunter, 12.0, Vector2(100.0, 0.0), 300.0)
	t.check(took, "o dano entra")
	t.check(hunter.hp < before, "a Vida sente")
	t.check_eq(hunter.state, HunterState.State.ATTACK, "mas o Golpe não é interrompido")
	t.check_eq(hunter.knockback, Vector2.ZERO, "e não há tranco: Resolve tanka, não esquiva")

	var plain := HunterState.new()
	plain.weapon_id = Weapons.AXE
	plain.state = HunterState.State.ATTACK
	HunterStep.take_hit(plain, 12.0, Vector2(100.0, 0.0), 300.0)
	t.check_eq(plain.state, HunterState.State.HURT, "sem Resolve, o mesmo golpe derruba o ritmo")


## Voo da Ruína ---------------------------------------------------------------

func test_the_special_throws_the_axe(t: TestCase) -> void:
	var sim := _sim(500.0)
	sim.fill_aether(HUNTER)
	_run(sim, _in(false, false, false, false, true), 1, [], 500.0)
	t.check(bool(_hunter(sim)["axe_out"]), "o machado sai da mão")
	t.check_approx(float(_hunter(sim)["aether"]), 0.0, "e o Éter zera")
	var projectiles: Array = sim.snapshot().get("projectiles", [])
	t.check(projectiles.size() >= 1, "o projétil existe no Instantâneo")
	if projectiles.size() >= 1:
		t.check_eq(String(projectiles[0]["kind"]), "ruin", "e se identifica como o machado")


func test_axe_out_blocks_strikes_but_not_the_dodge(t: TestCase) -> void:
	var sim := _sim(500.0)
	sim.fill_aether(HUNTER)
	_run(sim, _in(false, false, false, false, true), 1, [], 500.0)
	_run(sim, _in(true, false, true), 1, [], 500.0)
	t.check(
		_state(sim) != int(HunterState.State.AXE_CHARGE)
			and _state(sim) != int(HunterState.State.ATTACK),
		"sem arma na mão, nenhum Golpe começa"
	)
	_run(sim, HunterInput.make(Vector2.UP, 0.0, 0, false, true), 1, [], 500.0)
	t.check_eq(_state(sim), int(HunterState.State.DODGE), "mas a esquiva continua livre")


func test_the_axe_returns_and_grants_determination(t: TestCase) -> void:
	var sim := _sim(500.0)
	sim.fill_aether(HUNTER)
	var events: Array = []
	_run(sim, _in(false, false, false, false, true), 1, events, 500.0)
	_run(sim, _in(), SECOND * 4, events, 500.0)

	t.check(not bool(_hunter(sim)["axe_out"]), "o machado volta para a mão")
	t.check_eq(int(_hunter(sim)["det_stacks"]), 1, "e o catch que conectou dá uma pilha")
	t.check(float(_hunter(sim)["aether"]) > 0.0, "o catch devolve Éter")
	t.check(_hits_named(events, "Voo da Ruína").size() >= 1, "o machado acerta no caminho")
	var caught := false
	for event in events:
		if event.get("type", "") == "axe_catch":
			caught = true
	t.check(caught, "o catch é anunciado")


func test_a_missed_throw_grants_no_stack(t: TestCase) -> void:
	var sim := _sim(0.0, false)
	sim.fill_aether(HUNTER)
	_run(sim, _in(false, false, false, false, true), 1)
	_run(sim, _in(), SECOND * 4)
	t.check(not bool(_hunter(sim)["axe_out"]), "o machado volta mesmo sem acertar")
	t.check_eq(int(_hunter(sim)["det_stacks"]), 0, "mas sem pilha: a Determinação se ganha conectando")


func test_recall_brings_it_back_early(t: TestCase) -> void:
	var sim := _sim(0.0, false)
	sim.fill_aether(HUNTER)
	_run(sim, _in(false, false, false, false, true), 1)
	_run(sim, _in(), 20)
	var away: Vector2 = (sim.snapshot()["projectiles"][0] as Dictionary)["pos"]
	_run(sim, _in(false, false, false, false, true), 1)
	_run(sim, _in(), 3)
	var projectiles: Array = sim.snapshot().get("projectiles", [])
	t.check(projectiles.size() >= 1, "o machado ainda está no ar")
	if projectiles.size() >= 1:
		var now: Vector2 = (projectiles[0] as Dictionary)["pos"]
		t.check(now.length() < away.length(), "o segundo Especial o faz voltar antes da hora")


## Determinação ----------------------------------------------------------------

func test_determination_boosts_damage(t: TestCase) -> void:
	var plain := HunterState.new()
	plain.weapon_id = Weapons.AXE
	var stacked := HunterState.new()
	stacked.weapon_id = Weapons.AXE
	HunterStep.grant_determination(stacked)
	t.check_approx(
		HunterStep.buff_multiplier(stacked),
		HunterStep.buff_multiplier(plain) * (1.0 + SimConfig.DETERMINATION_DAMAGE_PER_STACK),
		"uma pilha vale +15% de dano"
	)


func test_determination_decays_progressively(t: TestCase) -> void:
	var hunter := HunterState.new()
	hunter.weapon_id = Weapons.AXE
	for _i in 4:
		HunterStep.grant_determination(hunter)
	t.check_eq(hunter.det_stacks, SimConfig.DETERMINATION_MAX_STACKS, "o teto é 3 pilhas")

	var ladder: Array[int] = []
	for _i in SECOND * 40:
		HunterStep.step(hunter, HunterInput.new(), SimConfig.TICK_DELTA)
		if ladder.is_empty() or ladder[ladder.size() - 1] != hunter.det_stacks:
			ladder.append(hunter.det_stacks)
	t.check_eq(ladder, [3, 2, 1, 0] as Array[int], "a escada completa desce 3→2→1→0")


func test_axe_state_survives_the_snapshot(t: TestCase) -> void:
	var sim := _sim()
	_run(sim, _in(true, false, true), 1)
	_run(sim, _in(false, false, true), 20)
	var copy := HunterState.new()
	copy.apply_dict(_hunter(sim))
	t.check_approx(copy.charge_time, float(_hunter(sim)["charge_time"]), "charge_time atravessa")
	t.check_eq(copy.charge_kind, int(_hunter(sim)["charge_kind"]), "charge_kind atravessa")
	t.check_eq(copy.axe_out, bool(_hunter(sim)["axe_out"]), "axe_out atravessa")
	t.check_eq(copy.det_stacks, int(_hunter(sim)["det_stacks"]), "det_stacks atravessa")
	# O remoto também precisa de axe_out e das pilhas para desenhar certo.
	var view := HunterState.new()
	view.id = 7
	t.check(view.to_view_dict().has("axe_out"), "o view-dict leva axe_out")
	t.check(view.to_view_dict().has("det_stacks"), "e as pilhas")
