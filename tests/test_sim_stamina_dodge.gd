extends RefCounted

## Fôlego, corrida e Esquiva, pela interface pública da Sim.

const HUNTER: int = 1
const SECOND: int = SimConfig.TICK_RATE


## REESCRITO no ticket 14.
##
## Antes o teste cobrava "o combo leve passa por TODOS os Golpes da lista
## leve". Com o grafo, a lista leve também guarda nós que só existem em outros
## contextos (corrida, pós-esquiva) e nós de desvio — martelar o botão leve
## nunca deveria alcançá-los. A cobrança fica MAIS específica, não mais frouxa:
## a cadeia que o grafo DECLARA saindo de `entry.free` por `light` tem que ser
## percorrida inteira, na ordem, e de graça.
##
## Repetidoras aparecem com cadeia vazia de propósito: o leve delas é um tiro,
## não um Golpe (ver test_sim_repeaters.gd).
func test_light_combos_are_free_even_with_zero_stamina(t: TestCase) -> void:
	for weapon in Weapons.ids():
		var hunter := HunterState.new()
		hunter.weapon_id = weapon
		hunter.stamina = 0.0
		# Bloqueia apenas a regeneração para provar que não depende dela.
		hunter.regen_delay = 100.0
		var seen: Array[String] = []
		var input := HunterInput.new()
		input.light = true
		for tick in SECOND * 5:
			HunterStep.step(hunter, input, SimConfig.TICK_DELTA)
			var node := hunter.current_node()
			if hunter.state == HunterState.State.ATTACK and not node.is_empty() and node not in seen:
				seen.append(node)
			t.check_approx(hunter.stamina, 0.0, weapon + " não exige vigor para leves")
		t.check_eq(seen, _light_chain(weapon), weapon + " percorre a cadeia leve declarada sem vigor")


## A cadeia leve declarada pelo grafo: entra por `entry.free` com `light` e
## segue as arestas `light` incondicionais até repetir um nó.
func _light_chain(weapon: String) -> Array[String]:
	var graph := Weapons.combo_graph(weapon)
	var chain: Array[String] = []
	var current := _light_edge(graph["entry"].get("free", []))
	while not current.is_empty() and not current.begins_with("@") and current not in chain:
		chain.append(current)
		current = _light_edge(graph["nodes"].get(current, {}).get("next", []))
	return chain


func _light_edge(candidates: Array) -> String:
	for candidate in candidates:
		var edge: Dictionary = candidate
		if String(edge.get("input", "")) == "light" and String(edge.get("if", "")).is_empty():
			return String(edge.get("to", ""))
	return ""


## REESCRITO no ticket 14: o Machado sai da varredura porque o leve dele é
## CARREGÁVEL — segurar o Preparo drena vigor de propósito (exceção declarada
## no MEMORY.md, coberta por test_sim_axe.gd). Para as outras cinco armas a
## regra continua idêntica: martelar o leve regenera igual ao repouso.
func test_light_spam_preserves_regeneration_and_its_delay(t: TestCase) -> void:
	for weapon in Weapons.ids():
		if weapon == Weapons.AXE:
			continue
		var attacking := HunterState.new()
		attacking.weapon_id = weapon
		var resting := HunterState.new()
		for hunter in [attacking, resting]:
			hunter.stamina = 10.0
			hunter.regen_delay = SimConfig.STAMINA_REGEN_DELAY
		var light := HunterInput.new()
		light.light = true
		for tick in SECOND * 4:
			HunterStep.step(attacking, light, SimConfig.TICK_DELTA)
			HunterStep.step(resting, HunterInput.new(), SimConfig.TICK_DELTA)
			t.check_approx(attacking.stamina, resting.stamina, weapon + " regenera como repouso")
			t.check_approx(attacking.regen_delay, resting.regen_delay, weapon + " não reinicia nem pula espera")
		t.check(attacking.stamina > 10.0, "regeneração ocorre durante combo")


func test_sword_heavy_still_spends_and_delays_regeneration(t: TestCase) -> void:
	var hunter := HunterState.new()
	var input := HunterInput.new()
	input.heavy = true
	HunterStep.step(hunter, input, SimConfig.TICK_DELTA)
	t.check_eq(hunter.state, HunterState.State.ATTACK, "pesado começa")
	t.check_approx(hunter.stamina, SimConfig.STAMINA_MAX - float(hunter.current_move()["stamina"]), "pesado mantém custo")
	t.check(hunter.regen_delay > 0.0, "gasto real adia regeneração")

