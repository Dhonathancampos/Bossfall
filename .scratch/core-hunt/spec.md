# Spec: Caçada Base (`core-hunt`) — Onda 1

Status: ready-for-agent · Onda: 1 (2D). Ver `ROADMAP.md` para a Onda 2 (3D).

## Problem Statement

Dauntless foi desligado em 29/05/2025 e, por ser um jogo só online, deixou de
existir: não há como jogar nem em modo offline. O usuário quer poder jogar o
núcleo daquela experiência de novo — correr, esquivar, escolher uma arma e
derrubar um monstro grande com os amigos — sem depender de servidores de
terceiros.

Hoje não existe nada disso neste repositório.

## Solution

Um jogo em **Godot 4.7.2 / GDScript**, 2D visto de cima, em que:

- O jogador abre o jogo e escolhe **Hospedar** ou **Entrar**.
- **Quem hospeda roda a Simulação autoritativa.** Não há servidor dedicado nem
  serviço externo: a máquina do Anfitrião é o servidor. Até 4 Caçadores.
- No lobby cada Caçador escolhe nome, arma e Elemento da arma; o Anfitrião
  escolhe o Behemoth e inicia.
- A Caçada acontece numa Arena circular contra um Behemoth com Partes
  quebráveis, Atordoamento, Fúria e ataques Telegrafados.
- Vitória quando o Behemoth morre; derrota quando o grupo fica sem Fichas de
  Reviver. Os dois casos voltam ao lobby.

O combate é **comprometido**: um Golpe iniciado vai até o fim. Posicionar-se e
escolher a hora de bater é o jogo.

## User Stories

### Movimentação

1. Como Caçador, quero andar em qualquer direção com WASD, para me posicionar em volta do Behemoth.
2. Como Caçador, quero mirar com o mouse de forma independente de onde ando, para atacar numa direção enquanto me afasto de outra.
3. Como Caçador, quero correr segurando Shift gastando Fôlego, para fechar distância depois de uma Telegrafia terminar.
4. Como Caçador, quero que a corrida pare de funcionar com o Fôlego vazio, para que correr seja uma decisão e não um estado padrão.
5. Como Caçador, quero rolar com Espaço gastando Fôlego, para atravessar um ataque.
6. Como Caçador, quero ficar invulnerável durante parte do rolamento, para que uma esquiva no tempo certo anule o dano por completo.
7. Como Caçador, quero que o rolamento tenha uma recuperação curta no fim, para não poder rolar infinitamente.
8. Como Caçador, quero que meu Fôlego volte sozinho depois de uma pausa curta sem gastar, para me recompensar por recuar.
9. Como Caçador, quero esbarrar na borda da Arena em vez de sair dela, para nunca me perder do combate.
10. Como Caçador, quero atravessar livremente o corpo dos outros Caçadores, para que o grupo não se atrapalhe em espaço apertado.

### Combate — regras gerais

11. Como Caçador, quero um ataque leve no botão esquerdo, para o dano constante.
12. Como Caçador, quero um ataque pesado no botão direito, para o dano alto e lento.
13. Como Caçador, quero que todo Golpe tenha Preparo, Ativo e Recuperação visíveis no personagem, para conseguir ler o próprio tempo de ação.
14. Como Caçador, quero que um Golpe iniciado não possa ser cancelado, para que atacar no momento errado seja punido.
15. Como Caçador, quero encadear Combos apertando de novo dentro da Janela de Combo, para ser premiado por ficar perto.
16. Como Caçador, quero que o Combo volte ao início se eu perder a Janela, para que a sequência tenha ritmo próprio.
17. Como Caçador, quero que cada Golpe me empurre um pouco para frente, para alcançar o alvo sem precisar colar nele.
18. Como Caçador, quero acertar no máximo uma vez por alvo por Golpe, para que o dano seja previsível.
19. Como Caçador, quero uma travadinha na imagem ao acertar (hitstop), para sentir o peso do golpe.
20. Como Caçador, quero ver números de dano saindo do ponto que acertei, para entender o que está funcionando.
21. Como Caçador, quero que meus Golpes gastem Fôlego, para não poder atacar sem parar.
22. Como Caçador, quero encher o Éter acertando Golpes, para liberar o Especial da arma.
23. Como Caçador, quero disparar o Especial com F quando o Éter estiver cheio, para ter um momento forte por Caçada.

