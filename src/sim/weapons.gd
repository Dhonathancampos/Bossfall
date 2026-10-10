class_name Weapons
extends RefCounted

## Armas, seus Golpes e o GRAFO DE COMBO de cada uma, como dados.
##
## Acrescentar uma arma é escrever uma entrada aqui, não um arquivo de código
## novo. A máquina que lê estes números é a mesma para todas.
##
## Um Golpe tem três fases em sequência:
##
##     |---- Preparo ----|-- Ativo --|------ Recuperação ------|
##      não acerta nada   acerta      não acerta, mas prende
##
## ## O grafo de combo (ticket 14)
##
## O encadeamento NÃO é mais "o próximo índice do mesmo tipo". Cada Golpe é um
## **nó** com um `id`, e declara as arestas que saem dele em `next`. A arma
## declara por onde se ENTRA no grafo em `entry`, por contexto (`free`,
## `sprint`, `dodge`). Estar no nó `l2` já É ter vindo de L,L — não existe
## histórico guardado em lugar nenhum.
##
## Vocabulários fechados (a máquina interpreta; nenhuma arma traz código):
##
## - `input`: `light`, `heavy`, `light_hold`, `heavy_hold`, `reload`.
##   `*_hold` casa quando o botão é apertado E continua segurado.
## - `if` (predicado): `brio>=n`, `ammo>=n`, `ammo==0`, `pips>=n`, `mag>=n`,
##   `near`, `far`, `back_dodge`, `no_world`. `near`/`far` precisam do mundo;
##   na predição do Cliente (sem mundo) só valem candidatas `no_world`.
## - `on_start`/`on_end` (efeitos): `brio+n`, `brio-n`, `ammo+1`, `ammo-1`,
##   `ammo_all`, `pips_all`, `det+1`.
## - `to: "@algo"`: ponte para um ESTADO da máquina (`@hook`, `@charging`,
##   `@tumble`), não para um nó. O grafo decide QUANDO; o estado decide COMO.
## - transição sem `to`, só com `on_start`: aplica o efeito e mantém o nó e a
##   janela (a recarga encaixada do Martelo).
##
## Campos de nó que a máquina entende além das três fases:
##
## - `id`: o nome do nó. Golpe SEM `id` não participa do grafo (o Gancho, a
##   Rajada em carga, o tiro das Repetidoras e o Rolinho são estados/ações).
## - `window`: a Janela de Combo depois da Recuperação (`combo_window`).
## - `lunge`: deslocamento total à frente durante Preparo+Ativo, em cm
##   (negativo = para trás). É a EXCEÇÃO declarada à regra "golpe não locomove".
## - `pulse_every`: o Golpe acerta em pulsos (multi-hit) em vez de uma vez só.
## - `channel`: o Golpe se sustenta enquanto o botão estiver seguro, drenando
##   `channel_stamina` por segundo, até `channel_max` segundos.
## - `channel_speedup`: cada pulso do canal sai esta fração mais rápido.
## - `chargeable`: o Preparo pode ser segurado (Machado), escalando o dano.
## - `projectile`: o nó cospe um projétil ao começar.
##
## Armas sem `entry` declarada ganham um grafo LINEAR compilado das listas
## `light`/`heavy` — comportamento idêntico ao do sistema antigo de índices.
## Os campos legados `advance` não são mais aplicados.

enum DamageType {
	## Corte: bom contra Partes decepáveis (cauda, asa).
	SLASH,
	## Impacto: bom contra Atordoamento e Partes duras (cabeça).
	BLUNT,
	## Perfuração: gera Ferimento. A Lança de Guerra é a primeira usuária.
	PIERCE,
	## Balístico: físico neutro, sem bônus de decepar nem de Parte dura.
	## (No FIM do enum: os ints viajam em dados.)
	BALLISTIC,
}

enum Kind { LIGHT, HEAVY }

