class_name Arena3D
extends Node3D

## A Arena em 3D: apresentação pura, como o ArenaScreen era no 2D.
##
## Lê o que o NetGame deixou pronto e posiciona nós; captura teclado, mouse e
## a câmera orbital e produz Entrada. Nenhuma regra de jogo mora aqui — a Sim
## continua sem saber que a câmera existe.

signal leave_requested

## Câmera orbital em terceira pessoa.
## Afastada e um pouco alta: o monstro tem 3 m de lombo, e colar a câmera
## nele enche a tela de couro.
const CAMERA_DISTANCE: float = 7.0
const CAMERA_HEIGHT: float = 2.0
const MOUSE_SENSITIVITY: float = 0.0035
const PITCH_MIN: float = -0.9
const PITCH_MAX: float = 0.35

const HUNTER_COLORS: Array[Color] = [
	Color("7fd4ff"),
	Color("ffcf7f"),
	Color("a8ff9e"),
	Color("ff9ed6"),
]

const TELEGRAPH_FILL := Color(1.0, 0.20, 0.12, 0.38)
const TELEGRAPH_READY := Color(1.0, 0.56, 0.20, 0.72)
const TELEGRAPH_STRIKE := Color(1.0, 0.88, 0.48, 0.82)
const SWING_COLOR := Color(0.62, 0.86, 1.0, 0.3)

var _net: NetGame
var _camera: Camera3D
var _yaw: float = 0.0
var _pitch: float = -0.55

## A câmera nasce olhando para o Behemoth: a Caçada começa de frente para a
## caça, não de costas.
var _faced_hunt: bool = false

## id -> nó do Caçador na cena.
var _hunter_nodes: Dictionary = {}
## id -> nó de alvo estático (o boneco da Área de Treinamento).
var _target_nodes: Dictionary = {}
var _behemoth_node: Node3D
var _hud: Hud3D

## Formas no chão deste quadro. Recriadas a cada quadro: são baratas e o
## estado delas mora na Sim, não aqui.
var _ground_layer: Node3D

## Números de dano flutuando. {label, age}
var _damage_labels: Array[Dictionary] = []


func setup(net: NetGame) -> void:
	_net = net
	_net.events_happened.connect(_on_events)


func _ready() -> void:
	_build_arena()
	_ground_layer = Node3D.new()
	add_child(_ground_layer)

	_camera = Camera3D.new()
	add_child(_camera)
	_camera.make_current()

	_hud = Hud3D.new()
	_hud.setup(_net)
	add_child(_hud)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Cena estática ------------------------------------------------------------

func _build_arena() -> void:
	var radius := SimConfig.ARENA_RADIUS * GameWorld.SIM_TO_WORLD

	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.1
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("3a4433")
	disc.material = ground_material
	ground.mesh = disc
	ground.position.y = -0.05
	add_child(ground)

	# Anéis concêntricos dão noção de distância, como no 2D.
	for i in range(1, 6):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius * float(i) / 6.0 - 0.02
		torus.outer_radius = radius * float(i) / 6.0 + 0.02
		var ring_material := StandardMaterial3D.new()
		ring_material.albedo_color = Color("46523d")
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		torus.material = ring_material
		ring.mesh = torus
		ring.position.y = 0.01
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)

	# Parede baixa na borda: o limite é visível, não um empurrão invisível.
	var wall := MeshInstance3D.new()
	var tube := TorusMesh.new()
	tube.inner_radius = radius - 0.15
	tube.outer_radius = radius + 0.35
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color("57514a")
	tube.material = wall_material
	wall.mesh = tube
	wall.position.y = 0.3
	add_child(wall)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	add_child(sun)

	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("2c3844")
	sky.sky_horizon_color = Color("5a6673")
	sky.ground_bottom_color = Color("23282e")
	sky.ground_horizon_color = Color("4a545e")
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.sky = Sky.new()
	environment.environment.sky.sky_material = sky
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.environment.ambient_light_energy = 0.8
	add_child(environment)


