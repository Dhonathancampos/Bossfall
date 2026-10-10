class_name MenuScreen
extends Control

## Tela inicial. Quatro caminhos: Buscar partida, Área de treinamento,
## Aprenda e Sair.
##
## O lobby virou o ponto de entrada das duas coisas que existem (Caçada e
## treinamento), então a escolha de arma, Elemento e Behemoth saiu daqui: ela
## acontece na sala, onde todo mundo vê a escolha de todo mundo.
##
## Montada em código em vez de .tscn porque é uma tela só e o layout cabe numa
## leitura. Nenhuma regra de jogo mora aqui — ela só emite o que o jogador
## pediu.

signal search_requested(display_name: String)
signal training_requested(display_name: String)
signal learn_requested
signal quit_requested

var _name_field: LineEdit
var _message: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.fill_background(self)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size = Vector2(420.0, 0.0)
	centre.add_child(column)

	column.add_child(UiKit.label("DAUNTLESS LITE", UiKit.SIZE_TITLE, UiKit.TITLE))
	column.add_child(UiKit.label(
		"Caça cooperativa. Quem abre a sala hospeda a partida.",
		UiKit.SIZE_BODY, UiKit.DIM
	))
	column.add_child(UiKit.spacer(18))

	column.add_child(UiKit.label("Seu nome", UiKit.SIZE_SMALL, UiKit.TEXT))
	_name_field = LineEdit.new()
	_name_field.text = "Caçador"
	_name_field.max_length = 16
	column.add_child(_name_field)

	column.add_child(UiKit.spacer(14))

	var search := UiKit.button("Buscar partida")
	search.pressed.connect(func() -> void: search_requested.emit(hunter_name()))
	column.add_child(search)

	var training := UiKit.button("Área de treinamento")
	training.pressed.connect(func() -> void: training_requested.emit(hunter_name()))
	column.add_child(training)

	var learn := UiKit.button("Aprenda")
	learn.pressed.connect(func() -> void: learn_requested.emit())
	column.add_child(learn)

	var quit := UiKit.button("Sair")
	quit.pressed.connect(func() -> void: quit_requested.emit())
	column.add_child(quit)

	column.add_child(UiKit.spacer(14))
	_message = UiKit.wrapped_label("", UiKit.SIZE_SMALL, UiKit.ERROR)
	column.add_child(_message)

	search.grab_focus()


func set_message(text: String) -> void:
	if _message != null:
		_message.text = text


func hunter_name() -> String:
	var typed := _name_field.text.strip_edges()
	return typed if not typed.is_empty() else "Caçador"


func set_hunter_name(value: String) -> void:
	if _name_field != null and not value.strip_edges().is_empty():
		_name_field.text = value
