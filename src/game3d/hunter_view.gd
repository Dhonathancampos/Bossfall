class_name HunterView
extends Node3D

## O Caçador em carne e osso: carrega hunter.glb, escolhe a animação pelo
## estado do Instantâneo e prende a arma na mão.
##
## Componente de apresentação da Arena3D. Nenhuma regra de jogo mora aqui:
## a animação segue a Sim, nunca o contrário.

const HUNTER_SCENE: String = "res://assets/models/hunter.glb"
const WEAPON_SCENES: Dictionary = {
	"sword": "res://assets/models/weapon_sword.glb",
	"hammer": "res://assets/models/weapon_hammer.glb",
	"blades": "res://assets/models/weapon_blades.glb",
}

## Animações que repetem enquanto o estado durar.
const LOOPING: Array[String] = ["idle", "walk", "sprint", "charge", "downed"]

## Velocidade (cm/s do plano da Sim) que separa parado/andando/correndo.
const WALK_SPEED_MIN: float = 12.0
const SPRINT_SPEED_MIN: float = 300.0

## Ajuste fino da arma na mão: o cabo fica na origem do .glb, apontando +Y.
const WEAPON_OFFSET := Vector3(0.0, 0.05, 0.0)
const WEAPON_TILT := Vector3(0.0, 0.0, deg_to_rad(-90.0))

var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _current: String = ""
var _weapon_id: String = Weapons.SWORD


func setup(weapon_id: String, player_color: Color) -> void:
	_weapon_id = weapon_id
	var packed: PackedScene = load(HUNTER_SCENE)
	if packed == null:
		return
	var model := packed.instantiate()
	add_child(model)

	_player = _find_player(model)
	_skeleton = _find_skeleton(model)
	if _player != null and _skeleton != null:
		var library := _player.get_animation_library("").duplicate(true) as AnimationLibrary
		_player.remove_animation_library("")
		_player.add_animation_library("", library)
		_build_locomotion()
	if _player != null:
		for anim_name in LOOPING:
			if _player.has_animation(anim_name):
				_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

	_recolor_accent(model, player_color)
	_attach_weapon(weapon_id)


## Escolhe e sincroniza a animação a partir do dicionário do Instantâneo.
## Velocidade vem da Sim: vários frames podem desenhar o mesmo tique.
func update_from(hunter: Dictionary, _delta: float) -> void:
	if _player == null:
		return

	var state := int(hunter.get("state", 0))
	var state_time := float(hunter.get("state_time", 0.0))

	var velocity: Vector2 = hunter.get("velocity", Vector2.ZERO)
	var speed := velocity.length()
	# O corpo acompanha a caminhada; a mira continua independente na Sim.
	rotation.y = GameWorld.to_yaw(velocity.angle()) - GameWorld.to_yaw(float(hunter.get("facing", 0.0))) \
		if state == HunterState.State.FREE and speed >= WALK_SPEED_MIN else 0.0

	match state:
		HunterState.State.DOWNED:
			_play("downed")
		HunterState.State.HURT:
			_play("hurt", state_time)
		HunterState.State.DODGE:
			_play("dodge", state_time)
		HunterState.State.ATTACK:
			var move := Weapons.move(_weapon_id, int(hunter.get("attack_kind", 0)) as Weapons.Kind, int(hunter.get("attack_index", 0)))
			var anim := _attack_animation(hunter)
			_play(anim, _attack_clip_time(anim, move, state_time))
		# Estados das armas clássicas (revisão): sem isto, carga e gancho
		# mostravam o Caçador parado em idle. SPECIAL_SPIN e RELOADING ainda
		# caem no idle — animações próprias ficam com o papel Modelos.
		HunterState.State.CHARGING:
			_play("charge")
		HunterState.State.HOOK_PULL:
			_play("dodge", state_time)
		_:
			if speed >= SPRINT_SPEED_MIN:
				_play("sprint")
			elif speed >= WALK_SPEED_MIN:
				_play("walk")
			else:
				_play("idle")


func _attack_animation(hunter: Dictionary) -> String:
	if int(hunter.get("attack_kind", 0)) == int(Weapons.Kind.HEAVY):
		return String(Weapons.move(_weapon_id, Weapons.Kind.HEAVY, int(hunter.get("attack_index", 0))).get("animation", "heavy"))
	return "light_%d" % (int(hunter.get("attack_index", 0)) % 3 + 1)


## Reutilização provisória dos clips da espada: alinha preparo/contato/recuperação,
## não só a duração total (o segundo pesado usa o corte ascendente).
func _attack_clip_time(anim: String, move: Dictionary, time: float) -> float:
	var phases: Array = {"light_1": [0.12, 0.08, 0.22], "light_2": [0.11, 0.08, 0.24],
		"light_3": [0.16, 0.14, 0.36], "heavy": [0.32, 0.10, 0.42]}[anim]
	var elapsed := 0.0
	var clip_elapsed := 0.0
	var keys := ["windup", "active", "recovery"]
	for i in 3:
		var duration := float(move[keys[i]])
		if time <= elapsed + duration:
			return clip_elapsed + clampf((time - elapsed) / maxf(duration, 0.001), 0, 1) * float(phases[i])
		elapsed += duration
		clip_elapsed += float(phases[i])
	return clip_elapsed


