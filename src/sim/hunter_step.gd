class_name HunterStep
extends RefCounted

## A máquina de estados do Caçador: andar, correr, rolar, golpear, carregar,
## canalizar, atirar, ser puxado pelo Gancho — e o Fôlego que paga por tudo.
##
## Mora fora da Sim de propósito. O Cliente precisa rodar exatamente estas
## regras para prever o próprio movimento e reconciliar com o Instantâneo; se
## houvesse duas cópias delas, elas divergiriam e o Caçador local ficaria dando
## solavancos. Por isso ela recebe o estado e o altera, em vez de ter estado
## próprio.
##
## ## O grafo de combo (ticket 14)
##
## Não existe mais "índice do próximo Golpe do mesmo tipo". Cada Golpe é um NÓ
## e declara as arestas que saem dele; a arma declara por onde se ENTRA, por
## contexto (`free`, `sprint`, `dodge`). Desviar de leve para pesado deixou de
## ser um RESET: é só uma aresta — e é exatamente o ponto do ticket. Toda a
## topologia mora em `weapons.gd`; esta máquina só interpreta o vocabulário.
##
## O que *não* mora aqui: quem o Golpe acerta e quanto dano causa. Isso é
## Combat, e só o Anfitrião resolve. O Cliente prevê o seu movimento, nunca o
## seu dano.
##
## `world` é o pouco que o Caçador enxerga do mundo (posição do Behemoth, para
## o Gancho e para os predicados `near`/`far`). Só o Anfitrião o fornece; a
## predição do Cliente passa vazio e essas transições simplesmente não são
## previstas — o Instantâneo corrige em um ou dois quadros.

static func step(hunter: HunterState, input: HunterInput, dt: float, world: Dictionary = {}) -> void:
	var previous_pos := hunter.pos
	hunter.state_time += dt
	hunter.hurt_iframes = maxf(0.0, hunter.hurt_iframes - dt)
	hunter.invulnerable = hunter.hurt_iframes > 0.0
	hunter.valor_time = maxf(0.0, hunter.valor_time - dt)
	hunter.resolve_time = maxf(0.0, hunter.resolve_time - dt)
	hunter.wound_buff_time = maxf(0.0, hunter.wound_buff_time - dt)
	hunter.dodge_window = maxf(0.0, hunter.dodge_window - dt)
	hunter.fire_cooldown = maxf(0.0, hunter.fire_cooldown - dt)
	_tick_determination(hunter, dt)

	# Flags de um Tique: nascem aqui zeradas e são consumidas pela Sim logo
	# depois do passo. Nunca viajam no Instantâneo.
	hunter.spin_strike = false
	hunter.pending_projectile = ""
	hunter.wants_shot = false
	hunter.wants_axe_recall = false
	hunter.just_empowered = false

	# As Aflições rodam no passo compartilhado para a predição do Cliente
	# sentir a mesma lentidão e o mesmo dreno que a Sim do Anfitrião.
	Afflictions.step(hunter, dt)
	if hunter.hp <= 0.0 and hunter.state != HunterState.State.DOWNED:
		# A Queimadura também derruba, pelo mesmo caminho do dano comum.
		_enter(hunter, HunterState.State.DOWNED)
		_break_combo(hunter)

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
		HunterState.State.TUMBLE:
			_step_tumble(hunter, dt)
		HunterState.State.ATTACK:
			_step_attack(hunter, input, dt, world)
		HunterState.State.CHARGING:
			_step_charging(hunter, input, dt)
		HunterState.State.AXE_CHARGE:
			_step_axe_charge(hunter, input, dt)
		HunterState.State.RELOADING:
			_step_reloading(hunter, input, world)
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

	var context := _context(hunter, input)

	# R tem dois caminhos: a recarga ENCAIXADA (transição-efeito do grafo, que
	# dá munição sem quebrar o combo) e, se ela não couber, a recarga de
	# verdade, que é um estado.
	if input.reload:
		var reloaded := _try_inputs(hunter, ["reload"], world, context)
		if reloaded == _ENTERED:
			return
		# A recarga encaixada JÁ resolveu o R: não cair também no estado de
		# recarga, senão o combo morria no mesmo toque que o alimentou.
		if reloaded == _NOTHING and _begin_reload(hunter):
			return

	if input.light and _try_inputs(hunter, _names_light(input), world, context) == _ENTERED:
		return
	if input.heavy and _try_inputs(hunter, _names_heavy(input), world, context) == _ENTERED:
		return

	var speed := SimConfig.HUNTER_WALK_SPEED
	var sprinting := _can_sprint(hunter, input, direction)
	if sprinting:
		speed = SimConfig.HUNTER_SPRINT_SPEED
		_spend(hunter, SimConfig.SPRINT_DRAIN_PER_SECOND * dt)
	else:
		# Tiro contínuo (Repetidoras): não tranca o movimento, mas a corrida
		# tem prioridade sobre ele — correr é o jeito de parar de atirar.
		_try_shot(hunter, input)

	# O Congelamento deixa tudo mais lento; o Valor, mais rápido.
	hunter.pos += direction * speed * Afflictions.speed_multiplier(hunter) * _valor_speed(hunter) * dt


