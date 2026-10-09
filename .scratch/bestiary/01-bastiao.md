# 01 — Bastião

> **Status: IMPLEMENTADO** (papel Mecânica). `bastion` em behemoths.gd,
> armadura com ARMOR_LEAK = 0.15 (sempre vaza, regra do usuário), penalidade
> do Rolamento na quebra da Carapaça, selecionável no menu. Modelo 3D pendente
> (papel Modelos).

## Nome, arquétipo e fantasia

**Bastião** — tanque blindado. Um colosso quadrúpede entre tatu e pangolim,
coberto de placas de pedra viva que rangem quando ele anda; caçá-lo é menos
uma luta e mais uma demolição.

## A mecânica nova: Armadura antes da Vida

As Partes blindadas do Bastião têm uma **camada de Armadura**: enquanto a
placa daquele setor está inteira, acertos ali causam só **15% do dano** à Vida
dele (a Parte recebe dano normal). Quebrar a placa expõe a carne — o setor
passa a receber dano cheio, mais o bônus de Parte quebrada que já existe.

É o inverso do Gnasher: a luta começa lenta e termina explosiva, e **escolher
onde bater deixa de ser otimização e vira pré-requisito**. O Martelo (bom
contra Partes duras) vira a chave que abre o monstro para as outras armas.

## Partes

| Parte | Setor | HP | Decepável | Dura | Quebra muda o quê |
|---|---|---|---|---|---|
| Crista | front | 480 | não | sim | Expõe a cabeça (dano cheio na frente) e causa o Atordoamento de quebra |
| Carapaça | side | 700 | não | sim | Expõe os flancos; o Rolamento ganha +1s de recarga (ele hesita sem o escudo) |
| Cauda-maça | back | 420 | sim | não | Remove o golpe de maça; é o único setor SEM armadura — a rota dos espadachins |

## Ataques

```gdscript
"attacks": [
    {
        "id": "headbutt",
        "name": "Cabeçada",
        "windup": 0.66, "active": 0.16, "recovery": 0.70,
        "cooldown": 2.2,
        "min_range": 0.0, "max_range": 220.0,
        "shape": {"type": SHAPE_CONE, "range": 220.0, "arc": 1.0, "offset": 0.0},
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
    },
    {
        "id": "mace",
        "name": "Maçada",
        "windup": 0.60, "active": 0.20, "recovery": 0.75,
        "cooldown": 5.0,
        "min_range": 0.0, "max_range": 255.0,
        "shape": {"type": SHAPE_CONE, "range": 250.0, "arc": 2.2, "offset": PI},
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
        "shape": {"type": SHAPE_CIRCLE, "range": 260.0},
        "damage": 24.0, "knockback": 380.0,
        "turn_rate": 0.80,
        "advance": 0.0,
        "weight": 1.5,
        "element": Elements.Element.TERRA,
    },
]
```

Base: `hp 3000` (mais que o Gnasher — a armadura já encurta a luta efetiva,
então a Vida bruta não pode ser baixa), `radius 115`, `move_speed 120`
(lento), `turn_speed 1.9`, `preferred_gap 50`, `stagger_threshold 500`,
`enrage_at 0.40`, `enrage_speed 1.2`, `enrage_damage 1.3`,
`enrage_cooldown 0.7`.

O Tremor com Elemento Terra é a assinatura cruel: quem toma leva acúmulo de
**Enraizamento** — e ficar preso ao lado de um tanque é onde os revives
acontecem.

## Elemento e variantes

Natural: **Terra**. Variantes: **Gélido** (placas de geleira — Congelamento
transforma a luta em claustrofobia) e **Incêndio** (basalto rachado com magma
nas frestas).

## Custo de motor

Pequeno. Um campo `"armored": true` por Parte nos dados; em
`sim._hit_behemoth`, se a Parte atingida está blindada e não quebrada, o dano
à Vida é multiplicado por `ARMOR_DAMAGE_FRACTION` (0.15) — o dano à Parte e o
Atordoamento seguem cheios. O +1s de recarga do Rolamento na quebra da
Carapaça é um `if` no evento de quebra. Nada de entidade nova, nada de rede
nova: o Instantâneo já carrega as Partes.

## Visual (cartunesco low-poly)

Corpo de tatu gigante: domo de placas hexagonais grandes e chanfradas
(cada placa um prisma de 6-8 faces, tons de cinza-ardósia com musgo
`a8c97f` nas frestas), cabeça baixa com crista frontal em cunha, patas
grossas como pilares, cauda terminando numa maça poliédrica. As placas
quebradas REVELAM carne laranja-clara (`e0a85a`) brilhante — o jogador vê de
longe qual setor já está aberto. Na Fúria, as frestas acendem.
