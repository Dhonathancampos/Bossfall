class_name CreatureView
extends Node3D

## O Behemoth em carne e osso: carrega o .glb da criatura, segue o estado do
## Instantâneo com a animação certa, tinge pela variante elemental e mostra no
## CORPO o que a Sim diz das Partes — placa quebrada, membro decepado.
##
## Componente de apresentação puro: nenhuma regra mora aqui. O que a Parte faz
## é decisão da Sim; esta classe só escolhe qual malha fica visível.
##
## O contrato com `tools/models/*.py`: toda Parte que muda de cara ao quebrar
## tem MALHA COM NOME PRÓPRIO no .glb. Quebrou aqui = o gerador do modelo
## parou de exportar a malha com aquele nome; conserta-se no .py, não aqui.

const SCENES: Dictionary = {
	"gnasher": "res://assets/models/quadruped.glb",
	"bastion": "res://assets/models/bastiao.glb",
	## A Faiscaia ainda não existe em `src/sim/behemoths.gd` — o modelo e as
	## animações já existem, e o dia em que a Mecânica criar o tipo ela nasce
	## com corpo. Até lá esta entrada nunca é procurada.
	"faiscaia": "res://assets/models/faiscaia.glb",
}

## Malhas por Parte, por tipo de Behemoth. Dois papéis possíveis:
##
## - `sever`: a malha SOME quando a Parte quebra sendo decepável (a cauda do
##   Gnasher, o Ferrão e as Antenas da Faiscaia).
## - `plate` + `raw`: a placa some e a carne/quartzo por baixo aparece. É a
##   leitura do Bastião: de longe se vê QUAL setor já foi aberto.
const PARTS: Dictionary = {
	"gnasher": {
		"tail": {"sever": "tail"},
	},
	"bastion": {
		"tail": {"sever": "tail"},
		"head": {"plate": "crest", "raw": "raw_head"},
		"shell": {"plate": "shell", "raw": "raw_shell"},
	},
	"faiscaia": {
		"stinger": {"sever": "stinger"},
		"antennae": {"sever": "antenna"},
		"plates": {"plate": "plates", "raw": "raw_plates"},
	},
}

## Estações do Núcleo Errante da Faiscaia, na ordem do ciclo da ficha
## (Ferrão → dorso traseiro → dorso dianteiro → Mandíbulas). Só a estação da
## vez fica visível: localizar o núcleo num relance é a mecânica da luta.
## Enquanto a Sim não serializar `core_station`, vale a estação 0.
const CORE_STATIONS: Array[String] = ["core_tail", "core_back_a", "core_back_b", "core_head"]

## Material do couro/casca por criatura: é o que a variante elemental tinge e
## o que lampeja ao levar dano.
const BODY_MATERIALS: Dictionary = {
	"gnasher": "quad_moss",
	"bastion": "bastion_hide",
	"faiscaia": "faiscaia_quartz",
}

const LOOPING: Array[String] = ["idle", "walk"]

## Quanto da cor do Elemento entra no couro da variante.
const ELEMENT_TINT: float = 0.45

## Velocidade (cm/s) acima da qual a criatura "anda".
const WALK_SPEED_MIN: float = 15.0

## Pulso do núcleo: 1 Hz normal, 2 Hz em Fúria (ficha da Faiscaia).
const CORE_PULSE_HZ: float = 1.0
const CORE_ENERGY: float = 1.8

var _player: AnimationPlayer
var _body_material: BaseMaterial3D
var _base_color: Color = Color.WHITE
## Parte -> {papel -> [nós]}, montado do PARTS do tipo desta criatura.
var _part_nodes: Dictionary = {}
## Estação -> [nós] do Núcleo Errante, com material próprio para acender.
var _core_nodes: Dictionary = {}
var _core_materials: Array[BaseMaterial3D] = []
var _core_time: float = 0.0
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

	_collect_parts(model, type_id)
	_collect_core(model)
	_claim_body_material(model, BODY_MATERIALS.get(type_id, "quad_moss"))

	# A variante elemental tinge o couro de uma vez, no nascimento.
	var kind := element as Elements.Element
	if _body_material != null and kind != Elements.Element.NEUTRAL:
		_base_color = _base_color.lerp(Elements.color(kind), ELEMENT_TINT)
		_body_material.albedo_color = _base_color


