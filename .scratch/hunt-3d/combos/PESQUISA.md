# Pesquisa — árvores de combo pré-Awakening (ticket 14)

Referência canônica: última build live de *Dauntless* anterior a Awakening
(até **04/12/2024**). Este arquivo separa **EVIDÊNCIA** (o que as fontes dizem,
com era identificada) de **ESCOLHA NOSSA** (o que decidimos onde a fonte falta
ou onde o Lite simplifica). Nomes de golpes citados aqui são os do jogo de
referência, usados SÓ como documentação de pesquisa; os nomes do nosso jogo
são originais e estão nas fichas por arma.

## Aviso de era — leia primeiro

O jogo mudou muito entre 2019 e 2024. Cada fonte abaixo está marcada com a
era que descreve. O que vale para a referência é o estado em 04/12/2024:

| Arma | Último estado pré-Awakening | Quando ficou assim |
| --- | --- | --- |
| Espada | Sistema de **Valour** (combos mistos que gastam pips) | Rework no patch 1.3.3, jul/2020 ([pinoygamer](https://pinoygamer.ph/articles/dauntless-is-back-with-a-new-ramsgate-and-reworked-sword-in-patch-1-3-3.9960/)) |
| Martelo | Munição + aetherslam + golpes "preparados" (sem rework grande depois de 2019) | OB/1.0 em diante |
| Lâminas | Refresh de combos por papel | Patch 1.8.3, 02/12/2021 ([mmobomb](https://www.mmobomb.com/news/dauntless-update-1-8-3-adds-mantis-like-behemoth-sahvyt-refreshes-chain-blades)) |
| Machado | Carga + Determinação + Resolve | Estável desde ~2019 |
| Lança | Estocadas/Ferimento + conversão do medidor em munição | Estável desde ~2019 |
| Repetidoras | Peças (cano/câmara/empunhadura/prisma), recarga empoderada por PROXIMIDADE | Rework de peças ~2019 |

O guia mais detalhado encontrado
([Nigh7mare, Google Doc](https://docs.google.com/document/d/1nUWSdxu5IsyIptd1IVLNQus5yADUgI3dyohYx0bI8PQ/mobilebasic))
é do patch **0.8.1 (2019)** — ótimo para Martelo/Machado/Lança (que mudaram
pouco), **inválido para Espada e parcialmente para Lâminas** (anteriores aos
reworks). Risco registrado: não conseguimos acessar a wiki Fandom (HTTP 402)
nem o archive.org nesta sessão; a verificação final por vídeo/captura da
build de nov/2024 continua pendente (critério do MEMORY.md).

---

## Espada (referência: pós-rework 1.3.3, vigente em 2024)

Fontes: [busca sobre a wiki Fandom/Sword](https://dauntless.fandom.com/wiki/Sword)
(conteúdo obtido via resumo de busca, não acesso direto),
[pinoygamer sobre o patch 1.3.3](https://pinoygamer.ph/articles/dauntless-is-back-with-a-new-ramsgate-and-reworked-sword-in-patch-1-3-3.9960/).

**EVIDÊNCIA:**

- Recurso **Valour**: máx. **6** pips.
- Combos núcleo (geram Valour):
  - *Frenzied Blade* = **L-L-L** → +1 Valour.
  - *Sundering Blade* = **H-H-H** → +2 Valour.
- Combos de Valour (custam **3** Valour cada):
  - *Crescent Strike* = **L-L-H** — golpe forte único, dano alto e confiável.
  - *Resounding Echo* = **H-L-H** — crava a espada no chão, deixa poça de dano
    por tempo (AoE tick).
  - *Blade Rush* = **segurar L** — investida de média distância com corte.
  - *Blade Surge* = **segurar H** — projétil de alcance que pode interromper
    Behemoths.
- Ou seja: a referência EXIGE sequências mistas — L-L-H ≠ H-H-H ≠ H-L-H.
- Ataque pós-esquiva: leve depois do rolamento dá uma **estocada (lunge)** que
  emenda nos cortes horizontais — existe desde o patch 0.2.4
  ([mmos.com](https://mmos.com/news/dauntless-dodge-attack-patch-0-2-4)).

**LACUNAS / ESCOLHA NOSSA:**

- O que sai de L-L-H **sem** 3 Valour não está documentado nas fontes
  acessadas. Escolha nossa: desvia para o primeiro pesado da cadeia pesada
  (sem reset para o início dos leves).
- Ataque saindo da corrida da espada não documentado. Escolha nossa: estocada
  de avanço própria.
- O destino dos Especiais antigos (Overdrive/Cyclone) após o rework não ficou
  confirmado (há vídeos de 1.3.3 com Ardent Cyclone). O nosso "Valor" (buff F)
  já aprovado em MEMORY.md fica como está; os pips de Valour das fichas são o
  recurso dos COMBOS, separado do Éter do Especial. Conflito de nomes
  Valor/Valour registrado — na ficha usamos **Brio** para os pips.

## Martelo (referência: estável desde 2019)

Fontes: [guia Nigh7mare 0.8.1](https://docs.google.com/document/d/1nUWSdxu5IsyIptd1IVLNQus5yADUgI3dyohYx0bI8PQ/mobilebasic)
(detalhe de moveset), [dauntlesswiki.com/hammer](https://dauntlesswiki.com/dauntless-hammer-guide/).

**EVIDÊNCIA (guia 0.8.1, confirmado em guias posteriores):**

- Todo combo de Martelo são **3 pancadas leves + finalizador aetherslam**
  (pesado ao fim do combo), que descarrega a munição restante em explosões no
  chão e recarrega com munição aethercarregada (+75% nos efeitos dela).
- Três variantes do combo leve por DIREÇÃO (parado = horizontais; andando à
  frente = verticais; misto = uppercuts). São variantes de animação/alcance da
  mesma cadeia de 3.
- **Golpe preparado (primed)**: ANTES de um leve conectar, apertar o pesado
  "prepara" aquele golpe, consumindo 1 munição e somando dano/atordoamento —
  a rajada encaixa ENTRE golpes do combo **sem resetá-lo**. É a assinatura.
- **Recarga encaixada (inline reload)**: apertar recarga imediatamente após um
  golpe do combo conectar devolve **+1 munição** sem quebrar o combo.
- Recarga com timing: barra com janela; acertar a janela encurta.
- **Salto de martelo**: correndo + pesado = salto com pancada; duplo toque =
  salto duplo. Golpes aéreos podem ser preparados.
- **Explosão evasiva**: duplo toque no pesado (sem corrida) = disparo que
  desloca o Caçador e pode interromper o Behemoth ("blast dodge",
  [shacknews](https://www.shacknews.com/article/111844/dauntless-weapon-guide-best-starter-weapon)).
- Segurar o pesado: cone concussivo que consome 1 munição por segundo
  (variante *Mighty Landbreaker* vira fissura de buff — é um Special/mod,
  fora do escopo do ticket 14).

**LACUNAS / ESCOLHA NOSSA:**

- Não confirmamos por fonte de 2024 que os golpes preparados e a recarga
  encaixada sobreviveram até a última build (nenhuma fonte diz que saíram;
  o kit do Martelo não teve refresh anunciado). Tratamos como presentes.
- As 3 variantes direcionais do combo leve NÃO entram no Lite por ora
  (uma cadeia só) — corte de escopo consciente, registrado na ficha.
- No Lite, recarga é R (decisão já feita); na referência era o botão de
  Special. Mantemos R.

## Lâminas Correntes (referência: pós-refresh 1.8.3, dez/2021)

Fontes: [anúncio oficial do refresh](https://playdauntless.com/news/chain-blades-refresh/)
(site fora do ar nesta sessão — HTTP 522; conteúdo obtido via resumos de
busca), [mmobomb](https://www.mmobomb.com/news/dauntless-update-1-8-3-adds-mantis-like-behemoth-sahvyt-refreshes-chain-blades),
guia 0.8.1 para o que o refresh não mudou.

**EVIDÊNCIA (pós-1.8.3):**

- *Bladed Edge* = **L×5** — combo clássico, melhor geração de medidor do kit
  (enche o medidor completando todos os acertos).
- *Blade Spin* = **L-L-L-(segurar H)-L** — o combo de dano: giro contínuo das
  lâminas à frente, pode andar/virar devagar durante o giro; o leve final é
  um corte cruzado pesado.
- *Lacerating Onslaught* = **H-H-H** — combo novo do refresh que causa
  **Ferimento** (antes exclusivo da Lança).
- *Chain Pull* = **direção + H à distância** — virou parte do moveset BÁSICO
  (separado dos Especiais no refresh): lança as correntes e puxa o Caçador
  até o alvo, custa vigor.
- Esquiva das Lâminas é um **dash/teleporte** curto em vez de rolamento, com
  i-frames perto do FIM do dash (guia 0.8.1 + [shacknews](https://www.shacknews.com/article/111844/dauntless-weapon-guide-best-starter-weapon)).
- *Reaper's Dance* (Special, perto do alvo): **salto mortal para trás** que
  evita ataques e reposiciona alguns metros atrás — é o "golpe de
  afastamento" citado no ticket; na referência mora no Special.

**EVIDÊNCIA pré-refresh (0.8.1), situação em 2024 incerta:**

- *Swinging Blades* = **L-L-H** — giro de área com bom alcance, multi-hit.
  O refresh não anuncia a remoção; tratamos como vigente, marcado provisório.

**LACUNAS / ESCOLHA NOSSA:**

- O nosso Golpe de Corrente (pesado colado gastando pips de Momentum) é
  mecânica JÁ APROVADA do Lite (MEMORY.md) sem equivalente 1:1 na referência;
  fica, integrado à árvore como entrada "pesado perto".
- O afastamento vira golpe de moveset no Lite (esquiva-para-trás + pesado),
  adaptação declarada do comportamento do Reaper's Dance.
- Ferimento ainda não existe na Sim (vem com a Lança, ticket 12); a cadeia
  H-H-H entra marcada como dependente.

## Machado (referência: estável; rework de Awakening não conta)

Fontes: [resumo de busca sobre a wiki/gamewith](https://dauntless.fandom.com/wiki/Axe),
guia 0.8.1 (seções detalhadas via resumos de busca),
[dauntlesswiki.com/axe](https://dauntlesswiki.com/dauntless-axe-guide/).

**EVIDÊNCIA:**

- Dois combos núcleo:
  - **Ripper Vertical** (cadeia vertical): 1º golpe = pancada de cima
    **carregável**; 2º = investida rápida; 3º = corte subindo + descendo,
    **carregável**; depois do 4º acerto, entra o **Ripper**: golpes verticais
    repetidos enquanto houver vigor, cada um mais rápido que o anterior.
  - **Fio Horizontal** (cadeia horizontal): 1º golpe carregável **andando**
    (custo alto de vigor, velocidade reduzida); 2º = investida; 3º/4º = dois
    golpes verticais saltados por cima, o primeiro carregável.
- **Carga**: segurar o botão segura o golpe no preparo e escala o dano;
  soltar no flash mais brilhante = carga perfeita.
- **Resolve**: carga completa/perfeita (nível 3 de carga vertical) dá
  super-armadura momentânea — imune a empurrão/cambaleio do Behemoth.
- **Determinação**: multiplicador de dano, acumula até **3 pilhas**, gerado
  por golpes carregados (horizontais ou verticais) conectados e por reativar
  o Special.
- Specials: *Flight of Ruin* (arremesso que gira, dana até voltar; recall
  manual pode dar boop) e *Grim Onslaught* (nível 8). São Specials — no Lite
  viram o F do ticket 11.

**LACUNAS / ESCOLHA NOSSA:**

- Taxas exatas de carga (tempo/escala) sem fonte: usamos os números do
  ticket 11 (~1.6x em 1 s), provisórios.
- A arma ainda não existe em src/. O pacote do ticket 11 foi publicado em
  `.scratch/hunt-3d/weapons/axe.md` DURANTE este trabalho; a ficha
  combos/axe.md já está conciliada com ele (o Ripper, o Resolve e a
  mobilidade foram remetidos por lá a este ticket).

## Lança de Guerra (referência: estável)

Fontes: [dauntlesswiki.com/war-pike](https://dauntlesswiki.com/dauntless-war-pike-guide/),
guia 0.8.1.

**EVIDÊNCIA:**

- Combo leve: **estocadas repetidas** (perfurantes, geram **Ferimento**);
  variante *Stabbing* = **L×5 segurando o botão no 5º** golpe.
- Combo pesado: **cortes/varreduras repetidos** — NÃO causam Ferimento.
- **Ferimento**: enche por dano perfurante na Parte; Parte Ferida (esfera
  azul) recebe bônus de dano de todas as armas (fonte dá +50% corte, +25%
  impacto, −25% perfuração — números a validar; o espírito: quem fere colhe
  menos, o grupo colhe mais).
- Medidor: convertível em munição; segurar para mirar e soltar para disparar
  o projétil de longo alcance; potência proporcional ao medidor convertido
  (*Concussive Payload* dispara míssil que dá boop; *Savage Wellspring* vira
  aura de buff — Specials, ticket 12).
- Ataques de mobilidade DOCUMENTADOS por nome:
  - *Running Stab* = **leve durante a corrida**.
  - *Jump Stab* = **leve depois da esquiva**.
  - *Knife in jump* = **pesado depois da esquiva**.

**LACUNAS / ESCOLHA NOSSA:**

- Combos mistos leve↔pesado da Lança não documentados; escolha nossa:
  alternar reinicia (sem desvio), exceto o 5º leve segurável.
- Arma ainda não existe em src/. Pacote do ticket 12 publicado em
  `.scratch/hunt-3d/weapons/pike.md` durante este trabalho; combos/pike.md
  já conciliado (kit de 4 leves + 2 pesados adotado; mobilidade e broca são
  deste ticket).

## Repetidoras (referência: estável pós-rework de peças)

Fontes: [dauntlesswiki.com/ostian-repeaters](https://dauntlesswiki.com/dauntless-ostian-repeaters-guide/),
[fextralife/Repeaters](https://dauntless.wiki.fextralife.com/Repeaters),
[resumo de busca sobre Marksman Chamber](https://dauntless.fandom.com/wiki/Ostian_Repeaters).

**EVIDÊNCIA:**

- **Não há árvore de combo corpo-a-corpo**: leve = tiro básico contínuo;
  pesado = habilidade da **Câmara** (tiro especial em linha: *Salvo* míssil
  explosivo 400, *Marksman* 250 + marca a Parte (+40% de dano de tiro por
  10 s), *Full-Bore* perfurante com queda por distância).
- Quatro peças trocáveis: cano (elemento), câmara (tiro especial),
  empunhadura (habilidade arremessada), prisma (passiva).
- **Recarga empoderada por PROXIMIDADE**: recarregar PERTO do Behemoth drena
  éter e empodera os próximos tiros/habilidades por um tempo (tiro básico
  empoderado sai em rajada de 3; Marksman empoderado: 80% + bônus de grupo).
- Dano consideravelmente maior DE PERTO (queda por distância).

**CONFLITO COM O TICKET 13 (resolvido na conciliação):** o texto do ticket
especificava recarga empoderada por **timing**; a referência usa
**proximidade**. O pacote do ticket 13 (`.scratch/hunt-3d/weapons/
repeaters.md`, publicado durante este trabalho) escolheu a versão fiel por
PROXIMIDADE e também fixou o pesado como Rolinho (dash). A ficha
combos/repeaters.md segue o pacote; cabe ao Gerente reverter se quiser o
timing do texto original.

**ESCOLHA NOSSA (conciliada):** as Repetidoras NÃO têm árvore de combo — o
tiro contínuo resolve fora da máquina (ramo `shot` do kit 13) e o pesado é
o Rolinho (estado). A máquina de combos precisa tolerar um grafo sem nós,
sem caso especial.

## Universais (todas as armas)

- Ataque pós-esquiva: documentado por nome para Espada (lunge, 0.2.4) e
  Lança (Jump Stab / Knife in jump); Martelo tem aéreos a partir do salto.
  Para as demais, EXISTEM variações mas sem fonte com sequência exata —
  as fichas definem versões nossas, marcadas como escolha.
- Ataque saindo da corrida: documentado para Lança (Running Stab) e Martelo
  (salto com pesado). Demais: escolha nossa, exigida pelo ticket.
- Esquiva das Lâminas é dash (não rolamento) na referência — anotado para o
  papel Mecânica; não é bloqueador das árvores.

## Fontes (lista completa)

1. Guia Nigh7mare (patch 0.8.1, 2019) — https://docs.google.com/document/d/1nUWSdxu5IsyIptd1IVLNQus5yADUgI3dyohYx0bI8PQ/mobilebasic
2. Sword/wiki Fandom (via resumos de busca; acesso direto bloqueado) — https://dauntless.fandom.com/wiki/Sword
3. Rework da Espada 1.3.3 — https://pinoygamer.ph/articles/dauntless-is-back-with-a-new-ramsgate-and-reworked-sword-in-patch-1-3-3.9960/
4. Refresh das Lâminas (oficial, fora do ar na sessão) — https://playdauntless.com/news/chain-blades-refresh/
5. Refresh das Lâminas 1.8.3 (cobertura) — https://www.mmobomb.com/news/dauntless-update-1-8-3-adds-mantis-like-behemoth-sahvyt-refreshes-chain-blades
6. Guia de Lança — https://dauntlesswiki.com/dauntless-war-pike-guide/
7. Guia de Machado — https://dauntlesswiki.com/dauntless-axe-guide/
8. Guia de Martelo — https://dauntlesswiki.com/dauntless-hammer-guide/
9. Guia de Repetidoras — https://dauntlesswiki.com/dauntless-ostian-repeaters-guide/
10. Repeaters/Fextralife — https://dauntless.wiki.fextralife.com/Repeaters
11. Dodge attack da Espada (patch 0.2.4) — https://mmos.com/news/dauntless-dodge-attack-patch-0-2-4
12. Guia geral de armas — https://www.shacknews.com/article/111844/dauntless-weapon-guide-best-starter-weapon

> Pendência de verificação: capturar vídeo/telemetria da build de nov/2024
> antes de fixar números finais (critério do MEMORY.md). Tudo que é número
> nas fichas está marcado como provisório.
