# Integração — Machado, Lança e Repetidoras

Pacote escrito SEM tocar em `src/` (outro agente estava reconstruindo o
contrato de combate e o Gnasher). O Gerente aplica quando a Sim estiver
livre. Se o contrato de combate mudar as assinaturas citadas aqui
(`_hit_behemoth`, partes, projéteis), adaptar os pontos de costura — as
REGRAS das armas não dependem do formato exato.

Conciliação com o contrato de combate que entrou em 09/10 (ver MEMORY.md):

- O enum NOVO `INTERRUPTED` é do **Behemoth**, não do Caçador — a ordem do
  `HunterState.State` deste pacote segue válida (AXE_CHARGE e TUMBLE no fim).
- As Partes ganharam `zone` nos dados; o Ferimento deste pacote acrescenta
  `wound/wounded/wound_time` nas MESMAS entradas — campos ortogonais.
- O boop por limiar já existe: o míssil da Lança (`pike_shot`) e a Salva das
  Repetidoras devem passar pelo mesmo caminho de interrupção que a Rajada e
  o Magma antes de alimentar o medidor (ver pike.md §5/§Fora do escopo).
- Os snapshots de leitura dos testes novos devem considerar os eventos
  padronizados (`behemoth_phase`, `interrupt`) ao filtrar `take_events()`.

## Ordem de aplicação

1. **Machado** (ticket 11) — introduz a infraestrutura comum:
   - campo de entrada `light_held` (usado também pelas Repetidoras);
   - estado `AXE_CHARGE` no FIM do enum;
   - generalização do `buff_multiplier` (Valor × Determinação);
   - projétil com `kind` novo e retorno ("ruin").
2. **Lança** (ticket 12) — depende de nada do Machado, mas aplicar depois
   para os estados/enum não trocarem de ordem entre as levas:
   - Ferimento nas Partes (campos novos em `BehemothState.spawn`);
   - reestruturação do `_begin_special` (o requisito de Éter cheio vira
     por-tipo — o Machado também passa por ali, por isso a ordem);
   - remove `PIERCE_WOUND_MULT` (substituída por `PIERCE_WOUND_RATE`).
3. **Repetidoras** (ticket 13) — depende das duas anteriores:
   - usa `light_held` (do Machado);
   - `DamageType.BALLISTIC` no FIM do enum;
   - estado `TUMBLE` no FIM do enum (DEPOIS de `AXE_CHARGE`);
   - ramo por arma no `_step_reloading` (que passa a receber `world`).

Rodar a suíte inteira após CADA arma, não só no fim.

## AVISO — enums só crescem pelo FIM

O REVIEW.md registra que estados novos entraram no MEIO do enum `State` na
leva passada (ints replicados mudaram). **Não repetir.** Ordem final:

```
FREE, DODGE, ATTACK, CHARGING, HOOK_PULL, SPECIAL_SPIN, HURT, DOWNED,
RELOADING, AXE_CHARGE, TUMBLE
```

O mesmo vale para `Weapons.DamageType`: `SLASH, BLUNT, PIERCE, BALLISTIC`
(BALLISTIC por último) — e para `SimConfig.STAGGER_TYPE_MULT`, que precisa
da chave nova junto.

## Replicação — o checklist que o REVIEW.md manda não esquecer

### HunterState.to_dict  (+ apply_dict, simétrico, SEMPRE)

Campos novos, por arma:

| Campo             | Arma        | to_dict | to_view_dict | apply_dict |
|-------------------|-------------|---------|--------------|------------|
| `charge_time`     | Machado     | sim     | não (1)      | sim        |
| `charge_locked`   | Machado     | sim     | não          | sim        |
| `charge_kind`     | Machado     | sim     | não (2)      | sim        |
| `axe_out`         | Machado     | sim     | **SIM** (3)  | sim        |
| `det_stacks`      | Machado     | sim     | **SIM** (4)  | sim        |
| `det_time`        | Machado     | sim     | não          | sim        |
| `pike_ammo`       | Lança       | sim     | não (5)      | sim        |
| `mag`             | Repetidoras | sim     | não (5)      | sim        |
| `empowered_shots` | Repetidoras | sim     | não (5)      | sim        |
| `fire_cooldown`   | Repetidoras | sim     | não (6)      | sim        |

1. O remoto desenha a pose de carga por `state == AXE_CHARGE` + `state_time`.
2. O remoto pode derivar a animação por `attack_kind`, que já viaja.
3. Sem `axe_out` o remoto desenha o Caçador com o machado na mão ENQUANTO o
   projétil-machado também aparece — duplicado visível.
