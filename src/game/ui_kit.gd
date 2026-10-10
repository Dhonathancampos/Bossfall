class_name UiKit
extends RefCounted

## Paleta e peças comuns das telas 2D (menu, busca, lobby, Aprenda).
##
## As telas são montadas em código, não em .tscn: cada uma é uma tela só e o
## layout cabe numa leitura. Este arquivo existe para que todas usem as MESMAS
## cores e os mesmos espaçamentos — coerência visual sem copiar constante.
##
## Nenhuma regra de jogo mora aqui.

const BACKGROUND := Color("0b0e12")
const PANEL := Color("131a21")
const PANEL_EDGE := Color("243039")
const TITLE := Color("7fd4ff")
const TEXT := Color("aebccb")
const DIM := Color("5d6b7a")
const ERROR := Color("ff8f7a")
const ACCENT := Color("ffcf7f")
const OK := Color("8de08a")

## Tamanhos de fonte com nome, para as telas não espalharem números soltos.
const SIZE_TITLE: int = 34
const SIZE_HEADING: int = 20
const SIZE_BODY: int = 14
const SIZE_SMALL: int = 12


static func label(text: String, size: int = SIZE_BODY, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


static func wrapped_label(text: String, size: int = SIZE_BODY, color: Color = TEXT) -> Label:
	var node := label(text, size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


static func spacer(height: float) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0.0, height)
	return node


static func button(text: String, height: float = 40.0) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0.0, height)
	node.focus_mode = Control.FOCUS_ALL
	return node


## Fundo opaco que ocupa a tela inteira e não rouba o mouse.
static func fill_background(parent: Control, color: Color = BACKGROUND) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


## Caixa com fundo e borda, para separar listas do resto da tela.
static func panel(padding: int = 12) -> PanelContainer:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = PANEL_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	box.add_theme_stylebox_override("panel", style)
	return box


## Um número para texto: 0,62 em vez de 0.62. A interface é em português.
static func number(value: float, decimals: int = 2) -> String:
	return String.num(value, decimals).replace(".", ",")


static func seconds(value: float, decimals: int = 2) -> String:
	return number(value, decimals) + " s"


## Ângulo em radianos virando graus inteiros, que é como se lê um arco.
static func degrees(radians: float) -> String:
	return "%d°" % int(roundf(rad_to_deg(radians)))
