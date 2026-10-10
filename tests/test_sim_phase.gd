extends RefCounted

## Fases da Caçada: LOBBY → HUNT → RESULT, "pronto" por Caçador e o resumo
## que a tela de resultado consome.
##
## Compatibilidade: o caminho antigo (hospedar já entra na Caçada) continua
## valendo — só quem pede lobby nasce em LOBBY.

const SECOND: int = SimConfig.TICK_RATE


func _lobby() -> Sim:
	var sim := Sim.new(Behemoths.GNASHER, Elements.Element.NEUTRAL, true)
	sim.add_hunter(1, "Anfitrião", Weapons.SWORD)
	sim.add_hunter(2, "Convidada", Weapons.HAMMER)
	return sim


func _idle() -> HunterInput:
	return HunterInput.make(Vector2.ZERO, 0.0)


func _run(sim: Sim, ticks: int) -> void:
	for _i in ticks:
		sim.set_input(1, _idle())
		sim.set_input(2, _idle())
		sim.step(SimConfig.TICK_DELTA)
		sim.take_events()


## Compatibilidade ---------------------------------------------------------

func test_hosting_still_drops_straight_into_the_hunt(t: TestCase) -> void:
	var sim := Sim.new(Behemoths.GNASHER)
	sim.add_hunter(1, "Teste")
	t.check_eq(int(sim.phase()), int(Sim.Phase.HUNT), "o caminho atual continua entrando na Caçada")
	t.check(sim.behemoth() != null, "com o Behemoth já na Arena")


func test_training_has_no_behemoth_and_still_hunts(t: TestCase) -> void:
	var sim := Sim.new()
	sim.add_hunter(1, "Teste")
	t.check_eq(int(sim.phase()), int(Sim.Phase.HUNT), "a área de treinamento não vira lobby")
	t.check(sim.behemoth() == null, "e segue sem monstro")


## Lobby -------------------------------------------------------------------

func test_the_lobby_waits_for_the_host(t: TestCase) -> void:
	var sim := _lobby()
	t.check_eq(int(sim.phase()), int(Sim.Phase.LOBBY), "pedindo lobby, a Sim nasce em LOBBY")
	t.check(sim.behemoth() == null, "o Behemoth só nasce quando a Caçada começa")
	_run(sim, SECOND)
	t.check(sim.behemoth() == null, "e o tempo passando não o faz nascer")


func test_ready_is_per_hunter(t: TestCase) -> void:
	var sim := _lobby()
	t.check(not sim.all_ready(), "ninguém pronto no começo")
	sim.set_ready(1, true)
	t.check(sim.is_ready(1), "o Anfitrião ficou pronto")
	t.check(not sim.is_ready(2), "a convidada ainda não")
	t.check(not sim.all_ready(), "e o grupo ainda não está")
	sim.set_ready(2, true)
	t.check(sim.all_ready(), "com os dois prontos, o grupo está")
	sim.set_ready(2, false)
	t.check(not sim.all_ready(), "e dá para desmarcar")


func test_ready_travels_in_the_snapshot_and_the_roster(t: TestCase) -> void:
	var sim := _lobby()
	sim.set_ready(2, true)
	var hunters: Array = sim.snapshot()["hunters"]
	var guest: Dictionary = hunters[1]
	t.check(bool(guest["ready"]), "o 'pronto' viaja no Instantâneo")
	t.check(bool(sim.roster()[2]["ready"]), "e na lista de Caçadores")
	# O lobby precisa ver o 'pronto' dos OUTROS, não só o próprio.
	var partial: Array = sim.snapshot(1)["hunters"]
	t.check(bool((partial[1] as Dictionary)["ready"]), "inclusive na visão enxuta dos remotos")


func test_starting_the_hunt_spawns_the_behemoth(t: TestCase) -> void:
	var sim := _lobby()
	t.check(sim.start_hunt(), "o Anfitrião começa a Caçada")
	t.check_eq(int(sim.phase()), int(Sim.Phase.HUNT), "a fase vira HUNT")
	t.check(sim.behemoth() != null, "e o Behemoth nasce")
	t.check_eq(sim.behemoth().type_id, Behemoths.GNASHER, "do tipo escolhido no lobby")


