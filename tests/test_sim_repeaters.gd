extends RefCounted

## Ticket 13 — Repetidoras: tiro contínuo, pente de 12, queda por distância,
## recarga empoderada por PROXIMIDADE, Rolinho e Salva Explosiva.

const HUNTER: int = 1
const SECOND: int = SimConfig.TICK_RATE


func _sim(distance: float = 400.0) -> Sim:
	var sim := Sim.new(Behemoths.GNASHER)
	sim.add_hunter(HUNTER, "Teste", Weapons.REPEATERS)
	_park(sim, distance)
	return sim


func _park(sim: Sim, distance: float) -> void:
	var behemoth := sim.behemoth()
	behemoth.pos = Vector2(distance, 0.0)
	behemoth.facing = PI
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0


func _hunter(sim: Sim) -> Dictionary:
	return sim.snapshot()["hunters"][0]


func _run(sim: Sim, input: HunterInput, ticks: int, events: Array = [], distance: float = 400.0) -> void:
	for _i in ticks:
		_park(sim, distance)
		sim.set_input(HUNTER, input)
		sim.step(SimConfig.TICK_DELTA)
		events.append_array(sim.take_events())


func _in(
	light: bool = false, heavy: bool = false, light_held: bool = false,
	special: bool = false, reload: bool = false,
	move: Vector2 = Vector2.ZERO, sprint: bool = false
) -> HunterInput:
	return HunterInput.make(
		move, 0.0, 0, sprint, false, light, heavy, special, false, reload, light_held
	)


func _shots(events: Array) -> Array:
	var found: Array = []
	for event in events:
		if event.get("type", "") == "hit" and event.get("move", "") == "Tiro Duplo":
			found.append(event)
	return found


## Tiro contínuo -----------------------------------------------------------

func test_holding_fire_consumes_the_mag_at_cadence(t: TestCase) -> void:
	var sim := _sim()
	t.check_eq(int(_hunter(sim)["mag"]), SimConfig.REPEATER_MAG, "o pente nasce cheio")
	_run(sim, _in(true, false, true), SECOND)
	var spent := SimConfig.REPEATER_MAG - int(_hunter(sim)["mag"])
	t.check(spent >= 4 and spent <= 6, "um segundo segurando gasta ~5 tiros (veio %d)" % spent)


func test_firing_does_not_lock_movement(t: TestCase) -> void:
	var sim := _sim()
	var before: Vector2 = _hunter(sim)["pos"]
	_run(sim, _in(true, false, true, false, false, Vector2.UP), 30)
	t.check_eq(int(_hunter(sim)["state"]), int(HunterState.State.FREE), "atirar não tranca o Caçador")
	t.check(((_hunter(sim)["pos"] as Vector2) - before).length() > 50.0, "e dá para andar atirando")


func test_an_empty_mag_stops_firing(t: TestCase) -> void:
	var sim := _sim()
	_run(sim, _in(true, false, true), SECOND * 3)
	t.check_eq(int(_hunter(sim)["mag"]), 0, "o pente esvazia")
	var hp_before := sim.behemoth().hp
	_run(sim, _in(true, false, true), SECOND)
	t.check_approx(sim.behemoth().hp, hp_before, "com o pente vazio nada sai", 0.01)


func test_bullets_hit_and_grant_aether(t: TestCase) -> void:
	var sim := _sim()
	var events: Array = []
	_run(sim, _in(true, false, true), SECOND, events)
	t.check(_shots(events).size() >= 3, "os tiros conectam")
	t.check(float(_hunter(sim)["aether"]) > 0.0, "e enchem o medidor")


func test_damage_falls_with_distance(t: TestCase) -> void:
	var near := _sim(300.0)
	var near_events: Array = []
	_run(near, _in(true, false, true), SECOND, near_events, 300.0)
	var far := _sim(860.0)
	var far_events: Array = []
	_run(far, _in(true, false, true), SECOND, far_events, 860.0)

	var near_hits := _shots(near_events)
	var far_hits := _shots(far_events)
	t.check(near_hits.size() >= 1 and far_hits.size() >= 1, "os dois conectaram")
	if near_hits.is_empty() or far_hits.is_empty():
		return
	t.check(
		float(far_hits[0]["amount"]) < float(near_hits[0]["amount"]),
		"de longe o tiro bate menos"
	)


