# 04: Espada — Golpes, Comprometimento e Combo

**What to build:** a primeira arma. Bater num alvo de treino, ver o número de
dano sair, encadear o combo de três Golpes — e descobrir que, uma vez que o
Golpe começa, não dá para desistir dele.

**Blocked by:** 03

**Status:** done

- [x] Botão esquerdo dispara o Golpe leve, botão direito o Golpe pesado
- [x] Todo Golpe passa por Preparo, Ativo e Recuperação, visíveis no personagem
- [x] Um Golpe iniciado não pode ser cancelado por movimento nem por Esquiva
- [x] Três Golpes leves encadeiam em Combo dentro da Janela de Combo
- [x] Perder a Janela de Combo reinicia a sequência no primeiro Golpe
- [x] Cada Golpe avança o Caçador um pouco para frente
- [x] Existe um alvo de treino na Arena que recebe dano
- [x] Números de dano saem do ponto atingido
- [x] Um Golpe acerta o mesmo alvo no máximo uma vez
- [x] Travadinha curta na imagem ao acertar (hitstop)
- [x] Golpes gastam Fôlego
- [x] Os Golpes da Espada são dados numa tabela, não código
- [x] Testes: Comprometimento, Janela de Combo (dentro e fora), um acerto por
      alvo por Golpe
