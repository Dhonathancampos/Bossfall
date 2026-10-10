# Lança de Guerra — pacote pronto para integrar (ticket 12)

Identidade: estocadas perfurantes muito rápidas e lineares (arco estreito,
alcance alto), a arma que FERE Partes e converte o medidor em munição de
canhão. Primeira usuária do `DamageType.PIERCE` reservado desde a Onda 1.
**Números provisórios**; coerência: cadência próxima das Lâminas
(11/11/14/20), com dano por golpe um pouco maior e stagger menor
(PIERCE × 0.5 em `STAGGER_TYPE_MULT` já existe).

## 1. Entrada em `Weapons._DATA`

```gdscript
const PIKE: String = "pike"
```

```gdscript
PIKE: {
    "name": "Lança de Guerra",
    "blurb": "Estocadas perfurantes que Ferem. O medidor vira munição de canhão.",
    "damage_type": DamageType.PIERCE,
    "special": {
        "type": "conversion",        # Conversão Aetérica (Concussive Payload).
        "name": "Conversão Aetérica",
        ## Qualidade da munição por fração do Éter ao converter (fonte 1.6.0).
        "ammo_thresholds": [10.0, 33.0, 66.0, 90.0],
        ## Míssil: potência proporcional ao nível da munição (1..4).
        "damage_base": 35.0, "damage_per_level": 30.0,
        "stagger_base": 60.0, "stagger_per_level": 60.0,
        "speed": 820.0, "range": 900.0, "radius": 16.0,
    },
    ## Estocadas: arco estreito, alcance alto, vigor zero (MEMORY.md).
    "light": [
        {
            "name": "Estocada",
            "windup": 0.10, "active": 0.06, "recovery": 0.16,
            "damage": 14.0, "stagger": 10.0, "part": 1.0,
            "range": 136.0, "arc": 0.55, "advance": 0.0,
            "stamina": 0.0, "aether": 4.0, "combo_window": 0.22,
        },
        {
            "name": "Estocada Dupla",
            "windup": 0.09, "active": 0.06, "recovery": 0.16,
            "damage": 14.0, "stagger": 10.0, "part": 1.0,
            "range": 136.0, "arc": 0.55, "advance": 0.0,
            "stamina": 0.0, "aether": 4.0, "combo_window": 0.22,
            "animation": "light_2",
        },
        {
            "name": "Estocada Alta",
            "windup": 0.10, "active": 0.07, "recovery": 0.18,
            "damage": 16.0, "stagger": 12.0, "part": 1.05,
            "range": 142.0, "arc": 0.55, "advance": 0.0,
            "stamina": 0.0, "aether": 5.0, "combo_window": 0.22,
        },
        {
            "name": "Perfurante Final",
            "windup": 0.14, "active": 0.08, "recovery": 0.26,
            "damage": 22.0, "stagger": 16.0, "part": 1.1,
            "range": 150.0, "arc": 0.5, "advance": 0.0,
            "stamina": 0.0, "aether": 6.0, "combo_window": 0.20,
        },
    ],
    ## Pesado: varredura ampla, depois estocada profunda.
    "heavy": [
        {
            "name": "Varredura",
            "windup": 0.22, "active": 0.12, "recovery": 0.34,
            "damage": 30.0, "stagger": 26.0, "part": 1.1,
            "range": 128.0, "arc": 2.4, "advance": 0.0,
            "stamina": 12.0, "aether": 8.0, "combo_window": 0.26,
        },
        {
            "name": "Estocada Profunda",
            "windup": 0.26, "active": 0.10, "recovery": 0.40,
            "damage": 44.0, "stagger": 34.0, "part": 1.3,
            "range": 160.0, "arc": 0.45, "advance": 0.0,
            "stamina": 16.0, "aether": 10.0, "combo_window": 0.26,
            "animation": "heavy",
        },
    ],
},
```

### Campos novos no formato

- `special.type == "conversion"` — Especial em dois tempos (converter,
  depois disparar), SEM exigir Éter cheio (ver §3).