func test_full_damage_before_the_falloff(t: TestCase) -> void:
	# A 300 e a 400 o projétil percorre menos que `falloff_start` até o corpo:
	# dano cheio nos dois.
	var close_events: Array = []
	_run(_sim(300.0), _in(true, false, true), SECOND, close_events, 300.0)
	var mid_events: Array = []
	_run(_sim(400.0), _in(true, false, true), SECOND, mid_events, 400.0)
	var close_hits := _shots(close_events)
	var mid_hits := _shots(mid_events)
	t.check(close_hits.size() >= 1 and mid_hits.size() >= 1, "os dois conectaram")
	if close_hits.is_empty() or mid_hits.is_empty():
		return
	t.check_approx(
		float(mid_hits[0]["amount"]), float(close_hits[0]["amount"]),
		"antes do início da queda o dano é o mesmo", 0.01
	)


## Recarga -----------------------------------------------------------------

func test_reload_refills_after_the_time(t: TestCase) -> void:
	var sim := _sim(800.0)
	_run(sim, _in(true, false, true), SECOND, [], 800.0)
	_run(sim, _in(false, false, false, false, true), 1, [], 800.0)
	t.check_eq(int(_hunter(sim)["state"]), int(HunterState.State.RELOADING), "R entra em recarga")
	_run(sim, _in(), int(SimConfig.REPEATER_RELOAD_TIME * SECOND) + 4, [], 800.0)
	t.check_eq(int(_hunter(sim)["mag"]), SimConfig.REPEATER_MAG, "o pente volta cheio")
	t.check_eq(int(_hunter(sim)["empowered_shots"]), 0, "longe do monstro não empodera")


func test_reloading_next_to_the_behemoth_empowers(t: TestCase) -> void:
	var sim := _sim(130.0)
	var events: Array = []
	_run(sim, _in(true, false, true), SECOND, events, 130.0)
	_run(sim, _in(false, false, false, false, true), 1, events, 130.0)
	_run(sim, _in(), int(SimConfig.REPEATER_RELOAD_TIME * SECOND) + 4, events, 130.0)
	t.check_eq(int(_hunter(sim)["empowered_shots"]), SimConfig.REPEATER_MAG,
		"recarregar colado empodera o pente inteiro")
	var announced := false
	for event in events:
		if event.get("type", "") == "empowered":
			announced = true
	t.check(announced, "e o empoderamento é anunciado")


func test_empowered_bullets_hit_harder(t: TestCase) -> void:
	var plain := _sim(300.0)
	var plain_events: Array = []
	_run(plain, _in(true, false, true), 20, plain_events, 300.0)

	var strong := _sim(300.0)
	# Gasta algumas balas (a recarga exige pente incompleto) e recarrega
	# COLADO, que é o que empodera.
	_run(strong, _in(true, false, true), 30, [], 130.0)
	_run(strong, _in(false, false, false, false, true), 1, [], 130.0)
	_run(strong, _in(), int(SimConfig.REPEATER_RELOAD_TIME * SECOND) + 4, [], 130.0)
	var strong_events: Array = []
	_run(strong, _in(true, false, true), 20, strong_events, 300.0)

	var plain_hits := _shots(plain_events)
	var strong_hits := _shots(strong_events)
	t.check(plain_hits.size() >= 1 and strong_hits.size() >= 1, "os dois conectaram")
	if plain_hits.is_empty() or strong_hits.is_empty():
		return
	t.check(
		float(strong_hits[0]["amount"]) > float(plain_hits[0]["amount"]) * 1.2,
		"o tiro empoderado bate ~25% a mais"
	)
	t.check(int(_hunter(strong)["empowered_shots"]) < SimConfig.REPEATER_MAG,
		"e cada tiro consome um empoderado")


