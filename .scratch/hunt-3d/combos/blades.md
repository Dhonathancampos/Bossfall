# Lâminas Correntes — árvore completa (ticket 14)

Base: estado atual (4 leves; pesado = Gancho longe / Golpe de Corrente perto,
com pips de Momentum) + referência pós-refresh 1.8.3 (PESQUISA.md): combo
leve de 5, giro segurável no meio da cadeia com corte cruzado final, cadeia
pesada de Ferimento, gancho como parte do moveset que NÃO reseta o combo, e
afastamento que abre espaço.

Números provisórios. Momentum/pips e o Especial (Dança da Ceifadora) não
mudam neste ticket.

## Grafo

```gdscript
"combo": {
    "entry": {
        "free": [
            {"input": "light", "to": "t1"},
            {"input": "heavy", "se": "perto", "to": "corrente"},
            {"input": "heavy", "se": "longe", "to": "@hook"},
            # Sem world (predição) o pesado não resolve aqui; o Instantâneo
            # corrige — contrato atual do Gancho, mantido.
        ],
        "sprint": [ {"input": "light", "to": "talho_corrida"} ],
        "dodge":  [ {"input": "light", "to": "cruzado_rasante"},
                    {"input": "heavy", "se": "recuo", "to": "salto_recuo"} ],
    },
    "nodes": {
        "t1": { "next": [ {"input": "light", "to": "t2"},
                          {"input": "heavy", "se": "longe", "to": "@hook"},
                          {"input": "heavy", "to": "h1"} ] },
        "t2": { "next": [ {"input": "light", "to": "t3"},
                          {"input": "heavy", "se": "longe", "to": "@hook"},
                          {"input": "heavy", "to": "giro_amplo"} ] },
        "t3": { "next": [ {"input": "light", "to": "t4"},
                          {"input": "heavy_hold", "to": "roda_viva"},
                          {"input": "heavy", "se": "longe", "to": "@hook"} ] },
        "t4": { "next": [ {"input": "light", "to": "t5"} ] },
        "t5": { "next": [ {"input": "light", "to": "t1"} ] },
        # L-L-H: giro de área multi-hit (ref. pré-refresh Swinging Blades).
        "giro_amplo": { "next": [ {"input": "light", "to": "corte_cruzado"} ] },
        # L-L-L-(segurar H): canal giratório; anda devagar; drena vigor.
        "roda_viva": { "canal": true, "stamina_por_s": 14.0,
                       "next": [ {"input": "light", "to": "corte_cruzado"} ] },
        "corte_cruzado": { "next": [] },
        # Cadeia pesada de Ferimento (ref. Lacerating Onslaught).
        "h1": { "next": [ {"input": "heavy", "to": "h2"} ] },
        "h2": { "next": [ {"input": "heavy", "to": "h3"} ] },
        "h3": { "next": [] },
        # Pesado colado gastando pips (mecânica aprovada do Lite, mantida).
        "corrente": { "ao_comecar": ["pips_all"],
                      "next": [ {"input": "light", "to": "t3"} ] },
        # Mobilidade
        "talho_corrida":   { "next": [ {"input": "light", "to": "t2"} ] },
        "cruzado_rasante": { "next": [ {"input": "light", "to": "t2"} ] },
        "salto_recuo":     { "next": [] },
    },
}
```

Regras que esta arma exercita na máquina:

- **Gancho no meio do combo sem resetar**: `@hook` preserva `combo_from` e
  congela `combo_grace` durante o puxão (regra 5 do MODELO.md). Chegar
  colado e apertar leve continua de onde a cadeia estava. Item explícito do
  ticket.
- `heavy_hold` em t3 vs `heavy` em t2: é o par que prova que a máquina
  distingue toque de segurada no MESMO botão em nós vizinhos.
- `se: "recuo"` no pós-esquiva: esquiva para TRÁS (dodge_dir contrária ao
  facing) + pesado = salto de recuo. Predicado novo barato (dot product de
  estado replicado); marcado como adaptação do backflip do Reaper's Dance,
  que na referência mora no Special.

## Nós (t1-t4 = leves atuais; corrente = heavy 1 atual)

| id | Nome | O que é | w/a/r | dano | stagger | janela |
| --- | --- | --- | --- | --- | --- | --- |
| t1 | Talho Cruzado | atual (0) | 0.08/0.06/0.14 | 11 | 10 | 0.22 |
| t2 | Talho Reverso | atual (1) | 0.07/0.06/0.14 | 11 | 10 | 0.22 |
| t3 | Tesoura | atual (2) | 0.09/0.07/0.16 | 14 | 12 | 0.22 |
| t4 | Redemoinho | atual (3) | 0.12/0.10/0.26 | 20 | 18 | 0.20 |
| t5 | Lâmina Dupla | 5º leve novo: fecha a cadeia com o melhor ganho de Momentum (ref.: Bladed Edge ×5 = melhor geração de medidor). Momentum: +50 em vez de +34 (provisório) | 0.10/0.08/0.20 | 18 | 16 | 0.22 |
| giro_amplo | Giro Amplo | L-L-H: giro multi-hit de área (3 ticks de 8) | 0.12/0.30/0.24 | 3×8 | 20 | 0.24 |
| roda_viva | Roda Viva | canal: gira enquanto segurar H (≤2,5 s ou vigor), tick 0,25 s, anda a 30% | 0.12/canal/0.28 | 7/tick | 5/tick | 0.24 |
| corte_cruzado | Corte Cruzado | leve final após giro: o cross slash pesado da referência | 0.10/0.08/0.22 | 30 | 28 | — |
| h1-h3 | Dentes da Corrente I-III | cadeia pesada: multi-hit que causará **Ferimento** quando a Sim ganhar o sistema (ticket 12). Até lá: dano/parte comuns, marcado | 0.14/0.10/0.24 | 16/17/22 | 14 | 0.24 |
| corrente | Golpe de Corrente | atual: gasta todos os pips | 0.14/0.10/0.30 | 22 + escala | 20 | 0.24 |
| talho_corrida | Talho em Disparada | leve na corrida: corte com o embalo | 0.08/0.08/0.18 | 16 | 12 | 0.24 |
| cruzado_rasante | Cruzado Rasante | leve pós-esquiva (dash): corte duplo saindo do deslize | 0.08/0.08/0.18 | 18 | 14 | 0.24 |
| salto_recuo | Salto de Recuo | esquiva p/ trás + pesado: mortal para trás ~220 cm, sem dano, i-frames parciais no início (provisório) — abre espaço | 0.10/—/0.30 | 0 | 0 | — |

**Profundidade: 16 nós** + ponte `@hook`.

## Pendências registradas

- `giro_amplo` (L-L-H) tem evidência só pré-refresh; se a revisão decidir que
  o refresh o removeu, a aresta sai sem afetar o resto.
- h1-h3 dependem do Ferimento (ticket 12); entram atrás de flag ou com dano
  comum até lá.
- Esquiva-dash das Lâminas (em vez de rolamento) anotada na PESQUISA; é do
  papel Mecânica, não bloqueia esta árvore.
