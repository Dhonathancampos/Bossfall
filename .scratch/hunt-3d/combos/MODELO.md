# Modelo — máquina de combos por grafo de nós (ticket 14)

Projeto pronto para integrar. NÃO implementado: src/ está sendo reconstruído
por outro agente; quem integrar deve rebasear este modelo sobre o estado novo.

## O problema com o sistema atual

Hoje (`hunter_step.gd::_begin_attack`) o encadeamento é: um índice por TIPO
(`combo_next`), válido só se o próximo golpe for do MESMO tipo
(`attack_kind == kind`), dentro de uma janela (`combo_grace`). Consequências:

- Alternar leve/pesado **reseta** — mas a referência define golpes que SÓ
  existem alternando (Espada L-L-H ≠ H-L-H; Lâminas L-L-L-(seg.H)-L).
- Desvios que não resetam (Martelo preparado, gancho no meio do combo) são
  casos especiais codados em `_begin_heavy`/`_finish_attack`, um por arma.
- Corrida e pós-esquiva não têm entrada própria na sequência.

## Proposta: grafo de combo como dados (`combo` por arma)

Cada arma declara um grafo. **Nó** = um Golpe (as mesmas fases
Preparo/Ativo/Recuperação de hoje). **Transição** = o que cada entrada faz a
partir daquele nó. O histórico vira posição no grafo: não guardamos "L,L"
em lugar nenhum — estar no nó `l2` JÁ É ter vindo de L,L.

```gdscript
"combo": {
    # Entradas por contexto. Lista ordenada: a primeira candidata cujo
    # "se" passa vence (como as cláusulas de um match).
    "entry": {
        "free":   [ {"input": "light", "to": "l1"},
                    {"input": "heavy", "se": "perto", "to": "slam"},
                    {"input": "heavy", "se": "longe", "to": "@hook"},
                    {"input": "heavy_hold", "se": "brio>=3", "to": "surge"} ],
        "sprint": [ {"input": "light", "to": "run_l"} ],      # saindo da corrida
        "dodge":  [ {"input": "light", "to": "dodge_l"} ],    # pós-esquiva
    },
    "nodes": {
        "l1": {
            "name": "Corte Horizontal",
            "windup": 0.12, "active": 0.08, "recovery": 0.22,
            "damage": 20.0, "stagger": 28.0, "part": 1.0,
            "range": 92.0, "arc": 1.7, "stamina": 0.0, "aether": 5.0,
            "window": 0.30,          # ex-combo_window
            "animation": "light_1",
            "next": [ {"input": "light", "to": "l2"},
                      {"input": "heavy", "to": "h1"} ],
            # opcionais: "ao_comecar": ["brio-3"], "ao_terminar": ["brio+1"],
            #            "canal": true, "carga": {...}
        },
        ...
    },
}
```

### Vocabulários (fechados, interpretados pela máquina — nunca código por arma)

- **input**: `light`, `heavy`, `light_hold`, `heavy_hold`, `reload`.
  (`light_hold` exige `light_held` em `HunterInput` — hoje só existe
  `heavy_held`; mudança pequena e replicável.)
- **se** (predicados de transição): `brio>=n`, `ammo>=n`, `ammo==0`,
  `pips>=n`, `perto`, `longe`, `sem_mundo`. `perto/longe` usam `world`;
  na predição do Cliente (world vazio) vale a candidata `sem_mundo` se
  declarada, senão a transição falha — exatamente o contrato atual do Gancho.
- **efeitos** (`ao_comecar`/`ao_terminar`): `brio+n`, `brio-n`, `ammo-1`,
  `ammo+1`, `ammo_all` (trava a descarga no golpe, estilo blast_ammo),
  `pips_all` (estilo slam_pips). Lista curta; crescer o vocabulário é
  decisão de revisão, não de ficha.
- **`to: "@hook"`**: prefixo `@` = transições para ESTADOS da máquina
  (HOOK_PULL, CHARGING), não para nós. O grafo decide QUANDO; o estado
  continua decidindo COMO (puxão, carga). Nada do estado muda de dono.
- **nós especiais**: `"canal": true` = o golpe se sustenta enquanto o botão
  estiver seguro, drenando vigor (Ripper do Machado, Giro das Lâminas,
  Broca da Lança); `"carga": {max: 1.0, escala: 1.6, perfeita: [a,b]}` =
  preparo segurável que escala dano (Machado).

### Regras da máquina (substituem `combo_next`/`combo_grace` parcialmente)

1. Ao TERMINAR um nó, a Sim grava `combo_from = nó` e arma
   `combo_grace = window` do nó. (Mesma semântica de janela de hoje:
   buffer durante o golpe, janela depois da recuperação.)
2. Entrada dentro da janela (ou bufferizada): procura em
   `nodes[combo_from].next`; sem candidata válida, cai na `entry` do
   contexto atual (free). **Desvio ≠ reset**: desvio é só uma aresta.
3. Janela expirada → `combo_from = -1` → só `entry` responde.
4. Contextos: `sprint` vale se o Caçador vinha correndo (velocidade de
   sprint sustentada por N tiques — N provisório); `dodge` vale por uma
   janela curta após o fim do rolamento (provisório: 0,25 s). Ambos são
   deriváveis do estado replicado (velocity/state/state_time) — nada novo
   viaja no Instantâneo para isso.
