extends RefCounted

## O rework clássico das armas (munição e recarga do Martelo, Onda de Valor,
## Momentum e Golpe de Corrente) e o Bastião com a Armadura que sempre vaza.

const HUNTER: int = 1
const SECOND: int = SimConfig.TICK_RATE

func _sim(weapon: String, behemoth: String = Behemoths.GNASHER,
		weapon_element: Elements.Element = Elements.Element.NEUTRAL,
		behemoth_element: Elements.Element = Elements.Element.NEUTRAL) -> Sim:
	var sim := Sim.new(behemoth, behemoth_element)
	sim.add_hunter(HUNTER, "Teste", weapon)
	sim.set_weapon(HUNTER, weapon, weapon_element)
	return sim

func _beh(sim: Sim) -> BehemothState:
	return sim.behemoth()

func _hunter(sim: Sim) -> Dictionary:
	return sim.snapshot()["hunters"][0]

func _park(sim: Sim, distance: float = 130.0, facing: float = PI) -> void:
	var behemoth := _beh(sim)
	behemoth.pos = Vector2(distance, 0.0)
	behemoth.facing = facing
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0

## Anda N Tiques segurando o monstro no lugar, acumulando os eventos.
func _run(sim: Sim, input: HunterInput, ticks: int, events: Array = [],
		distance: float = 130.0, facing: float = PI) -> void:
	for _i in ticks:
		if _beh(sim) != null:
			_beh(sim).pos = Vector2(distance, 0.0)
			_beh(sim).facing = facing
			for key in _beh(sim).cooldowns:
				_beh(sim).cooldowns[key] = 999.0
		sim.set_input(HUNTER, input)
		sim.step(SimConfig.TICK_DELTA)
		events.append_array(sim.take_events())

func _in(light: bool = false, heavy: bool = false, held: bool = false,
		special: bool = false, reload: bool = false) -> HunterInput:
	return HunterInput.make(Vector2.ZERO, 0.0, 0, false, false, light, heavy, special, held, reload)

func _hits_named(events: Array, move_name: String) -> Array:
	var found: Array = []
	for event in events:
		if event.get("type", "") == "hit" and event.get("move", "") == move_name:
			found.append(event)
	return found

## Esvazia as munições pelo caminho do jogo: segura o leve até o combo chegar
## ao terceiro golpe, guarda o pesado durante ele e deixa o finalizador sair.
func _empty_ammo(sim: Sim, events: Array = []) -> void:
	var guard := 0
	while guard < SECOND * 8:
		guard += 1
		var hunter := _hunter(sim)
		if int(hunter["state"]) == int(HunterState.State.ATTACK) \
				and int(hunter["attack_kind"]) == int(Weapons.Kind.LIGHT) \
				and int(hunter["attack_index"]) == 2:
			break
		_run(sim, _in(true), 1, events)
	_run(sim, _in(false, true), 1, events)
	# O terceiro leve ainda termina antes do Estouro começar: espera voltar ao
	# controle em vez de chutar um tempo fixo.
	var settle := 0
	while settle < SECOND * 5 and int(_hunter(sim)["state"]) != int(HunterState.State.FREE):
		settle += 1
		_run(sim, _in(), 1, events)


## Martelo: munição, Coronhada e finalizador ---------------------------------

func test_a_blast_spends_one_shell(t: TestCase) -> void:
	var sim := _sim(Weapons.HAMMER)
	_park(sim)
	t.check_eq(int(_hunter(sim)["ammo"]), 4, "o Martelo nasce com 4 munições")

	_run(sim, _in(false, true, true), 1)
	_run(sim, _in(false, false, false), SECOND)

	t.check_eq(int(_hunter(sim)["ammo"]), 3, "o toque gasta exatamente uma")


func test_the_finisher_discharges_everything(t: TestCase) -> void:
	var sim := _sim(Weapons.HAMMER)
	_park(sim)
	var events: Array = []
	_empty_ammo(sim, events)

	t.check_eq(int(_hunter(sim)["ammo"]), 0, "o finalizador descarrega todas as munições")
	t.check(_hits_named(events, "Estouro Aéter").size() >= 1, "e o Estouro Aéter conecta")
	var behemoth := _beh(sim)
	t.check(
		behemoth.state == BehemothState.State.STAGGERED or behemoth.stagger > 0.0,
		"quatro munições de uma vez sacodem o medidor"
	)


