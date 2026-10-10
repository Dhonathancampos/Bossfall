class_name SimConfig
extends RefCounted

## Constantes de ajuste da Simulação.
##
## Dados puros: nada aqui conhece cena, nó ou física da Godot.
## Ver docs/adr/0001-sim-independente-da-apresentacao.md.

## A Sim só é avançada por este passo fixo. Nunca por delta de quadro.
const TICK_RATE: int = 60
const TICK_DELTA: float = 1.0 / 60.0

## A Arena é um círculo centrado na origem do plano de chão.
const ARENA_RADIUS: float = 900.0

## Caçador
const HUNTER_RADIUS: float = 22.0
const HUNTER_WALK_SPEED: float = 240.0
const HUNTER_SPRINT_SPEED: float = 370.0

## Fôlego
const STAMINA_MAX: float = 100.0

## Correr drena enquanto corre; a Esquiva cobra de uma vez.
const SPRINT_DRAIN_PER_SECOND: float = 22.0
const DODGE_COST: float = 25.0

## Fôlego mínimo para correr. Sem esse piso, assim que o Fôlego voltasse um
## tico a corrida retomaria e drenaria de novo, e segurar Shift com o Fôlego
## no fim viraria um engasgo de correr/andar/correr.
const SPRINT_MIN_STAMINA: float = 12.0

## Espera desde o último gasto real, não desde o fim da animação.
## Base sem bônus, segundo relatos pré-Awakening (fontes em MEMORY.md).
## Leves gratuitos permitem recuperar sem reiniciar esse relógio.
const STAMINA_REGEN_DELAY: float = 1.5
const STAMINA_REGEN_PER_SECOND: float = 9.0

## Esquiva
##
## O rolamento tem três pedaços em sequência: o impulso, dos quais os primeiros
## instantes são Invulneráveis, e a recuperação no fim, que é o que impede
## rolar sem parar.
const DODGE_SPEED: float = 560.0
const DODGE_DURATION: float = 0.22
const DODGE_IFRAMES_END: float = 0.16
const DODGE_RECOVERY: float = 0.12

## Vida do Caçador e o que acontece ao levar dano.
const HUNTER_MAX_HP: float = 100.0

## Tranco: o Caçador perde o controle por um instante e escorrega para longe.
const HURT_DURATION: float = 0.28
const KNOCKBACK_DECAY: float = 7.0

## Invulnerabilidade curta depois de levar dano, para que um ataque só não
## vire três por estar no meio de uma área.
const HURT_IFRAMES: float = 0.55

## Abatido. O sistema de verdade (Fichas de Reviver, companheiro levantando,
## derrota) chega no ticket 10; por ora o Caçador levanta sozinho, para a
## Caçada não travar.
const DOWNED_DURATION: float = 5.0
const DOWNED_REVIVE_FRACTION: float = 0.5

## Tipos de Dano contra Partes. Corte decepa; Impacto quebra o que é duro.
const SLASH_SEVER_MULT: float = 1.4
const BLUNT_HARD_MULT: float = 1.35

## Uma Parte quebrada recebe mais dano dali em diante.
const BROKEN_PART_MULT: float = 1.5

## Quanto do Atordoamento do golpe cada Tipo de Dano gera. É isto que faz o
## Martelo derrubar e a Espada decepar, em vez de todo mundo fazer tudo.
const STAGGER_TYPE_MULT: Dictionary = {
	Weapons.DamageType.SLASH: 0.6,
	Weapons.DamageType.BLUNT: 2.2,
	Weapons.DamageType.PIERCE: 0.5,
	Weapons.DamageType.BALLISTIC: 0.4,
}

## Atordoamento: o medidor esvazia sozinho, derruba quando enche, e cada
## queda seguinte exige mais que a anterior.
const STAGGER_DECAY_PER_SECOND: float = 16.0
const STAGGER_DOWN_DURATION: float = 4.5
const STAGGER_ESCALATION: float = 1.45
const STAGGERED_DAMAGE_MULT: float = 1.5

