# Animação — diagnóstico e reconstrução (09/10/2026)

Papel ANIMAÇÕES. Alvo: as animações precisam *parecer* o jogo de referência
pré-Awakening (build até 04/12/2024) — peso, tempo, antecipação e recuperação
que casam com os números da Sim e comunicam o Comprometimento. Nada de asset
de terceiros: só comportamento estudado e reproduzido com código da casa.

---

## 1. Diagnóstico do estado anterior

### 1.1 O teto do pipeline era "boneco de armar"

`tools/models/common.py` oferecia três coisas: malhas primitivas, um rig de
ossos e `animation(rig, nome, segundos, poses)`. Toda peça era presa a UM osso
com peso 1 (`attach`) e toda chave era `(tempo, rotação, translação)`. Faltava
tudo o que faz uma pose virar movimento:

| Faltava | Consequência no jogo |
| --- | --- |
| Interpolação por chave | O Blender interpolava TUDO em Bézier automático: o preparo entrava macio e o impacto saía macio. Um Ativo de 0,08 s amolecido nas duas pontas não lê como impacto — lê como gesto. |
| Articulações | Coluna de UM osso (`chest`), sem pescoço, sem mão esquerda, sem pé. O corpo só podia girar em bloco. |
| Movimento secundário | Nenhum. Cachecol e cauda eram peças rígidas; o golpe parava no mesmo quadro em todas as partes do corpo. |
| Deslocamento de raiz | Tecnicamente possível (translação do osso raiz), mas em espaço LOCAL do osso, com eixos diferentes por osso. Quase não era usado. |
| Eixos legíveis | A pose era escrita no espaço de cada osso. O comentário no topo de `hunter._animate` ("X = lado", "Z = inclinar frente") valia para os ossos verticais e era FALSO para os que apontam para baixo. |

### 1.2 O sintoma: a locomoção fugiu para a apresentação

A consequência mais cara do item "eixos" está registrada no MEMORY.md:
`hunter_view.gd` passou a **reconstruir caminhada e corrida por código**
(`_build_locomotion`), porque o balanço em X do clipe gerado "abria as pernas
para os lados". Isto é dívida de duas maneiras:

1. A regra de ouro do projeto é *asset é código*: o `.glb` nasce de
   `tools/models/*.py`. Uma animação fabricada em GDScript não é regerável,
   não é inspecionável pelo preview e não aparece no teste de assets.
2. O remendo escondia o defeito em vez de corrigi-lo: o gerador continuava
   produzindo `walk`/`sprint` ruins, que ninguém mais olhava.

### 1.3 O sintoma: um jogo de Golpes para três armas

Só existia `light_1..3` + `heavy`, tirados dos tempos da ESPADA. Martelo e
Lâminas tocavam esses mesmos clipes:

- O Martelo (preparo 0,22–0,30 s) usava um clipe desenhado para 0,12 s.
- As Lâminas (0,27 s de Golpe inteiro) usavam um clipe de 0,42 s.
- `_attack_clip_time` em `hunter_view.gd` existia só para esticar/encolher as
  três fases do clipe da espada até caberem no Golpe de outra arma. Funcionava
  como relógio e falhava como leitura: o corpo fazia o gesto errado no tempo
  certo.
- O quarto leve das Lâminas e os pesados 2/3 caíam num `animation` escrito à
  mão nos DADOS da Sim (`"animation": "light_2"`), misturando apresentação com
  conteúdo.
- `SPECIAL_SPIN` e `RELOADING` não tinham clipe nenhum (apontado na
  `REVIEW.md`): o Caçador recarregava e dançava **parado em repouso**.

### 1.4 Diagnóstico em três linhas

1. O pipeline só sabia prender peça em osso e interpolar reto, então nenhuma
   animação tinha antecipação, estalo de impacto nem arrasto — era mímica no
   tempo certo, não peso.
2. Como a pose era escrita no eixo de cada osso, a caminhada saiu errada e foi
   refeita por código na apresentação, tirando do asset o trabalho do asset.
3. Havia UM jogo de Golpes (o da espada) servindo as três armas por esticão de
   relógio, e dois estados de arma (recarga e Dança) sem animação alguma.

