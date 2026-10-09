# 04 — Vespreia

## Nome, arquétipo e fantasia

**Vespreia** — enxameadora ágil. Uma rainha-vespa esguia de quatro asas e
pernas de louva-a-deus, que nunca para quieta e nunca luta sozinha: o enxame é
o corpo dela estendido pela arena.

## A mecânica nova: Invocação de crias

A Vespreia convoca **Zangões** — crias pequenas (2 por chamado, teto de 4
vivas) que perseguem e picam os Caçadores. Fracos (60 de Vida, morrem em 2-3
golpes), mas mudam a aritmética do grupo: alguém precisa limpar o enxame
enquanto os outros seguram a rainha.

O gancho de design que fecha o ciclo: **cada Zangão morto enche 15% do
Atordoamento dela** — limpar o enxame não é tempo perdido, é o caminho para
derrubá-la. A luta respira em ondas: chamado → enxame → limpeza → queda →
janela de dano.

## Partes

| Parte | Setor | HP | Decepável | Dura | Quebra muda o quê |
|---|---|---|---|---|---|
| Cabeça | front | 460 | não | sim | Padrão (dano aumentado) |
| Asas | side | 520 | sim | não | O Rasante some e a velocidade cai 30% — ela vira presa |
| Ovipositor | back | 440 | sim | não | **Cada chamado convoca 1 Zangão em vez de 2** — desarma o enxame |

## Ataques

```gdscript
"attacks": [
    {
        "id": "sting",
        "name": "Ferroada",
        "windup": 0.48, "active": 0.12, "recovery": 0.55,
        "cooldown": 1.8,
        "min_range": 0.0, "max_range": 200.0,
        "shape": {"type": SHAPE_CONE, "range": 200.0, "arc": 0.9, "offset": 0.0},
        "damage": 15.0, "knockback": 240.0,
        "turn_rate": 1.8, "advance": 0.0, "weight": 3.0,
    },
    {
        "id": "skim",
        "name": "Rasante",
        "windup": 0.60, "active": 0.30, "recovery": 0.55,
        "cooldown": 4.0,
        "min_range": 200.0, "max_range": 600.0,
        "shape": {"type": SHAPE_DASH, "width": 110.0, "range": 420.0},
        "damage": 20.0, "knockback": 300.0,
        "turn_rate": 0.7, "advance": 1300.0, "weight": 2.5,
        "requires_part": "wings",
    },
    {
        "id": "summon",
        "name": "Chamado do Enxame",
        "windup": 1.10, "active": 0.10, "recovery": 0.80,
        "cooldown": 14.0,
        "min_range": 0.0, "max_range": 900.0,
        ## Sem dano: o círculo é só o aviso de "interrompam ela AGORA".
        "shape": {"type": SHAPE_CIRCLE, "range": 140.0},
        "damage": 0.0, "knockback": 0.0,
        "turn_rate": 0.3, "advance": 0.0, "weight": 2.0,
        "summons": 2,
    },
    {
        "id": "dazzle",
        "name": "Pó Cintilante",
        "windup": 0.70, "active": 0.20, "recovery": 0.75,
        "cooldown": 8.0,
        "min_range": 0.0, "max_range": 190.0,
        "shape": {"type": SHAPE_CIRCLE, "range": 230.0},
        "damage": 14.0, "knockback": 200.0,
        "turn_rate": 0.9, "advance": 0.0, "weight": 1.5,
        "element": Elements.Element.RADIANT,
    },
]
```

Base: `hp 2300` (a mais frágil — o enxame é a Vida extra dela), `radius 95`,
`move_speed 190` (a mais rápida), `turn_speed 3.0`, `preferred_gap 140`,
`stagger_threshold 380`, `enrage_at 0.45` (na Fúria, o teto de Zangões sobe
para 6).

Zangão: 60 de Vida, raio 34, velocidade 240, uma picada fraca (8 de dano,
cone curto, recarga 2s). Não tem Partes nem medidores — é população, não
monstro.

## Elemento e variantes

Natural: **Radiante** (o Pó Cintilante cega — e lutar cego dentro de um
enxame é o pesadelo assinatura dela). Variantes: **Choque** (Zangões que
estalam) e **Terra**.

## Custo de motor

O maior dos quatro. Uma lista `_minions` na Sim com uma IA mínima própria
(perseguir alvo por Ameaça simplificada, uma picada em recarga — um
sub-conjunto do BehemothStep, sem Partes/Fúria/Atordoamento); os Golpes dos
Caçadores precisam resolver contra os Zangões (o laço de `_resolve_attack` já
itera `_targets`, dá para os Zangões viverem ali com IA em cima); morte de
Zangão alimenta `add_stagger` da rainha; tudo entra no Instantâneo e a
Apresentação desenha N corpos pequenos. É o behemoth que mais paga
infraestrutura — e a infraestrutura vira as "crias" de qualquer monstro
futuro e os inimigos menores das masmorras da Onda 4.

## Visual (cartunesco low-poly)

Corpo de vespa alongado em três contas (tórax, cintura fina, abdômen
listrado âmbar/preto — `ffe066` e `1a1a1a`), quatro asas de vitral
translúcidas (planos com material emissivo fraco), pernas dianteiras de
louva-a-deus dobradas como foices, ovipositor curvo e proeminente atrás.
Cabeça pequena com dois olhos compostos enormes (icoesferas facetadas
`ffe9b0`). Zangões: a mesma silhueta encolhida a 1/4, sem o ovipositor, com
UMA asa de cada lado — de longe, a rainha e as vírgulas dela.