### Armas

24. Como Caçador, quero escolher entre Espada, Martelo e Lâminas Correntes no lobby, para jogar do jeito que gosto.
25. Como Caçador, quero que a Espada tenha combo de 3 golpes rápidos e alcance médio, para ser a escolha equilibrada.
26. Como Caçador, quero que o Especial da Espada (**Valor**) me dê mais dano e mais velocidade por alguns segundos, para premiar agressividade.
27. Como Caçador, quero que o Martelo seja lento, de alcance curto e cause muito Atordoamento, para ser a arma que derruba o Behemoth.
28. Como Caçador, quero carregar o ataque pesado do Martelo segurando o botão, para escolher entre bater rápido ou bater forte.
29. Como Caçador, quero que o Especial do Martelo (**Câmara de Magma**) dispare um tiro explosivo, para ter alcance quando não dá para chegar perto.
30. Como Caçador, quero que as Lâminas tenham combo de 4 golpes muito rápidos e alcance curto, para ser a arma de ficar colado.
31. Como Caçador, quero que o ataque pesado das Lâminas seja um gancho que me puxa até o Behemoth, para recuperar distância sem gastar Fôlego.
32. Como Caçador, quero que o Especial das Lâminas (**Dança da Ceifadora**) seja um giro contínuo com muitos acertos, para acumular Elemento rápido.
33. Como Caçador, quero ver o moveset da arma escolhida no lobby, para saber o que vou fazer antes de entrar.

### Tipos de dano

34. Como Caçador, quero que Espada e Lâminas causem dano de **Corte**, para serem boas em decepar cauda e asa.
35. Como Caçador, quero que o Martelo cause dano de **Impacto**, para ser bom em quebrar cabeça e encher o Atordoamento.
36. Como Caçador, quero que Corte cause mais dano em Partes decepáveis, para que a escolha de arma mude onde eu bato.
37. Como Caçador, quero que Impacto encha o Atordoamento muito mais rápido, para que o Martelo tenha um papel claro no grupo.
38. Como Caçador, quero que o jogo tenha o tipo **Perfuração** definido mesmo sem arma que o use, para que uma Lança possa ser adicionada depois sem reescrever o sistema.

### Elementos

39. Como Caçador, quero escolher o Elemento da minha arma no lobby entre Neutro, Incêndio, Gélido, Choque, Terra, Radiante e Umbral, para me preparar para o Behemoth.
40. Como Caçador, quero causar dano aumentado contra o Elemento oposto ao da minha arma, para que a preparação valha a pena.
41. Como Caçador, quero causar dano reduzido contra o mesmo Elemento da minha arma, para ser punido por não me preparar.
42. Como Caçador, quero que arma Neutra nunca receba bônus nem penalidade, para ser a escolha segura.
43. Como Caçador, quero ver no lobby qual Elemento é forte contra o Behemoth escolhido, para não precisar decorar a tabela.
44. Como Caçador, quero que o dano elemental apareça em cor diferente do dano físico, para ler o que está acontecendo.

### Aflições

45. Como Caçador, quero que ataques de Incêndio me causem **Queimadura**, tirando vida aos poucos.
46. Como Caçador, quero que ataques Gélidos me causem **Congelamento**, me deixando mais lento até me prender no lugar.
47. Como Caçador, quero que ataques de Choque me causem **Choque**, interrompendo meu Golpe e drenando Fôlego.
48. Como Caçador, quero que ataques de Terra me causem **Enraizamento**, me impedindo de rolar por alguns segundos.
49. Como Caçador, quero que ataques Radiantes me causem **Cegueira**, escurecendo parte da minha visão.
50. Como Caçador, quero que ataques Umbrais me causem **Dreno**, travando a regeneração de Fôlego e esvaziando meu Éter.
51. Como Caçador, quero ver um ícone com contador de cada Aflição ativa em mim, para saber por que estou jogando pior.
52. Como Caçador, quero que Aflições tenham um acúmulo antes de disparar, para que um acerto solto não me arruíne.

