extends RefCounted

## Partes, Tipos de Dano e Atordoamento, pela interface pública da Sim.
##
## Pragmatismo assumido: posicionar o Caçador atrás do monstro andando de
## verdade exigiria coreografia de Ameaça; os testes fixam `facing` e `pos` do
## BehemothState (já exposto por sim.behemoth()) e batem pela Sim normal.

const HUNTER: int = 1
const SECOND: int = SimConfig.TICK_RATE

func _sim(weapon: String = Weapons.SWORD) -> Sim:
	var sim := Sim.new(Behemoths.GNASHER)
	sim.add_hunter(HUNTER, "Teste", weapon)
	return sim

func _beh(sim: Sim) -> BehemothState:
	return sim.behemoth()

func _hunter(sim: Sim) -> Dictionary:
	for hunter in sim.snapshot()["hunters"]:
		if hunter["id"] == HUNTER:
			return hunter
	return {}

## Coloca o monstro colado ao Caçador (que fica na origem), virado num ângulo
## fixo, e congela a IA no lugar zerando a Vida de ataque dele via cooldowns.
func _park_behemoth(sim: Sim, facing: float) -> void:
	var behemoth := _beh(sim)
	behemoth.pos = Vector2(130.0, 0.0)
	behemoth.facing = facing
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0

## Um Golpe leve completo mirando o monstro, com o facing do monstro re-fixado
## a cada Tique (a IA tenta virar; o teste quer o setor estável).
func _swing(sim: Sim, facing: float) -> void:
	var behemoth := _beh(sim)
	var aim := (behemoth.pos - Vector2.ZERO).angle()
	# A duração do primeiro Golpe leve é a mesma ordem de grandeza nas duas
	# armas; usa a mais longa para o swing sempre terminar.
	var duration := 1.2
	sim.set_input(HUNTER, HunterInput.make(Vector2.ZERO, aim, 0, false, false, true, false))
	for _i in int(ceilf(duration * SimConfig.TICK_RATE)):
		behemoth.facing = facing
		behemoth.pos = Vector2(130.0, 0.0)
		sim.step(SimConfig.TICK_DELTA)
		sim.set_input(HUNTER, HunterInput.make(Vector2.ZERO, aim))

func _part(sim: Sim, id: String) -> Dictionary:
	return _beh(sim).part(id)


## Setores -------------------------------------------------------------------

func test_hitting_the_front_damages_the_head(t: TestCase) -> void:
	var sim := _sim()
	_park_behemoth(sim, PI)  # de frente para o Caçador
	_swing(sim, PI)

	t.check(float(_part(sim, "head")["hp"]) < float(_part(sim, "head")["max_hp"]), "golpe de frente desconta da cabeça")
	t.check_approx(float(_part(sim, "tail")["hp"]), float(_part(sim, "tail")["max_hp"]), "e não da cauda")


func test_hitting_the_back_damages_the_tail(t: TestCase) -> void:
	var sim := _sim()
	_park_behemoth(sim, 0.0)  # de costas para o Caçador
	_swing(sim, 0.0)

	t.check(float(_part(sim, "tail")["hp"]) < float(_part(sim, "tail")["max_hp"]), "golpe por trás desconta da cauda")
	t.check_approx(float(_part(sim, "head")["hp"]), float(_part(sim, "head")["max_hp"]), "e não da cabeça")


func test_hitting_the_side_damages_the_legs(t: TestCase) -> void:
	var sim := _sim()
	_park_behemoth(sim, PI * 0.5)  # de lado
	_swing(sim, PI * 0.5)

	t.check(float(_part(sim, "legs")["hp"]) < float(_part(sim, "legs")["max_hp"]), "golpe de lado desconta das pernas")


## Tipos de Dano ---------------------------------------------------------------

func test_slash_is_better_than_blunt_against_the_tail(t: TestCase) -> void:
	var slash_sim := _sim(Weapons.SWORD)
	_park_behemoth(slash_sim, 0.0)
	_swing(slash_sim, 0.0)
	var slash_hp := float(_part(slash_sim, "tail")["hp"])

	var blunt_sim := _sim(Weapons.HAMMER)
	_park_behemoth(blunt_sim, 0.0)
	_swing(blunt_sim, 0.0)
	var blunt_hp := float(_part(blunt_sim, "tail")["hp"])

	# Espada base 20 × 1.4 (decepável) = 28; Martelo base 30 sem bônus = 30
	# na Vida — mas na PARTE conta o dano, então comparamos a fração removida
	# ajustada pelos danos base: o que importa é o bônus de Corte existir.
	var slash_taken := float(_part(slash_sim, "tail")["max_hp"]) - slash_hp
	var blunt_taken := float(_part(blunt_sim, "tail")["max_hp"]) - blunt_hp
	var sword_base := float(Weapons.move(Weapons.SWORD, Weapons.Kind.LIGHT, 0)["damage"])
	var hammer_base := float(Weapons.move(Weapons.HAMMER, Weapons.Kind.LIGHT, 0)["damage"])

	t.check(
		slash_taken / sword_base > blunt_taken / hammer_base + 0.2,
		"por ponto de dano base, Corte tira mais da cauda que Impacto"
	)


func test_blunt_builds_stagger_much_faster_than_slash(t: TestCase) -> void:
	var slash_sim := _sim(Weapons.SWORD)
	_park_behemoth(slash_sim, PI)
	_swing(slash_sim, PI)
	var slash_stagger := _beh(slash_sim).stagger

	var blunt_sim := _sim(Weapons.HAMMER)
	_park_behemoth(blunt_sim, PI)
	_swing(blunt_sim, PI)
	var blunt_stagger := _beh(blunt_sim).stagger

	t.check(blunt_stagger > slash_stagger * 2.0, "o Martelo enche o Atordoamento muito mais rápido")


