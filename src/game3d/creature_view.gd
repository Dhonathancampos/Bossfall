class_name CreatureView
extends Node3D

## O Behemoth em carne e osso: carrega o .glb da criatura, segue o estado do
## Instantâneo com a animação certa, tinge pela variante elemental e esconde a
## cauda decepada.
##
## Componente de apresentação puro, AINDA NÃO integrado à Arena3D — a troca
## da cápsula por isto é passo de integração do Gerente.

const SCENES: Dictionary = {
	"gnasher": "res://assets/models/quadruped.glb",
}

const LOOPING: Array[String] = ["idle", "walk"]

## Quanto da cor do Elemento entra no couro da variante.
const ELEMENT_TINT: float = 0.45

## Velocidade (cm/s) acima da qual a criatura "anda".
const WALK_SPEED_MIN: float = 15.0

var _player: AnimationPlayer
var _body_material: BaseMaterial3D
var _base_color: Color = Color.WHITE
var _tail_nodes: Array[Node3D] = []
var _current: String = ""
var _roaring: bool = false
var _last_pos: Vector2 = Vector2.ZERO
var _has_pos: bool = false


func setup(type_id: String, element: int) -> void:
	var packed: PackedScene = load(SCENES.get(type_id, SCENES["gnasher"]))
	if packed == null:
		return
	var model := packed.instantiate()
	add_child(model)

	_player = _find_player(model)
	if _player != null:
		for anim_name in LOOPING:
			if _player.has_animation(anim_name):
				_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

	_collect_tail(model)
	_claim_body_material(model)

	# A variante elemental tinge o couro de uma vez, no nascimento.
	var kind := element as Elements.Element
	if _body_material != null and kind != Elements.Element.NEUTRAL:
		_base_color = _base_color.lerp(Elements.color(kind), ELEMENT_TINT)
		_body_material.albedo_color = _base_color


func update_from(behemoth: Dictionary, delta: float) -> void:
	if _player == null:
		return

	_update_flash(behemoth)
	_update_tail(behemoth)

	var state := int(behemoth.get("state", 0))
	var state_time := float(behemoth.get("state_time", 0.0))
	var attack_id: String = behemoth.get("attack", "")

	var speed := 0.0
	var pos: Vector2 = behemoth.get("pos", Vector2.ZERO)
	if _has_pos and delta > 0.0001:
		speed = pos.distance_to(_last_pos) / delta
	_last_pos = pos
	_has_pos = true

	match state:
		BehemothState.State.DEAD:
			_play("death")
		BehemothState.State.STAGGERED:
			_play("stagger_fall", state_time)
		BehemothState.State.WINDUP:
			_play_attack(behemoth, attack_id, state_time, 0.0)
		BehemothState.State.ACTIVE:
			_play_attack(behemoth, attack_id, state_time, 1.0)
		BehemothState.State.RECOVER:
			_play_attack(behemoth, attack_id, state_time, 2.0)
		_:
			# O rugido da Fúria toma o lugar do idle enquanto o aviso dura.
			if float(behemoth.get("enrage_flash", 0.0)) > 0.0 and _player.has_animation("roar"):
				if not _roaring:
					_roaring = true
					_current = "roar"
					_player.play("roar")
				return
			_roaring = false
			_play("walk" if speed >= WALK_SPEED_MIN else "idle")


## A animação do ataque tem as mesmas três fases da Sim; `phase` diz em qual
## estamos (0 Preparo, 1 Ativo, 2 Recuperação) para ressincronizar o relógio.
func _play_attack(behemoth: Dictionary, attack_id: String, state_time: float, phase: float) -> void:
	if attack_id.is_empty() or not _player.has_animation(attack_id):
		return
	var data := Behemoths.attack(behemoth.get("type", "gnasher"), attack_id)
	var offset := state_time
	if phase >= 1.0 and not data.is_empty():
		offset += float(data["windup"])
	if phase >= 2.0 and not data.is_empty():
		offset += float(data["active"])
	_play(attack_id, offset)


func _play(anim_name: String, seek_to: float = -1.0) -> void:
	if not _player.has_animation(anim_name):
		return
	_roaring = false
	if _current != anim_name:
		_current = anim_name
		_player.play(anim_name)
		if seek_to > 0.0:
			_player.seek(minf(seek_to, _player.get_animation(anim_name).length), true)


## Lampejo branco de dano: emissão no couro, sem mexer na cor base.
func _update_flash(behemoth: Dictionary) -> void:
	if _body_material == null:
		return
	var flashing: bool = float(behemoth.get("hit_flash", 0.0)) > 0.0
	_body_material.emission_enabled = flashing
	if flashing:
		_body_material.emission = Color(1.0, 0.95, 0.85)
		_body_material.emission_energy_multiplier = 0.7


## A cauda decepada some do corpo — a Sim já tirou a rabada do repertório.
func _update_tail(behemoth: Dictionary) -> void:
	for part in behemoth.get("parts", []):
		if part.get("id", "") != "tail":
			continue
		var severed: bool = part.get("broken", false) and part.get("severable", false)
		for node in _tail_nodes:
			node.visible = not severed


func _collect_tail(node: Node) -> void:
	if node is Node3D and String(node.name).begins_with("tail"):
		_tail_nodes.append(node)
	for child in node.get_children():
		_collect_tail(child)


## Duplica o material do couro ("quad_moss") para esta instância, para tinta
## e lampejo não vazarem para outro Behemoth no futuro.
func _claim_body_material(model: Node) -> void:
	for mesh in _meshes(model):
		if mesh.mesh == null:
			continue
		for surface in range(mesh.mesh.get_surface_count()):
			var mat := mesh.mesh.surface_get_material(surface)
			if mat == null or not (mat is BaseMaterial3D):
				continue
			if mat.resource_name != "quad_moss":
				continue
			if _body_material == null:
				_body_material = (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				_base_color = _body_material.albedo_color
			mesh.set_surface_override_material(surface, _body_material)


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
