class_name HunterView
extends Node3D

## O Caçador em carne e osso: carrega hunter.glb, escolhe a animação pelo
## estado do Instantâneo e prende a arma na mão.
##
## Componente de apresentação da Arena3D. Nenhuma regra de jogo mora aqui:
## a animação segue a Sim, nunca o contrário.
##
## Esta classe NÃO fabrica animação. Houve uma fase em que ela reconstruía
## caminhada e corrida por código, porque os ciclos gerados batiam o balanço
## no eixo errado; `tools/models/common.py` passou a aceitar pose em eixos do
## mundo e os clipes voltaram a ser a fonte. Clipe ruim se conserta no
## gerador, não aqui.

const HUNTER_SCENE: String = "res://assets/models/hunter.glb"

## Modelo por arma. Machado, Lança e Repetidoras já têm .glb (papel Modelos)
## mas ainda NÃO existem em `src/sim/weapons.gd`: o id nunca chega aqui até a
## Mecânica criá-los. Ficam registrados para a arma nascer montada no dia em
## que chegarem — e para o teste de assets provar que elas encaixam na mão.
const WEAPON_SCENES: Dictionary = {
	"sword": "res://assets/models/weapon_sword.glb",
	"hammer": "res://assets/models/weapon_hammer.glb",
	"blades": "res://assets/models/weapon_blades.glb",
	"axe": "res://assets/models/weapon_axe.glb",
	"pike": "res://assets/models/weapon_pike.glb",
	"repeaters": "res://assets/models/weapon_repeaters.glb",
}

## Armas que são um PAR: o mesmo .glb vai nas duas mãos.
const DUAL_WIELD: Array[String] = ["blades", "repeaters"]

## Animações que repetem enquanto o estado durar. Duram o que a Sim quiser:
## o Gancho acaba quando chega, a carga quando o jogador solta.
const LOOPING: Array[String] = ["idle", "walk", "sprint", "charge", "downed", "hook"]

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
	rotation.y = _body_yaw(hunter, state, speed)

	match state:
		HunterState.State.DOWNED:
			_play("downed")
		HunterState.State.HURT:
			_play("hurt", state_time)
		HunterState.State.DODGE:
			_play("dodge", state_time)
		HunterState.State.ATTACK:
			# O clipe tem a duração exata do Golpe na Sim, fase por fase:
			# o tempo do estado É o tempo do clipe, sem remapear nada.
			_play(_attack_animation(hunter), state_time)
		HunterState.State.CHARGING:
			_play("charge")
		HunterState.State.HOOK_PULL:
			_play("hook")
		HunterState.State.SPECIAL_SPIN:
			_play("special_spin", state_time)
		HunterState.State.RELOADING:
			_play("reload", state_time)
		_:
			if speed >= SPRINT_SPEED_MIN:
				_play("sprint")
			elif speed >= WALK_SPEED_MIN:
				_play("walk")
			else:
				_play("idle")


## Para onde o corpo aponta. A mira da Sim é o nó pai; aqui só se desvia dela
## quando o movimento manda: andar na diagonal e rolar para o lado.
func _body_yaw(hunter: Dictionary, state: int, speed: float) -> float:
	var facing := GameWorld.to_yaw(float(hunter.get("facing", 0.0)))
	if state == HunterState.State.DODGE:
		var dir: Vector2 = hunter.get("dodge_dir", Vector2.ZERO)
		# O rolamento é um mergulho PARA A FRENTE no clipe: virar o corpo
		# para a direção da esquiva é o que o torna legível de qualquer lado.
		return GameWorld.to_yaw(dir.angle()) - facing if dir.length_squared() > 0.0001 else 0.0
	if state == HunterState.State.FREE and speed >= WALK_SPEED_MIN:
		var velocity: Vector2 = hunter.get("velocity", Vector2.ZERO)
		return GameWorld.to_yaw(velocity.angle()) - facing
	return 0.0


## Cada arma tem o seu jogo de clipes, um por Golpe, com os mesmos índices da
## tabela de `weapons.gd`: `sword_light_1`, `hammer_heavy_3`, `blades_light_4`.
## O campo `animation` dos dados de Golpe é legado e não é mais lido — ele
## existia para reaproveitar clipes da espada quando só havia um jogo.
func _attack_animation(hunter: Dictionary) -> String:
	var kind := "heavy" if int(hunter.get("attack_kind", 0)) == int(Weapons.Kind.HEAVY) else "light"
	var index := int(hunter.get("attack_index", 0)) + 1
	var wanted := "%s_%s_%d" % [_weapon_id, kind, index]
	if _player.has_animation(wanted):
		return wanted
	# Arma sem clipe próprio para este índice cai no jogo da espada, e em
	# último caso no primeiro Golpe dela: nunca num nome inexistente.
	var fallback := "%s_%s_%d" % [Weapons.SWORD, kind, index]
	return fallback if _player.has_animation(fallback) else "sword_light_1"


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


## A arma vai num BoneAttachment3D da mão direita. As armas de DUAL_WIELD
## (Lâminas, Repetidoras) ganham uma segunda instância na mão esquerda.
func _attach_weapon(weapon_id: String) -> void:
	if _skeleton == null or not WEAPON_SCENES.has(weapon_id):
		return
	var packed: PackedScene = load(WEAPON_SCENES[weapon_id])
	if packed == null:
		return

	_mount(packed, "hand_r")
	if weapon_id in DUAL_WIELD:
		_mount(packed, "hand_l")


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
