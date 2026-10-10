# Machado — árvore completa (ticket 14)

**CONCILIADO com `.scratch/hunt-3d/weapons/axe.md` (ticket 11)**, que é a
fonte do kit: 3 leves horizontais carregáveis (Talho Amplo, Talho de
Retorno, Ceifa Total), 2 pesados verticais carregáveis (Racha-Crânio, Queda
da Ruína), estado `AXE_CHARGE`, Determinação pelas pilhas do Voo da Ruína.
Aquele pacote declara FORA do escopo dele e REMETE a este ticket: o canal
"Ripper", o **Resolve** (super-armadura) e o andar durante a carga
horizontal. Esta ficha fecha essas pontas + corrida/pós-esquiva + desvios.

Números provisórios. Referência em PESQUISA.md (cadeias
horizontal/vertical, Ripper acelerando, Resolve na carga perfeita).

## Grafo (nós base = os 5 golpes do pacote do ticket 11)

```gdscript
"combo": {
    "entry": {
        # "light"/"light_hold" no MESMO destino: a carga é propriedade do nó
        # (chargeable) e passa pelo estado AXE_CHARGE do ticket 11; o grafo
        # só decide QUAL golpe sai ao soltar.
        "free": [
            {"input": "light", "to": "talho_amplo"},
            {"input": "heavy", "to": "racha_cranio"},
        ],
        "sprint": [ {"input": "light", "to": "ceifa_corrida"} ],
        "dodge":  [ {"input": "light", "to": "corte_erguido"} ],
    },
    "nodes": {
        # Cadeia horizontal (leve) — kit do ticket 11.
        "talho_amplo":   { "next": [ {"input": "light", "to": "talho_retorno"},
                                     {"input": "heavy", "to": "racha_cranio"} ] },
        "talho_retorno": { "next": [ {"input": "light", "to": "ceifa_total"},
                                     {"input": "heavy", "to": "queda_ruina"} ] },  # desvio
        "ceifa_total":   { "next": [ {"input": "heavy", "to": "queda_ruina"} ] },
        # Cadeia vertical (pesado) — kit do ticket 11.
        "racha_cranio": { "resolve_na_perfeita": true,
                          "next": [ {"input": "heavy", "to": "queda_ruina"},
                                    {"input": "light", "to": "talho_retorno"} ] },
        "queda_ruina":  { "resolve_na_perfeita": true,
                          "next": [ {"input": "heavy_hold", "to": "ceifa_continua"},
                                    {"input": "heavy", "to": "racha_cranio"} ] },
        # Fecho novo deste ticket: o canal do Ripper.
        "ceifa_continua": { "canal": true, "stamina_por_s": 18.0,
                            "acelera": 1.08, "next": [] },
        # Mobilidade (novos deste ticket)
        "ceifa_corrida": { "next": [ {"input": "light", "to": "talho_retorno"} ] },
        "corte_erguido": { "next": [ {"input": "heavy", "to": "queda_ruina"},
                                     {"input": "light", "to": "talho_retorno"} ] },
    },
}
```

## Nós novos deste ticket (números provisórios)

| id | Nome | O que é | w/a/r | dano | stagger | janela |
| --- | --- | --- | --- | --- | --- | --- |
| ceifa_continua | Ceifa Contínua | canal após Queda da Ruína: verticais repetidos enquanto segurar o pesado e houver vigor; cada ciclo 8% mais rápido (ref.: Ripper, remetido pelo ticket 11 a este) | 0.20 + ciclo 0.55/golpe | 34/golpe | 40/golpe | — |
| ceifa_corrida | Ceifa em Corrida | leve na corrida: varrida larga com o embalo | 0.24/0.14/0.40 | 44 | 50 | 0.28 |
| corte_erguido | Corte Erguido | leve pós-esquiva: corte ascendente de levantada | 0.18/0.10/0.32 | 36 | 40 | 0.28 |

Os 5 nós base usam exatamente os números de weapons/axe.md.

**Profundidade: 8 nós** (5 do kit + 3 novos) + estado `AXE_CHARGE`.

## Resolve — especificação (pendência remetida pelo ticket 11)

Seguindo a sugestão de weapons/axe.md §5:

- `resolve_time: float` no HunterState (replicado; default 0 em apply_dict).
- Nó com `resolve_na_perfeita`: soltar a carga dentro da janela `perfeita`
  do AXE_CHARGE concede `resolve_time = windup + active` do golpe (cobre o
  golpe inteiro; provisório).
- `take_hit` com `resolve_time > 0`: aplica o dano, mas NÃO troca o estado,
  NÃO aplica knockback (o golpe não é interrompido). i-frames não: Resolve
  tanka, não esquiva.

## Decisões de conciliação (registrar na integração)

1. **Carga andando**: o ticket 11 prende o corpo na v1 (reusa a regra do
   CHARGING testada) e remete a fidelidade a este ticket. Proposta deste
   ticket: carga de LEVE desloca a 30% da velocidade (`carga_movel` nos
   leves), carga de PESADO prende. Aplicar como fase separada, DEPOIS do
   pacote 11 estar verde.
2. **Determinação**: o pacote 11 dá pilhas pelo catch do Voo da Ruína. A
   referência também dá por golpes carregados (PESQUISA.md). Divergência
   REGISTRADA, sem mudança aqui: balanceamento futuro decide se golpes
   carregados perfeitos também geram pilha (gancho de efeito
   `ao_terminar: ["det+1"]` fica disponível na máquina).
3. Desvios leve↔pesado no meio (talho_retorno→queda_ruina,
   racha_cranio→talho_retorno) são escolha nossa (a referência documenta as
   cadeias desembocando uma na outra; a aresta reproduz isso sem duplicar
   nós).
4. O índice de combo que o AXE_CHARGE guarda (ticket 11 decide o índice ao
   ENTRAR na carga, com a combo_grace atual) passa a ser o id do nó
   resolvido pelo grafo — mesma costura, fonte nova (ver MIGRACAO.md).
