class_name LearnScreen
extends Control

## Aprenda: a seção que ensina o jogo.
##
## REGRA DESTE ARQUIVO: nada aqui inventa número. Toda página é escrita a
## partir dos dados reais (`Weapons`, `Elements`, `Behemoths`, `SimConfig`) no
## momento em que é aberta. Se o balanceamento mudar, o Aprenda muda junto —
## uma tela de ajuda com números copiados à mão vira mentira na primeira
## rebalanceada, e mentira é pior que ausência.
##
## As árvores de combo são lidas de `Weapons.combo_graph()`: a mesma estrutura
## que a Simulação percorre para decidir o próximo Golpe. Arma sem grafo
## declarado ganha o grafo linear compilado pela própria `Weapons`, então esta
## tela não tem caminho especial para arma nenhuma.
##
## Navegação por teclado (setas/Tab entre os itens, Enter abre, Esc volta) e
## por mouse. A tela abre do menu e também da sala.

signal back_requested

const TITLE_HEX: String = "7fd4ff"
const ACCENT_HEX: String = "ffcf7f"
const DIM_HEX: String = "5d6b7a"
const ALERT_HEX: String = "ff8f7a"
const OK_HEX: String = "8de08a"

## Os botões do jogo, com o nome curto que aparece nas árvores de combo.
const INPUT_NAMES: Dictionary = {
	"light": "L",
	"heavy": "P",
	"light_hold": "L segurado",
	"heavy_hold": "P segurado",
	"reload": "R",
}

## Os contextos de entrada do grafo: de onde se começa um combo.
const CONTEXT_NAMES: Dictionary = {
	"free": "Parado ou andando",
	"sprint": "Saindo da corrida",
	"dodge": "Logo depois da Esquiva",
}

## Predicados do grafo que não são comparações numéricas.
const CONDITION_NAMES: Dictionary = {
	"near": "colado no alvo",
	"far": "longe do alvo",
	"no_world": "sem alvo conhecido",
	"back_dodge": "depois de esquivar para trás",
	"ammo==0": "sem munição",
}

## As pontes para ESTADOS da máquina (`to: "@algo"`): o grafo decide quando,
## o estado decide como. Nomes em português, como todo o resto da interface.
const STATE_NAMES: Dictionary = {
	"hook": "Gancho — puxão até o alvo",
	"charging": "carga do pesado",
	"tumble": "Rolinho",
}

## Efeitos do grafo que não são "recurso ± número".
const EFFECT_NAMES: Dictionary = {
	"ammo_all": "descarrega toda a munição restante",
	"pips_all": "gasta todos os pips de Momentum",
}

## Os recursos por arma, do jeito que o jogador os vê.
const RESOURCE_NAMES: Dictionary = {
	"brio": "Brio",
	"ammo": "munição",
	"pips": "pips de Momentum",
	"det": "Determinação",
	"mag": "pente",
}

## O que cada bandeira num Golpe significa. Lida dos dados: um Golpe que
## perder a bandeira perde a explicação junto.
const MOVE_FLAG_NOTES: Dictionary = {
	"hook": "Gancho: longe do alvo, o pesado vira puxão até ele",
	"chain": "Golpe de Corrente: colado, gasta todos os pips de Momentum",
	"concussive": "Rajada Concussiva: segurar o pesado entra em carga e come munição",
	"blast": "a força escala com a munição gasta",
	"shot": "tiro: resolvido fora da árvore de combo",
	"tumble": "Rolinho: dash lateral curto, com Invulnerabilidade parcial",
}

const MAX_COMBO_DEPTH: int = 6

## Teto POR ENTRADA, não por arma: sem isso o primeiro caminho de entrada
## (que na Espada exige Brio) encheria a lista sozinho e esconderia o
## L → L → L, que é o combo que todo mundo usa.
const MAX_PATHS_PER_ENTRY: int = 5

var _pages: Array = []
var _nav: VBoxContainer
var _body: RichTextLabel
var _wheel: Control
var _current: int = -1
var _buttons: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.fill_background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	column.add_child(UiKit.label("APRENDA", UiKit.SIZE_HEADING, UiKit.TITLE))
	column.add_child(UiKit.label(
		"Tudo aqui é lido dos dados do jogo. Setas e Enter, ou o mouse. Esc volta.",
		UiKit.SIZE_SMALL, UiKit.DIM
	))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(columns)

	columns.add_child(_build_nav())
	columns.add_child(_build_body())

	var back := UiKit.button("Voltar (Esc)", 32.0)
	back.pressed.connect(func() -> void: back_requested.emit())
	column.add_child(back)

	_fill_nav()
	_open(0)


func _build_nav() -> Control:
	var panel := UiKit.panel(10)
	panel.custom_minimum_size = Vector2(240.0, 0.0)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_nav = VBoxContainer.new()
	_nav.add_theme_constant_override("separation", 2)
	_nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_nav)
	return panel


func _build_body() -> Control:
	var panel := UiKit.panel(16)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	scroll.add_child(stack)

	_wheel = ElementWheel.new()
	_wheel.visible = false
	stack.add_child(_wheel)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 14)
	_body.add_theme_color_override("default_color", UiKit.TEXT)
	# Sem folga entre as colunas a tabela de controles encosta uma na outra.
	_body.add_theme_constant_override("table_h_separation", 22)
	stack.add_child(_body)
	return panel


## Índice -------------------------------------------------------------------