## Quebrar uma Parte enche este tanto do limiar atual de uma vez.
const PART_BREAK_STAGGER_FRACTION: float = 0.5

## Martelo clássico: munições e a Rajada Concussiva. Segurar o pesado consome
## munição (1 ao armar, +1 por segundo segurando) e a Rajada escala por
## munição. R recarrega: apertar de novo na janela certa termina na hora;
## na errada, trava o tempo cheio e mais um pouco.
const HAMMER_MAX_AMMO: int = 4
const HAMMER_HOLD_PER_AMMO: float = 1.0
const RELOAD_TIME: float = 1.6
const RELOAD_QUICK_START: float = 0.5
const RELOAD_QUICK_END: float = 0.8
const RELOAD_FAIL_EXTRA: float = 0.4

## Lâminas: Momentum. Golpes leves que conectam enchem o medidor; cada 100
## vira um pip (até 3), e o Golpe de Corrente gasta todos de uma vez.
const MOMENTUM_PER_HIT: float = 34.0
const MOMENTUM_PIP: float = 100.0
const MOMENTUM_MAX_PIPS: int = 3
## A distância é medida da borda do corpo. Com o collider fiel do Behemoth,
## Corrente só substitui o Gancho quando o caçador está realmente colado.
const CHAIN_SLAM_RANGE: float = 40.0
const CHAIN_SLAM_DAMAGE_PER_PIP: float = 25.0
const CHAIN_SLAM_STAGGER_PER_PIP: float = 20.0

## Grafo de combo (ticket 14) -------------------------------------------------

## Contexto `sprint` do grafo: a velocidade a partir da qual o Caçador conta
## como "saindo da corrida". Derivada de `velocity`, que já é replicada —
## nenhum campo novo viaja no Instantâneo por causa disso.
const COMBO_SPRINT_SPEED_MIN: float = HUNTER_SPRINT_SPEED * 0.9

## Contexto `dodge` do grafo: quanto tempo depois do fim do rolamento (ou do
## Rolinho) as entradas pós-esquiva ainda respondem.
const COMBO_DODGE_WINDOW: float = 0.25

## Espada: Brio. Fechar cadeias enche; os Golpes de desvio gastam 3.
const BRIO_MAX: int = 6

## Onda de Brio (segurar o pesado com Brio): projétil que pode interromper.
const BRIO_WAVE_DAMAGE: float = 50.0
const BRIO_WAVE_STAGGER: float = 160.0
const BRIO_WAVE_SPEED: float = 820.0
const BRIO_WAVE_RANGE: float = 620.0

## Machado: carga por golpe. O multiplicador cresce linear até o teto em 1 s.
const AXE_CHARGE_TIME_MAX: float = 1.0
const AXE_CHARGE_MULT_MAX: float = 1.6
## Carga parcial mínima para o acerto contar como "carregado" (gera Éter).
const AXE_CHARGE_METER_MIN: float = 0.35
## Segurar a carga drena vigor: é o custo do golpe canalizado. Toques
## continuam gratuitos nos leves (decisão do MEMORY.md).
const AXE_CHARGE_DRAIN_PER_SECOND: float = 10.0
## Janela da carga PERFEITA (fração do tempo máximo) que concede Resolve.
const AXE_CHARGE_PERFECT: Vector2 = Vector2(0.85, 1.0)

## Determinação: pilhas ganhas ao apanhar o Voo da Ruína que conectou.
## Mais pilhas = decaimento mais rápido.
const DETERMINATION_MAX_STACKS: int = 3
const DETERMINATION_DAMAGE_PER_STACK: float = 0.15
const DETERMINATION_DURATIONS: Array[float] = [12.0, 9.0, 6.0]