const SWORD: String = "sword"
const HAMMER: String = "hammer"
const BLADES: String = "blades"
const AXE: String = "axe"
const PIKE: String = "pike"
const REPEATERS: String = "repeaters"

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
		## Brio: pips ganhos fechando cadeias, gastos nos Golpes de desvio.
		## Nome nosso para não colidir com o Especial "Valor", que não muda.
		"entry": {
			"free": [
				{"input": "light_hold", "if": "brio>=3", "to": "investida_brio"},
				{"input": "heavy_hold", "if": "brio>=3", "to": "onda_brio"},
				{"input": "light", "to": "l1"},
				{"input": "heavy", "to": "h1"},
			],
			"sprint": [
				{"input": "light", "to": "estocada_corrida"},
				{"input": "heavy", "to": "h1"},
			],
			"dodge": [
				{"input": "light", "to": "bote_rasteiro"},
			],
		},
		"light": [
			{
				"id": "l1", "name": "Corte Horizontal",
				"windup": 0.12, "active": 0.08, "recovery": 0.22,
				"damage": 20.0, "stagger": 28.0, "part": 1.0,
				"range": 92.0, "arc": 1.7,
				"stamina": 0.0, "aether": 5.0, "combo_window": 0.20,
				"next": [{"input": "light", "to": "l2"}, {"input": "heavy", "to": "h1"}],
			},
			{
				"id": "l2", "name": "Corte Ascendente",
				"windup": 0.11, "active": 0.08, "recovery": 0.24,
				"damage": 23.0, "stagger": 30.0, "part": 1.0,
				"range": 96.0, "arc": 1.6,
				"stamina": 0.0, "aether": 5.0, "combo_window": 0.22,
				"next": [
					{"input": "light", "to": "l3"},
					{"input": "heavy", "if": "brio>=3", "to": "meia_lua"},
					{"input": "heavy", "to": "h1"},
				],
			},
			{
				"id": "l3", "name": "Giro Cortante",
				"windup": 0.16, "active": 0.14, "recovery": 0.36,
				"damage": 34.0, "stagger": 55.0, "part": 1.1,
				"range": 104.0, "arc": TAU,
				"stamina": 0.0, "aether": 9.0, "combo_window": 0.18,
				"on_end": ["brio+1"],
				"next": [{"input": "light", "to": "l1"}, {"input": "heavy", "to": "h1"}],
			},
			{
				## O leve de ligação: é AQUI que L-L-H e H-L-H divergem.
				"id": "hl", "name": "Corte de Ligação",
				"windup": 0.10, "active": 0.07, "recovery": 0.20,
				"damage": 18.0, "stagger": 24.0, "part": 1.0,
				"range": 94.0, "arc": 1.6,
				"stamina": 0.0, "aether": 4.0, "combo_window": 0.26,
				"next": [
					{"input": "heavy", "if": "brio>=3", "to": "eco"},
					{"input": "heavy", "to": "h2"},
					{"input": "light", "to": "l2"},
				],
			},
			{
				"id": "investida_brio", "name": "Investida de Brio",
				"windup": 0.18, "active": 0.12, "recovery": 0.30,
				"damage": 55.0, "stagger": 70.0, "part": 1.2,
				"range": 100.0, "arc": 1.4, "lunge": 300.0,
				"stamina": 0.0, "aether": 10.0, "combo_window": 0.26,
				"on_start": ["brio-3"],
				"next": [{"input": "light", "to": "l2"}],
			},
			{
				"id": "estocada_corrida", "name": "Estocada em Corrida",
				"windup": 0.10, "active": 0.08, "recovery": 0.24,
				"damage": 24.0, "stagger": 30.0, "part": 1.0,
				"range": 100.0, "arc": 1.0, "lunge": 90.0,
				"stamina": 0.0, "aether": 5.0, "combo_window": 0.26,
				"next": [{"input": "light", "to": "l2"}],
			},
			{
				"id": "bote_rasteiro", "name": "Bote Rasteiro",
				"windup": 0.10, "active": 0.08, "recovery": 0.22,
				"damage": 22.0, "stagger": 26.0, "part": 1.0,
				"range": 98.0, "arc": 1.0, "lunge": 70.0,
				"stamina": 0.0, "aether": 5.0, "combo_window": 0.26,
				"next": [{"input": "light", "to": "l2"}],
			},
		],
		"heavy": [
			{
				"id": "h1", "name": "Corte Pesado",
				"windup": 0.32, "active": 0.10, "recovery": 0.42,
				"damage": 46.0, "stagger": 95.0, "part": 1.3,
				"range": 112.0, "arc": 1.2,
				"stamina": 16.0, "aether": 12.0, "combo_window": 0.30,
				"animation": "heavy",
				"next": [{"input": "heavy", "to": "h2"}, {"input": "light", "to": "hl"}],
			},
			{
				"id": "h2", "name": "Retorno Pesado",
				"windup": 0.28, "active": 0.10, "recovery": 0.38,
				"damage": 48.0, "stagger": 100.0, "part": 1.3,
				"range": 112.0, "arc": 1.7,
				"stamina": 16.0, "aether": 12.0, "combo_window": 0.30,
				"animation": "light_2",
				"next": [{"input": "heavy", "to": "h3"}, {"input": "light", "to": "hl"}],
			},
			{
				"id": "h3", "name": "Finalizador Pesado",
				"windup": 0.36, "active": 0.14, "recovery": 0.46,
				"damage": 64.0, "stagger": 130.0, "part": 1.4,
				"range": 120.0, "arc": 1.8,
				"stamina": 20.0, "aether": 16.0, "combo_window": 0.30,
				"animation": "heavy",
				"on_end": ["brio+2"],
				"next": [{"input": "heavy", "to": "h1"}, {"input": "light", "to": "l1"}],
			},
			{
				"id": "meia_lua", "name": "Golpe de Meia-Lua",
				"windup": 0.26, "active": 0.12, "recovery": 0.44,
				"damage": 95.0, "stagger": 140.0, "part": 1.5,
				"range": 120.0, "arc": 2.0,
				"stamina": 0.0, "aether": 16.0, "combo_window": 0.30,
				"on_start": ["brio-3"],
				"next": [{"input": "light", "to": "l1"}],
			},
			{
				## Crava a espada: a poça pulsa durante a fase Ativa.
				"id": "eco", "name": "Eco Cravado",
				"windup": 0.30, "active": 0.50, "recovery": 0.60,
				"damage": 18.0, "stagger": 15.0, "part": 1.0,
				"range": 130.0, "arc": TAU, "pulse_every": 0.12,
				"stamina": 0.0, "aether": 6.0, "combo_window": 0.0,
				"on_start": ["brio-3"],
				"next": [],
			},
			{
				"id": "onda_brio", "name": "Onda de Brio",
				"windup": 0.30, "active": 0.0, "recovery": 0.40,
				"damage": 0.0, "stagger": 0.0, "part": 0.0,
				"range": 0.0, "arc": 0.0,
				"stamina": 0.0, "aether": 0.0, "combo_window": 0.0,
				"projectile": "brio_wave",
				"on_start": ["brio-3"],
				"next": [],
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
		"entry": {
			"free": [
				{"input": "light", "to": "p1"},
				{"input": "heavy_hold", "if": "ammo>=1", "to": "@charging"},
				{"input": "heavy", "if": "ammo==0", "to": "coronhada"},
				{"input": "heavy", "to": "@charging"},
			],
			"sprint": [
				{"input": "heavy", "to": "salto_demolidor"},
				{"input": "light", "to": "p1"},
			],
			"dodge": [
				{"input": "light", "to": "pancada_curta"},
			],
		},
		"light": [
			{
				"id": "p1", "name": "Pancada Lateral",
				"windup": 0.22, "active": 0.10, "recovery": 0.34,
				"damage": 30.0, "stagger": 34.0, "part": 1.0,
				"range": 98.0, "arc": 1.5,
				"stamina": 0.0, "aether": 7.0, "combo_window": 0.24,
				"next": [
					{"input": "light", "to": "p2"},
					## Segurar arma a Rajada SEM quebrar a cadeia (o estado
					## congela a janela); tocar sai o disparo encaixado.
					{"input": "heavy_hold", "if": "ammo>=1", "to": "@charging"},
					{"input": "heavy", "if": "ammo>=1", "to": "prep1"},
					{"input": "reload", "on_start": ["ammo+1"]},
				],
			},
			{
				"id": "p2", "name": "Retorno Pesado",
				"windup": 0.20, "active": 0.10, "recovery": 0.38,
				"damage": 34.0, "stagger": 38.0, "part": 1.0,
				"range": 98.0, "arc": 1.5,
				"stamina": 0.0, "aether": 7.0, "combo_window": 0.22,
				"next": [
					{"input": "light", "to": "p3"},
					{"input": "heavy_hold", "if": "ammo>=1", "to": "@charging"},
					{"input": "heavy", "if": "ammo>=1", "to": "prep2"},
					{"input": "reload", "on_start": ["ammo+1"]},
				],
			},
			{
				"id": "p3", "name": "Esmagada",
				"windup": 0.30, "active": 0.12, "recovery": 0.52,
				"damage": 48.0, "stagger": 70.0, "part": 1.15,
				"range": 92.0, "arc": 1.1,
				"stamina": 0.0, "aether": 11.0, "combo_window": 0.18,
				"next": [
					{"input": "heavy", "if": "ammo>=1", "to": "estouro"},
					{"input": "light", "to": "p1"},
					{"input": "reload", "on_start": ["ammo+1"]},
				],
			},
			{
				"id": "pancada_curta", "name": "Pancada Curta",
				"windup": 0.14, "active": 0.08, "recovery": 0.26,
				"damage": 22.0, "stagger": 30.0, "part": 1.0,
				"range": 94.0, "arc": 1.4,
				"stamina": 0.0, "aether": 6.0, "combo_window": 0.24,
				"next": [{"input": "light", "to": "p2"}],
			},
		],
		## O pesado clássico: segurar arma a Rajada Concussiva, que consome
		## munição e escala por munição consumida (`blast` marca a escala;
		## `concussive` marca a entrada em carga). Sem munição sai a Coronhada.
		## O Estouro Aéter é o finalizador: terceiro leve + pesado descarrega
		## todas as munições restantes num círculo no chão.
		"heavy": [
			{
				## Sem `id`: não é um nó do grafo. Sai do estado CHARGING.
				"name": "Rajada Concussiva",
				"concussive": true, "blast": true,
				"windup": 0.10, "active": 0.10, "recovery": 0.45,
				"damage": 22.0, "stagger": 150.0, "part": 0.8,
				"range": 240.0, "arc": 0.9,
				"stamina": 0.0, "aether": 8.0, "combo_window": 0.0,
			},
			{
				"id": "coronhada", "name": "Coronhada",
				"windup": 0.18, "active": 0.10, "recovery": 0.34,
				"damage": 16.0, "stagger": 40.0, "part": 1.0,
				"range": 95.0, "arc": 1.2,
				"stamina": 8.0, "aether": 5.0, "combo_window": 0.24,
				"next": [{"input": "light", "to": "p2"}],
			},
			{
				"id": "estouro", "name": "Estouro Aéter",
				"blast": true,
				"windup": 0.30, "active": 0.15, "recovery": 0.70,
				"damage": 20.0, "stagger": 110.0, "part": 1.2,
				"range": 150.0, "arc": TAU,
				"stamina": 12.0, "aether": 10.0, "combo_window": 0.0,
				"on_start": ["ammo_all"],
				"next": [],
			},
			{
				## Golpe PREPARADO: pancada com o cano entre dois leves. Gasta
				## uma munição e NÃO reinicia a cadeia — a assinatura da arma.
				"id": "prep1", "name": "Disparo Encaixado I",
				"windup": 0.14, "active": 0.10, "recovery": 0.30,
				"damage": 44.0, "stagger": 90.0, "part": 1.1,
				"range": 150.0, "arc": 1.0,
				"stamina": 0.0, "aether": 8.0, "combo_window": 0.26,
				"on_start": ["ammo-1"],
				"next": [{"input": "light", "to": "p2"}],
			},
			{
				"id": "prep2", "name": "Disparo Encaixado II",
				"windup": 0.14, "active": 0.10, "recovery": 0.30,
				"damage": 44.0, "stagger": 95.0, "part": 1.1,
				"range": 150.0, "arc": 1.0,
				"stamina": 0.0, "aether": 8.0, "combo_window": 0.26,
				"on_start": ["ammo-1"],
				"next": [{"input": "light", "to": "p3"}],
			},
			{
				"id": "salto_demolidor", "name": "Salto Demolidor",
				"windup": 0.34, "active": 0.12, "recovery": 0.50,
				"damage": 44.0, "stagger": 120.0, "part": 1.2,
				"range": 120.0, "arc": 1.6, "lunge": 160.0,
				"stamina": 14.0, "aether": 10.0, "combo_window": 0.24,
				"next": [{"input": "light", "to": "p3"}],
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
		"entry": {
			"free": [
				{"input": "light", "to": "t1"},
				{"input": "heavy", "if": "near", "to": "corrente"},
				{"input": "heavy", "if": "far", "to": "@hook"},
			],
			"sprint": [
				{"input": "light", "to": "talho_corrida"},
			],
			"dodge": [
				{"input": "heavy", "if": "back_dodge", "to": "salto_recuo"},
				{"input": "light", "to": "cruzado_rasante"},
			],
		},
		"light": [
			{
				"id": "t1", "name": "Talho Cruzado",
				"windup": 0.08, "active": 0.06, "recovery": 0.14,
				"damage": 11.0, "stagger": 10.0, "part": 0.9,
				"range": 76.0, "arc": 1.6,
				"stamina": 0.0, "aether": 3.5, "combo_window": 0.22,
				"next": [
					{"input": "light", "to": "t2"},
					{"input": "heavy", "if": "far", "to": "@hook"},
					{"input": "heavy", "to": "h1"},
				],
			},
			{
				"id": "t2", "name": "Talho Reverso",
				"windup": 0.07, "active": 0.06, "recovery": 0.14,
				"damage": 11.0, "stagger": 10.0, "part": 0.9,
				"range": 76.0, "arc": 1.6,
				"stamina": 0.0, "aether": 3.5, "combo_window": 0.22,
				"next": [
					{"input": "light", "to": "t3"},
					{"input": "heavy", "if": "far", "to": "@hook"},
					{"input": "heavy", "to": "giro_amplo"},
				],
			},
			{
				"id": "t3", "name": "Tesoura",
				"windup": 0.09, "active": 0.07, "recovery": 0.16,
				"damage": 14.0, "stagger": 12.0, "part": 0.95,
				"range": 80.0, "arc": 1.8,
				"stamina": 0.0, "aether": 4.5, "combo_window": 0.22,
				"next": [
					{"input": "heavy_hold", "to": "roda_viva"},
					{"input": "light", "to": "t4"},
					{"input": "heavy", "if": "far", "to": "@hook"},
				],
			},
			{
				"id": "t4", "name": "Redemoinho",
				"windup": 0.12, "active": 0.1, "recovery": 0.26,
				"damage": 20.0, "stagger": 18.0, "part": 1.0,
				"range": 88.0, "arc": TAU,
				"stamina": 0.0, "aether": 7.0, "combo_window": 0.2,
				"next": [{"input": "light", "to": "t5"}],
			},
			{
				## O 5º leve fecha a cadeia com o melhor ganho de Momentum.
				"id": "t5", "name": "Lâmina Dupla",
				"windup": 0.10, "active": 0.08, "recovery": 0.20,
				"damage": 18.0, "stagger": 16.0, "part": 1.0,
				"range": 82.0, "arc": 1.8, "momentum": 50.0,
				"stamina": 0.0, "aether": 6.0, "combo_window": 0.22,
				"next": [{"input": "light", "to": "t1"}],
			},
			{
				"id": "corte_cruzado", "name": "Corte Cruzado",
				"windup": 0.10, "active": 0.08, "recovery": 0.22,
				"damage": 30.0, "stagger": 28.0, "part": 1.1,
				"range": 92.0, "arc": 1.8,
				"stamina": 0.0, "aether": 8.0, "combo_window": 0.0,
				"next": [],
			},
			{
				"id": "talho_corrida", "name": "Talho em Disparada",
				"windup": 0.08, "active": 0.08, "recovery": 0.18,
				"damage": 16.0, "stagger": 12.0, "part": 0.95,
				"range": 84.0, "arc": 1.5, "lunge": 80.0,
				"stamina": 0.0, "aether": 4.5, "combo_window": 0.24,
				"next": [{"input": "light", "to": "t2"}],
			},
			{
				"id": "cruzado_rasante", "name": "Cruzado Rasante",
				"windup": 0.08, "active": 0.08, "recovery": 0.18,
				"damage": 18.0, "stagger": 14.0, "part": 0.95,
				"range": 84.0, "arc": 1.6, "lunge": 70.0,
				"stamina": 0.0, "aether": 5.0, "combo_window": 0.24,
				"next": [{"input": "light", "to": "t2"}],
			},
		],
		## O pesado das Lâminas se desdobra pela distância: longe é o Gancho
		## (HOOK_PULL, resolvido pela máquina de estados — `hook` marca isso);
		## colado é o Golpe de Corrente, que gasta todos os pips de Momentum
		## (`chain` marca a escala por pip).
		"heavy": [
			{
				## Sem `id`: o Gancho não é Golpe, é o estado HOOK_PULL.
				"name": "Gancho",
				"hook": true,
				"windup": 0.0, "active": 0.0, "recovery": 0.0,
				"damage": 0.0, "stagger": 0.0, "part": 0.0,
				"range": 420.0, "arc": 0.6,
				"stamina": 0.0, "aether": 0.0, "combo_window": 0.0,
			},
			{
				"id": "corrente", "name": "Golpe de Corrente",
				"chain": true,
				"windup": 0.14, "active": 0.10, "recovery": 0.30,
				"damage": 22.0, "stagger": 20.0, "part": 1.0,
				"range": 110.0, "arc": 1.2,
				"stamina": 8.0, "aether": 8.0, "combo_window": 0.24,
				"on_start": ["pips_all"],
				"next": [{"input": "light", "to": "t3"}],
			},
			{
				"id": "giro_amplo", "name": "Giro Amplo",
				"windup": 0.12, "active": 0.30, "recovery": 0.24,
				"damage": 8.0, "stagger": 7.0, "part": 0.8,
				"range": 96.0, "arc": TAU, "pulse_every": 0.10,
				"stamina": 0.0, "aether": 3.0, "combo_window": 0.24,
				"next": [{"input": "light", "to": "corte_cruzado"}],
			},
			{
				## Canal: gira enquanto o pesado estiver seguro.
				"id": "roda_viva", "name": "Roda Viva",
				"windup": 0.12, "active": 0.0, "recovery": 0.28,
				"damage": 7.0, "stagger": 5.0, "part": 0.7,
				"range": 96.0, "arc": TAU,
				"channel": true, "channel_max": 2.5, "channel_stamina": 14.0,
				"pulse_every": 0.25,
				"stamina": 0.0, "aether": 2.5, "combo_window": 0.24,
				"next": [{"input": "light", "to": "corte_cruzado"}],
			},
			{
				"id": "h1", "name": "Dentes da Corrente I",
				"windup": 0.14, "active": 0.10, "recovery": 0.24,
				"damage": 16.0, "stagger": 14.0, "part": 1.0,
				"range": 88.0, "arc": 1.4,
				"stamina": 6.0, "aether": 5.0, "combo_window": 0.24,
				"next": [{"input": "heavy", "to": "h2"}],
			},
			{
				"id": "h2", "name": "Dentes da Corrente II",
				"windup": 0.14, "active": 0.10, "recovery": 0.24,
				"damage": 17.0, "stagger": 14.0, "part": 1.0,
				"range": 88.0, "arc": 1.4,
				"stamina": 6.0, "aether": 5.0, "combo_window": 0.24,
				"next": [{"input": "heavy", "to": "h3"}],
			},
			{
				"id": "h3", "name": "Dentes da Corrente III",
				"windup": 0.14, "active": 0.10, "recovery": 0.24,
				"damage": 22.0, "stagger": 14.0, "part": 1.1,
				"range": 90.0, "arc": 1.4,
				"stamina": 6.0, "aether": 6.0, "combo_window": 0.0,
				"next": [],
			},
			{
				## Afastamento: salta para trás, sem dano. Abre espaço.
				"id": "salto_recuo", "name": "Salto de Recuo",
				"windup": 0.10, "active": 0.0, "recovery": 0.30,
				"damage": 0.0, "stagger": 0.0, "part": 0.0,
				"range": 0.0, "arc": 0.0, "lunge": -220.0,
				"stamina": 10.0, "aether": 0.0, "combo_window": 0.0,
				"next": [],
			},
		],
	},
	AXE: {
		"name": "Machado",
		"blurb": "Lento e devastador. Segure o golpe para carregar; solte para arrasar.",
		"damage_type": DamageType.SLASH,
		"special": {
			## Voo da Ruína: projétil de ida e volta.
			"type": "ruin",
			"name": "Voo da Ruína",
			"damage": 55.0,
			"stagger": 90.0,
			"part": 1.2,
			"speed": 640.0,
			"range": 520.0,
			"radius": 26.0,
			"catch_refund": 25.0,
		},
		"entry": {
			"free": [
				{"input": "light", "to": "talho_amplo"},
				{"input": "heavy", "to": "racha_cranio"},
			],
			"sprint": [
				{"input": "light", "to": "ceifa_corrida"},
			],
			"dodge": [
				{"input": "light", "to": "corte_erguido"},
			],
		},
		## Horizontais largos, todos carregáveis. Vigor zero nos toques; a
		## CARGA tem dreno próprio (AXE_CHARGE_DRAIN_PER_SECOND).
		"light": [
			{
				"id": "talho_amplo", "name": "Talho Amplo",
				"chargeable": true,
				"windup": 0.26, "active": 0.10, "recovery": 0.40,
				"damage": 36.0, "stagger": 40.0, "part": 1.1,
				"range": 110.0, "arc": 2.2,
				"stamina": 0.0, "aether": 8.0, "combo_window": 0.30,
				"next": [
					{"input": "light", "to": "talho_retorno"},
					{"input": "heavy", "to": "racha_cranio"},
				],
			},
			{
				"id": "talho_retorno", "name": "Talho de Retorno",
				"chargeable": true,
				"windup": 0.24, "active": 0.10, "recovery": 0.42,
				"damage": 40.0, "stagger": 44.0, "part": 1.1,
				"range": 110.0, "arc": 2.2,
				"stamina": 0.0, "aether": 8.0, "combo_window": 0.30,
				"animation": "light_2",
				"next": [
					{"input": "light", "to": "ceifa_total"},
					{"input": "heavy", "to": "queda_ruina"},
				],
			},
			{
				"id": "ceifa_total", "name": "Ceifa Total",
				"chargeable": true,
				"windup": 0.34, "active": 0.14, "recovery": 0.60,
				"damage": 56.0, "stagger": 80.0, "part": 1.2,
				"range": 124.0, "arc": TAU,
				"stamina": 0.0, "aether": 12.0, "combo_window": 0.26,
				"next": [{"input": "heavy", "to": "queda_ruina"}],
			},
			{
				"id": "ceifa_corrida", "name": "Ceifa em Corrida",
				"windup": 0.24, "active": 0.14, "recovery": 0.40,
				"damage": 44.0, "stagger": 50.0, "part": 1.1,
				"range": 120.0, "arc": 2.2, "lunge": 100.0,
				"stamina": 0.0, "aether": 9.0, "combo_window": 0.28,
				"next": [{"input": "light", "to": "talho_retorno"}],
			},
			{
				"id": "corte_erguido", "name": "Corte Erguido",
				"windup": 0.18, "active": 0.10, "recovery": 0.32,
				"damage": 36.0, "stagger": 40.0, "part": 1.1,
				"range": 112.0, "arc": 1.6,
				"stamina": 0.0, "aether": 8.0, "combo_window": 0.28,
				"next": [
					{"input": "heavy", "to": "queda_ruina"},
					{"input": "light", "to": "talho_retorno"},
				],
			},
		],
		## Verticais estreitos e brutais, também carregáveis. Pagam vigor.
		"heavy": [
			{
				"id": "racha_cranio", "name": "Racha-Crânio",
				"chargeable": true, "resolve_on_perfect": true,
				"windup": 0.36, "active": 0.12, "recovery": 0.50,
				"damage": 58.0, "stagger": 70.0, "part": 1.4,
				"range": 116.0, "arc": 1.1,
				"stamina": 18.0, "aether": 12.0, "combo_window": 0.30,
				"animation": "heavy",
				"next": [
					{"input": "heavy", "to": "queda_ruina"},
					{"input": "light", "to": "talho_retorno"},
				],
			},
			{
				"id": "queda_ruina", "name": "Queda da Ruína",
				"chargeable": true, "resolve_on_perfect": true,
				"windup": 0.46, "active": 0.14, "recovery": 0.62,
				"damage": 78.0, "stagger": 110.0, "part": 1.5,
				"range": 120.0, "arc": 1.1,
				"stamina": 22.0, "aether": 16.0, "combo_window": 0.30,
				"animation": "heavy",
				"next": [
					{"input": "heavy_hold", "to": "ceifa_continua"},
					{"input": "heavy", "to": "racha_cranio"},
				],
			},
			{
				## Ripper: verticais repetidos enquanto segurar o pesado,
				## cada ciclo um pouco mais rápido.
				"id": "ceifa_continua", "name": "Ceifa Contínua",
				"windup": 0.20, "active": 0.0, "recovery": 0.30,
				"damage": 34.0, "stagger": 40.0, "part": 1.2,
				"range": 116.0, "arc": 1.3,
				"channel": true, "channel_max": 3.0, "channel_stamina": 18.0,
				"pulse_every": 0.55, "channel_speedup": 1.08,
				"stamina": 0.0, "aether": 8.0, "combo_window": 0.0,
				"next": [],
			},
		],
	},
	PIKE: {
		"name": "Lança de Guerra",
		"blurb": "Estocadas perfurantes que Ferem. O medidor vira munição de canhão.",
		"damage_type": DamageType.PIERCE,
		"special": {
			## Conversão Aetérica: converte o medidor em munição de canhão.
			"type": "conversion",
			"name": "Conversão Aetérica",
			"ammo_thresholds": [10.0, 33.0, 66.0, 90.0],
			"damage_base": 35.0, "damage_per_level": 30.0,
			"stagger_base": 60.0, "stagger_per_level": 60.0,
			"speed": 820.0, "range": 900.0, "radius": 16.0,
		},
		"entry": {
			"free": [
				{"input": "light", "to": "e1"},
				{"input": "heavy", "to": "varredura"},
			],
			"sprint": [
				{"input": "light", "to": "estocada_disparada"},
			],
			"dodge": [
				{"input": "light", "to": "estocada_rasante"},
				{"input": "heavy", "to": "varredura_saltada"},
			],
		},
		"light": [
			{
				"id": "e1", "name": "Estocada",
				"windup": 0.10, "active": 0.06, "recovery": 0.16,
				"damage": 14.0, "stagger": 10.0, "part": 1.0,
				"range": 136.0, "arc": 0.55,
				"stamina": 0.0, "aether": 4.0, "combo_window": 0.22,
				"next": [
					{"input": "light", "to": "e2"},
					{"input": "heavy", "to": "varredura"},
				],
			},
			{
				"id": "e2", "name": "Estocada Dupla",
				"windup": 0.09, "active": 0.06, "recovery": 0.16,
				"damage": 14.0, "stagger": 10.0, "part": 1.0,
				"range": 136.0, "arc": 0.55,
				"stamina": 0.0, "aether": 4.0, "combo_window": 0.22,
				"animation": "light_2",
				"next": [
					{"input": "light", "to": "e3"},
					{"input": "heavy", "to": "varredura"},
				],
			},
			{
				"id": "e3", "name": "Estocada Alta",
				"windup": 0.10, "active": 0.07, "recovery": 0.18,
				"damage": 16.0, "stagger": 12.0, "part": 1.05,
				"range": 142.0, "arc": 0.55,
				"stamina": 0.0, "aether": 5.0, "combo_window": 0.22,
				"next": [
					{"input": "light_hold", "to": "broca"},
					{"input": "light", "to": "e4"},
					{"input": "heavy", "to": "varredura"},
				],
			},
			{
				"id": "e4", "name": "Perfurante Final",
				"windup": 0.14, "active": 0.08, "recovery": 0.26,
				"damage": 22.0, "stagger": 16.0, "part": 1.1,
				"range": 150.0, "arc": 0.5,
				"stamina": 0.0, "aether": 6.0, "combo_window": 0.20,
				"next": [{"input": "light", "to": "e1"}],
			},
			{
				## Broca: perfuração contínua no lugar; acumula Ferimento rápido.
				"id": "broca", "name": "Broca",
				"windup": 0.12, "active": 0.0, "recovery": 0.26,
				"damage": 6.0, "stagger": 2.0, "part": 0.6,
				"range": 140.0, "arc": 0.5,
				"channel": true, "channel_max": 3.0, "channel_stamina": 12.0,
				"pulse_every": 0.2,
				"stamina": 0.0, "aether": 1.5, "combo_window": 0.0,
				"next": [],
			},
			{
				"id": "estocada_disparada", "name": "Estocada Disparada",
				"windup": 0.10, "active": 0.08, "recovery": 0.22,
				"damage": 20.0, "stagger": 12.0, "part": 1.0,
				"range": 140.0, "arc": 0.6, "lunge": 120.0,
				"stamina": 0.0, "aether": 5.0, "combo_window": 0.26,
				"next": [{"input": "light", "to": "e2"}],
			},
			{
				"id": "estocada_rasante", "name": "Estocada Rasante",
				"windup": 0.10, "active": 0.08, "recovery": 0.20,
				"damage": 18.0, "stagger": 10.0, "part": 1.0,
				"range": 138.0, "arc": 0.6, "lunge": 60.0,
				"stamina": 0.0, "aether": 5.0, "combo_window": 0.26,
				"next": [{"input": "light", "to": "e2"}],
			},
		],
		"heavy": [
			{
				"id": "varredura", "name": "Varredura",
				"windup": 0.22, "active": 0.12, "recovery": 0.34,
				"damage": 30.0, "stagger": 26.0, "part": 1.1,
				"range": 128.0, "arc": 2.4,
				"stamina": 12.0, "aether": 8.0, "combo_window": 0.26,
				"next": [
					{"input": "heavy", "to": "estocada_profunda"},
					{"input": "light", "to": "e2"},
				],
			},
			{
				"id": "estocada_profunda", "name": "Estocada Profunda",
				"windup": 0.26, "active": 0.10, "recovery": 0.40,
				"damage": 44.0, "stagger": 34.0, "part": 1.3,
				"range": 160.0, "arc": 0.45,
				"stamina": 16.0, "aether": 10.0, "combo_window": 0.26,
				"animation": "heavy",
				"next": [{"input": "light", "to": "e2"}],
			},
			{
				"id": "varredura_saltada", "name": "Varredura Saltada",
				"windup": 0.16, "active": 0.10, "recovery": 0.28,
				"damage": 26.0, "stagger": 30.0, "part": 1.1,
				"range": 130.0, "arc": 2.0, "lunge": 80.0,
				"stamina": 12.0, "aether": 8.0, "combo_window": 0.26,
				"next": [{"input": "heavy", "to": "estocada_profunda"}],
			},
		],
	},
	REPEATERS: {
		"name": "Repetidoras",
		"blurb": "Pistolas gêmeas. Perto o dano é cheio; recarregar colado empodera.",
		"damage_type": DamageType.BALLISTIC,
		"special": {
			"type": "salvo",
			"name": "Salva Explosiva",
			"damage": 70.0,
			## Acima do limiar de boop mais alto em jogo (110, do Bastião): a
			## Salva é o interruptor à distância das Repetidoras, não um
			## estouro decorativo. Provisório, como todos os limiares.
			"stagger": 130.0,
			"radius": 120.0,
			"speed": 760.0,
			"range": 820.0,
			"empowered_count": 3,
			"empowered_spread": 0.25,
		},
		## SEM árvore de combo — e isso é fidelidade, não lacuna: o kit é tiro
		## contínuo + habilidades, sem sequências corpo-a-corpo. A máquina
		## precisa tolerar `nodes` vazio sem caso especial.
		"entry": {
			"free": [{"input": "heavy", "to": "@tumble"}],
			"sprint": [],
			"dodge": [],
		},
		## O "leve" é a definição do TIRO, não um nó de combo: a cadência vem
		## de fire_interval e o acerto é um projétil, não um setor.
		"light": [
			{
				"name": "Tiro Duplo",
				"shot": true,
				"fire_interval": 0.2,
				"projectile_speed": 1400.0,
				"projectile_radius": 6.0,
				"windup": 0.0, "active": 0.0, "recovery": 0.0,
				"damage": 14.0, "stagger": 8.0, "part": 0.9,
				"range": 900.0,
				"falloff_start": 360.0,
				"falloff_min": 0.4,
				"arc": 0.0,
				"stamina": 0.0, "aether": 3.0, "combo_window": 0.0,
			},
		],
		## O pesado é o Rolinho: dash lateral curto, i-frames parciais.
		"heavy": [
			{
				"name": "Rolinho",
				"tumble": true,
				"windup": 0.0, "active": 0.0, "recovery": 0.0,
				"damage": 0.0, "stagger": 0.0, "part": 0.0,
				"range": 0.0, "arc": 0.0,
				"stamina": 15.0, "aether": 0.0, "combo_window": 0.0,
			},
		],
	},
}

## Grafos compilados, por arma. Construir uma vez e reusar: a resolução de
## combo roda a cada Entrada, no Anfitrião e na predição do Cliente.
static var _graphs: Dictionary = {}


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


## Todos os Golpes de um tipo (leve ou pesado) de uma arma. A ordem é estável
## e os índices dos Golpes antigos NÃO mudaram: `attack_index` continua sendo
## o índice dentro do tipo, e a Apresentação continua escolhendo o clipe por
## (tipo, índice).
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
## Nós de canal não têm duração fixa: o tempo segurado entra por fora.
static func duration(data: Dictionary) -> float:
	return float(data["windup"]) + float(data["active"]) + float(data["recovery"])


## O Especial da arma (dados). Toda arma tem um.
static func special(weapon_id: String) -> Dictionary:
	return get_weapon(weapon_id).get("special", {})


## O grafo de combo ----------------------------------------------------------

## O grafo da arma: `{"entry": {contexto: [transições]}, "nodes": {id: nó}}`.
## Cada nó traz `kind`, `index` (onde o Golpe mora nas listas), `next`,
## `on_start` e `on_end`.
##
## Arma sem `entry` declarada ganha um grafo LINEAR compilado das listas
## light/heavy — o comportamento do sistema antigo de índices, aresta por
## aresta. É isso que deixa a migração ser incremental.
static func combo_graph(weapon_id: String) -> Dictionary:
	if _graphs.has(weapon_id):
		return _graphs[weapon_id]
	var graph := _build_graph(weapon_id)
	_graphs[weapon_id] = graph
	return graph


static func _build_graph(weapon_id: String) -> Dictionary:
	var weapon := get_weapon(weapon_id)
	var nodes: Dictionary = {}
	var declared: bool = weapon.has("entry")

	for kind in [Kind.LIGHT, Kind.HEAVY]:
		var list := moves(weapon_id, kind)
		for index in list.size():
			var data: Dictionary = list[index]
			var node_id: String = String(data.get("id", ""))
			if declared:
				if node_id.is_empty():
					continue  # Gancho, Rajada em carga, tiro, Rolinho.
			else:
				# Grafo compilado: todo Golpe vira nó, com id sintético.
				if data.get("hook", false):
					continue
				node_id = ("l%d" if kind == Kind.LIGHT else "h%d") % index
			nodes[node_id] = {
				"id": node_id,
				"kind": int(kind),
				"index": index,
				"next": data.get("next", []) if declared else _linear_next(weapon_id, kind, index),
				"on_start": data.get("on_start", []),
				"on_end": data.get("on_end", []),
			}

	var entry: Dictionary = weapon.get("entry", {})
	if not declared:
		entry = _linear_entry(weapon_id)
	return {"entry": entry, "nodes": nodes}


## A aresta linear do sistema antigo: o mesmo botão avança no mesmo tipo e
## volta ao primeiro Golpe no fim da lista. Golpe com janela zero não encadeia.
static func _linear_next(weapon_id: String, kind: Kind, index: int) -> Array:
	var list := moves(weapon_id, kind)
	var data: Dictionary = list[index]
	if float(data.get("combo_window", 0.0)) <= 0.0:
		return []
	var following := (index + 1) % list.size()
	var label := "l%d" if kind == Kind.LIGHT else "h%d"
	return [{"input": "light" if kind == Kind.LIGHT else "heavy", "to": label % following}]


static func _linear_entry(weapon_id: String) -> Dictionary:
	var free: Array = []
	if not moves(weapon_id, Kind.LIGHT).is_empty():
		free.append({"input": "light", "to": "l0"})
	var heavy_list := moves(weapon_id, Kind.HEAVY)
	if not heavy_list.is_empty() and not (heavy_list[0] as Dictionary).get("hook", false):
		free.append({"input": "heavy", "to": "h0"})
	return {"free": free, "sprint": [], "dodge": []}


## O nó de um id, ou vazio.
static func node(weapon_id: String, node_id: String) -> Dictionary:
	return combo_graph(weapon_id)["nodes"].get(node_id, {})


## O Golpe (números) de um nó.
static func node_move(weapon_id: String, node_id: String) -> Dictionary:
	var entry := node(weapon_id, node_id)
	if entry.is_empty():
		return {}
	return move(weapon_id, int(entry["kind"]) as Kind, int(entry["index"]))


## O id do nó que está em (tipo, índice), ou "" se aquele Golpe não é nó.
static func node_name(weapon_id: String, kind: Kind, index: int) -> String:
	for key in combo_graph(weapon_id)["nodes"]:
		var entry: Dictionary = combo_graph(weapon_id)["nodes"][key]
		if int(entry["kind"]) == int(kind) and int(entry["index"]) == index:
			return key
	return ""


## Identidade do nó num int só, para caber no Instantâneo (`combo_from`).
## Achatamento estável: primeiro os leves, depois os pesados.
static func flat_id(weapon_id: String, kind: Kind, index: int) -> int:
	if kind == Kind.LIGHT:
		return index
	return moves(weapon_id, Kind.LIGHT).size() + index


static func flat_of(weapon_id: String, node_id: String) -> int:
	var entry := node(weapon_id, node_id)
	if entry.is_empty():
		return -1
	return flat_id(weapon_id, int(entry["kind"]) as Kind, int(entry["index"]))


## O id do nó a partir do int achatado, ou "" quando não há nó ali.
static func node_from_flat(weapon_id: String, flat: int) -> String:
	if flat < 0:
		return ""
	var light_count := moves(weapon_id, Kind.LIGHT).size()
	if flat < light_count:
		return node_name(weapon_id, Kind.LIGHT, flat)
	return node_name(weapon_id, Kind.HEAVY, flat - light_count)
