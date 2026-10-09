extends RefCounted

## Ticket 07: a carga do Martelo, o Gancho das Lâminas e os três Especiais.

const HUNTER: int = 1
const SECOND: int = SimConfig.TICK_RATE

func _sim(weapon: String, with_behemoth: bool = true) -> Sim:
	var sim := Sim.new(Behemoths.GNASHER if with_behemoth else "")
	sim.add_hunter(HUNTER, "Teste", weapon)
	return sim

func _beh(sim: Sim) -> BehemothState:
	return sim.behemoth()

func _hunter(sim: Sim) -> Dictionary:
	return sim.snapshot()["hunters"][0]

## Estaciona o monstro colado ao Caçador (origem), de frente, com a IA presa.
func _park(sim: Sim, distance: float = 130.0) -> void:
	var behemoth := _beh(sim)
	behemoth.pos = Vector2(distance, 0.0)
	behemoth.facing = PI
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0

## Mantém o monstro no lugar enquanto a Sim anda N Tiques com a Entrada dada.
func _run(sim: Sim, input: HunterInput, ticks: int, hold_behemoth: bool = true) -> void:
	for _i in ticks:
		if hold_behemoth and _beh(sim) != null:
			_beh(sim).pos = Vector2(130.0, 0.0)
			_beh(sim).facing = PI
			for key in _beh(sim).cooldowns:
				_beh(sim).cooldowns[key] = 999.0
		sim.set_input(HUNTER, input)
		sim.step(SimConfig.TICK_DELTA)

func _in(
	heavy: bool = false, held: bool = false, special: bool = false,
	aim: float = 0.0, move: Vector2 = Vector2.ZERO
) -> HunterInput:
	return HunterInput.make(move, aim, 0, false, false, false, heavy, special, held)


## Rajada Concussiva do Martelo ------------------------------------------------

func test_holding_heavy_arms_without_firing(t: TestCase) -> void:
	var sim := _sim(Weapons.HAMMER)
	_park(sim)
	var hp_before := _beh(sim).hp

	_run(sim, _in(true, true), 1)
	t.check_eq(int(_hunter(sim)["state"]), int(HunterState.State.CHARGING), "segurar o pesado arma a Rajada")
	t.check_eq(int(_hunter(sim)["ammo"]), 3, "e já engole uma munição")

	_run(sim, _in(false, true), SECOND)
	t.check_eq(int(_hunter(sim)["state"]), int(HunterState.State.CHARGING), "e segue armada enquanto segura")
	t.check_approx(_beh(sim).hp, hp_before, "sem soltar, nada sai")


func test_holding_longer_consumes_more_ammo_and_scales(t: TestCase) -> void:
	var tap := _sim(Weapons.HAMMER)
	_park(tap)
	var tap_before := _beh(tap).hp
	_run(tap, _in(true, true), 1)             # arma (1 munição)
	_run(tap, _in(false, false), SECOND)      # solta na hora
	var tap_taken := tap_before - _beh(tap).hp

	var held := _sim(Weapons.HAMMER)
	_park(held)
	var held_before := _beh(held).hp
	_run(held, _in(true, true), 1)
	_run(held, _in(false, true), int(SECOND * 2.1))   # 2,1s: engole a 2ª e a 3ª
	t.check_eq(int(_hunter(held)["ammo"]), 1, "segurar 2s engoliu três munições")
	_run(held, _in(false, false), SECOND)
	var held_taken := held_before - _beh(held).hp

	t.check(tap_taken > 0.0, "o toque dispara uma Rajada de 1 munição")
	t.check(held_taken > tap_taken * 2.0, "três munições batem quase o triplo")


func test_a_two_shell_blast_knocks_the_behemoth_down(t: TestCase) -> void:
	# 150 de Atordoamento x 2 munições x 2,2 (Impacto) = 660, acima do limiar
	# de 420. Uma munição só (330) não derruba: a Rajada é o interruptor.
	var sim := _sim(Weapons.HAMMER)
	_park(sim)
	_run(sim, _in(true, true), 1)
	_run(sim, _in(false, true), int(SECOND * 1.1))
	_run(sim, _in(false, false), SECOND)

	t.check_eq(int(_beh(sim).state), int(BehemothState.State.STAGGERED), "duas munições derrubam")


## Gancho das Lâminas ----------------------------------------------------------

func test_the_hook_pulls_to_the_behemoth(t: TestCase) -> void:
	var sim := _sim(Weapons.BLADES)
	var behemoth := _beh(sim)
	behemoth.pos = Vector2(300.0, 0.0)
	behemoth.facing = PI
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0

	var stamina_before: float = _hunter(sim)["stamina"]
	sim.set_input(HUNTER, _in(true, false))
	sim.step(SimConfig.TICK_DELTA)
	t.check_eq(int(_hunter(sim)["state"]), int(HunterState.State.HOOK_PULL), "o Gancho pega e puxa")

	for _i in SECOND:
		behemoth.pos = Vector2(300.0, 0.0)
		sim.set_input(HUNTER, _in())
		sim.step(SimConfig.TICK_DELTA)

	var pos: Vector2 = _hunter(sim)["pos"]
	t.check_approx(
		pos.distance_to(behemoth.pos),
		behemoth.radius + SimConfig.HUNTER_RADIUS + SimConfig.HOOK_ARRIVE_GAP,
		"o Caçador foi parar rente ao Behemoth"
	)
	t.check_approx(_hunter(sim)["stamina"], stamina_before, "e o puxão não custou Fôlego", 1.0)


