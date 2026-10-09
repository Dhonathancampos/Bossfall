extends RefCounted

## Movimentação do Caçador, testada pela interface pública da Sim.
##
## Nada aqui olha dentro da Sim: só set_input, step e snapshot. Se um dia a Sim
## for reescrita por completo, estes testes devem continuar valendo.

const HUNTER: int = 1
const SECOND: int = SimConfig.TICK_RATE

func _sim_with_hunter() -> Sim:
	var sim := Sim.new()
	sim.add_hunter(HUNTER, "Teste")
	return sim

func _advance(sim: Sim, input: HunterInput, ticks: int) -> void:
	sim.set_input(HUNTER, input)
	for _i in ticks:
		sim.step(SimConfig.TICK_DELTA)

func _hunter(sim: Sim, id: int = HUNTER) -> Dictionary:
	for hunter in sim.snapshot()["hunters"]:
		if hunter["id"] == id:
			return hunter
	return {}

func _pos(sim: Sim, id: int = HUNTER) -> Vector2:
	var hunter := _hunter(sim, id)
	return hunter.get("pos", Vector2.INF)


func test_hunter_starts_at_arena_centre(t: TestCase) -> void:
	var sim := _sim_with_hunter()
	t.check_vec_approx(_pos(sim), Vector2.ZERO, "Caçador começa no centro da Arena")


func test_training_sim_has_a_dummy_without_a_behemoth(t: TestCase) -> void:
	var sim := Sim.new()
	sim.add_hunter(HUNTER, "Teste")
	var snapshot := sim.snapshot()

	t.check(sim.behemoth() == null, "o treinamento não inicia um Behemoth")
	t.check_eq(snapshot["targets"].size(), 1, "o treinamento cria um boneco")
	t.check_eq(snapshot["targets"][0]["name"], "Boneco de treino", "o alvo é identificado")


func test_hunter_walks_at_walk_speed(t: TestCase) -> void:
	var sim := _sim_with_hunter()
	_advance(sim, HunterInput.make(Vector2.RIGHT, 0.0), SECOND)
	t.check_vec_approx(
		_pos(sim),
		Vector2(SimConfig.HUNTER_WALK_SPEED, 0.0),
		"um segundo andando para a direita percorre a velocidade de caminhada"
	)


func test_zero_input_keeps_hunter_still(t: TestCase) -> void:
	var sim := _sim_with_hunter()
	_advance(sim, HunterInput.make(Vector2.ZERO, 0.0), SECOND)
	t.check_vec_approx(_pos(sim), Vector2.ZERO, "sem Entrada de movimento o Caçador não sai do lugar")


func test_diagonal_is_not_faster_than_straight(t: TestCase) -> void:
	var straight := _sim_with_hunter()
	_advance(straight, HunterInput.make(Vector2.RIGHT, 0.0), SECOND)

	var diagonal := _sim_with_hunter()
	# Vetor de comprimento maior que 1: a Sim tem que limitar, senão andar na
	# diagonal viraria um jeito grátis de correr.
	_advance(diagonal, HunterInput.make(Vector2(1.0, 1.0), 0.0), SECOND)

	t.check_approx(
		_pos(diagonal).length(),
		_pos(straight).length(),
		"andar na diagonal não é mais rápido que andar reto"
	)


func test_hunter_stops_at_arena_edge(t: TestCase) -> void:
	var sim := _sim_with_hunter()
	_advance(sim, HunterInput.make(Vector2.RIGHT, 0.0), SECOND * 30)
	t.check_approx(
		_pos(sim).length(),
		SimConfig.hunter_limit(),
		"o Caçador para na borda da Arena em vez de sair dela"
	)


func test_facing_is_independent_of_movement(t: TestCase) -> void:
	var sim := _sim_with_hunter()
	# Anda para a esquerda apontando para a direita.
	_advance(sim, HunterInput.make(Vector2.LEFT, 0.0), SECOND)

	t.check_approx(_hunter(sim)["facing"], 0.0, "a mira segue a Entrada de mira")
	t.check(_pos(sim).x < 0.0, "andar para a esquerda move o Caçador para a esquerda")


func test_removed_hunter_disappears_from_snapshot(t: TestCase) -> void:
	var sim := _sim_with_hunter()
	sim.add_hunter(2, "Outro")
	sim.remove_hunter(HUNTER)
	sim.step(SimConfig.TICK_DELTA)

	var ids: Array = []
	for hunter in sim.snapshot()["hunters"]:
		ids.append(hunter["id"])
	t.check_eq(ids, [2], "um Caçador removido some do Instantâneo e os outros ficam")


func test_same_inputs_produce_same_snapshot(t: TestCase) -> void:
	var inputs: Array[HunterInput] = [
		HunterInput.make(Vector2.RIGHT, 0.0),
		HunterInput.make(Vector2(0.6, -0.8), 1.2),
		HunterInput.make(Vector2.ZERO, 2.5),
		HunterInput.make(Vector2.LEFT, -0.3),
	]

	var first := _sim_with_hunter()
	var second := _sim_with_hunter()
	for sim in [first, second]:
		for input in inputs:
			sim.set_input(HUNTER, input)
			for _i in 15:
				sim.step(SimConfig.TICK_DELTA)

	t.check_eq(
		str(first.snapshot()),
		str(second.snapshot()),
		"a mesma sequência de Entradas produz o mesmo Instantâneo"
	)
