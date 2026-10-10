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
	# Um clipe por Golpe e por arma: os nomes seguem os índices de weapons.gd.
	# `blades_heavy_1` não existe de propósito — o índice 0 do pesado das
	# Lâminas é o Gancho, que vira estado HOOK_PULL e usa o clipe "hook".
	"res://assets/models/hunter.glb": [
		"idle", "walk", "sprint", "dodge", "hurt", "downed", "revive",
		"charge", "reload", "special_spin", "hook",
		"sword_light_1", "sword_light_2", "sword_light_3",
		"sword_heavy_1", "sword_heavy_2", "sword_heavy_3",
		"hammer_light_1", "hammer_light_2", "hammer_light_3",
		"hammer_heavy_1", "hammer_heavy_2", "hammer_heavy_3",
		"blades_light_1", "blades_light_2", "blades_light_3", "blades_light_4",
		"blades_heavy_2",
	],
	"res://assets/models/quadruped.glb": [
		"idle", "walk", "bite", "charge", "tail", "stomp",
		"roar", "stagger_fall", "death",
	],
	# Um clipe por ataque do Bastião, com o id EXATO de behemoths.gd.
	"res://assets/models/bastiao.glb": [
		"idle", "walk", "headbutt", "roll", "mace", "quake",
		"roar", "stagger_fall", "death",
	],
	# A Faiscaia ainda não existe na Sim: os nomes dos clipes vêm dos ataques
	# da ficha `.scratch/bestiary/05-faiscaia.md`. Quando a Mecânica criar o
	# tipo, os ids têm de ser estes — ou o modelo é regerado com os novos.
	"res://assets/models/faiscaia.glb": [
		"idle", "walk", "pince", "whip", "serpentine", "coil",
		"static_lash", "discharge", "roar", "stagger_fall", "death",
	],
	"res://assets/models/weapon_sword.glb": [],
	"res://assets/models/weapon_hammer.glb": [],
	"res://assets/models/weapon_blades.glb": [],
	"res://assets/models/weapon_axe.glb": [],
	"res://assets/models/weapon_pike.glb": [],
	"res://assets/models/weapon_repeaters.glb": [],
}

## Durações da ficha da Faiscaia (windup+active+recovery), em segundos. A Sim
## ainda não as tem; quando tiver, esta tabela sai e o teste passa a ler
## `Behemoths.attacks("faiscaia")`, como já faz com os outros dois.
const FAISCAIA_ATTACKS: Dictionary = {
	"pince": 1.22, "whip": 1.43, "serpentine": 2.08,
	"coil": 2.12, "static_lash": 1.50, "discharge": 3.70,
}