func _fill_nav() -> void:
	_pages = [{"kind": "basics", "id": "", "title": "Básico"}]
	_add_group("ARMAS")
	for weapon_id in Weapons.ids():
		_pages.append({
			"kind": "weapon", "id": weapon_id, "title": Weapons.display_name(weapon_id),
		})
	_add_group("ELEMENTOS")
	_pages.append({"kind": "elements", "id": "", "title": "Roda de Oposição"})
	_add_group("BEHEMOTHS")
	for type_id in Behemoths.ids():
		_pages.append({
			"kind": "behemoth", "id": type_id, "title": Behemoths.display_name(type_id),
		})

	for i in _pages.size():
		var page: Dictionary = _pages[i]
		if page["kind"] == "group":
			_nav.add_child(UiKit.spacer(8))
			_nav.add_child(UiKit.label(page["title"], UiKit.SIZE_SMALL, UiKit.DIM))
			_buttons.append(null)
			continue
		var button := Button.new()
		button.text = page["title"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0.0, 28.0)
		var index := i
		button.pressed.connect(func() -> void: _open(index))
		_nav.add_child(button)
		_buttons.append(button)


func _add_group(title: String) -> void:
	_pages.append({"kind": "group", "id": "", "title": title})


func _open(index: int) -> void:
	if index < 0 or index >= _pages.size():
		return
	var page: Dictionary = _pages[index]
	if page["kind"] == "group":
		return
	_current = index
	_wheel.visible = page["kind"] == "elements"
	_body.text = _page_text(page)
	var button: Variant = _buttons[index] if index < _buttons.size() else null
	if button != null:
		(button as Button).grab_focus()


func _page_text(page: Dictionary) -> String:
	match String(page["kind"]):
		"basics":
			return _basics_page()
		"weapon":
			return _weapon_page(String(page["id"]))
		"elements":
			return _elements_page()
		"behemoth":
			return _behemoth_page(String(page["id"]))
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			back_requested.emit()
			accept_event()


## Formatação ---------------------------------------------------------------

func _h1(text: String) -> String:
	return "[font_size=24][color=#%s]%s[/color][/font_size]\n" % [TITLE_HEX, text]


func _h2(text: String) -> String:
	return "\n[font_size=17][color=#%s]%s[/color][/font_size]\n" % [ACCENT_HEX, text]


func _dim(text: String) -> String:
	return "[color=#%s]%s[/color]" % [DIM_HEX, text]


func _alert(text: String) -> String:
	return "[color=#%s]%s[/color]" % [ALERT_HEX, text]


func _good(text: String) -> String:
	return "[color=#%s]%s[/color]" % [OK_HEX, text]


func _row(left: String, right: String) -> String:
	return "[cell][color=#%s]%s[/color][/cell][cell]%s[/cell]" % [ACCENT_HEX, left, right]


## Básico -------------------------------------------------------------------

func _basics_page() -> String:
	var text := _h1("Básico")
	text += "O combate é de leitura: o Behemoth avisa antes de bater, e você decide.\n"

	text += _h2("Controles")
	text += "[table=2]"
	text += _row("WASD", "mover (a frente é para onde a câmera olha)")
	text += _row("Mouse", "girar a câmera")
	text += _row("Botão esquerdo", "Golpe leve (L)")
	text += _row("Botão direito", "Golpe pesado (P) — em algumas armas dá para segurar")
	text += _row("Shift", "correr")
	text += _row("Espaço", "Esquiva")
	text += _row("F", "Especial da arma (precisa do Éter cheio)")
	text += _row("R", "recarregar")
	text += _row("Esc", "sair da Caçada")
	text += "[/table]\n"

	text += _h2("Fôlego")
	text += "Barra de %d. Correr gasta %s por segundo e exige pelo menos %d para começar; a Esquiva cobra %d de uma vez.\n" % [
		int(SimConfig.STAMINA_MAX), UiKit.number(SimConfig.SPRINT_DRAIN_PER_SECOND, 0),
		int(SimConfig.SPRINT_MIN_STAMINA), int(SimConfig.DODGE_COST),
	]
	text += "Depois do último gasto DE VERDADE, o Fôlego espera %s parado e então volta a %s por segundo. " % [
		UiKit.seconds(SimConfig.STAMINA_REGEN_DELAY, 1),
		UiKit.number(SimConfig.STAMINA_REGEN_PER_SECOND, 0),
	]
	text += "Golpes leves custam zero: dá para encadear leves enquanto o Fôlego volta.\n"

	text += _h2("Esquiva e Invulnerabilidade")
	text += "O rolamento dura %s. Os primeiros %s são INVULNERÁVEIS: nesse intervalo o ataque passa por você. " % [
		UiKit.seconds(SimConfig.DODGE_DURATION), UiKit.seconds(SimConfig.DODGE_IFRAMES_END),
	]
	text += "Depois vêm %s de recuperação, que é o que impede rolar sem parar.\n" % UiKit.seconds(SimConfig.DODGE_RECOVERY)
	text += _dim("Esquivar cedo demais é o erro mais comum: a Invulnerabilidade acaba antes do golpe chegar.") + "\n"
	text += "Esquivar também ABRE combo: algumas armas têm Golpe próprio nos %s seguintes ao fim do rolamento.\n" % UiKit.seconds(SimConfig.COMBO_DODGE_WINDOW)

	text += _h2("Comprometimento")
	text += "Golpe começado vai até o fim. Não existe cancelar no meio — é a decisão central do combate. "
	text += "A única coisa que quebra isso é a Aflição de %s, que interrompe o seu Golpe.\n" % Elements.affliction_name(Elements.Element.SHOCK)
	text += "Cada Golpe tem três fases: [color=#%s]Preparo[/color] (não acerta), [color=#%s]Ativo[/color] (a única fase que acerta) e [color=#%s]Recuperação[/color] (não acerta, mas prende).\n" % [DIM_HEX, ACCENT_HEX, DIM_HEX]
	text += "Encadear é apertar o próximo dentro da Janela de combo, que começa no fim da Recuperação.\n"

	text += _h2("Atordoamento e Partes")
	text += "Dano de Impacto enche o medidor de Atordoamento do Behemoth; cheio, ele cai por %s e sofre ×%s de dano. " % [
		UiKit.seconds(SimConfig.STAGGER_DOWN_DURATION, 1), UiKit.number(SimConfig.STAGGERED_DAMAGE_MULT, 1),
	]
	text += "Cada queda seguinte exige ×%s do medidor. Parado, o medidor esvazia %s por segundo.\n" % [
		UiKit.number(SimConfig.STAGGER_ESCALATION, 2), UiKit.number(SimConfig.STAGGER_DECAY_PER_SECOND, 0),
	]
	text += "Quanto cada Tipo de Dano rende de Atordoamento: "
	var shares: Array[String] = []
	for damage_type in SimConfig.STAGGER_TYPE_MULT.keys():
		shares.append("%s ×%s" % [
			_damage_type_name(damage_type), UiKit.number(SimConfig.STAGGER_TYPE_MULT[damage_type], 1),
		])
	text += ", ".join(shares) + ".\n"
	text += "Quebrar uma Parte enche %d%% do medidor de uma vez e faz aquela Parte receber ×%s dali em diante.\n" % [
		int(SimConfig.PART_BREAK_STAGGER_FRACTION * 100.0), UiKit.number(SimConfig.BROKEN_PART_MULT, 1),
	]

	text += _h2("Interrupção")
	text += "Alguns ataques têm uma JANELA no começo do Preparo em que um impacto forte o bastante CANCELA o golpe. "
	text += "O Behemoth fica exposto por %s, e aquele golpe não alimenta o medidor de queda. " % UiKit.seconds(SimConfig.INTERRUPT_DURATION, 1)
	text += "Quais ataques aceitam isso, e quanto de impacto cada um exige, está na página de cada Behemoth.\n"
	text += _good("Durante a janela o HUD avisa: JANELA DE INTERRUPÇÃO.") + "\n"

	text += _h2("Abatido")
	text += "Com a Vida zerada o Caçador fica Abatido: imóvel e vulnerável, com %s de contador. " % UiKit.seconds(SimConfig.DOWNED_DURATION, 1)
	text += "Hoje ele levanta sozinho com %d%% da Vida.\n" % int(SimConfig.DOWNED_REVIVE_FRACTION * 100.0)
	text += _dim("Fichas de Reviver e companheiro levantando ainda não estão no jogo.") + "\n"

	text += _h2("Éter e Especial")
	text += "Acertar Golpes enche o Éter (máximo %d). Cheio, F dispara o Especial da sua arma — cada arma tem o seu, descrito na página dela.\n" % int(SimConfig.AETHER_MAX)
	return text


