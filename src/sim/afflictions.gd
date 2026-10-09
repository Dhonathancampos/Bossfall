class_name Afflictions
extends RefCounted

## O ciclo de vida de uma Aflição no Caçador: acúmulo → disparo → efeito
## contínuo → expiração.
##
## Mora fora do HunterStep porque é alimentado pelo Anfitrião (os acertos do
## Behemoth) mas os EFEITOS rodam no passo do Caçador — que o Cliente também
## roda na predição. Sem isto o Congelamento, por exemplo, faria o Caçador
## local andar mais rápido na tela dele do que na verdade do Anfitrião.

## Soma acúmulo de um Elemento. Devolve o nome da Aflição quando ela dispara,
## para a Sim anunciar; vazio nas outras vezes.
static func add_buildup(hunter: HunterState, element: Elements.Element) -> String:
	if element == Elements.Element.NEUTRAL:
		return ""
	var key := int(element)
	if hunter.has_affliction(element):
		return ""

	var total := float(hunter.affliction_buildup.get(key, 0.0)) + SimConfig.AFFLICTION_BUILDUP_PER_HIT
	if total < SimConfig.AFFLICTION_THRESHOLD:
		hunter.affliction_buildup[key] = total
		return ""

	hunter.affliction_buildup[key] = 0.0
	hunter.afflictions[key] = SimConfig.AFFLICTION_DURATION
	_on_trigger(hunter, element)
	return Elements.affliction_name(element)


## Efeitos imediatos do disparo.
static func _on_trigger(hunter: HunterState, element: Elements.Element) -> void:
	match element:
		Elements.Element.SHOCK:
			# O Choque interrompe o Golpe — a única coisa no jogo que quebra o
			# Comprometimento, e por isso ele assusta.
			if hunter.state == HunterState.State.ATTACK:
				hunter.state = HunterState.State.FREE
				hunter.state_time = 0.0
			hunter.stamina = maxf(0.0, hunter.stamina - SimConfig.SHOCK_STAMINA_COST)
			hunter.regen_delay = SimConfig.STAMINA_REGEN_DELAY
		_:
			pass


## Efeitos por Tique + expiração. Chamado pelo HunterStep em todo passo,
## inclusive na predição do Cliente.
static func step(hunter: HunterState, dt: float) -> void:
	for key in hunter.affliction_buildup.keys():
		hunter.affliction_buildup[key] = maxf(
			0.0, float(hunter.affliction_buildup[key]) - SimConfig.AFFLICTION_BUILDUP_DECAY * dt
		)

	var expired: Array = []
	for key in hunter.afflictions.keys():
		var remaining := float(hunter.afflictions[key]) - dt
		if remaining <= 0.0:
			expired.append(key)
			continue
		hunter.afflictions[key] = remaining
		_apply_continuous(hunter, key as Elements.Element, dt)
	for key in expired:
		hunter.afflictions.erase(key)


static func _apply_continuous(hunter: HunterState, element: Elements.Element, dt: float) -> void:
	match element:
		Elements.Element.BLAZE:
			hunter.hp = maxf(0.0, hunter.hp - SimConfig.BURN_DPS * dt)
		Elements.Element.UMBRAL:
			# Dreno: a regeneração nunca chega e o Éter escorre.
			hunter.regen_delay = maxf(hunter.regen_delay, 0.1)
			hunter.aether = maxf(0.0, hunter.aether - SimConfig.DRAIN_AETHER_PER_SECOND * dt)
		_:
			pass


## Fator de velocidade de movimento (Congelamento).
static func speed_multiplier(hunter: HunterState) -> float:
	return SimConfig.FROST_SLOW if hunter.has_affliction(Elements.Element.FROST) else 1.0


## O Enraizamento tranca a Esquiva.
static func can_dodge(hunter: HunterState) -> bool:
	return not hunter.has_affliction(Elements.Element.TERRA)
