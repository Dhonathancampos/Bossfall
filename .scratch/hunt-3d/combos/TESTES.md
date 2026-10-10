# Testes — provas determinísticas das árvores (ticket 14)

Todos os testes rodam a Sim pública (padrão de tests/test_sim_sword.gd:
andar até o boneco, injetar Entradas, ler Instantâneos). Nenhum teste lê
estado privado. Helper novo sugerido:

```gdscript
func _node(sim: Sim) -> String:
    # attack_index é o id do nó; Weapons.node_name(weapon, id) devolve o nome.
    return Weapons.node_name(WEAPON, int(_hunter(sim)["attack_index"]))

func _walk(sim: Sim, inputs: Array) -> Array[String]:
    # Executa uma sequência ["L", "H", "Lh" (segurar), "R", "."] golpe a
    # golpe: aperta, registra o nó, espera a duração + 1 tique.
```

## 1. Infra da máquina (valem para qualquer arma)

- **Determinismo**: o mesmo roteiro de Entradas duas vezes, de Sims novas →
  Instantâneos idênticos tique a tique (dict comparado).
- **Predição**: repetir o roteiro via `HunterStep.step` com world VAZIO
  reproduz pos/estado/nó do Anfitrião para sequências sem predicado de
  mundo; com predicado de mundo (gancho/corrente), o passo sem world não
  resolve e o Instantâneo corrige (contrato atual do Gancho, agora testado).
- **Janela**: terminar um nó, esperar `window` + ε, apertar de novo → nó de
  `entry`, não de `next` (reset). Esperar `window` − ε → `next` (mantém).
- **Buffer**: apertar o próximo DURANTE o golpe encadeia no primeiro tique
  após a recuperação (nó certo, sem tique de FREE no meio).
- **Snapshot**: `combo_from`/`brio`/nó sobrevivem a to_dict → apply_dict.

## 2. Espada (14 nós)

- Percorrer **L,L,L** → nós `l1,l2,l3`; ao fim, `brio == 1`.
- **H,H,H** → `h1,h2,h3`; `brio == 2`.
- **Desvio pesado**: com `brio >= 3`, **L,L,H** → `l1,l2,meia_lua` e brio
  −3. Com `brio == 0`, **L,L,H** → `l1,l2,h1` (desvia, NÃO reseta p/ l1).
- **H,L,H** com brio ≥ 3 → `h1,hl,eco`; sem brio → `h1,hl,h2`.
- **Mesmas teclas ≠ mesmo golpe**: provar `l3` (de L,L,L) ≠ `hl` (de H,L)
  comparando os ids de nó — é O teste de sequência mista do ticket.
- Segurar L com brio ≥ 3 parado → `investida_brio`, desloca ~300 e brio −3;
  com brio < 3 → `l1` e posição parada.
- Corrida: sprint sustentado + L → `estocada_corrida`; depois L → `l2`.
- Pós-esquiva: rolar, L dentro de 0,25 s → `bote_rasteiro` → L → `l2`;
  L após 0,25 s → `l1`.
- Regressão: brio máximo 6; `eco` cria a poça (eventos de tick ≥ 1 no alvo).

## 3. Martelo (9 nós)

- **L,L,L,H** com munição → `p1,p2,p3,estouro`; munição zera; dano do
  estouro escala com as munições travadas (comparar 4 vs 2).
- **Preparado não reseta**: **L,H,L,L,H** com munição →
  `p1,prep1,p2,p3,estouro`; munição total consumida = 1 (prep) + resto
  (estouro). Prova central da assinatura.
- **Preparado sem munição**: em `p1`, H com `ammo == 0` → nenhuma transição
  `prep1`; cai na entry (coronhada) — decidir e fixar: o teste trava o
  comportamento escolhido.
- **Recarga encaixada**: `p1`, R na janela → `ammo + 1`, `combo_from`
  continua `p1` (o L seguinte vai a `p2`); segundo R na mesma janela não
  soma (limite 1/nó).
- **Rajada não quebra o combo**: `p1`, segurar H (CHARGING), soltar, L →
  `p2` (regra 5: estado preserva `combo_from`).
- Corrida: sprint + H → `salto_demolidor` (desloca ~160); depois L → `p3`.
- Pós-esquiva: rolar + L → `pancada_curta` → L → `p2`.
- Reset: janela de `p2` expirada → L → `p1`.

## 4. Lâminas (16 nós)

- **L×5** → `t1..t5`; Momentum após t5 > Momentum médio dos outros (ganho
  maior no fechamento).
- **Giro misto**: **L,L,H** (perto) → `t1,t2,giro_amplo` → L →
  `corte_cruzado`. Multi-hit: nº de eventos de acerto do giro ≥ 3.
