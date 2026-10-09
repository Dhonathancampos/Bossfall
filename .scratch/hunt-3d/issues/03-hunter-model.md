# 03: Caçador — modelo, rig e animações

**What to build:** a cápsula vira gente. Um humanoide low-poly gerado por
script, com as 12 animações do combate, trocando de animação conforme o que a
Sim diz que ele está fazendo — e a arma na mão.

**Blocked by:** 02

**Status:** done (animações específicas de Martelo/Lâminas/recarga ficam com Modelos na próxima leva)

- [x] tools/models/hunter.py gera humanoide low-poly riggado
- [x] Animações: idle, walk, sprint, dodge, light_1, light_2, light_3, heavy,
      hurt, downed, revive, drink
- [x] As durações dos Golpes vêm dos números de Weapons (windup/active/
      recovery), para o corpo contar o tempo exato do Comprometimento
- [x] AnimationTree segue o estado do Instantâneo (nunca decide nada)
- [x] Modelos das 3 armas (sword.py, hammer.py, blades.py) presos à mão
- [x] Cada Caçador remoto aparece com o próprio modelo, arma e cor
- [x] Captura de tela com o Caçador golpeando