## Malhas que a CreatureView precisa encontrar PELO NOME para mostrar o estado
## das Partes. Contrato com tools/models/bastiao.py e faiscaia.py.
const NAMED_MESHES: Dictionary = {
	"res://assets/models/bastiao.glb": ["crest", "shell", "tail", "raw_head", "raw_shell"],
	"res://assets/models/faiscaia.glb": [
		"plates", "raw_plates", "stinger", "antenna_r", "antenna_l",
		"core_tail", "core_back_a", "core_back_b", "core_head",
	],
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


## O contrato de fidelidade: o clipe de cada Golpe dura EXATAMENTE o que a
## Sim cobra de Comprometimento. Quebrou aqui = a animação parou de contar o
## mesmo tempo que a hitbox, e a leitura do jogador mente.
##
## A tolerância é um quadro do gerador (1/60 s): o glTF só guarda a animação
## amostrada, então a duração cai no múltiplo de quadro mais próximo.
func test_attack_clips_last_exactly_what_the_sim_charges(t: TestCase) -> void:
	var packed: PackedScene = load("res://assets/models/hunter.glb")
	if packed == null:
		t.check(false, "hunter.glb não importou")
		return
	var instance := packed.instantiate()
	var player := _find_animation_player(instance)
	if player == null:
		t.check(false, "hunter.glb sem AnimationPlayer")
		instance.free()
		return
	var baseline: Array = GAME_MODELS["res://assets/models/hunter.glb"]
	for weapon_id in Weapons.ids():
		for kind in [Weapons.Kind.LIGHT, Weapons.Kind.HEAVY]:
			var list := Weapons.moves(weapon_id, kind)
			for index in list.size():
				var move: Dictionary = list[index]
				# Gancho, tiro e Rolinho não são Golpes: não têm fases nem
				# clipe próprio.
				if move.get("hook", false) or move.get("shot", false) or move.get("tumble", false):
					continue
				var label := "heavy" if kind == Weapons.Kind.HEAVY else "light"
				var clip := "%s_%s_%d" % [weapon_id, label, index + 1]
				# Nenhum clipe existente pode SUMIR: o conjunto gerado em
				# 09/10 continua obrigatório. Os nós novos do grafo (ticket 14)
				# e as três armas novas ainda estão na fila do papel Modelos;
				# até lá caem no fallback declarado da HunterView.
				if clip in baseline:
					t.check(
						player.has_animation(clip),
						"o clipe '%s' (%s) não pode sumir" % [clip, move["name"]]
					)
				# O contrato de fidelidade segue INTACTO, sem afrouxar nada:
				# clipe que existe dura exatamente o que a Sim cobra.
				if player.has_animation(clip):
					t.check_approx(
						player.get_animation(clip).length, Weapons.duration(move),
						"'%s' dura o Golpe inteiro" % clip, 0.017
					)
	instance.free()


## Mesmo contrato do lado do Behemoth. Se a Sim mudar os tempos do Gnasher,
## REGERE o modelo (tools/models/build_all.ps1) — não afrouxe este teste: a
## telegrafia do ataque é a própria animação.
func test_behemoth_clips_last_exactly_what_the_sim_charges(t: TestCase) -> void:
	var packed: PackedScene = load("res://assets/models/quadruped.glb")
	if packed == null:
		t.check(false, "quadruped.glb não importou")
		return
	var instance := packed.instantiate()
	var player := _find_animation_player(instance)
	if player == null:
		t.check(false, "quadruped.glb sem AnimationPlayer")
		instance.free()
		return
	for attack in Behemoths.attacks(Behemoths.GNASHER):
		var clip: String = attack["id"]
		t.check(player.has_animation(clip), "existe o clipe '%s'" % clip)
		if player.has_animation(clip):
			t.check_approx(
				player.get_animation(clip).length, Behemoths.duration(attack),
				"'%s' dura o ataque inteiro" % clip, 0.017
			)
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
		var expected_mounts := 2 if id in HunterView.DUAL_WIELD else 1
		t.check_eq(mounts.size(), expected_mounts, "%s equipa todas as armas" % id)
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


## Cada arma mostra o SEU Golpe. Antes desta leva, Martelo e Lâminas tocavam
## os clipes da espada por índice; agora só caem nesse atalho se o clipe
## próprio não existir.
func test_each_weapon_plays_its_own_attack_clips(t: TestCase) -> void:
	for id in [Weapons.SWORD, Weapons.HAMMER, Weapons.BLADES]:
		var view := HunterView.new()
		view.setup(id, Color.WHITE)
		(Engine.get_main_loop() as SceneTree).root.add_child(view)
		var player: AnimationPlayer = view.get("_player")
		for kind in [Weapons.Kind.LIGHT, Weapons.Kind.HEAVY]:
			var list := Weapons.moves(id, kind)
			for index in list.size():
				if (list[index] as Dictionary).get("hook", false):
					continue
				view.update_from({
					"state": HunterState.State.ATTACK,
					"attack_kind": int(kind), "attack_index": index,
					"state_time": 0.01, "velocity": Vector2.ZERO,
				}, 0.016)
				var label := "heavy" if kind == Weapons.Kind.HEAVY else "light"
				var own := "%s_%s_%d" % [id, label, index + 1]
				if player.has_animation(own):
					t.check_eq(
						view.get("_current"), own,
						"%s toca o clipe do próprio Golpe %d" % [id, index + 1]
					)
				else:
					# Nó novo do ticket 14 ainda sem clipe (fila do papel
					# Modelos): o fallback tem que ser um clipe que EXISTE —
					# nunca um nome inexistente.
					t.check(
						player.has_animation(String(view.get("_current"))),
						"%s cai num clipe existente no Golpe %d" % [id, index + 1]
					)
		view.free()


## Os estados que a revisão de 09/10 apontou sem animação própria (caíam no
## repouso) agora têm clipe: recarga, Dança da Ceifadora e Gancho.
func test_weapon_states_have_their_own_clips(t: TestCase) -> void:
	var view := HunterView.new()
	view.setup(Weapons.HAMMER, Color.WHITE)
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	for pair in [[HunterState.State.RELOADING, "reload"],
			[HunterState.State.SPECIAL_SPIN, "special_spin"],
			[HunterState.State.HOOK_PULL, "hook"],
			[HunterState.State.CHARGING, "charge"]]:
		view.update_from({"state": pair[0], "state_time": 0.1, "velocity": Vector2.ZERO}, 0.016)
		t.check_eq(view.get("_current"), pair[1], "o estado %d tem animação própria" % pair[0])
	view.free()


func test_training_dummy_has_monster_cart_silhouette(t: TestCase) -> void:
	var dummy := TrainingDummyView.new()
	for part in ["Chassis", "Wheel", "Barrel", "Snout", "Jaw", "Banner"]:
		t.check(dummy.has_node(part), "boneco inclui " + part)
	t.check(dummy.has_meta("material"), "mantém feedback de acerto da Arena")
	dummy.free()


## O Bastião tem agora o CORPO dele, e o mesmo contrato de fidelidade do
## Gnasher: um clipe por ataque, com o id exato e a duração exata. Se a
## Mecânica mexer nos tempos dele, este teste quebra DE PROPÓSITO — a correção
## é regerar o modelo (tools/models/build_all.ps1), não afrouxar o teste.
func test_bastion_clips_last_exactly_what_the_sim_charges(t: TestCase) -> void:
	var packed: PackedScene = load("res://assets/models/bastiao.glb")
	if packed == null:
		t.check(false, "bastiao.glb não importou")
		return
	var instance := packed.instantiate()
	var player := _find_animation_player(instance)
	if player == null:
		t.check(false, "bastiao.glb sem AnimationPlayer")
		instance.free()
		return
	for attack in Behemoths.attacks(Behemoths.BASTION):
		var clip: String = attack["id"]
		t.check(player.has_animation(clip), "existe o clipe '%s'" % clip)
		if player.has_animation(clip):
			t.check_approx(
				player.get_animation(clip).length, Behemoths.duration(attack),
				"'%s' dura o ataque inteiro" % clip, 0.017
			)
	instance.free()


## A Faiscaia ainda não é um tipo da Sim: o corpo e os clipes nascem da ficha
## do bestiário. O contrato é o mesmo, só que contra a tabela da ficha — no
## dia em que a Mecânica criar o tipo, trocar FAISCAIA_ATTACKS por
## `Behemoths.attacks("faiscaia")` é a única mudança deste teste.
func test_faiscaia_clips_match_the_bestiary_sheet(t: TestCase) -> void:
	var packed: PackedScene = load("res://assets/models/faiscaia.glb")
	if packed == null:
		t.check(false, "faiscaia.glb não importou")
		return
	var instance := packed.instantiate()
	var player := _find_animation_player(instance)
	if player == null:
		t.check(false, "faiscaia.glb sem AnimationPlayer")
		instance.free()
		return
	for clip in FAISCAIA_ATTACKS:
		t.check(player.has_animation(clip), "existe o clipe '%s'" % clip)
		if player.has_animation(clip):
			t.check_approx(
				player.get_animation(clip).length, float(FAISCAIA_ATTACKS[clip]),
				"'%s' dura o ataque inteiro da ficha" % clip, 0.017
			)
	instance.free()


## As Partes que mudam de cara ao quebrar precisam ser malhas ESCONDÍVEIS pelo
## nome. É o contrato entre tools/models/*.py e a CreatureView; quebrou aqui =
## o gerador parou de exportar a malha com esse nome.
func test_part_meshes_are_named_nodes(t: TestCase) -> void:
	for path in NAMED_MESHES:
		var packed: PackedScene = load(path)
		if packed == null:
			t.check(false, "%s não importou" % path)
			continue
		var instance := packed.instantiate()
		for name in (NAMED_MESHES[path] as Array):
			t.check(
				_find_named_prefix(instance, String(name)) != null,
				"%s traz a malha '%s'" % [path.get_file(), name]
			)
		instance.free()


## O Bastião mostra NO CORPO o que a Sim diz das Partes: placa inteira esconde
## a carne, placa quebrada troca as duas, cauda decepada some.
func test_creature_view_swaps_bastion_plates_on_break(t: TestCase) -> void:
	var view := CreatureView.new()
	view.setup(Behemoths.BASTION, int(Elements.Element.NEUTRAL))
	(Engine.get_main_loop() as SceneTree).root.add_child(view)

	var parts := [
		{"id": "head", "broken": false, "severable": false},
		{"id": "shell", "broken": false, "severable": false},
		{"id": "tail", "broken": false, "severable": true},
	]
	view.update_from({"state": BehemothState.State.CHASE, "parts": parts,
		"pos": Vector2.ZERO}, 0.016)
	t.check(_named_visible(view, "shell"), "a Carapaça inteira está à mostra")
	t.check(not _named_visible(view, "raw_shell"), "a carne nasce escondida")
	t.check(_named_visible(view, "tail"), "a Cauda-maça começa no corpo")

	parts[1]["broken"] = true
	parts[2]["broken"] = true
	view.update_from({"state": BehemothState.State.CHASE, "parts": parts,
		"pos": Vector2.ZERO}, 0.016)
	t.check(not _named_visible(view, "shell"), "a Carapaça quebrada some")
	t.check(_named_visible(view, "raw_shell"), "a carne aparece na quebra")
	t.check(not _named_visible(view, "tail"), "a Cauda-maça decepada some")
	t.check(_named_visible(view, "crest"), "a Crista inteira continua à mostra")
	view.free()


## O Núcleo Errante: uma estação acesa por vez. Enquanto a Sim não mandar
## `core_station`, vale a estação 0 (o Ferrão), que é onde o ciclo começa.
func test_creature_view_lights_one_core_station(t: TestCase) -> void:
	var view := CreatureView.new()
	view.setup("faiscaia", int(Elements.Element.NEUTRAL))
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	for station in CreatureView.CORE_STATIONS.size():
		view.update_from({"state": BehemothState.State.CHASE, "parts": [],
			"pos": Vector2.ZERO, "core_station": station}, 0.016)
		for index in CreatureView.CORE_STATIONS.size():
			var name: String = CreatureView.CORE_STATIONS[index]
			t.check_eq(
				_named_visible(view, name), index == station,
				"estação %d: '%s' aceso só na vez dele" % [station, name]
			)
	view.free()


func _named_visible(view: CreatureView, prefix: String) -> bool:
	var node := _find_named_prefix(view, prefix)
	return node != null and (node as Node3D).visible
