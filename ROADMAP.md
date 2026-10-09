# Roadmap

**Decisão de 09/10/2026:** a Onda 2 começou antes de a Onda 1 terminar. O jogo
passa a ser 3D a partir daqui; os tickets 2D restantes foram absorvidos pelos
tickets 3D. A Onda 1 fica no histórico como a fundação que construiu a `Sim`.

---

## Onda 1 — Caçada Base, 2D visto de cima (encerrada)

**Estado:** encerrada com os tickets 01–05 entregues (projeto, rede
Hospedar/Entrar, Fôlego/Esquiva, Espada com Combos, Gnasher com Telegrafia e
Fúria). Os tickets 06–11 não serão feitos em 2D — o conteúdo deles renasce nos
tickets da Onda 2.

**O que ela deixou e continua valendo:**

- A **`Sim`** inteira: movimento, Golpes, Comprometimento, Combos, Esquiva com
  Invulnerabilidade, Fôlego, Éter, dano, Ameaça, Fúria, IA do Behemoth,
  Abatido. 62 testes, todos verdes, todos ainda rodando.
- A **rede**: Anfitrião autoritativo, predição do Caçador local, interpolação,
  Instantâneo por Cliente (MTU), lista de Caçadores fora do Instantâneo.
- O glossário (`CONTEXT.md`), o ADR 0001 e as ferramentas de verificação
  (`netcheck`, runner de testes).

## Onda 2 — Caçada 3D (em construção)

**Estado:** em construção.
**Spec:** `.scratch/hunt-3d/spec.md`
**Tickets:** `.scratch/hunt-3d/issues/`

A mesma experiência, em 3D com câmera em terceira pessoa:

- Modelos e animações **gerados por script no Blender** (headless, Python),
  exportados em `.glb` e importados pela Godot. Nenhum asset binário manual no
  repositório: os modelos são *compilados* a partir dos scripts, como código.
- Criaturas **originais no espírito dos arquétipos** do Dauntless (um
  quadrúpede mordedor, um voador de mergulho) — não cópias dos modelos do jogo,
  que são propriedade da Phoenix Labs/Forte.
- A `Sim` segue intocada: posições continuam no plano de chão (`Vector2`), que
  o 3D lê como `(x, z)`. A Telegrafia vira decalque no chão — a mesma área que
  machuca.
- O conteúdo dos antigos tickets 06–11 (Partes, Atordoamento, Elementos,
  Aflições, Martelo, Lâminas, Especiais, Shrike, Abatido/Reviver de verdade,
  lobby completo) entra direto em 3D.

## Ondas futuras (registradas em 09/10/2026, sem data)

Depois que a Onda 2 entregar a caçada 3D completa, entram as demais camadas do
jogo, em ondas separadas e nesta ordem provável:

- **Onda 3 — Progressão:** armaduras e **Células** (os encaixes de perk do
  original): equipamento muda os números e as vantagens do Caçador entre
  Caçadas, com salvamento local.
- **Onda 4 — Raids de masmorra:** sequência de salas com inimigos e um
  **boss** no fim, para o grupo atravessar — a camada PvE estendida por cima
  da arena única.

Nada dessas ondas deve ser construído durante a Onda 2, mas as decisões de
hoje não podem bloqueá-las: equipamento é dado (como armas já são), e a Arena
não pode ser a única sala possível no código da apresentação.

---

## Regras que continuam valendo

1. **Nenhuma regra de jogo fora da `Sim`.**
2. **Nenhum tipo de cena dentro da `Sim`.** Sem `Node`, `Node3D`,
   `CharacterBody3D`. Ver `docs/adr/0001-sim-independente-da-apresentacao.md`.
3. **Conteúdo é dado, não código.** E agora: **modelo é script, não binário** —
   todo asset 3D nasce de um script Blender versionado no repositório.
4. Interface e documentação em português; código e commits em inglês.
