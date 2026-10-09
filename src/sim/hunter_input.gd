class_name HunterInput
extends RefCounted

## O que um Caçador está apertando durante um Tique.
##
## É a única coisa que um Cliente manda para o Anfitrião.

## Direção desejada de movimento no plano de chão. Comprimento é limitado a 1
## pela Sim, então mandar um vetor maior não deixa ninguém mais rápido.
var move: Vector2 = Vector2.ZERO

## Para onde o Caçador aponta, em radianos. Independente de `move`.
var aim: float = 0.0

## Segurando para correr.
var sprint: bool = false

## Pedido de Esquiva. Vale para um Tique só: a Apresentação arma o pedido
## quando a tecla é apertada e ele é consumido no Tique seguinte, para que uma
## apertada nunca vire dois rolamentos nem se perca entre quadros.
var dodge: bool = false

## Pedidos de Golpe leve e pesado. Como a Esquiva, valem para um Tique só.
var light: bool = false
var heavy: bool = false

## Pedido do Especial da arma. Um Tique só, como a Esquiva.
var special: bool = false

## O botão pesado continua segurado (contínuo, como `sprint`). É o que
## sustenta a carga do Martelo: o pedido entra por `heavy`, a carga dura
## enquanto `heavy_held` for verdadeiro.
var heavy_held: bool = false

## Pedido de recarga do Martelo (tecla R). Um Tique só, como a Esquiva.
var reload: bool = false

## Número de sequência, crescente, atribuído pelo Cliente. O Anfitrião devolve
## no Instantâneo a última sequência que aplicou, e é assim que o Cliente sabe
## quais Entradas ainda precisa repetir na predição.
var seq: int = 0


static func make(
	move_dir: Vector2,
	aim_angle: float,
	sequence: int = 0,
	is_sprinting: bool = false,
	is_dodging: bool = false,
	is_light: bool = false,
	is_heavy: bool = false,
	is_special: bool = false,
	is_heavy_held: bool = false,
	is_reload: bool = false
) -> HunterInput:
	var input := HunterInput.new()
	input.move = move_dir
	input.aim = aim_angle
	input.seq = sequence
	input.sprint = is_sprinting
	input.dodge = is_dodging
	input.light = is_light
	input.heavy = is_heavy
	input.special = is_special
	input.heavy_held = is_heavy_held
	input.reload = is_reload
	return input


func to_dict() -> Dictionary:
	return {
		"move": move, "aim": aim, "seq": seq,
		"sprint": sprint, "dodge": dodge, "light": light, "heavy": heavy,
		"special": special, "held": heavy_held, "reload": reload,
	}


static func from_dict(data: Dictionary) -> HunterInput:
	return HunterInput.make(
		data.get("move", Vector2.ZERO),
		data.get("aim", 0.0),
		data.get("seq", 0),
		data.get("sprint", false),
		data.get("dodge", false),
		data.get("light", false),
		data.get("heavy", false),
		data.get("special", false),
		data.get("held", false),
		data.get("reload", false)
	)
