class_name Elements
extends RefCounted

## Os sete Elementos, a tabela de Oposição e as Aflições.
##
## Dados puros, como Weapons e Behemoths: a quarta variante elemental de um
## monstro é uma escolha de Elemento, não um arquivo novo.

enum Element {
	NEUTRAL,
	BLAZE,    # Incêndio
	FROST,    # Gélido
	SHOCK,    # Choque
	TERRA,    # Terra
	RADIANT,  # Radiante
	UMBRAL,   # Umbral
}

## Os pares opostos. Neutro não tem oposto: é a escolha segura, nunca
## bonificada nem punida.
const OPPOSITES: Dictionary = {
	Element.BLAZE: Element.FROST,
	Element.FROST: Element.BLAZE,
	Element.SHOCK: Element.TERRA,
	Element.TERRA: Element.SHOCK,
	Element.RADIANT: Element.UMBRAL,
	Element.UMBRAL: Element.RADIANT,
}

const OPPOSITION_BONUS: float = 1.25
const SAME_ELEMENT_PENALTY: float = 0.75

## O que cada Elemento é na tela e o que ele aflige num Caçador.
## Nomes amplos de propósito (decisão do usuário, 09/10/2026): "Fogo" em vez
## de "Incêndio", "Água" em vez de "Gélido" etc., para caberem possibilidades
## futuras (um behemoth de vapor, uma arma de maré). Os identificadores do
## código (BLAZE, FROST...) não mudam: replicação e saves não ligam para nome.
const _DATA: Dictionary = {
	Element.NEUTRAL: {"name": "Neutro", "color": "aebccb", "affliction": ""},
	Element.BLAZE: {"name": "Fogo", "color": "ff8a5c", "affliction": "Queimadura"},
	Element.FROST: {"name": "Água", "color": "8fd8ff", "affliction": "Congelamento"},
	Element.SHOCK: {"name": "Elétrico", "color": "ffe066", "affliction": "Choque"},
	Element.TERRA: {"name": "Terra", "color": "a8c97f", "affliction": "Enraizamento"},
	Element.RADIANT: {"name": "Luz", "color": "ffe9b0", "affliction": "Cegueira"},
	Element.UMBRAL: {"name": "Trevas", "color": "b48cff", "affliction": "Dreno"},
}


## O fator de dano de um ataque elemental contra um dono de Elemento.
## Oposto premia, igual pune, Neutro em qualquer lado é sempre 1.
static func damage_multiplier(attacker: Element, defender: Element) -> float:
	if attacker == Element.NEUTRAL or defender == Element.NEUTRAL:
		return 1.0
	if OPPOSITES.get(attacker) == defender:
		return OPPOSITION_BONUS
	if attacker == defender:
		return SAME_ELEMENT_PENALTY
	return 1.0


static func all() -> Array:
	return _DATA.keys()


static func display_name(element: Element) -> String:
	return _DATA[element]["name"]


static func color(element: Element) -> Color:
	return Color(_DATA[element]["color"])


static func affliction_name(element: Element) -> String:
	return _DATA[element]["affliction"]


## O Elemento forte contra este (o oposto dele), para a dica do lobby.
static func strong_against(element: Element) -> Element:
	return OPPOSITES.get(element, Element.NEUTRAL)
