class_name ElementWheel
extends Control

## A roda de Oposição desenhada: os seis Elementos com oposto, cada par ligado
## pela linha que atravessa o centro, e o Neutro no meio sem ligação nenhuma.
##
## A ordem no círculo é escolhida para que cada par caia em pontas DIAMETRAIS:
## ver o oposto é olhar para o outro lado da roda, não procurar numa tabela.
##
## Os Elementos e as cores vêm de `Elements`; esta classe não guarda nenhum.

const RADIUS: float = 108.0

## Os rótulos moram num anel maior que as bolas, senão o nome cobre a cor.
const LABEL_RADIUS: float = 152.0
const NODE_RADIUS: float = 15.0
const HEIGHT: float = 380.0

const LINE_COLOR := Color("31414e")

## Posições na roda: BLAZE em cima, e o oposto dele (FROST) embaixo; SHOCK
## contra TERRA e RADIANT contra UMBRAL pelas outras duas diagonais.
const ORDER: Array = [
	Elements.Element.BLAZE,
	Elements.Element.SHOCK,
	Elements.Element.RADIANT,
	Elements.Element.FROST,
	Elements.Element.TERRA,
	Elements.Element.UMBRAL,
]

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(0.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var centre := Vector2(size.x * 0.5, HEIGHT * 0.5)
	var half := int(ORDER.size() / 2)

	# As linhas de Oposição primeiro, para passarem por baixo das bolas.
	for i in half:
		draw_line(_point(centre, i), _point(centre, i + half), LINE_COLOR, 2.0)
	draw_arc(centre, RADIUS, 0.0, TAU, 72, UiKit.PANEL_EDGE, 1.0)

	# Neutro no meio: sem oposto, sem linha. O disco de fundo abre espaço para
	# o rótulo dele em cima das linhas que se cruzam ali.
	draw_circle(centre, NODE_RADIUS * 2.6, UiKit.PANEL)
	draw_circle(centre, NODE_RADIUS * 0.8, Elements.color(Elements.Element.NEUTRAL))
	_text(centre + Vector2(0.0, NODE_RADIUS + 12.0), "Neutro", UiKit.DIM)
	_text(centre + Vector2(0.0, NODE_RADIUS + 26.0), "sem oposto", UiKit.DIM, 11)

	for i in ORDER.size():
		var element: Elements.Element = ORDER[i]
		var at := _point(centre, i)
		var color := Elements.color(element)
		draw_circle(at, NODE_RADIUS, color)
		draw_arc(at, NODE_RADIUS, 0.0, TAU, 32, UiKit.BACKGROUND, 2.0)

		var label_at := _point(centre, i, LABEL_RADIUS)
		_text(label_at + Vector2(0.0, -2.0), Elements.display_name(element), color)
		_text(label_at + Vector2(0.0, 12.0), Elements.affliction_name(element), UiKit.DIM, 11)


func _point(centre: Vector2, index: int, radius: float = RADIUS) -> Vector2:
	var angle := -PI * 0.5 + TAU * float(index) / float(ORDER.size())
	return centre + Vector2(cos(angle), sin(angle)) * radius


func _text(at: Vector2, text: String, color: Color, font_size: int = 13) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(
		_font, at - Vector2(width * 0.5, 0.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color
	)