5. Transições que não resetam por fora do grafo: entrar em `@hook` ou
   `@charging` **preserva** `combo_from` e congela `combo_grace` até voltar
   (é o que faz o gancho e a rajada encaixarem no meio do combo).
6. `reload` como input de transição: no Martelo, R dentro da janela de um nó
   do combo = efeito `ammo+1` sem trocar de nó e sem zerar a janela
   (recarga encaixada). Fora de combo, R segue para o estado RELOADING como
   hoje.

### Replicação e Instantâneo

- `attack_index` passa a ser o **id do nó** (posição numa lista achatada e
  determinística por arma: primeiro os nós que espelham a lista `light`
  atual, depois os da `heavy`, depois os novos — os ids 0..N dos golpes
  atuais NÃO mudam, o que preserva replays/testes dos combos básicos).
- `attack_kind` continua existindo e replicado (a View escolhe animação por
  ele), mas vira DERIVADO do nó (`kind` declarado no nó).
- `combo_next` (int) sai do Instantâneo; entra `combo_from` (int, -1 = nada).
  Mesmo custo de bytes. `combo_grace` fica como está.
- Recursos novos por arma entram como campos normais (ex.: `brio` da
  Espada), com default em `apply_dict` — Instantâneo antigo não derruba.
- Predição do Cliente continua exata: o grafo é dado estático compartilhado;
  as transições dependem só de (nó atual, entrada, recursos replicados,
  world). Sem world, vale a regra `sem_mundo` — determinística dos dois
  lados, corrigida pelo Instantâneo como hoje (contrato atual do Gancho).

### Fases de um golpe, dano, acerto: NADA muda

O nó carrega os mesmos campos de um Golpe de hoje. `Combat`, `hit_ids`,
eventos, Éter, tudo continua lendo `current_move()` — que passa a resolver
`weapon.combo.nodes[node_order[attack_index]]`.

## Alternativa descartada: caminho textual ("LLH")

Guardar o histórico de entradas ("LLH") e casar contra uma tabela de padrões
por prefixo mais longo.

- Precisa replicar o histórico no Instantâneo (string/array que cresce) ou
  aceitarmos divergência de predição ao reconciliar no meio de um combo.
- Ambiguidade: "LLH" também é prefixo de "LLHL"; exige regra de desempate e
  lookahead — a máquina deixa de ser O(1) por entrada.
- Desvios que voltam (preparado do Martelo: L-H-L continua a cadeia leve)
  não são um PADRÃO, são um retorno — em texto vira regex; em grafo é uma
  aresta.
- O grafo já é a forma compilada disso: cada nó é uma classe de equivalência
  de históricos. Mesmo poder, estado menor (1 int), predição trivial.

Segunda alternativa descartada: máquina scriptada por arma (um .gd por
arma). Viola a regra do projeto "arma nova = entrada de dados" e duplicaria
a lógica que a predição do Cliente precisa espelhar com exatidão.

## Conciliação com `.scratch/hunt-3d/weapons/` (publicado durante este projeto)

O pacote dos tickets 11–13 apareceu enquanto esta pasta era escrita; os dois
projetos foram conciliados:

- `light_held` já está especificado LÁ (INTEGRACAO.md, com chave "lheld" e
  preservação em `_next_input`) — este modelo USA aquele campo, não cria
  outro.
- Os `@estados` deste grafo mapeiam para os estados daquele pacote:
  `@charging` (Martelo, existente), `@hook` (existente), `@tumble` e o
  AXE_CHARGE do Machado (novos lá, no FIM do enum). A carga do Machado
  continua sendo um ESTADO (kit 11); o grafo só escolhe o nó que sai ao
  soltar.
- O ramo `shot` das Repetidoras resolve o tiro FORA do grafo (ver
  repeaters.md desta pasta): a máquina precisa aceitar grafo sem nós.
- Ordem de aplicação: o pacote 11–13 entra ANTES da troca de máquina
  (MIGRACAO.md Fase 4 vira "ligar os grafos por cima dos kits aplicados").

## O que precisa mudar fora dos dados (resumo para o integrador)

1. `HunterInput`: + `light_held` (já especificado em
   weapons/INTEGRACAO.md; uma implementação só).
2. `HunterState`: `combo_next` → `combo_from`; + `brio` (Espada) e campos de
   carga do Machado quando o ticket 11 chegar; to_dict/apply_dict com
   defaults.
3. `HunterStep`: `_begin_attack/_begin_heavy/_finish_attack` viram
   resolução de grafo (entry/next + predicados + efeitos); os casos
   especiais do Martelo/Lâminas migram para dados (ver MIGRACAO.md).
4. `Weapons`: `moves()/move()` ganham a forma por grafo; um adaptador
   compila o formato antigo (listas light/heavy) para grafos lineares,
   para a transição ser incremental.
5. Tela de ajuda do lobby (item do ticket): a árvore é serializável — a UI
   desenha `entry` + `next` sem conhecer arma nenhuma.

Números e janelas citados são provisórios (padrão do MEMORY.md).
