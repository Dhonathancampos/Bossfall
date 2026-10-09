extends SceneTree

## Inspeção reproduzível: boneco e quatro fases da corrida, sem headless.
func _initialize() -> void:
	call_deferred("preview")

func preview() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(6, 5, 9)
	camera.look_at(Vector3(0, 1, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.0
	camera.make_current()
	var light := DirectionalLight3D.new()
	scene.add_child(light)
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_energy = 1.7
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("303946")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	scene.add_child(environment)
	var dummy := TrainingDummyView.new()
	scene.add_child(dummy)
	dummy.position = Vector3(0, 0, -2.4)
	for column in 4:
		var view := HunterView.new()
		view.setup(Weapons.SWORD, Color("63c9e8"))
		scene.add_child(view)
		view.position = Vector3((column - 1.5) * 2.0, 0, 1.2)
		var player: AnimationPlayer = view.get("_player")
		player.play("sprint")
		player.seek(0.55 * column / 4.0, true)
		player.pause()
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://.scratch/combat-preview.png")
	print("Captura combate: ", result)
	quit(result)
