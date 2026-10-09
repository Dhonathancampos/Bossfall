class_name TargetState
extends RefCounted

## Um alvo que recebe dano dentro da Arena.
##
## No ticket 04 é só o boneco de treino: fica parado e serve para ver se o
## Golpe acerta e quanto tira. No ticket 05 o Behemoth nasce daqui, ganhando
## Partes, Atordoamento e IA — a Apresentação continua desenhando pelos mesmos
## campos de posição, raio e Vida.

var id: int = 0
var display_name: String = ""
var pos: Vector2 = Vector2.ZERO
var radius: float = 64.0
var hp: float = 1000.0
var max_hp: float = 1000.0

## Quanto tempo ainda dura o lampejo branco de "levei uma pancada". Puramente
## para a Apresentação ter o que desenhar, mas vive aqui porque o Cliente
## precisa receber isso junto com o resto do estado.
var hit_flash: float = 0.0


static func make(id: int, display_name: String, pos: Vector2, radius: float, hp: float) -> TargetState:
	var target := TargetState.new()
	target.id = id
	target.display_name = display_name
	target.pos = pos
	target.radius = radius
	target.hp = hp
	target.max_hp = hp
	return target


func is_alive() -> bool:
	return hp > 0.0


func take_damage(amount: float) -> void:
	hp = maxf(0.0, hp - amount)
	hit_flash = SimConfig.HIT_FLASH_DURATION


func step(dt: float) -> void:
	hit_flash = maxf(0.0, hit_flash - dt)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"pos": pos,
		"radius": radius,
		"hp": hp,
		"max_hp": max_hp,
		"hit_flash": hit_flash,
	}