## Armas --------------------------------------------------------------------

func _weapon_page(weapon_id: String) -> String:
	var weapon := Weapons.get_weapon(weapon_id)
	var text := _h1(String(weapon.get("name", weapon_id)))
	text += String(weapon.get("blurb", "")) + "\n\n"
	text += _dim(
		"L = botão esquerdo · P = botão direito · R = recarregar · F = Especial · " +
		"Espaço = Esquiva · Shift = correr"
	) + "\n"

	text += _h2("Tipo de dano")
	var damage_type := Weapons.damage_type(weapon_id)
	text += "%s. %s\n" % [_damage_type_name(damage_type), _damage_type_note(damage_type)]

	var meter := _weapon_meter(weapon_id, damage_type)
	if not meter.is_empty():
		text += _h2("Medidor próprio")
		text += meter

	text += _h2("Especial (F)")
	text += _special_text(weapon_id)

	text += _h2("Árvore de combos")
	text += _combo_text(weapon_id, damage_type)

	var loose := _loose_moves(weapon_id, damage_type)
	if not loose.is_empty():
		text += _h2("Fora da árvore")
		text += loose
	return text


func _damage_type_name(damage_type: Weapons.DamageType) -> String:
	match damage_type:
		Weapons.DamageType.SLASH:
			return "Corte"
		Weapons.DamageType.BLUNT:
			return "Impacto"
		Weapons.DamageType.PIERCE:
			return "Perfuração"
		Weapons.DamageType.BALLISTIC:
			return "Balístico"
	return "?"


func _damage_type_note(damage_type: Weapons.DamageType) -> String:
	var stagger := "Rende ×%s de Atordoamento." % UiKit.number(
		SimConfig.STAGGER_TYPE_MULT.get(damage_type, 1.0), 1
	)
	match damage_type:
		Weapons.DamageType.SLASH:
			return "Decepa Partes decepáveis (cauda, asa): ×%s nelas. %s" % [
				UiKit.number(SimConfig.SLASH_SEVER_MULT, 2), stagger,
			]
		Weapons.DamageType.BLUNT:
			return "Castiga Partes duras (cabeça): ×%s nelas. %s É a arma que derruba." % [
				UiKit.number(SimConfig.BLUNT_HARD_MULT, 2), stagger,
			]
		Weapons.DamageType.PIERCE:
			return "Abre Ferimento nas Partes: %d%% do dano vira acúmulo de ferida. %s" % [
				int(SimConfig.PIERCE_WOUND_RATE * 100.0), stagger,
			]
		Weapons.DamageType.BALLISTIC:
			return "Físico neutro: sem bônus de decepar nem contra Parte dura. %s" % stagger
	return stagger


