# Bestiário — novos Behemoths (papel: Creator)

Cinco criaturas originais, cada uma trazendo UMA mecânica que o motor ainda
não tem. É isso que faz o jogo passar de recriação a evolução: o Gnasher
ensina o básico, e cada monstro novo quebra uma suposição que o jogador tinha.

## Resumo

| # | Nome | Arquétipo | Mecânica nova | Elemento | Custo de motor |
|---|---|---|---|---|---|
| 01 | **Bastião** | Tanque blindado | Armadura antes da Vida (quebrar placas para o dano entrar) | Terra | Pequeno (FEITO) |
| 02 | **Fornalho** | Colosso de fase dupla | Troca de fase aos 50%: outro moveset, outras stats | Fogo | Pequeno-médio |
| 03 | **Brejara** | Controladora de área | Poças persistentes que encolhem a arena (Esquiva não resolve) | Trevas | Médio |
| 04 | **Vespreia** | Enxameadora ágil | Crias invocadas; matar cria enche o Atordoamento da rainha | Luz | Grande |
| 05 | **Faiscaia** | Duelista de relógio | Núcleo Errante: zona de acerto que migra pelo corpo + Descarga interruptível (boop como recurso central) | Elétrico | Médio-grande |

(Elementos nas fichas antigas usam os nomes pré-renomeação de 09/10 —
Incêndio/Umbral/Radiante/Gélido/Choque lêem-se Fogo/Trevas/Luz/Água/Elétrico.)

## Ordem de implementação recomendada (custo crescente)

1. **Bastião** — implementado (armadura com `ARMOR_LEAK`, penalidade do
   Rolamento). Falta o modelo próprio.
2. **Fornalho** — campo `phase` nos ataques (mesmo padrão do `requires_part`)
   + transição única em `step` + evento para o visual.
3. **Brejara** — lista de poças na Sim + dano por Tique + replicação +
   decalque. Infra reaproveitada pelo mergulho do voador e por arenas futuras.
4. **Faiscaia** — primeiro cliente de verdade do contrato novo (zonas
   offset+raio, `interruptible`, `telegraph`, cérebro por padrões): zona com
   offset dinâmico (2 campos no Instantâneo), gancho de dano no núcleo,
   `faiscaia_plan` com disparo por estado interno. Serve de validação do
   contrato que o Gnasher está estreando — por isso entra ANTES da Vespreia
   apesar do custo parecido.
5. **Vespreia** — entidades-cria com IA mínima + alvos múltiplos nos Golpes +
   replicação de N corpos. Infra que vira os inimigos menores das masmorras
   (Onda 4).

## Qual fazer primeiro: Bastião (feito) → Fornalho

O Bastião já entrou. A Brejara segue sendo o maior salto de experiência do
trio intermediário: a infra de poças paga a si mesma duas vezes (mergulho do
voador, variantes com lava). A Faiscaia depende do contrato novo
(zonas/interrupção) estar assentado com o Gnasher — não começar antes disso.

## Nota de coerência

Todos os números seguem as âncoras do Gnasher (hp 2600, danos 15-26, windups
0.48-1.10, knockbacks 180-420) e cabem na arena de raio 900. Exceções
declaradas: a Descarga Plena da Faiscaia (windup 2.0, dano 40) está fora da
faixa de propósito — é o centerpiece do boop e só dispara por condição do
cérebro, nunca por sorteio. Os formatos de ataque usam só os três shapes
existentes (cone/círculo/corredor). Campos novos propostos: `armored`
(Partes), `phase` e multiplicadores de fase, `spawns_pools`, `summons`,
`zone` (offset+raio por Parte, já no contrato novo), `telegraph`,
`interruptible`/`interrupt_bonus` e o relógio do Núcleo Errante — cada um
descrito no "custo de motor" da sua ficha.
