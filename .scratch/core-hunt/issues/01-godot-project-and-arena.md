# 01: Projeto Godot, Arena e Caçador que anda

**What to build:** abrir o projeto na Godot e ver um Caçador numa Arena
circular, andando com WASD e apontando para o cursor do mouse. Junto vem o
esqueleto da `Sim` e o runner de testes sem janela, que todo ticket seguinte
vai usar.

**Blocked by:** None (can start immediately)

**Status:** done

- [x] `godot --headless --script res://tests/run_tests.gd` roda e passa
- [x] Abrir o projeto mostra uma Arena circular com um Caçador
- [x] WASD move o Caçador em qualquer direção, com velocidade constante
- [x] O Caçador aponta para o cursor, independente da direção em que anda
- [x] O Caçador para na borda da Arena em vez de sair dela
- [x] A câmera segue o Caçador
- [x] A `Sim` expõe `set_input`, `step` e `snapshot`
- [x] A `Sim` não referencia nenhum tipo de cena (`Node`, `Node2D`, `Area2D`,
      `CharacterBody2D`, `move_and_slide`)
- [x] Teste: a mesma sequência de Entradas produz o mesmo Instantâneo
