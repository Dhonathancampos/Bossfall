class_name BehemothState
extends RefCounted

## O estado de um Behemoth dentro da Simulação.
##
## Ao contrário do Caçador, nada disto é previsto pelo Cliente: o Behemoth é
## interpolado entre Instantâneos, e só. Por isso o que vai para a rede é
## pequeno — o suficiente para desenhar o corpo e a Telegrafia.

enum State {
	## Perseguindo, ou parado decidindo o que fazer.
	CHASE,
	## Preparando um ataque. É a fase com Telegrafia no chão.
	WINDUP,
	## A única fase que machuca.
	ACTIVE,
	## Terminando o ataque. Janela de dano livre para os Caçadores.
	RECOVER,
	## Caído pelo Atordoamento: indefeso, recebendo dano aumentado.
	STAGGERED,
	DEAD,
	## Boopado: o ataque em Preparo foi cancelado por um impacto forte na
	## janela interrompível. Punição curta, sem bônus de dano — distinta da
	## queda. (No FIM do enum para não mudar os ints replicados — aviso da
	## Revisão de 09/10.)
	INTERRUPTED,
}

var id: int = 0
var type_id: String = Behemoths.GNASHER
var element: Elements.Element = Elements.Element.NEUTRAL
var pos: Vector2 = Vector2.ZERO
var facing: float = 0.0
var hp: float = 0.0
var max_hp: float = 0.0
var radius: float = 100.0

var state: State = State.CHASE
var state_time: float = 0.0

## O ataque em andamento, vazio fora de um ataque.
var attack_id: String = ""

## attack_id -> segundos que faltam para poder usar de novo.
var cooldowns: Dictionary = {}

## Ritmo do cérebro: brecha pós-ataque (dada por ataque nos dados) e pausa
## entre passos de uma sequência encadeada. Substituem a antiga pausa global.
var decision_gap: float = 0.0
var plan_gap: float = 0.0

## A sequência encadeada em andamento (ids de ataque ainda por sair).
var plan: Array[String] = []

## O ataque atual conectou em alguém? Decide a punição por erro (whiff).
var attack_connected: bool = false

## Recuperação extra do ataque atual (investida que errou fica mais exposta).
var recovery_bonus: float = 0.0

## Há quanto tempo o alvo está colado (alcance de pisão). Alimenta o padrão
## de castigo do Gnasher.
var sticky_time: float = 0.0

## Quem este ataque já acertou. Um ataque acerta cada Caçador no máximo uma vez.
var hit_ids: Array[int] = []

## id do Caçador -> quanto ele irritou o Behemoth.
var threat: Dictionary = {}
var target_id: int = 0

## Quanto falta para reavaliar em quem focar.
var retarget_in: float = 0.0

var enraged: bool = false

## Partes do corpo, copiadas dos dados no nascimento:
## [{id, name, hp, max_hp, sector, severable, hard, broken}]
var parts: Array[Dictionary] = []

## Medidor de Atordoamento e o limiar atual (cresce a cada queda).
var stagger: float = 0.0
var stagger_threshold: float = 0.0

## Penalidade permanente de recarga por ataque, ganha quando certas Partes
## quebram (a Carapaça do Bastião atrasa o Rolamento). {attack_id -> extra}
var cooldown_penalty: Dictionary = {}

## Lampejo de "levei uma pancada", para a Apresentação.
var hit_flash: float = 0.0

## Quanto tempo ainda dura o aviso de Fúria na tela.
var enrage_flash: float = 0.0


static func spawn(
	id: int,
	type_id: String,
	pos: Vector2,
	element: Elements.Element = Elements.Element.NEUTRAL
) -> BehemothState:
	var data := Behemoths.get_behemoth(type_id)
	var behemoth := BehemothState.new()
	behemoth.id = id
	behemoth.type_id = type_id
	behemoth.element = element
	behemoth.pos = pos
	behemoth.hp = float(data["hp"])
	behemoth.max_hp = float(data["hp"])
	behemoth.radius = float(data["radius"])
	behemoth.stagger_threshold = float(data["stagger_threshold"])
	for part in data["parts"]:
		behemoth.parts.append({
			"id": part["id"],
			"name": part["name"],
			"hp": float(part["hp"]),
			"max_hp": float(part["hp"]),
			"sector": part["sector"],
			"severable": part["severable"],
			"hard": part["hard"],
			"armored": part.get("armored", false),
			"break_penalty": part.get("break_penalty", {}),
			## Zona de acerto no plano (hurtbox da Parte); vazio = setor.
			"zone": part.get("zone", {}),
			"broken": false,
			## Ferimento (Lança de Guerra): o acúmulo de Perfuração, se a
			## Parte está Ferida agora e por quanto tempo ainda. Replicam de
			## graça — `to_dict` já manda `parts.duplicate(true)`.
			"wound": 0.0,
			"wounded": false,
			"wound_time": 0.0,
			## Quanto dano cada Caçador já tirou DESTA ferida aberta. Quem
			## chega ao alvo leva o buff pessoal. {id do Caçador -> float}
			"wound_claim": {},
		})

	# Todo ataque começa recarregando, com tempos diferentes, para que o
	# Behemoth não dispare tudo no primeiro segundo da Caçada.
	var delay := 1.0
	for attack in Behemoths.attacks(type_id):
		behemoth.cooldowns[attack["id"]] = delay
		delay += 0.6
	return behemoth


func is_alive() -> bool:
	return state != State.DEAD


func data() -> Dictionary:
	return Behemoths.get_behemoth(type_id)


func current_attack() -> Dictionary:
	return Behemoths.attack(type_id, attack_id)


func take_damage(amount: float) -> void:
	hp = maxf(0.0, hp - amount)
	hit_flash = SimConfig.HIT_FLASH_DURATION


func part(part_id: String) -> Dictionary:
	for entry in parts:
		if entry["id"] == part_id:
			return entry
	return {}


## Uma Parte decepada é uma quebrada que era decepável.
func is_severed(part_id: String) -> bool:
	var entry := part(part_id)
	return not entry.is_empty() and entry["broken"] and entry["severable"]


func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": type_id,
		"element": int(element),
		"pos": pos,
		"facing": facing,
		"hp": hp,
		"max_hp": max_hp,
		"radius": radius,
		"state": int(state),
		"state_time": state_time,
		"attack": attack_id,
		"enraged": enraged,
		"enrage_flash": enrage_flash,
		"hit_flash": hit_flash,
		"stagger": stagger,
		"stagger_threshold": stagger_threshold,
		"parts": parts.duplicate(true),
		## A janela de INTERRUPÇÃO aberta agora: é com isto que o HUD e a tela
		## "Aprenda" conseguem AVISAR que o boop cabe aqui. Sem este campo a
		## apresentação teria que reimplementar a regra lendo os dados.
		"interrupt_window": is_interruptible_now(),
		"interrupt_threshold": interrupt_threshold(),
	}


## Verdadeiro enquanto o ataque em Preparo pode ser cancelado por um impacto
## de Atordoamento forte. Fonte única da regra: quem desenha e quem resolve o
## boop leem a MESMA função.
func is_interruptible_now() -> bool:
	if state != State.WINDUP or attack_id.is_empty():
		return false
	var window: Dictionary = current_attack().get("interruptible", {})
	if window.is_empty():
		return false
	return state_time <= float(window.get("until", 0.0))


## Quanto Atordoamento o impacto precisa gerar para interromper agora.
## Zero quando não há janela aberta.
func interrupt_threshold() -> float:
	if not is_interruptible_now():
		return 0.0
	return float(current_attack().get("interruptible", {}).get("threshold", 0.0))
