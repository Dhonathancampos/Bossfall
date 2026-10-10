class_name Hud3D
extends CanvasLayer

## O HUD da Arena 3D: barras do Caçador local, Vida do Behemoth e o texto de
## estado. UI é UI — continua 2D por cima da cena, lendo o NetGame.

const HUD_COLOR := Color("aebccb")
const BAR_BACK := Color(0.08, 0.1, 0.13, 0.85)
const BAR_EDGE := Color(0.25, 0.3, 0.36, 1.0)
const HP_COLOR := Color("e2574c")
const HP_LOW := Color("ffb347")
const STAMINA_COLOR := Color("8de08a")
const STAMINA_LOW := Color("e0a85a")
const AETHER_COLOR := Color("8fb6ff")
const AETHER_FULL := Color("d8e4ff")
const BEHEMOTH_HP := Color("c9544a")
const STAGGER_COLOR := Color("f2d249")
const PART_COLOR := Color("b9a06a")
const PART_BROKEN_COLOR := Color("6e6253")
const ENRAGE_COLOR := Color("ff8a5c")

## O aviso de interrupção pisca em verde: é a única cor do HUD que significa
## "faça alguma coisa AGORA", e precisa ser lida no canto do olho.
const INTERRUPT_COLOR := Color("8de08a")

const BAR_WIDTH: float = 320.0
const BAR_HEIGHT: float = 12.0

var _net: NetGame
var _canvas: Control
var _status: Label
var _font: Font

## Relógio só da piscada do aviso de interrupção. Nada da Sim depende dele.
var _blink: float = 0.0


func setup(net: NetGame) -> void:
	_net = net


func _ready() -> void:
	_font = ThemeDB.fallback_font

	_status = Label.new()
	_status.position = Vector2(18.0, 14.0)
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", HUD_COLOR)
	add_child(_status)

	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)


func _process(delta: float) -> void:
	if _net == null or not _net.is_running():
		return
	_blink += delta
	_status.text = _status_text()
	_canvas.queue_redraw()


func _draw_hud() -> void:
	var mine := _local_hunter()
	if mine.is_empty():
		return

	var viewport := _canvas.get_viewport_rect().size
	var origin := Vector2((viewport.x - BAR_WIDTH) * 0.5, viewport.y - 42.0)

	var hp := clampf(float(mine.get("hp", 0.0)) / SimConfig.HUNTER_MAX_HP, 0.0, 1.0)
	_bar(origin - Vector2(0.0, BAR_HEIGHT + 8.0), hp, HP_LOW if hp < 0.3 else HP_COLOR, "Vida")

	var stamina := clampf(float(mine.get("stamina", 0.0)) / SimConfig.STAMINA_MAX, 0.0, 1.0)
	_bar(origin, stamina, STAMINA_LOW if stamina < 0.3 else STAMINA_COLOR, "Fôlego")

	var aether := clampf(float(mine.get("aether", 0.0)) / SimConfig.AETHER_MAX, 0.0, 1.0)
	_bar(
		origin + Vector2(0.0, BAR_HEIGHT + 8.0),
		aether,
		AETHER_FULL if aether >= 1.0 else AETHER_COLOR,
		"Éter"
	)

	_weapon_resources(mine, origin)
	_afflictions(mine, origin, viewport)
	_behemoth_bar(viewport)
	_interrupt_banner(viewport)


## O aviso que fecha o ciclo com o Aprenda: lá o jogador leu QUAIS ataques dão
## para interromper; aqui ele vê QUANDO. Sem isto a interrupção só é
## descoberta por acidente.
func _interrupt_banner(viewport: Vector2) -> void:
	var notice := _interrupt_notice(_net.view_behemoth())
	if notice.is_empty():
		return

	# Piscada lenta: chama o olho sem virar estroboscópio no meio da luta.
	var pulse := 0.65 + 0.35 * sin(_blink * 7.0)
	var color := INTERRUPT_COLOR
	color.a = pulse

	var width := _font.get_string_size(notice, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24).x
	var at := Vector2((viewport.x - width) * 0.5, viewport.y * 0.22)
	_canvas.draw_rect(
		Rect2(at - Vector2(12.0, 22.0), Vector2(width + 24.0, 32.0)), BAR_BACK
	)
	_canvas.draw_string(_font, at, notice, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, color)