## Os recursos da arma saem do PRÓPRIO grafo: os efeitos (`brio+1`, `ammo-1`)
## e os predicados (`ammo>=1`) dizem quais medidores aquela arma usa. Uma arma
## que perder o recurso perde a explicação junto.
func _weapon_meter(weapon_id: String, damage_type: Weapons.DamageType) -> String:
	var tokens := _resource_tokens(weapon_id)
	var text := ""

	if tokens.has("brio"):
		text += "[color=#%s]Brio[/color]: fechar cadeias enche (até %d). Os Golpes de desvio gastam 3 pips de uma vez.\n" % [
			ACCENT_HEX, SimConfig.BRIO_MAX,
		]
	if tokens.has("ammo"):
		text += "[color=#%s]Munição[/color]: %d cargas. Segurar o pesado consome 1 ao armar e +1 a cada %s segurando.\n" % [
			ACCENT_HEX, SimConfig.HAMMER_MAX_AMMO, UiKit.seconds(SimConfig.HAMMER_HOLD_PER_AMMO, 1),
		]
		text += "R recarrega em %s. Apertar R de novo entre %s e %s termina na hora; fora da janela trava o tempo cheio mais %s. Dentro de um combo, R encaixa +1 munição sem cortar a cadeia.\n" % [
			UiKit.seconds(SimConfig.RELOAD_TIME, 1), UiKit.seconds(SimConfig.RELOAD_QUICK_START, 1),
			UiKit.seconds(SimConfig.RELOAD_QUICK_END, 1), UiKit.seconds(SimConfig.RELOAD_FAIL_EXTRA, 1),
		]
	if tokens.has("pips"):
		text += "[color=#%s]Momentum[/color]: cada Golpe leve que conecta soma %s; a cada %s vira 1 pip, até %d. " % [
			ACCENT_HEX, UiKit.number(SimConfig.MOMENTUM_PER_HIT, 0),
			UiKit.number(SimConfig.MOMENTUM_PIP, 0), SimConfig.MOMENTUM_MAX_PIPS,
		]
		text += "O Golpe de Corrente gasta TODOS os pips: +%s de dano e +%s de Atordoamento por pip.\n" % [
			UiKit.number(SimConfig.CHAIN_SLAM_DAMAGE_PER_PIP, 0),
			UiKit.number(SimConfig.CHAIN_SLAM_STAGGER_PER_PIP, 0),
		]
	if tokens.has("det"):
		text += "[color=#%s]Determinação[/color]: até %d pilhas, +%d%% de dano cada.\n" % [
			ACCENT_HEX, SimConfig.DETERMINATION_MAX_STACKS,
			int(SimConfig.DETERMINATION_DAMAGE_PER_STACK * 100.0),
		]
	# As Repetidoras não têm árvore, então o pente não aparece em predicado
	# nenhum: a bandeira `shot` do Golpe é o que denuncia a arma de pente.
	if tokens.has("mag") or _has_flag(weapon_id, "shot"):
		text += "[color=#%s]Pente[/color]: %d tiros, recarga de %s. Recarregar a até %s cm da BORDA do corpo do Behemoth empodera o pente (×%s de dano).\n" % [
			ACCENT_HEX, SimConfig.REPEATER_MAG, UiKit.seconds(SimConfig.REPEATER_RELOAD_TIME, 1),
			UiKit.number(SimConfig.REPEATER_EMPOWER_RANGE, 0),
			UiKit.number(SimConfig.REPEATER_EMPOWER_MULT, 2),
		]

	if damage_type == Weapons.DamageType.PIERCE:
		text += "[color=#%s]Ferimento[/color]: a Parte abre uma ferida ao acumular %s, e ela dura %s. " % [
			ACCENT_HEX, UiKit.number(SimConfig.WOUND_THRESHOLD, 0),
			UiKit.seconds(SimConfig.WOUND_DURATION, 1),
		]
		text += "Explorar a ferida (%s de dano nela enquanto está aberta) dá +%d%% de dano pessoal por %s.\n" % [
			UiKit.number(SimConfig.WOUND_HARVEST_TARGET, 0),
			int(SimConfig.WOUND_BUFF_DAMAGE * 100.0),
			UiKit.seconds(SimConfig.WOUND_BUFF_DURATION, 1),
		]

	if _has_flag(weapon_id, "chargeable"):
		text += "[color=#%s]Carga[/color]: segurar o Preparo escala o dano até ×%s em %s; segurar drena %s de Fôlego por segundo. Soltar entre %d%% e %d%% da carga é a carga PERFEITA.\n" % [
			ACCENT_HEX, UiKit.number(SimConfig.AXE_CHARGE_MULT_MAX, 2),
			UiKit.seconds(SimConfig.AXE_CHARGE_TIME_MAX, 1),
			UiKit.number(SimConfig.AXE_CHARGE_DRAIN_PER_SECOND, 0),
			int(SimConfig.AXE_CHARGE_PERFECT.x * 100.0), int(SimConfig.AXE_CHARGE_PERFECT.y * 100.0),
		]
	return text


func _resource_tokens(weapon_id: String) -> Dictionary:
	var tokens: Dictionary = {}
	var graph := Weapons.combo_graph(weapon_id)
	var transitions: Array = []
	for context in (graph["entry"] as Dictionary).keys():
		transitions.append_array(graph["entry"][context])
	for node_id in (graph["nodes"] as Dictionary).keys():
		var node: Dictionary = graph["nodes"][node_id]
		transitions.append_array(node.get("next", []))
		for effect in (node.get("on_start", []) + node.get("on_end", [])):
			_collect_token(String(effect), tokens)
	for transition in transitions:
		_collect_token(String((transition as Dictionary).get("if", "")), tokens)
		for effect in (transition as Dictionary).get("on_start", []):
			_collect_token(String(effect), tokens)
	return tokens


func _collect_token(expression: String, tokens: Dictionary) -> void:
	for token in RESOURCE_NAMES.keys():
		if expression.begins_with(token):
			tokens[token] = true
	if expression == "ammo_all":
		tokens["ammo"] = true
	if expression == "pips_all":
		tokens["pips"] = true


func _has_flag(weapon_id: String, flag: String) -> bool:
	for kind in [Weapons.Kind.LIGHT, Weapons.Kind.HEAVY]:
		for move in Weapons.moves(weapon_id, kind):
			if bool((move as Dictionary).get(flag, false)):
				return true
	return false


