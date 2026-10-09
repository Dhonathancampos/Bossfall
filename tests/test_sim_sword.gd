extends RefCounted

## A Espada: fases do Golpe, Comprometimento, Combo e acerto.

const HUNTER: int = 1

## Distância do centro do boneco em que os Golpes da Espada alcançam.
const REACH_DISTANCE: float = 100.0

## Anda até ficar ao alcance do boneco de treino. Andar de verdade, em vez de
## colocar o Caçador lá à força, mantém o teste preso só à interface pública.
func _sim_next_to_target() -> Sim:
	var sim := Sim.new()
	sim.add_hunter(HUNTER, "Teste")

	var toward := HunterInput.make(SimConfig.DUMMY_POS.normalized(), _aim_at_target())
	for _i in 300:
		if _hunter(sim)["pos"].distance_to(SimConfig.DUMMY_POS) <= REACH_DISTANCE:
			break
		sim.set_input(HUNTER, toward)
		sim.step(SimConfig.TICK_DELTA)
	return sim

func _hunter(sim: Sim) -> Dictionary:
	for hunter in sim.snapshot()["hunters"]:
		if hunter["id"] == HUNTER:
			return hunter
	return {}

func _target(sim: Sim) -> Dictionary:
	return sim.snapshot()["targets"][0]

func _state(sim: Sim) -> int:
	return int(_hunter(sim)["state"])

## Mira no boneco de treino, que fica ao norte do centro.
func _aim_at_target() -> float:
	return (SimConfig.DUMMY_POS - Vector2.ZERO).angle()

func _press(light: bool = true, heavy: bool = false) -> HunterInput:
	return HunterInput.make(Vector2.ZERO, _aim_at_target(), 0, false, false, light, heavy)

func _idle() -> HunterInput:
	return HunterInput.make(Vector2.ZERO, _aim_at_target())

func _hold(sim: Sim, input: HunterInput, ticks: int) -> void:
	for _i in ticks:
		sim.set_input(HUNTER, input)
		sim.step(SimConfig.TICK_DELTA)

func _ticks(seconds: float) -> int:
	return int(ceilf(seconds * SimConfig.TICK_RATE))

func _first_light() -> Dictionary:
	return Weapons.move(Weapons.SWORD, Weapons.Kind.LIGHT, 0)


## Fases do Golpe ----------------------------------------------------------