func test_no_ammo_heavy_is_the_weak_hit(t: TestCase) -> void:
	var sim := _sim(Weapons.HAMMER)
	_park(sim)
	_empty_ammo(sim)

	var events: Array = []
	_run(sim, _in(false, true, true), 1, events)
	t.check(int(_hunter(sim)["state"]) != int(HunterState.State.CHARGING), "sem munição não arma Rajada")
	_run(sim, _in(), SECOND, events)

	t.check(_hits_named(events, "Coronhada").size() >= 1, "sai a Coronhada fraca")
	t.check_eq(int(_hunter(sim)["ammo"]), 0, "e nenhuma munição aparece do nada")


## Recarga --------------------------------------------------------------------

func test_a_standard_reload_refills_after_the_full_time(t: TestCase) -> void:
	var sim := _sim(Weapons.HAMMER)
	_park(sim)
	_empty_ammo(sim)

	_run(sim, _in(false, false, false, false, true), 1)
	t.check_eq(int(_hunter(sim)["state"]), int(HunterState.State.RELOADING), "R entra em recarga")

	_run(sim, _in(), int(SimConfig.RELOAD_TIME * SECOND * 0.8))
	t.check_eq(int(_hunter(sim)["state"]), int(HunterState.State.RELOADING), "no meio ainda não acabou")

	_run(sim, _in(), int(SimConfig.RELOAD_TIME * SECOND * 0.3) + 4)
	t.check_eq(int(_hunter(sim)["ammo"]), 4, "no tempo cheio as 4 voltam")
	t.check_eq(int(_hunter(sim)["state"]), int(HunterState.State.FREE), "e o Caçador volta ao controle")


func test_a_timed_press_finishes_the_reload_early(t: TestCase) -> void:
	var sim := _sim(Weapons.HAMMER)
	_park(sim)
	_empty_ammo(sim)

	_run(sim, _in(false, false, false, false, true), 1)
	# Espera até dentro da janela (0,5–0,8s) e aperta de novo.
	_run(sim, _in(), int(0.6 * SECOND))
	_run(sim, _in(false, false, false, false, true), 1)

	t.check_eq(int(_hunter(sim)["ammo"]), 4, "a recarga cronometrada termina na hora")
	t.check_eq(int(_hunter(sim)["state"]), int(HunterState.State.FREE), "sem esperar o tempo cheio")


func test_a_mistimed_press_locks_the_reload_longer(t: TestCase) -> void:
	var sim := _sim(Weapons.HAMMER)
	_park(sim)
	_empty_ammo(sim)

	_run(sim, _in(false, false, false, false, true), 1)
	_run(sim, _in(), 3)
	# Cedo demais (bem antes da janela de 0,5s): falha.
	_run(sim, _in(false, false, false, false, true), 1)

	_run(sim, _in(), int(SimConfig.RELOAD_TIME * SECOND) + 3)
	t.check_eq(int(_hunter(sim)["state"]), int(HunterState.State.RELOADING),
		"falhou: no tempo normal ainda está travado")

	_run(sim, _in(), int(SimConfig.RELOAD_FAIL_EXTRA * SECOND) + 6)
	t.check_eq(int(_hunter(sim)["ammo"]), 4, "mas a recarga termina no tempo estendido")


## Onda de Valor ----------------------------------------------------------------

func test_valor_waves_only_exist_during_the_buff(t: TestCase) -> void:
	var plain := _sim(Weapons.SWORD)
	_park(plain)
	var plain_events: Array = []
	_run(plain, _in(true), 1, plain_events)
	_run(plain, _in(), SECOND * 2, plain_events)
	t.check_eq(_hits_named(plain_events, "Onda de Valor").size(), 0, "sem buff, nenhuma onda")

	var buffed := _sim(Weapons.SWORD)
	_park(buffed)
	buffed.fill_aether(HUNTER)
	var events: Array = []
	_run(buffed, _in(false, false, false, true), 1, events)
	_run(buffed, _in(true), 1, events)
	_run(buffed, _in(), SECOND * 2, events)

	t.check(_hits_named(events, "Onda de Valor").size() >= 1, "com Valor, o Golpe conectado emite a onda")


