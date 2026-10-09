class_name HunterStep
extends RefCounted

## A máquina de estados do Caçador: andar, correr, rolar, golpear, carregar,
## ser puxado pelo Gancho, girar no Especial — e o Fôlego que paga por tudo.
##
## Mora fora da Sim de propósito. O Cliente precisa rodar exatamente estas
## regras para prever o próprio movimento e reconciliar com o Instantâneo; se
## houvesse duas cópias delas, elas divergiriam e o Caçador local ficaria dando
## solavancos. Por isso ela recebe o estado e o altera, em vez de ter estado
## próprio.
##
## O que *não* mora aqui: quem o Golpe acerta e quanto dano causa. Isso é
## Combat, e só o Anfitrião resolve. O Cliente prevê o seu movimento, nunca o
## seu dano.
##
## `world` é o pouco que o Caçador enxerga do mundo (posição do Behemoth, para
## o Gancho). Só o Anfitrião o fornece; a predição do Cliente passa vazio e o
## início do Gancho simplesmente não é previsto — o Instantâneo corrige em um
## ou dois quadros, e o PUXÃO em si (que já tem alvo fixado) é previsto normal.

static func step(hunter: HunterState, input: HunterInput, dt: float, world: Dictionary = {}) -> void:
	var previous_pos := hunter.pos
	hunter.state_time += dt
	hunter.hurt_iframes = maxf(0.0, hunter.hurt_iframes - dt)
	hunter.invulnerable = hunter.hurt_iframes > 0.0
	hunter.valor_time = maxf(0.0, hunter.valor_time - dt)
	hunter.spin_strike = false

	# As Aflições rodam no passo compartilhado para a predição do Cliente
	# sentir a mesma lentidão e o mesmo dreno que a Sim do Anfitrião.
	Afflictions.step(hunter, dt)
	if hunter.hp <= 0.0 and hunter.state != HunterState.State.DOWNED:
		# A Queimadura também derruba, pelo mesmo caminho do dano comum.
		_enter(hunter, HunterState.State.DOWNED)
		hunter.combo_grace = 0.0
		hunter.combo_next = 0

	# O empurrão escorrega e some, qualquer que seja o estado. Levar um tranco
	# no meio de um Golpe desloca o Caçador sem interromper o Golpe.
	if hunter.knockback != Vector2.ZERO:
		hunter.pos += hunter.knockback * dt
		hunter.knockback = hunter.knockback.lerp(Vector2.ZERO, minf(1.0, SimConfig.KNOCKBACK_DECAY * dt))
		if hunter.knockback.length() < 4.0:
			hunter.knockback = Vector2.ZERO

	match hunter.state:
		HunterState.State.DOWNED:
			_step_downed(hunter)
		HunterState.State.HURT:
			_step_hurt(hunter)
		HunterState.State.DODGE:
			_step_dodge(hunter, dt)
		HunterState.State.ATTACK:
			_step_attack(hunter, input, dt)
		HunterState.State.CHARGING:
			_step_charging(hunter, input, dt)
		HunterState.State.RELOADING:
			_step_reloading(hunter, input)
		HunterState.State.HOOK_PULL:
			_step_hook(hunter, dt)
		HunterState.State.SPECIAL_SPIN:
			_step_spin(hunter, input, dt)
		_:
			# A mira só é livre fora de um Golpe: uma vez que o Golpe começa, a
			# direção está comprometida junto com o resto.
			hunter.facing = input.aim
			_tick_combo_grace(hunter, dt)
			_step_free(hunter, input, dt, world)

	_regenerate_stamina(hunter, dt)
	_keep_inside_arena(hunter)
	_keep_outside_behemoth(hunter, world)
	hunter.velocity = (hunter.pos - previous_pos) / dt if dt > 0.0 else Vector2.ZERO


## Movimento livre ---------------------------------------------------------

