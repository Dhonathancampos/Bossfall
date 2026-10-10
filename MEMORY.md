# Memória do projeto — Dauntless Lite

Registro vivo das decisões, mudanças e referências do projeto. Atualize este
arquivo ao concluir qualquer alteração relevante de mecânica, apresentação,
rede, conteúdo ou balanceamento.

## Referência canônica

- **Alvo de reprodução:** última versão live de *Dauntless* anterior a
  **Awakening**, isto é, a build disponível até **4 de dezembro de 2024**.
- Awakening entrou em 5 de dezembro de 2024 e alterou armas e progressão; suas
  mecânicas não são referência para este projeto.
- Objetivo: reproduzir o comportamento e a legibilidade do combate dessa
  versão com código, arte e nomes originais deste repositório. Não copiar
  arquivos, vozes, modelos, animações ou outros assets proprietários.

## Direção de combate aprovada

O jogo deixa de ser apenas inspirado em Dauntless. O combate precisa convergir
para o modelo pré-Awakening:

1. Behemoths com movimentos, janelas e oportunidades de interrupção próprios;
   não uma IA genérica que sorteia ataques equivalentes.
2. Defesa baseada em leitura de animação, posicionamento e esquiva com
   invulnerabilidade; telemetria no chão só quando fizer parte da leitura do
   ataque, e sempre coincidente com a área de dano.
3. Dano separado em Vida/base, Parte, Atordoamento e Ferimento, com feedback
   visual distinto e efeitos corretos de quebra, atordoamento e ferida.
4. Ritmo solo que alterna pressão, recuperação e oportunidades claras de
   punição — sem encadear ataques por uma pausa artificial universal.
5. Armas, combos, medidores, especiais e mobilidade serão substituídos por
   versões equivalentes às armas pré-Awakening, uma por vez e com testes.

## Estado encontrado em 09/10/2026

- A Sim é determinística e separada da apresentação; essa arquitetura será
  preservada.
- Existiam Espada, Martelo e Lâminas com kits próprios simplificados. Eles não
  são ainda reproduções fiéis dos kits pré-Awakening.
- Gnasher e Bastião usam uma máquina genérica de perseguição e escolha ponderada
  de ataques. Isso é provisório e será trocado por padrões por Behemoth.
- O projeto ainda não possui Ferimento, interrupções/boops, zonas de acerto por
  parte, nem o conjunto completo de armas e sistemas de caça da referência.

## Alterações já feitas

### Colisão e áreas

- A área `dash` passou a usar o corredor completo mostrado pela telegrafia, em
  vez de um círculo no centro do Behemoth.
- Cones passaram a considerar o raio do corpo do Caçador nas bordas.
- Foi incluída separação física entre Caçador e Behemoth na Sim e na predição do
  cliente, evitando atravessamento lógico.
- Testes cobrem o corredor de investida e a separação dos corpos.

### Ajustes temporários de legibilidade e solo

- O raio lógico dos Behemoths foi elevado para acompanhar melhor o modelo 3D
  provisório, que é maior que o antigo collider.
- Câmera foi afastada/inclinada e as cores da telegrafia ganharam contraste.
- Foi inserida uma pausa global de 0,8 s entre ataques e o alcance do Golpe de
  Corrente foi reduzido para 40 cm.

> Esses três últimos ajustes são **temporários**. Eles não devem ser tratados
> como números do Dauntless pré-Awakening: serão substituídos durante a
> implementação de padrões, hitboxes e timings específicos por Behemoth.

### Área de treinamento — 09/10/2026

- Foi criado um modo local acessível pelo botão **Área de treinamento** no menu.
- Ele instancia a mesma `Sim` usada nas caçadas, mas sem Behemoth e com um
  boneco de Vida muito alta, visível na Arena 3D. Assim os testes de combos,
  alcance, esquiva e recursos não usam regras paralelas.
- A arma e o elemento selecionados no menu também são usados no treinamento.
- Próximos incrementos: troca de arma dentro da área, reinício de posição,
  painel de comandos/combos, histórico de dano e modos de comportamento do
  boneco.

### Correção das armas invisíveis — 09/10/2026

- Causa confirmada no rig importado: o glTF renomeou `hand_r` e `forearm_l`
  para `hand_r_2` e `forearm_l_2`. A montagem procurava os nomes sem sufixo e
  retornava silenciosamente; nenhuma arma era instanciada.
- `HunterView` agora prefere o nome exato e aceita um único nome com sufixo
  numérico do importador. Usa o nome/índice real no `BoneAttachment3D` e emite
  erro se o osso estiver ausente ou ambíguo.
- Espada e martelo equipam na mão direita; as lâminas equipam dos dois lados.
  A esquerda usa a ponta do antebraço (offset de 0,27 m), pois o rig atual
  ainda não possui osso de mão esquerda.
- Teste de regressão verifica quantidade de armas, vínculo ao osso, presença
  de malhas e visibilidade para os três modelos reais.
- Inspeção visual com renderizador OpenGL confirmou as três armas em repouso
  e ataque. Captura: `.scratch/weapons-preview.png`; reprodução:
  `godot --path . --rendering-method gl_compatibility --script res://tools/preview_weapons.gd`.
- Modelos e animações continuam provisórios; esta correção resolve a montagem
  visual, não a fidelidade dos combos pré-Awakening.
- Validação final: 126 testes, 0 falhas.

## Importado do chat do Gerente — 09/10/2026

Transcrito pelo Gerente em 09/10/2026:

### Fluxo de trabalho em equipe

O desenvolvimento roda com um Gerente (chat principal) e agentes por papel:
**Mecânica** (Sim/rede), **Áudio** (SFX procedurais em `tools/sfx/`),
**Modelos/Animações** (Blender headless em `tools/models/`), **Creator**
(design de Behemoths novos em `.scratch/bestiary/`) e **Revisão** (passa
depois de cada leva; achados em `.scratch/hunt-3d/REVIEW.md`). Papéis recebem
arquivos disjuntos para não conflitar. Todo agente deve ler este MEMORY.md
antes de mexer em mecânica (regra do CLAUDE.md).

### Ordem de tarefas (fila aprovada pelo usuário)

Tickets em `.scratch/hunt-3d/issues/`. Feitos: 01–07 (pipeline Blender,
arena 3D/câmera, caçador, quadrúpede, Partes/Atordoamento, Elementos/Aflições,
rework clássico das armas + Bastião). Fila, nesta ordem:

1. **08** Voador (segundo Behemoth, projéteis/mergulho)
2. **09** Abatido/Reviver de verdade (Fichas, companheiro levanta, derrota)
3. **10** Lobby completo, HUD, tela de resultado
4. **11** Machado (carga + Determinação) — pedido 09/10
5. **12** Lança (Perfuração/Ferimento + Conversão Aetérica) — pedido 09/10
6. **13** Repetidoras/pistolas (pente, recarga com timing, queda por
   distância) — pedido 09/10
7. **14** Combos completos + habilidades exclusivas de TODAS as armas —
   pedido 09/10

Do bestiário (Creator): implementar **Brejara** depois do Bastião (a infra de
poças persistentes serve ao mergulho do Voador e à lava do Fornalho); depois
Fornalho e Vespreia. Fichas em `.scratch/bestiary/`.

**Conciliação decidida em 09/10/2026 pelo responsável:** a "Ordem de
reconstrução" PREVALECE sobre a fila de tickets. A fila (08–14) vira backlog
de conteúdo, encaixado após os itens 1–3 da reconstrução. Próxima rodada da
equipe: contrato de combate + Gnasher de referência.

### Elementos — decisão de 09/10/2026

Renomeados para abranger possibilidades futuras: **Fogo, Água, Elétrico,
Terra, Luz, Trevas** (+ Neutro). Identificadores do código (BLAZE, FROST,
SHOCK, TERRA, RADIANT, UMBRAL) não mudam — replicação/saves não dependem de
nome. Oposição: Fogo↔Água, Elétrico↔Terra, Luz↔Trevas; oposto ×1,25, mesmo
×0,75, Neutro sempre ×1. Aflições por elemento: Queimadura, Congelamento,
Choque, Enraizamento, Cegueira, Dreno — com acúmulo (60/acerto, limiar 100,
decaimento 8/s; valores provisórios). Fonte única: `src/sim/elements.gd`.

### Armas — status em 09/10/2026

- **Aprovadas e ativas (3):** Espada, Martelo, Lâminas Correntes. Nenhuma
  removida. Rework de 09/10 na direção da referência:
  - Martelo: 4 munições; segurar o pesado = rajada concussiva escalando por
    munição; R = recarga com janela de timing; finalizador descarrega as
    munições restantes. A carga estilo "segurar para bater mais forte em
    tempo contínuo" foi REMOVIDA de propósito — não reintroduzir.
  - Espada: Valor/Overdrive (F): ×1,3 dano, ×1,15 velocidade, 8 s, golpes
    conectados emitem onda elemental (projétil que respeita a Oposição).
  - Lâminas: momentum (34/acerto, 100 = 1 pip, máx 3), gancho de graça,
    pesado colado = Golpe de Corrente consumindo os pips.