func update_from(behemoth: Dictionary, delta: float) -> void:
	if _player == null:
		return

	_update_flash(behemoth)
	_update_parts(behemoth)
	_update_core(behemoth, delta)

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


## O corpo conta o estado das Partes: o membro decepado some, a placa quebrada
## dá lugar à carne. A Sim já tirou o ataque correspondente do repertório —
## aqui é só a cara disso.
func _update_parts(behemoth: Dictionary) -> void:
	if _part_nodes.is_empty():
		return
	for part in behemoth.get("parts", []):
		var slots: Dictionary = _part_nodes.get(part.get("id", ""), {})
		if slots.is_empty():
			continue
		var broken: bool = part.get("broken", false)
		var severed: bool = broken and part.get("severable", false)
		for node in slots.get("sever", []):
			node.visible = not severed
		for node in slots.get("plate", []):
			node.visible = not broken
		for node in slots.get("raw", []):
			node.visible = broken


func _collect_parts(model: Node, type_id: String) -> void:
	var table: Dictionary = PARTS.get(type_id, {})
	for part_id in table:
		var slots: Dictionary = {}
		for role in (table[part_id] as Dictionary):
			var nodes := _named(model, String(table[part_id][role]))
			slots[role] = nodes
			# A camada de baixo nasce escondida: ela é a cara da QUEBRA.
			if role == "raw":
				for node in nodes:
					node.visible = false
		_part_nodes[part_id] = slots


## O Núcleo Errante: só a estação da vez fica visível, pulsando. Material
## próprio por nó, para o pulso não vazar para outra instância.
func _update_core(behemoth: Dictionary, delta: float) -> void:
	if _core_nodes.is_empty():
		return
	var station := clampi(int(behemoth.get("core_station", 0)), 0, CORE_STATIONS.size() - 1)
	for index in CORE_STATIONS.size():
		for node in _core_nodes.get(CORE_STATIONS[index], []):
			node.visible = index == station
	var rate := CORE_PULSE_HZ * (2.0 if bool(behemoth.get("enraged", false)) else 1.0)
	_core_time += delta * rate
	var pulse := 0.75 + 0.25 * sin(_core_time * TAU)
	for material in _core_materials:
		material.emission_energy_multiplier = CORE_ENERGY * pulse


func _collect_core(model: Node) -> void:
	for name in CORE_STATIONS:
		var nodes := _named(model, name)
		if nodes.is_empty():
			continue
		_core_nodes[name] = nodes
		for node in nodes:
			if not (node is MeshInstance3D):
				continue
			var mesh := node as MeshInstance3D
			if mesh.mesh == null:
				continue
			for surface in range(mesh.mesh.get_surface_count()):
				var mat := mesh.mesh.surface_get_material(surface)
				if mat == null or not (mat is BaseMaterial3D):
					continue
				var copy := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				copy.emission_enabled = true
				mesh.set_surface_override_material(surface, copy)
				_core_materials.append(copy)


## Nós cujo nome é `prefix` ou começa com ele — o importador glTF desambigua
## nomes repetidos com sufixo (`tail_2`), então o prefixo é o contrato.
func _named(node: Node, prefix: String) -> Array[Node3D]:
	var found: Array[Node3D] = []
	if node is Node3D and not (node is AnimationPlayer) and String(node.name).begins_with(prefix):
		found.append(node as Node3D)
	for child in node.get_children():
		found.append_array(_named(child, prefix))
	return found


## Duplica o material do couro/casca para esta instância, para tinta e lampejo
## não vazarem para outro Behemoth no futuro.
func _claim_body_material(model: Node, material_name: String) -> void:
	for mesh in _meshes(model):
		if mesh.mesh == null:
			continue
		for surface in range(mesh.mesh.get_surface_count()):
			var mat := mesh.mesh.surface_get_material(surface)
			if mat == null or not (mat is BaseMaterial3D):
				continue
			if mat.resource_name != material_name:
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
