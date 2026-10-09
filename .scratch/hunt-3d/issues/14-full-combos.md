# 14: Combos completos e habilidades exclusivas de todas as armas

**What to build:** a gramática completa de combate do clássico: cada arma com
sua árvore de combos inteira (sequências leve/pesado intercaladas, finalizadores
distintos, desvios no meio da sequência) e suas habilidades exclusivas de
moveset — não só os golpes básicos de hoje.

**Blocked by:** 13 (entra depois das três armas novas, para fechar as 6 de uma vez)

**Status:** ready-for-agent

Nota de escopo: combos são estruturas de jogo (sequências, tempos, custos) —
implementação e nomes nossos, no espírito do clássico pré-Awakening. Pesquisar
as árvores por arma em guias da época antes de implementar e propor a
tradução de cada uma para os dados de `Weapons` antes de codar.

- [ ] A máquina de Golpes passa a suportar SEQUÊNCIAS MISTAS: o próximo golpe
      da árvore depende do histórico (ex.: leve-leve-pesado é um golpe
      diferente de pesado seco), não só do índice do combo leve
- [ ] Espada: árvore completa (combo leve, desvio pesado no meio, finalizador)
      + ataque em investida (golpe distinto saindo da corrida) + ataque
      saindo do rolamento
- [ ] Martelo: combos de 3 pancadas com finalizador de descarga, rajadas
      encaixáveis ENTRE golpes do combo sem resetá-lo (a assinatura da arma)
- [ ] Lâminas: árvore longa de leves, alternância perto/longe (gancho entra
      no meio do combo sem resetar), golpe de afastamento (empurrão para trás
      que abre espaço)
- [ ] Machado, Lança e Pistolas (tickets 11–13): mesma profundidade, com as
      sequências e desvios próprios de cada uma
- [ ] Ataques universais: golpe saindo da corrida e golpe saindo da Esquiva
      para TODAS as armas (dados por arma)
- [ ] Tela de ajuda/lobby mostra a árvore de combos da arma escolhida
- [ ] Testes: cada árvore percorrida golpe a golpe pela Sim (sequência,
      desvio, reset por janela perdida), investida e pós-esquiva por arma