func test_the_hook_does_nothing_when_out_of_range(t: TestCase) -> void:
	var sim := _sim(Weapons.BLADES)
	var behemoth := _beh(sim)
	behemoth.pos = Vector2(800.0, 0.0)  # longe demais (alcance 420)
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0

	sim.set_input(HUNTER, _in(true, false))
	sim.step(SimConfig.TICK_DELTA)

	t.check(int(_hunter(sim)["state"]) != int(HunterState.State.HOOK_PULL), "errar o Gancho não puxa")
	t.check_vec_approx(_hunter(sim)["pos"], Vector2.ZERO, "e o Caçador não sai do lugar", 1.0)


## Especiais --------------------------------------------------------------------

func test_a_special_needs_a_full_meter(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD)
	_park(sim)
	sim.set_input(HUNTER, _in(false, false, true))
	sim.step(SimConfig.TICK_DELTA)

	t.check_approx(float(_hunter(sim)["valor_time"]), 0.0, "sem Éter cheio, o Especial não sai")


func test_valor_consumes_aether_and_boosts_damage(t: TestCase) -> void:
	var plain := _sim(Weapons.SWORD)
	_park(plain)
	var plain_before := _beh(plain).hp
	_run(plain, HunterInput.make(Vector2.ZERO, 0.0, 0, false, false, true), 1)
	_run(plain, _in(), SECOND)
	var plain_taken := plain_before - _beh(plain).hp

	var valorous := _sim(Weapons.SWORD)
	_park(valorous)
	valorous.fill_aether(HUNTER)
	_run(valorous, _in(false, false, true), 1)
	t.check(float(_hunter(valorous)["valor_time"]) > 0.0, "o Valor liga")
	t.check_approx(float(_hunter(valorous)["aether"]), 0.0, "e consome o Éter inteiro")

	var valor_before := _beh(valorous).hp
	_run(valorous, HunterInput.make(Vector2.ZERO, 0.0, 0, false, false, true), 1)
	_run(valorous, _in(), SECOND)
	var valor_taken := valor_before - _beh(valorous).hp

	t.check(valor_taken > plain_taken * 1.15, "com Valor o mesmo Golpe tira mais")


func test_magma_flies_and_explodes_on_the_behemoth(t: TestCase) -> void:
	var sim := _sim(Weapons.HAMMER)
	var behemoth := _beh(sim)
	behemoth.pos = Vector2(400.0, 0.0)
	behemoth.facing = PI
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0
	sim.fill_aether(HUNTER)
	var hp_before := behemoth.hp

	sim.set_input(HUNTER, _in(false, false, true))
	sim.step(SimConfig.TICK_DELTA)
	t.check(sim.snapshot().has("projectiles"), "o tiro existe no Instantâneo")

	var exploded := false
	for _i in SECOND * 2:
		behemoth.pos = Vector2(400.0, 0.0)
		for key in behemoth.cooldowns:
			behemoth.cooldowns[key] = 999.0
		sim.set_input(HUNTER, _in())
		sim.step(SimConfig.TICK_DELTA)
		for event in sim.take_events():
			if event["type"] == "explosion":
				exploded = true

	t.check(exploded, "o tiro explode")
	t.check(behemoth.hp < hp_before - 40.0, "e a explosão machuca")
	t.check(behemoth.stagger > 0.0 or behemoth.state == BehemothState.State.STAGGERED,
		"com muito Atordoamento junto")
	t.check(not sim.snapshot().has("projectiles"), "e o projétil some depois")


func test_magma_expires_at_max_range(t: TestCase) -> void:
	# Sem Behemoth na Arena: o tiro viaja até o fim do alcance e estoura no ar.
	var sim := _sim(Weapons.HAMMER, false)
	sim.fill_aether(HUNTER)
	sim.set_input(HUNTER, _in(false, false, true))
	sim.step(SimConfig.TICK_DELTA)
	t.check(sim.snapshot().has("projectiles"), "o tiro sai mesmo sem alvo")

	var exploded := false
	for _i in SECOND * 2:
		sim.set_input(HUNTER, _in())
		sim.step(SimConfig.TICK_DELTA)
		for event in sim.take_events():
			if event["type"] == "explosion":
				exploded = true

	t.check(exploded, "no fim do alcance ele estoura sozinho")
	t.check(not sim.snapshot().has("projectiles"), "e deixa de existir")


func test_reaper_dance_hits_many_times(t: TestCase) -> void:
	var sim := _sim(Weapons.BLADES)
	_park(sim)
	sim.fill_aether(HUNTER)

	sim.set_input(HUNTER, _in(false, false, true))
	sim.step(SimConfig.TICK_DELTA)
	t.check_eq(int(_hunter(sim)["state"]), int(HunterState.State.SPECIAL_SPIN), "a Dança começa")

	var hits := 0
	for _i in SECOND * 3:
		_beh(sim).pos = Vector2(130.0, 0.0)
		for key in _beh(sim).cooldowns:
			_beh(sim).cooldowns[key] = 999.0
		sim.set_input(HUNTER, _in())
		sim.step(SimConfig.TICK_DELTA)
		for event in sim.take_events():
			if event["type"] == "hit" and event["move"] == "Dança da Ceifadora":
				hits += 1

	t.check(hits >= 6, "o giro acerta muitas vezes (veio %d)" % hits)
	t.check_eq(int(_hunter(sim)["state"]), int(HunterState.State.FREE), "e acaba sozinho")
