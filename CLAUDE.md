# Dauntless Lite

Recriação simplificada e jogável do action-RPG de caça a monstros Dauntless
(Phoenix Labs, 2019–2025). Quem inicia a partida hospeda a Simulação
autoritativa; os demais Caçadores se conectam a ela.

O projeto tem duas ondas — a Onda 1 é 2D e está em construção, a Onda 2 é a
recriação 3D fiel que usa a Onda 1 como base. Ver `ROADMAP.md`.

## Regras que valem sempre

1. **Nenhuma regra de jogo fora da `Sim`.** A camada de desenho não decide nada.
2. **Nenhum tipo de cena dentro da `Sim`.** Sem `Node`, `Node2D`,
   `CharacterBody2D`, `Area2D`, `move_and_slide()`. Posição é `Vector2` no
   plano de chão, que na Onda 2 vira `(x, z)`.
   Ver `docs/adr/0001-sim-independente-da-apresentacao.md`.
3. **Conteúdo é dado, não código.** Armas, Golpes, Behemoths e ataques moram em
   tabelas.
4. **Interface e documentação em português; código, nomes de arquivo e commits
   em inglês.**

## Memória do projeto

Leia `MEMORY.md` antes de alterar mecânicas e atualize-o ao concluir qualquer
decisão ou mudança relevante.

## Rodar

- Jogo: abrir o projeto em `C:\Godot\Godot_v4.7.2-stable_mono_win64`.
- Testes: `godot --headless --script res://tests/run_tests.gd`

## Agent skills

### Issue tracker

Markdown local: issues e specs vivem em `.scratch/<feature>/`. Ver `docs/agents/issue-tracker.md`.

### Triage labels

Vocabulário padrão dos cinco papéis canônicos. Ver `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` na raiz + `docs/adr/`. Ver `docs/agents/domain.md`.
