extends RefCounted

## Ticket 14: o grafo de combo.
##
## Tudo pela interface pública da Sim: Entradas injetadas, nós lidos a partir
## do Instantâneo (`attack_kind` + `attack_index`, que continuam sendo a
## identidade replicada do Golpe).

const HUNTER: int = 1
const SECOND: int = SimConfig.TICK_RATE

## Colado no corpo (borda a ~22 cm) e longe o bastante para o Gancho.
const CLOSE: float = 130.0
const FAR: float = 500.0


func _sim(weapon: String, distance: float = CLOSE) -> Sim:
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


## Anda N Tiques com o monstro preso no lugar, acumulando eventos.
func _run(sim: Sim, input: HunterInput, ticks: int, events: Array = [], distance: float = CLOSE) -> void:
	for _i in ticks:
		_park(sim, distance)
		sim.set_input(HUNTER, input)
		sim.step(SimConfig.TICK_DELTA)
		events.append_array(sim.take_events())


func _in(
	light: bool = false, heavy: bool = false,
	light_held: bool = false, heavy_held: bool = false,
	special: bool = false, reload: bool = false,
	move: Vector2 = Vector2.ZERO, sprint: bool = false
) -> HunterInput:
	return HunterInput.make(
		move, 0.0, 0, sprint, false, light, heavy, special, heavy_held, reload, light_held
	)


func _weapon(sim: Sim) -> String:
	return String(sim.roster()[HUNTER]["weapon"])


## O NÓ do grafo em que o Golpe atual está. "" fora de um Golpe.
func _node(sim: Sim) -> String:
	var hunter := _hunter(sim)
	var state := int(hunter["state"])
	if state != int(HunterState.State.ATTACK) and state != int(HunterState.State.AXE_CHARGE):
		return ""
	return Weapons.node_name(
		_weapon(sim),
		int(hunter["attack_kind"]) as Weapons.Kind,
		int(hunter["attack_index"])
	)


func _state(sim: Sim) -> int:
	return int(_hunter(sim)["state"])


## Executa um roteiro de teclas, Golpe a Golpe: aperta, registra o nó, e
## espera o Golpe terminar (segurando o botão quando o roteiro pede).
##
## Tokens: "L" leve, "H" pesado, "Lh"/"Hh" segurados, "R" recarga.
func _walk(sim: Sim, tokens: Array, events: Array = [], distance: float = CLOSE) -> Array[String]:
	var seen: Array[String] = []
	for token in tokens:
		var press := _token(token, true)
		_run(sim, press, 1, events, distance)
		seen.append(_node(sim))
		var hold := _token(token, false)
		var guard := 0
		while guard < SECOND * 6 and _state(sim) != int(HunterState.State.FREE):
			guard += 1
			_run(sim, hold, 1, events, distance)
	return seen


func _token(token: String, pressing: bool) -> HunterInput:
	match token:
		"L":
			return _in(pressing, false, false, false)
		"Lh":
			return _in(pressing, false, true, false)
		"H":
			return _in(false, pressing, false, false)
		"Hh":
			return _in(false, pressing, false, true)
		"R":
			return _in(false, false, false, false, false, pressing)
	return _in()


func _hits_named(events: Array, move_name: String) -> Array:
	var found: Array = []
	for event in events:
		if event.get("type", "") == "hit" and event.get("move", "") == move_name:
			found.append(event)
	return found


## Enche o Brio da Espada pelo caminho do jogo: três cadeias leves fechadas.
func _fill_brio(sim: Sim) -> void:
	for _i in 3:
		_walk(sim, ["L", "L", "L"])
		_run(sim, _in(), 30)


## 1. Infra da máquina ------------------------------------------------------

func test_the_same_script_twice_produces_the_same_snapshots(t: TestCase) -> void:
	var first := _sim(Weapons.SWORD)
	var second := _sim(Weapons.SWORD)
	var script := ["L", "L", "H", "L"]
	_walk(first, script)
	_walk(second, script)
	t.check_eq(
		_hunter(first)["attack_index"], _hunter(second)["attack_index"],
		"o grafo é determinístico: mesmo roteiro, mesmo nó"
	)
	t.check_eq(
		_hunter(first)["combo_from"], _hunter(second)["combo_from"],
		"e a mesma posição no grafo"
	)
	t.check_eq(first.snapshot()["hunters"], second.snapshot()["hunters"], "Instantâneos idênticos")


