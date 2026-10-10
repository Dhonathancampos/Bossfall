# Repetidoras — pacote pronto para integrar (ticket 13)

Identidade: a primeira arma de alcance. Tiro contínuo mirado (segurar o
leve), pente de 12, recarga que EMPODERA quando feita colada ao Behemoth
(fiel à referência — a janela de timing do ticket foi descartada, ver
PESQUISA.md §3), dano caindo com a distância. Pesado = rolinho lateral curto
(escolha nossa; evidência inconclusiva). **Números provisórios**; coerência:
DPS contínuo de perto ≈ combo leve da Espada (~70/s), caindo a ~28/s no
alcance máximo.

## 1. Tipo de dano novo

`Weapons.DamageType` ganha um valor NO FIM do enum:

```gdscript
## Balístico: físico neutro, sem bônus de decepar nem de Parte dura.
BALLISTIC,
```

E `SimConfig.STAGGER_TYPE_MULT` ganha a entrada:

```gdscript
Weapons.DamageType.BALLISTIC: 0.4,   # [NOSSO] abaixo do Corte (0.6)
```

(Enum no FIM pela mesma razão do State: os ints viajam em dados.)

## 2. Entrada em `Weapons._DATA`

```gdscript
const REPEATERS: String = "repeaters"
```

```gdscript
REPEATERS: {
    "name": "Repetidoras",
    "blurb": "Pistolas gêmeas. Perto o dano é cheio; recarregar colado empodera.",
    "damage_type": DamageType.BALLISTIC,
    "special": {
        "type": "salvo",            # Salvo Chamber clássico.
        "name": "Salva Explosiva",
        "damage": 70.0,
        "stagger": 100.0,
        "radius": 120.0,            # área da explosão
        "speed": 760.0,
        "range": 820.0,
        "empowered_count": 3,       # empoderada: 3 mísseis em leque [EV]
        "empowered_spread": 0.25,   # desvio angular dos laterais (rad)
    },
    ## O "leve" é a definição do TIRO, não um golpe de combo: a cadência vem
    ## de fire_interval e o acerto é um projétil, não um setor.
    "light": [
        {
            "name": "Tiro Duplo",
            "shot": true,
            "fire_interval": 0.2,          # 5 tiros/s (ticket)
            "projectile_speed": 1400.0,
            "projectile_radius": 6.0,
            "windup": 0.0, "active": 0.0, "recovery": 0.0,
            "damage": 14.0, "stagger": 8.0, "part": 0.9,
            "range": 900.0,                 # alcance máximo do projétil
            "falloff_start": 360.0,         # dano cheio até aqui (ticket)
            "falloff_min": 0.4,             # fração no alcance máximo (ticket)
            "arc": 0.0, "advance": 0.0,
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
            "range": 0.0, "arc": 0.0, "advance": 0.0,
            "stamina": 15.0, "aether": 0.0, "combo_window": 0.0,
        },
    ],
},
```

### Campos novos no formato

- `shot: true` — o "golpe" é um disparo contínuo: não entra em ATTACK; o
  HunterStep emite pedidos de projétil na cadência de `fire_interval`
  enquanto o botão está seguro e o pente tem tiro.
- `fire_interval`, `projectile_speed`, `projectile_radius` — cadência e
  balística.
- `falloff_start` / `falloff_min` — queda por distância, resolvida no
  impacto pela distância percorrida do projétil.
- `tumble: true` — o pesado é o Rolinho (estado novo, §3), não um golpe.

## 3. Constantes novas em `SimConfig`

```gdscript
## Repetidoras: pente e recarga. Empodera recarregando com a BORDA do corpo
## do Behemoth a até esta distância (fiel à referência; sem janela de timing).
const REPEATER_MAG: int = 12                       # [EV]
const REPEATER_RELOAD_TIME: float = 1.2            # [NOSSO/ticket]
const REPEATER_EMPOWER_RANGE: float = 160.0        # [NOSSO]
const REPEATER_EMPOWER_MULT: float = 1.25          # [NOSSO/ticket]
## Rolinho: dash lateral curto com i-frames parciais.
const TUMBLE_SPEED: float = 520.0                  # [NOSSO]
const TUMBLE_DURATION: float = 0.18                # [NOSSO]
const TUMBLE_IFRAMES_END: float = 0.08             # [NOSSO] (esquiva: 0.16)
const TUMBLE_RECOVERY: float = 0.10                # [NOSSO]
```

## 4. Estados e campos novos (HunterState / HunterStep)

### Enum `State` — acrescentar NO FIM (depois de AXE_CHARGE do Machado):

```gdscript
## Rolinho das Repetidoras: dash curto com Invulnerabilidade parcial.
TUMBLE,
```

### Campos novos em `HunterState` (replicados):

- `mag: int = SimConfig.REPEATER_MAG` — tiros no pente.
- `empowered_shots: int = 0` — tiros empoderados restantes (12 após recarga
  colada; cada disparo consome 1).
- `fire_cooldown: float = 0.0` — tempo até o próximo tiro poder sair.
  Precisa replicar: a predição do dono dispara na mesma cadência que o host.

Flag de um Tique (não replicada):

- `wants_shot: bool = false` — o passo decidiu que um tiro sai neste Tique;
  a Sim (host) cria o projétil. O Cliente prevê pente/cadência, nunca dano.

### Máquina de estados (HunterStep)