## Verdadeiro enquanto o Behemoth está num trecho interrompível.
##
## A janela e o limiar vêm prontos do Instantâneo, da MESMA função que resolve
## o boop na Sim (`BehemothState.is_interruptible_now()`), então o aviso nunca
## pode contradizer a regra — há teste na Sim cobrando essa igualdade.
##
## A dedução local que existia aqui saiu quando o campo chegou. A tela
## "Aprenda" continua lendo `interruptible` dos dados: lá é para ENSINAR quais
## ataques aceitam boop; aqui é para AVISAR que a janela está aberta agora.
func _interrupt_notice(behemoth: Dictionary) -> String:
	if behemoth.is_empty() or not bool(behemoth.get("interrupt_window", false)):
		return ""
	var attack := Behemoths.attack(
		behemoth.get("type", Behemoths.GNASHER), behemoth.get("attack", "")
	)
	return "JANELA DE INTERRUPÇÃO — %s · impacto %d+" % [
		String(attack.get("name", "")),
		int(float(behemoth.get("interrupt_threshold", 0.0)))
	]


## Recursos da arma, ao lado das barras: as 4 munições do Martelo como
## quadrados, os 3 pips de Momentum das Lâminas como losangos. Só da SUA arma.
func _weapon_resources(mine: Dictionary, origin: Vector2) -> void:
	var weapon := String(mine.get("weapon", ""))
	var slot := origin + Vector2(BAR_WIDTH + 14.0, -2.0)

	if weapon == Weapons.HAMMER:
		var ammo := int(mine.get("ammo", 0))
		for i in SimConfig.HAMMER_MAX_AMMO:
			var rect := Rect2(slot + Vector2(float(i) * 17.0, 0.0), Vector2(13.0, 13.0))
			_canvas.draw_rect(rect, STAMINA_COLOR if i < ammo else BAR_BACK)
			_canvas.draw_rect(rect, BAR_EDGE, false, 1.0)
	elif weapon == Weapons.BLADES:
		var pips := int(mine.get("pips", 0))
		for i in SimConfig.MOMENTUM_MAX_PIPS:
			var centre := slot + Vector2(float(i) * 19.0 + 7.0, 7.0)
			var diamond := PackedVector2Array([
				centre + Vector2(0.0, -7.0), centre + Vector2(7.0, 0.0),
				centre + Vector2(0.0, 7.0), centre + Vector2(-7.0, 0.0),
			])
			if i < pips:
				_canvas.draw_colored_polygon(diamond, AETHER_COLOR)
			var outline := diamond
			outline.append(diamond[0])
			_canvas.draw_polyline(outline, BAR_EDGE, 1.0)


## Fichas das Aflições ativas sobre as barras, cada uma com a cor do Elemento
## e os segundos restantes — a resposta de "por que estou jogando pior".
func _afflictions(mine: Dictionary, origin: Vector2, viewport: Vector2) -> void:
	var active: Dictionary = mine.get("afflictions", {})
	if active.is_empty():
		return

	var chip := origin + Vector2(0.0, -(BAR_HEIGHT + 8.0) * 2.0 - 16.0)
	for key in active.keys():
		var element := int(key) as Elements.Element
		var text := "%s %.0fs" % [Elements.affliction_name(element), ceilf(float(active[key]))]
		var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x + 12.0
		_canvas.draw_rect(Rect2(chip, Vector2(width, 18.0)), BAR_BACK)
		_canvas.draw_rect(Rect2(chip, Vector2(width, 18.0)), Elements.color(element), false, 1.0)
		_canvas.draw_string(
			_font, chip + Vector2(6.0, 13.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Elements.color(element)
		)
		chip.x += width + 6.0

	# A Cegueira escurece as bordas da visão: jogável, mas desconfortável.
	if int(Elements.Element.RADIANT) in active:
		var veil := Color(0.0, 0.0, 0.0, 0.62)
		var hole_width := viewport.x * 0.30
		var hole_height := viewport.y * 0.30
		var cx := (viewport.x - hole_width) * 0.5
		var cy := (viewport.y - hole_height) * 0.5
		_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(viewport.x, cy)), veil)
		_canvas.draw_rect(Rect2(Vector2(0.0, cy + hole_height), Vector2(viewport.x, viewport.y - cy - hole_height)), veil)
		_canvas.draw_rect(Rect2(Vector2(0.0, cy), Vector2(cx, hole_height)), veil)
		_canvas.draw_rect(Rect2(Vector2(cx + hole_width, cy), Vector2(viewport.x - cx - hole_width, hole_height)), veil)


func _bar(origin: Vector2, fraction: float, color: Color, label: String) -> void:
	_canvas.draw_rect(Rect2(origin, Vector2(BAR_WIDTH, BAR_HEIGHT)), BAR_BACK)
	_canvas.draw_rect(Rect2(origin, Vector2(BAR_WIDTH * fraction, BAR_HEIGHT)), color)
	_canvas.draw_rect(Rect2(origin, Vector2(BAR_WIDTH, BAR_HEIGHT)), BAR_EDGE, false, 1.0)
	_canvas.draw_string(
		_font, origin + Vector2(-58.0, BAR_HEIGHT - 1.0), label,
		HORIZONTAL_ALIGNMENT_RIGHT, 52.0, 12, HUD_COLOR
	)