func test_the_client_predicts_the_graph_without_a_world(t: TestCase) -> void:
	# A Sim do Anfitrião tem mundo; a predição do Cliente não. Para uma
	# sequência sem predicado de mundo, os dois têm que chegar ao mesmo nó.
	var sim := _sim(Weapons.SWORD)
	var predicted := HunterState.new()
	predicted.weapon_id = Weapons.SWORD

	var script := ["L", "L", "L"]
	for token in script:
		var press := _token(token, true)
		_run(sim, press, 1)
		HunterStep.step(predicted, press, SimConfig.TICK_DELTA, {})
		var guard := 0
		while guard < SECOND * 6 and _state(sim) != int(HunterState.State.FREE):
			guard += 1
			_run(sim, _in(), 1)
			HunterStep.step(predicted, _in(), SimConfig.TICK_DELTA, {})
	t.check_eq(
		predicted.current_node(), Weapons.node_name(Weapons.SWORD, Weapons.Kind.LIGHT, 2),
		"sem mundo, a predição percorre o mesmo caminho"
	)
	t.check_eq(predicted.combo_from, int(_hunter(sim)["combo_from"]), "e para na mesma posição")


func test_a_world_predicate_simply_does_not_resolve_without_a_world(t: TestCase) -> void:
	# Contrato atual do Gancho, agora valendo para todo predicado de mundo.
	var predicted := HunterState.new()
	predicted.weapon_id = Weapons.BLADES
	HunterStep.step(predicted, _in(false, true), SimConfig.TICK_DELTA, {})
	t.check_eq(predicted.state, HunterState.State.FREE, "sem mundo, perto/longe não decidem nada")
	t.check(predicted.state != HunterState.State.ATTACK, "nenhum Golpe começa")
	t.check(predicted.state != HunterState.State.HOOK_PULL, "e nenhum Gancho é antecipado")


func test_losing_the_window_falls_back_to_the_entry(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD)
	_walk(sim, ["L"])
	# Janela de l1 é 0,20 s: esperar bem mais derruba a posição no grafo.
	_run(sim, _in(), 40)
	t.check_eq(int(_hunter(sim)["combo_from"]), -1, "janela expirada esquece o nó")
	t.check_eq(_walk(sim, ["L"]), ["l1"] as Array[String], "e a próxima Entrada volta pelo `entry`")


func test_inside_the_window_the_edge_wins(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD)
	_walk(sim, ["L"])
	# Janela de l1 = 0,20 s; 6 Tiques = 0,10 s.
	_run(sim, _in(), 6)
	t.check_eq(_walk(sim, ["L"]), ["l2"] as Array[String], "dentro da janela, a aresta do nó decide")


func test_the_buffer_chains_on_the_first_free_tick(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD)
	# Aperta durante o Golpe: o pedido fica guardado e sai sem um Tique de
	# FREE no meio.
	_run(sim, _in(true), 1)
	_run(sim, _in(true), 1)
	var first := Weapons.move(Weapons.SWORD, Weapons.Kind.LIGHT, 0)
	_run(sim, _in(), int(ceilf(Weapons.duration(first) * SECOND)) + 1)
	t.check_eq(_state(sim), int(HunterState.State.ATTACK), "o Combo emenda sem soltar o controle")
	t.check_eq(_node(sim), "l2", "no nó certo")


func test_the_graph_state_survives_the_snapshot(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD)
	_fill_brio(sim)
	_walk(sim, ["L"])
	var copy := HunterState.new()
	copy.apply_dict(_hunter(sim))
	t.check_eq(copy.combo_from, int(_hunter(sim)["combo_from"]), "combo_from atravessa o Instantâneo")
	t.check_eq(copy.brio, int(_hunter(sim)["brio"]), "brio também")
	t.check_eq(copy.attack_index, int(_hunter(sim)["attack_index"]), "e o nó em andamento")


func test_an_empty_graph_is_valid(t: TestCase) -> void:
	var graph := Weapons.combo_graph(Weapons.REPEATERS)
	t.check((graph["nodes"] as Dictionary).is_empty(), "as Repetidoras não têm árvore — e isso é fidelidade")
	t.check(not (graph["entry"] as Dictionary).get("free", []).is_empty(), "mas têm entrada (o Rolinho)")


