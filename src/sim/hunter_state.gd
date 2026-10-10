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
	## Segurando um Golpe carregável do Machado no Preparo: mira livre, corpo
	## preso, vigor drenando. (No FIM do enum — os ints viajam no Instantâneo;
	## aviso do REVIEW de 09/10 que não queremos repetir.)
	AXE_CHARGE,
	## Rolinho das Repetidoras: dash lateral curto com Invulnerabilidade
	## parcial. (Também no FIM, depois de AXE_CHARGE.)
	TUMBLE,
}

## Os pedidos que ficam guardados durante um Golpe. `light_hold`/`heavy_hold`
## entram como variantes porque o grafo distingue toque de segurada.
enum Buffered { NONE, LIGHT, HEAVY, LIGHT_HOLD, HEAVY_HOLD, RELOAD }

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

## De qual NÓ do grafo de combo o Caçador acabou de sair, no formato achatado
## de `Weapons.flat_id`. -1 = nenhum: a próxima Entrada entra pelo `entry` da
## arma. Estar no nó `l2` já É ter vindo de L,L — não há histórico guardado.
var combo_from: int = -1

## Quanto tempo ainda dá para continuar o Combo. Zera e a sequência volta ao
## começo do grafo. Só corre fora de um Golpe (fica congelada durante o
## Gancho e a carga da Rajada — é o que os deixa encaixar no meio do combo).
var combo_grace: float = 0.0

## A transição-efeito (recarga encaixada do Martelo) já foi usada neste nó.
## Sem isso, dava para farmar munição apertando R dentro da mesma janela.
var combo_effect_used: bool = false

## Espada: Brio. Pips ganhos fechando cadeias, gastos nos Golpes de desvio.
var brio: int = 0

## Janela do contexto `dodge` do grafo: corre depois do fim de um rolamento
## (ou de um Rolinho) e é o que faz o "golpe pós-esquiva" existir.
var dodge_window: float = 0.0

## Nós de canal (Roda Viva, Ceifa Contínua, Broca): há quanto tempo o canal
## se sustenta, e quantos pulsos já saíram (a Ceifa acelera por pulso).
var channel_time: float = 0.0
var channel_hits: int = 0

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

## Relógio de pulsos: a Dança da Ceifadora e os Golpes multi-hit/canal
## acumulam aqui até o próximo tick de acerto. Os estados são exclusivos,
## então um relógio só serve aos dois.
var spin_tick: float = 0.0

## Machado: a carga em andamento, a carga travada no Golpe que saiu, e qual
## botão está carregando.
var charge_time: float = 0.0
var charge_locked: float = 0.0
var charge_kind: int = int(Weapons.Kind.LIGHT)

## Machado: o machado foi arremessado e ainda não voltou. Enquanto verdadeiro
## não há arma na mão (Golpes recusados); esquiva e movimento seguem livres.
var axe_out: bool = false

## Machado: pilhas de Determinação e o tempo restante da pilha corrente.
var det_stacks: int = 0
var det_time: float = 0.0

## Resolve (Machado): enquanto maior que zero, o Caçador apanha o dano mas
## não entra em HURT nem é empurrado. Super-armadura, não invulnerabilidade.
var resolve_time: float = 0.0

## Lança: nível (0..4) da munição convertida pela Conversão Aetérica.
var pike_ammo: int = 0

## Lança: tempo restante do buff pessoal ganho ao explorar uma Ferida.
var wound_buff_time: float = 0.0

## Repetidoras: pente, tiros empoderados restantes e a cadência.
var mag: int = SimConfig.REPEATER_MAG
var empowered_shots: int = 0
var fire_cooldown: float = 0.0

## Placar da Caçada, por Caçador: alimenta a tela de RESULTADO do lobby.
var damage_dealt: float = 0.0
var parts_broken: int = 0
var interrupts: int = 0

## Lobby: o Caçador declarou que está pronto.
var ready: bool = false