### Behemoth

53. Como Caçador, quero caçar o **Gnasher**, um quadrúpede terrestre que morde, investe e gira a cauda, para ter uma luta direta.
54. Como Caçador, quero caçar o **Shrike**, um voador que mergulha, sopra vento e atira penas, para ter uma luta de reposicionamento.
55. Como Caçador, quero que cada Behemoth tenha um Elemento, para que minha escolha de arma importe.
56. Como Caçador, quero poder escolher variantes elementais do mesmo Behemoth, para enfrentar o mesmo monstro com preparação diferente.
57. Como Caçador, quero ver uma Telegrafia no chão durante o Preparo de cada ataque, para decidir quando rolar.
58. Como Caçador, quero que a Telegrafia mostre o formato real do golpe (cone, círculo, linha), para aprender os ataques.
59. Como Caçador, quero que o Behemoth gire na minha direção durante o Preparo, mas devagar, para poder contornar o golpe correndo pelo lado.
60. Como Caçador, quero que o Behemoth escolha o alvo por Ameaça, para que quem mais bate puxe a atenção.
61. Como Caçador, quero que o Behemoth entre em **Fúria** abaixo de certa Vida, ficando mais rápido e perigoso, para que o fim da luta seja tenso.
62. Como Caçador, quero ver a entrada em Fúria claramente (rugido, cor, aviso), para reagir.
63. Como Caçador, quero ver a barra de Vida do Behemoth no topo da tela, para saber quanto falta.

### Partes e Atordoamento

64. Como Caçador, quero que o Behemoth tenha Partes com Vida própria, para escolher onde bater.
65. Como Caçador, quero ver quais Partes existem e quanto falta para quebrar, para coordenar com o grupo.
66. Como Caçador, quero que quebrar uma Parte cause Atordoamento imediato, para premiar o foco.
67. Como Caçador, quero que uma Parte quebrada passe a receber mais dano, para que quebrar compense.
68. Como Caçador, quero que decepar a cauda tire do Behemoth os ataques que usam a cauda, para que quebrar mude a luta e não só os números.
69. Como Caçador, quero que quebrar a asa do Shrike impeça o mergulho, para que o grupo tenha uma meta clara.
70. Como Caçador, quero encher o medidor de Atordoamento batendo, para derrubar o Behemoth.
71. Como Caçador, quero que o Atordoamento esvazie sozinho com o tempo, para que precise ser acumulado com pressão constante.
72. Como Caçador, quero que o Behemoth caia indefeso por alguns segundos quando o Atordoamento enche, para ter a janela de dano livre.
73. Como Caçador, quero que cada Atordoamento seguinte fique mais caro, para que a luta não vire uma corrente de quedas.

### Dano sofrido, Abatido e Reviver

74. Como Caçador, quero levar dano e empurrão ao ser atingido, para sentir o erro.
75. Como Caçador, quero ficar brevemente invulnerável depois de levar dano, para não morrer num ataque só.
76. Como Caçador, quero ficar **Abatido** em vez de morrer na primeira vez, para ter uma segunda chance.
77. Como Caçador, quero que um companheiro me levante segurando E perto de mim, para que jogar junto importe.
78. Como Caçador, quero ver a barra de progresso do Reviver, para saber se dá tempo.
79. Como Caçador, quero poder me levantar sozinho gastando uma **Ficha de Reviver** do grupo, para não travar a partida quando estou sozinho.
80. Como Caçador, quero ver quantas Fichas de Reviver o grupo ainda tem, para saber o risco.
81. Como Caçador, quero perder a Caçada quando todos estiverem Abatidos sem Fichas, para que haja consequência.
82. Como Caçador, quero curar com uma poção apertando Q, ficando parado e vulnerável enquanto bebo, para que curar seja uma decisão arriscada.
83. Como Caçador, quero ter um número limitado de poções por Caçada, para não poder me curar sem parar.

### Multijogador