## O Especial é renderizado em cima do dicionário de dados, campo a campo:
## uma arma nova com um Especial novo aparece aqui sem tocar neste arquivo.
func _special_text(weapon_id: String) -> String:
	var special := Weapons.special(weapon_id)
	if special.is_empty():
		return _dim("Esta arma não tem Especial.") + "\n"

	var labels := {
		"duration": "Duração", "damage": "Dano", "stagger": "Atordoamento",
		"radius": "Raio", "speed": "Velocidade", "range": "Alcance",
		"tick": "Intervalo entre acertos", "part": "Dano de Parte",
		"damage_mult": "Dano ×", "speed_mult": "Velocidade ×",
		"damage_base": "Dano base", "stagger_base": "Atordoamento base",
		"damage_per_level": "Dano por nível", "stagger_per_level": "Atordoamento por nível",
		"empowered_count": "Projéteis quando empoderado",
		"empowered_spread": "Abertura quando empoderado",
		"catch_refund": "Devolução ao aparar",
	}
	var text := "[color=#%s]%s[/color] — precisa do Éter cheio (%d).\n" % [
		ACCENT_HEX, String(special.get("name", "Especial")), int(SimConfig.AETHER_MAX)
	]
	for key in special.keys():
		if key == "name" or key == "type":
			continue
		var value: Variant = special[key]
		if not (value is float or value is int):
			continue
		var pretty: String = labels.get(key, String(key))
		if key == "duration" or key == "tick":
			text += "· %s: %s\n" % [pretty, UiKit.seconds(float(value), 2)]
		elif String(key).ends_with("_mult"):
			text += "· %s%s\n" % [pretty, UiKit.number(float(value), 2)]
		else:
			text += "· %s: %s\n" % [pretty, UiKit.number(float(value), 0)]
	if String(special.get("type", "")) == "valor":
		text += "Enquanto dura, cada Golpe conectado solta uma onda elemental de %s de dano, que respeita a Oposição.\n" % UiKit.number(SimConfig.VALOR_WAVE_DAMAGE, 0)
	return text


## Árvore de combos ---------------------------------------------------------

## A árvore sai de `Weapons.combo_graph()`: a MESMA estrutura que a Sim
## percorre. Arma sem grafo declarado recebe o grafo linear compilado lá, e
## esta função nem sabe a diferença.
func _combo_text(weapon_id: String, damage_type: Weapons.DamageType) -> String:
	var graph := Weapons.combo_graph(weapon_id)
	var nodes: Dictionary = graph["nodes"]
	var entry: Dictionary = graph["entry"]
	if nodes.is_empty():
		return _dim(
			"Esta arma não tem árvore de combo: os Golpes dela são ações soltas, " +
			"listadas abaixo. É assim de propósito."
		) + "\n"

	var text := "\n[color=#%s]Como começa[/color]\n" % TITLE_HEX
	for context in entry.keys():
		var candidates: Array = entry[context]
		if candidates.is_empty():
			continue
		var parts: Array[String] = []
		for candidate in candidates:
			parts.append(_transition_text(weapon_id, candidate, nodes))
		text += "· %s: %s\n" % [CONTEXT_NAMES.get(context, String(context)), ", ".join(parts)]

	var paths := _combo_paths(weapon_id, nodes, entry.get("free", []))
	if not paths.is_empty():
		text += "\n[color=#%s]Sequências completas[/color]\n" % TITLE_HEX
		for line in paths:
			text += "· " + line + "\n"

	text += "\n[color=#%s]Golpe a Golpe[/color]\n" % TITLE_HEX
	for node_id in nodes.keys():
		text += _node_text(weapon_id, nodes, node_id, damage_type)
	return text


func _node_text(
	weapon_id: String, nodes: Dictionary, node_id: String, damage_type: Weapons.DamageType
) -> String:
	var node: Dictionary = nodes[node_id]
	var move := Weapons.node_move(weapon_id, node_id)
	var kind_name := "leve" if int(node.get("kind", 0)) == int(Weapons.Kind.LIGHT) else "pesado"

	var text := "[color=#%s]%s[/color] %s\n" % [
		ACCENT_HEX, String(move.get("name", node_id)), _dim("(%s)" % kind_name),
	]
	text += "   " + _move_stats(move, damage_type) + "\n"

	var notes := _move_notes(move)
	for note in notes:
		text += "   " + _good("→ " + note) + "\n"

	var effects: Array = node.get("on_start", []) + node.get("on_end", [])
	if not effects.is_empty():
		var pretty: Array[String] = []
		for effect in effects:
			pretty.append(_effect_text(String(effect)))
		text += "   " + _dim("recurso: " + ", ".join(pretty)) + "\n"

	var nexts: Array = node.get("next", [])
	if nexts.is_empty():
		text += "   " + _dim("termina a cadeia") + "\n"
		return text
	var parts: Array[String] = []
	for candidate in nexts:
		parts.append(_transition_text(weapon_id, candidate, nodes))
	text += "   " + _dim("continua: " + ", ".join(parts)) + "\n"
	return text


## Golpes que NÃO são nós do grafo: o Gancho, a Rajada em carga, o tiro, o
## Rolinho. Eles existem na arma mas são estados ou ações, não arestas.
func _loose_moves(weapon_id: String, damage_type: Weapons.DamageType) -> String:
	var text := ""
	for kind in [Weapons.Kind.LIGHT, Weapons.Kind.HEAVY]:
		var list := Weapons.moves(weapon_id, kind)
		for index in list.size():
			if not Weapons.node_name(weapon_id, kind as Weapons.Kind, index).is_empty():
				continue
			var move: Dictionary = list[index]
			text += "[color=#%s]%s[/color]\n" % [ACCENT_HEX, String(move.get("name", "?"))]
			for note in _move_notes(move):
				text += "   " + _good("→ " + note) + "\n"
			text += "   " + _move_stats(move, damage_type) + "\n"
	return text


