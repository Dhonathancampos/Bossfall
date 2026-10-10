class_name LobbyScreen
extends Control

## A sala, depois de hospedar ou entrar.
##
## Cada Caçador escolhe a própria arma e o próprio Elemento AQUI (saiu do menu
## inicial) e marca Pronto; o Anfitrião escolhe o Behemoth e a variante e
## começa a Caçada. A dica de Oposição fica à vista enquanto a escolha está
## sendo feita — é o momento em que ela importa.
##
## Enquanto o Anfitrião está na sala, esta tela também anuncia a sala na rede
## local pelo LanDiscovery; sair da tela cala o anúncio, e por isso uma sala em
## Caçada não aparece mais na busca.

signal start_requested
signal learn_requested
signal leave_requested

const ADVERTISE_EVERY: float = 1.0

var _net: NetGame
var _discovery: LanDiscovery
var _advertise_countdown: float = 0.0

var _heading: Label
var _subtitle: Label
var _hunters_box: VBoxContainer
var _weapon_picker: OptionButton
var _element_picker: OptionButton
var _behemoth_picker: OptionButton
var _variant_picker: OptionButton
var _host_box: VBoxContainer
var _tip: Label
var _ready_button: Button
var _start_button: Button
var _message: Label


func setup(net: NetGame) -> void:
	_net = net


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.fill_background(self)

	_discovery = LanDiscovery.new()
	_discovery.name = "LanDiscovery"
	add_child(_discovery)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(900.0, 0.0)
	centre.add_child(column)

	_heading = UiKit.label("SALA", UiKit.SIZE_HEADING, UiKit.TITLE)
	column.add_child(_heading)
	_subtitle = UiKit.label("", UiKit.SIZE_SMALL, UiKit.DIM)
	column.add_child(_subtitle)
	column.add_child(UiKit.spacer(8))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	column.add_child(columns)

	columns.add_child(_build_hunters())
	columns.add_child(_build_choices())

	column.add_child(UiKit.spacer(10))
	_tip = UiKit.wrapped_label("", UiKit.SIZE_BODY, UiKit.ACCENT)
	column.add_child(_tip)

	column.add_child(UiKit.spacer(8))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)

	_ready_button = UiKit.button("Pronto")
	_ready_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ready_button.pressed.connect(_on_ready_pressed)
	buttons.add_child(_ready_button)

	_start_button = UiKit.button("Iniciar Caçada")
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_button.pressed.connect(func() -> void: start_requested.emit())
	buttons.add_child(_start_button)

	var learn := UiKit.button("Aprenda")
	learn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	learn.pressed.connect(func() -> void: learn_requested.emit())
	buttons.add_child(learn)

	var leave := UiKit.button("Sair da sala (Esc)")
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(func() -> void: leave_requested.emit())
	buttons.add_child(leave)

	column.add_child(UiKit.spacer(8))
	_message = UiKit.wrapped_label("", UiKit.SIZE_SMALL, UiKit.ERROR)
	column.add_child(_message)

	if _net != null:
		_net.lobby_changed.connect(refresh)
		_push_loadout()
	refresh()
	_ready_button.grab_focus()


func _exit_tree() -> void:
	if _discovery != null:
		_discovery.stop_advertising()


func set_message(text: String) -> void:
	if _message != null:
		_message.text = text


func _build_hunters() -> Control:
	var panel := UiKit.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	box.add_child(UiKit.label("CAÇADORES", UiKit.SIZE_SMALL, UiKit.DIM))
	_hunters_box = VBoxContainer.new()
	_hunters_box.add_theme_constant_override("separation", 4)
	_hunters_box.custom_minimum_size = Vector2(430.0, 180.0)
	box.add_child(_hunters_box)
	return panel


