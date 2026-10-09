# 07: Martelo, Lâminas e Especiais (3D)

**What to build:** o antigo ticket 08, em 3D: as outras duas armas com seus
mecanismos (carga do Martelo, gancho das Lâminas), animações próprias e os 3
Especiais pagos com Éter.

**Blocked by:** 06

**Status:** done (mecânica completa; animações entram com o modelo do Caçador, ticket 03)

- [x] Martelo na Sim: lento, Impacto, carga segurando o botão
- [x] Lâminas na Sim: combo de 4, Corte, gancho que puxa
- [ ] Animações novas do Caçador para Martelo e Lâminas (com o papel Modelos — o Caçador ainda é cápsula)
- [x] Especiais: Valor (Espada), Câmara de Magma (Martelo, projétil),
      Dança da Ceifadora (Lâminas)
- [x] Projéteis existem na Sim e são replicados
- [x] Testes: carga, gancho, Éter, os 3 Especiais

## Nota pós-entrega (rework clássico)

A pedido do usuário, as armas foram retrabalhadas no estilo pré-Awakening:
a carga do Martelo deu lugar a **munições + Rajada Concussiva + recarga
cronometrada (R) + finalizador Estouro Aéter**; as Lâminas ganharam
**Momentum + Golpe de Corrente** (o Gancho continua, de longe); o Valor da
Espada passou a emitir **Ondas elementais** por Golpe conectado durante o
buff. Testes em tests/test_sim_rework.gd.