static func _step_free(hunter: HunterState, input: HunterInput, dt: float, world: Dictionary) -> void:
	var direction := input.move.limit_length(1.0)

	# A Esquiva tem prioridade sobre o Golpe: quem aperta os dois no mesmo
	# quadro está tentando escapar, não atacar. O Enraizamento a tranca.
	if input.dodge and hunter.stamina >= SimConfig.DODGE_COST and Afflictions.can_dodge(hunter):
		_begin_dodge(hunter, direction)
		return

	if input.special and _begin_special(hunter):
		return

	# Recarga do Martelo: só quando falta munição; nas outras armas, R é mudo.
	if input.reload and hunter.weapon_id == Weapons.HAMMER \
			and hunter.ammo < SimConfig.HAMMER_MAX_AMMO:
		hunter.reload_failed = false
		_enter(hunter, HunterState.State.RELOADING)
		return

	if input.light and _begin_attack(hunter, Weapons.Kind.LIGHT):
		return
	if input.heavy and _begin_heavy(hunter, world):
		return

	var speed := SimConfig.HUNTER_WALK_SPEED
	if _can_sprint(hunter, input, direction):
		speed = SimConfig.HUNTER_SPRINT_SPEED
		_spend(hunter, SimConfig.SPRINT_DRAIN_PER_SECOND * dt)

	# O Congelamento deixa tudo mais lento; o Valor, mais rápido.
	hunter.pos += direction * speed * Afflictions.speed_multiplier(hunter) * _valor_speed(hunter) * dt


static func _can_sprint(hunter: HunterState, input: HunterInput, direction: Vector2) -> bool:
	# Correr parado não faz sentido, e sem Fôlego suficiente não acontece: é o
	# que torna correr uma decisão em vez de um estado padrão.
	return input.sprint and direction != Vector2.ZERO and hunter.stamina >= SimConfig.SPRINT_MIN_STAMINA


## O botão pesado se desdobra por arma e por distância: Martelo arma a Rajada
## (ou o finalizador, vindo do terceiro leve), Lâminas colam o Golpe de
## Corrente ou lançam o Gancho, o resto ataca direto.
static func _begin_heavy(hunter: HunterState, world: Dictionary) -> bool:
	var move := Weapons.move(hunter.weapon_id, Weapons.Kind.HEAVY, 0)

	if move.get("hook", false):
		# Colado no Behemoth o Gancho não faz sentido: vira o Golpe de
		# Corrente, que gasta os pips de Momentum.
		if world.get("has_behemoth", false):
			var edge := ((world["behemoth_pos"] as Vector2) - hunter.pos).length() \
				- float(world["behemoth_radius"])
			if edge <= SimConfig.CHAIN_SLAM_RANGE:
				return _begin_chain_slam(hunter)
		return _begin_hook(hunter, move, world)

	if move.get("concussive", false):
		# Terceiro leve ainda na Janela de Combo + pesado = o finalizador que
		# descarrega todas as munições.
		if hunter.combo_grace > 0.0 and hunter.combo_next >= 3 and hunter.ammo > 0:
			return _begin_hammer_finisher(hunter)
		return _begin_concussive_hold(hunter, move)

	return _begin_attack(hunter, Weapons.Kind.HEAVY)


## Martelo: segurar o pesado arma a Rajada. Entrar já engole 1 munição; sem
## munição, sai a Coronhada fraca.
static func _begin_concussive_hold(hunter: HunterState, move: Dictionary) -> bool:
	if hunter.ammo <= 0:
		return _begin_attack(hunter, Weapons.Kind.HEAVY, 1)
	if hunter.stamina < SimConfig.DODGE_COST * 0.4:
		return false
	_spend(hunter, SimConfig.DODGE_COST * 0.4)
	hunter.ammo -= 1
	hunter.blast_ammo = 1
	hunter.attack_dir = Vector2.RIGHT.rotated(hunter.facing)
	_enter(hunter, HunterState.State.CHARGING)
	return true


