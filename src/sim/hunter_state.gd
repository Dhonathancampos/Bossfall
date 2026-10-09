class_name HunterState
extends RefCounted

## O estado de um Caçador dentro da Simulação.
##
## Tudo que o movimento e os Golpes precisam está aqui, e tudo isso vai no
## Instantâneo: o Cliente copia este estado e repete as Entradas pendentes por
## cima para prever o próprio movimento. Se algum campo ficasse de fora, a
## predição divergiria e o Caçador local daria solavancos.

enum State {
	## Andando, correndo ou parado: o Caçador manda no próprio movimento.
	FREE,
	## Rolando. A Entrada de movimento é ignorada até o rolamento acabar.
	DODGE,
	## Golpeando. Nem movimento nem Esquiva cancelam.
	ATTACK,
	## Armando a Rajada Concussiva (Martelo): cada segundo segurando engole
	## mais uma munição. Preso no lugar até soltar.
	CHARGING,
	## Sendo puxado pelo Gancho das Lâminas até o Behemoth.
	HOOK_PULL,
	## Dança da Ceifadora: girando e acertando tudo em volta, por tempo fixo.
	SPECIAL_SPIN,
	## Levou dano: escorregando para longe, sem controle, por um instante.
	HURT,
	## Vida zerada. Imóvel até levantar.
	DOWNED,
	## Recarregando o Martelo. R de novo na janela certa encurta; na errada,
	## trava mais tempo. (No fim do enum para não mudar os valores antigos.)
	RELOADING,
}

enum Buffered { NONE, LIGHT, HEAVY }

var id: int = 0
var display_name: String = ""
var weapon_id: String = Weapons.SWORD
var element: Elements.Element = Elements.Element.NEUTRAL

## Posição no plano de chão. Na Onda 2 isto vira (x, z) num mundo 3D.
var pos: Vector2 = Vector2.ZERO
## Velocidade do tique, não estimada por quadros de renderização.
var velocity: Vector2 = Vector2.ZERO

## Direção que o Caçador aponta, em radianos.
var facing: float = 0.0

var hp: float = SimConfig.HUNTER_MAX_HP
var stamina: float = SimConfig.STAMINA_MAX
var aether: float = 0.0

## Velocidade residual do empurrão. Decai sozinha.
var knockback: Vector2 = Vector2.ZERO

## Invulnerabilidade por ter levado dano, separada da do rolamento.
var hurt_iframes: float = 0.0

var state: State = State.FREE

## Há quanto tempo o Caçador está no estado atual.
var state_time: float = 0.0

## Direção travada no começo do rolamento. Uma vez rolando, mudar a Entrada
## não muda para onde o rolamento vai.
var dodge_dir: Vector2 = Vector2.RIGHT

## Quanto falta para o Fôlego voltar a regenerar.
var regen_delay: float = 0.0

## Verdadeiro durante os quadros Invulneráveis do rolamento.
var invulnerable: bool = false

## Golpe em andamento.
var attack_kind: int = int(Weapons.Kind.LIGHT)
var attack_index: int = 0

## Direção da área de acerto, travada no começo do Golpe.
var attack_dir: Vector2 = Vector2.RIGHT

## Quem este Golpe já acertou. Um Golpe acerta cada alvo no máximo uma vez.
var hit_ids: Array[int] = []

## Próximo Golpe pedido durante o atual. Guardar o pedido é o que faz o Combo
## responder sem exigir precisão de milissegundo.
var buffered: Buffered = Buffered.NONE

## Índice do próximo Golpe do mesmo tipo, se o Combo continuar.
var combo_next: int = 0

## Quanto tempo ainda dá para continuar o Combo. Zera e a sequência volta ao
## primeiro Golpe.
var combo_grace: float = 0.0

## Aflições: acúmulo por Elemento e tempo restante das ativas.
## {Elements.Element (int) -> float}
var affliction_buildup: Dictionary = {}
var afflictions: Dictionary = {}

## Martelo clássico: munições na arma, quantas a Rajada em preparo já engoliu,
## e se a recarga em andamento falhou (trava mais tempo).
var ammo: int = SimConfig.HAMMER_MAX_AMMO
var blast_ammo: int = 0
var reload_failed: bool = false

## Lâminas: o medidor de Momentum e os pips prontos para o Golpe de Corrente.
var momentum: float = 0.0
var pips: int = 0

## Pips travados no Golpe de Corrente em andamento (a escala dele).
var slam_pips: int = 0

## Tempo restante do Valor (Especial da Espada). Zero = sem buff.
var valor_time: float = 0.0

## Para onde o Gancho puxa. Fixado no início do puxão.
var hook_target: Vector2 = Vector2.ZERO

## Relógio interno da Dança da Ceifadora: acumula até o próximo tick de acerto.
var spin_tick: float = 0.0

