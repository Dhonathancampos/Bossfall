extends RefCounted

## Ticket 12 — Lança de Guerra: Perfuração que FERE Partes e Conversão
## Aetérica em quatro níveis.
##
## O Ferimento segue o MODELO FIEL (rework de abr/2021): a Parte Ferida não dá
## bônus de dano a ninguém; quem EXPLORA a ferida leva um buff pessoal. A
## decisão (e o híbrido descartado) está registrada no MEMORY.md.

const HUNTER: int = 1
const SECOND: int = SimConfig.TICK_RATE
const CLOSE: float = 130.0


func _sim(weapon: String = Weapons.PIKE, distance: float = CLOSE) -> Sim:
	var sim := Sim.new(Behemoths.GNASHER)
	sim.add_hunter(HUNTER, "Teste", weapon)
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


func _run(sim: Sim, input: HunterInput, ticks: int, events: Array = [], distance: float = CLOSE) -> void:
	for _i in ticks:
		_park(sim, distance)
		sim.set_input(HUNTER, input)
		sim.step(SimConfig.TICK_DELTA)
		events.append_array(sim.take_events())


func _in(
	light: bool = false, heavy: bool = false,
	light_held: bool = false, special: bool = false
) -> HunterInput:
	return HunterInput.make(
		Vector2.ZERO, 0.0, 0, false, false, light, heavy, special, false, false, light_held
	)


## Martela o leve por N segundos, com o monstro preso no lugar.
func _spam_light(sim: Sim, seconds: float, events: Array = []) -> void:
	_run(sim, _in(true), int(seconds * SECOND), events)


func _head(sim: Sim) -> Dictionary:
	return sim.behemoth().part("head")


## Ferimento ---------------------------------------------------------------

func test_pierce_builds_wound_on_the_part(t: TestCase) -> void:
	var sim := _sim()
	var hp_before := sim.behemoth().hp
	_spam_light(sim, 2.0)
	t.check(float(_head(sim)["wound"]) > 0.0, "estocadas acumulam Ferimento na Parte")
	t.check(sim.behemoth().hp < hp_before, "e o dano à Vida acontece normalmente")


func test_only_pierce_wounds(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD)
	_spam_light(sim, 2.0)
	t.check(float(_head(sim)["hp"]) < float(_head(sim)["max_hp"]), "a Espada machuca a Parte")
	t.check_approx(float(_head(sim)["wound"]), 0.0, "mas não acumula Ferimento: só Perfuração fere")


func test_the_threshold_wounds_the_part(t: TestCase) -> void:
	var sim := _sim()
	_head(sim)["wound"] = SimConfig.WOUND_THRESHOLD - 10.0
	var events: Array = []
	_spam_light(sim, 1.5, events)

	t.check(bool(_head(sim)["wounded"]), "estourar o limiar abre a Ferida")
	t.check_approx(float(_head(sim)["wound"]), 0.0, "e zera o acúmulo")
	t.check(float(_head(sim)["wound_time"]) > 0.0, "com relógio próprio")
	var announced := false
	for event in events:
		if event.get("type", "") == "part_wound" and String(event.get("part_id", "")) == "head":
			announced = true
	t.check(announced, "a Ferida é anunciada com o id da Parte")


func test_a_wounded_part_gives_nobody_a_damage_bonus(t: TestCase) -> void:
	# A DECISÃO do ticket: modelo fiel. Ferida não é um multiplicador de dano.
	var healthy := _sim(Weapons.SWORD)
	var healthy_before := healthy.behemoth().hp
	var healthy_part := float(healthy.behemoth().part("head")["hp"])
	_run(healthy, _in(true), 1)
	_run(healthy, _in(), SECOND)
	var healthy_body := healthy_before - healthy.behemoth().hp
	var healthy_taken := healthy_part - float(healthy.behemoth().part("head")["hp"])

	var wounded := _sim(Weapons.SWORD)
	wounded.behemoth().part("head")["wounded"] = true
	wounded.behemoth().part("head")["wound_time"] = SimConfig.WOUND_DURATION
	var wounded_before := wounded.behemoth().hp
	var wounded_part := float(wounded.behemoth().part("head")["hp"])
	_run(wounded, _in(true), 1)
	_run(wounded, _in(), SECOND)
	var wounded_body := wounded_before - wounded.behemoth().hp
	var wounded_taken := wounded_part - float(wounded.behemoth().part("head")["hp"])

	t.check(healthy_body > 0.0 and wounded_body > 0.0, "os dois golpes conectaram")
	t.check_approx(wounded_body, healthy_body, "a Ferida NÃO multiplica o dano à Vida", 0.01)
	t.check_approx(wounded_taken, healthy_taken, "nem o dano de Parte", 0.01)


func test_exploiting_the_wound_grants_a_personal_buff(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD)
	var head := _head(sim)
	head["wounded"] = true
	head["wound_time"] = SimConfig.WOUND_DURATION
	# Quase na cota: o próximo golpe fecha a colheita.
	head["wound_claim"] = {HUNTER: SimConfig.WOUND_HARVEST_TARGET - 5.0}

	var events: Array = []
	_run(sim, _in(true), 1, events)
	_run(sim, _in(), SECOND, events)

	t.check(float(_hunter(sim)["wound_buff_time"]) > 0.0, "explorar a Ferida dá buff PESSOAL")
	var harvested := false
	for event in events:
		if event.get("type", "") == "wound_harvest":
			harvested = true
	t.check(harvested, "e o evento anuncia quem colheu")

	var buffed := HunterState.new()
	buffed.wound_buff_time = 1.0
	t.check(
		HunterStep.buff_multiplier(buffed) > HunterStep.buff_multiplier(HunterState.new()),
		"o buff multiplica o dano de quem colheu"
	)