## O finalizador clássico: todas as munições restantes num estouro no chão.
## Não recarrega sozinho — a conta chega no R.
static func _begin_hammer_finisher(hunter: HunterState) -> bool:
	var shots := hunter.ammo
	if not _begin_attack(hunter, Weapons.Kind.HEAVY, 2):
		return false
	hunter.blast_ammo = shots
	hunter.ammo = 0
	return true


## Lâminas coladas: o Golpe de Corrente trava e gasta todos os pips.
static func _begin_chain_slam(hunter: HunterState) -> bool:
	var pips := hunter.pips
	if not _begin_attack(hunter, Weapons.Kind.HEAVY, 1):
		return false
	hunter.slam_pips = pips
	hunter.pips = 0
	hunter.momentum = 0.0
	return true


## Rolamento ---------------------------------------------------------------

static func _step_dodge(hunter: HunterState, dt: float) -> void:
	# Impulso, depois recuperação. A Entrada de movimento não é lida em
	# nenhuma das duas: uma vez que o rolamento começa, ele vai até o fim.
	if hunter.state_time < SimConfig.DODGE_DURATION:
		hunter.pos += hunter.dodge_dir * SimConfig.DODGE_SPEED * dt
		hunter.invulnerable = hunter.invulnerable or hunter.state_time < SimConfig.DODGE_IFRAMES_END
		return

	if hunter.state_time >= SimConfig.DODGE_DURATION + SimConfig.DODGE_RECOVERY:
		_enter(hunter, HunterState.State.FREE)


static func _begin_dodge(hunter: HunterState, direction: Vector2) -> void:
	# Sem direção de movimento, rola para onde está mirando.
	hunter.dodge_dir = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT.rotated(hunter.facing)
	_spend(hunter, SimConfig.DODGE_COST)
	_enter(hunter, HunterState.State.DODGE)
	hunter.invulnerable = true


## Golpes ------------------------------------------------------------------

static func _step_attack(hunter: HunterState, input: HunterInput, _dt: float) -> void:
	var move := hunter.current_move()

	# O próximo Golpe pode ser pedido a qualquer momento e fica guardado. É o
	# que faz o Combo responder sem exigir precisão de milissegundo — mas o
	# Golpe atual continua indo até o fim de qualquer jeito.
	if input.light:
		hunter.buffered = HunterState.Buffered.LIGHT
	elif input.heavy:
		hunter.buffered = HunterState.Buffered.HEAVY

	# Golpes comuns não locomovem. Gancho, esquiva e empurrão têm regras próprias.

	if hunter.state_time < Weapons.duration(move):
		return

	_finish_attack(hunter, move)


static func _finish_attack(hunter: HunterState, move: Dictionary) -> void:
	var buffered := hunter.buffered
	hunter.buffered = HunterState.Buffered.NONE

	# A escala da Rajada e do Corrente vale só para o Golpe em que foi travada.
	hunter.blast_ammo = 0
	hunter.slam_pips = 0

	# Terceiro leve do Martelo com o pesado guardado = finalizador.
	if buffered == HunterState.Buffered.HEAVY and hunter.weapon_id == Weapons.HAMMER \
			and hunter.attack_kind == int(Weapons.Kind.LIGHT) and hunter.attack_index == 2 \
			and hunter.ammo > 0:
		hunter.combo_grace = float(move["combo_window"])
		if _begin_hammer_finisher(hunter):
			return

	# A Janela de Combo começa a correr no fim do Golpe. Quem já pediu o
	# próximo encadeia na hora; quem ainda não pediu tem essa janela para
	# pedir, e depois dela a sequência volta ao primeiro Golpe.
	hunter.combo_grace = float(move["combo_window"])

	if buffered != HunterState.Buffered.NONE:
		# Pesado guardado sai na versão rápida: nem Gancho (precisa de mundo)
		# nem Rajada (precisa segurar) — encadear é o caminho rápido.
		var kind := Weapons.Kind.LIGHT if buffered == HunterState.Buffered.LIGHT else Weapons.Kind.HEAVY
		var next_move := Weapons.move(hunter.weapon_id, kind, 0)
		if next_move.get("hook", false):
			pass
		elif next_move.get("concussive", false):
			if _begin_attack(hunter, kind, 1):
				return
		elif _begin_attack(hunter, kind):
			return

	_enter(hunter, HunterState.State.FREE)