4. Aura/feedback de Determinação nos remotos; é 1 int, cabe no MTU.
5. Só o dono precisa (HUD) — e o dono recebe o dict completo.
6. Predição do dono: sem replicar, a reconciliação faria o tiro "pular".

Flags de um Tique ficam FORA do snapshot (padrão existente):
`wants_axe_throw`, `wants_axe_recall`, `wants_pike_shot`, `wants_shot`.

### HunterInput — campo novo `light_held`

- `HunterInput`: var nova `light_held: bool` (contínua, como `heavy_held`).
- `make(...)`: parâmetro novo NO FIM da assinatura (não reordenar os
  existentes — os testes atuais chamam por posição).
- `to_dict` / `from_dict`: chave `"lheld"` (curta, o input viaja todo tique).
- `Sim._next_input`: ao repetir a última entrada com a fila seca,
  **preservar `light_held`** (como `heavy_held`) — senão o tiro contínuo das
  Repetidoras e a carga leve do Machado caem a cada pacote atrasado.
- Apresentação (papel de integração): capturar o botão segurado e preencher
  o campo (fora do nosso escopo de arquivo, registrar no ticket).

### BehemothState — Ferimento

`spawn` adiciona `wound/wounded/wound_time` a cada Parte. A serialização já
é `parts.duplicate(true)` em `to_dict` — **replica de graça**, nada a fazer
no snapshot. O decaimento roda só no host; o cliente recebe o estado pronto.

### Snapshot de projéteis

`Sim.snapshot` hoje envia `{pos, radius}` por projétil. Acrescentar
`"kind"` (string) para a Apresentação distinguir machado girando / míssil
da Lança / bala / salva / magma / onda. Campo pequeno; sem ele todos os
projéteis viram a mesma bolinha.

## Pontos de costura por arquivo (resumo)

- `weapons.gd`: consts `AXE/PIKE/REPEATERS` + 3 entradas de `_DATA`
  (copiar de axe.md / pike.md / repeaters.md).
- `sim_config.gd`: blocos de constantes de axe.md §2, pike.md §2,
  repeaters.md §3; chave BALLISTIC em `STAGGER_TYPE_MULT`; REMOVER
  `PIERCE_WOUND_MULT`.
- `hunter_state.gd`: enum (fim!), campos novos, to_dict/to_view_dict/
  apply_dict conforme a tabela.
- `hunter_input.gd`: `light_held` (+ make/to_dict/from_dict).
- `hunter_step.gd`: ramos `AXE_CHARGE` e `TUMBLE` no match; carga do
  Machado; tiro contínuo no `_step_free`; `_step_reloading(hunter, input,
  world)` com ramo por arma; `_begin_special` reestruturado por tipo;
  `buff_multiplier` composto; decaimento da Determinação no `step`.
- `sim.gd`: consumo das flags novas; `_spawn_axe/_spawn_pike_shot/
  _spawn_bullet/_spawn_salvo`; ramos novos em `_step_projectiles`
  (ruin/pike_shot/bullet/salvo); escala de carga e regras de Ferimento em
  `_hit_behemoth`; helper `_aether_gain`; `kind` no snapshot;
  `_next_input` preservando `light_held`.
- `behemoth_state.gd`: campos de Ferimento no `spawn`.
- `combat.gd`: SEM mudanças (decisão deliberada: Ferida e queda por
  distância aplicam na Sim, onde o número exibido é calculado — mesmo
  padrão do ARMOR_LEAK).

## Predição — o que o Cliente prevê e o que degrada

- Prevê: carga do Machado (estado/tempo), cadência e pente das Repetidoras,
  Rolinho, recarga (sem o empoderamento), conversão da Lança (pike_ammo).
- NÃO prevê (host-only, padrão atual): dano, Ferimento, pilhas de
  Determinação (chegam no Instantâneo — o `det_stacks` replicado corrige em
  1–2 quadros), empoderamento do pente, projéteis (inclusive o machado:
  `axe_out` chega pelo Instantâneo; entre o F e o Instantâneo o dono pode
  ver 1–2 quadros de machado na mão — mesma degradação aceita do Gancho).

## Pendências para outros papéis (registrar ao aplicar)

- Modelos: `weapon_axe.py`, `weapon_pike.py`, `weapon_repeaters.py`;
  animações de carga do Machado, arremesso/catch, estocadas, tiro e Rolinho
  (AXE_CHARGE e TUMBLE caem no fallback de idle até lá, como
  SPECIAL_SPIN/RELOADING hoje).
- HUD: medidor+pilhas (Machado), medidor com marcas 10/33/66/90 + munição
  (Lança), pente + marcador de empoderado (Repetidoras), indicador de
  Ferida nas barras de Parte.
- Áudio: tiro, recarga, empoderamento, arremesso/catch, ferida aberta.
