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
