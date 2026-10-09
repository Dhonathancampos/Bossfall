# 11: Machado — carga e Determinação

**What to build:** a quarta arma, no estilo clássico: golpes seguráveis que
carregam dano, e o medidor que vira pilhas de **Determinação** — a arma de quem
aceita ser lento para bater absurdamente forte.

**Blocked by:** rework das armas (em andamento no papel Mecânica)

**Status:** ready-for-agent

- [ ] Nova arma `axe` em Weapons._DATA: Corte, arcos largos, alcance médio,
      os golpes mais lentos e fortes do jogo
- [ ] CARGA POR GOLPE: segurar o botão do golpe segura o Golpe no Preparo e
      escala dano/ganho de medidor (até ~1.6x em 1s); soltar dispara. Vale
      para leve e pesado (diferente do Martelo clássico, que não carrega)
- [ ] MEDIDOR interno enche com golpes carregados conectados
- [ ] DETERMINAÇÃO: disparar o Especial (F) com o medidor cheio concede 1
      pilha (máx 3), cada uma +15% de dano; a pilha decai sozinha, e decai
      mais rápido quanto mais pilhas — manter 3 exige agressão contínua
- [ ] Especial do Machado: **Voo da Ruína** — arremessa o machado em linha,
      que volta (projétil de ida e volta na Sim); pegar de volta no ar devolve
      parte do medidor
- [ ] HUD: medidor + pilhas de Determinação quando a arma é sua
- [ ] Modelo weapon_axe.py (papel Modelos) — exagerado, lâmina enorme
- [ ] Testes: carga escala, medidor enche só com carregado, pilhas somam/decaem
      com decaimento progressivo, arremesso vai e volta
