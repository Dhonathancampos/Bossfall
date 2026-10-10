# Testes determinísticos — Machado, Lança e Repetidoras

Padrão: o mesmo de `tests/test_sim_weapons2.gd` e `test_sim_rework.gd` —
Sim com Gnasher estacionado (`_park`/`_run` segurando posição e cooldowns),
entradas via `HunterInput.make`, leitura por `snapshot()` e `take_events()`.
Um arquivo por arma: `test_sim_axe.gd`, `test_sim_pike.gd`,
`test_sim_repeaters.gd`.

Atenção aos helpers: `HunterInput.make` ganha `light_held` no FIM da
assinatura; os `_in(...)` locais de cada arquivo novo devem expor
`light`, `light_held`, `heavy`, `heavy_held`, `special`, `reload`.

## test_sim_axe.gd

- `test_pressing_light_enters_charge` — apertar o leve com o Machado entra
  em `AXE_CHARGE` (não em ATTACK) e nada acerta enquanto segura (hp do
  Behemoth intacto após 1 s segurando).
- `test_releasing_fires_the_strike` — soltar o botão dispara o golpe: estado
  vira ATTACK, e o evento "hit" com o nome do golpe aparece.
- `test_charge_scales_damage` — duas Sims: toque (soltar no 1º tique) vs
  carga cheia (segurar 1 s). O dano da carga cheia é > 1.5x o do toque e
  ≤ 1.6x + margem (a escala satura em AXE_CHARGE_MULT_MAX).
- `test_charge_saturates` — segurar 2 s não tira mais que segurar 1 s
  (mesmo dano com a escala saturada).
- `test_charging_drains_stamina_and_zero_forces_release` — vigor cai durante
  a carga (AXE_CHARGE_DRAIN); com vigor quase zero, a carga solta sozinha
  (estado sai de AXE_CHARGE sem soltar o botão).
- `test_tap_light_costs_no_stamina` — toque de leve custa 0 de vigor
  (decisão do MEMORY.md) e não adia a regeneração.
- `test_meter_fills_only_with_charged_hits` — acerto sem carga (toque) não
  gera Éter; acerto com carga ≥ AXE_CHARGE_METER_MIN gera (`aether` > 0).
- `test_combo_continues_between_charges` — leve carregado, soltar, carregar
  de novo dentro da janela: o segundo golpe é o índice 1 (combo avança
  através da carga).
- `test_special_throws_the_axe` — Éter cheio + F: `axe_out` vira true, o
  snapshot tem projectile com `kind == "ruin"`, e o Éter zera.
- `test_axe_out_blocks_attacks` — com `axe_out`, apertar leve/pesado não
  entra em AXE_CHARGE nem ATTACK; esquiva continua funcionando.
- `test_axe_returns_and_grants_determination` — machado arremessado através
  do Behemoth: acerta na ida (evento "hit" do Voo da Ruína), volta sozinha
  no fim do alcance, catch: `axe_out` false, `det_stacks == 1`, Éter
  devolvido em `catch_refund`.
- `test_recall_brings_it_back_early` — F de novo durante a ida inverte o
  projétil antes de `max_range` (posição do projétil volta a se aproximar
  do Caçador) e o catch acontece.
- `test_missed_throw_grants_no_stack` — arremesso para longe do Behemoth
  (sem acertar nada): catch sem pilha (`det_stacks == 0`).
- `test_determination_boosts_damage` — com 1 pilha (forjada via arremesso
  que conecta), o mesmo golpe carregado tira ~15% a mais que sem pilha.
- `test_determination_decays_progressively` — com 3 pilhas (helper que força
  `det_stacks`/`det_time` direto no estado, como `fill_aether` faz), após
  DETERMINATION_DURATIONS[2] segundos cai para 2; a janela seguinte usa a
  duração de 2 pilhas (maior). Asserta a escada completa 3→2→1→0.
- `test_axe_state_survives_the_snapshot` — to_dict → apply_dict num estado
  novo preserva charge_time, charge_locked, axe_out, det_stacks, det_time
  (teste de replicação, padrão do REVIEW).

## test_sim_pike.gd

- `test_pike_lights_cost_no_stamina` — combo leve completo com vigor zero
  funciona e regenera durante (padrão dos testes de vigor existentes).
- `test_pierce_builds_wound_on_the_part` — estocadas repetidas na mesma
  Parte (Caçador parado à frente: setor "front"): `part["wound"]` cresce; o
  dano à Vida continua acontecendo normalmente.
- `test_wound_threshold_wounds_the_part` — golpes até `wound >= 300`:
  `wounded == true`, `wound` zera, evento `part_wound` com o id da Parte.
- `test_only_pierce_wounds` — a Espada (SLASH) batendo na mesma Parte não
  move `wound` (continua 0.0).
- `test_wounded_part_boosts_all_weapons` — Parte Ferida: o MESMO golpe de
  Espada tira mais dano de Parte (hp da Parte cai `* 1.5`) e mais Vida
  (`* 1.25`) do que contra a Parte sã (duas Sims comparadas).