## Entrada ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - motion.relative.y * MOUSE_SENSITIVITY, PITCH_MIN, PITCH_MAX)
		return

	if event is InputEventMouseButton and event.pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				_net.request_light()
			MOUSE_BUTTON_RIGHT:
				_net.request_heavy()
		return

	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_SPACE:
			_net.request_dodge()
		KEY_F:
			_net.request_special()
		KEY_R:
			_net.request_reload()
		KEY_ESCAPE:
			leave_requested.emit()


## O WASD é rotacionado pelo yaw da câmera antes de virar o vetor da Sim:
## "frente" é sempre para onde você olha, como no jogo original.
func _read_move() -> Vector2:
	var input := Vector2(_axis(KEY_D, KEY_A), _axis(KEY_S, KEY_W))
	if input == Vector2.ZERO:
		return Vector2.ZERO

	var forward := -_camera.global_transform.basis.z
	var forward_sim := Vector2(forward.x, forward.z).normalized()
	var right_sim := Vector2(-forward_sim.y, forward_sim.x)
	return (forward_sim * -input.y + right_sim * input.x).normalized()


func _axis(positive: Key, negative: Key) -> float:
	var value := 0.0
	if Input.is_physical_key_pressed(positive):
		value += 1.0
	if Input.is_physical_key_pressed(negative):
		value -= 1.0
	return value


## Quadro -------------------------------------------------------------------

func _process(delta: float) -> void:
	if _net == null or not _net.is_running():
		return

	if not _faced_hunt:
		_face_the_hunt()
	_update_camera()

	var forward := -_camera.global_transform.basis.z
	_net.set_local_input(
		_read_move(),
		GameWorld.aim_from_forward(forward),
		Input.is_key_pressed(KEY_SHIFT),
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)

	_sync_hunters(delta)
	_sync_behemoth(delta)
	_sync_targets()
	_redraw_ground()
	_age_damage_labels(delta)


func _face_the_hunt() -> void:
	var behemoth := _net.view_behemoth()
	if behemoth.is_empty():
		return
	_faced_hunt = true
	var to_beast := (behemoth["pos"] as Vector2) - _net.local_pos()
	if to_beast.length() < 1.0:
		return
	# A frente da câmera é -(sin yaw, cos yaw) no plano xz.
	_yaw = atan2(-to_beast.x, -to_beast.y)


func _update_camera() -> void:
	var anchor := GameWorld.to_world(_net.local_pos(), CAMERA_HEIGHT)
	var orbit := Vector3(
		cos(_pitch) * sin(_yaw),
		-sin(_pitch),
		cos(_pitch) * cos(_yaw)
	)
	_camera.position = anchor + orbit * CAMERA_DISTANCE
	_camera.look_at(anchor)


## Caçadores ----------------------------------------------------------------

func _sync_hunters(delta: float) -> void:
	var seen: Array[int] = []
	for hunter in _net.view_hunters():
		var id: int = hunter["id"]
		seen.append(id)
		var node: Node3D = _hunter_nodes.get(id)

		# A arma chega pela lista de Caçadores e pode mudar entre partidas:
		# se mudou, o nó renasce com o modelo certo na mão.
		var weapon: String = hunter.get("weapon", Weapons.SWORD)
		if node != null and String(node.get_meta("weapon", "")) != weapon:
			node.queue_free()
			node = null
			_hunter_nodes.erase(id)

		if node == null:
			node = _make_hunter_node(id, weapon)
			_hunter_nodes[id] = node
			add_child(node)

		node.position = GameWorld.to_world(hunter["pos"])
		node.rotation.y = GameWorld.to_yaw(hunter["facing"])
		(node.get_node("View") as HunterView).update_from(hunter, delta)

		var tag := node.get_node("Tag") as Label3D
		var label: String = hunter.get("name", "")
		if id == _net.local_id:
			label += " (você)"
		tag.text = label

	for id in _hunter_nodes.keys():
		if id not in seen:
			_hunter_nodes[id].queue_free()
			_hunter_nodes.erase(id)


