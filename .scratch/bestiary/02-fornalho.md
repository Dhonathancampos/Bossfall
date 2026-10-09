# 02 — Fornalho

## Nome, arquétipo e fantasia

**Fornalho** — colosso de fase dupla. Um gorila-golem de magma com a crosta
resfriada por fora: a primeira metade da caçada é contra uma estátua lenta e
pesada, até a crosta estourar e sobrar só o incêndio que morava dentro.

## A mecânica nova: Troca de Fase

Aos **50% de Vida**, o Fornalho troca de fase, uma única vez e para sempre:

1. Um estouro imediato (círculo grande, dano alto) pune quem estava colado.
2. A crosta some do corpo (visual) e as **estatísticas trocam**: velocidade
   +40%, recargas −35%, dano +20%.
3. O **repertório de ataques troca**: os golpes de fase 1 saem, os de fase 2
   entram.

Diferente da Fúria (que é um buff), a fase dois é **outro monstro** — o
jogador precisa reaprender a luta no meio dela. É a mecânica que faz uma
caçada de 2 minutos parecer duas.

## Partes

| Parte | Setor | HP | Decepável | Dura | Quebra muda o quê |
|---|---|---|---|---|---|
| Crosta Peitoral | front | 520 | não | sim | Só existe na fase 1; quebrá-la antes dos 50% ADIANTA a troca de fase (estratégia: controlar QUANDO ele vira) |
| Braços | side | 640 | não | não | Fase 2 perde a Varredura Dupla |
| Núcleo Caudal | back | 400 | não | não | Recebe +25% de dano permanente (o ponto fraco clássico, atrás) |

## Ataques — Fase 1 (lento e pesado)

```gdscript
{
    "id": "slam",
    "name": "Pancada Dupla",
    "windup": 0.70, "active": 0.18, "recovery": 0.75,
    "cooldown": 2.4,
    "min_range": 0.0, "max_range": 230.0,
    "shape": {"type": SHAPE_CONE, "range": 230.0, "arc": 1.3, "offset": 0.0},
    "damage": 20.0, "knockback": 320.0,
    "turn_rate": 1.2, "advance": 0.0, "weight": 3.0,
    "phase": 1,
},
{
    "id": "pound",
    "name": "Soco no Chão",
    "windup": 0.80, "active": 0.20, "recovery": 0.85,
    "cooldown": 6.5,
    "min_range": 0.0, "max_range": 200.0,
    "shape": {"type": SHAPE_CIRCLE, "range": 240.0},
    "damage": 23.0, "knockback": 360.0,
    "turn_rate": 0.8, "advance": 0.0, "weight": 2.0,
    "phase": 1, "element": Elements.Element.BLAZE,
},
{
    "id": "lumber",
    "name": "Arremetida",
    "windup": 0.95, "active": 0.40, "recovery": 0.95,
    "cooldown": 7.5,
    "min_range": 240.0, "max_range": 620.0,
    "shape": {"type": SHAPE_DASH, "width": 140.0, "range": 460.0},
    "damage": 25.0, "knockback": 400.0,
    "turn_rate": 0.45, "advance": 1000.0, "weight": 2.0,
    "phase": 1,
},
```

## Ataques — Fase 2 (rápido e incendiário)

```gdscript
{
    "id": "eruption",
    "name": "Erupção",
    "windup": 0.75, "active": 0.22, "recovery": 0.70,
    "cooldown": 6.0,
    "min_range": 0.0, "max_range": 240.0,
    "shape": {"type": SHAPE_CIRCLE, "range": 300.0},
    "damage": 26.0, "knockback": 400.0,
    "turn_rate": 0.9, "advance": 0.0, "weight": 2.0,
    "phase": 2, "element": Elements.Element.BLAZE,
},
{
    "id": "blazing_rush",
    "name": "Avanço Flamejante",
    "windup": 0.62, "active": 0.34, "recovery": 0.70,
    "cooldown": 5.0,
    "min_range": 200.0, "max_range": 640.0,
    "shape": {"type": SHAPE_DASH, "width": 120.0, "range": 440.0},
    "damage": 22.0, "knockback": 340.0,
    "turn_rate": 0.6, "advance": 1250.0, "weight": 2.5,
    "phase": 2, "element": Elements.Element.BLAZE,
},
{
    "id": "double_sweep",
    "name": "Varredura Dupla",
    "windup": 0.55, "active": 0.24, "recovery": 0.60,
    "cooldown": 3.0,
    "min_range": 0.0, "max_range": 235.0,
    "shape": {"type": SHAPE_CONE, "range": 235.0, "arc": 2.0, "offset": 0.0},
    "damage": 19.0, "knockback": 300.0,
    "turn_rate": 1.4, "advance": 0.0, "weight": 3.0,
    "phase": 2, "requires_part": "arms",
},
```

Base: `hp 2800`, `radius 110`, fase 1 `move_speed 115` / fase 2 `160`,
`turn_speed 2.0`, `preferred_gap 55`, `stagger_threshold 460`,
`enrage_at 0.25` (a Fúria vira o "soft enrage" do fim da fase 2).

## Elemento e variantes

Natural: **Incêndio**. Variantes: **Umbral** (magma negro, Dreno — a fase 2
que não deixa você correr) e **Choque** (núcleo de tempestade).

## Custo de motor

Pequeno-médio. Um campo `"phase"` nos ataques e um `phase` no BehemothState;
`_choose_attack` filtra pelo campo (mesma mecânica do `requires_part`). A
transição é um check em `step`: `hp <= 50%` e `phase == 1` → dispara o
estouro (reutiliza o caminho de ataque com um id reservado), troca `phase`,
aplica multiplicadores de stats (campos novos nos dados, lidos como os de
`enrage_*`). Um evento `"phase_change"` para a Apresentação trocar o visual.
Sem entidade nova, sem rede nova.

## Visual (cartunesco low-poly)

Fase 1: gorila troncudo de pedra cinza-carvão, placas angulares, juntas com
brilho laranja fraco (`ff8a5c`), postura curvada de nocaute. Fase 2: as
placas saltam fora (ficam no chão como entulho de cena), o corpo inteiro vira
magma vivo — malha laranja-vermelha emissiva com veios amarelos, olhos
brancos, e ele corre com os punhos. A silhueta encolhe 10%: mais magro, mais
rápido, mais assustador.