func test_a_weapon_without_a_declared_graph_compiles_a_linear_one(t: TestCase) -> void:
	# O adaptador da migração: sem `entry`, as listas light/heavy viram a
	# cadeia linear do sistema antigo. Nenhuma arma do jogo depende disso
	# hoje, mas é a rede de segurança para a próxima arma.
	for weapon in Weapons.ids():
		var graph := Weapons.combo_graph(weapon)
		t.check(graph.has("entry") and graph.has("nodes"), weapon + " tem grafo")
	t.check_eq(
		Weapons.node_name(Weapons.SWORD, Weapons.Kind.HEAVY, 0), "h1",
		"os ids dos Golpes antigos não mudaram de posição"
	)
	t.check_eq(
		Weapons.flat_id(Weapons.SWORD, Weapons.Kind.HEAVY, 0),
		Weapons.moves(Weapons.SWORD, Weapons.Kind.LIGHT).size(),
		"o achatamento é leves primeiro, pesados depois"
	)


## 2. Espada ---------------------------------------------------------------

func test_sword_light_chain_closes_with_brio(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD)
	var seen := _walk(sim, ["L", "L", "L"])
	t.check_eq(seen, ["l1", "l2", "l3"] as Array[String], "L,L,L percorre a cadeia leve")
	t.check_eq(int(_hunter(sim)["brio"]), 1, "fechar a cadeia dá 1 de Brio")


func test_sword_heavy_chain_gives_two_brio(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD)
	var seen := _walk(sim, ["H", "H", "H"])
	t.check_eq(seen, ["h1", "h2", "h3"] as Array[String], "H,H,H percorre a cadeia pesada")
	t.check_eq(int(_hunter(sim)["brio"]), 2, "o finalizador pesado dá 2 de Brio")


func test_sword_divert_without_brio_does_not_reset(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD)
	var seen := _walk(sim, ["L", "L", "H"])
	t.check_eq(seen, ["l1", "l2", "h1"] as Array[String], "L,L,H sem Brio desvia para o pesado")


func test_sword_divert_with_brio_is_the_crescent(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD)
	_fill_brio(sim)
	t.check(int(_hunter(sim)["brio"]) >= 3, "Brio suficiente para o desvio")
	var seen := _walk(sim, ["L", "L", "H"])
	t.check_eq(seen, ["l1", "l2", "meia_lua"] as Array[String], "L,L,H com Brio é a Meia-Lua")
	t.check_eq(int(_hunter(sim)["brio"]), 0, "e ela cobra os 3 pips")


func test_sword_h_l_h_differs_from_l_l_h(t: TestCase) -> void:
	var plain := _sim(Weapons.SWORD)
	t.check_eq(_walk(plain, ["H", "L", "H"]), ["h1", "hl", "h2"] as Array[String],
		"H,L,H sem Brio segue a cadeia pesada pela ligação")

	var brave := _sim(Weapons.SWORD)
	_fill_brio(brave)
	t.check_eq(_walk(brave, ["H", "L", "H"]), ["h1", "hl", "eco"] as Array[String],
		"H,L,H com Brio crava o Eco")


func test_the_same_key_is_not_the_same_strike(t: TestCase) -> void:
	# O teste de sequência mista do ticket: o 2º leve de L,L,L e o leve de
	# H,L são a MESMA tecla e Golpes diferentes.
	var light := _sim(Weapons.SWORD)
	var after_light := _walk(light, ["L", "L"])[1]

	var heavy := _sim(Weapons.SWORD)
	var after_heavy := _walk(heavy, ["H", "L"])[1]

	t.check_eq(after_light, "l2", "L,L dá o segundo leve")
	t.check_eq(after_heavy, "hl", "H,L dá o Corte de Ligação")
	t.check(after_light != after_heavy, "mesma tecla, Golpes diferentes: o histórico é a posição no grafo")


func test_sword_brio_never_passes_the_cap(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD)
	for _i in 10:
		_walk(sim, ["L", "L", "L"])
		_run(sim, _in(), 30)
	t.check_eq(int(_hunter(sim)["brio"]), SimConfig.BRIO_MAX, "o Brio para no teto")