- **Priorizadas (fila):** Machado → Lança → Repetidoras → combos completos.
- Timings/valores atuais são provisórios; a fidelidade por arma é o ticket 14
  somado aos itens 4–5 da Ordem de reconstrução.

### Bastião — regra do usuário

Placas de armadura reduzem o dano que atravessa para a Vida a **15%
(`ARMOR_LEAK`), nunca zero** — decisão explícita do usuário. A placa em si
apanha o dano cheio. Quebra da Carapaça atrasa o Rolamento (+1 s, dado
`break_penalty`).

### Revisão de 09/10 — avisos ainda abertos

- Estados novos do HunterState entraram no MEIO do enum (ints replicados
  mudaram); inofensivo com host/cliente no mesmo build, mas não repetir.
- SPECIAL_SPIN e RELOADING sem animação própria (fallback) — papel Modelos.
- Eventos (sons/números de dano) viajam no canal não confiável: pacote
  perdido = som perdido no cliente.
- `_redraw_ground` recria malhas todo quadro — candidato a pooling com 4
  jogadores.
- Bastião usa o modelo do quadrúpede como corpo provisório.
- Câmera sem colisão: atravessa o corpo do Behemoth quando colado.

### Convenções que o Gerente cobra dos agentes

- Teste determinístico para toda regra nova; captura para todo visual.
- Asset é código: .glb nasce de `tools/models/*.py`, .wav de `tools/sfx/`.
- Mecânicas seguem a referência; nomes, arte e código são originais deste
  repositório (nunca incorporar assets de terceiros).

## Bestiário — ficha 05: Faiscaia (Creator) — 09/10/2026

- Nova ficha de design em `.scratch/bestiary/05-faiscaia.md` (sem código).
  **Faiscaia**: lacraia colossal de quartzo, duelista de relógio, Elemento
  Elétrico. Mecânica nova: **Núcleo Errante** — zona de acerto (offset+raio,
  contrato novo) que migra por 4 estações do corpo (Ferrão → dorso → cabeça);
  ao chegar às Mandíbulas dispara a **Descarga Plena**, ataque enorme com
  Preparo de 2 s `interruptible` — a luta que faz da interrupção/boop um
  recurso central, não um bônus. Dano no núcleo atrasa o relógio; quebras
  mudam o PADRÃO (Antenas = perde o lead da esquiva; Placas = relógio lento;
  Ferrão decepado ENCURTA o ciclo — primeira quebra com preço deliberado).
- Usa o vocabulário do contrato novo: `zone` por Parte, `interruptible`
  (janela/limiar no Preparo), `telegraph` por ataque (Pinçada lê-se só pela
  animação), `post_gap`, cérebro por padrões (`faiscaia_plan`), com um disparo
  por estado interno (estação do núcleo) que o contrato ainda não tem.
- Custo de motor: médio-grande, sem entidade/rede nova além de 2 campos no
  Instantâneo (`core_station`, `station_time`); detalhado na ficha. Entra na
  ordem de implementação como 4º (antes da Vespreia), condicionado ao contrato
  novo estar assentado com o Gnasher.
- Provisórios: limiares de `interruptible` (60/110 — calibrar contra o
  Atordoamento real da Rajada do Martelo), dano 40 da Descarga (vs. Vida do
  Caçador), tempos de estação (9 s/13 s/6,5 s) e o raio 140 (as fichas usam a
  escala antiga; o código hoje infla raios temporariamente).
- `.scratch/bestiary/README.md` atualizado (tabela com 5, ordem recomendada,
  nota mapeando os nomes antigos de Elemento das fichas 01–04 para os novos).

## Ordem de reconstrução

1. Criar o contrato de combate: hitboxes, hurtboxes, zonas de parte, eventos de
   ataque e interrupção, sem depender da apresentação.
2. Recriar o Gnasher como primeiro Behemoth de referência, com sequência,
   timings e oportunidades próprias; validar solo.
3. Separar dano Base/Parte/Atordoamento/Ferimento e o feedback visual.
4. Recriar as armas pré-Awakening por prioridade: Espada, Martelo, Lâminas,
   Machado, Lança de Guerra, Repetidores e Aether Strikers.
5. Acrescentar estados de Behemoth (enfurecido, aethercharged, interrompido),
   caça, equipamentos, perks e conteúdo adicional.

## Critérios para aceitar uma mecânica

- A regra entra na `Sim`; apresentação apenas mostra o estado/evento.
- Ataque, animação, telemetria e hitbox precisam usar a mesma definição de
  timing e forma.
- Toda alteração ganha teste determinístico e, quando for visual, uma captura
  ou checklist de inspeção manual.
- Valores sem fonte ou teste são marcados como provisórios aqui; não são
  apresentados como fiéis ao jogo de referência.

## Fontes consultadas