- `test_wound_expires` — 15 s depois de ferir, `wounded == false` e os
  multiplicadores somem.
- `test_wound_decays_below_threshold` — acúmulo parcial (ex.: 200) sem
  novos golpes decai 10/s até zero.
- `test_wound_survives_part_break` — quebrar a Parte Ferida (não decepável:
  usar a cabeça) não encerra `wounded` antes dos 15 s.
- `test_conversion_needs_ten_percent` — F com Éter < 10: nada acontece
  (`pike_ammo == 0`, Éter intacto).
- `test_conversion_levels` — quatro Sims com Éter forçado em 15/40/70/95:
  F converte para `pike_ammo` 1/2/3/4 e zera o Éter (os limiares
  10/33/66/90 da referência).
- `test_second_special_fires_the_missile` — com `pike_ammo > 0`, F dispara:
  snapshot tem projétil `kind == "pike_shot"`, `pike_ammo` zera, e o
  Behemoth a 400 de distância leva o dano escalado pelo nível.
- `test_missile_scales_with_ammo_level` — míssil nível 4 tira mais que o
  dobro do nível 1 (35+30L: 65 vs 155) e empurra o medidor de Atordoamento
  (stagger 120 vs 300).
- `test_pike_state_survives_the_snapshot` — to_dict → apply_dict preserva
  `pike_ammo`; `parts` do Behemoth no snapshot carregam
  wound/wounded/wound_time.

## test_sim_repeaters.gd

- `test_holding_fire_consumes_the_mag_at_cadence` — segurar `light_held`
  por 1 s: ~5 tiros saem (snapshot: `mag == 12 - 5 ± 1`), projéteis
  `kind == "bullet"` existem no Instantâneo.
- `test_firing_does_not_lock_movement` — atirar andando: a posição muda
  enquanto o pente desce (estado continua FREE).
- `test_empty_mag_stops_firing` — com `mag == 0`, segurar o botão não cria
  projétil nenhum e o Behemoth não leva dano.
- `test_bullets_hit_and_grant_aether` — tiros no Behemoth parado: eventos
  "hit" com `move == "Tiro Duplo"`, Éter do Caçador sobe.
- `test_damage_falls_with_distance` — Behemoth a 200 (dentro do
  falloff_start) vs a 800: o dano por tiro de longe é menor; a 800 fica
  próximo de 40–60% do dano de perto (degrau linear entre 360 e 900).
- `test_full_damage_up_close` — a 200 e a 350 o dano por tiro é o mesmo
  (sem queda antes de falloff_start).
- `test_reload_refills_after_the_time` — R com pente parcial: estado
  RELOADING por 1.2 s, depois `mag == 12`; sem Behemoth por perto,
  `empowered_shots == 0`.
- `test_reload_next_to_the_behemoth_empowers` — recarregar com a borda do
  corpo a ≤ 160: `empowered_shots == 12` e evento "empowered"; cada tiro
  consome 1 e tira 25% a mais que o tiro normal (comparar dano dos eventos).
- `test_empowerment_does_not_stack_nor_persist` — regra: a recarga
  SOBRESCREVE `empowered_shots` (12 perto, 0 longe). O teste empodera,
  gasta 3 tiros, recarrega longe e asserta `empowered_shots == 0`; depois
  recarrega perto duas vezes seguidas e asserta que continua 12 (não 24).
- `test_tumble_dashes_sideways` — pesado: estado TUMBLE, deslocamento
  perpendicular à mira (y muda, x quase não), duração ~0.18 s + recuperação,
  custo 15 de vigor.
- `test_tumble_iframes_are_partial` — ataque do Behemoth no 1º tique do
  Rolinho não acerta (invulnerável); no tique após TUMBLE_IFRAMES_END
  (0.08–0.18 s) acerta (diferente da esquiva, que cobre 0.16 de 0.22).
- `test_salvo_explodes_in_area` — Éter cheio + F: projétil `kind ==
  "salvo"`, evento "explosion" no impacto, Behemoth leva ~70 de dano.
- `test_empowered_salvo_fires_three` — com `empowered_shots > 0`, F cria 3
  projéteis no snapshot (leque) e NÃO consome `empowered_shots`.
- `test_ballistic_has_no_type_bonus` — tiro na cauda decepável não ganha o
  bônus SLASH (dano igual contra parte decepável e dura, descontada a
  diferença de setor).
- `test_repeater_state_survives_the_snapshot` — to_dict → apply_dict
  preserva mag, empowered_shots, fire_cooldown; `_next_input` com a fila
  seca preserva `light_held` (o tiro não engasga com pacote atrasado).

## Regressões obrigatórias (nos arquivos existentes)

- Suíte inteira verde após CADA arma (136 testes atuais + novos).
- `test_sim_rework.gd` intacto: a recarga do Martelo não pode mudar com o
  ramo por arma no `_step_reloading`.
- Teste de enum: novo teste simples assertando os ints congelados dos
  estados antigos (`FREE==0 … RELOADING==8`) para o aviso do REVIEW virar
  verificação (`test_state_enum_is_append_only`).