## Quebra ----------------------------------------------------------------------

func test_breaking_a_part_raises_damage_and_adds_stagger(t: TestCase) -> void:
	var sim := _sim()
	_park_behemoth(sim, 0.0)
	var behemoth := _beh(sim)
	var tail := _part(sim, "tail")
	tail["hp"] = 1.0  # a um golpe da quebra

	_swing(sim, 0.0)

	t.check(tail["broken"], "a cauda quebra")
	t.check(behemoth.stagger > 0.0 or behemoth.state == BehemothState.State.STAGGERED,
		"a quebra empurra o Atordoamento")

	var break_events := 0
	for event in sim.take_events():
		if event["type"] == "part_break":
			break_events += 1
	t.check_eq(break_events, 1, "a quebra é anunciada uma vez")


func test_a_severed_tail_removes_the_tail_attack(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	behemoth.part("tail")["broken"] = true

	# Com a cauda decepada e todos os outros em recarga, não há ataque válido
	# mesmo na distância da rabada.
	for key in behemoth.cooldowns:
		behemoth.cooldowns[key] = 999.0
	behemoth.cooldowns["tail"] = 0.0
	behemoth.pos = Vector2(180.0, 0.0)

	for _i in SECOND:
		sim.set_input(HUNTER, HunterInput.make(Vector2.ZERO, 0.0))
		sim.step(SimConfig.TICK_DELTA)

	t.check(behemoth.attack_id != "tail", "a rabada sumiu do repertório")
	t.check_eq(int(behemoth.state), int(BehemothState.State.CHASE), "sem opções, ele volta a perseguir")


func test_a_broken_part_takes_bonus_damage(t: TestCase) -> void:
	var intact := _sim()
	_park_behemoth(intact, PI)
	var hp_before_intact := _beh(intact).hp
	_swing(intact, PI)
	var intact_taken := hp_before_intact - _beh(intact).hp

	var broken := _sim()
	_park_behemoth(broken, PI)
	_beh(broken).part("head")["broken"] = true
	var hp_before_broken := _beh(broken).hp
	_swing(broken, PI)
	var broken_taken := hp_before_broken - _beh(broken).hp

	t.check(broken_taken > intact_taken * 1.2, "a Parte quebrada recebe dano aumentado")


## Atordoamento -----------------------------------------------------------------

func test_a_full_meter_knocks_the_behemoth_down(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	BehemothStep.add_stagger(behemoth, behemoth.stagger_threshold + 1.0)

	t.check_eq(int(behemoth.state), int(BehemothState.State.STAGGERED), "medidor cheio derruba")
	t.check_approx(behemoth.stagger, 0.0, "e o medidor zera")


func test_the_behemoth_gets_up_after_the_down_duration(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	BehemothStep.add_stagger(behemoth, behemoth.stagger_threshold + 1.0)

	for _i in int(SimConfig.STAGGER_DOWN_DURATION * SimConfig.TICK_RATE) + 4:
		sim.set_input(HUNTER, HunterInput.make(Vector2.ZERO, 0.0))
		sim.step(SimConfig.TICK_DELTA)

	t.check(int(behemoth.state) != int(BehemothState.State.STAGGERED), "a queda acaba sozinha")


func test_each_knockdown_costs_more_than_the_last(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	var first := behemoth.stagger_threshold
	BehemothStep.add_stagger(behemoth, first + 1.0)

	t.check(behemoth.stagger_threshold > first * 1.2, "o próximo limiar fica mais caro")


func test_the_meter_decays_over_time(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	BehemothStep.add_stagger(behemoth, behemoth.stagger_threshold * 0.5)
	var before := behemoth.stagger

	for _i in SECOND * 2:
		sim.set_input(HUNTER, HunterInput.make(Vector2.ZERO, 0.0))
		sim.step(SimConfig.TICK_DELTA)

	t.check(behemoth.stagger < before - 10.0, "o medidor esvazia sozinho com o tempo")


func test_a_staggered_behemoth_takes_bonus_damage(t: TestCase) -> void:
	var normal := _sim()
	_park_behemoth(normal, PI)
	var hp_a := _beh(normal).hp
	_swing(normal, PI)
	var normal_taken := hp_a - _beh(normal).hp

	var downed := _sim()
	_park_behemoth(downed, PI)
	BehemothStep.add_stagger(_beh(downed), _beh(downed).stagger_threshold + 1.0)
	var hp_b := _beh(downed).hp
	_swing(downed, PI)
	var downed_taken := hp_b - _beh(downed).hp

	t.check(downed_taken > normal_taken * 1.2, "o Behemoth caído recebe dano aumentado")


func test_a_knockdown_interrupts_the_current_attack(t: TestCase) -> void:
	var sim := _sim()
	var behemoth := _beh(sim)
	behemoth.attack_id = "bite"
	behemoth.state = BehemothState.State.WINDUP
	behemoth.state_time = 0.1

	BehemothStep.add_stagger(behemoth, behemoth.stagger_threshold + 1.0)

	t.check_eq(behemoth.attack_id, "", "a queda cancela o ataque em Preparo")
	t.check(float(behemoth.cooldowns["bite"]) > 0.0, "e o ataque cancelado entra em recarga")