static func _can_sprint(hunter: HunterState, input: HunterInput, direction: Vector2) -> bool:
	# Correr parado não faz sentido, e sem Fôlego suficiente não acontece: é o
	# que torna correr uma decisão em vez de um estado padrão.
	return input.sprint and direction != Vector2.ZERO and hunter.stamina >= SimConfig.SPRINT_MIN_STAMINA


## Grafo de combo ----------------------------------------------------------

## Resultados de uma tentativa de transição.
const _NOTHING: int = 0
## A transição era só efeito (recarga encaixada): o Caçador continua livre.
const _EFFECT: int = 1
## A transição trocou o estado (Golpe, Gancho, carga, Rolinho).
const _ENTERED: int = 2


## Em que contexto do grafo o Caçador está. Tudo derivado de estado já
## replicado — nada novo viaja no Instantâneo por causa disto.
static func _context(hunter: HunterState, input: HunterInput) -> String:
	if hunter.dodge_window > 0.0:
		return "dodge"
	if input.sprint and hunter.velocity.length() >= SimConfig.COMBO_SPRINT_SPEED_MIN:
		return "sprint"
	return "free"


static func _names_light(input: HunterInput) -> Array:
	return ["light_hold", "light"] if input.light_held else ["light"]


static func _names_heavy(input: HunterInput) -> Array:
	return ["heavy_hold", "heavy"] if input.heavy_held else ["heavy"]


## Tenta casar uma Entrada com o grafo: primeiro as arestas do nó de onde o
## Caçador veio (se a Janela de Combo ainda corre), depois a entrada do
## contexto, e por último a entrada livre.
static func _try_inputs(hunter: HunterState, names: Array, world: Dictionary, context: String) -> int:
	var graph := Weapons.combo_graph(hunter.weapon_id)
	var nodes: Dictionary = graph["nodes"]

	if hunter.combo_grace > 0.0 and hunter.combo_from >= 0:
		var from_id := Weapons.node_from_flat(hunter.weapon_id, hunter.combo_from)
		if nodes.has(from_id):
			var chained := _match(nodes[from_id].get("next", []), names, hunter, world)
			if not chained.is_empty():
				return _apply_transition(hunter, chained, world)

	var entry: Dictionary = graph["entry"]
	var contextual := _match(entry.get(context, []), names, hunter, world)
	if not contextual.is_empty():
		return _apply_transition(hunter, contextual, world)
	if context != "free":
		var free_entry := _match(entry.get("free", []), names, hunter, world)
		if not free_entry.is_empty():
			return _apply_transition(hunter, free_entry, world)
	return _NOTHING


## A primeira candidata cujo `input` casa e cujo `if` passa vence — como as
## cláusulas de um match. A ORDEM da lista é a prioridade.
static func _match(candidates: Array, names: Array, hunter: HunterState, world: Dictionary) -> Dictionary:
	for candidate in candidates:
		var entry: Dictionary = candidate
		if not names.has(String(entry.get("input", ""))):
			continue
		if not _predicate(hunter, String(entry.get("if", "")), world):
			continue
		return entry
	return {}