---

## 2. O que subiu no pipeline (`tools/models/common.py`)

Tudo documentado em PT no docstring de cada função. Resumo:

### 2.1 Easing por chave

O 4º campo de uma chave escolhe a curva de SAÍDA daquela chave. Tabela
`EASING`, em vocabulário de animação, não de Blender:

| Nome | Para quê |
| --- | --- |
| `auto` | Bézier suave — o comportamento antigo, que continua sendo o padrão |
| `linear` | Velocidade constante (giros, esteiras) |
| `hold` | Degrau: a pose troca de uma vez |
| `wind` / `accel` | Antecipação: sai quase parado e acelera (preparo curto / longo) |
| `snap` / `hit` | Impacto: parte no talo e trava (leve / pesado) |
| `settle` | Chega desacelerando (fim de recuperação) |
| `ease` | Macio dos dois lados, com mais miolo que `auto` |
| `anticip` / `overshoot` | Recua antes de ir / passa do ponto e volta |
| `bounce` | Quica até parar (corpo pesado no chão) |

O exportador glTF amostra as curvas quadro a quadro (`export_force_sampling`),
então a forma chega inteira na Godot mesmo o glTF só sabendo de chave linear.

### 2.2 Pose em eixos do mundo (`space="world"`)

Rotação E translação passam a poder ser escritas nos MESMOS eixos para todo
osso, com o personagem olhando para +X: `rx` rola para a esquerda, `ry`
inclina a ponta do osso para a frente, `rz` gira para a esquerda; translação
em metros de mundo. A conversão é `R_osso = M⁻¹ · R_mundo · M` com a matriz de
repouso do osso, encadeando o euler anterior para giros de volta inteira não
voltarem a zero.

É isto que mata a classe de bug que empurrou a locomoção para a apresentação.
Modelos antigos não mudam: o padrão continua `space="bone"`.

### 2.3 Mais ossos e hierarquia mais funda

- `chain(nomes, pontos, pai)` declara uma corrente de ossos ligados ponta a
  ponta em uma linha — subdividir uma articulação virou acrescentar um nome.
- `attach_gradient(malha, rig, segmentos, eixo, mistura)` reparte UMA malha
  entre VÁRIOS ossos por posição, com transição suave. Foi o que permitiu a
  cauda do quadrúpede chicotear continuando a ser uma malha só chamada `tail`
  (a Godot a esconde pelo nome ao decepar a Parte).

### 2.4 Movimento secundário barato

- `settle(pico, pose, fim, repouso, amount, at)` — duas chaves que passam do
  ponto e assentam. Usada no fim de todo Golpe.
- `follow(chaves, atraso, damping, limite)` — cópia atrasada e amortecida das
  chaves de outro osso. Com `damping` **negativo** vira o arrasto de um osso
  FILHO (cachecol no peito, ponta da cauda na base), que já herda o giro do
  pai e só precisa ficar para trás.

### 2.5 Ciclos e deslocamento de raiz

- `cycle(duração, amplitude, bias, phase, samples, rectify, harmonic, loc_*)`
  amostra uma senoide. `rectify` dá o joelho que só dobra na fase de balanço;
  `harmonic=2` dá a raiz que sobe e desce uma vez por passada.
- Deslocamento de raiz dentro do clipe é só uma translação em `space="world"`:
  a passada que pisa, a investida que avança o corpo, o salto do pisão.

### 2.6 Quadro-base 60 fps e tempo zero no quadro zero

`FPS` passou de 30 para **60**, igual ao passo fixo da Sim. E o tempo zero
passou a ser o quadro ZERO (era o quadro 1): o exportador glTF conta a duração
a partir do quadro 0, então começar no 1 somava um quadro a todo clipe — um
Golpe de 0,43 s chegava à Godot com 0,45 s. Com as duas correções, a diferença
entre a duração do clipe e o número da Sim fica abaixo de 8 ms, e isso virou
teste.

---

## 3. Caçador — animações entregues

