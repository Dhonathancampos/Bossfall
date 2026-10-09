# CONTEXT

Glossário do projeto. Termos em português (como aparecem na interface), com o
identificador usado no código entre parênteses.

---

## Caçada (`Hunt`)

Uma partida. Começa quando o Anfitrião inicia, termina quando o Behemoth morre
(vitória) ou quando todos os Caçadores ficam Abatidos sem Fichas de Reviver
(derrota). Não há progressão entre Caçadas.

## Caçador (`Hunter`)

Um jogador dentro da Caçada. Máximo de 4 por Caçada.

## Anfitrião (`Host`)

O Caçador que abriu a partida. Sua máquina roda a Simulação autoritativa; os
demais são Clientes. Não é um papel de jogo — é um papel de rede.

## Simulação (`Sim`)

O núcleo determinístico do jogo: recebe as Entradas de todos os Caçadores por
Tique e produz o estado do mundo. Não sabe desenhar nem falar em rede.

## Tique (`Tick`)

Um passo de tempo fixo da Simulação.

## Entrada (`Input`)

O que um Caçador está pressionando num Tique. É a única coisa que o Cliente
manda para o Anfitrião.

## Instantâneo (`Snapshot`)

O estado do mundo num Tique, enviado do Anfitrião para os Clientes. É a única
coisa que o Anfitrião manda de volta.

## Arena

O campo circular onde a Caçada acontece. Não há hub nem exploração.

---

## Behemoth

O monstro caçado. Tem Vida, Partes, medidor de Atordoamento, um Elemento e uma
máquina de estados de IA. Nunca é controlado por um jogador.

## Parte (`Part`)

Uma região do corpo do Behemoth com Vida própria (cabeça, cauda, asa, perna).
Acerto numa Parte conta para a Vida do Behemoth **e** para a Vida da Parte.

## Quebra de Parte (`PartBreak`)

Quando a Vida de uma Parte chega a zero. A Parte passa a receber dano
aumentado, o Behemoth sofre Atordoamento imediato, e Partes decepáveis
(cauda, asa) deixam de ser usadas nos ataques que dependem delas.

## Atordoamento (`Stagger`)

Medidor do Behemoth que enche com dano de Impacto e esvazia com o tempo. Cheio,
o Behemoth cai e fica indefeso por alguns segundos.

## Ferimento (`Wound`)

Acúmulo numa Parte causado por dano de Perfuração. Reservado: nenhuma arma do
escopo inicial causa Perfuração.

## Fúria (`Enrage`)

Estado do Behemoth abaixo de certa Vida: mais rápido, mais dano, menos tempo
entre ataques.

## Telegrafia (`Telegraph`)

O aviso visual desenhado no chão durante o preparo de um ataque do Behemoth,
mostrando a área que vai ser atingida. É o que torna a Esquiva uma decisão e
não um palpite.

## Ameaça (`Threat`)

Quanto cada Caçador irritou o Behemoth. Decide em quem ele vai focar.

---

## Golpe (`Move`)

Um ataque de uma arma. Tem três fases em sequência: **Preparo** (`windup`),
**Ativo** (`active`, a única fase que acerta) e **Recuperação** (`recovery`).

## Comprometimento (`Commitment`)

A regra de que um Golpe iniciado vai até o fim: não dá para cancelar no meio.
É a decisão de design central do combate.

## Combo

Encadear o próximo Golpe durante a Recuperação do anterior, dentro da Janela de
Combo.

## Esquiva (`Dodge`)

Rolamento que custa Fôlego e concede Invulnerabilidade por parte da sua
duração.

## Invulnerabilidade (`IFrames`)

O intervalo da Esquiva em que o Caçador não pode ser atingido.

## Fôlego (`Stamina`)

Recurso gasto por Esquiva, corrida e Golpes. Regenera sozinho após uma pausa.

## Éter (`Aether`)

Medidor que enche conforme o Caçador acerta Golpes e gasta no Especial da arma.

## Especial (`Special`)

A habilidade única de cada arma, liberada com o Éter cheio.

---

## Tipo de Dano (`DamageType`)

A natureza física do golpe. Três tipos:

- **Corte** (`Slash`) — bom contra Partes decepáveis (cauda, asa).
- **Impacto** (`Blunt`) — bom contra Atordoamento e Partes duras (cabeça).
- **Perfuração** (`Pierce`) — gera Ferimento. Reservado.

## Elemento (`Element`)

Sete valores: **Neutro**, **Fogo**, **Água**, **Elétrico**, **Terra**,
**Luz**, **Trevas**. (Renomeados em 09/10/2026 para abranger possibilidades
futuras; os identificadores no código mantêm os nomes antigos em inglês.)

## Oposição (`Opposition`)

Os pares opostos: Fogo ↔ Água, Elétrico ↔ Terra, Luz ↔ Trevas. Neutro
não tem oposto. Arma causa dano a mais contra o Elemento oposto e dano a menos
contra o mesmo Elemento.

## Aflição (`Affliction`)

O efeito que o Elemento de um ataque do Behemoth aplica no Caçador. Uma por
Elemento: Queimadura, Congelamento, Choque, Enraizamento, Cegueira, Dreno.

---

## Abatido (`Downed`)

Estado do Caçador com Vida zerada: imóvel, vulnerável, com um contador. Um
companheiro pode Reviver, ou o Caçador gasta uma Ficha de Reviver.

## Ficha de Reviver (`ReviveToken`)

Recurso compartilhado pelo grupo. Acaba o estoque e o próximo Abatido vira
Morto. Todos Mortos = Caçada perdida.
