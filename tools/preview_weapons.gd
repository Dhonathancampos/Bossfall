extends SceneTree

## Captura as três armas montadas nos rigs reais, em repouso e ataque.
## Rodar com renderizador (sem --headless), --rendering-method gl_compatibility.
func _initialize() -> void:
	call_deferred("preview")

func preview() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(6, 5, 10)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.0
	camera.make_current()
	var light := DirectionalLight3D.new()
	scene.add_child(light)
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 2.0
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("303946")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	scene.add_child(environment)
	var ids := [Weapons.SWORD, Weapons.HAMMER, Weapons.BLADES]
	for row in 2:
		for column in 3:
			var view := HunterView.new()
			view.setup(ids[column], Color("63c9e8"))
			scene.add_child(view)
			view.position = Vector3((column - 1) * 3.0, 0, (row - 0.5) * 3.0)
			var player: AnimationPlayer = view.get("_player")
			player.play("idle" if row == 0 else "light_1")
			player.seek(0.0 if row == 0 else 0.18, true)
			player.pause()
			var label := Label3D.new()
			view.add_child(label)
			label.text = ids[column] + (" / idle" if row == 0 else " / ataque")
			label.position.y = 2.3
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 48
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	var result := capture.save_png("res://.scratch/weapons-preview.png")
	print("Captura de armas: ", result)
	quit(result)
