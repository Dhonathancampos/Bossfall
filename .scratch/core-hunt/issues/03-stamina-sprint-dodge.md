# 03: Fôlego, corrida e Esquiva

**What to build:** o Caçador passa a ter um recurso que limita o que ele pode
fazer. Corre segurando Shift, rola com Espaço, e um rolamento no tempo certo
atravessa qualquer coisa sem levar dano.

**Blocked by:** 02

**Status:** done

- [x] Barra de Fôlego visível na tela
- [x] Shift corre e drena Fôlego enquanto estiver correndo
- [x] Com o Fôlego vazio não dá para correr
- [x] Espaço rola na direção do movimento, ou na direção da mira se parado
- [x] O rolamento custa Fôlego e não acontece sem Fôlego suficiente
- [x] Durante parte do rolamento o Caçador fica Invulnerável
- [x] O rolamento tem uma recuperação curta no fim, antes de poder rolar de novo
- [x] O Fôlego regenera sozinho após uma pausa curta sem gastar
- [x] O Fôlego e o estado de Esquiva aparecem no Instantâneo e chegam aos Clientes
- [x] Testes: gasto, bloqueio por falta, regeneração após pausa, e que a
      Invulnerabilidade existe dentro da janela e não fora dela