## Toca sem recomeçar o que já está tocando; com `seek_to`, ressincroniza a
## linha do tempo com a da Sim (importante nos Caçadores remotos, que podem
## entrar no meio de um Golpe).
func _play(anim_name: String, seek_to: float = -1.0) -> void:
	if not _player.has_animation(anim_name):
		return
	if _current != anim_name:
		_current = anim_name
		_player.play(anim_name)
	if seek_to >= 0.0:
		# Inclusive tempo zero: golpes consecutivos que usam o mesmo clip reiniciam.
		_player.seek(minf(seek_to, _player.get_animation(anim_name).length), true)
		_player.pause()


## O rig olha +X. O balanço original em X abria pernas para os lados.
## Constrói ciclos no plano sagital, convertendo o eixo mundial para cada osso.
func _build_locomotion() -> void:
	var library := _player.get_animation_library("")
	var skeleton_path := _player.get_node(_player.root_node).get_path_to(_skeleton)
	for clip in ["walk", "sprint"]:
		var running: bool = clip == "sprint"
		var animation := Animation.new()
		animation.length = 0.55 if running else 0.8
		animation.loop_mode = Animation.LOOP_LINEAR
		for bone in _skeleton.get_bone_count():
			var bone_name := _skeleton.get_bone_name(bone)
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath(str(skeleton_path) + ":" + bone_name))
			var rest := _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
			var axis := _skeleton.get_bone_global_rest(bone).basis.inverse() * Vector3(0, 0, 1)
			for key in 17:
				var phase := TAU * float(key) / 16.0
				var side := 0.0 if "_r" in bone_name else PI
				var angle := 0.0
				if bone_name.begins_with("thigh"):
					angle = sin(phase + side) * (40.0 if running else 24.0)
				elif bone_name.begins_with("shin"):
					angle = -maxf(0.0, sin(phase + side)) * (58.0 if running else 32.0)
				elif bone_name.begins_with("upper_arm"):
					angle = -sin(phase + side) * (28.0 if running else 16.0)
				elif bone_name.begins_with("forearm"):
					angle = 30.0 if running else 12.0
				elif bone_name.begins_with("chest"):
					angle = -8.0 if running else -2.0
				animation.rotation_track_insert_key(track, animation.length * float(key) / 16.0, rest * Quaternion(axis.normalized(), deg_to_rad(angle)))
		if library.has_animation(clip):
			library.remove_animation(clip)
		library.add_animation(clip, animation)


## A arma vai num BoneAttachment3D da mão direita. As Lâminas são um par:
## ganham uma segunda instância no antebraço esquerdo.
func _attach_weapon(weapon_id: String) -> void:
	if _skeleton == null or not WEAPON_SCENES.has(weapon_id):
		return
	var packed: PackedScene = load(WEAPON_SCENES[weapon_id])
	if packed == null:
		return

	_mount(packed, "hand_r")
	if weapon_id == "blades":
		# O rig atual não tem mão esquerda: a empunhadura fica na ponta
		# do antebraço (0,27 m), não na origem do osso, junto ao cotovelo.
		_mount(packed, "forearm_l", Vector3(0.0, 0.27, 0.0))


func _mount(packed: PackedScene, bone: String, grip_offset: Vector3 = WEAPON_OFFSET) -> void:
	var index := _resolve_bone(bone)
	if index < 0:
		push_error("Não foi possível equipar a arma: osso '%s' ausente no caçador." % bone)
		return
	var mount := BoneAttachment3D.new()
	mount.name = "WeaponMount_" + bone
	_skeleton.add_child(mount)
	mount.bone_name = _skeleton.get_bone_name(index)
	mount.bone_idx = index
	var weapon := packed.instantiate() as Node3D
	mount.add_child(weapon)
	weapon.position = grip_offset
	weapon.rotation = WEAPON_TILT


## O importador glTF desambigua nomes de malhas/ossos iguais com _2, _3...
## Prefere o nome exato e só aceita um sufixo numérico inequívoco.
func _resolve_bone(bone: String) -> int:
	var exact := _skeleton.find_bone(bone)
	if exact >= 0:
		return exact
	var found := -1
	for i in _skeleton.get_bone_count():
		var imported := _skeleton.get_bone_name(i)
		if imported.begins_with(bone + "_") and imported.trim_prefix(bone + "_").is_valid_int():
			if found >= 0:
				return -1
			found = i
	return found


## Pinta de volta a cor do jogador no material "accent" (cachecol e capuz).
func _recolor_accent(model: Node, color: Color) -> void:
	for mesh in _meshes(model):
		for surface in range(mesh.get_surface_override_material_count()):
			var mat := mesh.mesh.surface_get_material(surface) if mesh.mesh != null else null
			if mat == null or not (mat is BaseMaterial3D):
				continue
			if mat.resource_name != "accent":
				continue
			var copy := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			copy.albedo_color = color
			mesh.set_surface_override_material(surface, copy)


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_meshes(child))
	return found


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var hit := _find_player(child)
		if hit != null:
			return hit
	return null


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var hit := _find_skeleton(child)
		if hit != null:
			return hit
	return null