func test_sword_sprint_and_dodge_have_their_own_entries(t: TestCase) -> void:
	var sprinting := _sim(Weapons.SWORD, FAR)
	# Corre por meio segundo e aperta o leve ainda correndo.
	_run(sprinting, _in(false, false, false, false, false, false, Vector2.UP, true), 30, [], FAR)
	_run(sprinting, _in(true, false, false, false, false, false, Vector2.UP, true), 1, [], FAR)
	t.check_eq(_node(sprinting), "estocada_corrida", "leve saindo da corrida tem nó próprio")

	var rolling := _sim(Weapons.SWORD)
	_run(rolling, HunterInput.make(Vector2.UP, 0.0, 0, false, true), 1)
	var guard := 0
	while guard < SECOND and _state(rolling) != int(HunterState.State.FREE):
		guard += 1
		_run(rolling, _in(), 1)
	_run(rolling, _in(true), 1)
	t.check_eq(_node(rolling), "bote_rasteiro", "leve logo após o rolamento tem nó próprio")


func test_the_dodge_entry_expires(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD)
	_run(sim, HunterInput.make(Vector2.UP, 0.0, 0, false, true), 1)
	var guard := 0
	while guard < SECOND and _state(sim) != int(HunterState.State.FREE):
		guard += 1
		_run(sim, _in(), 1)
	# Passa da janela pós-esquiva (0,25 s).
	_run(sim, _in(), int(SimConfig.COMBO_DODGE_WINDOW * SECOND) + 3)
	_run(sim, _in(true), 1)
	t.check_eq(_node(sim), "l1", "fora da janela, o leve volta a ser o primeiro da cadeia")


func test_the_echo_pulses_more_than_once(t: TestCase) -> void:
	var sim := _sim(Weapons.SWORD)
	_fill_brio(sim)
	var events: Array = []
	_walk(sim, ["H", "L", "H"], events)
	t.check(_hits_named(events, "Eco Cravado").size() >= 3, "o Eco pulsa a poça várias vezes")


## 3. Martelo --------------------------------------------------------------

func test_hammer_light_chain_ends_in_the_burst(t: TestCase) -> void:
	var sim := _sim(Weapons.HAMMER)
	var seen := _walk(sim, ["L", "L", "L", "H"])
	t.check_eq(seen, ["p1", "p2", "p3", "estouro"] as Array[String], "L,L,L,H descarrega o Estouro")
	t.check_eq(int(_hunter(sim)["ammo"]), 0, "e zera a munição")


func test_the_primed_shot_does_not_reset_the_chain(t: TestCase) -> void:
	# A assinatura do Martelo: o pesado encaixado ENTRE leves continua a
	# cadeia de onde ela estava, em vez de recomeçar.
	var sim := _sim(Weapons.HAMMER)
	var seen := _walk(sim, ["L", "H", "L", "L", "H"])
	t.check_eq(
		seen, ["p1", "prep1", "p2", "p3", "estouro"] as Array[String],
		"L,H,L,L,H encaixa o disparo sem reiniciar"
	)
	t.check_eq(int(_hunter(sim)["ammo"]), 0, "o encaixado gasta 1 e o Estouro leva o resto")


func test_the_primed_shot_needs_ammo(t: TestCase) -> void:
	var sim := _sim(Weapons.HAMMER)
	# Esvazia o pente pelo caminho do jogo e tenta o encaixado sem munição.
	_walk(sim, ["L", "L", "L", "H"])
	_run(sim, _in(), 60)
	var seen := _walk(sim, ["L", "H"])
	t.check_eq(seen[0], "p1", "a cadeia leve começa normal")
	t.check_eq(seen[1], "coronhada", "sem munição não há encaixado: cai na Coronhada da entrada")


func test_the_inline_reload_keeps_the_chain(t: TestCase) -> void:
	var sim := _sim(Weapons.HAMMER)
	_walk(sim, ["L", "L", "L", "H"])  # zera a munição no Estouro
	_run(sim, _in(), 60)
	_walk(sim, ["L"])
	t.check_eq(int(_hunter(sim)["ammo"]), 0, "pente vazio antes da encaixada")

	_run(sim, _in(false, false, false, false, false, true), 1)
	t.check_eq(int(_hunter(sim)["ammo"]), 1, "R dentro da janela dá uma munição")
	t.check_eq(_state(sim), int(HunterState.State.FREE), "sem entrar na recarga de verdade")
	t.check_eq(_walk(sim, ["L"]), ["p2"] as Array[String], "e a cadeia continua de onde estava")


