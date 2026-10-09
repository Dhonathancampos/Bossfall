# 05 — Faiscaia

## Nome, arquétipo e fantasia

**Faiscaia** — duelista de relógio. Uma lacraia colossal de placas de quartzo
com um coração de tempestade que viaja pelo corpo dela como uma conta num
ábaco; a caçada inteira é uma contagem regressiva que o grupo pode atrasar,
desarmar — ou interromper no último segundo.

## A mecânica nova: o Núcleo Errante (zona que se move + interrupção como recurso central)

A Faiscaia tem um **Núcleo Errante**: uma zona de acerto viva (raio 70) que
percorre o corpo em estações fixas — **Ferrão → Placas traseiras → Placas
dianteiras → Mandíbulas** — parando ~9 s em cada uma. É a primeira criatura a
usar o contrato novo de zonas por Parte (offset+raio) de verdade: a zona do
núcleo **muda de offset durante a luta**, e o jogador caça um ponto fraco que
anda.

O relógio tem consequência: quando o núcleo chega às Mandíbulas, ela se planta
e inicia a **Descarga Plena** — o maior ataque do jogo até aqui, com o maior
Preparo do jogo até aqui, e **interruptível do começo ao quase-fim**. As três
respostas, por ordem de recompensa:

1. **Interromper (boop)**: um golpe de Atordoamento alto na cabeça durante a
   janela cancela a Descarga, sobrecarrega o núcleo e abre a maior janela de
   punição do bestiário (núcleo exposto na cabeça, dano ×2, por 6 s).
2. **Atrasar**: dano no Núcleo Errante, onde quer que ele esteja, empurra o
   relógio para trás (+1,5 s de estação a cada 100 de dano, teto +6 s por
   estação). Caçar a zona móvel é a defesa contínua.
3. **Fugir**: o círculo é grande (520) mas não cobre a arena — correr salva a
   vida e não rende nada.

É o inverso da Vespreia (que pune ignorar as crias): a Faiscaia **recompensa
quem aprendeu o sistema de interrupção** — o Martelo deixa de ser "a arma de
quebrar placa" do Bastião e vira o desarmador de bomba. E é a primeira luta em
que a pergunta por minuto não é "onde estou?" e sim "onde ELE está no corpo?".

## Partes (com zonas do contrato novo)

Zonas no plano local (x = frente), como o contrato novo define: cada Parte
tem `offset` + `radius` além do setor angular herdado.

| Parte | Zona (offset, raio) | Setor | HP | Decepável | Dura | Quebra muda O PADRÃO |
|---|---|---|---|---|---|---|
| Mandíbulas | (185, 0), 115 | front | 500 | não | sim | A Pinçada perde a segunda mordida e o Preparo da Descarga ganha +0,4 s — **a quebra facilita o boop** |
| Antenas | (230, 0), 70 | front | 380 | sim | não | Ela para de "ler" a esquiva: somem os encadeamentos que miram o ponto de fuga (Pinçada dupla, Látego→Pinçada) |
| Placas Dorsais | (−30, 0), 150 | side | 620 | sim* | sim | O núcleo atravessa o dorso na METADE da velocidade (estação 9→13 s) e a zona dele cresce de 70→95 — a quebra que desarma o relógio |
| Ferrão | (−235, 0), 95 | back | 400 | sim | não | Remove o Chicote Caudal, **mas o ciclo do núcleo passa a começar uma estação à frente** (~18 s em vez de ~27 s até a Descarga) — decepar tem preço |
| Núcleo Errante | (estação atual), 70 | móvel | — | não | não | Não quebra: dano ali vale ×1,5 à Vida e atrasa o relógio; o HP "dele" é o tempo que você compra |

\* As Placas "decepam" como entulho visual (lascas caem), mas a Parte não
remove ataque nenhum — a quebra mexe no relógio, não no repertório.

O Ferrão é a decisão de design mais arriscada da ficha: é a primeira quebra do
bestiário que **piora um aspecto da luta de propósito**. Cortar a cauda é
ótimo para espadachins (loot/remoção do Chicote) e ruim para o grupo que
depende de tempo. Discutir antes de cortar vira conversa de lobby.

## Ataques

Formato dos dados de `behemoths.gd`, com os campos novos do contrato:
`interruptible` (janela no Preparo, limiar de Atordoamento do golpe) e
`telegraph` (se desenha no chão; `false` = leitura só pela animação, como a
direção de combate aprovada pede para golpes rápidos e curtos).