Rig novo: `root ─ spine_01 ─ spine_02 ─ chest ─ neck ─ head`, `scarf` como
osso próprio no peito, braços com `upper_arm ─ forearm ─ hand` dos dois lados
e pernas com `thigh ─ shin ─ foot`. As malhas ganharam prefixo `m_` para não
disputarem nome com os ossos no glTF — era o que renomeava `hand_r` para
`hand_r_2` na importação e deixava as armas invisíveis (correção de 09/10).
Como `hand_l` agora existe, a lâmina esquerda deixou de ser pendurada na ponta
do antebraço.

**28 clipes.** Um por Golpe de cada arma, com os tempos exatos de
`src/sim/weapons.gd`:

| Arma | Clipes | Preparo / Ativo / Recuperação |
| --- | --- | --- |
| Espada | `sword_light_1..3` | 0,12/0,08/0,22 · 0,11/0,08/0,24 · 0,16/0,14/0,36 |
| Espada | `sword_heavy_1..3` | 0,32/0,10/0,42 · 0,28/0,10/0,38 · 0,36/0,14/0,46 |
| Martelo | `hammer_light_1..3` | 0,22/0,10/0,34 · 0,20/0,10/0,38 · 0,30/0,12/0,52 |
| Martelo | `hammer_heavy_1..3` | 0,10/0,10/0,45 · 0,18/0,10/0,34 · 0,30/0,15/0,70 |
| Lâminas | `blades_light_1..4` | 0,08/0,06/0,14 · 0,07/0,06/0,14 · 0,09/0,07/0,16 · 0,12/0,10/0,26 |
| Lâminas | `blades_heavy_2` | 0,14/0,10/0,30 |

`blades_heavy_1` **não existe de propósito**: o índice 0 do pesado das Lâminas
é o Gancho, que não é um Golpe — vira o estado `HOOK_PULL` e usa o clipe
`hook`.

Estados: `idle`, `walk` (0,86 s), `sprint` (0,58 s), `dodge` (0,34 s =
DODGE_DURATION + DODGE_RECOVERY), `hurt` (0,28 s), `downed`, `revive`,
`charge` (armar a Rajada, laço), `reload` (1,60 s = RELOAD_TIME),
`special_spin` (2,50 s = duração da Dança da Ceifadora) e `hook` (laço).

Detalhes de fidelidade que valem registro:

- **A batida da recarga cai dentro da janela do tiro certo.** `RELOAD_QUICK_START`
  é 0,50 s e `RELOAD_QUICK_END` é 0,80 s; a munição entra no cano em 0,65 s.
  O ritmo da recarga rápida passa a ser lido no CORPO, não só na barra do HUD.
- **O rolamento virou mergulho para a frente** e a `HunterView` gira o corpo
  para a direção da esquiva (`dodge_dir`), que antes era ignorada.
- **Pose de prontidão comum (`GUARD`)**: todo Golpe começa e termina nela, para
  trocar de clipe no meio de um combo não dar estalo de braço.
- **Os ângulos da coluna se somam.** Um `_torso(pitch, yaw)` reparte o ângulo
  TOTAL do peito pelos quatro ossos e devolve parte dele no pescoço, para o
  olhar não varrer o chão quando o corpo mergulha. Escrever "30" em cada osso
  dobrava o Caçador ao meio — aconteceu, está nos primeiros previews.

---

## 4. Quadrúpede — animações entregues

Rig novo: `root ─ spine ─ neck ─ head ─ jaw`, `tail_a ─ tail_b` e cada pata
com `leg_xx ─ paw_xx`. Os ossos da cauda NÃO se chamam `tail` para não
disputarem o nome com a malha que a Godot esconde ao decepar.

Durações espelhadas de `src/sim/behemoths.gd` (Gnasher):

