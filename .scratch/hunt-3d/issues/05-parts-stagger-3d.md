# 05: Partes, Tipos de Dano e Atordoamento (3D)

**What to build:** o conteúdo do antigo ticket 06 (2D), direto em 3D: Partes
com Vida própria em regiões do corpo do modelo, Corte vs Impacto, quebra de
Parte com consequência e o medidor de Atordoamento que derruba o monstro.

**Blocked by:** 04

**Status:** done (visual da cauda decepada no modelo fica para o ticket 04)

- [x] Partes na Sim: cabeça, cauda, pernas — com Vida própria e região de
      acerto decidida pela posição do Golpe no plano
- [x] Corte bom contra cauda; Impacto bom contra cabeça e Atordoamento;
      Perfuração existe sem arma
- [x] Quebra: Atordoamento imediato, dano aumentado, cauda decepada some do
      modelo e remove a rabada do repertório
- [x] Atordoamento enche/esvazia; cheio derruba (stagger_fall); cada queda
      seguinte mais cara
- [x] Barras das Partes no HUD
- [x] Testes na Sim para tudo acima