- **Segurada ≠ toque**: em `t3`, H segurado → `roda_viva` (canal: dura
  enquanto segurar, drena vigor por segundo, tick de dano a 0,25 s; soltar
  encerra); em `t2`, H tocado (perto) → `giro_amplo`.
- **Gancho no meio sem reset**: `t1,t2`, afastar o boneco (ou nascer longe),
  H → HOOK_PULL; chegar; L → `t3` (combo_from preservado e grace congelada
  durante o puxão).
- **H,H,H** → `h1,h2,h3`; quando o Ferimento (ticket 12) existir, acumula
  ferimento; até lá o teste cobra só a sequência.
- **Pesado perto** → `corrente` gastando todos os pips (teste atual
  adaptado); depois L → `t3`.
- **Afastamento**: esquiva para TRÁS + H na janela → `salto_recuo`: desloca
  ~220 para trás, nenhum evento de dano; esquiva para FRENTE + H → NÃO sai
  recuo.
- Corrida/pós-esquiva: `talho_corrida` → `t2`; `cruzado_rasante` → `t2`.
- Reset por janela: `t4`, esperar, L → `t1`.

## 5. Machado (8 nós; kit do ticket 11 — conciliado)

- **L,L,L** → `talho_amplo, talho_retorno, ceifa_total`; **H,H** →
  `racha_cranio, queda_ruina`; H segurado em `queda_ruina` →
  `ceifa_continua`.
- **Carga** (via AXE_CHARGE do kit 11): L segurado 1 s em `talho_amplo` →
  dano ≈ 1,6× o do toque (comparar HP do boneco nos dois roteiros).
- **Resolve**: soltar `racha_cranio` na janela perfeita → `resolve_time` >
  0; empurrão do Behemoth durante o golpe não entra em HURT nem aplica
  knockback (mas o dano entra). Soltar fora da janela → HURT normal.
- **Desvio**: `talho_retorno` → H → `queda_ruina`; `racha_cranio` → L →
  `talho_retorno` (não reseta).
- **Ceifa Contínua**: canal dura enquanto segurar + vigor; cada ciclo 8%
  mais curto que o anterior; vigor a zero encerra.
- Corrida: `ceifa_corrida` → L → `talho_retorno`. Pós-esquiva:
  `corte_erguido` → H → `queda_ruina`.
- Reset por janela em ambas as cadeias.
- (Fase posterior, se aprovada) carga móvel: carregando LEVE desloca a
  ~30%; carregando PESADO não desloca.

## 6. Lança (10 nós; kit do ticket 12 — conciliado)

- **L×4** → `e1..e4`; L segurado no 3º→4º → `broca` (canal, ticks a 0,2 s,
  drena vigor; soltar encerra).
- **H,H** → `varredura, estocada_profunda`; alternância: `e2` → H →
  `varredura`; `varredura` → L → `e2` (desvio sem reset nos DOIS sentidos).
- Ferimento (kit 12): estocadas e broca acumulam (PIERCE); varreduras NÃO.
- Corrida: `estocada_disparada` desloca ~120 e emenda em `e2`.
- Pós-esquiva: L → `estocada_rasante`; H → `varredura_saltada` (dois inputs
  diferentes no MESMO contexto dodge — prova a entry por input).
- Reset por janela.

## 7. Repetidoras (0 nós; kit do ticket 13 — conciliado)

O tiro contínuo, o pente, a recarga por proximidade e o Rolinho são do kit
13 e têm os testes de lá. O que é DESTE ticket é a robustez da máquina com
uma arma sem árvore:

- `combo_graph("repeaters")`: entry só com `@tumble`; `nodes` vazio — a
  máquina não trava nem exige nós.
- Atirar/rolar/recarregar nunca gravam `combo_from` (inspecionar o
  Instantâneo durante um roteiro completo de tiro+rolinho+recarga).
- Retomada pós-esquiva: rolar segurando o leve → tiro no 1º tique de FREE
  após a recuperação (`fire_cooldown` respeitado, sem tiro extra nem
  atraso).
- Retomada pós-corrida: durante sprint, zero tiros; soltar o sprint com o
  leve seguro → tiro no 1º tique.
- Prova de isolamento: um Caçador de Espada e um de Repetidoras na MESMA
  Sim, roteiros paralelos — nenhum `combo_from`/nó vaza entre eles,
  Instantâneos estáveis.

## 8. Regressões obrigatórias (suite atual)

- As fases/Comprometimento/acerto/Éter/vigor de test_sim_sword.gd continuam
  passando após a migração (ver MIGRACAO.md para os 2 testes de semântica
  antiga que serão reescritos de forma declarada).
- 136 testes atuais: nenhum removido silenciosamente; cada adaptação citada
  no commit.
