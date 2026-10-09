class_name TrainingDummyView
extends Node3D

## Reconstrução procedural do carro-Behemoth de treino, não asset original.
## Frente = +Z. Escala acompanha a área circular do alvo da Sim.
func _init() -> void:
	var wood := _material("99582f")
	var iron := _material("483d49")
	var armor := _material("b5b851")
	var cloth := _material("ddd5a1")
	var red := _material("cb493b")
	var ivory := _material("f3e5c6")
	set_meta("material", wood)
	_box("Chassis", Vector3(1.55, 0.18, 1.65), Vector3(0, 0.65, -0.15), wood)
	for x in [-0.84, 0.84]:
		for z in [-0.72, 0.48]:
			var wheel := _cylinder("Wheel", 0.49, 0.14, Vector3(x, 0.49, z), iron)
			wheel.rotation.z = PI / 2.0
			var hub := _cylinder("WheelWood", 0.39, 0.16, Vector3(x, 0.49, z), wood)
			hub.rotation.z = PI / 2.0
			_box("LegPlate", Vector3(0.16, 0.65, 0.34), Vector3(x * 1.12, 0.42, z), armor).rotation.x = -0.16
			_box("Foot", Vector3(0.25, 0.12, 0.46), Vector3(x * 1.12, 0.09, z + 0.08), armor)
	_box("Body", Vector3(1.25, 0.78, 1.13), Vector3(0, 1.12, -0.40), wood)
	# Barril atravessado e aros de metal.
	var barrel := _cylinder("Barrel", 0.38, 1.18, Vector3(0, 1.18, 0.24), wood)
	barrel.rotation.z = PI / 2.0
	for x in [-0.48, 0.48]:
		var ring := _cylinder("BarrelBand", 0.40, 0.075, Vector3(x, 1.18, 0.24), iron)
		ring.rotation.z = PI / 2.0
	_box("CanvasTop", Vector3(1.38, 0.08, 1.16), Vector3(0, 1.55, -0.40), cloth)
	for x in [-0.65, 0.65]:
		_box("CanvasSide", Vector3(0.06, 0.46, 1.12), Vector3(x, 1.35, -0.40), cloth).rotation.z = x * 0.25
	# Focinho inclinado, boca escura, dentes e placas nas bochechas.
	_box("Snout", Vector3(0.92, 0.22, 0.85), Vector3(0, 0.66, 0.96), wood).rotation.x = 0.32
	_box("Mouth", Vector3(0.76, 0.30, 0.16), Vector3(0, 0.40, 1.30), iron)
	_box("Jaw", Vector3(0.92, 0.13, 0.62), Vector3(0, 0.24, 1.12), wood)
	for x in [-0.51, 0.51]:
		_box("Cheek", Vector3(0.12, 0.52, 0.92), Vector3(x, 0.49, 0.99), armor).rotation.x = 0.30
		_box("Eye", Vector3(0.025, 0.07, 0.19), Vector3(x * 1.13, 0.68, 0.88), red)
	for x in [-0.29, -0.10, 0.10, 0.29]:
		var tooth := CylinderMesh.new()
		tooth.top_radius = 0.0
		tooth.bottom_radius = 0.095
		tooth.height = 0.20
		tooth.radial_segments = 3
		_mesh("Tooth", tooth, Vector3(x, 0.36, 1.39), ivory)
	# Três hastes e dois painéis triangulados de tecido, silhueta da bandeira.
	for x in [-0.55, 0.0, 0.55]:
		var height := 0.94 if x == 0.0 else 0.58
		_cylinder("BannerPole", 0.025, height, Vector3(x, 1.57 + height / 2.0, -0.48), wood)
	for side in [-1.0, 1.0]:
		var flag := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 1.65, -0.48), Vector3(0, 2.48, -0.48), Vector3(side * 0.55, 2.12, -0.48), Vector3(side * 0.55, 1.65, -0.48)])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		flag.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		red.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh("Banner", flag, Vector3.ZERO, red)
	var label := Label3D.new()
	label.text = "BEHEMOTH DE TREINO"
	label.position.y = 2.85
	label.font_size = 40
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _material(hex: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.roughness = 0.85
	return material


func _box(part: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(part, mesh, at, material)


func _cylinder(part: String, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return _mesh(part, mesh, at, material)


func _mesh(part: String, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)
	return node
