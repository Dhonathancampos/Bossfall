class_name GameWorld
extends RefCounted

## Constantes da apresentação 3D.
##
## A Sim fala em centímetros num plano de chão; a cena da Godot fala em
## metros. ESTE é o único lugar onde essa conversão existe — todo nó 3D que
## precisar dela importa daqui.

## 1 unidade da Sim (1 cm) = 0,01 m na cena.
const SIM_TO_WORLD: float = 0.01


## Posição da Sim (plano de chão) → posição na cena, a uma altura dada.
static func to_world(sim_pos: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(sim_pos.x * SIM_TO_WORLD, height, sim_pos.y * SIM_TO_WORLD)


## Ângulo no plano da Sim → rotação Y de um nó que "olha" para +X local.
## No plano da Sim, +x é leste e +y é sul (herança do 2D); na cena, leste é
## +X e sul é +Z.
static func to_yaw(sim_angle: float) -> float:
	return -sim_angle


## O ângulo da Sim correspondente à direção para onde uma câmera aponta.
static func aim_from_forward(forward: Vector3) -> float:
	return Vector2(forward.x, forward.z).angle()