## Vocabulário fechado de predicados. Crescer esta lista é decisão de revisão,
## não de ficha de arma: predicado ad hoc por arma recria o problema que o
## grafo resolve.
static func _predicate(hunter: HunterState, rule: String, world: Dictionary) -> bool:
	if rule.is_empty():
		return true
	match rule:
		"near":
			return _body_edge(hunter, world) <= SimConfig.CHAIN_SLAM_RANGE
		"far":
			return world.get("has_behemoth", false) \
				and _body_edge(hunter, world) > SimConfig.CHAIN_SLAM_RANGE
		"back_dodge":
			# Esquiva para TRÁS: o rolamento foi contra a mira.
			return hunter.dodge_dir.dot(Vector2.RIGHT.rotated(hunter.facing)) < 0.0
		"no_world":
			return not world.get("has_behemoth", false)
		"ammo==0":
			return hunter.ammo == 0
	if rule.begins_with("brio>="):
		return hunter.brio >= int(rule.substr(6))
	if rule.begins_with("ammo>="):
		return hunter.ammo >= int(rule.substr(6))
	if rule.begins_with("pips>="):
		return hunter.pips >= int(rule.substr(6))
	if rule.begins_with("mag>="):
		return hunter.mag >= int(rule.substr(5))
	return false


## Distância do Caçador à BORDA do corpo do Behemoth. Sem mundo (predição do
## Cliente), infinito: nenhum predicado de distância resolve, e o Instantâneo
## corrige — o contrato que o Gancho já tinha.
static func _body_edge(hunter: HunterState, world: Dictionary) -> float:
	if not world.get("has_behemoth", false):
		return INF
	return ((world["behemoth_pos"] as Vector2) - hunter.pos).length() - float(world["behemoth_radius"])


static func _apply_transition(hunter: HunterState, transition: Dictionary, world: Dictionary) -> int:
	var destination := String(transition.get("to", ""))

	# Transição-EFEITO (a recarga encaixada do Martelo): dá o efeito, mantém o
	# nó e a janela correndo. Uma por nó — senão dava para farmar munição.
	if destination.is_empty():
		if hunter.combo_effect_used:
			return _NOTHING
		_apply_effects(hunter, transition.get("on_start", []))
		hunter.combo_effect_used = true
		return _EFFECT

	# `@algo` é ponte para um ESTADO: o grafo decide QUANDO, o estado decide
	# COMO. Pontes preservam `combo_from` (a janela fica congelada fora do
	# FREE), e é isso que faz Gancho e Rajada encaixarem no meio do combo.
	if destination.begins_with("@"):
		return _ENTERED if _enter_bridge(hunter, destination, world) else _NOTHING

	return _ENTERED if _begin_node(hunter, destination) else _NOTHING


static func _enter_bridge(hunter: HunterState, bridge: String, world: Dictionary) -> bool:
	match bridge:
		"@hook":
			return _begin_hook(hunter, Weapons.move(hunter.weapon_id, Weapons.Kind.HEAVY, 0), world)
		"@charging":
			return _begin_concussive_hold(hunter)
		"@tumble":
			return _begin_tumble(hunter)
	return false


## Começa o Golpe de um nó. Devolve falso quando falta Fôlego (ou quando o
## machado está fora), para quem chamou poder seguir com o movimento normal em
## vez de travar o Caçador.
static func _begin_node(hunter: HunterState, node_id: String) -> bool:
	var node := Weapons.node(hunter.weapon_id, node_id)
	if node.is_empty():
		return false
	# Sem arma na mão (Voo da Ruína no ar) não há Golpe: só esquiva e correria.
	if hunter.axe_out:
		return false

	var kind := int(node["kind"]) as Weapons.Kind
	var index := int(node["index"])
	var move := Weapons.move(hunter.weapon_id, kind, index)
	if hunter.stamina < float(move["stamina"]):
		return false

	_apply_effects(hunter, node.get("on_start", []))

	hunter.attack_kind = int(kind)
	hunter.attack_index = index
	hunter.attack_dir = Vector2.RIGHT.rotated(hunter.facing)
	hunter.hit_ids.clear()
	hunter.buffered = HunterState.Buffered.NONE
	hunter.combo_from = -1
	hunter.combo_grace = 0.0
	hunter.combo_effect_used = false
	hunter.channel_time = 0.0
	hunter.channel_hits = 0
	# Golpe de pulso começa com o relógio cheio: o primeiro pulso sai no
	# CONTATO, não um intervalo depois dele.
	hunter.spin_tick = float(move.get("pulse_every", 0.0))
	hunter.charge_locked = 0.0

	# Golpe carregável (Machado): o Preparo fica segurável. O vigor do Golpe
	# só é pago ao SOLTAR; a carga tem o dreno dela.
	if move.get("chargeable", false):
		hunter.charge_time = 0.0
		hunter.charge_kind = int(kind)
		_enter(hunter, HunterState.State.AXE_CHARGE)
		return true

	_spend(hunter, float(move["stamina"]))
	if move.has("projectile"):
		hunter.pending_projectile = String(move["projectile"])
	_enter(hunter, HunterState.State.ATTACK)
	return true