func test_the_wave_carries_the_weapon_element(t: TestCase) -> void:
	# Contra um Behemoth Gélido, a onda de uma arma de Incêndio bate com o
	# bônus de Oposição; a Neutra, sem bônus.
	var neutral := _sim(Weapons.SWORD, Behemoths.GNASHER, Elements.Element.NEUTRAL, Elements.Element.FROST)
	_park(neutral)
	neutral.fill_aether(HUNTER)
	var neutral_events: Array = []
	_run(neutral, _in(false, false, false, true), 1, neutral_events)
	_run(neutral, _in(true), 1, neutral_events)
	_run(neutral, _in(), SECOND * 2, neutral_events)
	var neutral_waves := _hits_named(neutral_events, "Onda de Valor")

	var blaze := _sim(Weapons.SWORD, Behemoths.GNASHER, Elements.Element.BLAZE, Elements.Element.FROST)
	_park(blaze)
	blaze.fill_aether(HUNTER)
	var blaze_events: Array = []
	_run(blaze, _in(false, false, false, true), 1, blaze_events)
	_run(blaze, _in(true), 1, blaze_events)
	_run(blaze, _in(), SECOND * 2, blaze_events)
	var blaze_waves := _hits_named(blaze_events, "Onda de Valor")

	t.check(neutral_waves.size() >= 1 and blaze_waves.size() >= 1, "as duas ondas conectaram")
	if neutral_waves.size() >= 1 and blaze_waves.size() >= 1:
		t.check(
			float(blaze_waves[0]["amount"]) > float(neutral_waves[0]["amount"]) * 1.1,
			"a onda de Incêndio machuca mais o Gélido: a Oposição vale à distância"
		)


## Momentum e Golpe de Corrente ---------------------------------------------------

func test_light_hits_build_momentum_pips(t: TestCase) -> void:
	var sim := _sim(Weapons.BLADES)
	_park(sim)

	for _i in 3:
		_run(sim, _in(true), 1)
		_run(sim, _in(), int(SECOND * 0.5))
	t.check_eq(int(_hunter(sim)["pips"]), 1, "três conexões enchem o primeiro pip")

	for _i in 6:
		_run(sim, _in(true), 1)
		_run(sim, _in(), int(SECOND * 0.5))
	t.check_eq(int(_hunter(sim)["pips"]), 3, "nove conexões lotam os três pips")
	t.check_approx(float(_hunter(sim)["momentum"]), 0.0, "e o medidor para de acumular no teto")


func test_the_chain_slam_spends_pips_and_scales(t: TestCase) -> void:
	# Sem pips: o Corrente sai fraco.
	var weak := _sim(Weapons.BLADES)
	_park(weak)
	var weak_events: Array = []
	_run(weak, _in(false, true), 1, weak_events)
	_run(weak, _in(), SECOND, weak_events)
	var weak_hits := _hits_named(weak_events, "Golpe de Corrente")
	t.check(weak_hits.size() >= 1, "colado, o pesado vira o Golpe de Corrente")

	# Com 3 pips: bem mais forte, e os pips zeram.
	var strong := _sim(Weapons.BLADES)
	_park(strong)
	for _i in 9:
		_run(strong, _in(true), 1)
		_run(strong, _in(), int(SECOND * 0.5))
	t.check_eq(int(_hunter(strong)["pips"]), 3, "pips cheios antes do Corrente")

	var strong_events: Array = []
	_run(strong, _in(false, true), 1, strong_events)
	_run(strong, _in(), SECOND, strong_events)
	var strong_hits := _hits_named(strong_events, "Golpe de Corrente")

	t.check(strong_hits.size() >= 1, "o Corrente carregado conecta")
	if weak_hits.size() >= 1 and strong_hits.size() >= 1:
		t.check(
			float(strong_hits[0]["amount"]) > float(weak_hits[0]["amount"]) * 2.0,
			"três pips mais que dobram o dano"
		)
	t.check_eq(int(_hunter(strong)["pips"]), 0, "e o Corrente gasta tudo")