## Lança: Ferimento. Só Perfuração acumula; 133% do dano causado vira
## Ferimento (fonte comunitária). Limiar e decaimento são nossos.
const PIERCE_WOUND_RATE: float = 1.33
const WOUND_THRESHOLD: float = 300.0
const WOUND_DECAY_PER_SECOND: float = 10.0
const WOUND_DURATION: float = 15.0
## MODELO FIEL (rework 1.6.0): a Parte Ferida NÃO dá bônus de dano. Quem
## explora a ferida — acumulando este tanto de dano nela enquanto está aberta
## — ganha um buff PESSOAL por este tempo. Decisão registrada no MEMORY.md.
const WOUND_HARVEST_TARGET: float = 1000.0
const WOUND_BUFF_DURATION: float = 15.0
const WOUND_BUFF_DAMAGE: float = 0.15

## Repetidoras: pente e recarga. Empodera recarregando com a BORDA do corpo
## do Behemoth a até esta distância (fiel à referência; sem janela de timing).
const REPEATER_MAG: int = 12
const REPEATER_RELOAD_TIME: float = 1.2
const REPEATER_EMPOWER_RANGE: float = 160.0
const REPEATER_EMPOWER_MULT: float = 1.25

## Rolinho das Repetidoras: dash lateral curto com i-frames parciais.
const TUMBLE_SPEED: float = 520.0
const TUMBLE_DURATION: float = 0.18
const TUMBLE_IFRAMES_END: float = 0.08
const TUMBLE_RECOVERY: float = 0.10

## Espada: a Onda de Valor que cada Golpe conectado emite durante o buff.
const VALOR_WAVE_DAMAGE: float = 12.0
const VALOR_WAVE_STAGGER: float = 8.0
const VALOR_WAVE_SPEED: float = 760.0
const VALOR_WAVE_RANGE: float = 500.0

## Armadura (Bastião): a placa inteira segura o dano à Vida, mas sempre VAZA
## uma fração — nunca zero, por decisão do usuário.
const ARMOR_LEAK: float = 0.15

## Gancho das Lâminas: o puxão é rápido e para rente ao corpo do alvo.
const HOOK_PULL_SPEED: float = 1050.0
const HOOK_ARRIVE_GAP: float = 36.0

## Velocidade de deslocamento durante a Dança da Ceifadora (fração do andar).
const SPIN_MOVE_FRACTION: float = 0.45

## Aflições. O acúmulo protege de um acerto solto: só dispara ao encher.
## Dois acertos em sequência quase disparam; o terceiro garante. Com decay
## alto demais o limiar ficava inalcançável no ritmo real de ataque do
## Behemoth, e a Aflição virava letra morta.
const AFFLICTION_THRESHOLD: float = 100.0
const AFFLICTION_BUILDUP_DECAY: float = 8.0
const AFFLICTION_BUILDUP_PER_HIT: float = 60.0
const AFFLICTION_DURATION: float = 6.0

## Efeitos de cada Aflição no Caçador.
const BURN_DPS: float = 4.0
const FROST_SLOW: float = 0.55
const SHOCK_STAMINA_COST: float = 30.0
const DRAIN_AETHER_PER_SECOND: float = 12.0

## Behemoth
const BEHEMOTH_RETARGET_EVERY: float = 3.0

## Interrupção (boop): quanto tempo o Behemoth fica exposto depois de ter um
## ataque cancelado na janela interrompível. Punição curta — a queda por
## Atordoamento é a longa. Valor provisório (sem fonte de telemetria).
const INTERRUPT_DURATION: float = 1.6
const ENRAGE_FLASH_DURATION: float = 2.0
const BEHEMOTH_SPAWN := Vector2(0.0, 420.0)

## Éter: enche acertando Golpes e paga o Especial da arma.
const AETHER_MAX: float = 100.0

## Quanto tempo o alvo pisca de branco ao levar um Golpe.
const HIT_FLASH_DURATION: float = 0.09

## Boneco de treino. Some quando o Behemoth chegar, no ticket 05.
const DUMMY_RADIUS: float = 145.0
const DUMMY_HP: float = 100000.0
const DUMMY_POS := Vector2(0.0, -260.0)

## Até onde o centro do Caçador pode chegar antes de encostar na borda.
static func hunter_limit() -> float:
	return ARENA_RADIUS - HUNTER_RADIUS