## O Caçador de verdade: humanoide gerado no Blender, com a arma na mão e as
## animações seguindo o Instantâneo (HunterView cuida de tudo isso).
func _make_hunter_node(id: int, weapon: String) -> Node3D:
	var node := Node3D.new()
	node.set_meta("weapon", weapon)

	var view := HunterView.new()
	view.name = "View"
	view.setup(weapon, HUNTER_COLORS[absi(id) % HUNTER_COLORS.size()])
	node.add_child(view)

	var tag := Label3D.new()
	tag.name = "Tag"
	tag.position.y = 2.1
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 48
	tag.pixel_size = 0.004
	node.add_child(tag)
	return node


## Alvos de treino ---------------------------------------------------------

func _sync_targets() -> void:
	var seen: Array[int] = []
	for target in _net.view_targets():
		var id: int = target["id"]
		seen.append(id)
		var node: Node3D = _target_nodes.get(id)
		if node == null:
			node = _make_training_target()
			_target_nodes[id] = node
			add_child(node)

		node.position = GameWorld.to_world(target["pos"])
		var material := node.get_meta("material") as StandardMaterial3D
		material.emission_enabled = float(target.get("hit_flash", 0.0)) > 0.0
		if material.emission_enabled:
			material.emission = Color(1.0, 0.9, 0.55)

	for id in _target_nodes.keys():
		if id not in seen:
			_target_nodes[id].queue_free()
			_target_nodes.erase(id)


func _make_training_target() -> Node3D:
	return TrainingDummyView.new()


## Behemoth -----------------------------------------------------------------

## O Behemoth de verdade: criatura gerada no Blender, animada pelo estado do
## Instantâneo, com tinta elemental e cauda decepável (CreatureView cuida).
##
## O Bastião ainda não tem modelo próprio: CreatureView cai no quadrúpede como
## corpo provisório até o papel Modelos entregar o dele.
func _sync_behemoth(delta: float) -> void:
	var behemoth := _net.view_behemoth()
	if behemoth.is_empty():
		if _behemoth_node != null:
			_behemoth_node.queue_free()
			_behemoth_node = null
		return

	if _behemoth_node == null:
		var view := CreatureView.new()
		view.name = "View"
		view.setup(behemoth.get("type", "gnasher"), int(behemoth.get("element", 0)))
		_behemoth_node = Node3D.new()
		_behemoth_node.add_child(view)
		add_child(_behemoth_node)

	_behemoth_node.position = GameWorld.to_world(behemoth["pos"])
	_behemoth_node.rotation.y = GameWorld.to_yaw(behemoth["facing"])
	(_behemoth_node.get_node("View") as CreatureView).update_from(behemoth, delta)


## Formas no chão -----------------------------------------------------------

func _redraw_ground() -> void:
	for child in _ground_layer.get_children():
		child.queue_free()

	_draw_telegraph()
	for hunter in _net.view_hunters():
		_draw_swing(hunter)
	_draw_projectiles()


func _draw_telegraph() -> void:
	var behemoth := _net.view_behemoth()
	if behemoth.is_empty():
		return
	var state := int(behemoth.get("state", 0))
	var windup := state == int(BehemothState.State.WINDUP)
	var active := state == int(BehemothState.State.ACTIVE)
	if not windup and not active:
		return

	var attack := Behemoths.attack(behemoth.get("type", Behemoths.GNASHER), behemoth.get("attack", ""))
	if attack.is_empty():
		return
	# Telegrafia por ataque, decidida nos DADOS: um golpe lido pela animação
	# pode desligar o decalque — hoje todos mantêm (animações provisórias).
	if not attack.get("telegraph", true):
		return
	var shape: Dictionary = attack["shape"]
	var pos: Vector2 = behemoth["pos"]
	var facing: float = behemoth["facing"]
	var radius: float = behemoth["radius"]

	# Contorno completo sempre; o preenchimento cresce durante o Preparo e
	# clareia na fase Ativa — a mesma linguagem do 2D.
	var outline := GroundShapes.attack_shape_points(shape, pos, facing, radius)
	_ground_layer.add_child(GroundShapes.polygon(outline, TELEGRAPH_FILL))

	if active:
		_ground_layer.add_child(GroundShapes.polygon(outline, TELEGRAPH_STRIKE))
		return

	var progress := clampf(float(behemoth.get("state_time", 0.0)) / float(attack["windup"]), 0.0, 1.0)
	if progress > 0.05:
		var filled := GroundShapes.attack_shape_points(shape, pos, facing, radius, progress)
		_ground_layer.add_child(GroundShapes.polygon(filled, TELEGRAPH_READY))