## A Janela de Combo só corre fora de um Golpe. Expirada, o próximo Golpe leve
## recomeça a sequência.
static func _tick_combo_grace(hunter: HunterState, dt: float) -> void:
	if hunter.combo_grace <= 0.0:
		return
	hunter.combo_grace = maxf(0.0, hunter.combo_grace - dt)
	if hunter.combo_grace == 0.0:
		hunter.combo_next = 0


## Começa um Golpe. Devolve falso quando não há Fôlego, para quem chamou poder
## seguir com o movimento normal em vez de travar o Caçador. `forced_index`
## escolhe um Golpe específico (Coronhada, Corrente, Estouro); -1 deixa a
## lógica de Combo decidir.
static func _begin_attack(hunter: HunterState, kind: Weapons.Kind, forced_index: int = -1) -> bool:
	var list := Weapons.moves(hunter.weapon_id, kind)

	# Dentro da janela, a sequência do mesmo tipo continua. Alternar entre
	# leve e pesado reinicia; combos mistos ainda não estão implementados.
	var index := 0
	if forced_index >= 0:
		index = mini(forced_index, list.size() - 1)
	elif hunter.combo_grace > 0.0 and hunter.attack_kind == int(kind):
		index = hunter.combo_next % list.size()

	var move: Dictionary = list[index]
	# O Gancho nunca passa por aqui: ele não é um Golpe.
	if move.get("hook", false):
		return false
	if hunter.stamina < float(move["stamina"]):
		return false

	hunter.attack_kind = int(kind)
	hunter.attack_index = index
	hunter.attack_dir = Vector2.RIGHT.rotated(hunter.facing)
	hunter.hit_ids.clear()
	hunter.buffered = HunterState.Buffered.NONE
	hunter.combo_next = index + 1 if float(move["combo_window"]) > 0.0 else 0
	hunter.combo_grace = 0.0
	_spend(hunter, float(move["stamina"]))
	_enter(hunter, HunterState.State.ATTACK)
	return true


## Rajada e recarga do Martelo ------------------------------------------------

static func _step_charging(hunter: HunterState, input: HunterInput, dt: float) -> void:
	# A mira segue livre: você escolhe onde a Rajada sai até o último
	# instante. O corpo, não: armar prende no lugar.
	hunter.facing = input.aim

	# Cada segundo segurando engole mais uma munição e engrossa a Rajada.
	if hunter.state_time >= float(hunter.blast_ammo) * SimConfig.HAMMER_HOLD_PER_AMMO \
			and hunter.ammo > 0 and hunter.blast_ammo < SimConfig.HAMMER_MAX_AMMO:
		hunter.ammo -= 1
		hunter.blast_ammo += 1

	# Soltar dispara a Rajada com as munições engolidas (a escala é aplicada
	# pela Sim na resolução, via blast_ammo).
	if not input.heavy_held:
		if not _begin_attack(hunter, Weapons.Kind.HEAVY, 0):
			_enter(hunter, HunterState.State.FREE)


## R de novo dentro da janela encurta a recarga para agora; fora dela, trava o
## tempo cheio e mais um pouco. Não dá para andar nem cancelar: recarregar na
## hora errada é a punição clássica do Martelo.
static func _step_reloading(hunter: HunterState, input: HunterInput) -> void:
	var total := SimConfig.RELOAD_TIME \
		+ (SimConfig.RELOAD_FAIL_EXTRA if hunter.reload_failed else 0.0)

	if input.reload and not hunter.reload_failed:
		if hunter.state_time >= SimConfig.RELOAD_QUICK_START \
				and hunter.state_time <= SimConfig.RELOAD_QUICK_END:
			hunter.ammo = SimConfig.HAMMER_MAX_AMMO
			_enter(hunter, HunterState.State.FREE)
			return
		hunter.reload_failed = true

	if hunter.state_time >= total:
		hunter.ammo = SimConfig.HAMMER_MAX_AMMO
		hunter.reload_failed = false
		_enter(hunter, HunterState.State.FREE)


