extends RefCounted

## O que a Sim precisa oferecer para a rede funcionar: vários Caçadores
## independentes, Entrada que persiste entre Tiques, e um número de sequência
## que o Cliente use para saber até onde o Anfitrião já processou.

const A: int = 1
const B: int = 2
const SECOND: int = SimConfig.TICK_RATE

func _hunter(sim: Sim, id: int) -> Dictionary:
	for hunter in sim.snapshot()["hunters"]:
		if hunter["id"] == id:
			return hunter
	return {}

func _advance(sim: Sim, ticks: int) -> void:
	for _i in ticks:
		sim.step(SimConfig.TICK_DELTA)


func test_hunters_move_independently(t: TestCase) -> void:
	var sim := Sim.new()
	sim.add_hunter(A, "A")
	sim.add_hunter(B, "B")
	sim.set_input(A, HunterInput.make(Vector2.RIGHT, 0.0))
	sim.set_input(B, HunterInput.make(Vector2.UP, 0.0))
	_advance(sim, SECOND)

	t.check_vec_approx(_hunter(sim, A)["pos"], Vector2(SimConfig.HUNTER_WALK_SPEED, 0.0), "A anda para a direita")
	t.check_vec_approx(_hunter(sim, B)["pos"], Vector2(0.0, -SimConfig.HUNTER_WALK_SPEED), "B anda para cima")


func test_input_persists_between_ticks(t: TestCase) -> void:
	var sim := Sim.new()
	sim.add_hunter(A, "A")
	# Uma Entrada só, muitos Tiques: se o Cliente perder pacotes, o Caçador
	# continua andando em vez de congelar.
	sim.set_input(A, HunterInput.make(Vector2.RIGHT, 0.0))
	_advance(sim, SECOND)

	t.check_approx(_hunter(sim, A)["pos"].x, SimConfig.HUNTER_WALK_SPEED, "a Entrada vale até ser substituída")


func test_snapshot_reports_last_applied_input_seq(t: TestCase) -> void:
	var sim := Sim.new()
	sim.add_hunter(A, "A")
	t.check_eq(_hunter(sim, A)["seq"], 0, "sem Entrada aplicada, a sequência é zero")

	var input := HunterInput.make(Vector2.RIGHT, 0.0)
	input.seq = 42
	sim.set_input(A, input)
	t.check_eq(_hunter(sim, A)["seq"], 0, "a sequência só avança quando o Tique roda")

	sim.step(SimConfig.TICK_DELTA)
	t.check_eq(_hunter(sim, A)["seq"], 42, "o Instantâneo diz qual Entrada o Anfitrião já aplicou")


func test_prediction_matches_the_simulation(t: TestCase) -> void:
	# Esta é a propriedade que faz a predição do Cliente valer: repetir as
	# Entradas pendentes com HunterStep tem que dar exatamente o mesmo lugar
	# que a Sim do Anfitrião calculou.
	var inputs: Array[HunterInput] = [
		HunterInput.make(Vector2.RIGHT, 0.0, 1, true, false),
		HunterInput.make(Vector2(0.6, -0.8), 0.0, 2, false, true),
		HunterInput.make(Vector2(-1.0, 0.0), 0.0, 3, true, false),
		HunterInput.make(Vector2.ZERO, 0.0, 4, false, false),
	]

	var sim := Sim.new()
	sim.add_hunter(A, "A")
	var predicted := HunterState.new()

	for input in inputs:
		for _i in 20:
			sim.set_input(A, input)
			sim.step(SimConfig.TICK_DELTA)
			HunterStep.step(predicted, input, SimConfig.TICK_DELTA)

	t.check_vec_approx(predicted.pos, _hunter(sim, A)["pos"], "a predição do Cliente bate com a Sim do Anfitrião")
	t.check_approx(predicted.stamina, _hunter(sim, A)["stamina"], "o Fôlego previsto também bate")


func test_prediction_respects_the_arena_edge(t: TestCase) -> void:
	var input := HunterInput.make(Vector2.RIGHT, 0.0)
	var predicted := HunterState.new()
	for _i in SECOND * 30:
		HunterStep.step(predicted, input, SimConfig.TICK_DELTA)

	t.check_approx(predicted.pos.length(), SimConfig.hunter_limit(), "a predição também para na borda")


func test_removing_one_hunter_leaves_the_other_running(t: TestCase) -> void:
	var sim := Sim.new()
	sim.add_hunter(A, "A")
	sim.add_hunter(B, "B")
	sim.set_input(B, HunterInput.make(Vector2.RIGHT, 0.0))
	_advance(sim, 10)

	sim.remove_hunter(A)
	_advance(sim, SECOND - 10)

	t.check_approx(_hunter(sim, B)["pos"].x, SimConfig.HUNTER_WALK_SPEED, "a saída de um Caçador não atrapalha os outros")
