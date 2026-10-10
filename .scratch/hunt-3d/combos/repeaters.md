# Repetidoras — ficha de combos (ticket 14)

**CONCILIADO com `.scratch/hunt-3d/weapons/repeaters.md` (ticket 13)**, que
é a fonte do kit — e que tomou duas decisões que SUBSTITUEM o rascunho
anterior desta ficha:

1. **Recarga empoderada por PROXIMIDADE** (fiel à referência), descartando a
   janela de timing que o texto do ticket 13 sugeria. Esta ficha segue o
   pacote; o conflito ticket×referência está documentado lá e na nossa
   PESQUISA.md — o Gerente arbitra se quiser reverter.
2. **Pesado = Rolinho** (estado `TUMBLE`, dash lateral curto), não um "tiro
   concentrado". O pesado das Repetidoras NÃO é um nó de combo.

Com isso, a verdade desta arma no modelo de grafo é: **as Repetidoras não
têm árvore de combo** — e isso é fidelidade, não lacuna (na referência o
kit é tiro contínuo + habilidades de peça, sem sequências corpo-a-corpo).

## O que a máquina de combos precisa garantir (os testes moram aqui)

- **Grafo vazio é válido.** `combo_graph("repeaters")` devolve `entry` sem
  candidatas de nó: o leve é resolvido ANTES do grafo pelo ramo de `shot`
  em `_step_free` (cadência `fire_interval`, pente, `wants_shot` — kit 13);
  o pesado resolve para `@tumble`. A máquina não pode exigir que toda arma
  tenha nós.

```gdscript
"combo": {
    "entry": {
        "free":   [ {"input": "heavy", "to": "@tumble"} ],
        # Tiro contínuo NÃO passa pelo grafo (ramo "shot" do kit 13).
        "sprint": [],
        "dodge":  [],
    },
    "nodes": {},
}
```

- **`combo_from` nunca fica sujo**: atirar, rolar (DODGE ou TUMBLE) e
  recarregar não gravam `combo_from`; trocar de arma (lobby/treinamento)
  zera. Teste de robustez: Caçador de Espada e de Repetidoras na mesma Sim,
  roteiros paralelos, nós/Instantâneos estáveis.

## Ataques universais do ticket (corrida e pós-esquiva) — como ficam aqui

O requisito "golpe saindo da corrida e da Esquiva para TODAS as armas" é
atendido de forma DEGENERADA e declarada:

- **Saindo da corrida**: no kit 13, sprint tem prioridade sobre o tiro
  (escolha registrada lá). Mantido: soltar o sprint com o leve seguro
  retoma o fogo no mesmo tique (`fire_cooldown` já replicado garante a
  cadência sem salto). Não há nó de corrida.
- **Saindo da esquiva**: o tiro não depende de estado ATTACK; ao sair de
  DODGE/TUMBLE, com o leve seguro e `fire_cooldown` vencido, o tiro sai no
  PRIMEIRO tique de FREE. O "golpe pós-esquiva" das Repetidoras é isso —
  retomada instantânea, não um golpe distinto.

Teste correspondente (TESTES.md §7): rolar segurando o leve → `wants_shot`
no 1º tique após a recuperação; correr → zero tiros durante o sprint →
retomada no 1º tique após soltar.

## Alternativa descartada (registrada para o Gerente)

O rascunho anterior desta ficha propunha nós `tiro_apressado` (atirar
correndo a 60% da velocidade) e `tiro_rolado` (disparo na saída do
rolamento) e um `tiro_concentrado` no pesado. Descartados na conciliação:
o kit 13 resolve tiro fora da máquina de combos, e duplicar o disparo em
nós criaria duas fontes de cadência/pente (bug de predição esperando para
acontecer). Se o teste de uso pedir "atirar correndo", a mudança certa é no
ramo de `shot` do kit 13 (prioridade sprint×tiro), não em nós.

**Profundidade: 0 nós** (+ `@tumble`; tiro/recarga/empoderamento no kit 13).

Números: todos do kit 13 (pente 12, 5 tiros/s, queda 360→900 até 40%,
empoderado +25%), provisórios como lá.