## Gancho das Lâminas --------------------------------------------------------

## O início do Gancho precisa saber onde o Behemoth está — só o Anfitrião
## sabe. Errar o Gancho não puxa e não custa nada.
static func _begin_hook(hunter: HunterState, move: Dictionary, world: Dictionary) -> bool:
	if not world.get("has_behemoth", false):
		return false

	var target: Vector2 = world["behemoth_pos"]
	var target_radius: float = world["behemoth_radius"]
	var to_target := target - hunter.pos

	if to_target.length() > float(move["range"]) + target_radius:
		return false
	if absf(angle_difference(hunter.facing, to_target.angle())) > float(move["arc"]):
		return false

	# Puxa até rente ao corpo, não até o centro.
	var stop := target_radius + SimConfig.HUNTER_RADIUS + SimConfig.HOOK_ARRIVE_GAP
	hunter.hook_target = target - to_target.normalized() * stop
	hunter.facing = to_target.angle()
	_enter(hunter, HunterState.State.HOOK_PULL)
	return true


static func _step_hook(hunter: HunterState, dt: float) -> void:
	var to_target := hunter.hook_target - hunter.pos
	var step_len := SimConfig.HOOK_PULL_SPEED * dt
	if to_target.length() <= step_len:
		hunter.pos = hunter.hook_target
		_enter(hunter, HunterState.State.FREE)
		return
	hunter.pos += to_target.normalized() * step_len


## Especiais ------------------------------------------------------------------

## Dispara o Especial da arma. Exige o Éter cheio e consome tudo.
static func _begin_special(hunter: HunterState) -> bool:
	if hunter.aether < SimConfig.AETHER_MAX:
		return false
	var special := Weapons.special(hunter.weapon_id)
	if special.is_empty():
		return false

	hunter.aether = 0.0
	hunter.special_fired = true
	match String(special["type"]):
		"valor":
			hunter.valor_time = float(special["duration"])
		"magma":
			# O projétil vive na Sim; aqui só fica o pedido de um Tique.
			hunter.wants_projectile = true
		"reaper":
			hunter.spin_tick = 0.0
			_enter(hunter, HunterState.State.SPECIAL_SPIN)
	return true


static func _step_spin(hunter: HunterState, input: HunterInput, dt: float) -> void:
	var special := Weapons.special(hunter.weapon_id)
	hunter.facing = input.aim

	# Dá para deslizar devagar durante o giro, para perseguir o alvo.
	var direction := input.move.limit_length(1.0)
	hunter.pos += direction * SimConfig.HUNTER_WALK_SPEED * SimConfig.SPIN_MOVE_FRACTION \
		* Afflictions.speed_multiplier(hunter) * dt

	# O relógio dos acertos: a Sim resolve o dano quando `spin_strike` acende.
	hunter.spin_tick += dt
	var interval := float(special.get("tick", 0.3))
	if hunter.spin_tick >= interval:
		hunter.spin_tick -= interval
		hunter.spin_strike = true

	if hunter.state_time >= float(special.get("duration", 2.5)):
		_enter(hunter, HunterState.State.FREE)


## O multiplicador de dano dos buffs ativos (hoje, só o Valor), último na
## ordem do cálculo da spec.
static func buff_multiplier(hunter: HunterState) -> float:
	if hunter.valor_time > 0.0:
		return float(Weapons.special(hunter.weapon_id).get("damage_mult", 1.0))
	return 1.0


static func _valor_speed(hunter: HunterState) -> float:
	if hunter.valor_time <= 0.0:
		return 1.0
	return float(Weapons.special(hunter.weapon_id).get("speed_mult", 1.0))


## Dano sofrido ------------------------------------------------------------