## Flags de um Tique consumidas pela Sim (nunca viajam no Instantâneo):
## o giro/pulso acertou neste Tique, o pedido de projétil (por tipo), o tiro
## das Repetidoras e os dois pedidos do Voo da Ruína.
var spin_strike: bool = false
var pending_projectile: String = ""
var wants_shot: bool = false
var wants_axe_recall: bool = false
## A recarga das Repetidoras acabou de empoderar o pente (a Sim anuncia).
var just_empowered: bool = false

## O Especial disparou neste Tique (a Sim anuncia o evento e apaga).
var special_fired: bool = false

## A última sequência de Entrada que a Sim aplicou a este Caçador.
var last_input_seq: int = 0


func has_affliction(element_kind: Elements.Element) -> bool:
	return float(afflictions.get(int(element_kind), 0.0)) > 0.0


## O Golpe que está rolando agora.
func current_move() -> Dictionary:
	return Weapons.move(weapon_id, attack_kind as Weapons.Kind, attack_index)


## O nó do grafo de combo em que este Golpe está, ou "" quando o Golpe não é
## nó (Gancho, Rajada em carga, tiro, Rolinho).
func current_node() -> String:
	return Weapons.node_name(weapon_id, attack_kind as Weapons.Kind, attack_index)


## Verdadeiro só durante a fase Ativa, a única que acerta alguma coisa.
##
## Golpes de PULSO (multi-hit e canais) ficam de fora: o acerto deles sai do
## relógio de pulsos, não da fase. Ter os dois caminhos ligados faria o mesmo
## Golpe acertar duas vezes no mesmo Tique.
func is_attack_active() -> bool:
	if state != State.ATTACK:
		return false
	var move := current_move()
	if move.has("pulse_every"):
		return false
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
		"combo_from": combo_from,
		"combo_grace": combo_grace,
		"combo_effect_used": combo_effect_used,
		"brio": brio,
		"dodge_window": dodge_window,
		"channel_time": channel_time,
		"channel_hits": channel_hits,
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
		"charge_time": charge_time,
		"charge_locked": charge_locked,
		"charge_kind": charge_kind,
		"axe_out": axe_out,
		"det_stacks": det_stacks,
		"det_time": det_time,
		"resolve_time": resolve_time,
		"pike_ammo": pike_ammo,
		"wound_buff_time": wound_buff_time,
		"mag": mag,
		"empowered_shots": empowered_shots,
		"fire_cooldown": fire_cooldown,
		"damage_dealt": damage_dealt,
		"parts_broken": parts_broken,
		"interrupts": interrupts,
		"ready": ready,
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
		## Sem `axe_out` o remoto desenharia o machado na mão E o projétil.
		"axe_out": axe_out,
		## Aura de Determinação nos remotos: é um int, cabe no MTU.
		"det_stacks": det_stacks,
		## O lobby precisa do "pronto" de todo mundo, não só do dono.
		"ready": ready,
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
	combo_from = data.get("combo_from", combo_from)
	combo_grace = data.get("combo_grace", combo_grace)
	combo_effect_used = data.get("combo_effect_used", combo_effect_used)
	brio = data.get("brio", brio)
	dodge_window = data.get("dodge_window", dodge_window)
	channel_time = data.get("channel_time", channel_time)
	channel_hits = data.get("channel_hits", channel_hits)
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
	charge_time = data.get("charge_time", charge_time)
	charge_locked = data.get("charge_locked", charge_locked)
	charge_kind = data.get("charge_kind", charge_kind)
	axe_out = data.get("axe_out", axe_out)
	det_stacks = data.get("det_stacks", det_stacks)
	det_time = data.get("det_time", det_time)
	resolve_time = data.get("resolve_time", resolve_time)
	pike_ammo = data.get("pike_ammo", pike_ammo)
	wound_buff_time = data.get("wound_buff_time", wound_buff_time)
	mag = data.get("mag", mag)
	empowered_shots = data.get("empowered_shots", empowered_shots)
	fire_cooldown = data.get("fire_cooldown", fire_cooldown)
	damage_dealt = data.get("damage_dealt", damage_dealt)
	parts_broken = data.get("parts_broken", parts_broken)
	interrupts = data.get("interrupts", interrupts)
	ready = data.get("ready", ready)
	last_input_seq = data.get("seq", last_input_seq)
