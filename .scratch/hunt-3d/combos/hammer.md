# Martelo — árvore completa (ticket 14)

Base: estado atual (3 leves; pesado = segurar Rajada / Coronhada sem munição;
3º leve + pesado = Estouro Aéter; recarga R com janela) + referência
(PESQUISA.md): **golpe preparado** (pesado encaixado ENTRE leves consumindo 1
munição, sem resetar o combo — a assinatura da arma) e **recarga encaixada**
(R na janela de um golpe = +1 munição sem quebrar o combo).

Números provisórios. A decisão do MEMORY.md fica mantida: NÃO reintroduzir
carga contínua de "segurar para bater mais forte".

## Grafo

```gdscript
"combo": {
    "entry": {
        "free": [
            {"input": "light", "to": "p1"},
            {"input": "heavy_hold", "se": "ammo>=1", "to": "@charging"},
            {"input": "heavy", "se": "ammo==0", "to": "coronhada"},
            {"input": "heavy", "to": "@charging"},   # toque curto também arma
        ],
        "sprint": [ {"input": "heavy", "to": "salto_demolidor"},
                    {"input": "light", "to": "p1"} ],
        "dodge":  [ {"input": "light", "to": "pancada_curta"} ],
    },
    "nodes": {
        "p1": { "next": [ {"input": "light", "to": "p2"},
                          {"input": "heavy", "se": "ammo>=1", "to": "prep1"},
                          {"input": "reload", "efeito": ["ammo+1"]} ] },
        "p2": { "next": [ {"input": "light", "to": "p3"},
                          {"input": "heavy", "se": "ammo>=1", "to": "prep2"},
                          {"input": "reload", "efeito": ["ammo+1"]} ] },
        "p3": { "next": [ {"input": "heavy", "se": "ammo>=1", "to": "estouro"},
                          {"input": "light", "to": "p1"},
                          {"input": "reload", "efeito": ["ammo+1"]} ] },
        # Disparos encaixados: continuam a cadeia de onde ela estava.
        "prep1": { "ao_comecar": ["ammo-1"],
                   "next": [ {"input": "light", "to": "p2"} ] },
        "prep2": { "ao_comecar": ["ammo-1"],
                   "next": [ {"input": "light", "to": "p3"} ] },
        # Finalizador: descarrega todas as munições (nó atual "Estouro Aéter").
        "estouro": { "ao_comecar": ["ammo_all"], "next": [] },
        "coronhada": { "next": [ {"input": "light", "to": "p2"} ] },
        "salto_demolidor": { "next": [ {"input": "light", "to": "p3"} ] },
        "pancada_curta":   { "next": [ {"input": "light", "to": "p2"} ] },
    },
}
```

Notas de máquina:

- `{"input": "reload", "efeito": [...]}` sem `to`: transição-EFEITO — ganha
  1 munição, mantém `combo_from` e a janela correndo. É a recarga encaixada
  da referência. Limite: 1 por nó (não farmar munição parado); registrado
  como regra da máquina.
- Entrar em `@charging` a partir de `prep*`? NÃO: preparado é o caminho
  rápido; a Rajada segurável continua só como entrada (estado CHARGING
  atual, intocado).
- `@charging` preserva `combo_from` quando iniciado de dentro da janela de
  combo (regra 5 do MODELO.md) — soltar a Rajada e emendar o leve seguinte
  continua a cadeia. É o segundo jeito de "encaixar rajada sem resetar" do
  ticket.

## Nós (números provisórios; p1-p3 = leves atuais, estouro = pesado 2 atual)

| id | Nome | O que é | w/a/r | dano | stagger | janela |
| --- | --- | --- | --- | --- | --- | --- |
| p1 | Pancada Lateral | atual (0) | 0.22/0.10/0.34 | 30 | 34 | 0.24 |
| p2 | Retorno Pesado | atual (1) | 0.20/0.10/0.38 | 34 | 38 | 0.22 |
| p3 | Esmagada | atual (2) | 0.30/0.12/0.52 | 48 | 70 | 0.18 |
| prep1 | Disparo Encaixado I | pancada com cano: leve + explosão; −1 munição; não reseta | 0.14/0.10/0.30 | 26 + 18 (área) | 90 | 0.26 |
| prep2 | Disparo Encaixado II | idem, saindo de p2 | 0.14/0.10/0.30 | 26 + 18 | 95 | 0.26 |
| estouro | Estouro Aéter | atual (heavy 2): descarrega TODAS as munições num círculo | 0.30/0.15/0.70 | 20/munição | 110 | — |
| coronhada | Coronhada | atual (heavy 1): pesado sem munição | 0.18/0.10/0.34 | 16 | 40 | 0.24 |
| salto_demolidor | Salto Demolidor | correr + pesado: salto com pancada no chão (evidência: hammer jump). Desloca ~160 cm (exceção declarada ao "golpe não locomove") | 0.34/0.12/0.50 | 44 | 120 | 0.24 |
| pancada_curta | Pancada Curta | leve pós-esquiva: golpe rápido de levantada | 0.14/0.08/0.26 | 22 | 30 | 0.24 |

**Profundidade: 9 nós** + 2 pontes para estados (`@charging` via entry e a
regra de preservação do combo).

## Fora do escopo desta ficha (registrado)

- Variantes direcionais do combo leve (horizontais/verticais/uppercuts da
  referência): cortadas por ora — uma cadeia só.
- Explosão evasiva (duplo toque no pesado) e salto duplo: candidatas a
  ticket próprio de mobilidade do Martelo; exigem detecção de duplo toque
  no InputMap da Sim, que nenhuma outra arma precisa.
- Munição aethercarregada (+75% da referência ao acertar o estouro): anotada
  para balanceamento futuro, não entra agora.