func _behemoth_bar(viewport: Vector2) -> void:
	var behemoth := _net.view_behemoth()
	if behemoth.is_empty():
		return

	var width := viewport.x * 0.42
	var origin := Vector2((viewport.x - width) * 0.5, 26.0)
	var fraction := clampf(float(behemoth["hp"]) / maxf(1.0, float(behemoth["max_hp"])), 0.0, 1.0)

	_canvas.draw_rect(Rect2(origin, Vector2(width, 16.0)), BAR_BACK)
	_canvas.draw_rect(Rect2(origin, Vector2(width * fraction, 16.0)), BEHEMOTH_HP)
	_canvas.draw_rect(Rect2(origin, Vector2(width, 16.0)), BAR_EDGE, false, 1.0)

	var title := Behemoths.display_name(behemoth.get("type", Behemoths.GNASHER))
	var enraged: bool = behemoth.get("enraged", false)
	if enraged:
		title += "  ·  EM FÚRIA"
	if int(behemoth.get("state", 0)) == int(BehemothState.State.STAGGERED):
		title += "  ·  CAÍDO"
	_canvas.draw_string(
		_font, origin + Vector2(0.0, -6.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, ENRAGE_COLOR if enraged else HUD_COLOR
	)

	# Medidor de Atordoamento, fino, logo abaixo da Vida.
	var threshold := maxf(1.0, float(behemoth.get("stagger_threshold", 1.0)))
	var stagger := clampf(float(behemoth.get("stagger", 0.0)) / threshold, 0.0, 1.0)
	var stagger_origin := origin + Vector2(0.0, 20.0)
	_canvas.draw_rect(Rect2(stagger_origin, Vector2(width, 6.0)), BAR_BACK)
	_canvas.draw_rect(Rect2(stagger_origin, Vector2(width * stagger, 6.0)), STAGGER_COLOR)
	_canvas.draw_rect(Rect2(stagger_origin, Vector2(width, 6.0)), BAR_EDGE, false, 1.0)

	# As Partes, pequenas, à direita da barra.
	var part_origin := origin + Vector2(width + 14.0, 0.0)
	for part in behemoth.get("parts", []):
		var broken: bool = part["broken"]
		var part_fraction := 0.0 if broken else clampf(float(part["hp"]) / maxf(1.0, float(part["max_hp"])), 0.0, 1.0)
		_canvas.draw_rect(Rect2(part_origin, Vector2(90.0, 8.0)), BAR_BACK)
		_canvas.draw_rect(Rect2(part_origin, Vector2(90.0 * part_fraction, 8.0)), PART_COLOR)
		_canvas.draw_rect(Rect2(part_origin, Vector2(90.0, 8.0)), BAR_EDGE, false, 1.0)
		var label: String = part["name"]
		if broken:
			label += " ✕"
		_canvas.draw_string(
			_font, part_origin + Vector2(94.0, 8.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11,
			PART_BROKEN_COLOR if broken else HUD_COLOR
		)
		part_origin.y += 13.0

	if float(behemoth.get("enrage_flash", 0.0)) > 0.0:
		var text := "O %s ENTROU EM FÚRIA" % Behemoths.display_name(behemoth.get("type", Behemoths.GNASHER))
		var text_width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28).x
		_canvas.draw_string(
			_font, Vector2((viewport.x - text_width) * 0.5, viewport.y * 0.3), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, ENRAGE_COLOR
		)


func _local_hunter() -> Dictionary:
	for hunter in _net.view_hunters():
		if hunter["id"] == _net.local_id:
			return hunter
	return {}


func _status_text() -> String:
	var lines: Array[String] = []
	if _net.is_training:
		lines.append("ÁREA DE TREINAMENTO")
		lines.append("Boneco infinito · teste golpes, combos, esquivas e alcance")
	elif _net.is_host:
		var addresses := NetGame.local_addresses()
		var where := addresses[0] if not addresses.is_empty() else "este computador"
		lines.append("Hospedando — peça para entrarem em %s:%d" % [where, NetGame.DEFAULT_PORT])
	else:
		lines.append("Conectado ao Anfitrião")
	lines.append("Caçadores: %d/%d" % [_net.hunter_count(), NetGame.MAX_HUNTERS])
	lines.append("WASD mover · Mouse câmera · Botões golpes · Shift correr · Espaço rolar · Esc sair")

	var behemoth := _net.view_behemoth()
	if not behemoth.is_empty() and int(behemoth.get("state", 0)) == int(BehemothState.State.DEAD):
		lines.append("")
		lines.append("O Behemoth caiu.")
	return "\n".join(lines)
