# Revisão — integração de 09/10/2026

Passada do papel Revisão depois da rodada de quatro agentes (áudio, modelos,
rework de armas + Bastião, integração 3D). Corrigido no código: ver o fim.
O que fica aqui é o que foi verificado e o que fica de aviso.

## Verificado e OK

1. **Replicação** — todos os campos novos do HunterState (ammo, blast_ammo,
   reload_failed, momentum, pips, slam_pips, valor_time, hook_target,
   spin_tick) entram simétricos em `to_dict`/`apply_dict`. As flags de um
   Tique (spin_strike, wants_projectile, special_fired) ficam de fora de
   propósito. `to_view_dict` cobre o que a HunterView dos remotos lê.
2. **Predição** — a fila da Sim, ao secar, preserva `heavy_held` (contínuo) e
   zera os pedidos de um Tique; a carga não cai com pacote atrasado. O caminho
   do Cliente sem `world` degrada seguro: Gancho/Corrente só não são
   antecipados (sem travar estado), o Instantâneo corrige.
3. **Bastião** — `ARMOR_LEAK` aplicado só na Vida, DEPOIS do cálculo completo
   (Tipo→Oposição→quebra→Atordoado→buff); a placa apanha o valor cheio; o
   número na tela mostra o que entrou na Vida. `break_penalty` é dado e chega
   ao cooldown pelos dois caminhos do BehemothStep. O OptionButton propaga
   menu→app→NetGame.host→Sim.
4. **Apresentação** — recriar o nó do Caçador na troca de arma não vaza (o nó
   leva Tag e View juntos no queue_free); `_claim_body_material` duplica o
   material por instância e o lampejo de emissão desliga em todo update;
   os `.get` dos dicionários enxutos têm default.
5. **Eventos** — o evento `special` de um Tique acumula em `_events` até o
   broadcast (a cada 2 Tiques): não se perde nem duplica no Anfitrião.

## Avisos (documentado, sem mexer)

1. **Enum State fora de ordem**: CHARGING/HOOK_PULL/SPECIAL_SPIN entraram no
   MEIO do enum (HURT 3→6, DOWNED 4→7), ao contrário do que o relatório da
   Mecânica afirmou (só RELOADING foi para o fim). Hoje é inofensivo — Anfitrião
   e Cliente rodam o mesmo build e nada persiste esses ints — mas se um dia
   houver compatibilidade entre versões, este é o lugar que quebra. Não
   reordenei: seria churn puro agora.
2. **Sons dos Clientes em canal não confiável**: os eventos viajam dentro do
   Instantâneo (unreliable_ordered). Instantâneo perdido = som perdido no
   Cliente. Aceitável; se incomodar, eventos podem migrar para um RPC confiável.
3. **SPECIAL_SPIN e RELOADING sem animação**: caem no idle. Pendência do papel
   Modelos (animações de giro e recarga).
4. **`_redraw_ground` recria ImmediateMesh + materiais todo quadro**: certo em
   escala atual, candidato a pooling quando houver 4 jogadores + projéteis.
5. **Ameaça contra o Bastião usa o dano vazado** (pós-leak): bater na placa
   gera pouca ameaça. Parece intencional (a placa também protege a atenção) e
   tem efeito colateral bom — quem bate na cauda exposta puxa o foco.

## Corrigido nesta passada

- `hunter_view.gd`: CHARGING agora toca a animação `charge` (existia e estava
  órfã) e HOOK_PULL toca `dodge`; antes, carga e gancho mostravam o Caçador
  parado — pior para os REMOTOS, que não têm HUD do dono.
- `audio_fx.gd`: o swing tocava só no primeiro Golpe de um combo (o estado
  continua ATTACK nos encadeados); agora detecta a troca de golpe
  (kind+index) e cada elo do combo soa.