| Clipe | Preparo / Ativo / Recuperação | O que o corpo faz |
| --- | --- | --- |
| `bite` | 0,62 / 0,16 / 0,62 | Cabeça SOBE e RECUA com a goela à mostra, patas dianteiras freando; o bote desce e a mandíbula fecha no quadro de contato |
| `charge` | 0,82 / 0,42 / 0,85 | Agacha e recua 0,30 m, dispara 0,55 m à frente em flecha, derrapa sacudindo a cabeça |
| `tail` | 0,52 / 0,20 / 0,70 | Corpo torce para um lado e a cauda enrola; desenrola ao contrário, com a ponta atrasada em relação à base (estalo de chicote) |
| `stomp` | 0,70 / 0,18 / 0,75 | Empina nas traseiras com as dianteiras no alto; desaba com curva `hit` e quica |
| `roar` | 2,00 | Cabeça ao alto, goela escancarada, corpo tremendo |
| `stagger_fall` | 4,50 (STAGGER_DOWN_DURATION) | Tomba de lado de verdade (rolando ~62°), se debate duas vezes e se levanta |
| `death` | 2,00 | As patas cedem, o corpo desaba e congela na última pose |
| `idle` / `walk` | 2,00 / 0,90 | Respiração pesada · andadura diagonal (dianteira direita com traseira esquerda), com pata dobrando só no balanço |

A cauda é gerada como arrasto defasado do corpo (`follow` com damping
negativo) em TODOS os clipes menos a Rabada — ali ela é o golpe, não a
consequência.

**Não toquei em `src/sim/`.** As durações acima foram copiadas do estado atual
de `behemoths.gd`; outro papel está reconstruindo a IA/padrões do Gnasher. Se
os nomes ou tempos mudarem, o teste
`test_behemoth_clips_last_exactly_what_the_sim_charges` quebra de propósito —
a correção é **regerar o modelo** (`tools/models/build_all.ps1`), não afrouxar
o teste.

---

## 5. Apresentação (`src/game3d/hunter_view.gd`)

- **`_build_locomotion` REMOVIDA.** Caminhada e corrida voltaram a ser o clipe
  gerado. A `HunterView` não fabrica mais animação nenhuma, e o docstring da
  classe registra por quê, para o remendo não voltar.
- **`_attack_clip_time` REMOVIDA.** Como o clipe tem a duração exata do Golpe,
  fase por fase, o tempo do estado É o tempo do clipe.
- **Clipe por arma**: `<arma>_<leve|pesado>_<índice+1>`, com queda para o jogo
  da espada e, em último caso, `sword_light_1` — nunca para um nome
  inexistente. O campo `animation` dos dados de Golpe virou legado e não é
  mais lido (não foi removido: mora em `src/sim/`, que é de outro papel).
- **Estados novos**: `RELOADING` → `reload`, `SPECIAL_SPIN` → `special_spin`,
  `HOOK_PULL` → `hook` (antes tocava `dodge`), `CHARGING` → `charge`.
- **Lâmina esquerda em `hand_l`**, com o mesmo encaixe da direita.

---

## 6. Referência pública consultada

Estudo de COMPORTAMENTO (ritmo, ordem dos golpes, telegrafia). Nenhum arquivo,
animação ou asset de terceiros foi aberto, extraído ou incorporado.

