# 03 — Brejara

## Nome, arquétipo e fantasia

**Brejara** — controladora de área. Um sapo-serpente anfíbio do tamanho de uma
casa, de papada inchada e olhos de lamparina; ela não persegue ninguém —
envenena o chão até a arena inteira ser dela.

## A mecânica nova: Perigo persistente no chão

Os ataques da Brejara deixam **Poças** — zonas circulares que FICAM na arena
por 12 segundos, causando dano por segundo e acúmulo de Aflição em quem pisa.
A arena encolhe de verdade ao longo da luta: cada esquiva precisa considerar
não só o golpe, mas **onde se vai parar**.

É a mecânica que transforma posicionamento de hábito em recurso gasto — e a
primeira em que a Esquiva com Invulnerabilidade NÃO resolve (a poça não é um
golpe, é um lugar).

## Partes

| Parte | Setor | HP | Decepável | Dura | Quebra muda o quê |
|---|---|---|---|---|---|
| Cabeça | front | 500 | não | sim | Padrão (dano aumentado) |
| Sacos de Veneno | side | 560 | sim | não | **As Poças passam a durar metade do tempo** — a quebra desarma a mecânica, não só os números |
| Cauda | back | 420 | sim | não | Remove a Varredura de Cauda |

## Ataques

```gdscript
"attacks": [
    {
        "id": "spit",
        "name": "Cuspe Triplo",
        "windup": 0.72, "active": 0.18, "recovery": 0.70,
        "cooldown": 5.5,
        "min_range": 180.0, "max_range": 560.0,
        "shape": {"type": SHAPE_CONE, "range": 540.0, "arc": 0.9, "offset": 0.0},
        "damage": 15.0, "knockback": 180.0,
        "turn_rate": 1.1, "advance": 0.0, "weight": 3.0,
        ## Deixa 3 Poças (raio 110) espalhadas dentro do cone.
        "spawns_pools": 3,
    },
    {
        "id": "hop",
        "name": "Salto Esmagador",
        "windup": 0.85, "active": 0.25, "recovery": 0.80,
        "cooldown": 7.0,
        "min_range": 220.0, "max_range": 620.0,
        "shape": {"type": SHAPE_CIRCLE, "range": 250.0},
        "damage": 24.0, "knockback": 400.0,
        "turn_rate": 0.5,
        ## O salto reposiciona: Telegrafia no ponto de queda (como o mergulho
        ## do voador), e uma Poça nasce onde ela aterrissa.
        "advance": 0.0, "weight": 2.0,
        "spawns_pools": 1,
    },
    {
        "id": "tongue",
        "name": "Chicote de Língua",
        "windup": 0.58, "active": 0.14, "recovery": 0.60,
        "cooldown": 2.2,
        "min_range": 0.0, "max_range": 300.0,
        "shape": {"type": SHAPE_DASH, "width": 90.0, "range": 300.0},
        "damage": 17.0, "knockback": 260.0,
        "turn_rate": 1.4, "advance": 0.0, "weight": 3.0,
    },
    {
        "id": "tail",
        "name": "Varredura de Cauda",
        "windup": 0.52, "active": 0.20, "recovery": 0.68,
        "cooldown": 4.5,
        "min_range": 0.0, "max_range": 250.0,
        "shape": {"type": SHAPE_CONE, "range": 245.0, "arc": 2.4, "offset": PI},
        "damage": 19.0, "knockback": 320.0,
        "turn_rate": 0.7, "advance": 0.0, "weight": 2.0,
        "requires_part": "tail",
    },
]
```

Base: `hp 2500`, `radius 112`, `move_speed 105` (a mais lenta — ela não
precisa andar, o chão luta por ela), `turn_speed 1.8`, `preferred_gap 220`
(gosta de distância!), `stagger_threshold 400`, `enrage_at 0.45`.

Poça: raio 110, duração 12s (6s com os Sacos quebrados), 5 de dano/s + 30 de
acúmulo de Aflição/s do Elemento dela.

## Elemento e variantes

Natural: **Umbral** (poças de Dreno: pisou, o Fôlego para de voltar — cruel e
legível). Variantes: **Incêndio** (poças que queimam) e **Gélido** (poças que
congelam — a variante mais difícil do jogo até aqui).

## Custo de motor

Médio. Uma lista `_hazards` na Sim ({pos, radius, ttl, element, dps}),
criada quando um ataque com `spawns_pools` resolve; a cada Tique, Caçador
dentro de poça toma dano/acúmulo (ignorando Invulnerabilidade de rolamento —
decisão de design, é chão, não golpe). Entra no Instantâneo (lista pequena) e
a Apresentação desenha com o mesmo GroundShapes dos decalques. O Salto
reposicionar o monstro pede um caminho novo pequeno no `_step_active`
(teleporte ao ponto da Telegrafia no fim do Preparo). É a infraestrutura que
o voador (mergulho) e o Fornalho (lava) reaproveitam depois.

## Visual (cartunesco low-poly)

Sapo imenso de pele lisa roxo-acinzentada (`6b5a78`), papada enorme e
translúcida que pulsa (esfera achatada emissiva `b48cff`), dois Sacos de
Veneno como bolhas salientes nos flancos — balões low-poly que murcham
visivelmente quando quebrados. Olhos amarelos de pupila fendida no alto da
cabeça. Cauda de girino, achatada como remo. As Poças são discos borbulhantes
da cor do Elemento com borda mais clara — a leitura do chão acima de tudo.
