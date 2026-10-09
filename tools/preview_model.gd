extends SceneTree

## Abre um .glb num palco 3D mínimo e salva uma captura.
##
##     godot --path . --resolution 960x720 --script res://tools/preview_model.gd -- res://assets/models/totem.glb saida.png [animacao] [angulo]
##
## `angulo` muda o ponto de vista: "front" (de frente, baixo — para conferir
## rostos e mandíbulas), "side" (de lado) ou nada (três-quartos padrão).
##
## É como se confere o visual de um modelo gerado sem abrir o editor: gera no
## Blender, roda isto, olha o png.

const WARMUP_FRAMES: int = 30

var _output: String = "model.png"
var _frames: int = 0
var _done: bool = false

func _initialize() -> void:
	# A montagem acontece no primeiro quadro: durante _initialize a árvore
	# ainda não está ativa e global_transform/look_at não funcionam.
	process_frame.connect(_on_frame)


func _setup() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("uso: -- <modelo.glb> <saida.png> [animacao]")
		quit(1)
		return
	_output = args[1]

	var world := Node3D.new()
	root.add_child(world)

	var packed: PackedScene = load(args[0])
	if packed == null:
		printerr("não importou: %s" % args[0])
		quit(1)
		return
	var model := packed.instantiate()
	world.add_child(model)

	# Palco: chão, luz com sombra, céu neutro e câmera a três quartos.
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(12.0, 12.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("2a313b")
	(floor_mesh.mesh as PlaneMesh).material = floor_material
	world.add_child(floor_mesh)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.shadow_enabled = true
	world.add_child(sun)

	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("1b2027")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.5, 0.55, 0.62)
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)

	# Enquadra pelo tamanho real do modelo, para servir a qualquer escala.
	var bounds := _bounds(model)
	var target := bounds.get_center()
	var span := maxf(bounds.size.length(), 0.5)
	var camera := Camera3D.new()
	var angle := args[3] if args.size() > 3 else ""
	var offset := Vector3(span * 0.9, span * 0.7, span * 0.9)
	match angle:
		"front":
			offset = Vector3(span * 1.1, span * 0.25, span * 0.45)
		"side":
			offset = Vector3(0.0, span * 0.35, span * 1.1)
	camera.position = target + offset
	world.add_child(camera)
	camera.look_at(target)
	camera.make_current()

	var player := _find_animation_player(model)
	if player != null:
		var wanted := args[2] if args.size() > 2 else ""
		var names := player.get_animation_list()
		if wanted.is_empty() and names.size() > 0:
			wanted = names[0]
		if wanted in names:
			player.play(wanted)
			print("tocando '%s' (disponíveis: %s)" % [wanted, names])


func _on_frame() -> void:
	if _done:
		return
	_frames += 1
	if _frames == 1:
		_setup()
		return
	if _frames < WARMUP_FRAMES:
		return
	# quit() só vale no fim do quadro; a trava impede capturas repetidas.
	_done = true
	var image := root.get_texture().get_image()
	if image.save_png(_output) == OK:
		print("Captura salva em %s" % _output)
	quit(0)


func _bounds(node: Node) -> AABB:
	var merged := AABB()
	var first := true
	if node is MeshInstance3D:
		merged = (node as MeshInstance3D).global_transform * (node as MeshInstance3D).get_aabb()
		first = false
	for child in node.get_children():
		var child_bounds := _bounds(child)
		if child_bounds.size != Vector3.ZERO:
			merged = child_bounds if first else merged.merge(child_bounds)
			first = false
	return merged


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