- [Nigh7mare's Comprehensive New Player Guide to Dauntless](https://docs.google.com/document/d/1nUWSdxu5IsyIptd1IVLNQus5yADUgI3dyohYx0bI8PQ/mobilebasic)
  — guia comunitário anterior a Awakening. Descreve por arma:
  - **Espada**: combos "Quad Cross" (4 leves, rápidos, sem custo de vigor),
    "Rising Elements" (3 pesados, mais lentos e pesados) e o giro
    "Ardent Cyclone" com remate por cima. Foi a base para alternar o lado do
    arco nos leves e para o Giro Cortante dar volta inteira.
  - **Martelo**: "todo combo tem 3 golpes seguidos de um aetherslam";
    balanços horizontais largos parados, verticais andando para a frente;
    munição de 4 e recarga com batida no tempo; Rajada Concussiva como cone
    à frente "excelente para interromper". Virou: dois arcos horizontais, uma
    esmagada vertical, a Rajada saindo da pose de carga com coice, e o
    Estouro como pulo-e-queda com recuperação longa.
  - **Lâminas**: "Bladed Edge" (5 leves, alcance curtíssimo, a melhor geração
    de medidor), ataque giratório, e o Chain Pull como parte básica do
    moveset. Virou: três talhos curtos alternando o lado, o Redemoinho de
    volta inteira e um clipe de Gancho próprio.
  - **Gnasher**: "telegrafias longas e fáceis de ler"; o bote é anunciado com
    a cabeça puxada para trás; a cauda é o golpe que mais dói.
- [Busca sobre o moveset do Gnasher (wiki comunitária, resumo)](https://dauntless.fandom.com/wiki/Gnasher)
  — mordida frontal muito telegrafada (cabeça recua antes), pisão que derruba,
  rabada ampla, investida anunciada por um pulinho antes do arranque.
- [Refresh oficial das Chain Blades](https://playdauntless.com/news/chain-blades-refresh/)
  (página fora do ar no momento da consulta, HTTP 522; o conteúdo chegou pelo
  resumo de busca) — confirma os nomes dos combos e que o Chain Pull saiu do
  Especial para o moveset básico.
- [Guia de armas e tipos de dano](https://www.gameskinny.com/tips/slashing-piercing-or-blunt-a-dauntless-weapons-guide/)
  e [visão geral de armas](https://dauntless-archive.fandom.com/wiki/Weapons)
  — martelo como a arma mais lenta e de maior impacto, lâminas como a mais
  rápida e de menor alcance. É a razão de os preparos e as recuperações serem
  tão diferentes entre os três jogos de clipes.

**Limite honesto destas fontes**: são guias e relatos de jogadores, não
telemetria nem especificação oficial. Eles dão a ORDEM e o CARÁTER dos golpes;
os segundos exatos continuam vindo de `src/sim/weapons.gd` e
`src/sim/behemoths.gd`, que por sua vez ainda são valores provisórios do
projeto. Nenhum número desta leva pode ser apresentado como "fiel medido".

---

## 7. Validação

- `powershell -File tools/models/build_all.ps1` — verde, 6 modelos exportados.
- `godot --headless --path . --import` — sem erro.
- `godot --headless --script res://tests/run_tests.gd` — **160 testes, 0 falhas**
  (eram 136). Quatro testes novos:
  - duração de cada clipe de Golpe = duração do Golpe na Sim (tolerância de um
    quadro de 60 Hz);
  - o mesmo para os ataques do Gnasher;
  - cada arma toca o clipe do PRÓPRIO Golpe;
  - recarga, Dança da Ceifadora, Gancho e carga têm animação própria.
- Capturas em `.scratch/hunt-3d/previews/` — uma tira por animação
  (`hunter_*.png` e `quad_*.png`), cada uma com o clipe congelado no começo,
  no fim do Preparo, no quadro de contato, no meio da recuperação e no fim,
  com a arma da vez na mão. Reproduzir com:

      godot --path . --rendering-method gl_compatibility \
        --script res://tools/preview_model.gd -- \
        res://assets/models/hunter.glb saida.png sword_heavy_1 side \
        0,0.32,0.42,0.60,0.84 res://assets/models/weapon_sword.glb

  (`tools/preview_model.gd` ganhou: lista de tempos virando TIRA lado a lado,
  arma opcional na mão e enquadramento mais apertado.)

---

## 8. O que continua provisório

1. **Os segundos.** Os clipes casam com a Sim, e a Sim ainda é provisória. Nada
   aqui foi calibrado contra vídeo ou telemetria da build de dezembro de 2024.
2. **Combos mistos.** A Sim ainda reinicia a sequência ao alternar leve/pesado;
   os clipes acompanham essa limitação. O "Repeating Elements" da espada
   (2 pesados → leves) e os combos que mudam com a direção do movimento no
   Martelo não existem nem lá nem aqui.
3. **Sem blend entre clipes.** A `HunterView` troca de animação no corte
   (`play` sem `blend`). A pose `GUARD` comum disfarça, mas transição de
   verdade (AnimationTree/StateMachine) é trabalho futuro.
4. **Bastião ainda sem clipes próprios.** Ele usa o corpo do quadrúpede como
   provisório e seus quatro ataques (`headbutt`, `roll`, `mace`, `quake`) não
   têm animação; a `CreatureView` mantém a anterior nesse caso. Não os criei
   porque o modelo dele deve mudar e `src/sim/` está em obra por outro papel.
5. **Escala das armas.** O martelo e a espada são grandes a ponto de tapar a
   silhueta em alguns arcos (visível nos previews). É o modelo da arma, não a
   animação; fica anotado para a próxima passada de `weapon_*.py`.
6. **Sem animação de ferimento parcial, de quebra de Parte ou de interrupção
   (boop)** — esses estados ainda não existem na apresentação.
7. **Pé e mão não têm IK.** Em terreno plano e com câmera afastada não aparece;
   numa arena com desnível apareceria.

---

## 9. Segunda leva — Bastião, Faiscaia, armas novas (09/10/2026)

Esta leva fecha dois itens do "o que continua provisório" acima: o **4**
(Bastião sem clipes próprios) e o **5** (escala das armas).

### 9.1 A cor estava errada no pipeline inteiro

`common._hex_to_rgba` entregava o valor **sRGB** do hex como se fosse
**linear**. Todo material saía ~2× mais claro e menos saturado do que o hex
pedia — e tentar compensar escurecendo o hex não funcionava, porque a conta
errada clareava de novo (foram três tentativas de paleta antes de medir os
`baseColorFactor` dentro do .glb e achar a causa). Com a conversão correta, o
quadrúpede deixou de ser verde-pastel e virou o verde da ficha, e o Caçador
recuperou o azul e o ciano do cachecol. **Qualquer mexida em paleta daqui para
a frente exige regerar e olhar as capturas de novo.**

### 9.2 Contrato de Parte, generalizado

A cauda do quadrúpede já valia o contrato "malha com nome próprio que a Godot
esconde". Esta leva o estendeu para dois papéis, declarados em
`CreatureView.PARTS`:

| Papel | O que acontece ao quebrar | Quem usa |
| --- | --- | --- |
| `sever` | a malha some | cauda do Gnasher, `stinger` e `antenna_*` da Faiscaia, `tail` do Bastião |
| `plate` + `raw` | a placa some e a camada de baixo aparece | `crest`/`raw_head` e `shell`/`raw_shell` do Bastião, `plates`/`raw_plates` da Faiscaia |

A camada `raw` nasce escondida; quebrar vira **troca de camada**, não buraco.
É o que faz "qual setor já está aberto" ser lido de longe — a pergunta que a
luta do Bastião faz o tempo todo.

### 9.3 Dois erros de eixo que o preview pegou

1. **Sinal do `ry` da cauda.** Num osso que aponta para TRÁS, `ry` positivo
   LEVANTA a ponta. O Rolamento e a Maçada nasceram com o sinal trocado e
   enfiavam a maça no chão durante o golpe inteiro.
2. **Girar não é só girar.** No Rolamento a raiz dá 720°; o ponto mais
   distante dela passa por baixo do chão. O clipe sobe o centro 0,55 m durante
   o Ativo — e o mesmo raciocínio corrigiu as quedas do Atordoamento das duas
   criaturas novas, que herdaram do quadrúpede um deslocamento para BAIXO que
   só funciona para quem tem a raiz alta.

`tools/preview_model.gd` ganhou um 7º argumento: lista de prefixos de malha a
esconder. `... idle "" "" "" shell,crest,tail` é como se confere a cara do
Bastião demolido sem abrir o jogo.

### 9.4 Escala das armas

Medida contra o Caçador (1,90 m, mão a ~0,85 m): espada 1,20 → **0,95 m**
(lâmina 22 → 17 cm), martelo 1,25 → **0,95 m** (cabeça 62 → 46 cm), lâminas
encolhidas junto porque contam dobrado (são duas na tela). As três novas já
nascem nesta régua: machado 1,10 m, lança 1,45 m (fina, porque comprimento ali
é leitura de alcance), repetidoras 0,52 m.

### 9.5 O que esta leva NÃO fez

Os clipes do Caçador para Machado e Lança (18 Golpes, que a Mecânica
implementou na Sim em paralelo a este trabalho) continuam na fila: hoje caem
no fallback declarado da `HunterView`. As Repetidoras não precisam de clipe de
Golpe — tiro e Rolinho não são Golpes.
