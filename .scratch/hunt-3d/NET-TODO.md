# NET-TODO — o que `src/net/net_game.gd` precisa ganhar

Escrito pelo papel **Mecânica** em 09/10/2026, **depois** de ler o
`net_game.gd` com o lobby já implementado (enum `Phase {IDLE, LOBBY, HUNT}`,
`_lobby`, `set_ready`, `start_hunt`, `everyone_ready`). Nada aqui foi
aplicado: o arquivo é do papel do lobby. São os `TODO(fase)` daquele arquivo,
agora com o lado da Sim pronto e o trecho de código no formato dele.

**Nada do que está lá hoje quebrou.** `Sim.new(tipo, elemento)` continua
entrando direto na Caçada — o terceiro parâmetro é opcional.

## O que a Sim passou a oferecer

```gdscript
Sim.new(behemoth_type, behemoth_element, start_in_lobby)   # 3º parâmetro NOVO, opcional
sim.phase() -> Sim.Phase                                    # LOBBY / HUNT / RESULT
sim.set_ready(id, value) / sim.is_ready(id) / sim.all_ready()
sim.start_hunt(behemoth_type := "", behemoth_element := -1) -> bool
sim.set_weapon(id, weapon, element)                         # zera o grafo de combo da arma antiga
sim.result() -> Dictionary
#   {"outcome": "victory",
#    "hunters": [{id, name, weapon, damage, parts_broken, interrupts}, ...]}
```

No Instantâneo: `payload["phase"]` (int do enum da Sim) **sempre**;
`payload["result"]` só em RESULT; `hunters[i]["ready"]` no dict completo **e**
no enxuto (o lobby precisa ver o "pronto" dos outros).
A troca de fase também sai como evento, para quem prefere ouvir:
`{"type": "phase", "phase": "hunt"}` e
`{"type": "phase", "phase": "result", "outcome": "victory"}`.

---

## 1. `light_held` — PRIORIDADE, e não é opcional

Sem este campo **três mecânicas novas ficam mortas**: o tiro contínuo das
Repetidoras, a carga do Machado e todas as transições `light_hold` do grafo de
combo (Investida de Brio da Espada, Broca da Lança, segurada das Lâminas).
`HunterInput.make` já recebe o parâmetro **no fim** da assinatura, então o
arquivo compila sem a mudança — ela só não faz nada.

### 1.1 Campo de estado — junto de `_input_heavy_held`

```gdscript
var _input_light_held: bool = false
```

### 1.2 `set_local_input` — parâmetro novo NO FIM

```gdscript
func set_local_input(
	move: Vector2, aim: float, sprint: bool,
	heavy_held: bool = false, light_held: bool = false
) -> void:
	_input_move = move
	_input_aim = aim
	_input_sprint = sprint
	_input_heavy_held = heavy_held
	_input_light_held = light_held
```

### 1.3 `_tick()` — 11º argumento, no fim

```gdscript
	var input := HunterInput.make(
		_input_move, _input_aim, _seq,
		_input_sprint, _dodge_armed, _light_armed, _heavy_armed,
		_special_armed, _input_heavy_held, _reload_armed, _input_light_held
	)
```

### 1.4 Apresentação

Quem chama `set_local_input` captura o botão leve segurado do mesmo jeito que
o pesado já é capturado, e passa no argumento novo.

---

## 2. Fase RESULT e o resumo da Caçada

O enum de lá tem `IDLE, LOBBY, HUNT`. **`IDLE` continua sendo da rede** (a Sim
nem existe nessa hora); o que falta é a quarta:

```gdscript
enum Phase {
	IDLE,
	LOBBY,
	HUNT,
	## Caçada encerrada: a tela de RESULTADO. Espelha Sim.Phase.RESULT.
	RESULT,
}
```

### 2.1 Sinal novo, junto de `phase_changed`

```gdscript
## A Caçada acabou. `summary` é o `Sim.result()`: desfecho + uma linha por
## Caçador com dano causado, Partes quebradas e interrupções.
signal hunt_finished(summary: Dictionary)
```

### 2.2 Guardar o resumo

```gdscript
## O resumo da última Caçada. Vazio fora de RESULT.
var hunt_summary: Dictionary = {}
```

### 2.3 Anfitrião — no `_tick()`, logo depois de `sim.step(...)`

```gdscript
	if is_host:
		sim.set_input(local_id, input)
		sim.step(SimConfig.TICK_DELTA)
		if phase == Phase.HUNT and sim.phase() == Sim.Phase.RESULT:   # <<< novo
			hunt_summary = sim.result()
			_set_phase(Phase.RESULT)
			hunt_finished.emit(hunt_summary)
		_tick_count += 1
		...
```