func test_the_wound_expires(t: TestCase) -> void:
	var sim := _sim()
	var head := _head(sim)
	head["wounded"] = true
	head["wound_time"] = 0.5
	_run(sim, _in(), SECOND)
	t.check(not bool(_head(sim)["wounded"]), "a Ferida fecha no tempo dela")


func test_partial_wound_decays(t: TestCase) -> void:
	var sim := _sim()
	_head(sim)["wound"] = 100.0
	_run(sim, _in(), SECOND * 2)
	t.check_approx(
		float(_head(sim)["wound"]), 100.0 - SimConfig.WOUND_DECAY_PER_SECOND * 2.0,
		"acúmulo parcial decai sozinho", 1.0
	)


func test_the_wound_survives_a_part_break(t: TestCase) -> void:
	var sim := _sim()
	var head := _head(sim)
	head["wounded"] = true
	head["wound_time"] = SimConfig.WOUND_DURATION
	head["hp"] = 1.0
	_run(sim, _in(true), 1)
	_run(sim, _in(), SECOND)
	t.check(bool(_head(sim)["broken"]), "a Parte quebra")
	t.check(bool(_head(sim)["wounded"]), "e a Ferida continua aberta: quebrar não a fecha")


func test_the_snapshot_carries_the_wound_fields(t: TestCase) -> void:
	var sim := _sim()
	var parts: Array = (sim.snapshot()["behemoth"] as Dictionary)["parts"]
	var head: Dictionary = parts[0]
	t.check(head.has("wound") and head.has("wounded") and head.has("wound_time"),
		"as Partes replicam o Ferimento de graça")


## Conversão Aetérica ------------------------------------------------------

func test_conversion_needs_ten_percent(t: TestCase) -> void:
	var sim := _sim()
	_run(sim, _in(false, false, false, true), 1)
	t.check_eq(int(_hunter(sim)["pike_ammo"]), 0, "com o medidor vazio, nada acontece")
	t.check_approx(float(_hunter(sim)["aether"]), 0.0, "e o Éter continua onde estava")


func test_conversion_has_four_levels(t: TestCase) -> void:
	# Limiares da referência: 10 / 33 / 66 / 90% do medidor.
	for pair in [[15.0, 1], [40.0, 2], [70.0, 3], [95.0, 4]]:
		var sim := _sim(Weapons.PIKE, 5000.0)
		sim.set_aether(HUNTER, float(pair[0]))
		_run(sim, _in(false, false, false, true), 1, [], 5000.0)
		t.check_eq(
			int(_hunter(sim)["pike_ammo"]), int(pair[1]),
			"Éter %s converte para o nível %s" % [pair[0], pair[1]]
		)
		t.check_approx(float(_hunter(sim)["aether"]), 0.0, "a conversão consome TUDO")


func test_the_missile_scales_with_the_ammo_level(t: TestCase) -> void:
	var weak := _sim(Weapons.PIKE, 600.0)
	weak.set_aether(HUNTER, 15.0)
	_run(weak, _in(false, false, false, true), 1, [], 600.0)
	var weak_before := weak.behemoth().hp
	_run(weak, _in(false, false, false, true), 1, [], 600.0)
	_run(weak, _in(), SECOND, [], 600.0)
	var weak_taken := weak_before - weak.behemoth().hp

	var strong := _sim(Weapons.PIKE, 600.0)
	strong.set_aether(HUNTER, 95.0)
	_run(strong, _in(false, false, false, true), 1, [], 600.0)
	var strong_before := strong.behemoth().hp
	_run(strong, _in(false, false, false, true), 1, [], 600.0)
	_run(strong, _in(), SECOND, [], 600.0)
	var strong_taken := strong_before - strong.behemoth().hp

	t.check(weak_taken > 0.0, "o míssil de nível 1 machuca")
	t.check(strong_taken > weak_taken * 2.0, "e o de nível 4 bate mais que o dobro")


func test_the_second_special_fires_the_missile(t: TestCase) -> void:
	var sim := _sim(Weapons.PIKE, 600.0)
	sim.fill_aether(HUNTER)
	_run(sim, _in(false, false, false, true), 1, [], 600.0)
	t.check_eq(int(_hunter(sim)["pike_ammo"]), 4, "medidor cheio converte no nível máximo")

	var hp_before := sim.behemoth().hp
	var events: Array = []
	_run(sim, _in(false, false, false, true), 1, events, 600.0)
	var projectiles: Array = sim.snapshot().get("projectiles", [])
	t.check(projectiles.size() >= 1, "o míssil existe no Instantâneo")
	if projectiles.size() >= 1:
		t.check_eq(String(projectiles[0]["kind"]), "pike_shot", "identificado como míssil da Lança")
	t.check_eq(int(_hunter(sim)["pike_ammo"]), 0, "e a munição é gasta")

	_run(sim, _in(), SECOND, events, 600.0)
	t.check(sim.behemoth().hp < hp_before, "o míssil machuca à distância")


func test_pike_state_survives_the_snapshot(t: TestCase) -> void:
	var sim := _sim()
	sim.fill_aether(HUNTER)
	_run(sim, _in(false, false, false, true), 1)
	var copy := HunterState.new()
	copy.apply_dict(_hunter(sim))
	t.check_eq(copy.pike_ammo, int(_hunter(sim)["pike_ammo"]), "pike_ammo atravessa o Instantâneo")