- `ammo_thresholds` — frações do medidor (sobre `AETHER_MAX`) que definem a
  qualidade 1/2/3/4 da munição convertida (fonte: patch 1.6.0).

## 2. FERIMENTO — o medidor novo por Parte (regra completa)

Mora nas Partes do Behemoth (`BehemothState.parts`), não no Caçador.
Campos novos em cada entrada de `parts` (criados em `BehemothState.spawn`,
replicam de graça via `parts.duplicate(true)` no `to_dict`):

```gdscript
"wound": 0.0,        # acúmulo de Ferimento
"wounded": false,    # a Parte está Ferida agora
"wound_time": 0.0,   # tempo restante do estado Ferida
```

Constantes novas em `SimConfig`:

```gdscript
## Ferimento: só dano de Perfuração acumula. 133% do dano causado vira
## Ferimento (fonte comunitária); limiar e decaimento são nossos.
const PIERCE_WOUND_RATE: float = 1.33          # [EV]
const WOUND_THRESHOLD: float = 300.0           # [NOSSO] provisório
const WOUND_DECAY_PER_SECOND: float = 10.0     # [NOSSO] provisório
const WOUND_DURATION: float = 15.0             # [EV: 1.6.0]
## Efeito da Parte Ferida (modelo do ticket; diverge da 1.6.0 — ver
## PESQUISA.md §2). Vale para TODAS as armas enquanto durar.
const WOUNDED_PART_DAMAGE_MULT: float = 1.5    # [NOSSO] dano de Parte
const WOUNDED_BODY_DAMAGE_MULT: float = 1.25   # [NOSSO] dano à Vida
```

Regras (host-only, em `Sim._hit_behemoth` + um passo por tique):

1. **Acúmulo:** quando um golpe de arma `DamageType.PIERCE` acerta uma Parte
   não-Ferida: `part["wound"] += dealt * PIERCE_WOUND_RATE` (onde `dealt` é
   o dano calculado ANTES do vazamento de armadura — a perfuração fere a
   carne por baixo da placa; **[NOSSO]**, coerente com a placa apanhar cheio).
2. **Limiar:** `wound >= WOUND_THRESHOLD` → `wounded = true`,
   `wound_time = WOUND_DURATION`, `wound = 0.0`, evento
   `{"type": "part_wound", "pos": behemoth.pos, "part": part["name"],
   "part_id": part["id"], "hunter": id}`. A Apresentação mostra o brilho
   azul de éter vazando (papel Modelos/VFX; registrar pendência).
3. **Efeito:** enquanto `wounded`, TODO golpe (qualquer arma) naquela Parte:
   - dano de Parte: `part["hp"] -= dealt * move["part"] * WOUNDED_PART_DAMAGE_MULT`;
   - dano à Vida: multiplicado por `WOUNDED_BODY_DAMAGE_MULT` (aplicado em
     `Combat.damage_against`? Não — manter `damage_against` puro: aplicar na
     Sim, junto do leak de armadura, para o número exibido ser o real).
   - Partes Feridas também podem ser atingidas quebradas (a quebra não
     encerra a Ferida — fonte 1.6.0); a exceção de Parte decepada
     (`broken and severable`) continua valendo: decepada não existe mais.
4. **Decaimento/fim:** por tique (no passo do Behemoth ou num
   `_step_wounds(dt)` da Sim): se `wounded`, `wound_time -= dt`; zera →
   `wounded = false`. Se não-Ferida, `wound = max(0, wound - WOUND_DECAY_PER_SECOND*dt)`.
5. Enquanto `wounded == true`, novos acúmulos de Ferimento são ignorados
   (não há fila de feridas na mesma Parte).

### Modelo alternativo (fiel à 1.6.0, se o Gerente preferir)

Sem bônus de dano: quem acumular 1000 de dano numa Parte Ferida ganha buff
pessoal de 15 s (+15% dano — versão reduzida, sem velocidade de ataque).
Exigiria `wound_buff_time` no HunterState (replicado) e contadores por
ferida. Mais fiel, mais estado; o modelo principal acima preserva a
identidade de suporte do ticket ("a Lança fere, o grupo colhe").

