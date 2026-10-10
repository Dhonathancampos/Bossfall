# Espada — árvore completa (ticket 14)

Base: estado atual do repo (leves 0-2, pesados 0-2 com janela 0,30 s) +
referência pós-rework da Espada (PESQUISA.md). Recurso novo: **Brio**
(equivalente nosso ao Valour): pips 0..6, ganhos fechando cadeias, gastos nos
golpes de desvio. O Especial "Valor" (F, buff) NÃO muda neste ticket.

Todos os números são **provisórios**. Nomes de golpes são nossos.

## Ganho e gasto de Brio

- Fechar `l3` → **+1 Brio** (`ao_terminar: ["brio+1"]`).
- Fechar `h3` → **+2 Brio**.
- Golpes de Brio custam **3** (`ao_comecar: ["brio-3"]`). Máx. 6.
- `brio` viaja no Instantâneo (int pequeno) e aparece no HUD como pips.

## Grafo

```gdscript
"combo": {
    "entry": {
        "free": [
            {"input": "light_hold", "se": "brio>=3", "to": "investida_brio"},
            {"input": "heavy_hold", "se": "brio>=3", "to": "onda_brio"},
            {"input": "light", "to": "l1"},
            {"input": "heavy", "to": "h1"},
        ],
        "sprint": [ {"input": "light", "to": "estocada_corrida"},
                    {"input": "heavy", "to": "h1"} ],
        "dodge":  [ {"input": "light", "to": "bote_rasteiro"} ],
    },
    "nodes": {
        "l1": { "next": [ {"input": "light", "to": "l2"},
                          {"input": "heavy", "to": "h1"} ] },
        "l2": { "next": [ {"input": "light", "to": "l3"},
                          {"input": "heavy", "se": "brio>=3", "to": "meia_lua"},
                          {"input": "heavy", "to": "h1"} ] },
        "l3": { "ao_terminar": ["brio+1"],
                "next": [ {"input": "light", "to": "l1"},
                          {"input": "heavy", "to": "h1"} ] },
        "h1": { "next": [ {"input": "heavy", "to": "h2"},
                          {"input": "light", "to": "hl"} ] },
        "h2": { "next": [ {"input": "heavy", "to": "h3"},
                          {"input": "light", "to": "hl"} ] },
        "h3": { "ao_terminar": ["brio+2"],
                "next": [ {"input": "heavy", "to": "h1"},
                          {"input": "light", "to": "l1"} ] },
        # Transição leve dentro da cadeia pesada: H-L-H = Eco.
        "hl": { "next": [ {"input": "heavy", "se": "brio>=3", "to": "eco"},
                          {"input": "heavy", "to": "h2"},
                          {"input": "light", "to": "l2"} ] },
        # Golpes de Brio (gastam 3)
        "meia_lua":       { "ao_comecar": ["brio-3"],
                            "next": [ {"input": "light", "to": "l1"} ] },
        "eco":            { "ao_comecar": ["brio-3"], "next": [] },
        "investida_brio": { "ao_comecar": ["brio-3"],
                            "next": [ {"input": "light", "to": "l2"} ] },
        "onda_brio":      { "ao_comecar": ["brio-3"], "next": [] },
        # Mobilidade
        "estocada_corrida": { "next": [ {"input": "light", "to": "l2"} ] },
        "bote_rasteiro":    { "next": [ {"input": "light", "to": "l2"} ] },
    },
}
```

## Nós (números provisórios; l1-l3/h1-h3 = valores atuais do weapons.gd)

| id | Nome | O que é | windup/active/recovery | dano | stagger | janela |
| --- | --- | --- | --- | --- | --- | --- |
| l1 | Corte Horizontal | atual (índice 0) | 0.12/0.08/0.22 | 20 | 28 | 0.20 |
| l2 | Corte Ascendente | atual (1) | 0.11/0.08/0.24 | 23 | 30 | 0.22 |
| l3 | Giro Cortante | atual (2); fecha a cadeia, +1 Brio | 0.16/0.14/0.36 | 34 | 55 | 0.18 |
| h1 | Corte Pesado | atual (0) | 0.32/0.10/0.42 | 46 | 95 | 0.30 |
| h2 | Retorno Pesado | atual (1) | 0.28/0.10/0.38 | 48 | 100 | 0.30 |
| h3 | Finalizador Pesado | atual (2); +2 Brio | 0.36/0.14/0.46 | 64 | 130 | 0.30 |
| hl | Corte de Ligação | leve curto que mantém a cadeia pesada viva (L-L-H e H-L-H divergem AQUI) | 0.10/0.07/0.20 | 18 | 24 | 0.26 |
| meia_lua | Golpe de Meia-Lua | L-L-H com Brio: golpe único enorme (ref.: Crescent Strike) | 0.26/0.12/0.44 | 95 | 140 | 0.30 |
| eco | Eco Cravado | H-L-H com Brio: crava a espada, poça que pulsa dano 4×/0.5 s (ref.: Resounding Echo) | 0.30/0.10/0.60 | 30 + 4×12 | 60 | — |
| investida_brio | Investida de Brio | segurar L com Brio: avanço ~300 cm + corte (ref.: Blade Rush). EXCEÇÃO declarada à regra "golpe não locomove" | 0.18/0.12/0.30 | 55 | 70 | 0.26 |
| onda_brio | Onda de Brio | segurar H com Brio: projétil (reusa a infra da onda do Valor), pode interromper (ref.: Blade Surge) | 0.30/—/0.40 | 50 (projétil) | 160 | — |
| estocada_corrida | Estocada em Corrida | leve saindo do sprint, avanço curto | 0.10/0.08/0.24 | 24 | 30 | 0.26 |
| bote_rasteiro | Bote Rasteiro | leve logo após o rolamento: estocada que emenda em l2 (evidência: lunge pós-roll, patch 0.2.4) | 0.10/0.08/0.22 | 22 | 26 | 0.26 |

**Profundidade: 14 nós** (6 básicos + 1 ligação + 4 de Brio + 3 de mobilidade).

## Decisões e fidelidade

- L-L-H **sem** Brio desvia para `h1` (não reseta) — escolha nossa, lacuna de
  fonte.
- `hl` é invenção estrutural nossa para codificar H-L-H sem dar à cadeia
  leve inteira um segundo papel; na referência o leve do meio é um golpe de
  transição sem nome documentado.
- Interação Brio × Especial Valor: nenhuma neste ticket (Éter e Brio são
  medidores separados). Conflito de nome Valor/Valour registrado na PESQUISA.
- `eco` e `onda_brio` não encadeiam (next vazio): terminam o turno ofensivo,
  como finalizadores. Provisório; reavaliar na mão.