func _sim() -> Sim:
	var sim := Sim.new()
	sim.add_hunter(HUNTER, "Teste")
	return sim

func _hunter(sim: Sim) -> Dictionary:
	for hunter in sim.snapshot()["hunters"]:
		if hunter["id"] == HUNTER:
			return hunter
	return {}

## Repete a mesma Entrada por N Tiques. Como a fila é consumida uma por Tique,
## enfileirar uma só e andar vários Tiques também funciona — mas repetir é o
## que um Cliente de verdade faz.
func _hold(sim: Sim, input: HunterInput, ticks: int) -> void:
	for _i in ticks:
		sim.set_input(HUNTER, input)
		sim.step(SimConfig.TICK_DELTA)

func _walk(sprint: bool = false) -> HunterInput:
	return HunterInput.make(Vector2.RIGHT, 0.0, 0, sprint, false)

func _dodge_input(direction: Vector2 = Vector2.RIGHT) -> HunterInput:
	return HunterInput.make(direction, 0.0, 0, false, true)


## Corrida -----------------------------------------------------------------

func test_sprinting_is_faster_than_walking(t: TestCase) -> void:
	var walking := _sim()
	_hold(walking, _walk(false), 30)

	var sprinting := _sim()
	_hold(sprinting, _walk(true), 30)

	t.check(
		_hunter(sprinting)["pos"].x > _hunter(walking)["pos"].x + 10.0,
		"correr cobre mais distância que andar"
	)


func test_sprinting_drains_stamina(t: TestCase) -> void:
	var sim := _sim()
	_hold(sim, _walk(true), SECOND)
	t.check_approx(
		_hunter(sim)["stamina"],
		SimConfig.STAMINA_MAX - SimConfig.SPRINT_DRAIN_PER_SECOND,
		"um segundo correndo drena um segundo de Fôlego",
		1.0
	)


func test_walking_does_not_drain_stamina(t: TestCase) -> void:
	var sim := _sim()
	_hold(sim, _walk(false), SECOND)
	t.check_approx(_hunter(sim)["stamina"], SimConfig.STAMINA_MAX, "andar é de graça")


func test_sprinting_stops_when_stamina_falls_below_the_minimum(t: TestCase) -> void:
	var sim := _sim()
	_hold(sim, _walk(true), SECOND * 6)
	t.check(
		_hunter(sim)["stamina"] < SimConfig.SPRINT_MIN_STAMINA,
		"correr sem parar derruba o Fôlego abaixo do mínimo"
	)

	# Mede andando para longe da borda: para a direita o Caçador já está
	# colado nela e não mediria velocidade nenhuma. A janela é curta de
	# propósito, para ficar dentro da espera da regeneração.
	var ticks := 24
	var before: Vector2 = _hunter(sim)["pos"]
	_hold(sim, HunterInput.make(Vector2.LEFT, 0.0, 0, true, false), ticks)
	var covered: float = before.x - _hunter(sim)["pos"].x

	t.check_approx(
		covered,
		SimConfig.HUNTER_WALK_SPEED * float(ticks) * SimConfig.TICK_DELTA,
		"abaixo do mínimo, segurar correr anda no passo normal",
		3.0
	)


func test_sprinting_resumes_once_stamina_is_back_above_the_minimum(t: TestCase) -> void:
	var sim := _sim()
	_hold(sim, _walk(true), SECOND * 6)

	# Recupera também a reserva necessária para sustentar os 24 tiques abaixo.
	# Fica parado para não atingir a borda oposta durante a espera maior.
	_hold(sim, HunterInput.new(), int(ceilf((SimConfig.STAMINA_REGEN_DELAY +
		(SimConfig.SPRINT_MIN_STAMINA + SimConfig.SPRINT_DRAIN_PER_SECOND * 0.4) /
		SimConfig.STAMINA_REGEN_PER_SECOND) * SECOND)) + 2)
	t.check(
		_hunter(sim)["stamina"] > SimConfig.SPRINT_MIN_STAMINA,
		"descansar devolve Fôlego acima do mínimo"
	)

	var ticks := 24
	var before: Vector2 = _hunter(sim)["pos"]
	_hold(sim, HunterInput.make(Vector2.LEFT, 0.0, 0, true, false), ticks)
	var covered: float = before.x - _hunter(sim)["pos"].x

	t.check_approx(
		covered,
		SimConfig.HUNTER_SPRINT_SPEED * float(ticks) * SimConfig.TICK_DELTA,
		"o mínimo é um piso, não uma trava: a corrida volta",
		3.0
	)


