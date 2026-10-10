# Migração — do índice de combo ao grafo (ticket 14)

Como sair de `combo_next`/`combo_grace` + listas light/heavy para o grafo do
MODELO.md sem quebrar a suite (136 testes) de uma vez. **Atenção**: src/sim/
está sendo reconstruído por outro agente em paralelo — TODOS os pontos de
código citados aqui devem ser re-verificados contra o estado pós-reconstrução
antes de qualquer edição. Esta é a maior ameaça do plano.

## Fase 0 — adaptador (nenhum comportamento muda)

1. `Weapons` ganha `combo_graph(weapon_id)`: se a arma declara `combo`, usa;
   senão **compila** as listas `light`/`heavy` atuais num grafo linear
   equivalente (l0→l1→..., h0→h1→..., entry free light→l0/heavy→h0, janela =
   `combo_window` de cada golpe). A ordem achatada é `light + heavy`, então
   os ids dos nós coincidem com os `attack_index` atuais por tipo (light k →
   id k; heavy k → id len(light)+k).
2. `node_name(weapon_id, id)` e `node_kind(weapon_id, id)` públicos (os
   testes novos leem por nome).
3. Nada em HunterStep muda ainda. Suite: 136/136.

## Fase 1 — a máquina lê o grafo (comportamento idêntico por construção)

1. `HunterState`: `combo_next: int` → `combo_from: int = -1`. No
   to_dict/apply_dict, a CHAVE "combo_next" é substituída por "combo_from";
   defaults seguros via `.get`. Host e Cliente são o mesmo build neste
   projeto (decisão já registrada no MEMORY, com o aviso da Revisão de não
   repetir truques de enum — aqui não há enum novo no meio).
2. `attack_index` passa a guardar o id do nó; `attack_kind` vira derivado
   (`node_kind`) mas CONTINUA escrito no Instantâneo/view_dict (a View e o
   HUD o usam para animação).
3. `_begin_attack/_finish_attack/_tick_combo_grace` passam a resolver
   entry/next do grafo. Para armas sem `combo` declarado (grafo compilado),
   o resultado é bit a bit o de hoje para sequências do mesmo tipo:
   - mesma janela (`window` = combo_window),
   - mesmo buffer (Buffered),
   - mesma volta ao primeiro golpe quando a janela expira.
   DIFERENÇA deliberada: alternar leve/pesado deixa de resetar quando o
   grafo declarar aresta — no grafo COMPILADO não declara, logo Fase 1 não
   muda nada observável.
4. `HunterInput` ganha `light_held` (espelho do `heavy_held`). Campo novo no
   pacote de Entrada; replicação de Entradas já versiona por `seq`.
5. Suite: 136/136 esperado. Qualquer vermelho aqui é bug da máquina, não
   "teste desatualizado" — regra de ouro desta fase.

## Fase 2 — Espada real (primeiros testes reescritos, com honestidade)

Entra o grafo de sword.md + `brio` no estado/Instantâneo/HUD.

O que acontece com tests/test_sim_sword.gd:

- **Continuam passando sem tocar** (dependem de fase/custo/acerto, não da
  topologia): test_light_attack_enters_the_attack_state,
  test_attack_returns_to_free_when_it_finishes,
  test_light_attack_does_not_cost_stamina, os três de Comprometimento, os
  seis de Acerto/Éter/eventos, test_all_ordinary_weapon_strikes_are_stationary
  (ganha exceções DECLARADAS para nós com deslocamento: investida_brio,
  estocada_corrida/bote_rasteiro, salto_demolidor, salto_recuo,
  estocada_disparada — o teste passa a ler um campo `desloca` do nó em vez
  de supor que todo golpe é estacionário).
- **Adaptam (mesma intenção, leitura por nó)**:
  test_pressing_again_during_the_attack_chains_the_combo,
  test_the_combo_walks_through_all_three_light_moves,
  test_waiting_too_long_restarts_the_combo,
  test_heavy_combo_cycles_and_expires,
  test_buffered_heavy_chains_without_moving — trocam `attack_index == k`
  por `_node(sim) == "lk"`. Com o achatamento da Fase 0 os ints até
  coincidem para a cadeia leve, mas os testes passam a dizer o que cobram.
