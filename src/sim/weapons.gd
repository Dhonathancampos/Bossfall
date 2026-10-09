class_name Weapons
extends RefCounted

## Armas e seus Golpes, como dados.
##
## Acrescentar o Martelo ou as Lâminas é escrever uma entrada nova aqui, não um
## arquivo de código novo. A máquina de estados que lê estes números é a mesma
## para todas as armas.
##
## Um Golpe tem três fases em sequência:
##
##     |---- Preparo ----|-- Ativo --|------ Recuperação ------|
##      não acerta nada   acerta      não acerta, mas prende
##
## `combo_window` é a tolerância depois da recuperação. Durante o golpe,
## a entrada seguinte fica guardada. Os campos legados `advance` não são
## mais aplicados: golpes comuns ficam estacionários.

enum DamageType {
	## Corte: bom contra Partes decepáveis (cauda, asa).
	SLASH,
	## Impacto: bom contra Atordoamento e Partes duras (cabeça).
	BLUNT,
	## Perfuração: gera Ferimento. Reservado — nenhuma arma do escopo o usa.
	PIERCE,
}

enum Kind { LIGHT, HEAVY }

const SWORD: String = "sword"
const HAMMER: String = "hammer"
const BLADES: String = "blades"

const _DATA: Dictionary = {
	SWORD: {
		"name": "Espada",
		"blurb": "Equilibrada. Combo rápido de três Golpes e alcance médio.",
		"damage_type": DamageType.SLASH,
		"special": {
			"type": "valor",
			"name": "Valor",
			"duration": 8.0,
			"damage_mult": 1.3,
			"speed_mult": 1.15,
		},
		"light": [
			{
				"name": "Corte Horizontal",
				"windup": 0.12, "active": 0.08, "recovery": 0.22,
				"damage": 20.0, "stagger": 28.0, "part": 1.0,
				"range": 92.0, "arc": 1.7, "advance": 95.0,
				"stamina": 0.0, "aether": 5.0, "combo_window": 0.20,
			},
			{
				"name": "Corte Ascendente",
				"windup": 0.11, "active": 0.08, "recovery": 0.24,
				"damage": 23.0, "stagger": 30.0, "part": 1.0,
				"range": 96.0, "arc": 1.6, "advance": 110.0,
				"stamina": 0.0, "aether": 5.0, "combo_window": 0.22,
			},
			{
				"name": "Giro Cortante",
				"windup": 0.16, "active": 0.14, "recovery": 0.36,
				"damage": 34.0, "stagger": 55.0, "part": 1.1,
				"range": 104.0, "arc": TAU, "advance": 55.0,
				"stamina": 0.0, "aether": 9.0, "combo_window": 0.18,
			},
		],
		"heavy": [
			# Sequência provisória: valores não calibrados contra a referência.
			{
				"name": "Corte Pesado",
				"windup": 0.32, "active": 0.10, "recovery": 0.42,
				"damage": 46.0, "stagger": 95.0, "part": 1.3,
				"range": 112.0, "arc": 1.2, "advance": 140.0,
				"stamina": 16.0, "aether": 12.0, "combo_window": 0.30,
				"animation": "heavy",
			},
			{
				"name": "Retorno Pesado",
				"windup": 0.28, "active": 0.10, "recovery": 0.38,
				"damage": 48.0, "stagger": 100.0, "part": 1.3,
				"range": 112.0, "arc": 1.7, "advance": 0.0,
				"stamina": 16.0, "aether": 12.0, "combo_window": 0.30,
				"animation": "light_2",
			},
			{
				"name": "Finalizador Pesado",
				"windup": 0.36, "active": 0.14, "recovery": 0.46,
				"damage": 64.0, "stagger": 130.0, "part": 1.4,
				"range": 120.0, "arc": 1.8, "advance": 0.0,
				"stamina": 20.0, "aether": 16.0, "combo_window": 0.30,
				"animation": "heavy",
			},
		],
	},
	HAMMER: {
		"name": "Martelo",
		"blurb": "Lento e brutal. Impacto puro: é a arma que derruba o Behemoth.",
		"damage_type": DamageType.BLUNT,
		"special": {
			"type": "magma",
			"name": "Câmara de Magma",
			"damage": 70.0,
			"stagger": 240.0,
			"radius": 140.0,
			"speed": 700.0,
			"range": 820.0,
		},
		"light": [
			{
				"name": "Pancada Lateral",
				"windup": 0.22, "active": 0.10, "recovery": 0.34,
				"damage": 30.0, "stagger": 34.0, "part": 1.0,
				"range": 98.0, "arc": 1.5, "advance": 70.0,
				"stamina": 0.0, "aether": 7.0, "combo_window": 0.24,
			},
			{
				"name": "Retorno Pesado",
				"windup": 0.20, "active": 0.10, "recovery": 0.38,
				"damage": 34.0, "stagger": 38.0, "part": 1.0,
				"range": 98.0, "arc": 1.5, "advance": 80.0,
				"stamina": 0.0, "aether": 7.0, "combo_window": 0.22,
			},
			{
				"name": "Esmagada",
				"windup": 0.30, "active": 0.12, "recovery": 0.52,
				"damage": 48.0, "stagger": 70.0, "part": 1.15,
				"range": 92.0, "arc": 1.1, "advance": 55.0,
				"stamina": 0.0, "aether": 11.0, "combo_window": 0.18,
			},
		],
		## O pesado clássico: segurar arma a Rajada Concussiva, que consome
		## munição e escala por munição consumida (`blast` marca a escala;
		## `concussive` marca a entrada em carga). Sem munição sai a Coronhada.
		## O Estouro Aéter é o finalizador: terceiro leve + pesado descarrega
		## todas as munições restantes num círculo no chão.
		"heavy": [
			{
				"name": "Rajada Concussiva",
				"concussive": true, "blast": true,
				"windup": 0.10, "active": 0.10, "recovery": 0.45,
				"damage": 22.0, "stagger": 150.0, "part": 0.8,
				"range": 240.0, "arc": 0.9, "advance": 0.0,
				"stamina": 0.0, "aether": 8.0, "combo_window": 0.0,
			},
			{
				"name": "Coronhada",
				"windup": 0.18, "active": 0.10, "recovery": 0.34,
				"damage": 16.0, "stagger": 40.0, "part": 1.0,
				"range": 95.0, "arc": 1.2, "advance": 60.0,
				"stamina": 8.0, "aether": 5.0, "combo_window": 0.0,
			},
			{
				"name": "Estouro Aéter",
				"blast": true,
				"windup": 0.30, "active": 0.15, "recovery": 0.70,
				"damage": 20.0, "stagger": 110.0, "part": 1.2,
				"range": 150.0, "arc": 6.2832, "advance": 0.0,
				"stamina": 12.0, "aether": 10.0, "combo_window": 0.0,
			},
		],
	},
	BLADES: {
		"name": "Lâminas Correntes",
		"blurb": "Velocíssimas e curtas. O gancho puxa você até o Behemoth.",
		"damage_type": DamageType.SLASH,
		"special": {
			"type": "reaper",
			"name": "Dança da Ceifadora",
			"duration": 2.5,
			"tick": 0.3,
			"damage": 9.0,
			"stagger": 6.0,
			"part": 0.5,
			"range": 150.0,
		},
		"light": [
			{
				"name": "Talho Cruzado",
				"windup": 0.08, "active": 0.06, "recovery": 0.14,
				"damage": 11.0, "stagger": 10.0, "part": 0.9,
				"range": 76.0, "arc": 1.6, "advance": 55.0,
				"stamina": 0.0, "aether": 3.5, "combo_window": 0.22,
			},
			{
				"name": "Talho Reverso",
				"windup": 0.07, "active": 0.06, "recovery": 0.14,
				"damage": 11.0, "stagger": 10.0, "part": 0.9,
				"range": 76.0, "arc": 1.6, "advance": 55.0,
				"stamina": 0.0, "aether": 3.5, "combo_window": 0.22,
			},
			{
				"name": "Tesoura",
				"windup": 0.09, "active": 0.07, "recovery": 0.16,
				"damage": 14.0, "stagger": 12.0, "part": 0.95,
				"range": 80.0, "arc": 1.8, "advance": 65.0,
				"stamina": 0.0, "aether": 4.5, "combo_window": 0.22,
			},
			{
				"name": "Redemoinho",
				"windup": 0.12, "active": 0.1, "recovery": 0.26,
				"damage": 20.0, "stagger": 18.0, "part": 1.0,
				"range": 88.0, "arc": TAU, "advance": 40.0,
				"stamina": 0.0, "aether": 7.0, "combo_window": 0.2,
			},
		],
		## O pesado das Lâminas se desdobra pela distância: longe é o Gancho
		## (HOOK_PULL, resolvido pela máquina de estados — `hook` marca isso);
		## colado é o Golpe de Corrente, que gasta todos os pips de Momentum
		## (`chain` marca a escala por pip).
		"heavy": [
			{
				"name": "Gancho",
				"hook": true,
				"windup": 0.0, "active": 0.0, "recovery": 0.0,
				"damage": 0.0, "stagger": 0.0, "part": 0.0,
				"range": 420.0, "arc": 0.6, "advance": 0.0,
				"stamina": 0.0, "aether": 0.0, "combo_window": 0.0,
			},
			{
				"name": "Golpe de Corrente",
				"chain": true,
				"windup": 0.14, "active": 0.10, "recovery": 0.30,
				"damage": 22.0, "stagger": 20.0, "part": 1.0,
				"range": 110.0, "arc": 1.2, "advance": 30.0,
				"stamina": 8.0, "aether": 8.0, "combo_window": 0.0,
			},
		],
	},
}