- **Tiro contínuo** (dentro de `_step_free`, antes do bloco de sprint):
  com arma de `shot` e (`input.light` ou `input.light_held` — campo novo de
  entrada, compartilhado com a carga do Machado):
  ```gdscript
  hunter.fire_cooldown = maxf(0.0, hunter.fire_cooldown - dt)  # no step geral
  if hunter.fire_cooldown <= 0.0 and hunter.mag > 0:
      hunter.mag -= 1
      hunter.fire_cooldown = float(move["fire_interval"])
      hunter.wants_shot = true
  ```
  Atirar não trava o movimento (anda atirando; sprint interrompe o tiro —
  `sprint` tem prioridade **[NOSSO]**). Pente vazio: nada sai (a Apresentação
  toca o "click" via evento opcional `"dry_fire"` — não obrigatório na v1).
- **Recarga:** `input.reload` com `mag < REPEATER_MAG` entra em RELOADING
  (estado REUSADO). `_step_reloading` ganha ramo por arma:
  - Repetidoras: sem janela de timing, sem falha; aos
    `REPEATER_RELOAD_TIME` segundos: `mag = REPEATER_MAG`; se
    `world.has_behemoth` e a distância da borda
    (`(behemoth_pos - pos).length() - behemoth_radius`) for
    `<= REPEATER_EMPOWER_RANGE`, então `empowered_shots = REPEATER_MAG` e
    evento `{"type": "empowered", "hunter": id}`. Volta a FREE.
  - OBS: `_step_reloading` precisa receber `world` (hoje não recebe) — a
    assinatura muda para `_step_reloading(hunter, input, world)`. A predição
    do Cliente passa `world` vazio: o dono prevê a recarga, e o EMPODERAMENTO
    só se confirma no Instantâneo (degradação segura, mesmo padrão do Gancho).
  - Martelo: comportamento atual intocado.
- **Rolinho** (`_begin_heavy` com `tumble`): paga `stamina`, trava
  `dodge_dir` PERPENDICULAR à mira (`Vector2.RIGHT.rotated(facing ± PI/2)`,
  lado escolhido pela componente lateral de `input.move`; sem input lateral,
  direita), entra em `TUMBLE`. `_step_tumble` = cópia do `_step_dodge` com as
  constantes TUMBLE_* (i-frames só até TUMBLE_IFRAMES_END).
- **Especial** (`_begin_special`, tipo `"salvo"`): regra padrão de Éter
  cheio; seta `wants_projectile = true` (reusa a flag do Magma; o spawn
  decide o formato pelo tipo do special).

## 5. O que muda em `Sim` e `Combat`

### Projétil "bullet" (tiro básico)

`Sim.step` consome `wants_shot` → `_spawn_bullet(hunter, move)`:

```gdscript
{"kind": "bullet", "pos": hunter.pos, "dir": RIGHT.rotated(hunter.facing),
 "speed": move["projectile_speed"], "traveled": 0.0,
 "max_range": move["range"], "radius": move["projectile_radius"],
 "damage": move["damage"] * (REPEATER_EMPOWER_MULT se empoderado senão 1.0),
 "stagger": move["stagger"], "part_mult": move["part"],
 "falloff_start": move["falloff_start"], "falloff_min": move["falloff_min"],
 "element": int(hunter.element), "aether": move["aether"],
 "owner": hunter.id}
```

Se `empowered_shots > 0`, consumir 1 no spawn (host). O Cliente não prevê o
bônus (dano é do host); o contador replicado alimenta o HUD.

Em `_step_projectiles`, `bullet` no impacto aplica a queda por distância e
segue o caminho completo de `_hit_behemoth` (Parte/Tipo/Oposição/Ferida):

```gdscript
var travel := float(p["traveled"])
var fade := 1.0
if travel > float(p["falloff_start"]):
    var span := float(p["max_range"]) - float(p["falloff_start"])
    fade = lerpf(1.0, float(p["falloff_min"]),
        clampf((travel - float(p["falloff_start"])) / span, 0.0, 1.0))
```

Montar um pseudo-move `{name: "Tiro Duplo", damage: p.damage * fade,
stagger: p.stagger, part: p.part_mult, aether: p.aether}` e chamar
`_hit_behemoth(owner_state, pseudo_move)` — assim o tiro respeita Parte,
Oposição, armadura do Bastião e Ferimento (BALLISTIC não acumula Ferimento:
só PIERCE acumula). O ganho de Éter vem pelo caminho normal do
`_hit_behemoth`. Também acertar `_targets` (boneco de treino) com o dano
já com queda.

### Projétil "salvo" (Especial)

Spawn pelo `wants_projectile` quando o special é `"salvo"`: igual ao Magma
(explode em área no impacto ou no fim do alcance), com os números do
special. Se `empowered_shots > 0` no momento do disparo: nascem
`empowered_count` mísseis com desvios `-spread, 0, +spread` (e o
empoderamento NÃO é consumido pelo especial — só os tiros consomem;
**[NOSSO]**). A explosão reusa `_explode_projectile` (dano cru de área).

### Combat

Sem mudança de assinatura. A queda por distância mora no projétil (Sim);
`damage_against` continua puro.

## 6. Fora do escopo desta entrega (registrar no ticket 14)

- Full-Bore e Marksman Chambers, mods (Scoped Sights etc.), grips.
- Mira vertical/altura (a Sim é 2D no plano; "mirar" é o `aim` atual).
- "Click" de pente vazio e marcador de tiro empoderado no HUD — papel
  Apresentação/HUD.
- Decidir com teste de uso se o Rolinho mantém i-frames parciais ou nenhum
  (o ticket deixava em aberto; v1 = parciais).