## Vocabulário fechado de efeitos.
static func _apply_effects(hunter: HunterState, effects: Array) -> void:
	for raw in effects:
		var effect := String(raw)
		match effect:
			"ammo_all":
				# O finalizador do Martelo descarrega tudo de uma vez.
				hunter.blast_ammo = maxi(1, hunter.ammo)
				hunter.ammo = 0
				continue
			"pips_all":
				hunter.slam_pips = hunter.pips
				hunter.pips = 0
				hunter.momentum = 0.0
				continue
			"ammo+1":
				hunter.ammo = mini(SimConfig.HAMMER_MAX_AMMO, hunter.ammo + 1)
				continue
			"ammo-1":
				hunter.ammo = maxi(0, hunter.ammo - 1)
				continue
			"det+1":
				grant_determination(hunter)
				continue
		if effect.begins_with("brio+"):
			hunter.brio = mini(SimConfig.BRIO_MAX, hunter.brio + int(effect.substr(5)))
		elif effect.begins_with("brio-"):
			hunter.brio = maxi(0, hunter.brio - int(effect.substr(5)))


## A Janela de Combo só corre fora de um Golpe. Expirada, a próxima Entrada
## entra de novo pelo `entry` da arma.
static func _tick_combo_grace(hunter: HunterState, dt: float) -> void:
	if hunter.combo_grace <= 0.0:
		return
	hunter.combo_grace = maxf(0.0, hunter.combo_grace - dt)
	if hunter.combo_grace == 0.0:
		hunter.combo_from = -1
		hunter.combo_effect_used = false


static func _break_combo(hunter: HunterState) -> void:
	hunter.combo_grace = 0.0
	hunter.combo_from = -1
	hunter.combo_effect_used = false


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
		hunter.dodge_window = SimConfig.COMBO_DODGE_WINDOW


static func _begin_dodge(hunter: HunterState, direction: Vector2) -> void:
	# Sem direção de movimento, rola para onde está mirando.
	hunter.dodge_dir = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT.rotated(hunter.facing)
	_spend(hunter, SimConfig.DODGE_COST)
	_enter(hunter, HunterState.State.DODGE)
	hunter.invulnerable = true


## Rolinho (Repetidoras): dash LATERAL curto, com menos Invulnerabilidade que
## a Esquiva. É mobilidade de arma de alcance, não uma esquiva melhor.
static func _begin_tumble(hunter: HunterState) -> bool:
	var move := Weapons.move(hunter.weapon_id, Weapons.Kind.HEAVY, 0)
	if hunter.stamina < float(move["stamina"]):
		return false
	hunter.dodge_dir = Vector2.RIGHT.rotated(hunter.facing).orthogonal()
	_spend(hunter, float(move["stamina"]))
	_enter(hunter, HunterState.State.TUMBLE)
	hunter.invulnerable = true
	return true


static func _step_tumble(hunter: HunterState, dt: float) -> void:
	if hunter.state_time < SimConfig.TUMBLE_DURATION:
		hunter.pos += hunter.dodge_dir * SimConfig.TUMBLE_SPEED * dt
		hunter.invulnerable = hunter.invulnerable or hunter.state_time < SimConfig.TUMBLE_IFRAMES_END
		return
	if hunter.state_time >= SimConfig.TUMBLE_DURATION + SimConfig.TUMBLE_RECOVERY:
		_enter(hunter, HunterState.State.FREE)
		hunter.dodge_window = SimConfig.COMBO_DODGE_WINDOW