func test_sprinting_in_place_does_not_drain_stamina(t: TestCase) -> void:
	var sim := _sim()
	_hold(sim, HunterInput.make(Vector2.ZERO, 0.0, 0, true, false), SECOND)
	t.check_approx(_hunter(sim)["stamina"], SimConfig.STAMINA_MAX, "correr parado não gasta nada")


## Fôlego ------------------------------------------------------------------

func test_stamina_does_not_regenerate_during_the_delay(t: TestCase) -> void:
	var sim := _sim()
	_hold(sim, _walk(true), 30)
	var after_sprint: float = _hunter(sim)["stamina"]

	# Menos que a espera: ainda não pode ter voltado nada.
	var pause := int(SimConfig.STAMINA_REGEN_DELAY * SimConfig.TICK_RATE) - 4
	_hold(sim, _walk(false), pause)

	t.check_approx(_hunter(sim)["stamina"], after_sprint, "o Fôlego espera antes de voltar", 0.5)


func test_stamina_regenerates_after_the_delay(t: TestCase) -> void:
	var sim := _sim()
	_hold(sim, _walk(true), 60)
	var after_sprint: float = _hunter(sim)["stamina"]

	_hold(sim, _walk(false), int(ceilf(SimConfig.STAMINA_REGEN_DELAY * SECOND)) + SECOND)

	t.check_approx(_hunter(sim)["stamina"], after_sprint + 9.0,
		"após a espera, um segundo recupera nove pontos", 0.3)


func test_heavy_to_light_respects_one_and_half_second_delay(t: TestCase) -> void:
	var hunter := HunterState.new()
	var heavy := HunterInput.new()
	heavy.heavy = true
	HunterStep.step(hunter, heavy, SimConfig.TICK_DELTA)
	var after_heavy := hunter.stamina
	var light := HunterInput.new()
	light.light = true
	# Leve fica no buffer e encadeia ao terminar o pesado. Mesmo depois de
	# terminar o pesado, a espera do gasto inicial ainda não pode ter acabado.
	for tick in 88:
		HunterStep.step(hunter, light, SimConfig.TICK_DELTA)
		t.check_approx(hunter.stamina, after_heavy, "não regenera antes de 1,5 s", 0.001)
	t.check_eq(hunter.attack_kind, int(Weapons.Kind.LIGHT), "já encadeou leve")
	for tick in 62:
		HunterStep.step(hunter, light, SimConfig.TICK_DELTA)
	t.check_approx(hunter.stamina, after_heavy + 9.0, "regenera lentamente durante leves após espera", 0.3)


func test_new_heavy_restarts_the_regeneration_delay(t: TestCase) -> void:
	var hunter := HunterState.new()
	var heavy := HunterInput.new()
	heavy.heavy = true
	HunterStep.step(hunter, heavy, SimConfig.TICK_DELTA)
	for tick in SECOND:
		HunterStep.step(hunter, HunterInput.new(), SimConfig.TICK_DELTA)
	HunterStep.step(hunter, heavy, SimConfig.TICK_DELTA)
	var after_second := hunter.stamina
	for tick in 70:
		HunterStep.step(hunter, HunterInput.new(), SimConfig.TICK_DELTA)
	t.check_approx(hunter.stamina, after_second, "novo gasto reinicia espera, mesmo após acabar o golpe", 0.001)


func test_stamina_never_goes_above_the_maximum(t: TestCase) -> void:
	var sim := _sim()
	_hold(sim, _walk(false), SECOND * 5)
	t.check_approx(_hunter(sim)["stamina"], SimConfig.STAMINA_MAX, "o Fôlego não passa do teto")


## Esquiva -----------------------------------------------------------------

