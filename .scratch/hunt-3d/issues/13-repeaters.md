# 13: Pistolas (Repetidoras) — a arma de alcance

**What to build:** as pistolas duplas clássicas: tiro contínuo mirado, pente
com recarga, dano que cai com a distância — a primeira arma de alcance do
jogo, e a que muda como o grupo se distribui na Arena.

**Blocked by:** 12

**Status:** ready-for-agent

- [ ] Nova arma `repeaters` em Weapons._DATA: botão esquerdo segura para
      atirar continuamente (projéteis rápidos na Sim, ~5/s), tipo próprio de
      dano balístico tratado como Neutro físico de curto alcance
- [ ] PENTE: 12 tiros; R recarrega (~1.2s); recarga com timing (janela curta)
      devolve o pente INSTANTANEAMENTE e os próximos 12 tiros saem
      empoderados (+25%)
- [ ] QUEDA POR DISTÂNCIA: dano cheio até ~360 da Sim, caindo até 40% no
      alcance máximo (~900) — jogar perto é a recompensa, como no clássico
- [ ] Pesado: rolinho de esquiva curto próprio (dash lateral sem i-frames
      cheios) OU tiro concentrado — decidir na implementação com teste de uso
- [ ] Especial (F): rajada explosiva em área à frente
- [ ] HUD: contador de pente + marcador de tiro empoderado
- [ ] Modelo weapon_repeaters.py (papel Modelos) — par, canos exagerados
- [ ] Testes: cadência consome pente, recarga perfeita empodera, queda por
      distância nos dois degraus, projéteis replicados