## Aplica um ataque do Behemoth. Devolve falso quando não houve dano — por
## Invulnerabilidade ou por já estar Abatido — para quem chamou não anunciar
## um acerto que não aconteceu.
static func take_hit(hunter: HunterState, amount: float, from: Vector2, knockback: float) -> bool:
	if hunter.invulnerable or hunter.state == HunterState.State.DOWNED:
		return false

	hunter.hp = maxf(0.0, hunter.hp - amount)
	hunter.hurt_iframes = SimConfig.HURT_IFRAMES

	var away := hunter.pos - from
	hunter.knockback = (away.normalized() if away.length() > 0.001 else Vector2.RIGHT) * knockback

	if hunter.hp <= 0.0:
		_enter(hunter, HunterState.State.DOWNED)
		hunter.combo_grace = 0.0
		hunter.combo_next = 0
	else:
		_enter(hunter, HunterState.State.HURT)
	return true


static func _step_hurt(hunter: HunterState) -> void:
	if hunter.state_time >= SimConfig.HURT_DURATION:
		_enter(hunter, HunterState.State.FREE)


## Levantar sozinho é provisório: o ticket 09 troca isto por Fichas de
## Reviver, companheiro levantando e derrota de verdade.
static func _step_downed(hunter: HunterState) -> void:
	if hunter.state_time < SimConfig.DOWNED_DURATION:
		return
	hunter.hp = SimConfig.HUNTER_MAX_HP * SimConfig.DOWNED_REVIVE_FRACTION
	hunter.stamina = SimConfig.STAMINA_MAX
	hunter.hurt_iframes = SimConfig.HURT_IFRAMES * 2.0
	_enter(hunter, HunterState.State.FREE)


## Fôlego ------------------------------------------------------------------

static func _spend(hunter: HunterState, amount: float) -> void:
	# Golpes gratuitos não adiam a regeneração iniciada após corrida/esquiva.
	if amount <= 0.0:
		return
	hunter.stamina = maxf(0.0, hunter.stamina - amount)
	hunter.regen_delay = SimConfig.STAMINA_REGEN_DELAY


static func _regenerate_stamina(hunter: HunterState, dt: float) -> void:
	if hunter.regen_delay > 0.0:
		hunter.regen_delay = maxf(0.0, hunter.regen_delay - dt)
		return
	hunter.stamina = minf(SimConfig.STAMINA_MAX, hunter.stamina + SimConfig.STAMINA_REGEN_PER_SECOND * dt)


## Arena -------------------------------------------------------------------

static func _keep_inside_arena(hunter: HunterState) -> void:
	# Em vez de bloquear o movimento, o Caçador é empurrado de volta para a
	# borda, para que andar contra a parede deslize em vez de travar.
	var limit := SimConfig.hunter_limit()
	if hunter.pos.length() > limit:
		hunter.pos = hunter.pos.normalized() * limit


## A colisão do corpo é uma regra da Sim, não da cena 3D. Assim o caçador não
## entra no Behemoth ao andar, atacar, rolar ou ser puxado pelo Gancho.
## É pública porque a Sim também a reaplica depois que o Behemoth se move.
static func keep_outside_behemoth(hunter: HunterState, world: Dictionary) -> void:
	_keep_outside_behemoth(hunter, world)


static func _keep_outside_behemoth(hunter: HunterState, world: Dictionary) -> void:
	if not world.get("has_behemoth", false):
		return
	var center: Vector2 = world["behemoth_pos"]
	var minimum := float(world["behemoth_radius"]) + SimConfig.HUNTER_RADIUS
	var offset := hunter.pos - center
	if offset.length_squared() >= minimum * minimum:
		return

	# Centros exatamente sobrepostos não têm normal. A orientação do caçador é
	# estável, funciona também na predição e evita teleporte aleatório.
	var normal := offset.normalized() if offset.length_squared() > 0.0001 else Vector2.RIGHT.rotated(hunter.facing)
	hunter.pos = center + normal * minimum


static func _enter(hunter: HunterState, state: HunterState.State) -> void:
	hunter.state = state
	hunter.state_time = 0.0