func test_the_inline_reload_only_works_once_per_node(t: TestCase) -> void:
	# A segunda R no mesmo nó não dá munição de graça: ela cai na recarga de
	# verdade, com o preço de sempre. Sem esse limite dava para farmar munição
	# parado dentro da janela.
	var sim := _sim(Weapons.HAMMER)
	_walk(sim, ["L", "L", "L", "H"])
	_run(sim, _in(), 60)
	_walk(sim, ["L"])
	_run(sim, _in(false, false, false, false, false, true), 1)
	t.check_eq(int(_hunter(sim)["ammo"]), 1, "a primeira R encaixa")
	_run(sim, _in(), 1)
	_run(sim, _in(false, false, false, false, false, true), 1)
	t.check_eq(int(_hunter(sim)["ammo"]), 1, "a segunda não soma de graça")
	t.check_eq(_state(sim), int(HunterState.State.RELOADING), "ela vira a recarga de verdade")


func test_the_blast_does_not_break_the_chain(t: TestCase) -> void:
	# Regra 5 do modelo: entrar num ESTADO preserva a posição no grafo.
	var sim := _sim(Weapons.HAMMER)
	_walk(sim, ["L"])
	_run(sim, _in(false, true, false, true), 1)
	t.check_eq(_state(sim), int(HunterState.State.CHARGING), "segurar o pesado arma a Rajada")
	_run(sim, _in(), 1)
	var guard := 0
	while guard < SECOND * 3 and _state(sim) != int(HunterState.State.FREE):
		guard += 1
		_run(sim, _in(), 1)
	_run(sim, _in(true), 1)
	t.check_eq(_node(sim), "p2", "soltando a Rajada, o leve seguinte continua a cadeia")


func test_hammer_sprint_and_dodge_entries(t: TestCase) -> void:
	var sprinting := _sim(Weapons.HAMMER, FAR)
	_run(sprinting, _in(false, false, false, false, false, false, Vector2.UP, true), 30, [], FAR)
	_run(sprinting, _in(false, true, false, false, false, false, Vector2.UP, true), 1, [], FAR)
	t.check_eq(_node(sprinting), "salto_demolidor", "pesado em corrida é o Salto Demolidor")

	var rolling := _sim(Weapons.HAMMER)
	_run(rolling, HunterInput.make(Vector2.UP, 0.0, 0, false, true), 1)
	var guard := 0
	while guard < SECOND and _state(rolling) != int(HunterState.State.FREE):
		guard += 1
		_run(rolling, _in(), 1)
	_run(rolling, _in(true), 1)
	t.check_eq(_node(rolling), "pancada_curta", "leve pós-esquiva é a Pancada Curta")


## 4. Lâminas --------------------------------------------------------------

func test_blades_light_chain_has_five_links(t: TestCase) -> void:
	var sim := _sim(Weapons.BLADES)
	var seen := _walk(sim, ["L", "L", "L", "L", "L"])
	t.check_eq(seen, ["t1", "t2", "t3", "t4", "t5"] as Array[String], "o combo leve tem cinco Golpes")


func test_the_closing_link_gives_the_best_momentum(t: TestCase) -> void:
	var closing := Weapons.node_move(Weapons.BLADES, "t5")
	var middle := Weapons.node_move(Weapons.BLADES, "t2")
	t.check(
		float(closing.get("momentum", SimConfig.MOMENTUM_PER_HIT))
			> float(middle.get("momentum", SimConfig.MOMENTUM_PER_HIT)),
		"a Lâmina Dupla gera mais Momentum que os elos do meio"
	)
	var sim := _sim(Weapons.BLADES)
	_walk(sim, ["L", "L", "L", "L", "L"])
	t.check(float(_hunter(sim)["momentum"]) + float(_hunter(sim)["pips"]) * SimConfig.MOMENTUM_PIP > 0.0,
		"e a cadeia enche o medidor")