static func ids() -> Array:
	return _DATA.keys()


static func exists(weapon_id: String) -> bool:
	return _DATA.has(weapon_id)


static func get_weapon(weapon_id: String) -> Dictionary:
	return _DATA.get(weapon_id, _DATA[SWORD])


static func display_name(weapon_id: String) -> String:
	return get_weapon(weapon_id)["name"]


static func damage_type(weapon_id: String) -> DamageType:
	return get_weapon(weapon_id)["damage_type"]


## Todos os Golpes de um tipo (leve ou pesado) de uma arma.
static func moves(weapon_id: String, kind: Kind) -> Array:
	return get_weapon(weapon_id)["heavy" if kind == Kind.HEAVY else "light"]


## Um Golpe específico. Índice fora da faixa volta ao primeiro, para que um
## Instantâneo malformado nunca derrube a Simulação.
static func move(weapon_id: String, kind: Kind, index: int) -> Dictionary:
	var list := moves(weapon_id, kind)
	if index < 0 or index >= list.size():
		return list[0]
	return list[index]


## Duração total de um Golpe, do começo do Preparo ao fim da Recuperação.
static func duration(data: Dictionary) -> float:
	return float(data["windup"]) + float(data["active"]) + float(data["recovery"])


## O Especial da arma (dados). Toda arma tem um.
static func special(weapon_id: String) -> Dictionary:
	return get_weapon(weapon_id).get("special", {})