func test_dodge_costs_stamina(t: TestCase) -> void:
	var sim := _sim()
	sim.set_input(HUNTER, _dodge_input())
	sim.step(SimConfig.TICK_DELTA)
	t.check_approx(
		_hunter(sim)["stamina"],
		SimConfig.STAMINA_MAX - SimConfig.DODGE_COST,
		"rolar cobra o custo de uma vez",
		0.6
	)


func test_dodge_covers_more_ground_than_walking(t: TestCase) -> void:
	var sim := _sim()
	sim.set_input(HUNTER, _dodge_input())
	for _i in int(SimConfig.DODGE_DURATION * SimConfig.TICK_RATE) + 1:
		sim.step(SimConfig.TICK_DELTA)

	var expected := SimConfig.DODGE_SPEED * SimConfig.DODGE_DURATION
	t.check_approx(_hunter(sim)["pos"].x, expected, "o rolamento cobre a distância do impulso", 20.0)


func test_dodge_grants_invulnerability_early_and_not_late(t: TestCase) -> void:
	var sim := _sim()
	sim.set_input(HUNTER, _dodge_input())
	sim.step(SimConfig.TICK_DELTA)
	t.check(_hunter(sim)["invulnerable"], "o rolamento começa Invulnerável")

	# Passa do fim da janela, mas ainda dentro do impulso.
	var ticks_to_end := int(SimConfig.DODGE_IFRAMES_END * SimConfig.TICK_RATE) + 2
	for _i in ticks_to_end:
		sim.step(SimConfig.TICK_DELTA)
	t.check(not _hunter(sim)["invulnerable"], "a Invulnerabilidade acaba antes do rolamento")


func test_dodge_ignores_movement_input_until_it_finishes(t: TestCase) -> void:
	var sim := _sim()
	sim.set_input(HUNTER, _dodge_input(Vector2.RIGHT))
	sim.step(SimConfig.TICK_DELTA)

	# Tenta virar para a esquerda no meio do rolamento.
	_hold(sim, HunterInput.make(Vector2.LEFT, 0.0), 6)

	t.check(_hunter(sim)["pos"].x > 0.0, "mudar de direção no meio do rolamento não desvia o rolamento")


func test_dodge_does_not_happen_without_enough_stamina(t: TestCase) -> void:
	var sim := _sim()
	_hold(sim, _walk(true), SECOND * 6)  # zera o Fôlego

	var before: Vector2 = _hunter(sim)["pos"]
	sim.set_input(HUNTER, _dodge_input())
	sim.step(SimConfig.TICK_DELTA)
	var covered: float = _hunter(sim)["pos"].x - before.x

	t.check(
		covered < SimConfig.DODGE_SPEED * SimConfig.TICK_DELTA * 0.5,
		"sem Fôlego não há rolamento"
	)


func test_dodge_has_recovery_before_another_dodge(t: TestCase) -> void:
	var sim := _sim()
	sim.set_input(HUNTER, _dodge_input())
	sim.step(SimConfig.TICK_DELTA)

	# No meio da recuperação, pede outro rolamento.
	var mid := int((SimConfig.DODGE_DURATION + SimConfig.DODGE_RECOVERY * 0.5) * SimConfig.TICK_RATE)
	for _i in mid:
		sim.step(SimConfig.TICK_DELTA)
	var stamina_before: float = _hunter(sim)["stamina"]

	sim.set_input(HUNTER, _dodge_input())
	sim.step(SimConfig.TICK_DELTA)

	t.check(
		_hunter(sim)["stamina"] >= stamina_before,
		"pedir rolamento durante a recuperação não cobra nem rola de novo"
	)


func test_a_single_dodge_request_does_not_repeat(t: TestCase) -> void:
	var sim := _sim()
	sim.set_input(HUNTER, _dodge_input())
	# Nenhuma Entrada nova: a fila seca e a Sim repete a última, sem a Esquiva.
	for _i in SECOND * 2:
		sim.step(SimConfig.TICK_DELTA)

	t.check_approx(
		_hunter(sim)["stamina"],
		SimConfig.STAMINA_MAX - SimConfig.DODGE_COST +
			maxf(0.0, 2.0 - SimConfig.STAMINA_REGEN_DELAY) * SimConfig.STAMINA_REGEN_PER_SECOND,
		"uma apertada cobra uma única esquiva e regenera só depois da espera",
		0.3
	)