84. Como jogador, quero abrir o jogo e escolher **Hospedar** ou **Entrar**, para começar em dois cliques.
85. Como Anfitrião, quero ver o endereço da minha máquina na tela, para passar para os amigos.
86. Como jogador, quero entrar digitando o endereço do Anfitrião, para conectar sem configuração.
87. Como jogador, quero ver a lista de quem está conectado e com qual arma, para saber se o grupo está pronto.
88. Como Anfitrião, quero ser o único que escolhe o Behemoth e inicia a Caçada, para que o controle seja claro.
89. Como Caçador, quero ver os outros Caçadores se movendo de forma suave mesmo com rede imperfeita, para que o jogo não pareça travado.
90. Como Caçador, quero que a Simulação do Anfitrião seja a verdade final, para que ninguém possa trapacear.
91. Como Caçador, quero que a Vida do Behemoth cresça com o número de Caçadores, para que 4 jogadores não matem em 10 segundos.
92. Como jogador, quero que a saída de um Caçador no meio da Caçada não quebre a partida, para que o grupo continue.
93. Como jogador, quero jogar sozinho sem precisar de mais ninguém, para poder testar à vontade.
94. Como jogador, quero voltar ao lobby automaticamente no fim da Caçada, para encadear partidas.

### Interface

95. Como Caçador, quero ver minha Vida, Fôlego e Éter sempre na tela, para decidir sem adivinhar.
96. Como Caçador, quero ver a Vida dos companheiros numa lista, para saber quem está em apuros.
97. Como Caçador, quero ver a tela de resultado com dano causado e Partes quebradas por jogador, para comparar.
98. Como Caçador, quero ver os controles numa tela de ajuda, para não precisar perguntar.

## Implementation Decisions

### Arquitetura — uma única costura

O projeto se divide em **Simulação** e **Apresentação**, e a fronteira entre
elas é a única costura de testes.

- **`Sim`** (núcleo): classes GDScript puras (`RefCounted`), sem `Node`, sem
  cena, sem sinal de rede, sem `_process`. Interface mínima:
  `Sim.new(config)`, `sim.set_input(hunter_id, input)`, `sim.step(dt)`,
  `sim.snapshot()`. Determinística: mesmas Entradas, mesmo resultado. É onde
  vivem movimento, Golpes, dano, Elementos, Aflições, Partes, Atordoamento, IA
  do Behemoth e condição de vitória/derrota.
- **Apresentação** (`Node`s de cena): lê `snapshot()` e desenha; captura
  teclado/mouse e produz `input`. Não contém nenhuma regra de jogo.
- **Rede**: adaptador fino. O Anfitrião roda a `Sim` e publica `snapshot()`; os
  Clientes só mandam `input` e recebem `snapshot`. Trocar `ENetMultiplayerPeer`
  por outro transporte não deve tocar na `Sim`.

Consequência: jogar sozinho é o mesmo caminho de código que hospedar com 4 —
há sempre uma `Sim` e sempre um Anfitrião, mesmo que seja só você.

### Conteúdo orientado a dados

Armas, Golpes, Behemoths, ataques do Behemoth, Elementos e Aflições são
**dados**, não classes. Acrescentar a quarta arma ou o terceiro Behemoth é
escrever uma entrada nova na tabela, não um arquivo de código novo.

Um Golpe é descrito por: nome, duração de Preparo/Ativo/Recuperação, formato e
alcance da área de acerto, dano base, Tipo de Dano, multiplicador de
Atordoamento, multiplicador de dano em Parte, avanço para frente, custo de
Fôlego, ganho de Éter e Janela de Combo.

Um ataque de Behemoth é descrito por: nome, Preparo/Ativo/Recuperação, tempo de
recarga, faixa de distância em que é escolhido, formato da Telegrafia, dano,
Elemento, empurrão e Parte de que depende (para ser removido quando a Parte
for decepada).

### Rede

- Transporte: `ENetMultiplayerPeer` do Godot. `create_server(porta)` no
  Anfitrião, `create_client(ip, porta)` no Cliente.
- Autoridade total do Anfitrião. O Cliente nunca decide dano.
- Cliente manda só `input`; Anfitrião manda só `snapshot`.
- Cliente interpola os outros Caçadores e o Behemoth entre Instantâneos.
- O Caçador local prevê o próprio movimento livre (andar/correr) e reconcilia
  com o Instantâneo. **Não** prevê Golpe, Esquiva nem dano — o atraso aí é
  aceitável e a complexidade de reverter não é.
