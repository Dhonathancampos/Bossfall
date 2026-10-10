# Machado — pacote pronto para integrar (ticket 11)

Identidade: a arma mais lenta e mais forte. Corte, arcos largos, alcance
médio. Carga por golpe (segurar o botão segura o Preparo e escala o dano) e
pilhas de Determinação ganhas pelo Especial. **Todos os números são
provisórios** (ver PESQUISA.md); a coerência usada: leves acima do Martelo
(30/34/48) em dano e abaixo em cadência; pesados acima do pesado da Espada
(46/48/64).

## 1. Entrada em `Weapons._DATA`

Novo id ao lado dos existentes:

```gdscript
const AXE: String = "axe"
```

Entrada completa (campos novos explicados abaixo):

```gdscript
AXE: {
    "name": "Machado",
    "blurb": "Lento e devastador. Segure o golpe para carregar; solte para arrasar.",
    "damage_type": DamageType.SLASH,
    "special": {
        "type": "ruin",            # Voo da Ruína: projétil de ida e volta.
        "name": "Voo da Ruína",
        "damage": 55.0,            # por passagem (ida e volta acertam 1x cada)
        "stagger": 90.0,
        "part": 1.2,
        "speed": 640.0,
        "range": 520.0,            # distância máxima antes de voltar sozinho
        "radius": 26.0,            # raio do projétil-machado
        "catch_refund": 25.0,      # Éter devolvido ao pegar de volta [NOSSO]
    },
    ## Horizontais largos, todos carregáveis. Vigor zero nos toques (decisão
    ## do MEMORY.md); a CARGA tem dreno próprio (AXE_CHARGE_DRAIN).
    "light": [
        {
            "name": "Talho Amplo",
            "chargeable": true,
            "windup": 0.26, "active": 0.10, "recovery": 0.40,
            "damage": 36.0, "stagger": 40.0, "part": 1.1,
            "range": 110.0, "arc": 2.2, "advance": 0.0,
            "stamina": 0.0, "aether": 8.0, "combo_window": 0.30,
        },
        {
            "name": "Talho de Retorno",
            "chargeable": true,
            "windup": 0.24, "active": 0.10, "recovery": 0.42,
            "damage": 40.0, "stagger": 44.0, "part": 1.1,
            "range": 110.0, "arc": 2.2, "advance": 0.0,
            "stamina": 0.0, "aether": 8.0, "combo_window": 0.30,
            "animation": "light_2",
        },
        {
            "name": "Ceifa Total",
            "chargeable": true,
            "windup": 0.34, "active": 0.14, "recovery": 0.60,
            "damage": 56.0, "stagger": 80.0, "part": 1.2,
            "range": 124.0, "arc": TAU, "advance": 0.0,
            "stamina": 0.0, "aether": 12.0, "combo_window": 0.26,
        },
    ],
    ## Verticais estreitos e brutais, também carregáveis. Pagam vigor.
    "heavy": [
        {
            "name": "Racha-Crânio",
            "chargeable": true,
            "windup": 0.36, "active": 0.12, "recovery": 0.50,
            "damage": 58.0, "stagger": 70.0, "part": 1.4,
            "range": 116.0, "arc": 1.1, "advance": 0.0,
            "stamina": 18.0, "aether": 12.0, "combo_window": 0.30,
            "animation": "heavy",
        },
        {
            "name": "Queda da Ruína",
            "chargeable": true,
            "windup": 0.46, "active": 0.14, "recovery": 0.62,
            "damage": 78.0, "stagger": 110.0, "part": 1.5,
            "range": 120.0, "arc": 1.1, "advance": 0.0,
            "stamina": 22.0, "aether": 16.0, "combo_window": 0.30,
            "animation": "heavy",
        },
    ],
},
```

### Campos novos no formato

- `chargeable: bool` — o Golpe pode ser segurado no Preparo. Quando presente
  e verdadeiro, apertar o botão entra em `AXE_CHARGE` em vez de ir direto a
  `ATTACK`. Golpes sem o campo se comportam como hoje (default `false`).
- `special.type == "ruin"` — novo tipo de Especial, resolvido pela Sim como
  projétil de ida e volta (ver §4).
- `special.catch_refund` — Éter devolvido quando o machado é apanhado de
  volta.

## 2. Constantes novas em `SimConfig`

