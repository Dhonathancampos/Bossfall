class_name BrowseScreen
extends Control

## Buscar partida: as salas achadas na rede local, mais a entrada manual por
## endereço e o botão de abrir a sua própria sala.
##
## A entrada manual fica SEMPRE visível, não escondida atrás de um "avançado":
## a descoberta por broadcast só alcança a rede local, e jogar com alguém de
## fora dela é exatamente o caso em que digitar o endereço é a única saída.
##
## Quem fala UDP é o LanDiscovery; esta tela só desenha o que ele achou.

signal host_requested(room_name: String)
signal join_requested(address: String, port: int)
signal back_requested

const ROW_HEIGHT: float = 46.0

var _discovery: LanDiscovery
var _rooms_box: VBoxContainer
var _empty_note: Label
var _room_field: LineEdit
var _address_field: LineEdit
var _message: Label
var _first_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.fill_background(self)

	_discovery = LanDiscovery.new()
	_discovery.name = "LanDiscovery"
	_discovery.rooms_changed.connect(_refresh_rooms)
	add_child(_discovery)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(560.0, 0.0)
	centre.add_child(column)

	column.add_child(UiKit.label("BUSCAR PARTIDA", UiKit.SIZE_HEADING, UiKit.TITLE))
	column.add_child(UiKit.label(
		"Salas abertas na sua rede local. Procurando…", UiKit.SIZE_SMALL, UiKit.DIM
	))
	column.add_child(UiKit.spacer(6))

	var rooms_panel := UiKit.panel()
	column.add_child(rooms_panel)
	_rooms_box = VBoxContainer.new()
	_rooms_box.add_theme_constant_override("separation", 4)
	_rooms_box.custom_minimum_size = Vector2(0.0, 150.0)
	rooms_panel.add_child(_rooms_box)

	_empty_note = UiKit.label(
		"Nenhuma sala encontrada ainda.", UiKit.SIZE_BODY, UiKit.DIM
	)
	_rooms_box.add_child(_empty_note)

	column.add_child(UiKit.spacer(10))
	column.add_child(UiKit.label(
		"Fora da rede local? Entre pelo endereço:", UiKit.SIZE_SMALL, UiKit.TEXT
	))

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	column.add_child(join_row)

	_address_field = LineEdit.new()
	_address_field.placeholder_text = "endereço do Anfitrião"
	_address_field.text = "127.0.0.1"
	_address_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address_field.text_submitted.connect(func(_t: String) -> void: _on_manual_join())
	join_row.add_child(_address_field)

	var join_button := UiKit.button("Entrar", 0.0)
	join_button.custom_minimum_size = Vector2(120.0, 0.0)
	join_button.pressed.connect(_on_manual_join)
	join_row.add_child(join_button)

	column.add_child(UiKit.spacer(14))
	column.add_child(UiKit.label("Ou abra a sua sala:", UiKit.SIZE_SMALL, UiKit.TEXT))

	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 8)
	column.add_child(host_row)

	_room_field = LineEdit.new()
	_room_field.placeholder_text = "nome da sala"
	_room_field.max_length = 24
	_room_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_row.add_child(_room_field)

	var host_button := UiKit.button("Hospedar", 0.0)
	host_button.custom_minimum_size = Vector2(120.0, 0.0)
	host_button.pressed.connect(
		func() -> void: host_requested.emit(_room_field.text.strip_edges())
	)
	host_row.add_child(host_button)
	_first_button = host_button

	column.add_child(UiKit.spacer(12))
	_message = UiKit.wrapped_label("", UiKit.SIZE_SMALL, UiKit.ERROR)
	column.add_child(_message)

	var addresses := NetGame.local_addresses()
	if not addresses.is_empty():
		column.add_child(UiKit.label(
			"Esta máquina: " + ", ".join(addresses), UiKit.SIZE_SMALL, UiKit.DIM
		))

	column.add_child(UiKit.spacer(8))
	var back := UiKit.button("Voltar (Esc)", 34.0)
	back.pressed.connect(func() -> void: back_requested.emit())
	column.add_child(back)

	var error := _discovery.listen()
	if not error.is_empty():
		set_message(error)
	host_button.grab_focus()


func set_room_name(value: String) -> void:
	if _room_field != null:
		_room_field.text = value


func set_message(text: String) -> void:
	if _message != null:
		_message.text = text


func _on_manual_join() -> void:
	var address := _address_field.text.strip_edges()
	if address.is_empty():
		set_message("Digite o endereço do Anfitrião.")
		return
	join_requested.emit(address, NetGame.DEFAULT_PORT)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			back_requested.emit()
			accept_event()


func _refresh_rooms() -> void:
	for child in _rooms_box.get_children():
		if child != _empty_note:
			child.queue_free()

	var rooms := _discovery.rooms()
	_empty_note.visible = rooms.is_empty()

	for room in rooms:
		var address := String(room.get("address", ""))
		var port := int(room.get("port", NetGame.DEFAULT_PORT))
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s  ·  %d/%d Caçadores  ·  %s (%s)  ·  %s" % [
			String(room.get("room", "Sala")),
			int(room.get("hunters", 1)), int(room.get("max", NetGame.MAX_HUNTERS)),
			String(room.get("behemoth_name", "?")),
			String(room.get("variant", "Neutro")),
			address,
		]
		button.disabled = int(room.get("hunters", 0)) >= int(room.get("max", NetGame.MAX_HUNTERS))
		button.pressed.connect(func() -> void: join_requested.emit(address, port))
		_rooms_box.add_child(button)
