extends SceneTree

## Abre um .glb num palco 3D mínimo e salva uma captura.
##
##     godot --path . --script res://tools/preview_model.gd -- res://assets/models/totem.glb saida.png [animacao] [angulo] [tempos] [arma.glb] [esconder]
##
## `arma.glb` prende a arma na mão do Caçador (nas duas, se o nome contiver
## "blades"): sem ela não dá para julgar o arco de um Golpe.
##
## `esconder` é uma lista de prefixos de malha separados por vírgula que saem
## da cena antes da captura. É como se confere a cara de uma Parte QUEBRADA
## sem abrir o jogo: `shell,crest` no Bastião tira as placas e mostra a carne
## que a CreatureView acende na quebra.
##
## `angulo` muda o ponto de vista: "front" (de frente, baixo — para conferir
## rostos e mandíbulas), "side" (de lado) ou nada (três-quartos padrão).
##
## `tempo` em segundos congela a animação num instante exato. É o que permite
## conferir o quadro de contato de um Golpe (o fim do Preparo, o começo do
## Ativo) em vez de pegar um momento qualquer do clipe. Vários tempos
## separados por vírgula saem numa TIRA lado a lado — é assim que se lê
## antecipação → impacto → recuperação de uma vez só:
##
##     ... saida.png sword_heavy_1 side 0,0.32,0.42,0.6,0.84
##
## É como se confere o visual de um modelo gerado sem abrir o editor: gera no
## Blender, roda isto, olha o png.

const WARMUP_FRAMES: int = 24
## Quadros entre buscar o tempo e capturar: a pose precisa chegar ao desenho.
const SETTLE_FRAMES: int = 3

var _output: String = "model.png"
var _frames: int = 0
var _done: bool = false
var _player: AnimationPlayer
var _clip: String = ""
var _times: Array[float] = []
var _shots: Array[Image] = []
var _waiting: int = -1

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

	# Quadro quadrado: silhueta de corpo inteiro sem a tarja do 16:9.
	root.size = Vector2i(760, 760)

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
	var offset := Vector3(span * 0.52, span * 0.38, span * 0.52)
	match angle:
		"front":
			offset = Vector3(span * 0.70, span * 0.16, span * 0.28)
		"side":
			offset = Vector3(0.0, span * 0.22, span * 0.74)
	# Mira um pouco acima do centro: poses de mergulho e de pancada esticam o
	# corpo para cima e para a frente, fora da caixa da pose de repouso.
	target += Vector3(0.0, span * 0.06, 0.0)
	# Com arma na mão o enquadramento precisa de folga: a lâmina sai da caixa
	# do corpo e, num arco para a câmera, tapa a tela inteira.
	if args.size() > 5 and not args[5].is_empty():
		offset *= 1.7
	camera.position = target + offset
	world.add_child(camera)
	camera.look_at(target)
	camera.make_current()

	_player = _find_animation_player(model)
	if _player != null:
		var wanted := args[2] if args.size() > 2 else ""
		var names := _player.get_animation_list()
		if wanted.is_empty() and names.size() > 0:
			wanted = names[0]
		if wanted in names:
			_clip = wanted
			_player.play(wanted)
			print("tocando '%s' (disponíveis: %s)" % [wanted, names])
	if args.size() > 4 and _clip != "":
		for piece in args[4].split(",", false):
			if piece.is_valid_float():
				_times.append(piece.to_float())

	# Arma opcional na mão: sem ela não dá para julgar o arco de um Golpe.
	if args.size() > 5 and not args[5].is_empty():
		_equip(model, args[5])

	# Malhas escondidas: a cara de uma Parte quebrada, sem abrir o jogo.
	if args.size() > 6 and not args[6].is_empty():
		for prefix in args[6].split(",", false):
			_hide(model, prefix)


func _hide(node: Node, prefix: String) -> void:
	if node is Node3D and String(node.name).begins_with(prefix):
		(node as Node3D).visible = false
	for child in node.get_children():
		_hide(child, prefix)


func _equip(model: Node, weapon_path: String) -> void:
	var skeleton := _find_skeleton(model)
	var packed: PackedScene = load(weapon_path)
	if skeleton == null or packed == null:
		printerr("sem esqueleto ou arma: %s" % weapon_path)
		return
	var hands := ["hand_r"]
	if weapon_path.contains("blades"):
		hands.append("hand_l")
	for hand in hands:
		var index := skeleton.find_bone(hand)
		if index < 0:
			continue
		var mount := BoneAttachment3D.new()
		skeleton.add_child(mount)
		mount.bone_name = hand
		mount.bone_idx = index
		var weapon := packed.instantiate() as Node3D
		mount.add_child(weapon)
		weapon.position = Vector3(0.0, 0.05, 0.0)
		weapon.rotation = Vector3(0.0, 0.0, deg_to_rad(-90.0))


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _on_frame() -> void:
	if _done:
		return
	_frames += 1
	if _frames == 1:
		_setup()
		return
	if _frames < WARMUP_FRAMES:
		return

	# Sem tempos pedidos: uma captura só, do jeito antigo.
	if _times.is_empty():
		_finish([root.get_texture().get_image()])
		return

	# Com tempos: busca, deixa a pose chegar ao desenho e captura, um a um.
	if _waiting < 0:
		_seek_next()
		return
	_waiting -= 1
	if _waiting > 0:
		return
	_shots.append(root.get_texture().get_image())
	if _shots.size() >= _times.size():
		_finish(_shots)
		return
	_seek_next()


func _seek_next() -> void:
	var time: float = _times[_shots.size()]
	_player.play(_clip)
	_player.seek(minf(time, _player.get_animation(_clip).length), true)
	_player.pause()
	_waiting = SETTLE_FRAMES


## Junta as capturas numa tira horizontal, com um fio claro entre quadros.
func _finish(images: Array) -> void:
	_done = true
	var sheet: Image = images[0]
	if images.size() > 1:
		var width: int = images[0].get_width()
		var height: int = images[0].get_height()
		sheet = Image.create(width * images.size(), height, false, images[0].get_format())
		for index in images.size():
			sheet.blit_rect(images[index], Rect2i(0, 0, width, height), Vector2i(width * index, 0))
			if index > 0:
				sheet.fill_rect(Rect2i(width * index, 0, 2, height), Color("6d7a8a"))
	if sheet.save_png(_output) == OK:
		print("Captura salva em %s (%d quadro(s))" % [_output, images.size()])
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