```gdscript
## Machado: carga por golpe. Multiplicador cresce linear até o teto em 1 s.
const AXE_CHARGE_TIME_MAX: float = 1.0      # [NOSSO] (ticket: ~1s)
const AXE_CHARGE_MULT_MAX: float = 1.6      # [NOSSO] (ticket: até ~1.6x)
## Carga parcial mínima para o acerto contar como "carregado" (gera Éter).
const AXE_CHARGE_METER_MIN: float = 0.35    # [NOSSO]
## Segurar a carga drena vigor. Toques continuam gratuitos nos leves.
const AXE_CHARGE_DRAIN_PER_SECOND: float = 10.0  # [NOSSO]
## Determinação: pilhas e decaimento progressivo (mais pilhas = decai antes).
const DETERMINATION_MAX_STACKS: int = 3
const DETERMINATION_DAMAGE_PER_STACK: float = 0.15   # [NOSSO/ticket]
## Duração da pilha corrente por quantidade de pilhas: 1->12s, 2->9s, 3->6s.
const DETERMINATION_DURATIONS: Array[float] = [12.0, 9.0, 6.0]  # [NOSSO]
```

## 3. Estados e campos novos (HunterState / HunterStep)

### Enum `State` — acrescentar NO FIM (depois de RELOADING):

```gdscript
## Segurando um Golpe do Machado no Preparo. Mira livre, corpo preso.
AXE_CHARGE,
```

### Campos novos em `HunterState` (todos replicados — ver INTEGRACAO.md):

- `charge_time: float = 0.0` — tempo de carga acumulado no `AXE_CHARGE`.
  Entra quando o estado começa; sai (vira `charge_locked`) ao soltar.
- `charge_locked: float = 0.0` — a carga travada do ATTACK em andamento
  (0 = golpe não carregado). Zera em `_finish_attack`, junto com
  `blast_ammo`/`slam_pips`.
- `charge_kind: int = int(Weapons.Kind.LIGHT)` — qual botão está carregando
  (decide qual `*_held` sustenta a carga e qual golpe sai ao soltar).
- `axe_out: bool = false` — o machado foi arremessado e ainda não voltou.
  Enquanto verdadeiro, leves/pesados/carga são recusados (sem arma na mão);
  esquiva e movimento seguem livres. Replicado também no view-dict (o remoto
  precisa esconder o machado da mão).
- `det_stacks: int = 0` — pilhas de Determinação.
- `det_time: float = 0.0` — tempo restante da pilha corrente; ao zerar,
  perde 1 pilha e recomeça com a duração da nova contagem
  (`DETERMINATION_DURATIONS[det_stacks - 1]`).
- Flags de um Tique (NÃO replicadas, padrão `wants_projectile`):
  - `wants_axe_throw: bool` — o F pediu o arremesso (Sim cria o projétil).
  - `wants_axe_recall: bool` — F de novo com o machado fora (Sim inverte o
    projétil).

### Máquina de estados (HunterStep)

- `_begin_attack`/`_begin_heavy`: com `weapon_id == AXE` e golpe
  `chargeable`, em vez de entrar em ATTACK: valida vigor do golpe (pesados),
  guarda `charge_kind`, `attack_kind/attack_index` (o índice de combo é
  decidido AQUI, com a mesma regra de `combo_grace` atual), zera
  `charge_time` e entra em `AXE_CHARGE`. Se `axe_out`, recusa (retorna
  falso e o movimento segue).
- `_step_axe_charge(hunter, input, dt)`:
  - `hunter.facing = input.aim` (mira livre, corpo preso, como CHARGING).
  - `charge_time += dt` até `AXE_CHARGE_TIME_MAX` (satura, não transborda).
  - Drena `AXE_CHARGE_DRAIN_PER_SECOND * dt` via `_spend` enquanto segura
    (acima do mínimo de toque; é o custo do golpe canalizado permitido pelo
    MEMORY.md). Vigor zerado força a soltura.
  - Botão correspondente (`light_held` p/ LIGHT — campo NOVO de entrada,
    ver INTEGRACAO.md — ou `heavy_held` p/ HEAVY) solto → trava
    `charge_locked = charge_time`, paga o `stamina` do golpe (pesados) e
    entra em ATTACK com o golpe já escolhido (`_begin_attack` com
    `forced_index`).
- `step()` ganha o ramo `AXE_CHARGE` no `match` e o decaimento da
  Determinação (junto de `valor_time`):
  ```gdscript
  if hunter.det_time > 0.0:
      hunter.det_time -= dt
      if hunter.det_time <= 0.0:
          hunter.det_stacks = maxi(0, hunter.det_stacks - 1)
          hunter.det_time = 0.0 if hunter.det_stacks == 0 \
              else SimConfig.DETERMINATION_DURATIONS[hunter.det_stacks - 1]
  ```