## Golpes ------------------------------------------------------------------

static func _step_attack(hunter: HunterState, input: HunterInput, dt: float, world: Dictionary) -> void:
	var move := hunter.current_move()

	# O próximo Golpe pode ser pedido a qualquer momento e fica guardado. É o
	# que faz o Combo responder sem exigir precisão de milissegundo — mas o
	# Golpe atual continua indo até o fim de qualquer jeito.
	if input.light:
		hunter.buffered = HunterState.Buffered.LIGHT_HOLD if input.light_held \
			else HunterState.Buffered.LIGHT
	elif input.heavy:
		hunter.buffered = HunterState.Buffered.HEAVY_HOLD if input.heavy_held \
			else HunterState.Buffered.HEAVY
	elif input.reload:
		hunter.buffered = HunterState.Buffered.RELOAD

	# Golpes com deslocamento declarado (`lunge`): a EXCEÇÃO à regra de que
	# Golpe não locomove, por nó e por dado — nunca por tipo de botão.
	_apply_lunge(hunter, move, dt)

	if move.get("channel", false):
		if _step_channel(hunter, move, input, dt):
			return
	elif move.has("pulse_every"):
		var windup := float(move["windup"])
		if hunter.state_time > windup and hunter.state_time <= windup + float(move["active"]):
			_pulse(hunter, move, dt)

	if hunter.state_time < Weapons.duration(move):
		return

	_finish_attack(hunter, move, world)


## Um nó de canal se sustenta enquanto o botão estiver seguro: o relógio do
## Golpe CONGELA no fim do Preparo e o dano sai em pulsos. Soltar (ou zerar o
## vigor, ou bater o teto) destrava o relógio direto na Recuperação.
## Devolve verdadeiro enquanto o canal segura o Golpe.
static func _step_channel(hunter: HunterState, move: Dictionary, input: HunterInput, dt: float) -> bool:
	var windup := float(move["windup"])
	if hunter.state_time <= windup:
		return false

	var held := input.light_held if hunter.attack_kind == int(Weapons.Kind.LIGHT) else input.heavy_held
	var exhausted := hunter.stamina <= 0.0
	var expired := hunter.channel_time >= float(move.get("channel_max", 2.0))

	if held and not exhausted and not expired:
		hunter.state_time = windup
		hunter.channel_time += dt
		_spend(hunter, float(move.get("channel_stamina", 0.0)) * dt)
		_pulse(hunter, move, dt)
		return true

	# Destrava: pula a fase Ativa (que num canal tem duração zero) e deixa a
	# Recuperação correr pelo caminho normal.
	hunter.state_time = maxf(hunter.state_time, windup + float(move["active"]))
	return false


## O relógio dos pulsos de um Golpe multi-hit. Cada pulso limpa `hit_ids`
## (o limite de um-acerto-por-Golpe vale por PULSO) e acende `spin_strike`,
## que a Sim resolve.
static func _pulse(hunter: HunterState, move: Dictionary, dt: float) -> void:
	hunter.spin_tick += dt
	var interval := float(move["pulse_every"])
	var speedup := float(move.get("channel_speedup", 1.0))
	if speedup > 1.0:
		interval /= pow(speedup, hunter.channel_hits)
	if hunter.spin_tick < interval:
		return
	hunter.spin_tick -= interval
	hunter.channel_hits += 1
	hunter.hit_ids.clear()
	hunter.spin_strike = true


static func _apply_lunge(hunter: HunterState, move: Dictionary, dt: float) -> void:
	var lunge := float(move.get("lunge", 0.0))
	if lunge == 0.0:
		return
	var span := float(move["windup"]) + float(move["active"])
	if span <= 0.0:
		return
	# Pela FRAÇÃO do trecho percorrida neste Tique, não por velocidade vezes
	# dt: assim o deslocamento total é exatamente o `lunge` declarado mesmo
	# quando a duração não cai num número redondo de Tiques.
	var now := minf(hunter.state_time, span)
	var before := minf(maxf(0.0, hunter.state_time - dt), span)
	if now <= before:
		return
	hunter.pos += hunter.attack_dir * lunge * (now - before) / span


