class_name MenuScreen
extends Control

## Tela inicial: Hospedar ou Entrar.
##
## Montada em código em vez de .tscn porque é uma tela só e o layout cabe numa
## leitura. Nenhuma regra de jogo mora aqui — ela só emite o que o jogador
## pediu.

signal host_requested(display_name: String, weapon_id: String, weapon_element: int, behemoth_element: int, behemoth_type: String)
signal join_requested(address: String, display_name: String, weapon_id: String, weapon_element: int)
signal training_requested(display_name: String, weapon_id: String, weapon_element: int)

const BACKGROUND := Color("0b0e12")
const TITLE_COLOR := Color("7fd4ff")
const TEXT_COLOR := Color("aebccb")
const DIM_COLOR := Color("5d6b7a")
const ERROR_COLOR := Color("ff8f7a")

var _name_field: LineEdit
var _address_field: LineEdit
var _weapon_picker: OptionButton
var _element_picker: OptionButton
var _behemoth_picker: OptionButton
var _behemoth_type_picker: OptionButton
var _message: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size = Vector2(420.0, 0.0)
	centre.add_child(column)

	column.add_child(_label("DAUNTLESS LITE", 34, TITLE_COLOR))
	column.add_child(_label("Quem hospeda é o servidor.", 14, DIM_COLOR))
	column.add_child(_spacer(14))

	column.add_child(_label("Seu nome", 13, TEXT_COLOR))
	_name_field = LineEdit.new()
	_name_field.text = "Caçador"
	_name_field.max_length = 16
	column.add_child(_name_field)

	column.add_child(_spacer(10))

	# Seleção provisória de arma; o lobby de verdade chega no ticket 10.
	column.add_child(_label("Sua arma", 13, TEXT_COLOR))
	_weapon_picker = OptionButton.new()
	for weapon_id in Weapons.ids():
		_weapon_picker.add_item(Weapons.display_name(weapon_id))
		_weapon_picker.set_item_metadata(_weapon_picker.item_count - 1, weapon_id)
	_weapon_picker.select(0)
	column.add_child(_weapon_picker)

	column.add_child(_spacer(6))
	column.add_child(_label("Elemento da arma", 13, TEXT_COLOR))
	_element_picker = _make_element_picker()
	column.add_child(_element_picker)

	column.add_child(_spacer(6))
	column.add_child(_label("Behemoth (só o Anfitrião decide)", 13, TEXT_COLOR))
	_behemoth_type_picker = OptionButton.new()
	for type_id in Behemoths.ids():
		_behemoth_type_picker.add_item(Behemoths.display_name(type_id))
		_behemoth_type_picker.set_item_metadata(_behemoth_type_picker.item_count - 1, type_id)
	_behemoth_type_picker.select(0)
	column.add_child(_behemoth_type_picker)

	column.add_child(_spacer(6))
	column.add_child(_label("Variante do Behemoth (só o Anfitrião decide)", 13, TEXT_COLOR))
	_behemoth_picker = _make_element_picker()
	column.add_child(_behemoth_picker)

	column.add_child(_spacer(10))

	var host_button := Button.new()
	host_button.text = "Hospedar"
	host_button.custom_minimum_size = Vector2(0.0, 40.0)
	host_button.pressed.connect(_on_host_pressed)
	column.add_child(host_button)

	var training_button := Button.new()
	training_button.text = "Área de treinamento"
	training_button.custom_minimum_size = Vector2(0.0, 40.0)
	training_button.pressed.connect(_on_training_pressed)
	column.add_child(training_button)

	column.add_child(_spacer(16))
	column.add_child(_label("Ou entrar no jogo de alguém", 13, TEXT_COLOR))

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	column.add_child(join_row)

	_address_field = LineEdit.new()
	_address_field.placeholder_text = "endereço do Anfitrião"
	_address_field.text = "127.0.0.1"
	_address_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address_field.text_submitted.connect(func(_t: String) -> void: _on_join_pressed())
	join_row.add_child(_address_field)

	var join_button := Button.new()
	join_button.text = "Entrar"
	join_button.custom_minimum_size = Vector2(110.0, 0.0)
	join_button.pressed.connect(_on_join_pressed)
	join_row.add_child(join_button)

	column.add_child(_spacer(14))

	_message = _label("", 13, ERROR_COLOR)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)

	var addresses := NetGame.local_addresses()
	if not addresses.is_empty():
		column.add_child(_spacer(6))
		column.add_child(_label("Esta máquina: " + ", ".join(addresses), 12, DIM_COLOR))


func set_message(text: String) -> void:
	if _message != null:
		_message.text = text


func _make_element_picker() -> OptionButton:
	var picker := OptionButton.new()
	for element in Elements.all():
		picker.add_item(Elements.display_name(element))
		picker.set_item_metadata(picker.item_count - 1, int(element))
	picker.select(0)
	return picker


func _picked_element(picker: OptionButton) -> int:
	var selected: Variant = picker.get_selected_metadata()
	return int(selected) if selected != null else 0


func _on_host_pressed() -> void:
	host_requested.emit(
		_hunter_name(), _weapon(),
		_picked_element(_element_picker), _picked_element(_behemoth_picker),
		_behemoth_type()
	)


func _on_training_pressed() -> void:
	training_requested.emit(_hunter_name(), _weapon(), _picked_element(_element_picker))


func _behemoth_type() -> String:
	var selected: Variant = _behemoth_type_picker.get_selected_metadata()
	return String(selected) if selected != null else Behemoths.GNASHER


func _on_join_pressed() -> void:
	var address := _address_field.text.strip_edges()
	if address.is_empty():
		set_message("Digite o endereço do Anfitrião.")
		return
	join_requested.emit(address, _hunter_name(), _weapon(), _picked_element(_element_picker))


func _weapon() -> String:
	var selected: Variant = _weapon_picker.get_selected_metadata()
	return String(selected) if selected != null else Weapons.SWORD


func _hunter_name() -> String:
	var typed := _name_field.text.strip_edges()
	return typed if not typed.is_empty() else "Caçador"


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	return spacer