- [Anúncio de Awakening, 2/12/2024](https://news.xbox.com/en-us/2024/12/02/dauntless-awakening-karkonos-behemoth/) — confirma lançamento em 5/12/2024 e
  que foi uma reformulação ampla.
- [Notas oficiais de Awakening no Steam](https://steamcommunity.com/app/331370/announcements/) — descrevem a troca de armas e sistemas em 2.1.0.
- [Documentação comunitária de dano](https://dauntless.fandom.com/wiki/Damage) e
  [interrupções](https://dauntless.fandom.com/wiki/Stun) — referências
  secundárias para o modelo de dano, quebra, atordoamento e boops; validar por
  capturas/telemetria antes de fixar valores exatos.

## Próximo trabalho

### Revisão de movimento, pesado e alvo — 09/10/2026

- Pedido: eliminar avanço por golpe, corrigir movimento/corrida, encadear
  pesados e aproximar o boneco do treinamento pré-Awakening.
- Removida a aplicação automática de `advance` em todos os golpes comuns.
  Campos antigos ainda existem nos dados, mas não são consumidos. Gancho,
  rolamento, movimento durante especial e empurrões continuam separados.
- A velocidade agora é calculada por tique na `HunterStep`, serializada em
  snapshots completos/visuais e restaurada na predição. `HunterView` não
  deriva mais velocidade de posições repetidas entre frames (causa de
  alternância espúria entre idle/walk/sprint).
- Ciclos walk/sprint reconstruídos na apresentação usando o plano sagital
  real do rig, com biblioteca de animação privada por instância. O corpo
  acompanha a direção da caminhada sem alterar a mira lógica. O gerador
  Blender antigo ainda contém os ciclos antigos; o override de apresentação
  é intencional até a próxima revisão dos assets.
- A espada passou a ter pesado 1 → 2 → 3 → 1, buffer durante o golpe e janela
  de 0,30 s após recuperação. Alternar leve/pesado reinicia a sequência;
  combos mistos e sistema completo de Valor ainda NÃO foram reproduzidos.
  Martelo/Lâminas conservam suas ações especiais no botão pesado; suas listas
  de variantes não devem virar um combo sequencial genérico.
- Clips de golpe são sincronizados por fase da Sim, inclusive reinício do
  mesmo clip. Segundo pesado reutiliza light_2; demais usam heavy. Quarto
  leve das Lâminas usa fallback existente, evitando nome de clip inexistente.
  São animações provisórias, não animações fiéis às armas originais.
- Substituído alvo humanoide por carro-Behemoth procedural: quatro rodas,
  barril, lona, focinho/mandíbula, dentes, placas e bandeira vermelha. Raio
  de acerto aumentado de 70 para 145 cm para acompanhar a nova silhueta.
  Referência visual: [imagem do treinamento de 2020](https://d1lss44hh2trtw.cloudfront.net/assets/editorial/2020/06/dauntless-training-grounds.jpg).
  Nenhum asset original foi incorporado ao jogo. A imagem de referência
  fica apenas em `.scratch/dummy-reference.jpg`.
- Limites: boneco ainda usa alvo circular único, sem zonas de parte,
  bloqueio corporal próprio, ferimento ou equivalência completa ao original.
  Vida ainda é finita e alta (100000), não infinita. Aparência é low-poly
  simplificada; timings/dano dos pesados novos são escolhas provisórias.
- Validação: **131 testes, 0 falhas** na suite determinística e de assets; captura gráfica com
  `tools/preview_combat.gd` em `.scratch/combat-preview.png` (boneco e quatro
  fases da corrida). Reavaliar sensação em jogo e multiplayer real; testes
  automatizados não certificam fidelidade pré-Awakening.

### Continuidade do plano

### Contrato de combate e Gnasher de referência — 09/10/2026

Ordem de reconstrução, itens 1 e 2, implementados pelo papel Mecânica.

**Contrato (item 1):**
- Zonas por Parte: cada Parte pode definir `zone` nos dados (deslocamento
  frente/lado + raio, no plano) — o golpe atinge a Parte cuja zona está mais
  perto do atacante. Gnasher ganhou zonas (cabeça/cauda/pernas); Partes sem
  zona caem no setor angular (fallback usado pelo Bastião, coberto por teste).
- Eventos padronizados da Sim: `behemoth_phase` (windup/active/recover/end),
  `interrupt`, `staggered`, `enraged`, `behemoth_died`. O áudio deixou de
  adivinhar Fúria/queda/morte por polling e passou a reagir aos eventos
  (`audio_fx.gd`); a telegrafia virou dado por ataque (`telegraph`), lida em
  `arena_3d.gd`.
- Interrupção (boop): ataques declaram `interruptible` ({until, threshold})
  nos dados; impacto de Atordoamento acima do limiar dentro da janela do
  Preparo cancela o ataque, aplica a recarga e abre `INTERRUPTED` (1,6 s,
  novo estado no FIM do enum — ints replicados preservados). A Rajada do
  Martelo e a explosão do Magma passam pelo boop antes de alimentar o
  medidor; quando o boop acontece, aquele golpe não soma no medidor (regra
  provisória para boop e queda não saírem do mesmo golpe).
- Pausa global de 0,8 s REMOVIDA (era ajuste temporário): o ritmo agora é por
  ataque (`post_gap`) e por Behemoth (`decision_gap`), com Fúria cortando as
  brechas pela metade.

**Gnasher de referência (item 2):**
- `brain: "gnasher"` troca o sorteio ponderado por padrões situacionais
  (BehemothStep.gnasher_plan, público para os testes): alvo atrás → Rabada;
  colado ≥ 2,5 s → Pisão; no alcance da boca → Mordida (dupla por sorteio,
  45% — 70% em Fúria; único uso de rng); longe → Investida. Investida que
  termina com o alvo nas costas emenda a Rabada por padrão, e investida que
  ERRA fica exposta +0,7 s (`whiff_recovery_bonus`) — a janela de punição.
- Sequências encadeadas (plano) saem com pausa de 0,3 s entre passos, sem
  passar pela decisão — mordida dupla é um movimento, não dois.
- Bastião segue no cérebro genérico com `decision_gap` 0,7 e ganhou janelas
  de interrupção no Rolamento e no Tremor.

**Correções de coerência encontradas no caminho:**
- `min/max_range` de ESCOLHA agora são medidos da borda do corpo (centro −
  raio): com o raio provisório de 230, medir do centro deixava a mordida
  (215) inalcançável — o monstro só conseguia investir.
- Alcance das FORMAS de cone/círculo rebaixado nos dados para cobrir corpo +
  alcance útil (ex.: mordida 215 → 445 do centro), mantendo forma desenhada =
  forma que acerta. Números provisórios, atrelados ao raio provisório do
  modelo; recalibrar quando o collider/model definitivo chegar.

**Provisório (sem fonte de telemetria):** INTERRUPT_DURATION 1,6 s; janelas e
limiares de boop (90/110); post_gaps; chances da mordida dupla; `telegraph`
ainda true em todos os ataques enquanto as animações são provisórias (o dado
já permite desligar por ataque). Padrões do Gnasher inspirados no
comportamento documentado publicamente do monstro de referência (mordidas
encadeadas, investida com virada lenta, punição por posicionamento), sem
frame data real — timings são escolhas nossas.

**Validação:** 156 testes, 0 falhas (20 novos em `tests/test_sim_contract.gd`:
zonas, fallback por setor, ordem dos eventos de fase, boop dentro/fora da
janela e abaixo do limiar, levantada do boop, os 4 padrões + variação da
mordida dupla só por rng, encadeamento ignora a brecha de decisão, punição de
investida errada, Fúria encurtando brechas, Bastião no cérebro genérico).
Smoke de rede: o cliente headless conectou, replicou e previu contra uma
sessão AO VIVO na porta 7777 (havia um jogo aberto na máquina; por isso o
segundo host de teste não subiu — limitação do smoke, não regressão).


### Vigor dos ataques leves — 09/10/2026

- Corrigidos todos os golpes dos combos leves atuais de Espada, Martelo e
  Lâminas: custo de vigor = 0, definido nos dados de cada golpe. Não foi
  criada uma regra universal que isente qualquer ação ligada ao botão leve;
  futuros golpes carregados/canalizados podem ter custos próprios.
- `_spend` agora ignora valores zero: antes, mesmo um golpe gratuito
  reiniciaria `regen_delay`. Leves podem ser usados com vigor zerado e
  permitem regenerar durante o combo, após a espera do último gasto real.
- Referência consultada: [relatos de jogo de março de 2023](https://www.reddit.com/r/dauntless/comments/126qe9f/stamina_during_fight/),
  anteriores a Awakening, descrevem alternar pesados e leves para recuperar
  vigor. Evidência comunitária de experiência direta, não especificação
  oficial nem verificação da última build de dezembro de 2024.
- Escopo desta correção: custo dos leves e preservação da regeneração.
  Corrida, esquiva, pesados e especiais mantêm os custos anteriores,
  ainda provisórios. A fonte também descreve particularidades de ações com
  vigor baixo/zerado e espera de 1,5 s; esses pontos exigem revisão separada
  por ação. Não afirmar que todo o sistema de vigor já replica o original.
- Validação: **134 testes, 0 falhas**. Novos testes cobrem combos completos
  das três armas com vigor zero, regeneração idêntica ao repouso durante
  leves contínuos (sem reiniciar ou eliminar a espera) e manutenção do
  custo/atraso do pesado da espada. Teste antigo de custo do leve corrigido.

### Ritmo de regeneração do vigor — 09/10/2026

- Correção após teste do usuário: delay era 0,6 s e regeneração 34 pontos/s.
  Como o gasto ocorre ao começar o golpe, a espera acabava antes do fim de
  alguns pesados, dando aparência de regeneração imediata.
- Ajustados para 1,5 s sem gasto e 9 pontos/s, sem bônus. Relógio contado
  desde o último gasto real, NÃO desde o fim de qualquer animação. Novo
  gasto reinicia a espera; leves continuam gratuitos e permitem regenerar
  quando ela termina, sem criar bloqueio permanente durante combos leves.
- Base: [relatos de 2022](https://www.reddit.com/r/dauntless/comments/xsvzna/)
  indicam 1,5 s e taxa base 9/s; [relatos de 2023](https://www.reddit.com/r/dauntless/comments/126qe9f/)
  corroboram a espera. Evidência comunitária pré-Awakening, ainda sem
  confirmação oficial/telemetria da última build. Não inclui bônus de
  equipamento, células ou reforjas.
- Testes novos: pesado → leves sem regenerar antes de 1,5 s, recuperação de
  9 pontos no segundo seguinte e reinício da espera após novo pesado.
  Testes antigos de corrida e esquiva foram atualizados: não pressupõem
  mais barra cheia em dois segundos, nem reserva suficiente após espera curta.
- Validação final: **136 testes, 0 falhas**.

Substituir o combate genérico do Gnasher pelo primeiro vertical slice fiel à
referência pré-Awakening. Antes de calibrar valores finais, registrar neste
arquivo a evidência (vídeo, captura, patch note ou teste reproduzível) usada.

### Pacote Machado/Lança/Repetidoras — 09/10/2026 (projetado, NÃO aplicado)

- Enquanto o contrato de combate era reconstruído em `src/sim/`, o papel
  Mecânica (Armas) escreveu os tickets 11–13 como pacote pronto para
  integrar em `.scratch/hunt-3d/weapons/`: `PESQUISA.md` (fontes),
  `axe.md`, `pike.md`, `repeaters.md` (entradas completas de
  `Weapons._DATA`, estados novos, regras de Sim/Combat), `INTEGRACAO.md`
  (ordem de aplicação, tabela de replicação) e `TESTES.md` (48 testes
  nomeados). **Nada entrou em `src/`**; o Gerente aplica com a Sim livre.
- Descobertas da pesquisa que MUDAM os tickets (detalhe em PESQUISA.md):
  - **Ferimento (ticket 12)**: o ticket descreve o modelo pré-1.6.0 (Parte
    Ferida recebe bônus de dano de Parte). A build de referência usa o
    rework 1.6.0 (abr/2021): Ferida dura 15 s com éter vazando, SEM bônus
    de Parte — quem explora a ferida ganha buff pessoal. O pacote propõe um
    híbrido (15 s da referência + bônus do ticket: ×1,5 Parte / ×1,25 Vida)
    e especifica o modelo fiel como alternativa. Decisão pendente do
    Gerente/usuário.
  - **Recarga das Repetidoras (ticket 13)**: a referência empodera por
    PROXIMIDADE (recarregar colado ao Behemoth suga éter e empodera o
    pente), não por janela de timing. O pacote segue a referência; a
    recarga com timing fica exclusiva do Martelo. Pente de 12 confirmado.
  - **Determinação do Machado (ticket 11)**: a pilha vem de conectar o
    RECALL do Voo da Ruína com o medidor cheio, não de apertar F; máx 3
    pilhas confirmado; +15%/pilha segue SEM fonte (provisório). Resolve
    (super armor ao soltar o vertical no nível 3) existe na referência e
    ficou especificado como fase 2.
  - **Conversão Aetérica da Lança** converte a partir de 10% do medidor
    (qualidades 1–4 nos limiares 10/33/66/90%), não exige medidor cheio.
- Decisões registradas no pacote: `AXE_CHARGE` e `TUMBLE` SÓ no fim do enum
  State do Caçador (aviso do REVIEW; o INTERRUPTED novo é do Behemoth);
  `DamageType.BALLISTIC` no fim; entrada nova `light_held` (contínua,
  preservada quando a fila seca, como `heavy_held`); Ferimento mora nas
  Partes do Behemoth (replica via `parts.duplicate(true)`); `kind` entra no
  snapshot de projéteis; míssil da Lança e Salva devem passar pelo caminho
  de boop do contrato novo; vigor dos leves continua ZERO (a carga do
  Machado tem dreno próprio por ser golpe canalizado — exceção prevista).
- TODOS os números são provisórios, calibrados por coerência com
  Espada/Martelo/Lâminas atuais; os poucos com fonte comunitária estão
  marcados [EV] no pacote (pente 12, limiares 10/33/66/90, Ferida 15 s,
  Ferimento 133% do dano, Salva empoderada = 3 mísseis).
- Fontes novas: patch notes 1.6.0 (shacknews), devtrackers "State of
  Dauntless: Wounding and War Pike", gamewith (Machado), dauntlesswiki.com,
  fextralife (Repeaters), gameskinny. O dauntless.fandom.com respondia
  HTTP 402 nesta data (sem acesso).

### Combos completos de todas as armas — 09/10/2026 (projetado, NÃO aplicado)

- Ticket 14, papel Combos. Entregue em `.scratch/hunt-3d/combos/` (SÓ
  projeto; `src/`, `tools/` e `tests/` intactos — a Sim estava em
  reconstrução paralela): `PESQUISA.md` (árvores reais pré-Awakening, com
  fonte e ERA de cada uma), `MODELO.md` (máquina nova), fichas
  `sword/hammer/blades/axe/pike/repeaters.md`, `TESTES.md` e `MIGRACAO.md`.
- Modelo escolhido: **grafo de combo como dados** por arma — nós (= Golpes
  com as fases atuais) com transições por entrada (`light/heavy/light_hold/
  heavy_hold/reload`), entradas por contexto (free/corrida/pós-esquiva),
  predicados (`brio>=3`, `ammo==0`, `perto/longe`) e efeitos (`brio+1`,
  `ammo-1`...). `combo_next` → `combo_from` (id do nó anterior, 1 int no
  Instantâneo); `attack_index` vira id de nó com achatamento que preserva
  os ids atuais; predição do Cliente continua exata (grafo estático +
  recursos replicados; sem world vale a candidata `sem_mundo` — contrato
  atual do Gancho). Alternativa "caminho textual LLH" descartada
  (histórico no snapshot, ambiguidade de prefixo, O(1) perdido).
- Fidelidade descoberta na pesquisa: a Espada de dez/2024 é a de **Valour**
  (rework 1.3.3: L-L-L/H-H-H geram pips; L-L-H, H-L-H, segurar L/H gastam
  3) — o recurso ganhou o nome **Brio** para não colidir com o Especial
  "Valor" atual, que fica como está. Martelo: golpe **preparado** (pesado
  entre leves, −1 munição, SEM resetar o combo) e **recarga encaixada**
  (+1 munição no meio do combo) — guia 0.8.1, sem refresh posterior
  conhecido. Lâminas pós-1.8.3: leves ×5, giro segurável no 3º com corte
  cruzado final, H-H-H de Ferimento, gancho no moveset sem resetar;
  afastamento adaptado do backflip do Reaper's Dance para o moveset
  (esquiva-atrás + pesado), escolha declarada.
- Profundidade das árvores: Espada 14 nós, Martelo 9, Lâminas 16, Machado 8,
  Lança 10, Repetidoras **0** (sem árvore é a fidelidade; a máquina tolera
  grafo vazio sem caso especial).
- Conciliado com o pacote dos tickets 11–13 (`.scratch/hunt-3d/weapons/`,
  publicado durante o trabalho): kits adotados como nós base; Ripper
  (Ceifa Contínua), Resolve e golpes de mobilidade — remetidos de lá ao 14
  — especificados nas fichas daqui; Repetidoras seguem o pacote
  (proximidade + Rolinho); `light_held` é o do INTEGRACAO.md deles, uma
  implementação só.
- Migração em 4 fases (MIGRACAO.md): adaptador compila as listas atuais em
  grafos lineares (comportamento idêntico) → máquina lê grafo → Espada real
  (DOIS testes de `tests/test_sim_sword.gd` serão REESCRITOS
  declaradamente: a regra "pesado reinicia os leves" deixa de existir — é o
  ponto do ticket) → Martelo/Lâminas por predicados + armas novas por cima
  dos kits. Riscos: reconstrução paralela de src/sim (REBASEAR antes de
  executar), semântica nova de `attack_index` (mesmo build host/cliente),
  clips dos nós novos em fallback (listar para o papel Modelos), vocabulário
  de predicados/efeitos só cresce via revisão.
- Números/janelas das fichas: provisórios. Pendência: verificação por
  vídeo/telemetria da build de nov/2024 (Fandom 402 e archive.org
  inacessíveis nesta sessão).

### Animações: pipeline, Caçador e quadrúpede — 09/10/2026

Papel Animações. Diagnóstico completo, fontes e limites em
`.scratch/hunt-3d/ANIMACAO.md`.

- **Diagnóstico.** `tools/models/common.py` só sabia prender peça rígida em
  osso e interpolar tudo em Bézier automático: nenhum clipe tinha
  antecipação, estalo de contato nem arrasto. Como a pose era escrita no
  eixo LOCAL de cada osso (que muda conforme a direção do osso), a caminhada
  saiu com as pernas abrindo para os lados e foi refeita por código em
  `hunter_view.gd` — dívida registrada na entrada anterior. E havia UM jogo
  de Golpes (o da Espada) servindo as três armas por esticão de relógio
  (`_attack_clip_time`), com `SPECIAL_SPIN` e `RELOADING` sem clipe algum.
- **Pipeline (`common.py`).** Novidades, todas documentadas em PT no
  docstring: easing por chave (tabela `EASING`: `wind/accel` para preparo,
  `snap/hit` para contato, `settle/overshoot/bounce` para recuperação);
  `space="world"`, que escreve rotação E translação nos mesmos eixos para
  todo osso (rx rola, ry inclina a ponta para a frente, rz gira para a
  esquerda) e converte pela matriz de repouso; `chain()` para declarar
  correntes de ossos; `attach_gradient()` para repartir UMA malha entre
  vários ossos com transição suave; `settle()` e `follow()` para
  movimento secundário (follow com damping NEGATIVO = arrasto de osso
  filho); `cycle()` para ciclos senoidais amostrados (locomoção).
- **Duas correções de tempo no exportador.** `FPS` 30 → **60** (igual ao
  passo da Sim) e tempo zero no quadro ZERO em vez do quadro 1 — o
  exportador glTF conta a duração a partir do quadro 0, então começar no 1
  somava um quadro a todo clipe (um Golpe de 0,43 s chegava com 0,45 s).
  Agora a diferença entre clipe e número da Sim fica abaixo de 8 ms.
- **Caçador.** Rig mais fundo: `root─spine_01─spine_02─chest─neck─head`,
  osso próprio de cachecol, braços com mão dos DOIS lados e pernas com pé.
  Malhas ganharam prefixo `m_` para não disputarem nome com os ossos no
  glTF (era a causa do `hand_r_2`); com `hand_l` real, a lâmina esquerda
  saiu da ponta do antebraço. **28 clipes**: um por Golpe de cada arma
  (`sword_light_1..3`, `sword_heavy_1..3`, `hammer_light_1..3`,
  `hammer_heavy_1..3`, `blades_light_1..4`, `blades_heavy_2`) com a duração
  e as fases EXATAS de `src/sim/weapons.gd`, mais `idle/walk/sprint/dodge/
  hurt/downed/revive/charge/reload/special_spin/hook`. `blades_heavy_1` não
  existe de propósito: o índice 0 do pesado das Lâminas é o Gancho, que não
  é Golpe. A batida da recarga cai em 0,65 s, DENTRO da janela do tiro certo
  (`RELOAD_QUICK_START` 0,5 / `RELOAD_QUICK_END` 0,8).
- **Quadrúpede.** Rig `root─spine─neck─head─jaw`, `tail_a─tail_b` e pata com
  `leg─paw`. A cauda continua UMA malha chamada `tail` (contrato com a
  Godot para esconder a Parte decepada), agora repartida entre dois ossos —
  por isso os OSSOS da cauda não se chamam `tail`. Mordida com a cabeça
  recuando antes do bote, investida que avança 0,55 m dentro do clipe,
  pisão que empina e desaba com quique, rabada com a ponta atrasada em
  relação à base, tombo do Atordoamento rolando de verdade (~62°) por 4,5 s
  e morte que congela na última pose. **`src/sim/` não foi tocado** (outro
  papel reconstruindo o Gnasher); as durações foram copiadas do estado
  atual de `behemoths.gd`.
- **Apresentação.** `hunter_view.gd` perdeu `_build_locomotion` (caminhada e
  corrida voltaram ao clipe gerado — o docstring registra por quê, para o
  remendo não voltar) e `_attack_clip_time` (o tempo do estado É o tempo do
  clipe). Escolhe `<arma>_<leve|pesado>_<índice+1>` com queda para o jogo da
  Espada; `RELOADING`→`reload`, `SPECIAL_SPIN`→`special_spin`,
  `HOOK_PULL`→`hook`. O rolamento virou mergulho para a frente e o corpo
  gira para `dodge_dir`, que antes era ignorado. O campo `animation` dos
  dados de Golpe virou legado e não é mais lido (não removido: mora em
  `src/sim/`).
- **Ferramenta.** `tools/preview_model.gd` aceita vários tempos separados
  por vírgula (sai uma TIRA lado a lado: preparo → contato → recuperação) e
  uma arma opcional na mão.
- **Provisório.** Os clipes casam com a Sim, e a Sim ainda é provisória —
  nada foi calibrado contra vídeo ou telemetria de dez/2024. Sem blend
  entre clipes (a pose de prontidão comum disfarça o corte). Bastião segue
  sem clipes próprios. Combos mistos e as árvores do ticket 14 ainda não
  têm animação. Escala das armas tapa a silhueta em alguns arcos (é o
  modelo da arma, não a animação).
- **Fontes** (comportamento, nunca asset): guia comunitário pré-Awakening de
  Nigh7mare (combos e ritmo por arma, telegrafia do Gnasher), refresh
  oficial das Chain Blades, wikis de armas/tipos de dano. Links e o limite
  de cada uma no `ANIMACAO.md`. `dauntless-archive.fandom.com` respondeu
  HTTP 402 nesta data.
- **Validação:** `build_all.ps1` verde (6 modelos), `--import` sem erro,
  **160 testes, 0 falhas** (eram 136). Testes novos: duração de cada clipe
  de Golpe = duração do Golpe na Sim (tolerância de um quadro de 60 Hz), o
  mesmo para os ataques do Gnasher, cada arma tocando o clipe do próprio
  Golpe, e os quatro estados de arma com animação própria. Se a Sim mudar
  os tempos do Gnasher, o teste quebra de propósito: a correção é REGERAR
  o modelo, não afrouxar o teste. Capturas: `.scratch/hunt-3d/previews/`
  (`hunter_*.png`, `quad_*.png`).

### Casca do jogo: menu, descoberta LAN, sala e Aprenda — 09/10/2026

Papel Interface, ticket 10 (parte de lobby/HUD; a tela de RESULTADO continua
pendente, presa às fases da Sim).

**Navegação.** A tela inicial virou **Buscar partida · Área de treinamento ·
Aprenda · Sair**. O nome do Caçador continua no menu; a escolha de arma,
Elemento, Behemoth e variante SAIU do menu e foi para a sala — é lá que todo
mundo vê a escolha de todo mundo. `app.gd` virou a máquina de telas (menu →
busca → sala → Arena), com o Aprenda empilhado por cima e sabendo para onde
voltar. Telas em `src/game/`: `menu_screen`, `browse_screen`, `lobby_screen`,
`learn_screen`, `element_wheel`, mais `ui_kit.gd` (paleta e peças comuns, para
as telas não copiarem constante de cor).

**Descoberta na rede local.** Não existe matchmaking e não foi inventado um.
`src/net/lan_discovery.gd` (arquivo próprio, fora do NetGame): o Anfitrião
anuncia por UDP broadcast na porta **7778** uma vez por segundo — nome da sala,
Caçadores, Behemoth, variante e a porta do jogo — e quem busca escuta e lista.
Sala que para de anunciar some em 3,5 s. O pacote leva assinatura
(`magic`+`protocol`), então broadcast alheio não vira sala fantasma. O anúncio
vai para `255.255.255.255` **e** para `127.0.0.1`, porque o caso mais comum de
teste é Anfitrião e Cliente na mesma máquina; como o mesmo anúncio chega pelos
dois caminhos, cada sala carrega uma `session` sorteada e a lista prefere o
endereço roteável ao loopback — sem isso a mesma sala aparecia duas vezes.
**A entrada manual por endereço continua sempre visível**: o broadcast não sai
da rede local, e jogar com alguém de fora dela é exatamente o caso em que
digitar o endereço é a única saída. Quem anuncia é a TELA da sala, não o
NetGame — sair da sala cala o anúncio, e por isso sala em Caçada não aparece
na busca (não há entrada no meio da partida).

**Sala (fase LOBBY).** `NetGame` ganhou `Phase {IDLE, LOBBY, HUNT}`,
`host_lobby()`, `join_lobby()`, `set_loadout()`, `set_ready()`,
`set_hunt_settings()`, `everyone_ready()`, `lobby_entries()` e `start_hunt()`.
Decisão: **a Sim NÃO nasce na sala** — ela é criada só em `start_hunt()`, com
todo mundo que está na lista. Abrir a Sim junto com a porta faria o Behemoth
matar gente durante a escolha de arma. A lista da sala vive no NetGame
(`_lobby`), que é estado de ANTES da Caçada; replica por RPC confiável
(`_announce_lobby`/`_push_lobby`/`_begin_hunt`). `host()` antigo continua
existindo e começa a caçar na hora: é o caminho curto de `tools/screenshot.gd`
e `tools/netcheck.gd`. Corrigido de passagem: os sinais do `multiplayer` eram
religados a cada hospedagem (desconexão chegava em dobro) — agora passam por
`_wire_peer_signals()`.
A sala mostra nome, arma e Elemento de cada um, Pronto por Caçador, Behemoth e
variante só para o Anfitrião, e a **dica de Oposição** lida de
`Elements.strong_against` — com ✔ no Caçador que escolheu o Elemento certo e ✘
em quem escolheu o Elemento do próprio Behemoth.

**TODO(fase) — o que o Gerente precisa ligar quando a Sim tiver as fases:**
1. `net_game.gd`, enum `Phase`: virar espelho do da Sim; `_lobby` passa a ler
   o estado replicado em vez de guardar o próprio.
2. `net_game.gd::set_ready()`: virar pedido à Sim; o "pronto" volta pelo
   Instantâneo da fase LOBBY.
3. `net_game.gd::start_hunt()`: trocar o corpo por `sim.start_hunt()`; a
   Apresentação continua chamando a mesma função.
4. `app.gd::_on_leave_requested()`: sair da Arena deve cair na tela de
   RESULTADO e dali VOLTAR para a sala (encadear Caçadas sem reabrir a porta).
   Hoje sair encerra a sessão.
5. `hud_3d.gd::_interrupt_notice()`: quando o Instantâneo trouxer
   `interrupt_window`, ele manda e a dedução local sai.

**Aprenda.** Seção navegável por teclado e mouse, aberta do menu e da sala.
REGRA do arquivo: **nenhum número é escrito à mão** — toda página é montada a
partir de `Weapons`, `Elements`, `Behemoths` e `SimConfig` no momento em que
abre. Ajuda com número copiado vira mentira na primeira rebalanceada.
- **Armas** (uma página por arma, as 6): tipo de dano com o que ele é bom
  contra e quanto rende de Atordoamento; medidor próprio DEDUZIDO do grafo
  (os efeitos `brio+1`/`ammo-1` e os predicados `ammo>=1` dizem que recurso a
  arma usa) mais Ferimento por tipo de dano e carga por bandeira `chargeable`;
  Especial renderizado campo a campo do dicionário de dados; e a **árvore de
  combo de verdade**, lida de `Weapons.combo_graph()` — a MESMA estrutura que
  a Sim percorre. Mostra as entradas por contexto (parado/corrida/pós-esquiva)
  com os predicados em português, as sequências de botões legíveis
  (`L → L → P : Corte Horizontal → …`, com teto POR ENTRADA para o caminho que
  exige Brio não esconder o L-L-L), e cada nó com fases, números e para onde
  continua. Arma sem grafo declarado cai no grafo linear que a própria
  `Weapons` compila, então a tela não tem caminho especial para arma nenhuma;
  arma sem árvore (Repetidoras) diz isso e lista as ações soltas.
- **Elementos**: a roda de Oposição DESENHADA (`element_wheel.gd`), com cada
  par em pontas diametrais e o Neutro no centro sem ligação, mais a tabela de
  Aflição por Elemento e o efeito prático de cada uma com os números do
  SimConfig.
- **Behemoths** (uma página por Behemoth): Vida/raio/limiar/Fúria, Partes com
  o que muda ao quebrar (dano ×, fração do medidor, ataque que some, placa que
  vaza, penalidade de quebra), e os ataques com a FORMA da área em palavras
  (cone de X cm com abertura Y°, corredor A×B, círculo) — e, destacado em
  verde, **quais dão para INTERROMPER**, com a janela e o limiar lidos do
  campo `interruptible`. Pedido explícito do usuário: interrupção se ensina,
  não se descobre por acidente.
- **Básico**: controles, Fôlego, Esquiva com Invulnerabilidade,
  Comprometimento, Atordoamento/Partes, Interrupção e Abatido.

**HUD.** Aviso **JANELA DE INTERRUPÇÃO** em verde pulsante no alto da tela,
com o nome do ataque e o impacto mínimo. É o que fecha o ciclo: o Aprenda
ensina quais ataques aceitam o boop, o HUD avisa na hora. Lê
`behemoth.interrupt_window` do Instantâneo quando o campo existir; enquanto
não existe, deduz do MESMO dado que a Sim usa (`interruptible` do ataque +
`state_time`), então o aviso nunca contradiz a regra.

**Ferramenta.** `tools/screenshot.gd` ganhou os modos `browse`, `lobby`,
`learn <n>` e `interrupt` — cada um leva o App até a tela pelo mesmo caminho
que os botões chamam, então a captura mostra a tela de verdade.

**Validação.** `--import` limpo. Capturas conferidas uma a uma em
`.scratch/hunt-3d/previews/ui_*.png` (menu, busca com sala achada pelo
broadcast, sala, Aprenda: básico, as 6 armas, Elementos, Gnasher, Bastião, e o
HUD com a janela de interrupção aberta). A suíte NÃO foi usada como aferição
deste trabalho: durante estas horas os papéis Mecânica/Combos e Modelos
mexeram em `src/sim/**`, `tests/**` e `tools/models/**` ao mesmo tempo, e a
suíte saiu de 160/0 para 273 testes com 10 falhas — todas em testes de combo,
vigor e clipes de Golpe daqueles papéis. Nenhum arquivo desta entrega é lido
por teste algum; nenhuma falha vem daqui.

### Grafo de combo, três armas novas, boop estendido e fases — 09/10/2026

Papel Mecânica. Entregues de uma vez os tickets 11, 12, 13 e 14, a extensão da
Interrupção e o estado de fase que o lobby pediu. Arquivos tocados:
`src/sim/**` e `tests/**` apenas.

**REBASE do plano (o MIGRACAO.md avisava, e tinha razão).** Os pacotes
`.scratch/hunt-3d/combos/` e `.scratch/hunt-3d/weapons/` foram escritos antes
de o contrato de combate aterrissar. O que mudou ao executar:

1. **`attack_index` NÃO virou id global de nó.** O MIGRACAO.md propunha o
   achatamento `light + heavy`, o que empurraria os índices dos pesados. Só
   que `src/game3d/hunter_view.gd` escolhe o clipe por
   `<arma>_<tipo>_<índice+1>` e `arena_3d.gd`/`tools/screenshot.gd` chamam
   `Weapons.move(arma, tipo, índice)` — e esses arquivos não são deste papel.
   Decisão: o nó é identificado por `(attack_kind, attack_index)`, com os nós
   NOVOS acrescentados no FIM da lista do próprio tipo. Os índices dos Golpes
   antigos não mudaram, a apresentação seguiu funcionando sem uma linha
   editada, e o int único que o Instantâneo precisa (`combo_from`) usa um
   achatamento `leves+pesados` só para si (`Weapons.flat_id`).
2. **`combo_next` → `combo_from`** como planejado, mas acompanhado de
   `combo_effect_used` (a recarga encaixada precisa de "uma por nó").
3. **O pacote 11–13 entrou JUNTO com o grafo, não antes.** Fazer as armas
   novas no formato antigo de listas e depois religá-las seria escrever duas
   vezes; elas nasceram com `entry`/`next` declarados. O adaptador que compila
   listas em grafo linear foi implementado assim mesmo (`Weapons.combo_graph`
   quando a arma não declara `entry`) e tem teste: é a rede de segurança da
   próxima arma.
4. **A interrupção do Bastião já existia** (Rolamento e Tremor ganharam janela
   na rodada do contrato). O que faltava era o CRITÉRIO escrito e o aviso para
   a apresentação — foi isso que entrou.
5. **Vocabulário do grafo em inglês** (`if`, `on_start`, `on_end`, `channel`,
   `near/far/back_dodge`), não em português como nas fichas: regra do
   CLAUDE.md (código em inglês). Os ids dos nós seguem os das fichas.

**Grafo de combo (ticket 14).** `combo_next` e o índice linear saíram. Cada
Golpe é um NÓ com `id` e arestas `next`; a arma declara `entry` por contexto
(`free`/`sprint`/`dodge`). Vocabulários FECHADOS, interpretados pela máquina:
entradas `light/heavy/light_hold/heavy_hold/reload`; predicados `brio>=n`,
`ammo>=n`, `ammo==0`, `pips>=n`, `mag>=n`, `near`, `far`, `back_dodge`,
`no_world`; efeitos `brio±n`, `ammo±1`, `ammo_all`, `pips_all`, `det+1`;
pontes `@hook`, `@charging`, `@tumble`. Crescer essa lista é decisão de
revisão, não de ficha de arma.

- Nós por arma: **Espada 13, Martelo 9, Lâminas 15, Machado 8, Lança 10,
  Repetidoras 0**. As fichas somavam 14 e 16 para Espada e Lâminas; as tabelas
  delas listam 13 e 15 (a conta da ficha contou um nó duas vezes). Grafo vazio
  é VÁLIDO e tem teste: as Repetidoras não têm árvore, e isso é fidelidade.
- **Desvio ≠ reset**: alternar leve/pesado deixou de reiniciar. `L,L,H` da
  Espada vai a `h1` (ou à Meia-Lua com Brio ≥ 3); `H,L,H` passa pelo nó de
  ligação `hl` e vai a `h2` (ou ao Eco). Mesma tecla, Golpes diferentes — o
  histórico é a POSIÇÃO no grafo, não uma lista guardada.
- Entradas por contexto: corrida e pós-esquiva têm nó próprio em todas as
  armas de combo. `sprint` sai de `velocity` (já replicada); `dodge` usa
  `dodge_window`, campo novo de um float.
- Pontes para estados CONGELAM a janela (ela só corre em FREE), então Gancho e
  Rajada encaixam no meio do combo sem resetar — a regra 5 do MODELO.md, com
  teste.
- Recurso novo: **Brio** da Espada (fechar a cadeia leve +1, a pesada +2;
  desvios custam 3; teto 6). O Especial "Valor" não mudou.
- Nós de PULSO (`pulse_every`) e de CANAL (`channel`): Giro Amplo, Eco
  Cravado, Roda Viva, Ceifa Contínua (acelera 8% por ciclo) e Broca. O
  primeiro pulso sai no CONTATO; o canal congela o relógio do Golpe enquanto o
  botão estiver seguro, drenando vigor por segundo (gasto real: reinicia a
  espera de regeneração).
- `lunge` por nó é a EXCEÇÃO declarada ao "Golpe não locomove", aplicada por
  fração do trecho — o deslocamento total é exatamente o declarado.

**Machado (ticket 11).** Carga por golpe no estado `AXE_CHARGE` (mira livre,
corpo preso, dreno de vigor), escala até ×1,6 em 1 s e satura; o medidor SÓ
enche com golpe carregado. Voo da Ruína: projétil de ida e volta que acerta uma
vez em cada perna, persegue o dono na volta, devolve Éter no catch e concede
pilha de **Determinação** se tiver conectado (máx 3, +15%/pilha, decaimento
12/9/6 s). Segundo toque no Especial com o machado no ar = recall. **Resolve**
(super-armadura) entrou: soltar a carga PERFEITA (85–100%) num vertical dá
`resolve_time` — o dano entra, a troca de estado e o tranco não.

**Lança de Guerra (ticket 12).** Perfuração acumula Ferimento na Parte (133% do
dano, antes do vazamento de armadura; limiar 300, decaimento 10/s). Conversão
Aetérica em quatro níveis pelos limiares 10/33/66/90% (não exige medidor
cheio); o segundo toque dispara o míssil, que passa pelo caminho de boop.

> **DECISÃO — modelo de Ferimento (pendência remetida ao papel Mecânica,
> decidida aqui):** vale o **modelo FIEL ao rework 1.6.0** (abr/2021). A Parte
> Ferida dura 15 s com éter vazando e **NÃO dá bônus de dano a ninguém**; quem
> EXPLORA a ferida (1000 de dano nela enquanto está aberta) ganha um buff
> **pessoal** de 15 s (+15% de dano). Campos:
> `wound/wounded/wound_time/wound_claim` nas Partes e `wound_buff_time` no
> Caçador.
> **Alternativa DESCARTADA:** o híbrido proposto em `weapons/pike.md` (Ferida
> multiplicando ×1,5 o dano de Parte e ×1,25 o dano à Vida, aproveitado pelo
> grupo inteiro). Motivo: a referência manda, e o híbrido transformava a Lança
> num multiplicador de grupo que a build de dezembro/2024 não tem. Se um dia o
> balanceamento pedir "a Lança fere, o grupo colhe", o lugar de mudar é
> `_apply_wound` na Sim, num ponto só. Há teste cobrando explicitamente que a
> Ferida NÃO multiplica dano.

**Repetidoras (ticket 13).** Tiro contínuo segurando o leve (pente 12, 5
tiros/s, não trava o movimento, corrida tem prioridade), queda de dano por
distância (360→900 até 40%), recarga empoderada por **PROXIMIDADE** (borda a
≤160 cm: 12 tiros a ×1,25; recarregar longe SOBRESCREVE com zero, nunca
acumula), `TUMBLE` (Rolinho lateral, com menos Invulnerabilidade que a Esquiva)
e Salva Explosiva (leque de 3 quando empoderada, sem consumir o
empoderamento). `DamageType.BALLISTIC` entrou no FIM do enum, com entrada
própria em `STAGGER_TYPE_MULT`.

**Enums e replicação (o aviso do REVIEW virou teste).** `AXE_CHARGE` e `TUMBLE`
entraram no FIM de `HunterState.State`; `BALLISTIC` no fim de `DamageType`.
`test_state_enum_is_append_only` congela os ints antigos. Todos os campos novos
entram simétricos em `to_dict`/`apply_dict`; `axe_out`, `det_stacks` e `ready`
entram também no `to_view_dict` (sem eles o remoto desenharia o machado na mão
junto com o projétil, não mostraria a aura, e o lobby não veria o "pronto" dos
outros). `kind` entra no Instantâneo de projéteis. `light_held` é contínuo e
sobrevive à fila seca, como `heavy_held` — há teste.

**Interrupção em todos os Behemoths.** Critério do Bastião escrito nos dados:
interrompível = ataque LENTO E COMPROMETIDO (Preparo ≥ 0,80 s ou que arranca o
corpo para a frente). Rolamento (0,90 + investida) e Tremor (0,85) sim;
Cabeçada (0,66) e Maçada (0,60) não — perto dele a resposta é a esquiva, senão
a arma de Impacto apagaria o repertório de curta distância dele. Limiar 110 (o
Gnasher é 90). Passam pelo caminho de boop: Rajada do Martelo, explosão do
Magma, **Salva das Repetidoras** (Atordoamento subido de 100 para 130 para
caber acima do limiar mais alto em jogo — escolha de coerência, não de fonte),
míssil da Lança, Onda de Brio, machado do Voo da Ruína e as balas. O
Instantâneo do Behemoth ganhou **`interrupt_window: bool`** e
`interrupt_threshold: float`, saídos da MESMA função que resolve o boop
(`BehemothState.is_interruptible_now()`), com teste varrendo o Preparo inteiro
para provar que aviso e boop nunca discordam. É o que o HUD e a tela "Aprenda"
consomem.

**Fases da Caçada (lobby).** `Sim.Phase {LOBBY, HUNT, RESULT}`, `ready` por
Caçador (no Instantâneo completo E no enxuto, e na `roster()`),
`start_hunt(tipo, elemento)` que só vale a partir do LOBBY, e RESULT com resumo
por Caçador: **dano causado, Partes quebradas e interrupções** (acumulados no
HunterState durante a Caçada). `payload["phase"]` sempre, `payload["result"]`
em RESULT, mais eventos `{"type": "phase"}`. **Compatibilidade mantida:**
`Sim.new(tipo, elemento)` continua entrando direto na Caçada; só quem passa o
terceiro parâmetro `start_in_lobby` nasce em LOBBY. `set_weapon` passou a zerar
a posição no grafo e os recursos da arma anterior. O que falta em
`src/net/net_game.gd` (arquivo de outro papel) está escrito com trecho pronto e
lugar exato em `.scratch/hunt-3d/NET-TODO.md` — inclusive o `light_held`, sem o
qual três mecânicas novas ficam mortas.

**Testes: 274, 0 falhas** no fecho desta entrega (eram 160); 114 testes novos
em seis suítes: `test_sim_combos.gd` (44), `test_sim_axe.gd` (16),
`test_sim_pike.gd` (14), `test_sim_repeaters.gd` (18),
`test_sim_interrupt.gd` (10) e `test_sim_phase.gd` (12). `--import` limpo.

> Com o papel Modelos fechando os `.glb` das três armas novas no mesmo
> intervalo, a suíte conjunta terminou em **279 testes, 0 falhas**.

**Testes REESCRITOS (nenhum enfraquecido; cada um com o porquê no próprio
arquivo):**

1. `test_a_heavy_attack_restarts_the_light_sequence` →
   `test_a_heavy_attack_diverts_the_chain_instead_of_restarting_it`. A regra
   "pesado reinicia os leves" DEIXOU DE EXISTIR — é o ponto do ticket 14. O
   reset continua testado pelo caminho honesto (perder a Janela de Combo).
2. `test_all_ordinary_weapon_strikes_are_stationary` →
   `test_strikes_move_only_by_declared_lunge`. Ficou MAIS específico: antes
   cobrava "todo Golpe é estacionário"; agora cobra "sem `lunge`, zero; com
   `lunge`, exatamente o valor declarado", e o eixo lateral segue em zero.
3. `test_light_combos_are_free_even_with_zero_stamina`. Antes cobrava "o combo
   leve passa por TODOS os Golpes da lista leve" — com o grafo, a lista também
   guarda nós de outros contextos, inalcançáveis martelando o leve. Agora
   compara com a cadeia que o GRAFO declara, nó a nó.
4. `test_light_spam_preserves_regeneration_and_its_delay`. O Machado saiu da
   varredura porque o leve dele é carregável e a carga drena vigor de propósito
   (exceção declarada no MEMORY, coberta em `test_sim_axe.gd`). As outras cinco
   armas continuam cobradas igual.
5. `test_attack_clips_last_exactly_what_the_sim_charges`. O contrato de
   fidelidade NÃO afrouxou: clipe que existe continua tendo que durar
   exatamente o Golpe, e nenhum dos clipes já gerados pode sumir. O que saiu
   foi a exigência de clipe para os nós NOVOS e as três armas novas, que estão
   na fila do papel Modelos.
6. `test_each_weapon_plays_its_own_attack_clips`. Mesma lógica: clipe próprio
   existindo, é ele que toca; não existindo, o fallback tem de ser um clipe que
   EXISTE — nunca um nome inexistente.

**Pendências registradas.**

- **Modelos**: faltam clipes para os nós novos e para as três armas
  (`sword_light_4..7`, `sword_heavy_4..6`, `hammer_light_4`,
  `hammer_heavy_4..6`, `blades_light_5..8`, `blades_heavy_3..8`, e os jogos
  `axe_*`, `pike_*`, `repeaters_*`), e para os estados `AXE_CHARGE` e
  `TUMBLE`. Até lá caem no fallback declarado da HunterView.
- **Rede/lobby**: `.scratch/hunt-3d/NET-TODO.md`.
- **HUD**: Brio (pips), pilhas de Determinação, pente + marcador de
  empoderado, nível da munição convertida, indicador de Ferida nas barras de
  Parte.
- **Números**: TODOS os valores novos são provisórios, calibrados por coerência
  com as armas existentes. Sem telemetria da build de dez/2024. Em particular:
  escala e janela perfeita da carga, durações da Determinação,
  limiar/decaimento/cota do Ferimento, alcance de empoderamento, i-frames do
  Rolinho, e o Atordoamento da Salva.
- **Carga móvel do Machado** (andar a 30% carregando o leve) e a 5ª estocada da
  Lança continuam fora, como as fichas previam.
- A entrada anterior do papel de Interface menciona "273 testes com 10 falhas":
  eram as falhas intermediárias DESTA entrega, todas corrigidas antes do fim.
  Estado final: 274 testes, 0 falhas.

### Corpos do Bastião e da Faiscaia, armas novas e cor certa — 09/10/2026

Papel Modelos/Animações. Detalhe de pipeline em `.scratch/hunt-3d/ANIMACAO.md`.

**A correção que muda TODOS os modelos: cor.** `common._hex_to_rgba` dividia o
hex por 255 e entregava o valor sRGB como se fosse linear. Resultado: todo
material saía cerca de duas vezes mais claro e menos saturado do que o hex
escolhido — era por isso que as criaturas chegavam esbranquiçadas nas capturas
e por que "escurecer o material" não resolvia (a conta errada clareava de
novo). Agora a conversão é a do padrão sRGB. Nenhuma cor mudou de código;
todas mudaram de APARÊNCIA, e passam a ser a cor que o hex sempre disse. O
quadrúpede, por exemplo, deixou de ser verde-pastel e virou o verde saturado
da ficha. **Regerar e reconferir capturas é parte de qualquer mexida em
paleta daqui para a frente.**

**Bastião (`tools/models/bastiao.py` → `assets/models/bastiao.glb`).** ~978
tris, 36 malhas, 9 clipes. Ele deixou de usar o corpo emprestado do
quadrúpede. Tatu-pangolim baixo e largo: domo inteiriço com quilha e borda
escura, faixa de musgo na fresta, patas-pilar, cauda-maça em bloco chanfrado.
Rig `root ─ spine ─ neck ─ head ─ jaw`, `tail_a ─ tail_b`, quatro patas
`leg ─ paw`; pose em `space="world"`.

- **Contrato de Partes com a apresentação** (o mesmo da cauda do quadrúpede,
  estendido): a Crista é a malha `crest`, a Carapaça é `shell`, a Cauda-maça é
  `tail`; sob as duas placas moram `raw_head` e `raw_shell`, a carne laranja,
  que NASCEM ESCONDIDAS e aparecem na quebra. Quebrar deixou de ser "a peça
  some" e virou TROCA DE CAMADA: de longe se vê qual setor já está aberto, que
  é o ponto da luta dele.
- **Clipes com o id exato do ataque** e a duração exata de `behemoths.gd`:
  `headbutt` 1,52 s · `roll` 2,30 s · `mace` 1,55 s · `quake` 1,95 s, mais
  `idle`, `walk` (1,15 s — 20% mais lento que o do Gnasher, como o
  `move_speed` dele), `roar`, `stagger_fall` (4,5 s) e `death`.
- O Rolamento é duas voltas inteiras de verdade (720° em `ry`), com as patas
  recolhidas e a cauda enrolada por cima; a Maçada sobe a maça acima do domo e
  desce varrendo para trás; o Tremor empina e desaba com quique; a queda do
  Atordoamento o deixa de BARRIGA PARA CIMA (74°), que é o castigo próprio de
  um bicho cujo dorso é parede.

**Faiscaia (`tools/models/faiscaia.py` → `assets/models/faiscaia.glb`).** ~864
tris, 39 malhas, 11 clipes. A ficha 05 virou corpo antes de virar código: ela
**ainda não existe em `src/sim/behemoths.gd`**. Seis segmentos chatos de
quartzo, placas dorsais, cinco pares de fileiras de perninhas que ondulam em
fase, cabeça com tenazes e duas antenas, ferrão em gancho duplo. Rig com a
RAIZ NO SEGMENTO DO MEIO e duas cadeias saindo dela — é o que deixa empinar só
a frente (Descarga, Látego) sem levantar a cauda junto.

- **Núcleo Errante**: uma malha por estação — `core_tail`, `core_back_a`,
  `core_back_b`, `core_head` —, em material emissivo. A `CreatureView` mostra
  SÓ a estação da vez, pulsando a 1 Hz (2 Hz em Fúria, como a ficha pede), lida
  de um campo `core_station` do Instantâneo que a Sim ainda não manda (vale 0 =
  Ferrão até lá). `common.material` ganhou `emission`/`emission_strength` para
  isso.
- Partes decepáveis/quebráveis como malhas nomeadas: `antenna_r`/`antenna_l`,
  `stinger`, `plates`, e `raw_plates` (o quartzo fosco e rachado por baixo).
- **Clipes com os ids de ataque da ficha**: `pince` 1,22 · `whip` 1,43 ·
  `serpentine` 2,08 · `coil` 2,12 · `static_lash` 1,50 · `discharge` 3,70 s,
  mais `idle`, `walk` (0,75 s), `roar`, `stagger_fall`, `death`. A Descarga
  Plena é o clipe mais importante: 2 s empinada como cobra, com DUAS sacudidas
  no alto — o tremor é o relógio que o grupo lê para decidir quem dá o boop.

**Armas.** Três novas, no estilo das três existentes (punho na origem, arma
para +Z, sem rig): `weapon_axe` (~136 tris, crescente gordo de um lado e
contrapeso do outro), `weapon_pike` (~148 tris, haste fina com câmara aetérica
à vista acima da mão — a Conversão é o que a distingue de uma lança qualquer)
e `weapon_repeaters` (~130 tris, UMA pistola de tambor que a `HunterView`
instancia nas duas mãos). **A pendência de escala do ANIMACAO.md foi
resolvida**: espada 1,20 m → 0,95 m e lâmina mais fina, martelo 1,25 m →
0,95 m com cabeça de 46 cm (era 62), lâminas encolhidas junto. Nas capturas
dos Golpes o corpo do Caçador volta a aparecer por trás do arco.

**Apresentação.** `creature_view.gd` registra os três .glb por tipo
(`gnasher`/`bastion`/`faiscaia`), troca o `_update_tail` por um `_update_parts`
genérico guiado por uma tabela `PARTS` (papel `sever` = some ao decepar; papel
`plate`+`raw` = troca de camada ao quebrar), acende o núcleo por estação e
passou a saber o nome do material de couro de cada criatura.
`hunter_view.gd` registra as três armas novas e ganhou `DUAL_WIELD`
(Lâminas + Repetidoras) no lugar do `if weapon_id == "blades"`.
`tools/preview_model.gd` aceita uma lista de malhas a ESCONDER, que é como se
confere a cara de uma Parte quebrada sem abrir o jogo.

**Validação.** `build_all.ps1` verde (11 modelos), `--import` limpo,
**279 testes, 0 falhas**. Testes novos em `tests/test_assets.gd`: duração de
cada ataque do Bastião contra `behemoths.gd` (quebra de propósito se a
Mecânica mudar os tempos — a correção é REGERAR o modelo), duração de cada
ataque da Faiscaia contra a tabela da ficha, existência das malhas nomeadas
das Partes, troca placa↔carne do Bastião pela `CreatureView` e uma estação de
núcleo acesa por vez. Capturas em `.scratch/hunt-3d/previews/`:
`bastiao_*.png`, `faiscaia_*.png` (uma tira por clipe), `bastiao_broken.png` e
`faiscaia_broken.png` (Partes quebradas), `weapon_axe/pike/repeaters.png` e
`hunter_grip_<arma>.png` (as seis armas na mão, no mesmo Golpe, para comparar
escala).

**Pendências.**

- **Clipes do Caçador para as armas novas.** Enquanto este modelo era feito, a
  Mecânica implementou Machado, Lança e Repetidoras na Sim: faltam os jogos
  `axe_*` (8 Golpes) e `pike_*` (10 Golpes) — Repetidoras não precisam (tiro e
  Rolinho não são Golpes) — mais os nós novos do grafo de combo e os estados
  `AXE_CHARGE`/`TUMBLE`. Até lá tudo cai no fallback declarado da HunterView.
- `arena_3d.gd` ainda diz em comentário que "o Bastião não tem modelo próprio"
  (arquivo de outro papel nesta rodada; o código já funciona, só o comentário
  está velho).
- Faiscaia sem tipo na Sim: os ids/durações dos clipes vêm da ficha. Quando a
  Mecânica criar o tipo, trocar `FAISCAIA_ATTACKS` do teste por
  `Behemoths.attacks("faiscaia")`.
- Segue sem blend entre clipes, sem IK de pé/pata e sem animação de Ferimento,
  quebra ou interrupção. Nada aqui foi calibrado contra vídeo ou telemetria da
  build de dez/2024.