static func _finish_attack(hunter: HunterState, move: Dictionary, world: Dictionary) -> void:
	var buffered := hunter.buffered
	hunter.buffered = HunterState.Buffered.NONE

	# A escala da Rajada, do Corrente e da carga vale só para o Golpe em que
	# foi travada.
	hunter.blast_ammo = 0
	hunter.slam_pips = 0
	hunter.charge_locked = 0.0
	hunter.channel_time = 0.0
	hunter.channel_hits = 0

	var node_id := hunter.current_node()
	if node_id.is_empty():
		# Golpe que não é nó (a Rajada saindo da carga): não grava posição no
		# grafo e não mexe na janela — a cadeia continua de onde estava.
		_enter(hunter, HunterState.State.FREE)
		return

	_apply_effects(hunter, Weapons.node(hunter.weapon_id, node_id).get("on_end", []))

	# A Janela de Combo começa a correr no fim do Golpe. Quem já pediu o
	# próximo encadeia na hora; quem ainda não pediu tem essa janela para
	# pedir, e depois dela a próxima Entrada volta ao `entry` da arma.
	hunter.combo_from = Weapons.flat_of(hunter.weapon_id, node_id)
	hunter.combo_grace = float(move["combo_window"])
	hunter.combo_effect_used = false

	if buffered != HunterState.Buffered.NONE:
		if _try_inputs(hunter, _buffered_names(buffered), world, "free") == _ENTERED:
			return

	_enter(hunter, HunterState.State.FREE)


static func _buffered_names(buffered: HunterState.Buffered) -> Array:
	match buffered:
		HunterState.Buffered.LIGHT:
			return ["light"]
		HunterState.Buffered.LIGHT_HOLD:
			return ["light_hold", "light"]
		HunterState.Buffered.HEAVY:
			return ["heavy"]
		HunterState.Buffered.HEAVY_HOLD:
			return ["heavy_hold", "heavy"]
		HunterState.Buffered.RELOAD:
			return ["reload"]
	return []


## Carga do Machado ---------------------------------------------------------

## Segurar o Preparo escala o dano. Mira livre, corpo preso (mesma regra do
## CHARGING do Martelo) e vigor drenando: é golpe canalizado, e a exceção ao
## "leve custa zero" está declarada no MEMORY.md.
static func _step_axe_charge(hunter: HunterState, input: HunterInput, dt: float) -> void:
	hunter.facing = input.aim
	hunter.charge_time = minf(SimConfig.AXE_CHARGE_TIME_MAX, hunter.charge_time + dt)
	_spend(hunter, SimConfig.AXE_CHARGE_DRAIN_PER_SECOND * dt)

	var held := input.light_held if hunter.charge_kind == int(Weapons.Kind.LIGHT) else input.heavy_held
	if held and hunter.stamina > 0.0:
		return

	var move := Weapons.move(hunter.weapon_id, hunter.charge_kind as Weapons.Kind, hunter.attack_index)
	hunter.charge_locked = hunter.charge_time
	hunter.charge_time = 0.0

	# Carga PERFEITA no vertical: Resolve, a super-armadura que deixa o golpe
	# ir até o fim mesmo apanhando.
	if move.get("resolve_on_perfect", false) and _charge_is_perfect(hunter.charge_locked):
		hunter.resolve_time = float(move["windup"]) + float(move["active"])

	hunter.attack_dir = Vector2.RIGHT.rotated(hunter.facing)
	hunter.hit_ids.clear()
	hunter.buffered = HunterState.Buffered.NONE
	_spend(hunter, float(move["stamina"]))
	_enter(hunter, HunterState.State.ATTACK)


static func _charge_is_perfect(charge: float) -> bool:
	var ratio := charge / SimConfig.AXE_CHARGE_TIME_MAX
	return ratio >= SimConfig.AXE_CHARGE_PERFECT.x and ratio <= SimConfig.AXE_CHARGE_PERFECT.y


## Quanto a carga travada multiplica dano e Atordoamento deste Golpe.
static func charge_multiplier(hunter: HunterState) -> float:
	if hunter.charge_locked <= 0.0:
		return 1.0
	var t := clampf(hunter.charge_locked / SimConfig.AXE_CHARGE_TIME_MAX, 0.0, 1.0)
	return lerpf(1.0, SimConfig.AXE_CHARGE_MULT_MAX, t)


