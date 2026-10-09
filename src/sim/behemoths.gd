class_name Behemoths
extends RefCounted

## Behemoths e seus ataques, como dados.
##
## Acrescentar o Shrike é escrever uma entrada nova aqui. A máquina de estados
## que lê estes números é a mesma para todos.
##
## Um ataque tem as mesmas três fases do Golpe do Caçador:
##
##     |---- Preparo ----|-- Ativo --|--- Recuperação ---|
##      Telegrafia no chão  acerta     indefeso-ish
##
## O Preparo é desenhado no chão. É ele que transforma a Esquiva numa decisão
## em vez de um palpite — por isso é longo, bem mais longo que o do Caçador.

## Formatos de área. O mesmo formato serve para acertar e para desenhar a
## Telegrafia, então o que você vê é literalmente o que machuca.
const SHAPE_CONE: String = "cone"
const SHAPE_CIRCLE: String = "circle"
const SHAPE_DASH: String = "dash"

const GNASHER: String = "gnasher"
const BASTION: String = "bastion"

const _DATA: Dictionary = {
	GNASHER: {
		"name": "Gnasher",
		"blurb": "Quadrúpede terrestre. Morde, investe e gira a cauda.",
		## Cérebro próprio: padrões situacionais em BehemothStep.gnasher_plan
		## (mordida dupla, investida→rabada, pisão de castigo), em vez do
		## sorteio ponderado genérico.
		"brain": "gnasher",
		"hp": 2600.0,
		## O modelo ocupa quase 5 m de ponta a ponta; este raio acompanha o
		## tronco visível para o caçador não atravessar a criatura.
		"radius": 230.0,
		"move_speed": 148.0,

		## Quão rápido vira quando está só perseguindo.
		"turn_speed": 2.4,

		## Distância que tenta manter do alvo enquanto escolhe o que fazer.
		"preferred_gap": 60.0,

		## Atordoamento: quanto precisa acumular para derrubar.
		"stagger_threshold": 420.0,

		## Partes com Vida própria. O `sector` diz onde ela mora no corpo:
		## o acerto é atribuído pela posição do golpe em relação à frente do
		## Behemoth. `severable` cai com Corte; `hard` premia Impacto.
		## `zone` é a hurtbox da Parte no plano (deslocamento ao longo da
		## frente/lado + raio, em cm): a cabeça é atingível onde a cabeça
		## está. Partes sem `zone` caem no setor angular (fallback).
		"parts": [
			{"id": "head", "name": "Cabeça", "hp": 520.0, "sector": "front", "severable": false, "hard": true,
				"zone": {"along": 210.0, "side": 0.0, "radius": 120.0}},
			{"id": "tail", "name": "Cauda", "hp": 400.0, "sector": "back", "severable": true, "hard": false,
				"zone": {"along": -245.0, "side": 0.0, "radius": 140.0}},
			{"id": "legs", "name": "Pernas", "hp": 650.0, "sector": "side", "severable": false, "hard": false,
				"zone": {"along": 0.0, "side": 0.0, "radius": 230.0}},
		],

		## Abaixo desta fração de Vida, entra em Fúria.
		"enrage_at": 0.45,
		"enrage_speed": 1.25,
		"enrage_damage": 1.3,
		"enrage_cooldown": 0.7,

		"attacks": [
			{
				"id": "bite",
				"name": "Mordida",
				"windup": 0.62, "active": 0.16, "recovery": 0.62,
				"cooldown": 2.0,
				"min_range": 0.0, "max_range": 215.0,
				## Alcance da FORMA medido do centro: corpo (230) + boca (215). Os
				## min/max_range de escolha são medidos da borda. Provisório,
				## acompanha o raio provisório do modelo.
				"shape": {"type": SHAPE_CONE, "range": 445.0, "arc": 1.15, "offset": 0.0},
				"damage": 17.0, "knockback": 250.0,
				## Rapidez com que vira durante o Preparo. Baixa o bastante para
				## dar para contornar pelo lado, alta o bastante para punir
				## quem só anda para trás.
				"turn_rate": 1.5,
				"advance": 0.0,
				"weight": 3.0,
				## Brecha curta depois da mordida: é o golpe de pressão.
				"post_gap": 0.35,
				## A mordida é rápida demais para boop — a leitura é pela
				## animação. `telegraph` fica true enquanto as animações são
				## provisórias (registrado no MEMORY.md); o alvo é false.
				"telegraph": true,
			},
			{
				"id": "charge",
				"name": "Investida",
				"windup": 0.82, "active": 0.42, "recovery": 0.85,
				"cooldown": 6.5,
				"min_range": 230.0, "max_range": 640.0,
				"shape": {"type": SHAPE_DASH, "width": 130.0, "range": 480.0},
				"damage": 24.0, "knockback": 380.0,
				"turn_rate": 0.55,
				## Velocidade do arranque durante a fase Ativa.
				"advance": 1140.0,
				"weight": 2.5,
				"post_gap": 0.55,
				## Errar a investida custa caro: recuperação estendida — a
				## janela de punição clara do padrão.
				"whiff_recovery_bonus": 0.7,
				## Interrompível no comecinho do Preparo por impacto forte
				## (Rajada do Martelo). Janela e limiar provisórios.
				"interruptible": {"until": 0.6, "threshold": 90.0},
				"telegraph": true,
			},
			{
				"id": "tail",
				"name": "Rabada",
				"windup": 0.52, "active": 0.20, "recovery": 0.70,
				"cooldown": 4.5,
				"min_range": 0.0, "max_range": 250.0,
				## Cone virado para trás: pune quem fica atrás achando que é
				## lugar seguro.
				"shape": {"type": SHAPE_CONE, "range": 475.0, "arc": 2.5, "offset": PI},
				"damage": 19.0, "knockback": 320.0,
				"turn_rate": 0.7,
				"advance": 0.0,
				"weight": 2.0,
				"post_gap": 0.6,
				"telegraph": true,
				## Some do repertório quando esta Parte é decepada (ticket 06).
				"requires_part": "tail",
			},
			{
				"id": "stomp",
				"name": "Pisão",
				"windup": 0.70, "active": 0.18, "recovery": 0.75,
				"cooldown": 7.0,
				"min_range": 0.0, "max_range": 190.0,
				"shape": {"type": SHAPE_CIRCLE, "range": 460.0},
				"damage": 22.0, "knockback": 340.0,
				"turn_rate": 0.9,
				"advance": 0.0,
				"weight": 1.5,
				## O pisão castiga quem cola; errar deixa a maior brecha.
				"post_gap": 0.9,
				"whiff_recovery_bonus": 0.4,
				"interruptible": {"until": 0.5, "threshold": 90.0},
				"telegraph": true,
			},
		],
	},
	BASTION: {
		"name": "Bastião",
		"blurb": "Tanque blindado. As placas seguram o dano até serem demolidas.",
		"hp": 3000.0,
		## Enquanto usa o mesmo modelo provisório do Gnasher, conserva o mesmo
		## volume corporal até receber a malha própria.
		"radius": 230.0,
		"move_speed": 120.0,
		"turn_speed": 1.9,
		"preferred_gap": 50.0,
		"stagger_threshold": 500.0,
		## Sem cérebro próprio ainda: usa o sorteio genérico, com esta brecha
		## entre decisões (o ritmo por Behemoth que substituiu a pausa global).
		"decision_gap": 0.7,

		## A mecânica dele: Partes com "armored" seguram o dano à Vida em
		## ARMOR_LEAK até a placa quebrar. A Cauda-maça é a única carne exposta.
		## A quebra da Carapaça atrasa o Rolamento para sempre (break_penalty).
		"parts": [
			{"id": "head", "name": "Crista", "hp": 480.0, "sector": "front",
				"severable": false, "hard": true, "armored": true},
			{"id": "shell", "name": "Carapaça", "hp": 700.0, "sector": "side",
				"severable": false, "hard": true, "armored": true,
				"break_penalty": {"attack": "roll", "extra": 1.0}},
			{"id": "tail", "name": "Cauda-maça", "hp": 420.0, "sector": "back",
				"severable": true, "hard": false},
		],

		"enrage_at": 0.40,
		"enrage_speed": 1.2,
		"enrage_damage": 1.3,
		"enrage_cooldown": 0.7,

		"attacks": [
			{
				"id": "headbutt",
				"name": "Cabeçada",
				"windup": 0.66, "active": 0.16, "recovery": 0.70,
				"cooldown": 2.2,
				"min_range": 0.0, "max_range": 220.0,
				"shape": {"type": SHAPE_CONE, "range": 450.0, "arc": 1.0, "offset": 0.0},
				"damage": 18.0, "knockback": 300.0,
				"turn_rate": 1.3,
				"advance": 0.0,
				"weight": 3.0,
			},
			{
				"id": "roll",
				"name": "Rolamento de Pedra",
				"windup": 0.90, "active": 0.50, "recovery": 0.90,
				"cooldown": 7.0,
				"min_range": 250.0, "max_range": 700.0,
				"shape": {"type": SHAPE_DASH, "width": 150.0, "range": 520.0},
				"damage": 26.0, "knockback": 420.0,
				"turn_rate": 0.40,
				"advance": 1100.0,
				"weight": 2.5,
				"post_gap": 0.6,
				"whiff_recovery_bonus": 0.6,
				"interruptible": {"until": 0.65, "threshold": 110.0},
				"telegraph": true,
			},
			{
				"id": "mace",
				"name": "Maçada",
				"windup": 0.60, "active": 0.20, "recovery": 0.75,
				"cooldown": 5.0,
				"min_range": 0.0, "max_range": 255.0,
				"shape": {"type": SHAPE_CONE, "range": 480.0, "arc": 2.2, "offset": PI},
				"damage": 21.0, "knockback": 360.0,
				"turn_rate": 0.60,
				"advance": 0.0,
				"weight": 2.0,
				"requires_part": "tail",
			},
			{
				"id": "quake",
				"name": "Tremor",
				"windup": 0.85, "active": 0.20, "recovery": 0.90,
				"cooldown": 8.0,
				"min_range": 0.0, "max_range": 200.0,
				"shape": {"type": SHAPE_CIRCLE, "range": 490.0},
				"damage": 24.0, "knockback": 380.0,
				"turn_rate": 0.80,
				"advance": 0.0,
				"weight": 1.5,
				"post_gap": 1.0,
				"interruptible": {"until": 0.6, "threshold": 110.0},
				"telegraph": true,
				"element": Elements.Element.TERRA,
			},
		],
	},
}


static func ids() -> Array:
	return _DATA.keys()


static func get_behemoth(type_id: String) -> Dictionary:
	return _DATA.get(type_id, _DATA[GNASHER])


static func display_name(type_id: String) -> String:
	return get_behemoth(type_id)["name"]


static func attacks(type_id: String) -> Array:
	return get_behemoth(type_id)["attacks"]


## Um ataque pelo id. Devolve vazio se não existir, para que um Instantâneo
## malformado não derrube a Apresentação.
static func attack(type_id: String, attack_id: String) -> Dictionary:
	for entry in attacks(type_id):
		if entry["id"] == attack_id:
			return entry
	return {}


static func duration(data: Dictionary) -> float:
	return float(data["windup"]) + float(data["active"]) + float(data["recovery"])