- `_begin_special` ganha o tipo `"ruin"`: exige Éter cheio (regra padrão),
  e exige `not axe_out`; seta `wants_axe_throw = true` (o projétil nasce na
  Sim). NÃO entra em estado novo: o arremesso usa um ATTACK curto? Não —
  mais simples: o Caçador fica FREE e a animação de arremesso é dirigida
  pelo evento `special` já existente. Pressionar F com `axe_out` seta
  `wants_axe_recall` (consumido pela Sim).
- `buff_multiplier()` passa a compor Valor e Determinação:
  ```gdscript
  static func buff_multiplier(hunter: HunterState) -> float:
      var mult := 1.0
      if hunter.valor_time > 0.0:
          mult *= float(Weapons.special(hunter.weapon_id).get("damage_mult", 1.0))
      mult *= 1.0 + SimConfig.DETERMINATION_DAMAGE_PER_STACK * hunter.det_stacks
      return mult
  ```

## 4. O que muda em `Sim` e `Combat`

### Escala da carga (Sim._hit_behemoth, mesmo padrão de blast/chain)

```gdscript
elif move.get("chargeable", false) and hunter.charge_locked > 0.0:
    move_eff = move.duplicate()
    var t := clampf(hunter.charge_locked / SimConfig.AXE_CHARGE_TIME_MAX, 0.0, 1.0)
    var mult := lerpf(1.0, SimConfig.AXE_CHARGE_MULT_MAX, t)
    move_eff["damage"] = float(move["damage"]) * mult
    move_eff["stagger"] = float(move["stagger"]) * mult
```

### Éter só com golpe carregado (regra do ticket)

No Machado, o ganho de Éter do acerto (`move["aether"]`) só é concedido se
`charge_locked >= AXE_CHARGE_METER_MIN` (e escala com a mesma `mult` da
carga). Nas demais armas nada muda. Implementar como um helper na Sim
(`_aether_gain(hunter, move)`) usado em `_resolve_attack`/`_hit_behemoth`,
para a regra morar num lugar só.

### Projétil "ruin" (Voo da Ruína)

Novo kind na lista `_projectiles`:

```gdscript
{"kind": "ruin", "pos", "dir", "speed", "traveled", "max_range",
 "radius", "damage", "stagger", "part", "owner",
 "returning": false, "hit_out": [], "hit_back": [], "connected": false}
```

Regras em `_step_projectiles`:

- Ida: avança como os demais. Acerta o Behemoth no máximo 1x na ida
  (`hit_out`), via `_hit_behemoth` com um pseudo-move (padrão `_resolve_spin`)
  usando damage/stagger/part do special. Marca `connected = true`.
- Vira quando `traveled >= max_range` OU quando o dono pediu recall
  (`wants_axe_recall` consumido pela Sim → `returning = true`).
- Volta: persegue a POSIÇÃO ATUAL do dono (`dir` recalculada por tique),
  acerta no máximo 1x na volta (`hit_back`).
- Chegou ao dono (distância ≤ HUNTER_RADIUS + radius):
  - `axe_out = false`;
  - devolve `catch_refund` de Éter;
  - se `connected`, concede pilha: `det_stacks = mini(det_stacks + 1, MAX)`
    e `det_time = DETERMINATION_DURATIONS[det_stacks - 1]`;
  - evento `{"type": "axe_catch", "hunter": id, "stacks": det_stacks}`.
- Dono abatido (DOWNED): o machado volta direto e não acerta na volta.

Snapshot: o projétil já viaja em `payload["projectiles"]` ({pos, radius});
acrescentar `"kind"` à versão enxuta para a Apresentação desenhar o machado
girando em vez de uma bola de magma (ver INTEGRACAO.md).

### Simplificação assumida

O golpe de recall da referência (slam ao apanhar) está dissolvido no acerto
da volta + pilha no catch. Um slam de verdade no catch (ATTACK forçado) fica
para a fase de fidelidade (ticket 14). **[NOSSO]**

## 5. Fora do escopo desta entrega (registrar no ticket 14)

- **Resolve** (super armor ao soltar vertical no nível 3): exige flag de
  "não entra em HURT" em `take_hit`. Especificação sugerida:
  `resolve_time: float` no estado; `take_hit` aplica dano mas não troca de
  estado nem aplica knockback enquanto `resolve_time > 0`.
- Grim Onslaught (especial alternativo), mods, combo vertical "Ripper"
  sustentado por vigor.
- Andar durante carga horizontal (a referência permite; v1 prende o corpo
  como o CHARGING do Martelo para reusar a regra testada). **[NOSSO]**
