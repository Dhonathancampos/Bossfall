class_name Combat
extends RefCounted

## Geometria de acerto e cálculo de dano.
##
## Separado da máquina de estados de propósito: quem decide *quando* um Golpe
## está Ativo é o HunterStep, quem decide *o que ele acerta* é isto. Na Onda 2
## a geometria ganha altura; o resto não muda.

## Um Golpe acerta um alvo quando o alvo encosta no setor circular à frente do
## Caçador: dentro do alcance, e dentro do arco.
##
## O raio do alvo entra no alcance, senão um Behemoth enorme precisaria ser
## atingido no centro exato.
static func hits(
	origin: Vector2,
	facing: float,
	move: Dictionary,
	target_pos: Vector2,
	target_radius: float
) -> bool:
	var to_target := target_pos - origin
	var reach := float(move["range"]) + target_radius
	if to_target.length_squared() > reach * reach:
		return false

	var arc := float(move["arc"])
	if arc >= TAU:
		return true

	# Alvo em cima do Caçador: sem direção definida, conta como acerto.
	if to_target.length_squared() < 0.0001:
		return true

	return absf(angle_difference(facing, to_target.angle())) <= arc * 0.5


## Um ataque de Behemoth acerta um Caçador?
##
## O mesmo formato que decide isto é o que a Apresentação desenha como
## Telegrafia: o que você vê é literalmente o que machuca.
static func shape_hits(
	origin: Vector2,
	facing: float,
	shape: Dictionary,
	body_radius: float,
	point: Vector2,
	point_radius: float
) -> bool:
	var to_point := point - origin
	var kind: String = shape.get("type", Behemoths.SHAPE_CIRCLE)

	match kind:
		Behemoths.SHAPE_DASH:
			# O corredor começa na traseira do corpo e vai até o fim da
			# investida, exatamente como a telegrafia desenhada no chão.
			var forward := Vector2.RIGHT.rotated(facing)
			var along := to_point.dot(forward)
			var sideways := to_point.dot(forward.orthogonal())
			var nearest_along := clampf(along, -body_radius, float(shape["range"]))
			var half_width := float(shape["width"]) * 0.5
			var nearest_side := clampf(sideways, -half_width, half_width)
			var offset := Vector2(along - nearest_along, sideways - nearest_side)
			return offset.length_squared() <= point_radius * point_radius

		Behemoths.SHAPE_CIRCLE:
			var radius := float(shape["range"]) + point_radius
			return to_point.length_squared() <= radius * radius

		_:
			return _cone_distance(origin, facing + float(shape.get("offset", 0.0)), float(shape["range"]), float(shape["arc"]), point) <= point_radius


## Distância do centro de um corpo circular ao setor. Checar as bordas faz um
## caçador ser atingido quando o seu collider toca a área, não só pelo centro.
static func _cone_distance(origin: Vector2, facing: float, reach: float, arc: float, point: Vector2) -> float:
	var local := point - origin
	if local.length_squared() < 0.0001:
		return 0.0
	var angle := absf(angle_difference(facing, local.angle()))
	if angle <= arc * 0.5 and local.length() <= reach:
		return 0.0

	var left := origin + Vector2.RIGHT.rotated(facing - arc * 0.5) * reach
	var right := origin + Vector2.RIGHT.rotated(facing + arc * 0.5) * reach
	return minf(
		minf(_point_segment_distance(point, origin, left), _point_segment_distance(point, origin, right)),
		minf(point.distance_to(left), point.distance_to(right))
	)


static func _point_segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared < 0.0001:
		return point.distance_to(start)
	var progress := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * progress)


## O dano de um Golpe contra um alvo.
##
## Ordem do cálculo (a da spec): base → Tipo de Dano vs Parte → [Oposição
## elemental, ticket 06] → Parte quebrada → Atordoado → [buffs, ticket 07].
static func damage(move: Dictionary) -> float:
	return float(move["damage"])


static func damage_against(
	move: Dictionary,
	damage_type: Weapons.DamageType,
	weapon_element: Elements.Element,
	target_element: Elements.Element,
	part: Dictionary,
	staggered: bool,
	buff_mult: float = 1.0
) -> float:
	var amount := float(move["damage"])

	if not part.is_empty():
		if damage_type == Weapons.DamageType.SLASH and part["severable"]:
			amount *= SimConfig.SLASH_SEVER_MULT
		elif damage_type == Weapons.DamageType.BLUNT and part["hard"]:
			amount *= SimConfig.BLUNT_HARD_MULT

	amount *= Elements.damage_multiplier(weapon_element, target_element)

	if not part.is_empty() and part["broken"]:
		amount *= SimConfig.BROKEN_PART_MULT

	if staggered:
		amount *= SimConfig.STAGGERED_DAMAGE_MULT

	# Buffs do Caçador (Valor, carga do Martelo) entram por último, como a
	# ordem da spec manda.
	return amount * buff_mult


## Quanto Atordoamento um Golpe gera: o valor do Golpe vezes o fator do Tipo
## de Dano. É aqui que o Impacto vira a arma de derrubar.
static func stagger_from(move: Dictionary, damage_type: Weapons.DamageType) -> float:
	return float(move["stagger"]) * float(SimConfig.STAGGER_TYPE_MULT[damage_type])


## Qual Parte um golpe vindo de `from_pos` atinge.
##
## Contrato de combate: quando as Partes definem `zone` (hurtbox no plano —
## deslocamento ao longo da frente/lado + raio), vence a zona mais próxima do
## atacante: a cabeça é atingível onde a cabeça ESTÁ, não num setor abstrato.
## Partes sem zona caem no setor angular (fallback para dados antigos).
static func part_hit(behemoth: BehemothState, from_pos: Vector2) -> Dictionary:
	var forward := Vector2.RIGHT.rotated(behemoth.facing)
	var side := forward.orthogonal()

	var best: Dictionary = {}
	var best_distance := INF
	for part in behemoth.parts:
		if part["broken"] and part["severable"]:
			continue  # Decepada: não existe mais para ser atingida.
		var zone: Dictionary = part.get("zone", {})
		if zone.is_empty():
			continue
		var centre := behemoth.pos \
			+ forward * float(zone.get("along", 0.0)) \
			+ side * float(zone.get("side", 0.0))
		var distance := maxf(0.0, from_pos.distance_to(centre) - float(zone.get("radius", 0.0)))
		if distance < best_distance:
			best_distance = distance
			best = part
	if not best.is_empty():
		return best

	return _part_by_sector(behemoth, from_pos)


## O fallback por setor: a frente é a cabeça, as costas são a cauda, o resto
## são as pernas. Com a cauda decepada, golpes por trás caem nas pernas.
static func _part_by_sector(behemoth: BehemothState, from_pos: Vector2) -> Dictionary:
	var angle := absf(angle_difference(behemoth.facing, (from_pos - behemoth.pos).angle()))
	var sector := "side"
	if angle < 0.9:
		sector = "front"
	elif angle > PI - 0.9:
		sector = "back"

	for part in behemoth.parts:
		if part["sector"] != sector:
			continue
		if part["broken"] and part["severable"]:
			continue
		return part
	for part in behemoth.parts:
		if part["sector"] == "side":
			return part
	return {}


## O ponto onde desenhar o número de dano: na borda do alvo, virado para quem
## bateu, para o número não sumir dentro do corpo.
static func impact_point(origin: Vector2, target_pos: Vector2, target_radius: float) -> Vector2:
	var to_origin := origin - target_pos
	if to_origin.length_squared() < 0.0001:
		return target_pos
	return target_pos + to_origin.normalized() * target_radius