func test_light_attack_enters_the_attack_state(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	_hold(sim, _press(), 1)
	t.check_eq(_state(sim), int(HunterState.State.ATTACK), "o botão esquerdo começa um Golpe")


func test_attack_returns_to_free_when_it_finishes(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	_hold(sim, _press(), 1)
	_hold(sim, _idle(), _ticks(Weapons.duration(_first_light())) + 2)
	t.check_eq(_state(sim), int(HunterState.State.FREE), "o Golpe acaba sozinho e devolve o controle")


func test_light_attack_does_not_cost_stamina(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	_hold(sim, _press(), 1)
	t.check_approx(
		_hunter(sim)["stamina"],
		SimConfig.STAMINA_MAX,
		"o Golpe leve não cobra Fôlego",
		0.6
	)


## Comprometimento ---------------------------------------------------------

func test_movement_input_does_not_cancel_an_attack(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	_hold(sim, _press(), 1)
	# Tenta sair andando no meio do Golpe.
	_hold(sim, HunterInput.make(Vector2.LEFT, _aim_at_target()), 3)
	t.check_eq(_state(sim), int(HunterState.State.ATTACK), "andar não cancela o Golpe")


func test_dodge_does_not_cancel_an_attack(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	_hold(sim, _press(), 1)
	var stamina_before: float = _hunter(sim)["stamina"]
	_hold(sim, HunterInput.make(Vector2.LEFT, _aim_at_target(), 0, false, true), 3)

	t.check_eq(_state(sim), int(HunterState.State.ATTACK), "rolar não cancela o Golpe")
	t.check(_hunter(sim)["stamina"] >= stamina_before - 0.1, "e nem cobra o Fôlego do rolamento")


func test_an_attack_does_not_move_the_hunter_forward(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	var before: Vector2 = _hunter(sim)["pos"]
	_hold(sim, _press(), 1)
	_hold(sim, _idle(), _ticks(float(_first_light()["windup"]) + float(_first_light()["active"])))

	var moved: float = (_hunter(sim)["pos"] - before).length()
	t.check_approx(moved, 0.0, "golpear não aproxima automaticamente do alvo")


func test_heavy_combo_cycles_and_expires(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	var seen: Array[int] = []
	for i in 4:
		_hold(sim, _press(false, true), 1)
		seen.append(int(_hunter(sim)["attack_index"]))
		_hold(sim, _idle(), _ticks(Weapons.duration(_hunter_move(sim))) + 1)
	t.check_eq(seen, [0, 1, 2, 0], "pesado percorre três golpes e reinicia")
	_hold(sim, _idle(), 90)
	_hold(sim, _press(false, true), 1)
	t.check_eq(_hunter(sim)["attack_index"], 0, "janela expirada reinicia pesado")


func test_buffered_heavy_chains_without_moving(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	var before: Vector2 = _hunter(sim)["pos"]
	_hold(sim, _press(false, true), 2)
	_hold(sim, _idle(), _ticks(Weapons.duration(Weapons.move(Weapons.SWORD, Weapons.Kind.HEAVY, 0))))
	t.check_eq(_hunter(sim)["attack_index"], 1, "pesado guardado encadeia segundo")
	t.check_eq(_hunter(sim)["pos"], before, "combo não desloca")


func test_all_ordinary_weapon_strikes_are_stationary(t: TestCase) -> void:
	for weapon in Weapons.ids():
		for kind in [Weapons.Kind.LIGHT, Weapons.Kind.HEAVY]:
			for index in Weapons.moves(weapon, kind).size():
				var hunter := HunterState.new()
				hunter.weapon_id = weapon
				hunter.attack_kind = kind
				hunter.attack_index = index
				hunter.state = HunterState.State.ATTACK
				if hunter.current_move().get("hook", false):
					continue
				for tick in _ticks(Weapons.duration(hunter.current_move())) + 2:
					HunterStep.step(hunter, HunterInput.new(), SimConfig.TICK_DELTA)
				t.check_eq(hunter.pos, Vector2.ZERO, "%s golpe %s/%s estacionário" % [weapon, kind, index])


## Combo -------------------------------------------------------------------

func test_pressing_again_during_the_attack_chains_the_combo(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	_hold(sim, _press(), 1)
	# Pede o próximo no meio do Golpe: o pedido fica guardado.
	_hold(sim, _press(), 1)
	_hold(sim, _idle(), _ticks(Weapons.duration(_first_light())) + 1)

	t.check_eq(_state(sim), int(HunterState.State.ATTACK), "o Combo emenda sem soltar o controle")
	t.check_eq(_hunter(sim)["attack_index"], 1, "e vai para o segundo Golpe da sequência")


func test_the_combo_walks_through_all_three_light_moves(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	var seen: Array[int] = []

	for _chain in 3:
		_hold(sim, _press(), 1)
		seen.append(int(_hunter(sim)["attack_index"]))
		# Espera o Golpe acabar, sem sair da Janela de Combo.
		_hold(sim, _idle(), _ticks(Weapons.duration(_hunter_move(sim))) + 1)

	t.check_eq(seen, [0, 1, 2], "a sequência leve passa pelos três Golpes em ordem")


func test_waiting_too_long_restarts_the_combo(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	_hold(sim, _press(), 1)
	_hold(sim, _idle(), _ticks(Weapons.duration(_first_light())) + 1)

	# Deixa a Janela de Combo expirar com folga.
	_hold(sim, _idle(), _ticks(float(_first_light()["combo_window"])) + 20)
	_hold(sim, _press(), 1)

	t.check_eq(_hunter(sim)["attack_index"], 0, "perder a Janela volta a sequência para o primeiro Golpe")


func test_a_heavy_attack_restarts_the_light_sequence(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	_hold(sim, _press(), 1)
	_hold(sim, _idle(), _ticks(Weapons.duration(_first_light())) + 1)

	# Pesado logo em seguida, ainda dentro da Janela.
	_hold(sim, _press(false, true), 1)
	t.check_eq(int(_hunter(sim)["attack_kind"]), int(Weapons.Kind.HEAVY), "o botão direito dá o Golpe pesado")

	_hold(sim, _idle(), _ticks(Weapons.duration(Weapons.move(Weapons.SWORD, Weapons.Kind.HEAVY, 0))) + 1)
	_hold(sim, _press(), 1)
	t.check_eq(_hunter(sim)["attack_index"], 0, "depois do pesado, a sequência leve recomeça")


## Acerto ------------------------------------------------------------------

func test_an_attack_damages_a_target_in_front(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	var before: float = _target(sim)["hp"]
	_hold(sim, _press(), 1)
	_hold(sim, _idle(), _ticks(Weapons.duration(_first_light())) + 1)

	t.check(_target(sim)["hp"] < before, "o Golpe tira Vida do alvo à frente")


func test_an_attack_misses_a_target_behind(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	var before: float = _target(sim)["hp"]

	# Mira na direção oposta ao boneco.
	var away := _aim_at_target() + PI
	_hold(sim, HunterInput.make(Vector2.ZERO, away, 0, false, false, true, false), 1)
	_hold(sim, HunterInput.make(Vector2.ZERO, away), _ticks(Weapons.duration(_first_light())) + 1)

	t.check_approx(_target(sim)["hp"], before, "golpear de costas não acerta nada")


func test_an_attack_hits_a_target_only_once(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	var before: float = _target(sim)["hp"]
	_hold(sim, _press(), 1)
	_hold(sim, _idle(), _ticks(Weapons.duration(_first_light())) + 1)

	var taken: float = before - _target(sim)["hp"]
	t.check_approx(taken, Combat.damage(_first_light()), "um Golpe tira o dano de um Golpe, não de vários", 0.01)


func test_hitting_fills_aether(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	t.check_approx(_hunter(sim)["aether"], 0.0, "o Éter começa vazio")

	_hold(sim, _press(), 1)
	_hold(sim, _idle(), _ticks(Weapons.duration(_first_light())) + 1)

	t.check_approx(
		_hunter(sim)["aether"],
		float(_first_light()["aether"]),
		"acertar enche o Éter",
		0.01
	)


func test_missing_does_not_fill_aether(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	var away := _aim_at_target() + PI
	_hold(sim, HunterInput.make(Vector2.ZERO, away, 0, false, false, true, false), 1)
	_hold(sim, HunterInput.make(Vector2.ZERO, away), _ticks(Weapons.duration(_first_light())) + 1)

	t.check_approx(_hunter(sim)["aether"], 0.0, "errar não enche o Éter")


func test_a_hit_produces_one_event(t: TestCase) -> void:
	var sim := _sim_next_to_target()
	_hold(sim, _press(), 1)
	_hold(sim, _idle(), _ticks(Weapons.duration(_first_light())) + 1)

	var events := sim.take_events()
	t.check_eq(events.size(), 1, "um acerto gera um evento para a Apresentação desenhar")
	if events.size() == 1:
		t.check_eq(events[0]["type"], "hit", "o evento é de acerto")
		t.check_eq(events[0]["hunter"], HUNTER, "e diz quem bateu")

	t.check_eq(sim.take_events().size(), 0, "os eventos são consumidos: ninguém os lê duas vezes")


## Auxiliares --------------------------------------------------------------

func _hunter_move(sim: Sim) -> Dictionary:
	# A arma não viaja no Instantâneo: é estática e vai pela lista de
	# Caçadores. Aqui só existe a Espada.
	var hunter := _hunter(sim)
	return Weapons.move(
		Weapons.SWORD,
		int(hunter["attack_kind"]) as Weapons.Kind,
		int(hunter["attack_index"])
	)
