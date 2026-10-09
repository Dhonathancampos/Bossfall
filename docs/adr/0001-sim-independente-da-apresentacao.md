---
status: accepted
---

# A Simulação não conhece a apresentação, porque a Onda 2 será 3D

Este projeto tem duas ondas: a **Onda 1** é o jogo 2D visto de cima descrito em
`.scratch/core-hunt/spec.md`; a **Onda 2** é a recriação em 3D, fiel ao
Dauntless original, usando a Onda 1 como base. Por isso a `Sim` (movimento,
Golpes, dano, Elementos, Aflições, Partes, Atordoamento, IA do Behemoth,
condição de vitória) é escrita como GDScript puro — `RefCounted`, nunca `Node`,
nunca `Node2D`, nunca `CharacterBody2D` — e se comunica só por `set_input()` e
`snapshot()`. Posições e direções vivem num **plano de chão** em `Vector2`, que
em 3D vira `(x, z)` sem reescrita.

## Considered Options

A alternativa óbvia e mais rápida era construir direto sobre `CharacterBody2D`,
`Area2D` e `move_and_slide()`, deixando a física da Godot resolver colisão e
movimento. Em um projeto que fosse só 2D, essa seria a escolha certa: menos
código, menos chance de erro.

Foi rejeitada porque jogaria fora a Onda 2. Toda a regra de combate ficaria
presa a nós 2D e a reescrita em 3D começaria do zero — e é justamente a regra
de combate (tempos de Preparo/Ativo/Recuperação, tabela de Elementos,
Atordoamento, IA) que é cara de acertar e barata de transportar.

## Consequences

- A `Sim` resolve o próprio movimento e as próprias colisões (círculos contra
  círculos, limite circular da Arena). Não usa o motor de física da Godot.
- A camada de apresentação da Onda 1 vira descartável: na Onda 2 troca-se
  `Node2D` por `Node3D` e a `Sim` segue igual.
- Os testes rodam sem janela (`--headless`), porque não há cena envolvida.
- A autoridade do Anfitrião sai de graça: há exatamente um lugar onde o estado
  do jogo muda.
- Custa mais código na Onda 1 do que usar a física pronta. É o preço aceito.