- Saída de Caçador: a `Sim` remove o Caçador e segue. Se o Anfitrião sai, a
  partida acaba (sem migração de anfitrião).

### Regras de dano

Ordem de cálculo, do início ao fim:

1. Dano base do Golpe.
2. × multiplicador do Tipo de Dano contra aquela Parte.
3. × bônus/penalidade de Oposição elemental.
4. × bônus de Parte quebrada.
5. × multiplicador de Atordoado (Behemoth caído recebe mais).
6. × buffs ativos do Caçador (ex.: Valor).

Atordoamento e dano de Parte são medidores separados do dano em Vida, e todos
são alimentados pelo mesmo acerto.

### Escala por número de Caçadores

A Vida do Behemoth escala com o número de Caçadores vivos no início da Caçada.
As Partes e o Atordoamento **não** escalam, para que quebrar continue viável em
grupo pequeno.

### Plataforma

Godot 4.7.2 (build mono já instalado em `C:\Godot`), mas o projeto é **só
GDScript** — nada de C#, para não exigir SDK .NET nem passo de compilação.

## Testing Decisions

Um bom teste aqui exercita **comportamento externo da `Sim`**: alimenta
Entradas e verifica o Instantâneo resultante. Nunca inspeciona estado interno
nem chama método privado. Como a `Sim` não depende de cena, os testes rodam sem
janela.

- **Runner**: um script GDScript que estende `SceneTree`, executado com
  `godot --headless --script res://tests/run_tests.gd`. Sem addon externo
  (nada de GUT), para que `godot` mais o repositório sejam tudo que é preciso.
- **O que é testado**: a `Sim`, pela sua interface pública. Em especial:
  - cálculo de dano com Tipo de Dano, Oposição elemental e Parte quebrada;
  - Fôlego: gasto, bloqueio por falta e regeneração após pausa;
  - Esquiva: Invulnerabilidade anula dano dentro da janela e não fora;
  - Comprometimento: Entrada de movimento durante um Golpe não cancela o Golpe;
  - Combo: avança dentro da Janela, reinicia fora dela;
  - Partes: quebra causa Atordoamento, aumenta dano recebido e remove o ataque
    que depende da Parte;
  - Atordoamento: enche, esvazia com o tempo, derruba e fica mais caro a cada
    vez;
  - Aflições: acúmulo, disparo e expiração;
  - Abatido/Reviver: contador, Reviver por companheiro, consumo de Ficha,
    derrota com todos Abatidos sem Ficha;
  - condição de vitória e escala de Vida por número de Caçadores.
- **O que não é testado automaticamente**: desenho, câmera, som, e o
  comportamento sob latência real. Esses se validam jogando.
- **Prior art**: nenhum — este é o primeiro código do repositório. Os testes
  desta spec estabelecem o padrão.

## Out of Scope

- Progressão: loot, crafting, níveis, células, armaduras.
- Hub navegável, NPCs, missões, história.
- Mais de 3 armas ou mais de 2 Behemoths (os sistemas ficam prontos para
  receber mais, mas o conteúdo extra não entra).
- Dano de **Perfuração** com arma real (o tipo existe, nenhuma arma o usa).
- Migração de Anfitrião quando o Anfitrião sai.
- Descoberta automática de partidas, matchmaking, NAT traversal, servidor de
  sinalização. Entrar é digitar um endereço.
- Contas, salvamento, estatísticas entre partidas.
- Suporte a controle de videogame (teclado e mouse apenas).
- Som além de efeitos simples, se houver tempo.

## Further Notes

- Interface e documentação em português; identificadores, nomes de arquivo e
  mensagens de commit em inglês.
- O usuário tem TDAH: as entregas devem ser verificáveis em pedaços pequenos e
  jogáveis. Cada ticket deve terminar com algo que dá para abrir e ver
  funcionando, não com uma camada invisível.
- O primeiro ticket deve produzir algo jogável (um boneco que anda numa arena),
  mesmo que feio. Nada de construir a `Sim` inteira antes de ver um pixel.