func test_empowerment_overwrites_and_never_stacks(t: TestCase) -> void:
	var sim := _sim(130.0)
	_run(sim, _in(true, false, true), 40, [], 130.0)
	_run(sim, _in(false, false, false, false, true), 1, [], 130.0)
	_run(sim, _in(), int(SimConfig.REPEATER_RELOAD_TIME * SECOND) + 4, [], 130.0)
	t.check_eq(int(_hunter(sim)["empowered_shots"]), SimConfig.REPEATER_MAG, "empoderado perto")

	_run(sim, _in(true, false, true), 40, [], 130.0)
	_run(sim, _in(false, false, false, false, true), 1, [], 900.0)
	_run(sim, _in(), int(SimConfig.REPEATER_RELOAD_TIME * SECOND) + 4, [], 900.0)
	t.check_eq(int(_hunter(sim)["empowered_shots"]), 0, "recarregar longe SOBRESCREVE com zero")

	_run(sim, _in(true, false, true), 40, [], 130.0)
	_run(sim, _in(false, false, false, false, true), 1, [], 130.0)
	_run(sim, _in(), int(SimConfig.REPEATER_RELOAD_TIME * SECOND) + 4, [], 130.0)
	_run(sim, _in(false, false, false, false, true), 1, [], 130.0)
	_run(sim, _in(), int(SimConfig.REPEATER_RELOAD_TIME * SECOND) + 4, [], 130.0)
	t.check(int(_hunter(sim)["empowered_shots"]) <= SimConfig.REPEATER_MAG,
		"duas recargas coladas não acumulam 24")


func test_the_hammer_reload_is_untouched_by_the_per_weapon_branch(t: TestCase) -> void:
	var sim := Sim.new(Behemoths.GNASHER)
	sim.add_hunter(HUNTER, "Teste", Weapons.HAMMER)
	var hunter := HunterState.new()
	hunter.weapon_id = Weapons.HAMMER
	hunter.ammo = 0
	var reload := HunterInput.new()
	reload.reload = true
	HunterStep.step(hunter, reload, SimConfig.TICK_DELTA, {})
	t.check_eq(hunter.state, HunterState.State.RELOADING, "o Martelo continua entrando em recarga")
	for _i in int(SimConfig.RELOAD_TIME * SECOND) + 4:
		HunterStep.step(hunter, HunterInput.new(), SimConfig.TICK_DELTA, {})
	t.check_eq(hunter.ammo, SimConfig.HAMMER_MAX_AMMO, "e enchendo no tempo cheio")


## Rolinho ------------------------------------------------------------------

func test_the_tumble_dashes_sideways(t: TestCase) -> void:
	var sim := _sim()
	var before: Vector2 = _hunter(sim)["pos"]
	var stamina_before: float = _hunter(sim)["stamina"]
	_run(sim, _in(false, true), 1)
	t.check_eq(int(_hunter(sim)["state"]), int(HunterState.State.TUMBLE), "o pesado é o Rolinho")
	_run(sim, _in(), int(SimConfig.TUMBLE_DURATION * SECOND) + 2)
	var moved: Vector2 = (_hunter(sim)["pos"] as Vector2) - before
	t.check(absf(moved.y) > 50.0, "o Rolinho é LATERAL (mira em +x, desloca em y)")
	t.check(absf(moved.x) < absf(moved.y) * 0.3, "quase nada para a frente")
	t.check_approx(
		float(_hunter(sim)["stamina"]),
		stamina_before - float(Weapons.move(Weapons.REPEATERS, Weapons.Kind.HEAVY, 0)["stamina"]),
		"e cobra o vigor do dado", 1.5
	)


func test_the_tumble_iframes_are_shorter_than_the_dodge(t: TestCase) -> void:
	t.check(
		SimConfig.TUMBLE_IFRAMES_END < SimConfig.DODGE_IFRAMES_END,
		"o Rolinho cobre menos que a Esquiva: é mobilidade, não esquiva melhor"
	)
	var hunter := HunterState.new()
	hunter.weapon_id = Weapons.REPEATERS
	var heavy := HunterInput.new()
	heavy.heavy = true
	HunterStep.step(hunter, heavy, SimConfig.TICK_DELTA, {})
	t.check(hunter.invulnerable, "o começo do Rolinho é invulnerável")
	for _i in int(SimConfig.TUMBLE_IFRAMES_END * SECOND) + 2:
		HunterStep.step(hunter, HunterInput.new(), SimConfig.TICK_DELTA, {})
	t.check(not hunter.invulnerable, "e a cobertura acaba antes do deslocamento")


## Salva Explosiva -----------------------------------------------------------