func test_a_tap_and_a_hold_are_different_edges(t: TestCase) -> void:
	var tapped := _sim(Weapons.BLADES)
	t.check_eq(_walk(tapped, ["L", "L", "H"]), ["t1", "t2", "giro_amplo"] as Array[String],
		"pesado TOCADO em t2 é o Giro Amplo")

	var held := _sim(Weapons.BLADES)
	t.check_eq(_walk(held, ["L", "L", "L", "Hh"]), ["t1", "t2", "t3", "roda_viva"] as Array[String],
		"pesado SEGURADO em t3 é a Roda Viva")


func test_the_wide_spin_hits_more_than_once(t: TestCase) -> void:
	var sim := _sim(Weapons.BLADES)
	var events: Array = []
	_walk(sim, ["L", "L", "H"], events)
	t.check(_hits_named(events, "Giro Amplo").size() >= 3, "o Giro Amplo é multi-hit")


func test_the_channel_lasts_while_held_and_drains(t: TestCase) -> void:
	var sim := _sim(Weapons.BLADES)
	_walk(sim, ["L", "L", "L"])
	_run(sim, _in(false, true, false, true), 1)
	t.check_eq(_node(sim), "roda_viva", "a Roda Viva começa")
	var before: float = _hunter(sim)["stamina"]
	var events: Array = []
	_run(sim, _in(false, false, false, true), SECOND, events)
	t.check_eq(_node(sim), "roda_viva", "segurando, o canal continua")
	t.check(float(_hunter(sim)["stamina"]) < before - 5.0, "e drena vigor por segundo")
	t.check(_hits_named(events, "Roda Viva").size() >= 3, "pulsando dano o tempo todo")

	# Soltar encerra: o Golpe cai na Recuperação e volta ao controle.
	var guard := 0
	while guard < SECOND * 2 and _state(sim) != int(HunterState.State.FREE):
		guard += 1
		_run(sim, _in(), 1)
	t.check_eq(_state(sim), int(HunterState.State.FREE), "soltar encerra o canal")


func test_the_hook_does_not_reset_the_chain(t: TestCase) -> void:
	var sim := _sim(Weapons.BLADES, FAR)
	_walk(sim, ["L", "L"], [], FAR)
	t.check_eq(int(_hunter(sim)["combo_from"]), Weapons.flat_of(Weapons.BLADES, "t2"), "parado em t2")

	_run(sim, _in(false, true), 1, [], FAR)
	t.check_eq(_state(sim), int(HunterState.State.HOOK_PULL), "longe, o pesado é o Gancho")
	var guard := 0
	while guard < SECOND * 2 and _state(sim) != int(HunterState.State.FREE):
		guard += 1
		_run(sim, _in(), 1, [], FAR)
	_run(sim, _in(true), 1, [], FAR)
	t.check_eq(_node(sim), "t3", "chegando colado, o leve continua de onde a cadeia estava")


func test_blades_heavy_chain_exists(t: TestCase) -> void:
	var sim := _sim(Weapons.BLADES)
	var seen := _walk(sim, ["L", "H", "H", "H"])
	t.check_eq(seen, ["t1", "h1", "h2", "h3"] as Array[String], "a cadeia pesada tem três dentes")


func test_the_back_dodge_opens_space(t: TestCase) -> void:
	var sim := _sim(Weapons.BLADES)
	# Esquiva para TRÁS (mira em +x, rola para -x) e pesado na janela.
	_run(sim, HunterInput.make(Vector2.LEFT, 0.0, 0, false, true), 1)
	var guard := 0
	while guard < SECOND and _state(sim) != int(HunterState.State.FREE):
		guard += 1
		_run(sim, _in(), 1)
	var before: Vector2 = _hunter(sim)["pos"]
	_run(sim, _in(false, true), 1)
	t.check_eq(_node(sim), "salto_recuo", "esquiva para trás + pesado é o Salto de Recuo")
	var events: Array = []
	_run(sim, _in(), 30, events)
	t.check(float((_hunter(sim)["pos"] as Vector2).x) < before.x - 100.0, "e afasta de verdade")

	var forward := _sim(Weapons.BLADES)
	_run(forward, HunterInput.make(Vector2.RIGHT, 0.0, 0, false, true), 1)
	var guard2 := 0
	while guard2 < SECOND and _state(forward) != int(HunterState.State.FREE):
		guard2 += 1
		_run(forward, _in(), 1)
	_run(forward, _in(false, true), 1)
	t.check(_node(forward) != "salto_recuo", "esquiva para a FRENTE não dá o recuo")