func _build_choices() -> Control:
	var panel := UiKit.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	box.add_child(UiKit.label("SUA ESCOLHA", UiKit.SIZE_SMALL, UiKit.DIM))

	box.add_child(UiKit.label("Arma", UiKit.SIZE_SMALL, UiKit.TEXT))
	_weapon_picker = OptionButton.new()
	for weapon_id in Weapons.ids():
		_weapon_picker.add_item(Weapons.display_name(weapon_id))
		_weapon_picker.set_item_metadata(_weapon_picker.item_count - 1, weapon_id)
	_weapon_picker.select(0)
	_weapon_picker.item_selected.connect(func(_i: int) -> void: _push_loadout())
	box.add_child(_weapon_picker)

	box.add_child(UiKit.label("Elemento da arma", UiKit.SIZE_SMALL, UiKit.TEXT))
	_element_picker = _make_element_picker()
	_element_picker.item_selected.connect(func(_i: int) -> void: _push_loadout())
	box.add_child(_element_picker)

	_host_box = VBoxContainer.new()
	_host_box.add_theme_constant_override("separation", 6)
	box.add_child(_host_box)

	_host_box.add_child(UiKit.spacer(8))
	_host_box.add_child(UiKit.label("A CAÇA (só o Anfitrião)", UiKit.SIZE_SMALL, UiKit.DIM))

	_host_box.add_child(UiKit.label("Behemoth", UiKit.SIZE_SMALL, UiKit.TEXT))
	_behemoth_picker = OptionButton.new()
	for type_id in Behemoths.ids():
		_behemoth_picker.add_item(Behemoths.display_name(type_id))
		_behemoth_picker.set_item_metadata(_behemoth_picker.item_count - 1, type_id)
	_behemoth_picker.select(0)
	_behemoth_picker.item_selected.connect(func(_i: int) -> void: _push_hunt_settings())
	_host_box.add_child(_behemoth_picker)

	_host_box.add_child(UiKit.label("Variante elemental", UiKit.SIZE_SMALL, UiKit.TEXT))
	_variant_picker = _make_element_picker()
	_variant_picker.item_selected.connect(func(_i: int) -> void: _push_hunt_settings())
	_host_box.add_child(_variant_picker)

	return panel


func _make_element_picker() -> OptionButton:
	var picker := OptionButton.new()
	for element in Elements.all():
		picker.add_item(Elements.display_name(element))
		picker.set_item_metadata(picker.item_count - 1, int(element))
	picker.select(0)
	return picker


func _picked(picker: OptionButton) -> Variant:
	return picker.get_selected_metadata()


func _push_loadout() -> void:
	if _net == null:
		return
	var weapon: Variant = _picked(_weapon_picker)
	var element: Variant = _picked(_element_picker)
	_net.set_loadout(
		String(weapon) if weapon != null else Weapons.SWORD,
		(int(element) if element != null else 0) as Elements.Element
	)


func _push_hunt_settings() -> void:
	if _net == null or not _net.is_host:
		return
	var type_id: Variant = _picked(_behemoth_picker)
	var element: Variant = _picked(_variant_picker)
	_net.set_hunt_settings(
		String(type_id) if type_id != null else Behemoths.GNASHER,
		(int(element) if element != null else 0) as Elements.Element
	)


func _on_ready_pressed() -> void:
	if _net == null:
		return
	var mine := _net.lobby_entry(_net.local_id)
	_net.set_ready(not bool(mine.get("ready", false)))


## Desenha a sala inteira de novo. Barato: no máximo 4 linhas.
func refresh() -> void:
	if _net == null or _hunters_box == null:
		return

	_heading.text = "SALA — %s" % _net.room_name
	_subtitle.text = _where_text()

	for child in _hunters_box.get_children():
		child.queue_free()

	var variant := _net.behemoth_element as Elements.Element
	var wanted := Elements.strong_against(variant)
	for entry in _net.lobby_entries():
		_hunters_box.add_child(_hunter_row(entry, wanted, variant))

	_host_box.visible = _net.is_host
	_start_button.visible = _net.is_host
	_start_button.disabled = not _net.everyone_ready()

	var mine := _net.lobby_entry(_net.local_id)
	_ready_button.text = "Pronto ✔" if bool(mine.get("ready", false)) else "Pronto"
	_sync_pickers(mine)
	_tip.text = _tip_text(variant)


