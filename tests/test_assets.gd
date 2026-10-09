extends RefCounted

## O pipeline de modelos: o .glb gerado pelo Blender existe, importa na Godot
## e contém as animações com os nomes que a apresentação espera.
##
## Pré-requisito: `blender --background --python tools/models/totem.py` (ou
## build_all.ps1) e depois a importação do projeto. O README cobre os dois.

const TOTEM_PATH: String = "res://assets/models/totem.glb"
const TOTEM_ANIMATIONS: Array[String] = ["idle", "wobble"]

## Modelos do jogo e as animações que a apresentação espera pelo nome exato.
## Quebrou aqui = um script de modelo parou de gerar o que a HunterView ou a
## CreatureView consomem.
const GAME_MODELS: Dictionary = {
	"res://assets/models/hunter.glb": [
		"idle", "walk", "sprint", "dodge",
		"light_1", "light_2", "light_3", "heavy", "charge",
		"hurt", "downed", "revive",
	],
	"res://assets/models/quadruped.glb": [
		"idle", "walk", "bite", "charge", "tail", "stomp",
		"roar", "stagger_fall", "death",
	],
	"res://assets/models/weapon_sword.glb": [],
	"res://assets/models/weapon_hammer.glb": [],
	"res://assets/models/weapon_blades.glb": [],
}


func test_the_proof_model_exists(t: TestCase) -> void:
	t.check(
		FileAccess.file_exists(TOTEM_PATH),
		"o .glb de prova existe — rode tools/models/build_all.ps1 se não"
	)


func test_the_proof_model_loads_as_a_scene(t: TestCase) -> void:
	var packed: PackedScene = load(TOTEM_PATH)
	t.check(packed != null, "a Godot importa o .glb como cena")
	if packed == null:
		return

	var instance := packed.instantiate()
	t.check(instance != null, "a cena instancia")
	if instance != null:
		instance.free()


func test_the_proof_model_has_the_expected_animations(t: TestCase) -> void:
	var packed: PackedScene = load(TOTEM_PATH)
	if packed == null:
		t.check(false, "sem cena não há o que verificar")
		return

	var instance := packed.instantiate()
	var player := _find_animation_player(instance)
	t.check(player != null, "o .glb traz um AnimationPlayer")

	if player != null:
		var names := player.get_animation_list()
		for expected in TOTEM_ANIMATIONS:
			t.check(expected in names, "a animação '%s' chegou com o nome certo (veio: %s)" % [expected, names])
	instance.free()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func test_every_game_model_exists_and_loads(t: TestCase) -> void:
	for path in GAME_MODELS:
		t.check(FileAccess.file_exists(path), "%s existe — rode tools/models/build_all.ps1 se não" % path)
		var packed: PackedScene = load(path)
		t.check(packed != null, "%s importa como cena" % path)
		if packed != null:
			var instance := packed.instantiate()
			t.check(instance != null, "%s instancia" % path)
			if instance != null:
				instance.free()


func test_game_models_carry_the_expected_animations(t: TestCase) -> void:
	for path in GAME_MODELS:
		var expected: Array = GAME_MODELS[path]
		if expected.is_empty():
			continue
		var packed: PackedScene = load(path)
		if packed == null:
			t.check(false, "%s não importou" % path)
			continue
		var instance := packed.instantiate()
		var player := _find_animation_player(instance)
		t.check(player != null, "%s tem AnimationPlayer" % path)
		if player != null:
			var names := player.get_animation_list()
			for anim_name in expected:
				t.check(anim_name in names, "%s traz '%s' (veio: %s)" % [path.get_file(), anim_name, names])
		instance.free()


func test_the_quadruped_tail_is_a_named_node(t: TestCase) -> void:
	# A cauda decepável precisa ser um nó escondível pelo nome.
	var packed: PackedScene = load("res://assets/models/quadruped.glb")
	if packed == null:
		t.check(false, "quadruped.glb não importou")
		return
	var instance := packed.instantiate()
	t.check(_find_named_prefix(instance, "tail") != null, "existe um nó 'tail*' para esconder ao decepar")
	instance.free()


func _find_named_prefix(node: Node, prefix: String) -> Node:
	if String(node.name).begins_with(prefix) and node is Node3D and not (node is AnimationPlayer):
		return node
	for child in node.get_children():
		var hit := _find_named_prefix(child, prefix)
		if hit != null:
			return hit
	return null


func test_weapons_mount_to_imported_hand_bones(t: TestCase) -> void:
	for id in HunterView.WEAPON_SCENES:
		var view := HunterView.new()
		# Mesma ordem da Arena: setup antes de entrar na árvore.
		view.setup(id, Color.WHITE)
		(Engine.get_main_loop() as SceneTree).root.add_child(view)
		var skeleton: Skeleton3D = view.get("_skeleton")
		var mounts: Array[BoneAttachment3D] = []
		for child in skeleton.get_children():
			if child is BoneAttachment3D:
				mounts.append(child)
		t.check_eq(mounts.size(), 2 if id == Weapons.BLADES else 1, "%s equipa todas as armas" % id)
		for mount in mounts:
			t.check(mount.bone_idx >= 0, "o suporte resolve o osso importado")
			t.check_eq(mount.get_child_count(), 1, "o suporte contém o modelo da arma")
			var weapon := mount.get_child(0) as Node3D
			t.check(weapon.is_visible_in_tree(), "a arma está visível")
			t.check_eq(mount.bone_name, skeleton.get_bone_name(mount.bone_idx), "o suporte usa o nome real do osso")
			t.check(not (view.call("_meshes", weapon) as Array).is_empty(), "a arma contém malhas renderizáveis")
		view.free()


func test_locomotion_uses_tick_velocity_and_attacks_restart(t: TestCase) -> void:
	var view := HunterView.new()
	view.setup(Weapons.SWORD, Color.WHITE)
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	var data := {"state": HunterState.State.FREE, "velocity": Vector2(400, 0)}
	for frame in 10:
		view.update_from(data, 1.0 / 144.0)
		t.check_eq(view.get("_current"), "sprint", "mesmo snapshot não interrompe corrida")
	data["velocity"] = Vector2.ZERO
	view.update_from(data, 1.0 / 144.0)
	t.check_eq(view.get("_current"), "idle", "parar retorna ao repouso")
	data.merge({"state": HunterState.State.ATTACK, "attack_kind": Weapons.Kind.HEAVY, "state_time": 0.4}, true)
	view.update_from(data, 0.016)
	data["state_time"] = 0.0
	view.update_from(data, 0.016)
	var player: AnimationPlayer = view.get("_player")
	t.check_approx(player.current_animation_position, 0.0, "mesmo clip reinicia no novo golpe")
	view.free()


func test_training_dummy_has_monster_cart_silhouette(t: TestCase) -> void:
	var dummy := TrainingDummyView.new()
	for part in ["Chassis", "Wheel", "Barrel", "Snout", "Jaw", "Banner"]:
		t.check(dummy.has_node(part), "boneco inclui " + part)
	t.check(dummy.has_meta("material"), "mantém feedback de acerto da Arena")
	dummy.free()