func test_blades_sprint_and_dodge_entries(t: TestCase) -> void:
	var sprinting := _sim(Weapons.BLADES, FAR)
	_run(sprinting, _in(false, false, false, false, false, false, Vector2.UP, true), 30, [], FAR)
	_run(sprinting, _in(true, false, false, false, false, false, Vector2.UP, true), 1, [], FAR)
	t.check_eq(_node(sprinting), "talho_corrida", "leve em corrida tem nó próprio")

	var rolling := _sim(Weapons.BLADES)
	_run(rolling, HunterInput.make(Vector2.UP, 0.0, 0, false, true), 1)
	var guard := 0
	while guard < SECOND and _state(rolling) != int(HunterState.State.FREE):
		guard += 1
		_run(rolling, _in(), 1)
	_run(rolling, _in(true), 1)
	t.check_eq(_node(rolling), "cruzado_rasante", "leve pós-esquiva tem nó próprio")


## 5. Lança ----------------------------------------------------------------

func test_pike_light_chain_has_four_thrusts(t: TestCase) -> void:
	var sim := _sim(Weapons.PIKE)
	t.check_eq(
		_walk(sim, ["L", "L", "L", "L"]), ["e1", "e2", "e3", "e4"] as Array[String],
		"a Lança encadeia quatro estocadas"
	)


func test_holding_the_light_at_the_third_thrust_is_the_drill(t: TestCase) -> void:
	var sim := _sim(Weapons.PIKE)
	t.check_eq(
		_walk(sim, ["L", "L", "L", "Lh"]), ["e1", "e2", "e3", "broca"] as Array[String],
		"segurar o leve no fim da cadeia vira a Broca"
	)


func test_pike_diverts_both_ways_without_resetting(t: TestCase) -> void:
	var sim := _sim(Weapons.PIKE)
	t.check_eq(
		_walk(sim, ["L", "L", "H", "L"]), ["e1", "e2", "varredura", "e2"] as Array[String],
		"estocada → varredura → estocada: desvio nos dois sentidos, sem reset"
	)


func test_pike_sprint_and_dodge_entries(t: TestCase) -> void:
	var sprinting := _sim(Weapons.PIKE, FAR)
	_run(sprinting, _in(false, false, false, false, false, false, Vector2.UP, true), 30, [], FAR)
	_run(sprinting, _in(true, false, false, false, false, false, Vector2.UP, true), 1, [], FAR)
	t.check_eq(_node(sprinting), "estocada_disparada", "leve em corrida fecha distância")

	# Dois inputs diferentes no MESMO contexto pós-esquiva.
	for pair in [["L", "estocada_rasante"], ["H", "varredura_saltada"]]:
		var rolling := _sim(Weapons.PIKE)
		_run(rolling, HunterInput.make(Vector2.UP, 0.0, 0, false, true), 1)
		var guard := 0
		while guard < SECOND and _state(rolling) != int(HunterState.State.FREE):
			guard += 1
			_run(rolling, _in(), 1)
		_run(rolling, _token(String(pair[0]), true), 1)
		t.check_eq(_node(rolling), String(pair[1]), "pós-esquiva responde por Entrada")


## 6. Machado (árvore) -----------------------------------------------------

func test_axe_chains_and_diverts(t: TestCase) -> void:
	var sim := _sim(Weapons.AXE)
	t.check_eq(
		_walk(sim, ["L", "L", "L"]),
		["talho_amplo", "talho_retorno", "ceifa_total"] as Array[String],
		"a cadeia horizontal tem três golpes"
	)
	var diverting := _sim(Weapons.AXE)
	t.check_eq(
		_walk(diverting, ["L", "H"]),
		["talho_amplo", "racha_cranio"] as Array[String],
		"e desvia para o vertical sem reiniciar"
	)


func test_the_ripper_channel_accelerates(t: TestCase) -> void:
	var sim := _sim(Weapons.AXE)
	_walk(sim, ["H", "H"])
	_run(sim, _in(false, true, false, true), 1)
	t.check_eq(_node(sim), "ceifa_continua", "segurar o pesado após a Queda abre a Ceifa Contínua")
	var events: Array = []
	_run(sim, _in(false, false, false, true), int(SECOND * 2.5), events)
	t.check(_hits_named(events, "Ceifa Contínua").size() >= 3, "o canal bate várias vezes")