### 2.4 Cliente — em `_push_snapshot`, antes do `_reconcile(data)`

```gdscript
	if int(data.get("phase", int(Sim.Phase.HUNT))) == int(Sim.Phase.RESULT) \
			and phase == Phase.HUNT:
		hunt_summary = data.get("result", {})
		_set_phase(Phase.RESULT)
		hunt_finished.emit(hunt_summary)
```

### 2.5 `app.gd::_on_leave_requested()` (item 4 do TODO de lá)

Com `hunt_finished` existindo, sair da Arena pode cair na tela de RESULTADO e
dali **voltar para a sala**: `leave()` só na saída de verdade; para encadear
Caçadas, basta `_set_phase(Phase.LOBBY)` sem fechar a porta (a Sim antiga é
descartada e `start_hunt()` cria a próxima).

---

## 3. Mover o "pronto" e a largada para dentro da Sim (itens 1–3 do TODO de lá)

Isto é a migração completa — maior que as duas anteriores, e **opcional
agora**: o lobby de hoje funciona. O ganho é ter uma fonte só de verdade.

### 3.1 `host_lobby()` — criar a Sim já em LOBBY

```gdscript
	sim = Sim.new(behemoth_type, behemoth_element as Elements.Element, true)
	sim.add_hunter(local_id, display_name, weapon_id)
	sim.set_weapon(local_id, weapon_id, weapon_element)
```

Quem entra vira `sim.add_hunter(sender, nome, arma)` no mesmo lugar em que
hoje entra no `_lobby`.

### 3.2 `set_ready` vira pedido à Sim

```gdscript
func set_ready(ready: bool) -> void:
	if is_host:
		if sim == null:
			return
		sim.set_ready(local_id, ready)
		_publish_lobby()
		return
	_push_ready.rpc_id(1, ready)


@rpc("any_peer", "call_remote", "reliable")
func _push_ready(value: bool) -> void:
	if not is_host or sim == null:
		return
	sim.set_ready(multiplayer.get_remote_sender_id(), value)
	_publish_lobby()
```

`everyone_ready()` vira `return sim != null and sim.all_ready()`.
`lobby_entries()` passa a ler `sim.roster()`, que agora traz
`{"name", "weapon", "ready"}` por Caçador (o Elemento continua no `_lobby`, ou
vai junto se preferirem — a Sim guarda `element` no Caçador).

### 3.3 `start_hunt()` vira uma chamada

```gdscript
func start_hunt() -> String:
	if not is_host:
		return "Só o Anfitrião começa a Caçada."
	if sim == null or not sim.start_hunt(behemoth_type, behemoth_element):
		return "A sala não está aberta."
	_begin()
	_roster = sim.roster()
	_set_phase(Phase.HUNT)
	_begin_hunt.rpc(behemoth_type, behemoth_element)
	started.emit()
	return ""
```

Atenção ao `_begin()`: hoje ele zera a predição e as filas, o que continua
certo. O que **não** pode mais acontecer é recriar a Sim — ela já existe desde
o lobby.

---

## 4. `hud_3d.gd::_interrupt_notice()` (item 5 do TODO de lá)

O campo chegou. O Instantâneo do Behemoth agora traz:

```gdscript
behemoth["interrupt_window"]     # bool: a janela está ABERTA agora
behemoth["interrupt_threshold"]  # float: o Atordoamento mínimo do impacto
```

Os dois saem da MESMA função que resolve o boop
(`BehemothState.is_interruptible_now()` / `interrupt_threshold()`, usadas por
`BehemothStep.try_interrupt`), então o aviso nunca pode contradizer a regra —
há teste cobrando isso (`test_the_window_the_snapshot_shows_is_the_window_that_boops`).
A dedução local pode sair.

A tela "Aprenda" pode continuar lendo `interruptible` dos dados para ENSINAR
quais ataques aceitam boop; o campo novo é para AVISAR na hora.

---

## Avisos

- **LOBBY não resolve combate.** A Sim avança os Caçadores (dá para andar no
  lobby) mas não resolve acerto, projétil nem Behemoth.
- **`set_ready` fora do LOBBY é mudo** (a Sim ignora): a UI pode chamar à
  vontade.
- **`sim.result()` é `{}` antes de RESULT.**
- **`sim.set_weapon()` agora zera a posição no grafo de combo e os recursos da
  arma anterior** (pente, munição convertida, Brio, machado no ar). Trocar de
  arma na sala é seguro.
- **`phase` no Instantâneo é um int do enum `Sim.Phase`.** Anfitrião e Cliente
  rodam o mesmo build — premissa já registrada no MEMORY.md.