## Os seletores seguem a verdade da sala (ex.: o Anfitrião trocou o Behemoth)
## sem disparar de volta o sinal que acabaria em eco de rede.
func _sync_pickers(mine: Dictionary) -> void:
	_select_by_metadata(_weapon_picker, mine.get("weapon", Weapons.SWORD))
	_select_by_metadata(_element_picker, int(mine.get("element", 0)))
	_select_by_metadata(_behemoth_picker, _net.behemoth_type)
	_select_by_metadata(_variant_picker, _net.behemoth_element)


func _select_by_metadata(picker: OptionButton, value: Variant) -> void:
	for i in picker.item_count:
		if picker.get_item_metadata(i) == value:
			if picker.selected != i:
				picker.select(i)
			return


func _hunter_row(entry: Dictionary, wanted: Elements.Element, variant: Elements.Element) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var who: String = entry.get("name", "Caçador")
	if bool(entry.get("is_host", false)):
		who += " (Anfitrião)"
	if bool(entry.get("is_me", false)):
		who += " — você"
	var name_label := UiKit.label(who, UiKit.SIZE_BODY, UiKit.TEXT)
	name_label.custom_minimum_size = Vector2(250.0, 0.0)
	row.add_child(name_label)

	var weapon_label := UiKit.label(
		Weapons.display_name(entry.get("weapon", Weapons.SWORD)), UiKit.SIZE_BODY, UiKit.DIM
	)
	weapon_label.custom_minimum_size = Vector2(120.0, 0.0)
	row.add_child(weapon_label)

	var element := int(entry.get("element", 0)) as Elements.Element
	var element_text := Elements.display_name(element)
	if element != Elements.Element.NEUTRAL and element == wanted:
		element_text += " ✔"
	elif element != Elements.Element.NEUTRAL and element == variant:
		element_text += " ✘"
	var element_label := UiKit.label(element_text, UiKit.SIZE_BODY, Elements.color(element))
	element_label.custom_minimum_size = Vector2(90.0, 0.0)
	row.add_child(element_label)

	var is_ready := bool(entry.get("ready", false))
	row.add_child(UiKit.label(
		"PRONTO" if is_ready else "escolhendo…",
		UiKit.SIZE_SMALL, UiKit.OK if is_ready else UiKit.DIM
	))
	return row


func _tip_text(variant: Elements.Element) -> String:
	var beast := Behemoths.display_name(_net.behemoth_type)
	if variant == Elements.Element.NEUTRAL:
		return "Dica: %s Neutro não tem Oposição — nenhum Elemento ganha nem perde dano contra ele." % beast
	var wanted := Elements.strong_against(variant)
	return "Dica: %s %s sofre %s. Arma de %s causa +%d%% de dano; arma de %s causa −%d%%." % [
		beast, Elements.display_name(variant), Elements.affliction_name(variant),
		Elements.display_name(wanted),
		int(roundf((Elements.OPPOSITION_BONUS - 1.0) * 100.0)),
		Elements.display_name(variant),
		int(roundf((1.0 - Elements.SAME_ELEMENT_PENALTY) * 100.0)),
	]


func _where_text() -> String:
	if _net.is_host:
		var addresses := NetGame.local_addresses()
		var where := addresses[0] if not addresses.is_empty() else "este computador"
		return "Você hospeda. Quem estiver na mesma rede acha a sala sozinho; de fora, o endereço é %s:%d." % [
			where, NetGame.DEFAULT_PORT
		]
	return "Conectado ao Anfitrião. Ele escolhe o Behemoth e começa a Caçada."


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			leave_requested.emit()
			accept_event()


## O anúncio na rede local é refeito de segundo em segundo porque a contagem
## de Caçadores e a escolha do Behemoth mudam enquanto a sala está aberta.
func _process(delta: float) -> void:
	if _net == null or not _net.is_host or _net.phase != NetGame.Phase.LOBBY:
		if _discovery.is_advertising():
			_discovery.stop_advertising()
		return
	_advertise_countdown -= delta
	if _advertise_countdown > 0.0 and _discovery.is_advertising():
		return
	_advertise_countdown = ADVERTISE_EVERY
	_discovery.advertise(_net.announcement())