## Determinação: pilhas ganhas ao apanhar o Voo da Ruína que conectou. Mais
## pilhas, decaimento mais rápido — segurar três exige voltar a arremessar.
static func grant_determination(hunter: HunterState) -> void:
	hunter.det_stacks = mini(SimConfig.DETERMINATION_MAX_STACKS, hunter.det_stacks + 1)
	hunter.det_time = SimConfig.DETERMINATION_DURATIONS[hunter.det_stacks - 1]


static func _tick_determination(hunter: HunterState, dt: float) -> void:
	if hunter.det_time <= 0.0:
		return
	hunter.det_time -= dt
	if hunter.det_time > 0.0:
		return
	hunter.det_stacks = maxi(0, hunter.det_stacks - 1)
	hunter.det_time = 0.0 if hunter.det_stacks == 0 \
		else SimConfig.DETERMINATION_DURATIONS[hunter.det_stacks - 1]


## Rajada e recarga ---------------------------------------------------------

## Martelo: segurar o pesado arma a Rajada. Entrar já engole 1 munição.
static func _begin_concussive_hold(hunter: HunterState) -> bool:
	if hunter.ammo <= 0:
		return false
	if hunter.stamina < SimConfig.DODGE_COST * 0.4:
		return false
	_spend(hunter, SimConfig.DODGE_COST * 0.4)
	hunter.ammo -= 1
	hunter.blast_ammo = 1
	hunter.attack_dir = Vector2.RIGHT.rotated(hunter.facing)
	_enter(hunter, HunterState.State.CHARGING)
	return true


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
	# pela Sim na resolução, via blast_ammo). O Golpe que sai NÃO é nó do
	# grafo: a cadeia em andamento sobrevive à Rajada.
	if not input.heavy_held:
		hunter.attack_kind = int(Weapons.Kind.HEAVY)
		hunter.attack_index = 0
		hunter.attack_dir = Vector2.RIGHT.rotated(hunter.facing)
		hunter.hit_ids.clear()
		hunter.buffered = HunterState.Buffered.NONE
		_enter(hunter, HunterState.State.ATTACK)


## A recarga de verdade (estado). O Martelo cobra timing; as Repetidoras
## cobram POSIÇÃO — recarregar colado empodera o pente inteiro.
static func _begin_reload(hunter: HunterState) -> bool:
	if hunter.weapon_id == Weapons.HAMMER and hunter.ammo < SimConfig.HAMMER_MAX_AMMO:
		hunter.reload_failed = false
		_enter(hunter, HunterState.State.RELOADING)
		return true
	if hunter.weapon_id == Weapons.REPEATERS and hunter.mag < SimConfig.REPEATER_MAG:
		hunter.reload_failed = false
		_enter(hunter, HunterState.State.RELOADING)
		return true
	return false


static func _step_reloading(hunter: HunterState, input: HunterInput, world: Dictionary) -> void:
	if hunter.weapon_id == Weapons.REPEATERS:
		_step_reload_repeaters(hunter, world)
		return
	_step_reload_hammer(hunter, input)


## R de novo dentro da janela encurta a recarga para agora; fora dela, trava o
## tempo cheio e mais um pouco. Não dá para andar nem cancelar: recarregar na
## hora errada é a punição clássica do Martelo.
static func _step_reload_hammer(hunter: HunterState, input: HunterInput) -> void:
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


## Sem janela de timing e sem falha: o que decide é a DISTÂNCIA. Recarregar
## rente ao Behemoth suga Éter e empodera o pente inteiro.
##
## A predição do Cliente roda sem `world`: o dono prevê a recarga, e o
## empoderamento só se confirma pelo Instantâneo (mesma degradação do Gancho).
static func _step_reload_repeaters(hunter: HunterState, world: Dictionary) -> void:
	if hunter.state_time < SimConfig.REPEATER_RELOAD_TIME:
		return
	hunter.mag = SimConfig.REPEATER_MAG
	# A recarga SOBRESCREVE: longe zera o empoderamento, perto o repõe.
	# Nunca acumula.
	if _body_edge(hunter, world) <= SimConfig.REPEATER_EMPOWER_RANGE:
		hunter.empowered_shots = SimConfig.REPEATER_MAG
		hunter.just_empowered = true
	else:
		hunter.empowered_shots = 0
	_enter(hunter, HunterState.State.FREE)