```gdscript
"attacks": [
    {
        "id": "pince",
        "name": "Pinçada",
        "windup": 0.50, "active": 0.14, "recovery": 0.58,
        "cooldown": 1.8,
        "min_range": 0.0, "max_range": 205.0,
        "shape": {"type": SHAPE_CONE, "range": 205.0, "arc": 0.9, "offset": 0.0},
        "damage": 15.0, "knockback": 220.0,
        "turn_rate": 1.7,
        "advance": 0.0,
        "weight": 3.0,
        ## Curta e frontal: lê-se pela animação (mandíbulas abrem), não pelo chão.
        "telegraph": false,
        "post_gap": 0.35,
    },
    {
        "id": "whip",
        "name": "Chicote Caudal",
        "windup": 0.55, "active": 0.18, "recovery": 0.70,
        "cooldown": 4.0,
        "min_range": 0.0, "max_range": 260.0,
        "shape": {"type": SHAPE_CONE, "range": 255.0, "arc": 2.3, "offset": PI},
        "damage": 19.0, "knockback": 330.0,
        "turn_rate": 0.7,
        "advance": 0.0,
        "weight": 2.0,
        "telegraph": true,
        "post_gap": 0.6,
        "requires_part": "stinger",
        "element": Elements.Element.SHOCK,
    },
    {
        "id": "serpentine",
        "name": "Serpenteada",
        "windup": 0.78, "active": 0.45, "recovery": 0.85,
        "cooldown": 6.0,
        "min_range": 220.0, "max_range": 650.0,
        "shape": {"type": SHAPE_DASH, "width": 135.0, "range": 500.0},
        "damage": 22.0, "knockback": 360.0,
        "turn_rate": 0.5,
        "advance": 1200.0,
        "weight": 2.5,
        "telegraph": true,
        "post_gap": 0.5,
        ## Errar todo mundo deixa o corpo comprido esparramado: punição clara.
        "whiff_recovery_bonus": 0.6,
    },
    {
        "id": "coil",
        "name": "Enrodilho",
        "windup": 0.95, "active": 0.22, "recovery": 0.95,
        "cooldown": 7.5,
        "min_range": 0.0, "max_range": 210.0,
        "shape": {"type": SHAPE_CIRCLE, "range": 270.0},
        "damage": 24.0, "knockback": 380.0,
        "turn_rate": 0.6,
        "advance": 0.0,
        "weight": 1.5,
        "telegraph": true,
        "post_gap": 0.9,
        ## O boop de treino: janela generosa, limiar baixo. É aqui que o
        ## jogador aprende o verbo antes de precisar dele na Descarga.
        "interruptible": {"until": 0.60, "threshold": 60.0},
    },
    {
        "id": "static_lash",
        "name": "Látego Estático",
        "windup": 0.66, "active": 0.16, "recovery": 0.68,
        "cooldown": 3.5,
        "min_range": 150.0, "max_range": 420.0,
        "shape": {"type": SHAPE_DASH, "width": 100.0, "range": 400.0},
        "damage": 18.0, "knockback": 260.0,
        "turn_rate": 1.1,
        "advance": 0.0,
        "weight": 2.5,
        "telegraph": true,
        "post_gap": 0.45,
        "element": Elements.Element.SHOCK,
    },
    {
        "id": "discharge",
        "name": "Descarga Plena",
        ## Fora da faixa 0.48-1.10 DE PROPÓSITO: é o centerpiece do boop, e o
        ## único ataque do jogo com Preparo de 2 s. Só dispara por condição do
        ## cérebro (núcleo nas Mandíbulas), nunca por sorteio/peso.
        "windup": 2.00, "active": 0.30, "recovery": 1.40,
        "cooldown": 10.0,
        "min_range": 0.0, "max_range": 900.0,
        "shape": {"type": SHAPE_CIRCLE, "range": 520.0},
        "damage": 40.0, "knockback": 420.0,
        "turn_rate": 0.0,
        "advance": 0.0,
        "weight": 0.0,
        "telegraph": true,
        "post_gap": 1.2,
        ## Interruptível quase até o fim; limiar alto: pede a Rajada plena do
        ## Martelo ou o golpe de Impacto mais pesado de cada arma.
        "interruptible": {"until": 1.60, "threshold": 110.0},
        "element": Elements.Element.SHOCK,
    },
]
```

Base: `hp 2700`, `radius 140` (tronco central; o alcance real vem das zonas
por Parte, que se estendem até ±235), `move_speed 150`, `turn_speed 2.6`,
`preferred_gap 80`, `stagger_threshold 440`, `enrage_at 0.35`,
`enrage_speed 1.2`, `enrage_damage 1.25`, `enrage_cooldown 0.7`,
`decision_gap 0.5`, `brain: "faiscaia"`.

Relógio do núcleo: estação de **9 s** (13 s no dorso com Placas quebradas;
**6,5 s** em Fúria), 4 estações, ~27 s do Ferrão à Descarga. Dano no núcleo:
**×1,5 à Vida** + **+1,5 s de estação a cada 100 de dano** (teto +6 s por
estação). Após a Descarga (acertando, errando ou interrompida), o núcleo volta
ao Ferrão — ou à estação 2, se o Ferrão foi decepado.

Os limiares de `interruptible` (60/110) e o dano 40 da Descarga são
**provisórios**: calibrar contra o Atordoamento real da Rajada do Martelo e a
Vida do Caçador quando o contrato novo aterrissar com o Gnasher.

## Padrões de comportamento (cérebro `faiscaia`)

Regras em ordem de prioridade (primeira que casa vence), no molde do
`gnasher_plan`; o rng só varia dentro de uma regra:

1. **Núcleo nas Mandíbulas → `discharge`**, incondicional: ela ignora
   distância, desliza até longe da borda da arena e se planta. Única regra
   disparada por estado interno (estação do núcleo), não por
   distância/ângulo — o campo novo que o cérebro pede ao contrato.
2. **Alvo atrás (> BEHIND_ANGLE) com Ferrão inteiro → `whip`**; se as Antenas
   estão inteiras e o alvo seguiu colado depois do Chicote, encadeia
   `whip → coil` (plano de 2 passos). Sem Antenas, o Chicote sai sozinho.
3. **Alvo colado ≥ 2,5 s (sticky_time) → `coil`** — o castigo de quem abraça,
   e o lugar onde o jogador treina o boop com limiar baixo.
4. **Alvo a média distância (150–420) → `static_lash`**; com Antenas inteiras
   o látego MIRA O PONTO DE FUGA (lead usando a velocidade do alvo, que a Sim
   já serializa) e, se o alvo entra no alcance da boca ao esquivar, encadeia
   `static_lash → pince`.
5. **Alvo no alcance da boca → `pince`**; com Antenas inteiras e a primeira
   Pinçada no vazio, a segunda sai na direção da esquiva (plano de 2 passos,
   variação por rng como a mordida dupla do Gnasher: 45%, 70% em Fúria).
6. **Alvo longe → `serpentine`**; se termina com o alvo nas costas, emenda
   `whip` (mesmo padrão pós-recuperação do charge→tail do Gnasher).

**Janelas de punição prometidas:** Serpenteada no vazio (+0,6 s de
recuperação, o corpo comprido esparramado); recuperação do Enrodilho (0,95 s
colado nela); Enrodilho interrompido (INTERRUPTED padrão); e o jackpot — a
**Descarga interrompida**: INTERRUPTED estendida (~3,5 s) com o núcleo
sobrecarregado preso nas Mandíbulas por 6 s recebendo dano ×2. Quebrar as
Mandíbulas antes alarga o Preparo da Descarga em +0,4 s, então a rota "quebra
a cabeça cedo para o boop ficar confortável" é um plano de luta inteiro.

## Elemento e variantes

Natural: **Elétrico** (Aflição: Choque — tomar o Látego com o relógio andando
é o aperto assinatura dela). Variantes: **Trevas** (Faiscaia Abissal — núcleo
negro; a Descarga vira um dreno em área: quem sobrevive fica sem Fôlego, e as
poças de Choque viram Dreno) e **Água** (Faiscaia de Maré — placas de coral;
Congelamento no Enrodilho, o boop com luva de gelo).

## Custo de motor

Médio-grande — e quase todo ele é o primeiro cliente de verdade do contrato
novo, o que é intencional: (1) zona por Parte com offset+raio já está no
contrato; a novidade é **uma zona com offset dinâmico** — um `core_station:
int` + `station_time: float` no BehemothState, avançados no `step`, entrando
no Instantâneo (2 campos pequenos); (2) dano na zona do núcleo precisa de um
gancho no `_hit_behemoth` (multiplicador ×1,5 e empurrão no relógio); (3) o
cérebro `faiscaia` é um `*_plan` novo no molde do `gnasher_plan`, mais UMA
condição de disparo por estado interno (estação) que hoje não existe — o
`discharge` não pode ser escolhido por peso/distância; (4) a Descarga
interrompida pede um override de duração do INTERRUPTED por ataque (campo
`interrupt_bonus` nos dados) e um flag "núcleo exposto" com timer; (5) efeitos
de quebra no relógio (dorso lento, ciclo encurtado sem Ferrão) são `if`s no
avanço da estação. Sem entidade nova, sem rede nova além dos 2 campos — mais
barata que a Vespreia, mais cara que a Brejara. `telegraph: false` por ataque
é um `if` no desenho da telegrafia (a Sim não muda).

## Visual (cartunesco low-poly)

Lacraia de 6 segmentos achatados como vagões, cada um um prisma chanfrado de
quartzo cinza-azulado (`7d8aa5`) com UMA placa dorsal saliente clara
(`c9d4e8`); dezenas de perninhas viram fileiras de cunhas estilizadas que
ondulam em fase. Cabeça larga com mandíbulas-tenaz externas e duas antenas
compridas segmentadas (as Partes decepáveis bem visíveis). Ferrão caudal em
gancho duplo, tipo tesoura. O **Núcleo Errante é a estrela**: uma esfera
facetada âmbar-elétrica (`ffd23f`, emissiva, pulsando a 1 Hz) visível ENTRE as
placas do segmento atual, com um rastro de faíscas quando troca de estação —
o jogador tem que localizar a estação num relance. Na Descarga, o corpo
inteiro acende em veios amarelos da cauda à cabeça, como um pavio. Placas
quebradas caem como lascas e o quartzo exposto fica fosco e rachado. Em Fúria,
o núcleo pulsa a 2 Hz e as antenas faíscam nas pontas.