## 7. Repetidoras (robustez do grafo vazio) --------------------------------

func test_repeaters_never_write_a_combo_position(t: TestCase) -> void:
	var sim := _sim(Weapons.REPEATERS)
	# Atirar, rolar e recarregar: nada disso grava posição no grafo.
	_run(sim, _in(true, false, true), 30)
	t.check_eq(int(_hunter(sim)["combo_from"]), -1, "atirar não grava nó")
	_run(sim, _in(false, true), 1)
	t.check_eq(_state(sim), int(HunterState.State.TUMBLE), "o pesado é o Rolinho")
	_run(sim, _in(), 30)
	t.check_eq(int(_hunter(sim)["combo_from"]), -1, "rolar não grava nó")
	_run(sim, _in(false, false, false, false, false, true), 1)
	_run(sim, _in(), int(SimConfig.REPEATER_RELOAD_TIME * SECOND) + 5)
	t.check_eq(int(_hunter(sim)["combo_from"]), -1, "recarregar não grava nó")


func test_two_weapons_in_one_sim_do_not_leak(t: TestCase) -> void:
	var sim := Sim.new(Behemoths.GNASHER)
	sim.add_hunter(1, "Espada", Weapons.SWORD)
	sim.add_hunter(2, "Repetidoras", Weapons.REPEATERS)
	var sword_nodes: Array[String] = []
	var guns_leaked := false
	for _i in 180:
		_park(sim, CLOSE)
		sim.set_input(1, _in(true))
		sim.set_input(2, _in(true, false, true))
		sim.step(SimConfig.TICK_DELTA)
		sim.take_events()
		var frame := sim.snapshot()
		var sword: Dictionary = frame["hunters"][0]
		var guns: Dictionary = frame["hunters"][1]
		if int(sword["state"]) == int(HunterState.State.ATTACK):
			var node := Weapons.node_name(
				Weapons.SWORD, int(sword["attack_kind"]) as Weapons.Kind, int(sword["attack_index"])
			)
			if node not in sword_nodes:
				sword_nodes.append(node)
		if int(guns["combo_from"]) >= 0:
			guns_leaked = true
	t.check_eq(sword_nodes, ["l1", "l2", "l3"] as Array[String], "a Espada anda pelo grafo dela")
	t.check(not guns_leaked, "as Repetidoras continuam sem nó")
	t.check(
		int((sim.snapshot()["hunters"][1] as Dictionary)["mag"]) < SimConfig.REPEATER_MAG,
		"e gastando o pente"
	)


## 8. Regressão do enum ----------------------------------------------------

func test_state_enum_is_append_only(t: TestCase) -> void:
	# O aviso do REVIEW de 09/10 vira verificação: os ints dos estados antigos
	# viajam no Instantâneo e não podem mudar de valor.
	t.check_eq(int(HunterState.State.FREE), 0, "FREE == 0")
	t.check_eq(int(HunterState.State.DODGE), 1, "DODGE == 1")
	t.check_eq(int(HunterState.State.ATTACK), 2, "ATTACK == 2")
	t.check_eq(int(HunterState.State.CHARGING), 3, "CHARGING == 3")
	t.check_eq(int(HunterState.State.HOOK_PULL), 4, "HOOK_PULL == 4")
	t.check_eq(int(HunterState.State.SPECIAL_SPIN), 5, "SPECIAL_SPIN == 5")
	t.check_eq(int(HunterState.State.HURT), 6, "HURT == 6")
	t.check_eq(int(HunterState.State.DOWNED), 7, "DOWNED == 7")
	t.check_eq(int(HunterState.State.RELOADING), 8, "RELOADING == 8")
	t.check_eq(int(HunterState.State.AXE_CHARGE), 9, "AXE_CHARGE entrou no FIM")
	t.check_eq(int(HunterState.State.TUMBLE), 10, "TUMBLE entrou depois dele")
	t.check_eq(int(Weapons.DamageType.BALLISTIC), 3, "BALLISTIC também entrou no fim")
