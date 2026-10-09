# Spec: Caçada 3D (`hunt-3d`) — Onda 2

Status: ready-for-agent · Substitui os tickets 06–11 de `core-hunt` (2D).

## Problem Statement

A Onda 1 provou as regras: o combate comprometido, a rede com Anfitrião
autoritativo e a IA do Behemoth funcionam, com 62 testes verdes. Mas a
experiência que o usuário quer recuperar é a do jogo original — câmera em
terceira pessoa atrás do Caçador, um monstro grande na sua frente, a arena ao
redor — e isso o 2D visto de cima não entrega.

## Solution

O mesmo jogo, com a apresentação refeita em 3D:

- **Câmera em terceira pessoa**: atrás do ombro, mouse gira, WASD anda
  relativo à câmera.
- **Modelos e animações gerados por script** no Blender headless (Python →
  `.glb`). Nenhum binário manual: `tools/models/*.py` são a fonte, e um
  comando regenera tudo.
- **Criaturas originais no espírito dos arquétipos** (quadrúpede mordedor,
  voador de mergulho). Nada de copiar os modelos do jogo original, que são
  propriedade de terceiros.
- **A `Sim` não muda.** Posição segue sendo plano de chão (x, z na cena 3D).
  Altura é efeito visual (salto do mergulho, voo) até o dia em que uma
  mecânica precisar dela de verdade.
- **Telegrafia como decalque no chão**: a mesma forma que machuca, agora
  projetada na arena.
- A rede (`NetGame`) não muda: ela nunca soube o que é desenhado.
- O conteúdo dos tickets 2D não feitos (Partes, Atordoamento, Elementos,
  Aflições, Martelo, Lâminas, Especiais, Shrike, Abatido/Reviver de verdade,
  lobby completo, HUD, resultado) entra direto em 3D.

## User Stories

As 98 histórias de `.scratch/core-hunt/spec.md` continuam valendo — a
experiência de jogo é a mesma. As novas, específicas do 3D:

1. Como Caçador, quero ver o mundo em terceira pessoa atrás do meu personagem, para ter a sensação do jogo original.
2. Como Caçador, quero girar a câmera com o mouse, para olhar em volta sem mudar minha direção de movimento.
3. Como Caçador, quero andar com WASD relativo à câmera, para que "frente" seja sempre para onde estou olhando.
4. Como Caçador, quero que meus Golpes saiam na direção da câmera, para mirar com o olhar como no jogo original.
5. Como Caçador, quero ver meu personagem como um humanoide animado que corre, rola e golpeia, para que cada estado do combate seja legível no corpo dele.
6. Como Caçador, quero ver o Behemoth como uma criatura grande e animada, para sentir o tamanho da caça.
7. Como Caçador, quero ver a Telegrafia projetada no chão em 3D, para continuar decidindo a Esquiva pela leitura do chão.
8. Como Caçador, quero ver a arma na mão do meu personagem, para saber de relance o que cada um do grupo usa.
9. Como Caçador, quero uma mira suave no Behemoth (a câmera favorece o alvo), para não brigar com a câmera durante a luta.
10. Como desenvolvedor, quero regenerar todos os modelos com um comando, para que arte quebrada se conserte como código quebrado.

## Implementation Decisions

### Pipeline de modelos

- Blender 4.2 LTS portable em `C:\Blender`, rodado sempre headless:
  `blender --background --python tools/models/<nome>.py`.
- Um script Python por modelo em `tools/models/`, construindo malha, rig,
  materiais (vertex color / paleta simples) e animações por keyframe.
- Saída em `assets/models/*.glb`, importados nativamente pela Godot.
- `tools/models/build_all.ps1` regenera tudo.
- Os `.glb` são artefatos de build: versionados para conveniência, mas a
  fonte da verdade são os scripts.

### Animações por modelo

- **Caçador** (humanoide, rig próprio simples — não Mixamo, para que o
  pipeline inteiro seja reproduzível por script): idle, walk, sprint, dodge,
  light_1, light_2, light_3, heavy, hurt, downed, revive, drink. As
  durações das animações de Golpe são gravadas pelos mesmos números de
  `Weapons` (windup/active/recovery), para o corpo contar o tempo exato.
- **Quadrúpede** ("Gnasher-like"): idle, walk, bite, charge, tail, stomp,
  enrage_roar, stagger_fall, death.
- **Voador** ("Shrike-like", ticket próprio): idle_fly, fly, dive, gust,
  feathers, stagger_fall, death.
- `AnimationTree` da Godot casa animação com o estado vindo do Instantâneo.
  Nenhuma animação decide regra: ela segue a `Sim`, nunca o contrário.

### Câmera e Entrada

- A câmera orbita o Caçador (yaw pelo mouse, pitch limitado); a mira
  (`aim`) enviada à `Sim` é o yaw da câmera. A `Sim` não sabe que existe
  câmera.
- WASD é rotacionado pelo yaw antes de virar `move` — a `Sim` continua
  recebendo um vetor no plano de chão.
- Mira suave: quando há Behemoth vivo e a câmera está aproximadamente
  olhando para ele, o yaw enviado é levemente puxado para o centro dele.

### Mapeamento 2D → 3D

- `Vector2(x, y)` da `Sim` vira `Vector3(x, altura_visual, y)` na cena.
- Escala: 1 unidade da `Sim` = 1 cm visual (Arena de raio 900 → 18 m de
  diâmetro na cena). Fator único, definido numa constante só.

### O que morre

- `arena_screen.gd`, `behemoth_view.gd` (desenho 2D) e o modo 2D do
  `screenshot.gd`. O menu continua `Control` (UI é UI).

## Testing Decisions

- Os 62 testes da `Sim` continuam valendo sem mudança — eram o objetivo da
  arquitetura e são a prova de que a Onda 2 custa só apresentação.
- O pipeline de modelos é verificado por um teste headless novo: gerar um
  modelo, importar na Godot, conferir que o `.glb` tem as animações com os
  nomes esperados.
- Câmera, animação e sensação continuam sendo validadas jogando e por
  capturas de tela (o `screenshot.gd` ganha um modo 3D).

## Out of Scope

- Tudo que já estava fora na Onda 1 (loot, progressão, hub, matchmaking).
- Altura mecânica (ataques que passam por cima, terreno irregular). A
  `Sim` continua plana; altura é visual.
- Fidelidade visual aos modelos do jogo original (propriedade de terceiros).
- Mixamo/assets externos: o pipeline é 100% script, para ser reproduzível.

## Further Notes

- O usuário tem TDAH: manter entregas pequenas e jogáveis. Cada ticket
  termina com algo visível na tela.
- Capturas de tela em todos os tickets visuais, antes de declarar pronto.