func _draw_swing(hunter: Dictionary) -> void:
	if int(hunter.get("state", 0)) != int(HunterState.State.ATTACK):
		return
	var move := Weapons.move(
		hunter.get("weapon", Weapons.SWORD),
		int(hunter.get("attack_kind", 0)) as Weapons.Kind,
		int(hunter.get("attack_index", 0))
	)
	var elapsed: float = hunter.get("state_time", 0.0)
	var windup := float(move["windup"])
	if elapsed <= windup or elapsed > windup + float(move["active"]):
		return

	var direction: Vector2 = hunter.get("attack_dir", Vector2.RIGHT)
	var points := GroundShapes.move_arc_points(move, hunter["pos"], direction.angle())
	_ground_layer.add_child(GroundShapes.polygon(points, SWING_COLOR))


## A Câmara de Magma no ar: uma esfera brilhante por projétil, recriada por
## quadro como as formas do chão — o estado mora na Sim.
func _draw_projectiles() -> void:
	for projectile in _net.view_projectiles():
		var ball := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var radius := float(projectile["radius"]) * GameWorld.SIM_TO_WORLD * 2.0
		mesh.radius = radius
		mesh.height = radius * 2.0
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("ff8a3c")
		material.emission_enabled = true
		material.emission = Color("ff5a1e")
		material.emission_energy_multiplier = 2.4
		mesh.material = material
		ball.mesh = mesh
		ball.position = GameWorld.to_world(projectile["pos"], 1.1)
		_ground_layer.add_child(ball)


## Eventos ------------------------------------------------------------------

func _on_events(events: Array) -> void:
	for event in events:
		var kind: String = event.get("type", "")
		if kind == "part_break":
			var notice := Label3D.new()
			notice.text = "%s DECEPADA!" % String(event["part"]).to_upper() if event.get("severed", false) 				else "%s QUEBRADA!" % String(event["part"]).to_upper()
			notice.modulate = Color("f2d249")
			notice.font_size = 72
			notice.pixel_size = 0.006
			notice.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			notice.position = GameWorld.to_world(event["pos"], 2.6)
			add_child(notice)
			_damage_labels.append({"label": notice, "age": -0.6})
			continue
		if kind == "affliction":
			var alert := Label3D.new()
			alert.text = String(event["name"]).to_upper() + "!"
			alert.modulate = Elements.color(int(event["element"]) as Elements.Element)
			alert.font_size = 72
			alert.pixel_size = 0.006
			alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			alert.position = GameWorld.to_world(event["pos"], 2.2)
			add_child(alert)
			_damage_labels.append({"label": alert, "age": -0.6})
			continue
		if kind != "hit" and kind != "hurt":
			continue
		var label := Label3D.new()
		label.text = "%d" % int(roundf(float(event["amount"])))
		# Dano elemental tem a cor do Elemento; físico fica âmbar; sofrido,
		# vermelho — a tela conta a história sem precisar ler nada.
		var hit_element := int(event.get("element", 0)) as Elements.Element
		if kind == "hurt":
			label.modulate = Color("ff7a6b")
		elif hit_element != Elements.Element.NEUTRAL:
			label.modulate = Elements.color(hit_element)
		else:
			label.modulate = Color("ffe9b0")
		label.font_size = 64
		label.pixel_size = 0.005
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = GameWorld.to_world(event["pos"], 1.6)
		add_child(label)
		_damage_labels.append({"label": label, "age": 0.0})


func _age_damage_labels(delta: float) -> void:
	var alive: Array[Dictionary] = []
	for entry in _damage_labels:
		entry["age"] = float(entry["age"]) + delta
		var label := entry["label"] as Label3D
		if float(entry["age"]) >= 0.85:
			label.queue_free()
			continue
		label.position.y += delta * 0.9
		label.modulate.a = 1.0 - float(entry["age"]) / 0.85
		alive.append(entry)
	_damage_labels = alive