func test_the_salvo_explodes_in_area(t: TestCase) -> void:
	var sim := _sim(600.0)
	sim.fill_aether(HUNTER)
	var hp_before := sim.behemoth().hp
	var events: Array = []
	_run(sim, _in(false, false, false, true), 1, events, 600.0)
	var projectiles: Array = sim.snapshot().get("projectiles", [])
	t.check(projectiles.size() >= 1, "a Salva existe no Instantâneo")
	if projectiles.size() >= 1:
		t.check_eq(String(projectiles[0]["kind"]), "salvo", "identificada como Salva")
	_run(sim, _in(), SECOND * 2, events, 600.0)
	var exploded := false
	for event in events:
		if event.get("type", "") == "explosion":
			exploded = true
	t.check(exploded, "ela estoura")
	t.check(sim.behemoth().hp < hp_before - 40.0, "e machuca em área")


func test_an_empowered_salvo_fires_three(t: TestCase) -> void:
	var sim := _sim(130.0)
	_run(sim, _in(true, false, true), 40, [], 130.0)
	_run(sim, _in(false, false, false, false, true), 1, [], 130.0)
	_run(sim, _in(), int(SimConfig.REPEATER_RELOAD_TIME * SECOND) + 4, [], 130.0)
	var empowered_before := int(_hunter(sim)["empowered_shots"])
	t.check_eq(empowered_before, SimConfig.REPEATER_MAG, "pente empoderado")

	sim.fill_aether(HUNTER)
	_run(sim, _in(false, false, false, true), 1, [], 900.0)
	var projectiles: Array = sim.snapshot().get("projectiles", [])
	t.check_eq(projectiles.size(), 3, "empoderada, a Salva sai em leque de três")
	t.check_eq(int(_hunter(sim)["empowered_shots"]), empowered_before,
		"e o Especial NÃO consome o empoderamento: só os tiros consomem")


func test_ballistic_has_no_sever_or_hard_bonus(t: TestCase) -> void:
	t.check(
		not SimConfig.STAGGER_TYPE_MULT.has(null),
		"a tabela de Atordoamento existe"
	)
	t.check(
		SimConfig.STAGGER_TYPE_MULT.has(Weapons.DamageType.BALLISTIC),
		"o Balístico tem entrada própria no Atordoamento"
	)
	var severable := {"severable": true, "hard": false, "broken": false}
	var hard := {"severable": false, "hard": true, "broken": false}
	var move := {"damage": 100.0}
	var against_severable := Combat.damage_against(
		move, Weapons.DamageType.BALLISTIC, Elements.Element.NEUTRAL,
		Elements.Element.NEUTRAL, severable, false
	)
	var against_hard := Combat.damage_against(
		move, Weapons.DamageType.BALLISTIC, Elements.Element.NEUTRAL,
		Elements.Element.NEUTRAL, hard, false
	)
	t.check_approx(against_severable, 100.0, "balístico não ganha bônus de decepar")
	t.check_approx(against_hard, 100.0, "nem de Parte dura")


func test_repeater_state_survives_the_snapshot(t: TestCase) -> void:
	var sim := _sim()
	_run(sim, _in(true, false, true), 20)
	var copy := HunterState.new()
	copy.apply_dict(_hunter(sim))
	t.check_eq(copy.mag, int(_hunter(sim)["mag"]), "mag atravessa o Instantâneo")
	t.check_eq(copy.empowered_shots, int(_hunter(sim)["empowered_shots"]), "empowered_shots também")
	t.check_approx(copy.fire_cooldown, float(_hunter(sim)["fire_cooldown"]), "e a cadência")


func test_a_dry_input_queue_keeps_the_trigger_held(t: TestCase) -> void:
	# Pacote atrasado não pode engasgar o tiro contínuo: `light_held` é
	# contínuo e sobrevive à fila seca, como o `heavy_held`.
	var sim := _sim()
	sim.set_input(HUNTER, _in(true, false, true))
	for _i in 60:
		_park(sim, 400.0)
		sim.step(SimConfig.TICK_DELTA)
		sim.take_events()
	t.check(int(_hunter(sim)["mag"]) < SimConfig.REPEATER_MAG - 2,
		"com a fila seca o gatilho continua segurado")
