# 12: Lança — Perfuração, Ferimento e Conversão Aetérica

**What to build:** a arma que finalmente usa o tipo **Perfuração** reservado
desde a Onda 1: estocadas rápidas que **Ferem** Partes, e o medidor que vira
munição de canhão de longo alcance.

**Blocked by:** 11

**Status:** ready-for-agent

- [ ] Nova arma `pike` em Weapons._DATA: tipo PIERCE, estocadas leves muito
      rápidas e lineares (arco estreito, alcance alto), pesado = varredura
- [ ] FERIMENTO (Wound) na Sim: dano de Perfuração acumula ferimento na Parte
      atingida; cheio, a Parte fica **Ferida** — brilho azul vazando éter,
      recebe bônus de dano de PARTE de todas as armas até quebrar (é a arma
      de suporte: a Lança fere, o grupo colhe)
- [ ] Medidor enche causando dano; pesado "colhe" dano causado em medidor
- [ ] Especial (F): **Conversão Aetérica** — converte o medidor em munição e
      dispara um projétil de longo alcance; potência proporcional ao medidor
      convertido
- [ ] HUD: medidor + indicador de Parte Ferida nas barras de Partes
- [ ] Modelo weapon_pike.py (papel Modelos)
- [ ] Testes: Perfuração acumula ferimento, Parte Ferida dá bônus de dano de
      parte para TODAS as armas, conversão escala com o medidor
