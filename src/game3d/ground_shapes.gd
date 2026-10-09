class_name GroundShapes
extends RefCounted

## Formas pintadas no chão da cena 3D: a Telegrafia do Behemoth e o arco do
## Golpe do Caçador.
##
## A geometria vem das MESMAS definições que decidem o acerto na Sim
## (Behemoths.SHAPE_*, Weapons range/arc) — o que você vê no chão é
## literalmente o que machuca, como era no 2D.

const SCALE: float = GameWorld.SIM_TO_WORLD

## Altura mínima acima do chão, para a forma não brigar com o plano (z-fight).
const LIFT: float = 0.02


## Uma malha plana a partir de pontos no plano da Sim (em cm).
static func polygon(points_sim: PackedVector2Array, color: Color) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	# Leque a partir do primeiro ponto: as formas daqui são todas convexas ou
	# leques por construção (cone, círculo, corredor).
	for i in range(1, points_sim.size() - 1):
		mesh.surface_add_vertex(_lift(points_sim[0]))
		mesh.surface_add_vertex(_lift(points_sim[i]))
		mesh.surface_add_vertex(_lift(points_sim[i + 1]))
	mesh.surface_end()

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## Os pontos (no plano da Sim) da área de um ataque de Behemoth.
## Espelha Combat.shape_hits — mudou lá, muda aqui.
static func attack_shape_points(
	shape: Dictionary,
	pos: Vector2,
	facing: float,
	body_radius: float,
	fill: float = 1.0
) -> PackedVector2Array:
	var points := PackedVector2Array()
	match String(shape.get("type", Behemoths.SHAPE_CIRCLE)):
		Behemoths.SHAPE_DASH:
			var half := float(shape["width"]) * 0.5
			var length := float(shape["range"]) * fill
			var forward := Vector2.RIGHT.rotated(facing)
			var side := forward.orthogonal() * half
			points.append(pos - forward * body_radius + side)
			points.append(pos + forward * length + side)
			points.append(pos + forward * length - side)
			points.append(pos - forward * body_radius - side)
		Behemoths.SHAPE_CIRCLE:
			var radius := float(shape["range"]) * fill
			for i in range(36):
				points.append(pos + Vector2.RIGHT.rotated(TAU * float(i) / 36.0) * radius)
		_:
			var arc := float(shape["arc"])
			var reach := float(shape["range"]) * fill
			var centre := facing + float(shape.get("offset", 0.0))
			var start := centre - arc * 0.5
			points.append(pos)
			var steps := maxi(10, int(arc * 14.0))
			for i in range(steps + 1):
				points.append(pos + Vector2.RIGHT.rotated(start + arc * float(i) / float(steps)) * reach)
	return points


## Os pontos do setor de um Golpe de Caçador (Weapons range/arc).
static func move_arc_points(move: Dictionary, pos: Vector2, facing: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var arc := float(move["arc"])
	var reach := float(move["range"])
	if arc < TAU:
		points.append(pos)
	var start := facing - arc * 0.5
	var steps := maxi(8, int(arc * 12.0))
	for i in range(steps + 1):
		points.append(pos + Vector2.RIGHT.rotated(start + arc * float(i) / float(steps)) * reach)
	return points


static func _lift(point_sim: Vector2) -> Vector3:
	return Vector3(point_sim.x * SCALE, LIFT, point_sim.y * SCALE)
