# Lança de Guerra — árvore completa (ticket 14)

**CONCILIADO com `.scratch/hunt-3d/weapons/pike.md` (ticket 12)**, fonte do
kit: 4 leves perfurantes (Estocada, Estocada Dupla, Estocada Alta,
Perfurante Final), 2 pesados (Varredura, Estocada Profunda), Ferimento nas
Partes, Conversão Aetérica como Especial. Aquele pacote remete a este
ticket o "Pike Charge" (investida) e os golpes de mobilidade. Esta ficha
fecha a árvore: canal do 4º leve, desvios leve↔pesado, corrida e
pós-esquiva.

Números provisórios. Referência em PESQUISA.md (Stabbing com segurada no
final, Running Stab, Jump Stab, pesado pós-esquiva — os três últimos
documentados por nome em guia).

## Grafo (nós base = os 6 golpes do pacote do ticket 12)

```gdscript
"combo": {
    "entry": {
        "free": [
            {"input": "light", "to": "e1"},
            {"input": "heavy", "to": "varredura"},
        ],
        "sprint": [ {"input": "light", "to": "estocada_disparada"} ],
        "dodge":  [ {"input": "light", "to": "estocada_rasante"},
                    {"input": "heavy", "to": "varredura_saltada"} ],
    },
    "nodes": {
        # Estocadas (kit 12): e1 Estocada, e2 Estocada Dupla, e3 Estocada
        # Alta, e4 Perfurante Final. Alternância desvia, não reseta.
        "e1": { "next": [ {"input": "light", "to": "e2"},
                          {"input": "heavy", "to": "varredura"} ] },
        "e2": { "next": [ {"input": "light", "to": "e3"},
                          {"input": "heavy", "to": "varredura"} ] },
        "e3": { "next": [ {"input": "light", "to": "e4"},
                          {"input": "light_hold", "to": "broca"},
                          {"input": "heavy", "to": "varredura"} ] },
        "e4": { "next": [ {"input": "light", "to": "e1"} ] },
        # Segurar o leve no fim da cadeia: perfuração contínua (ref.:
        # "Stabbing" segura o último golpe; o kit 12 tem 4 leves, não 5 —
        # a segurada entra no 4º. Divergência registrada abaixo.)
        "broca": { "canal": true, "stamina_por_s": 12.0, "next": [] },
        # Varreduras (kit 12)
        "varredura":         { "next": [ {"input": "heavy", "to": "estocada_profunda"},
                                         {"input": "light", "to": "e2"} ] },
        "estocada_profunda": { "next": [ {"input": "light", "to": "e2"} ] },
        # Mobilidade (novos deste ticket)
        "estocada_disparada": { "next": [ {"input": "light", "to": "e2"} ] },
        "estocada_rasante":   { "next": [ {"input": "light", "to": "e2"} ] },
        "varredura_saltada":  { "next": [ {"input": "heavy", "to": "estocada_profunda"} ] },
    },
}
```

## Nós novos deste ticket (números provisórios)

| id | Nome | O que é | w/a/r | dano | stagger | janela |
| --- | --- | --- | --- | --- | --- | --- |
| broca | Broca | segurar o leve ao fim de e3: perfuração contínua no lugar, tick 0,2 s enquanto segurar/houver vigor; acumula Ferimento rápido (6/tick de dano PIERCE) | 0.12/canal/0.26 | 6/tick | 2/tick | — |
| estocada_disparada | Estocada Disparada | corrida + leve: estocada com avanço curto (~120 cm) que fecha distância (ref.: Running Stab; o "Pike Charge" remetido pelo ticket 12 entra como ESTE nó). Exceção declarada ao "golpe não locomove" | 0.10/0.08/0.22 | 20 | 12 | 0.26 |
| estocada_rasante | Estocada Rasante | leve pós-esquiva: estocada baixa saindo do rolamento (ref.: Jump Stab) | 0.10/0.08/0.20 | 18 | 10 | 0.26 |
| varredura_saltada | Varredura Saltada | pesado pós-esquiva: corte saltado de reentrada (ref.: "Knife in jump") | 0.16/0.10/0.28 | 26 | 30 | 0.26 |

Os 6 nós base usam exatamente os números de weapons/pike.md.

**Profundidade: 10 nós.**

## Decisões de conciliação (registrar na integração)

1. **4 leves, não 5**: a referência descreve 5 estocadas com segurada na 5ª;
   o kit 12 fechou em 4. A árvore segue o kit (a segurada entra como
   `light_hold` em e3, disparando a broca no lugar do Perfurante Final).
   Se o balanceamento pedir a 5ª, é um nó a mais entre e4 e e1.
2. **Desvio sem reset nos dois sentidos** (e_k→varredura, varredura→e2):
   escolha nossa — não há fonte de combo misto da Lança; o objetivo é a
   Lança falar o mesmo idioma de desvio das outras armas.
3. Ferimento: os leves e a broca acumulam (PIERCE, regra do kit 12);
   varreduras NÃO (impulso de medidor/colheita fica como está no kit 12 —
   nenhum efeito novo nesta árvore).
4. A mira segurável da Conversão ("segurar para mirar") continua fora da
   árvore: é Especial/estado, decisão do ticket 12 mantida.