## As particularidades do Golpe, lidas das bandeiras dos dados.
func _move_notes(move: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	for flag in MOVE_FLAG_NOTES.keys():
		if bool(move.get(flag, false)):
			notes.append(String(MOVE_FLAG_NOTES[flag]))
	var lunge := float(move.get("lunge", 0.0))
	if lunge > 0.0:
		notes.append("avança %s cm durante o golpe" % UiKit.number(lunge, 0))
	elif lunge < 0.0:
		notes.append("recua %s cm durante o golpe" % UiKit.number(-lunge, 0))
	if bool(move.get("channel", false)):
		notes.append("canalizado: segure o botão para sustentar, drenando Fôlego")
	if bool(move.get("chargeable", false)):
		notes.append("carregável: segurar o Preparo escala o dano")
	if float(move.get("pulse_every", 0.0)) > 0.0:
		notes.append("acerta em pulsos a cada %s" % UiKit.seconds(float(move["pulse_every"])))
	if move.has("projectile"):
		notes.append("cospe um projétil ao começar")
	return notes


func _transition_text(weapon_id: String, candidate: Dictionary, nodes: Dictionary) -> String:
	var button: String = INPUT_NAMES.get(candidate.get("input", ""), String(candidate.get("input", "?")))
	var condition := String(candidate.get("if", ""))
	var target := String(candidate.get("to", ""))

	var target_name := target
	if target.is_empty():
		var effects: Array = candidate.get("on_start", [])
		var pretty: Array[String] = []
		for effect in effects:
			pretty.append(_effect_text(String(effect)))
		target_name = "%s (sem trocar de Golpe)" % ", ".join(pretty)
	elif target.begins_with("@"):
		var state := target.substr(1)
		target_name = String(STATE_NAMES.get(state, state))
	else:
		target_name = String(Weapons.node_move(weapon_id, target).get("name", target))

	if condition.is_empty():
		return "%s → %s" % [button, target_name]
	return "%s se %s → %s" % [button, _condition_text(condition), target_name]


func _condition_text(condition: String) -> String:
	if CONDITION_NAMES.has(condition):
		return String(CONDITION_NAMES[condition])
	for token in RESOURCE_NAMES.keys():
		if not condition.begins_with(token):
			continue
		var rest: String = condition.substr(String(token).length())
		rest = rest.replace(">=", " ≥ ").replace("<=", " ≤ ").replace("==", " = ")
		return String(RESOURCE_NAMES[token]) + rest
	return condition


func _effect_text(effect: String) -> String:
	if EFFECT_NAMES.has(effect):
		return String(EFFECT_NAMES[effect])
	for token in RESOURCE_NAMES.keys():
		if not effect.begins_with(token):
			continue
		var rest: String = effect.substr(String(token).length())
		if rest.begins_with("+"):
			return "+%s de %s" % [rest.substr(1), RESOURCE_NAMES[token]]
		if rest.begins_with("-"):
			return "−%s de %s" % [rest.substr(1), RESOURCE_NAMES[token]]
	return effect


## Os números de um Golpe. Campo zerado fica de FORA: uma ação sem fases
## próprias (o tiro, o Rolinho) não deve exibir "Preparo 0,00 s · Ativo
## 0,00 s" como se fosse informação.
func _move_stats(move: Dictionary, damage_type: Weapons.DamageType) -> String:
	var lines: Array[String] = []

	var total := float(move.get("windup", 0.0)) + float(move.get("active", 0.0)) + float(move.get("recovery", 0.0))
	if total > 0.0:
		var phases := "Preparo %s · Ativo %s · Recuperação %s" % [
			UiKit.seconds(float(move.get("windup", 0.0))),
			UiKit.seconds(float(move.get("active", 0.0))),
			UiKit.seconds(float(move.get("recovery", 0.0))),
		]
		var window := float(move.get("combo_window", 0.0))
		if window > 0.0:
			phases += " · Janela %s" % UiKit.seconds(window)
		lines.append(phases)
	else:
		lines.append("sem fases próprias: o tempo vem do estado que resolve a ação")

	var stagger := float(move.get("stagger", 0.0))
	var numbers: Array[String] = ["Dano %s" % UiKit.number(float(move.get("damage", 0.0)), 0)]
	if stagger > 0.0:
		numbers.append("Atordoamento %s (vale %s com %s)" % [
			UiKit.number(stagger, 0),
			UiKit.number(stagger * float(SimConfig.STAGGER_TYPE_MULT.get(damage_type, 1.0)), 0),
			_damage_type_name(damage_type),
		])
	numbers.append("Parte ×%s" % UiKit.number(float(move.get("part", 1.0)), 2))
	lines.append(" · ".join(numbers))

	var reach: Array[String] = []
	if float(move.get("range", 0.0)) > 0.0:
		reach.append("Alcance %s cm" % UiKit.number(float(move["range"]), 0))
	if float(move.get("arc", 0.0)) > 0.0:
		reach.append("Arco %s" % _arc_text(float(move["arc"])))
	reach.append("Fôlego %s" % UiKit.number(float(move.get("stamina", 0.0)), 0))
	reach.append("Éter +%s" % UiKit.number(float(move.get("aether", 0.0)), 0))
	lines.append(" · ".join(reach))

	var dimmed: Array[String] = []
	for line in lines:
		dimmed.append(_dim(line))
	return "\n   ".join(dimmed)


func _arc_text(arc: float) -> String:
	if arc >= TAU - 0.01:
		return "360° (ao redor)"
	return UiKit.degrees(arc)


## As sequências legíveis: caminhos a partir das entradas de "parado",
## andando até onde a cadeia acaba, o grafo volta a um nó já visitado, ou a
## profundidade máxima.
func _combo_paths(weapon_id: String, nodes: Dictionary, free_entries: Array) -> Array[String]:
	var out: Array[String] = []
	for candidate in free_entries:
		var target := String(candidate.get("to", ""))
		if not nodes.has(target):
			continue
		var button: String = INPUT_NAMES.get(candidate.get("input", ""), "?")
		var condition := String(candidate.get("if", ""))
		if not condition.is_empty():
			button += " (%s)" % _condition_text(condition)
		var first := String(Weapons.node_move(weapon_id, target).get("name", target))

		var branch: Array[String] = []
		_walk(weapon_id, nodes, target, [button], [first], [target], branch)
		out.append_array(branch)
	return out


func _walk(
	weapon_id: String, nodes: Dictionary, node_id: String,
	buttons: Array, names: Array, visited: Array, out: Array[String]
) -> void:
	if out.size() >= MAX_PATHS_PER_ENTRY:
		return
	var node: Dictionary = nodes.get(node_id, {})
	var extended := false
	if buttons.size() < MAX_COMBO_DEPTH:
		for candidate in node.get("next", []):
			var target := String(candidate.get("to", ""))
			if target.is_empty() or target.begins_with("@"):
				continue
			if not nodes.has(target) or target in visited:
				continue
			extended = true
			var button: String = INPUT_NAMES.get(candidate.get("input", ""), "?")
			var pretty := String(Weapons.node_move(weapon_id, target).get("name", target))
			_walk(
				weapon_id, nodes, target,
				buttons + [button], names + [pretty], visited + [target], out
			)
	if not extended:
		out.append("[color=#%s]%s[/color] : %s" % [
			ACCENT_HEX, " → ".join(buttons), " → ".join(names)
		])


## Elementos ----------------------------------------------------------------

func _elements_page() -> String:
	var text := _h1("Elementos e Aflições")
	text += "Sete Elementos. Três pares opostos; Neutro não tem oposto — é a escolha segura, nunca premiada nem punida.\n"

	text += _h2("Oposição")
	for element in Elements.all():
		var opposite: Variant = Elements.OPPOSITES.get(element)
		if opposite == null:
			continue
		if int(element) > int(opposite):
			continue  # cada par aparece uma vez só
		text += "· [color=#%s]%s[/color] ↔ [color=#%s]%s[/color]\n" % [
			Elements.color(element).to_html(false), Elements.display_name(element),
			Elements.color(opposite).to_html(false), Elements.display_name(opposite),
		]
	text += "\nArma do Elemento OPOSTO ao do alvo: ×%s de dano. Arma do MESMO Elemento: ×%s. Neutro de qualquer lado: ×1.\n" % [
		UiKit.number(Elements.OPPOSITION_BONUS, 2), UiKit.number(Elements.SAME_ELEMENT_PENALTY, 2),
	]

	text += _h2("Aflições")
	text += "O Elemento de um ataque do Behemoth acumula em você: %s por acerto, dispara em %s e some %s por segundo sem apanhar. " % [
		UiKit.number(SimConfig.AFFLICTION_BUILDUP_PER_HIT, 0),
		UiKit.number(SimConfig.AFFLICTION_THRESHOLD, 0),
		UiKit.number(SimConfig.AFFLICTION_BUILDUP_DECAY, 0),
	]
	text += "Disparada, dura %s.\n\n" % UiKit.seconds(SimConfig.AFFLICTION_DURATION, 1)

	for element in Elements.all():
		var affliction := Elements.affliction_name(element)
		if affliction.is_empty():
			continue
		text += "[color=#%s]%s — %s[/color]\n" % [
			Elements.color(element).to_html(false), Elements.display_name(element), affliction,
		]
		text += "   " + _affliction_effect(element) + "\n"
	return text


func _affliction_effect(element: Elements.Element) -> String:
	match element:
		Elements.Element.BLAZE:
			return "Queima: perde %s de Vida por segundo enquanto durar." % UiKit.number(SimConfig.BURN_DPS, 0)
		Elements.Element.FROST:
			return "Congela: você anda a %d%% da velocidade." % int(roundf(SimConfig.FROST_SLOW * 100.0))
		Elements.Element.SHOCK:
			return "Choque: QUEBRA o Golpe em andamento — a única coisa que fura o Comprometimento — e tira %s de Fôlego." % UiKit.number(SimConfig.SHOCK_STAMINA_COST, 0)
		Elements.Element.TERRA:
			return "Enraíza: a Esquiva fica trancada. Sem Invulnerabilidade, só posicionamento."
		Elements.Element.RADIANT:
			return "Cega: as bordas da visão escurecem. Dá para jogar, mas você perde a leitura periférica."
		Elements.Element.UMBRAL:
			return "Drena: o Éter escorre %s por segundo e o Fôlego não regenera." % UiKit.number(SimConfig.DRAIN_AETHER_PER_SECOND, 0)
	return ""


## Behemoths ----------------------------------------------------------------

func _behemoth_page(type_id: String) -> String:
	var beast := Behemoths.get_behemoth(type_id)
	var text := _h1(String(beast.get("name", type_id)))
	text += String(beast.get("blurb", "")) + "\n"

	text += _h2("Números")
	text += "Vida %s · Corpo %s cm de raio · Atordoamento enche em %s\n" % [
		UiKit.number(float(beast.get("hp", 0.0)), 0),
		UiKit.number(float(beast.get("radius", 0.0)), 0),
		UiKit.number(float(beast.get("stagger_threshold", 0.0)), 0),
	]
	text += "Fúria abaixo de %d%% da Vida: ×%s de velocidade, ×%s de dano, brechas pela metade.\n" % [
		int(float(beast.get("enrage_at", 0.0)) * 100.0),
		UiKit.number(float(beast.get("enrage_speed", 1.0)), 2),
		UiKit.number(float(beast.get("enrage_damage", 1.0)), 2),
	]

	var breakable := _interruptible_names(type_id)
	text += _h2("Dá para interromper")
	if breakable.is_empty():
		text += _dim("Nenhum ataque deste Behemoth tem janela de interrupção.") + "\n"
	else:
		text += _good(", ".join(breakable)) + " — o detalhe está em cada ataque abaixo.\n"
	text += _dim(
		"Interromper é acertar um golpe de Atordoamento acima do limiar DENTRO da " +
		"janela do Preparo. O ataque é cancelado e ele fica exposto %s." % UiKit.seconds(SimConfig.INTERRUPT_DURATION, 1)
	) + "\n"

	text += _h2("Partes")
	for part in beast.get("parts", []):
		text += _part_text(type_id, part)

	text += _h2("Ataques")
	for attack in Behemoths.attacks(type_id):
		text += _attack_text(attack)
	return text


func _interruptible_names(type_id: String) -> Array[String]:
	var names: Array[String] = []
	for attack in Behemoths.attacks(type_id):
		if not (attack as Dictionary).get("interruptible", {}).is_empty():
			names.append(String((attack as Dictionary).get("name", "?")))
	return names


func _part_text(type_id: String, part: Dictionary) -> String:
	var text := "[color=#%s]%s[/color] — Vida %s\n" % [
		ACCENT_HEX, String(part.get("name", "?")), UiKit.number(float(part.get("hp", 0.0)), 0),
	]
	var traits: Array[String] = []
	if bool(part.get("severable", false)):
		traits.append("decepável (Corte ×%s)" % UiKit.number(SimConfig.SLASH_SEVER_MULT, 2))
	if bool(part.get("hard", false)):
		traits.append("dura (Impacto ×%s)" % UiKit.number(SimConfig.BLUNT_HARD_MULT, 2))
	if bool(part.get("armored", false)):
		traits.append("blindada: segura o dano à Vida, mas sempre vaza %d%%" % int(SimConfig.ARMOR_LEAK * 100.0))
	if not traits.is_empty():
		text += "   " + _dim(" · ".join(traits)) + "\n"

	var effects: Array[String] = [
		"recebe ×%s de dano" % UiKit.number(SimConfig.BROKEN_PART_MULT, 1),
		"enche %d%% do medidor de Atordoamento na hora" % int(SimConfig.PART_BREAK_STAGGER_FRACTION * 100.0),
	]
	var part_id := String(part.get("id", ""))
	for attack in Behemoths.attacks(type_id):
		if String((attack as Dictionary).get("requires_part", "")) == part_id:
			effects.append("o ataque %s some do repertório" % String((attack as Dictionary).get("name", "?")))
	var penalty: Dictionary = part.get("break_penalty", {})
	if not penalty.is_empty():
		var hit := Behemoths.attack(type_id, String(penalty.get("attack", "")))
		effects.append("%s fica %s mais lento" % [
			String(hit.get("name", penalty.get("attack", "?"))),
			UiKit.seconds(float(penalty.get("extra", 0.0)), 1),
		])
	text += "   Ao quebrar: " + " · ".join(effects) + "\n"
	return text


func _attack_text(attack: Dictionary) -> String:
	var text := "[color=#%s]%s[/color] — %s\n" % [
		ACCENT_HEX, String(attack.get("name", "?")), _shape_text(attack.get("shape", {})),
	]
	text += "   " + _dim("Preparo %s · Ativo %s · Recuperação %s · Dano %s · Empurrão %s · Espera %s" % [
		UiKit.seconds(float(attack.get("windup", 0.0))),
		UiKit.seconds(float(attack.get("active", 0.0))),
		UiKit.seconds(float(attack.get("recovery", 0.0))),
		UiKit.number(float(attack.get("damage", 0.0)), 0),
		UiKit.number(float(attack.get("knockback", 0.0)), 0),
		UiKit.seconds(float(attack.get("cooldown", 0.0)), 1),
	]) + "\n"

	var element := int(attack.get("element", Elements.Element.NEUTRAL)) as Elements.Element
	if element != Elements.Element.NEUTRAL:
		text += "   " + _dim("Elemento %s: aplica %s." % [
			Elements.display_name(element), Elements.affliction_name(element)
		]) + "\n"

	if bool(attack.get("telegraph", true)):
		text += "   " + _dim("Telegrafia no chão: a área pintada é exatamente a área que machuca.") + "\n"
	else:
		text += "   " + _alert("Sem telegrafia: a leitura é só pela animação.") + "\n"

	var window: Dictionary = attack.get("interruptible", {})
	if window.is_empty():
		text += "   " + _dim("Interrupção: NÃO dá. Este ataque só se evita.") + "\n"
	else:
		text += "   " + _good("INTERROMPÍVEL até %s de Preparo, com um acerto de %s de Atordoamento ou mais." % [
			UiKit.seconds(float(window.get("until", 0.0))),
			UiKit.number(float(window.get("threshold", 0.0)), 0),
		]) + "\n"

	var whiff := float(attack.get("whiff_recovery_bonus", 0.0))
	if whiff > 0.0:
		text += "   " + _good("Se ele errar, a recuperação estica mais %s: é a sua janela de punição." % UiKit.seconds(whiff)) + "\n"
	return text


func _shape_text(shape: Dictionary) -> String:
	match String(shape.get("type", "")):
		Behemoths.SHAPE_CONE:
			var offset := float(shape.get("offset", 0.0))
			var where := "à frente"
			if absf(offset - PI) < 0.1:
				where = "para TRÁS"
			elif absf(offset) > 0.1:
				where = "deslocado %s" % UiKit.degrees(offset)
			return "cone de %s cm, abertura %s, %s" % [
				UiKit.number(float(shape.get("range", 0.0)), 0),
				UiKit.degrees(float(shape.get("arc", 0.0))), where,
			]
		Behemoths.SHAPE_CIRCLE:
			return "círculo de %s cm ao redor dele" % UiKit.number(float(shape.get("range", 0.0)), 0)
		Behemoths.SHAPE_DASH:
			return "corredor de %s cm de comprimento por %s cm de largura" % [
				UiKit.number(float(shape.get("range", 0.0)), 0),
				UiKit.number(float(shape.get("width", 0.0)), 0),
			]
	return "área não declarada"