- **Reescritos porque a MECÂNICA muda (declarar no commit)**:
  - test_a_heavy_attack_restarts_the_light_sequence — a regra "pesado
    reinicia os leves" DEIXA DE EXISTIR na Espada (é o ponto do ticket).
    Substituto: o teste de desvio (L,L,H → meia_lua/h1) + o teste de reset
    por janela, de TESTES.md §2.
  - A parte de test_heavy_combo_cycles_and_expires que assume pesado como
    sequência isolada 0,1,2: vira percurso `h1,h2,h3` por nome + brio +2.

## Fase 3 — Martelo e Lâminas (retirar os casos especiais do código)

1. `_begin_heavy` (hook/perto/concussive/finisher) migra para predicados de
   entry (`perto`, `longe`, `ammo==0`) — o comportamento atual é reproduzido
   e os testes atuais de Martelo/Lâminas (test_sim_hammer/test_sim_blades,
   verificar nomes na suite pós-reconstrução) devem continuar verdes ANTES
   de adicionar os nós novos (prep*, t5, giro_amplo, h1-h3, recuo...).
2. O desvio hardcoded do finalizador em `_finish_attack` (buffered HEAVY no
   3º leve) vira a aresta `p3 --heavy--> estouro`. Teste atual do
   finalizador deve passar sem mudança de roteiro.
3. Regra 5 (estados preservam `combo_from`) entra aqui, com os testes do
   gancho-no-meio e da rajada-no-meio.
4. MEMORY.md: "Martelo/Lâminas conservam suas ações especiais no botão
   pesado; suas listas de variantes não devem virar um combo sequencial
   genérico" — RESPEITADO: Rajada/Gancho/Corrente continuam ações de
   contexto (entry com predicado), não posições de sequência.

## Fase 4 — armas novas (tickets 11-13): ligar os grafos por cima dos kits

O pacote `.scratch/hunt-3d/weapons/` (publicado em 09/10/2026, durante este
projeto) entra ANTES desta fase, no formato de listas light/heavy dele — o
adaptador da Fase 0 o compila em grafos lineares e tudo funciona como lá.
Esta fase então LIGA os grafos conciliados desta pasta por cima:

- Machado: + `ceifa_continua`, mobilidade, desvios, Resolve (axe.md daqui).
- Lança: + `broca`, mobilidade, desvios (pike.md daqui).
- Repetidoras: nada a ligar (grafo sem nós; só o teste de robustez).

Pré-requisito comum já resolvido LÁ: `light_held` (weapons/INTEGRACAO.md).

## Riscos (honestos)

1. **Concorrência**: a reconstrução de src/sim pode mudar nomes, assinaturas
   e até a existência de `combo_next`. Este plano referencia o estado de
   09/10/2026; rebasear antes de executar. Dono da integração decide a ordem
   com o Gerente.
2. **Replicação**: trocar a semântica de `attack_index` (índice-por-tipo →
   id de nó) é invisível para o protocolo (continua int), mas host e cliente
   PRECISAM do mesmo build — já é a premissa do projeto; registrar no
   MEMORY na hora da troca.
3. **View/animações**: a View escolhe clips por attack_kind/attack_index;
   nós novos (hl, prep*, t5...) caem no fallback de clip até o papel
   Modelos cobrir. Mesmo padrão do aviso aberto da Revisão (SPECIAL_SPIN
   sem animação). Não é bloqueador, mas listar os nós novos para Modelos.
4. **InputMap**: `light_hold` exige distinguir toque de segurada no leve.
   O Martelo já faz isso no pesado (heavy_held); replicar o padrão. Risco
   baixo, mas toca o caminho de Entrada → testar replay de Entradas.
5. **Vigor**: a regra "leves custam 0" (MEMORY 09/10) vale para os nós
   leves novos; canais (roda_viva, ceifa, broca) drenam por segundo — é
   GASTO real e reinicia o regen_delay por tick de dreno. Decidir com o
   papel Mecânica se o dreno conta como "gasto" para a espera de 1,5 s
   (proposta: sim).
6. **Escopo do vocabulário**: a tentação de adicionar predicados/efeitos ad
   hoc por arma recria o problema que o grafo resolve. Regra: vocabulário só
   cresce via revisão + entrada no MODELO.md.