func test_the_hook_still_fires_from_afar(t: TestCase) -> void:
	var sim := _sim(Weapons.BLADES)
	var behemoth := _beh(sim)
	behemoth.pos = Vector2(300.0, 0.0)
	behemoth.facing = PI
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0

	sim.set_input(HUNTER, _in(false, true))
	sim.step(SimConfig.TICK_DELTA)
	t.check_eq(int(_hunter(sim)["state"]), int(HunterState.State.HOOK_PULL),
		"longe do corpo, o pesado continua sendo o Gancho")


## Bastião: a Armadura que sempre vaza -------------------------------------------

func test_armor_leaks_a_sliver_of_damage_never_zero(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD, Behemoths.BASTION)
	_park(sim, 150.0)
	var behemoth := _beh(sim)
	var hp_before := behemoth.hp
	var part_before := float(behemoth.part("head")["hp"])

	_run(sim, _in(true), 1, [], 150.0)
	_run(sim, _in(), SECOND, [], 150.0)

	var body_taken := hp_before - behemoth.hp
	var part_taken := part_before - float(behemoth.part("head")["hp"])

	t.check(body_taken > 0.0, "a placa NUNCA zera o dano: sempre vaza algo")
	t.check(body_taken < part_taken * 0.3, "mas segura o grosso (a Vida sente só a fração)")
	t.check_approx(body_taken, part_taken * SimConfig.ARMOR_LEAK, "exatamente a fração da regra", 0.5)


func test_the_unarmored_tail_takes_full_damage(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD, Behemoths.BASTION)
	_park(sim, 150.0, 0.0)  # de costas: a Cauda-maça, sem placa
	var behemoth := _beh(sim)
	var hp_before := behemoth.hp

	_run(sim, _in(true), 1, [], 150.0, 0.0)
	_run(sim, _in(), SECOND, [], 150.0, 0.0)

	# Corte contra decepável: 20 × 1,4 = 28, direto na Vida.
	t.check(hp_before - behemoth.hp > 20.0, "a rota sem armadura existe: a cauda sente o golpe cheio")


func test_breaking_the_plate_opens_full_and_bonus_damage(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD, Behemoths.BASTION)
	_park(sim, 150.0)
	var behemoth := _beh(sim)
	behemoth.part("head")["hp"] = 1.0

	var events: Array = []
	_run(sim, _in(true), 1, events, 150.0)
	_run(sim, _in(), SECOND, events, 150.0)
	t.check(behemoth.part("head")["broken"], "a placa quebra")

	var hp_before := behemoth.hp
	_run(sim, _in(true), 1, [], 150.0)
	_run(sim, _in(), SECOND, [], 150.0)
	var taken := hp_before - behemoth.hp

	# 20 de base × 1,5 de Parte quebrada = 30, sem vazamento nenhum.
	t.check(taken > 20.0, "quebrada, a Vida sente o golpe cheio com o bônus de quebra")


func test_breaking_the_shell_slows_the_roll_forever(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD, Behemoths.BASTION)
	_park(sim, 150.0, PI * 0.5)  # de lado: a Carapaça
	var behemoth := _beh(sim)
	behemoth.part("shell")["hp"] = 1.0

	_run(sim, _in(true), 1, [], 150.0, PI * 0.5)
	_run(sim, _in(), SECOND, [], 150.0, PI * 0.5)

	t.check(behemoth.part("shell")["broken"], "a Carapaça quebra")
	t.check_approx(float(behemoth.cooldown_penalty.get("roll", 0.0)), 1.0,
		"e o Rolamento fica 1s mais lento para sempre")


func test_the_bastion_hunts_end_to_end(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD, Behemoths.BASTION)
	var behemoth := _beh(sim)
	t.check_eq(behemoth.type_id, Behemoths.BASTION, "o Bastião nasce quando escolhido")
	t.check(behemoth.part("head").get("armored", false), "com a Crista blindada")

	var start_distance := behemoth.pos.distance_to(Vector2.ZERO)
	var saw_windup := false
	for _i in SECOND * 12:
		sim.set_input(HUNTER, HunterInput.make(Vector2.ZERO, 0.0))
		sim.step(SimConfig.TICK_DELTA)
		if behemoth.state == BehemothState.State.WINDUP:
			saw_windup = true
			break

	t.check(behemoth.pos.distance_to(Vector2.ZERO) < start_distance or saw_windup, "ele persegue")
	t.check(saw_windup, "e chega a preparar um ataque")