## Flags de um Tique consumidas pela Sim (nunca viajam no Instantâneo):
## o giro acertou neste Tique / o Especial pediu um projétil.
var spin_strike: bool = false
var wants_projectile: bool = false

## O Especial disparou neste Tique (a Sim anuncia o evento e apaga).
var special_fired: bool = false

## A última sequência de Entrada que a Sim aplicou a este Caçador.
var last_input_seq: int = 0


func has_affliction(element_kind: Elements.Element) -> bool:
	return float(afflictions.get(int(element_kind), 0.0)) > 0.0


## O Golpe que está rolando agora.
func current_move() -> Dictionary:
	return Weapons.move(weapon_id, attack_kind as Weapons.Kind, attack_index)


## Verdadeiro só durante a fase Ativa, a única que acerta alguma coisa.
func is_attack_active() -> bool:
	if state != State.ATTACK:
		return false
	var move := current_move()
	var windup := float(move["windup"])
	return state_time > windup and state_time <= windup + float(move["active"])


## O estado completo. Só o dono do Caçador precisa disto: é o que a predição
## do Cliente usa como ponto de partida para repetir as Entradas pendentes.
##
## Nome e arma ficam de fora de propósito: são estáticos e viajam uma vez na
## lista de Caçadores, não 30 vezes por segundo dentro do Instantâneo.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"pos": pos,
		"velocity": velocity,
		"facing": facing,
		"hp": hp,
		"knockback": knockback,
		"hurt_iframes": hurt_iframes,
		"stamina": stamina,
		"aether": aether,
		"state": int(state),
		"state_time": state_time,
		"dodge_dir": dodge_dir,
		"regen_delay": regen_delay,
		"invulnerable": invulnerable,
		"attack_kind": attack_kind,
		"attack_index": attack_index,
		"attack_dir": attack_dir,
		"buffered": int(buffered),
		"combo_next": combo_next,
		"combo_grace": combo_grace,
		"afflictions": afflictions.duplicate(),
		"ammo": ammo,
		"blast_ammo": blast_ammo,
		"reload_failed": reload_failed,
		"momentum": momentum,
		"pips": pips,
		"slam_pips": slam_pips,
		"valor_time": valor_time,
		"hook_target": hook_target,
		"spin_tick": spin_tick,
		"seq": last_input_seq,
	}


## O mínimo para desenhar outro Caçador: onde está, para onde aponta, e em que
## fase do Golpe ou do rolamento está. Sem isto, o Instantâneo com 4 Caçadores
## passava do MTU e começava a perder pacote.
func to_view_dict() -> Dictionary:
	return {
		"id": id,
		"pos": pos,
		"velocity": velocity,
		"facing": facing,
		"hp": hp,
		"state": int(state),
		"state_time": state_time,
		"dodge_dir": dodge_dir,
		"invulnerable": invulnerable,
		"attack_kind": attack_kind,
		"attack_index": attack_index,
		"attack_dir": attack_dir,
	}


## Sobrescreve este estado com o que veio no Instantâneo. É o ponto de partida
## da predição do Cliente a cada Instantâneo recebido.
##
## `hit_ids` fica de fora de propósito: quem o Golpe acertou é decisão do
## Anfitrião, e o Cliente não prevê dano nenhum.
func apply_dict(data: Dictionary) -> void:
	id = data.get("id", id)
	pos = data.get("pos", pos)
	velocity = data.get("velocity", Vector2.ZERO)
	facing = data.get("facing", facing)
	hp = data.get("hp", hp)
	knockback = data.get("knockback", knockback)
	hurt_iframes = data.get("hurt_iframes", hurt_iframes)
	stamina = data.get("stamina", stamina)
	aether = data.get("aether", aether)
	state = data.get("state", int(state)) as State
	state_time = data.get("state_time", state_time)
	dodge_dir = data.get("dodge_dir", dodge_dir)
	regen_delay = data.get("regen_delay", regen_delay)
	invulnerable = data.get("invulnerable", invulnerable)
	attack_kind = data.get("attack_kind", attack_kind)
	attack_index = data.get("attack_index", attack_index)
	attack_dir = data.get("attack_dir", attack_dir)
	buffered = data.get("buffered", int(buffered)) as Buffered
	combo_next = data.get("combo_next", combo_next)
	combo_grace = data.get("combo_grace", combo_grace)
	afflictions = data.get("afflictions", afflictions)
	ammo = data.get("ammo", ammo)
	blast_ammo = data.get("blast_ammo", blast_ammo)
	reload_failed = data.get("reload_failed", reload_failed)
	momentum = data.get("momentum", momentum)
	pips = data.get("pips", pips)
	slam_pips = data.get("slam_pips", slam_pips)
	valor_time = data.get("valor_time", valor_time)
	hook_target = data.get("hook_target", hook_target)
	spin_tick = data.get("spin_tick", spin_tick)
	last_input_seq = data.get("seq", last_input_seq)