## Tiro contínuo (Repetidoras) ----------------------------------------------

## O "leve" das Repetidoras não é um Golpe: não entra em ATTACK, não trava o
## movimento e não grava posição no grafo. Sai na cadência do pente.
static func _try_shot(hunter: HunterState, input: HunterInput) -> void:
	var move := Weapons.move(hunter.weapon_id, Weapons.Kind.LIGHT, 0)
	if not move.get("shot", false):
		return
	if not (input.light or input.light_held):
		return
	if hunter.fire_cooldown > 0.0 or hunter.mag <= 0:
		return
	hunter.mag -= 1
	hunter.fire_cooldown = float(move["fire_interval"])
	hunter.wants_shot = true


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

## Dispara o Especial da arma.
##
## O requisito de Éter cheio é POR TIPO, não universal: a Conversão Aetérica
## da Lança converte a partir de 10% do medidor, e o recall do Machado não
## custa nada (é a mesma tecla pedindo o machado de volta).
static func _begin_special(hunter: HunterState) -> bool:
	var special := Weapons.special(hunter.weapon_id)
	if special.is_empty():
		return false
	var kind := String(special["type"])

	# Machado com o machado no ar: a tecla chama ele de volta.
	if kind == "ruin" and hunter.axe_out:
		hunter.wants_axe_recall = true
		return true

	if kind == "conversion":
		return _begin_conversion(hunter, special)

	if hunter.aether < SimConfig.AETHER_MAX:
		return false

	hunter.aether = 0.0
	hunter.special_fired = true
	match kind:
		"valor":
			hunter.valor_time = float(special["duration"])
		"magma":
			# O projétil vive na Sim; aqui só fica o pedido de um Tique.
			hunter.pending_projectile = "magma"
		"reaper":
			hunter.spin_tick = 0.0
			_enter(hunter, HunterState.State.SPECIAL_SPIN)
		"ruin":
			hunter.pending_projectile = "ruin"
			hunter.axe_out = true
		"salvo":
			hunter.pending_projectile = "salvo"
	return true


## Conversão Aetérica: o primeiro toque converte TODO o medidor em munição de
## canhão, com qualidade por faixa; o segundo dispara o míssil.
static func _begin_conversion(hunter: HunterState, special: Dictionary) -> bool:
	if hunter.pike_ammo > 0:
		hunter.pending_projectile = "pike_shot"
		hunter.special_fired = true
		return true

	var thresholds: Array = special["ammo_thresholds"]
	if hunter.aether < float(thresholds[0]):
		return false
	var level := 0
	for limit in thresholds:
		if hunter.aether >= float(limit):
			level += 1
	hunter.pike_ammo = level
	hunter.aether = 0.0
	hunter.special_fired = true
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


## O multiplicador de dano dos buffs ativos, último na ordem do cálculo da
## spec. Valor (Espada), Determinação (Machado) e o buff de Ferida (quem
## explorou uma Parte Ferida) se compõem.
static func buff_multiplier(hunter: HunterState) -> float:
	var mult := 1.0
	if hunter.valor_time > 0.0:
		mult *= float(Weapons.special(hunter.weapon_id).get("damage_mult", 1.0))
	mult *= 1.0 + SimConfig.DETERMINATION_DAMAGE_PER_STACK * hunter.det_stacks
	if hunter.wound_buff_time > 0.0:
		mult *= 1.0 + SimConfig.WOUND_BUFF_DAMAGE
	return mult


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

	if hunter.hp <= 0.0:
		hunter.knockback = _away(hunter, from) * knockback
		_enter(hunter, HunterState.State.DOWNED)
		_break_combo(hunter)
		return true

	# Resolve: o golpe vai até o fim. O dano entra, o tranco não — é
	# super-armadura, não Invulnerabilidade.
	if hunter.resolve_time > 0.0:
		return true

	hunter.knockback = _away(hunter, from) * knockback
	_enter(hunter, HunterState.State.HURT)
	return true


static func _away(hunter: HunterState, from: Vector2) -> Vector2:
	var away := hunter.pos - from
	return away.normalized() if away.length() > 0.001 else Vector2.RIGHT


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