## 3. Estados e campos novos (HunterState / HunterStep)

**Nenhum estado novo no enum.** A conversão é instantânea e o disparo é um
projétil.

Campos novos em `HunterState` (replicados):

- `pike_ammo: int = 0` — nível da munição convertida (0..4).

Flag de um Tique (não replicada):

- `wants_pike_shot: bool = false` — pediu o disparo do míssil.

`_begin_special` ganha o ramo `"conversion"`, que NÃO usa a regra de Éter
cheio:

```gdscript
"conversion":
    if hunter.pike_ammo > 0:
        hunter.wants_pike_shot = true      # segundo F: dispara
        hunter.special_fired = true
        return true
    var thresholds: Array = special["ammo_thresholds"]
    if hunter.aether < float(thresholds[0]):
        return false                       # menos de 10%: nada acontece
    var level := 0
    for limit in thresholds:
        if hunter.aether >= float(limit):
            level += 1
    hunter.pike_ammo = level
    hunter.aether = 0.0                    # converte TUDO (fonte 1.6.0)
    hunter.special_fired = true
    return true
```

Atenção: `_begin_special` hoje começa com `if hunter.aether < AETHER_MAX:
return false` e `hunter.aether = 0.0` incondicional — o ramo da Lança precisa
desviar ANTES dessas duas linhas (reestruturar a função: o requisito de Éter
cheio passa a ser dos tipos valor/magma/reaper/ruin/salvo).

## 4. O que muda em `Sim` e `Combat`

- `Sim.step`: consumir `wants_pike_shot` → `_spawn_pike_shot(hunter)`:
  projétil `{"kind": "pike_shot", damage/stagger escalados por pike_ammo,
  "owner", ...}`; `pike_ammo = 0` ao disparar.
  - `damage = damage_base + damage_per_level * level`
  - `stagger = stagger_base + stagger_per_level * level` (nível 4 = 300 de
    stagger bruto: é o míssil que derruba/boopa; a interrupção de verdade
    chega com o contrato de combate).
- `_step_projectiles`: `pike_shot` viaja como a Câmara de Magma e acerta
  DIRETO (sem explosão em área): no impacto usa o caminho do `_wave_hit`
  (dano + stagger + threat + evento "hit" com `move: "Conversão Aetérica"`),
  sem Parte e sem Tipo. Expira no fim do alcance sem estourar. **[NOSSO]**
- `Sim._hit_behemoth`: aplicar as regras de Ferimento do §2 (acúmulo quando
  `damage_type == PIERCE`; multiplicadores quando a Parte está `wounded`).
- `Combat` não muda de assinatura: `part_hit` já devolve a Parte com os
  campos novos dentro; os multiplicadores de Ferida aplicam na Sim para o
  número exibido ser o que entrou na Vida (mesma filosofia do ARMOR_LEAK).
- `SimConfig.PIERCE_WOUND_MULT` (constante reservada, hoje 1.0 e sem uso)
  é SUBSTITUÍDA por `PIERCE_WOUND_RATE` — remover a antiga para não deixar
  duas constantes contando a mesma história.

## 5. Fora do escopo desta entrega (registrar no ticket 14)

- Pike Charge (investida/lunge com estocada, dano 250 na referência) e o
  dodge próprio da 1.6.0.
- Boop/interrupção pelo míssil: o contrato de combate de 09/10 JÁ entrega a
  interrupção por limiar de Atordoamento (Rajada e Magma passam pelo boop).
  Ao aplicar este pacote, o impacto do `pike_shot` deve passar pelo MESMO
  caminho de boop antes de alimentar o medidor — com nível 4 (300 de
  stagger bruto), o míssil é o boop clássico da Lança. Não é mais fase 2:
  é um ponto de costura da integração.
- Buff pessoal de 4 atributos ao explorar a ferida (modelo 1.6.0 completo).
- HUD do medidor com marcas de limiar (10/33/66/90) e indicador de Ferida
  nas barras de Parte — papel Apresentação/HUD.