func test_the_hunt_only_starts_once(t: TestCase) -> void:
	var sim := _lobby()
	t.check(sim.start_hunt(), "a primeira chamada vale")
	t.check(not sim.start_hunt(), "a segunda é recusada: só se começa de dentro do LOBBY")


func test_the_host_can_change_the_behemoth_when_starting(t: TestCase) -> void:
	var sim := _lobby()
	sim.start_hunt(Behemoths.BASTION)
	t.check_eq(sim.behemoth().type_id, Behemoths.BASTION, "o tipo escolhido na largada vale")


func test_ready_is_mute_outside_the_lobby(t: TestCase) -> void:
	var sim := _lobby()
	sim.start_hunt()
	sim.set_ready(1, true)
	t.check(not sim.is_ready(1), "fora do lobby, 'pronto' não faz nada")


func test_the_phase_travels_in_the_snapshot(t: TestCase) -> void:
	var sim := _lobby()
	t.check_eq(int(sim.snapshot()["phase"]), int(Sim.Phase.LOBBY), "o Instantâneo diz a fase")
	sim.start_hunt()
	t.check_eq(int(sim.snapshot()["phase"]), int(Sim.Phase.HUNT), "e acompanha a troca")


## Resultado ---------------------------------------------------------------

func test_killing_the_behemoth_ends_in_result_with_a_summary(t: TestCase) -> void:
	var sim := _lobby()
	sim.start_hunt()
	var behemoth := sim.behemoth()
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0

	# Um golpe de Espada no Gnasher quase morto: a Caçada termina.
	behemoth.pos = Vector2(130.0, 0.0)
	behemoth.facing = PI
	behemoth.hp = 1.0
	var events: Array = []
	for _i in SECOND:
		behemoth.pos = Vector2(130.0, 0.0)
		behemoth.facing = PI
		sim.set_input(1, HunterInput.make(Vector2.ZERO, 0.0, 0, false, false, true))
		sim.set_input(2, _idle())
		sim.step(SimConfig.TICK_DELTA)
		events.append_array(sim.take_events())

	t.check_eq(int(sim.phase()), int(Sim.Phase.RESULT), "matar o Behemoth leva a RESULT")
	var summary := sim.result()
	t.check_eq(String(summary.get("outcome", "")), "victory", "com vitória")
	var hunters: Array = summary.get("hunters", [])
	t.check_eq(hunters.size(), 2, "e uma linha por Caçador")
	if hunters.size() == 2:
		var first: Dictionary = hunters[0]
		t.check(first.has("damage") and first.has("parts_broken") and first.has("interrupts"),
			"com dano causado, Partes quebradas e interrupções")
		t.check(float(first["damage"]) > 0.0, "quem bateu aparece com dano")
		t.check_approx(float((hunters[1] as Dictionary)["damage"]), 0.0, "quem não bateu, com zero")

	var announced := false
	for event in events:
		if event.get("type", "") == "phase" and String(event.get("phase", "")) == "result":
			announced = true
	t.check(announced, "a troca de fase é anunciada por evento")
	t.check(sim.snapshot().has("result"), "e o resumo viaja no Instantâneo")


func test_the_scoreboard_counts_parts_and_interrupts(t: TestCase) -> void:
	var sim := Sim.new(Behemoths.GNASHER)
	sim.add_hunter(1, "Teste", Weapons.SWORD)
	var behemoth := sim.behemoth()
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0
	behemoth.part("head")["hp"] = 1.0
	for _i in SECOND:
		behemoth.pos = Vector2(130.0, 0.0)
		behemoth.facing = PI
		sim.set_input(1, HunterInput.make(Vector2.ZERO, 0.0, 0, false, false, true))
		sim.step(SimConfig.TICK_DELTA)
		sim.take_events()
	var hunter: Dictionary = sim.snapshot()["hunters"][0]
	t.check_eq(int(hunter["parts_broken"]), 1, "quebrar uma Parte conta para quem quebrou")
	t.check(float(hunter["damage_dealt"]) > 0.0, "e o dano acumula no placar")
