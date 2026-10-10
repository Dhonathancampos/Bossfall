# -*- coding: utf-8 -*-
"""A Faiscaia: lacraia de quartzo, criatura original da casa, low-poly.

Ficha: `.scratch/bestiary/05-faiscaia.md`. Silhueta: seis segmentos chatos
como vagões de quartzo cinza-azulado, cada um com uma placa dorsal clara;
fileiras de perninhas em cunha que ondulam em fase; cabeça larga com tenazes
externas e duas antenas compridas; ferrão caudal em gancho duplo.

## O contrato com a apresentação (CreatureView)

O **Núcleo Errante** é a mecânica da ficha: uma zona de acerto que migra por
quatro estações do corpo. Cada estação é uma MALHA COM NOME PRÓPRIO, para a
apresentação acender a da vez e apagar as outras (a Sim ainda não tem o campo
`core_station`; quando tiver, é só ler o inteiro):

    core_tail     estação 0 — Ferrão
    core_back_a   estação 1 — placas traseiras
    core_back_b   estação 2 — placas dianteiras
    core_head     estação 3 — Mandíbulas (dispara a Descarga Plena)

As Partes decepáveis/quebráveis da ficha também são malhas nomeadas, no mesmo
contrato da cauda do quadrúpede:

    antenna_r / antenna_l   Antenas (decepáveis)
    stinger                 Ferrão (decepável)
    plates                  Placas Dorsais (quebram)
    raw_plates              quartzo fosco e rachado sob as placas (nasce
                            escondido; aparece quando a Parte quebra)
    jaw_r / jaw_l           Mandíbulas

## Rig

A raiz é o segmento do MEIO, e o corpo sai dela para os dois lados:

    seg_b ─ seg_a ─ neck ─ head ─ jaw_r / jaw_l / antenna_r / antenna_l
      │
    root (seg_c)
      │
    seg_d ─ seg_e ─ seg_f ─ stinger

Assim empinar a frente (Descarga, Látego) levanta SÓ a frente: numa cadeia
com a raiz na cabeça, o corpo inteiro subiria junto. Cada segmento tem um par
de ossos de perna (`legs_<seg>_r/l`) — é o que deixa as fileiras de pernas
ondularem em fase em vez de deslizarem rígidas.

Toda pose usa `space="world"`: rx rola, ry inclina a ponta do osso para a
frente (num osso que aponta para trás, ry positivo LEVANTA a ponta), rz gira
para a esquerda.

## Animações

A Faiscaia ainda NÃO está em `src/sim/behemoths.gd` — outro papel pode
implementá-la. As durações vêm da ficha (windup+active+recovery), e os nomes
dos clipes são os ids de ataque que a ficha define:

    pince       = 0.50 + 0.14 + 0.58 = 1.22 s
    whip        = 0.55 + 0.18 + 0.70 = 1.43 s
    serpentine  = 0.78 + 0.45 + 0.85 = 2.08 s
    coil        = 0.95 + 0.22 + 0.95 = 2.12 s
    static_lash = 0.66 + 0.16 + 0.68 = 1.50 s
    discharge   = 2.00 + 0.30 + 1.40 = 3.70 s

Mais `idle`, `walk`, `roar`, `stagger_fall` (4,5 s = STAGGER_DOWN_DURATION) e
`death`. Quando a ficha virar dados, estes números têm de bater com os da Sim
— o teste de duração cobre isso, e a correção é REGERAR o modelo.

Rodar:  blender --background --python tools/models/faiscaia.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common

OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "faiscaia.glb"
)

PINCE = (0.50, 0.14, 0.58)
WHIP = (0.55, 0.18, 0.70)
SERPENTINE = (0.78, 0.45, 0.85)
COIL = (0.95, 0.22, 0.95)
LASH = (0.66, 0.16, 0.68)
DISCHARGE = (2.00, 0.30, 1.40)
ROAR = 2.0
FALL = 4.5
DEATH = 2.0

## Segmentos da frente para trás, com o x do CENTRO de cada um. A ordem é o
## que faz a onda viajar: cada osso da lista entra com um atraso de fase.
SEGMENTS = [
    ("head", 1.40),
    ("neck", 0.72),
    ("seg_a", -0.02),
    ("seg_b", -0.85),
    ("root", -1.65),
    ("seg_d", -2.45),
    ("seg_e", -3.22),
    ("seg_f", -3.92),
    ("stinger", -4.45),
]
## Segmentos que carregam pernas (a cabeça e o ferrão não têm).
LEG_SEGMENTS = [("seg_a", -0.02), ("seg_b", -0.85), ("root", -1.65),
                ("seg_d", -2.45), ("seg_e", -3.22)]
## Atraso de fase por posição na lista: é a onda da lacraia.
PHASE_STEP = 0.11


def build() -> None:
    common.reset_scene()

    # Quartzo é o material que a CreatureView tinge pela variante elemental.
    #
    # Paleta da ficha: quartzo cinza-azulado, placa dorsal clara, quina quase
    # preta, núcleo âmbar-elétrico. Os tons são espaçados de propósito — numa
    # criatura chata, quase toda face vira topo virado para o sol, e valores
    # vizinhos viram uma mancha só de longe.
    quartz = common.material("faiscaia_quartz", "6b7b9c")
    quartz_light = common.material("faiscaia_quartz_light", "b9c6de")
    quartz_dull = common.material("faiscaia_dull", "6d6a63", roughness=1.0)
    chitin = common.material("faiscaia_chitin", "2b3550")
    core = common.material("faiscaia_core", "ffd23f", roughness=0.2,
                           emission="ffb020", emission_strength=1.5)
    eye = common.material("faiscaia_eye", "ff6b3d", roughness=0.25)

    bones = {
        # A raiz é o segmento do meio, de pé: é a âncora que não ondula.
        "root": ((-1.65, 0.0, 0.72), (-1.65, 0.0, 1.20), None),
    }
    bones.update(common.chain(
        ["seg_b", "seg_a", "neck", "head"],
        [(-1.25, 0.0, 0.76), (-0.45, 0.0, 0.78), (0.40, 0.0, 0.80),
         (1.05, 0.0, 0.82), (1.75, 0.0, 0.82)],
        "root",
    ))
    bones.update(common.chain(
        ["seg_d", "seg_e", "seg_f", "stinger"],
        [(-2.05, 0.0, 0.76), (-2.85, 0.0, 0.76), (-3.60, 0.0, 0.78),
         (-4.25, 0.0, 0.90), (-4.75, 0.0, 1.70)],
        "root",
    ))
    for side, sign in (("r", -1.0), ("l", 1.0)):
        bones["jaw_%s" % side] = ((1.62, sign * 0.34, 0.80), (2.45, sign * 0.52, 0.78), "head")
        bones["antenna_%s" % side] = ((1.55, sign * 0.30, 1.02), (2.70, sign * 0.80, 1.55), "head")
    for name, px in LEG_SEGMENTS:
        for side, sign in (("r", -1.0), ("l", 1.0)):
            bones["legs_%s_%s" % (name, side)] = (
                (px, sign * 0.52, 0.70), (px, sign * 1.15, 0.18), name,
            )
    rig = common.armature("Faiscaia", bones)

    # --- Segmentos: prismas chatos, afinando para a cauda ---
    # O "neck" é um segmento como os outros: sem malha nele o corpo ficava
    # com um vão entre o último vagão e a cabeça (visível no primeiro preview).
    widths = {"neck": 1.56, "root": 1.55, "seg_a": 1.62, "seg_b": 1.60,
              "seg_d": 1.46, "seg_e": 1.28, "seg_f": 1.08}
    lengths = {"neck": 0.66, "root": 0.86, "seg_a": 0.92, "seg_b": 0.86,
               "seg_d": 0.86, "seg_e": 0.80, "seg_f": 0.70}
    for name, px in [(n, x) for n, x in SEGMENTS if n in widths]:
        common.attach(
            common.box("m_%s" % name, (lengths[name], widths[name], 0.52),
                       (px, 0.0, 0.80), quartz),
            rig, name,
        )
        # Flancos chanfrados: a quina escura que separa um vagão do outro.
        common.attach(
            common.box("m_%s_rim" % name, (0.16, widths[name] + 0.12, 0.42),
                       (px + lengths[name] * 0.5, 0.0, 0.80), chitin),
            rig, name,
        )

    # --- Placas Dorsais: UMA malha "plates", repartida entre os segmentos ---
    plate_parts = []
    for name, px in [(n, x) for n, x in SEGMENTS if n in widths]:
        plate_parts.append(common.box(
            "plates_%s" % name, (lengths[name] * 0.78, widths[name] * 0.62, 0.34),
            (px, 0.0, 1.14), quartz_light,
        ))
        plate_parts.append(common.box(
            "plates_%s_crest" % name, (lengths[name] * 0.42, widths[name] * 0.22, 0.30),
            (px, 0.0, 1.38), quartz_light, rotation=(0.0, 0.0, 0.0),
        ))
    plates = common.join(plate_parts, "plates")
    common.attach_gradient(
        plates, rig,
        [("neck", 0.44, 1.06), ("seg_a", -0.48, 0.44), ("seg_b", -1.28, -0.48),
         ("root", -2.06, -1.28), ("seg_d", -2.86, -2.06), ("seg_e", -3.60, -2.86),
         ("seg_f", -4.40, -3.60)],
        axis=0, blend=0.12,
    )

    # Quartzo fosco e rachado sob as placas: nasce escondido, a CreatureView
    # acende quando a Parte quebra. Fica RENTE ao dorso para não espiar.
    raw_parts = []
    for name, px in [(n, x) for n, x in SEGMENTS if n in widths]:
        raw_parts.append(common.box(
            "raw_plates_%s" % name, (lengths[name] * 0.80, widths[name] * 0.66, 0.26),
            (px, 0.0, 1.06), quartz_dull,
        ))
    raw_plates = common.join(raw_parts, "raw_plates")
    common.attach_gradient(
        raw_plates, rig,
        [("neck", 0.44, 1.06), ("seg_a", -0.48, 0.44), ("seg_b", -1.28, -0.48),
         ("root", -2.06, -1.28), ("seg_d", -2.86, -2.06), ("seg_e", -3.60, -2.86),
         ("seg_f", -4.40, -3.60)],
        axis=0, blend=0.12,
    )

    # --- Pernas: fileiras de cunhas, uma malha por segmento e por lado ---
    for name, px in LEG_SEGMENTS:
        for side, sign in (("r", -1.0), ("l", 1.0)):
            wedges = []
            for i, offset in enumerate((-0.26, 0.0, 0.26)):
                wedges.append(common.cone(
                    "leg_%s_%s_%d" % (name, side, i), 0.16, 0.78,
                    (px + offset, sign * 0.88, 0.46), chitin,
                    rotation=(sign * 0.75, 0.0, 0.0), vertices=4,
                ))
            common.attach(common.join(wedges, "m_legs_%s_%s" % (name, side)),
                          rig, "legs_%s_%s" % (name, side))

    # --- Cabeça: larga, chata, com tenazes externas ---
    common.attach(common.box("m_head", (0.92, 1.50, 0.50), (1.40, 0.0, 0.82), quartz), rig, "head")
    common.attach(common.box("m_brow", (0.60, 1.20, 0.26), (1.55, 0.0, 1.10), quartz_light),
                  rig, "head")
    for side, sign in (("r", -1.0), ("l", 1.0)):
        common.attach(
            common.sphere("m_eye_%s" % side, 0.15, (1.78, sign * 0.48, 1.00), eye, subdivisions=1),
            rig, "head",
        )
        # Tenaz: braço reto que termina em gancho virado para dentro.
        common.attach(
            common.join([
                common.box("jaw_%s_arm" % side, (0.80, 0.22, 0.24),
                           (1.98, sign * 0.44, 0.78), chitin),
                common.cone("jaw_%s_tip" % side, 0.16, 0.56,
                            (2.42, sign * 0.30, 0.78), quartz_light,
                            rotation=(0.0, 1.10, -sign * 0.55), vertices=4),
            ], "jaw_%s" % side),
            rig, "jaw_%s" % side,
        )
        # Antena: três contas numa linha, bem visível — é Parte decepável.
        common.attach(
            common.join([
                common.box("antenna_%s_a" % side, (0.50, 0.14, 0.14),
                           (1.78, sign * 0.42, 1.14), chitin,
                           rotation=(0.0, -0.42, -sign * 0.5)),
                common.box("antenna_%s_b" % side, (0.46, 0.12, 0.12),
                           (2.18, sign * 0.62, 1.32), chitin,
                           rotation=(0.0, -0.42, -sign * 0.5)),
                common.cone("antenna_%s_tip" % side, 0.12, 0.34,
                            (2.52, sign * 0.78, 1.48), quartz_light,
                            rotation=(0.0, 1.0, -sign * 0.5), vertices=4),
            ], "antenna_%s" % side),
            rig, "antenna_%s" % side,
        )

    # --- Ferrão: gancho duplo, tipo tesoura. Parte decepável. ---
    common.attach(
        common.join([
            common.box("stinger_base", (0.60, 0.58, 0.46), (-4.42, 0.0, 1.10), quartz),
            common.cone("stinger_hook_r", 0.22, 0.90, (-4.70, -0.22, 1.72), quartz_light,
                        rotation=(-0.35, -0.35, 0.0), vertices=4),
            common.cone("stinger_hook_l", 0.22, 0.90, (-4.70, 0.22, 1.72), quartz_light,
                        rotation=(0.35, -0.35, 0.0), vertices=4),
        ], "stinger"),
        rig, "stinger",
    )

    # --- Núcleo Errante: uma malha por estação, acesa pela apresentação ---
    # Alto o bastante para espiar ACIMA da crista das placas: enterrado entre
    # elas, o núcleo sumia da captura — e localizar a estação num relance é a
    # mecânica inteira da luta.
    for station, (name, px, pz) in enumerate([("core_tail", -4.05, 1.40),
                                              ("core_back_a", -2.45, 1.62),
                                              ("core_back_b", -0.85, 1.62),
                                              ("core_head", 1.32, 1.42)]):
        bone = {"core_tail": "seg_f", "core_back_a": "seg_d",
                "core_back_b": "seg_b", "core_head": "head"}[name]
        common.attach(
            common.sphere(name, 0.34, (px, 0.0, pz), core, subdivisions=1),
            rig, bone,
        )

    _animate(rig)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    common.export_glb(os.path.abspath(OUT))


# --- Ferramentas de pose -------------------------------------------------


def _phase(name: str) -> float:
    """Atraso de fase do segmento: a onda viaja da cabeça para o ferrão."""
    for index, (bone, _px) in enumerate(SEGMENTS):
        if bone == name:
            return index * PHASE_STEP
    return 0.0


def _legs(duration: float, amplitude: float = 26.0, samples: int = 10,
          bias: float = 0.0, offset: float = 0.25) -> dict:
    """As fileiras de perninhas remando em fase.

    Cada par entra atrasado em relação ao segmento da frente; é a leitura de
    "dezenas de pernas" sem dezenas de ossos animados à mão.
    """
    poses = {}
    for name, _px in LEG_SEGMENTS:
        for side, sign in (("r", -1.0), ("l", 1.0)):
            poses["legs_%s_%s" % (name, side)] = common.cycle(
                duration, amplitude=(0, amplitude, 0), bias=(0, bias, 0),
                phase=_phase(name) + offset + (0.5 if side == "l" else 0.0),
                samples=samples,
            )
    return poses


def _still(duration: float, bones: list) -> dict:
    """Ossos parados no repouso durante o clipe inteiro."""
    return {name: [(0.0, (0, 0, 0), None, "ease"), (duration, (0, 0, 0), None, "ease")]
            for name in bones}


def _hold_legs(duration: float, angle: float = -10.0) -> dict:
    """Pernas plantadas: o que ela faz quando para para bater."""
    return {"legs_%s_%s" % (name, side): [(0.0, (0, 0, 0), None, "wind"),
                                          (duration * 0.3, (0, angle, 0), None, "ease"),
                                          (duration, (0, 0, 0), None, "settle")]
            for name, _px in LEG_SEGMENTS for side in ("r", "l")}


def _attack(rig, name, phases, wind, hit, amount=0.22, at=0.36,
            wind_ease="accel", hit_ease="hit", extra=None) -> None:
    """As três fases da Sim, no molde do quadrúpede e do Bastião.

    `extra` entra depois (poses completas por osso) para os clipes que
    precisam de mais de três chaves em algum osso.
    """
    windup, active, recovery = phases
    total = windup + active + recovery

    poses = {}
    for key in set(wind) | set(hit):
        base, base_loc = _split((0, 0, 0))
        w_rot, w_loc = _split(wind.get(key, (0, 0, 0)))
        h_rot, h_loc = _split(hit.get(key, wind.get(key, (0, 0, 0))))
        keys = [
            (0.0, base, base_loc, wind_ease),
            (windup, w_rot, w_loc, hit_ease),
            (windup + active, h_rot, h_loc, "ease"),
        ]
        tail = common.settle(windup + active, h_rot, total, amount=amount, at=at)
        if h_loc is not None:
            over_loc = tuple(h_loc[i] * 0.3 for i in range(3))
            tail = [(tail[0][0], tail[0][1], over_loc, tail[0][3]),
                    (tail[1][0], tail[1][1], (0.0, 0.0, 0.0), tail[1][3])]
        poses[key] = keys + tail

    poses.update(_hold_legs(total))
    if extra:
        poses.update(extra)
    common.animation(rig, name, total, poses, space="world")


def _split(value):
    if len(value) == 2 and isinstance(value[0], (tuple, list)):
        return tuple(value[0]), tuple(value[1])
    return tuple(value), None


def _animate(rig) -> None:
    _idle(rig)
    _walk(rig)
    _pince(rig)
    _whip(rig)
    _serpentine(rig)
    _coil(rig)
    _static_lash(rig)
    _discharge(rig)
    _roar(rig)
    _stagger(rig)
    _death(rig)


def _idle(rig) -> None:
    """Repouso: a onda do corpo continua andando, devagar, no lugar.

    Uma lacraia parada não fica rígida — o corpo respira em S e as antenas
    varrem o ar. É o que distingue a silhueta dela da do quadrúpede mesmo
    sem nenhum ataque acontecendo.
    """
    idle = 2.2
    poses = {}
    for name, _px in SEGMENTS:
        poses[name] = common.cycle(idle, amplitude=(0, 0, 4.5), phase=_phase(name), samples=12)
    for side, sign in (("r", -1.0), ("l", 1.0)):
        poses["antenna_%s" % side] = common.cycle(
            idle, amplitude=(0, -6.0, sign * 9.0), samples=12, phase=0.1)
        poses["jaw_%s" % side] = common.cycle(
            idle, amplitude=(0, 0, sign * 5.0), bias=(0, 0, sign * 3.0), samples=12)
    poses.update(_legs(idle, amplitude=9.0, samples=12))
    common.animation(rig, "idle", idle, poses, space="world")


def _walk(rig) -> None:
    """Andar: onda lateral viajando da cabeça ao ferrão, pernas remando.

    0,75 s de ciclo — ela é a criatura mais rápida do bestiário (move_speed
    150 na ficha), e o passo precisa dizer isso. A amplitude da onda cresce
    para trás: a ponta da cauda é o que mais varre.
    """
    walk = 0.75
    poses = {}
    for index, (name, _px) in enumerate(SEGMENTS):
        amplitude = 7.0 + index * 1.6
        poses[name] = common.cycle(walk, amplitude=(0, 0, amplitude),
                                   phase=_phase(name), samples=12)
    for side, sign in (("r", -1.0), ("l", 1.0)):
        poses["antenna_%s" % side] = common.cycle(
            walk, amplitude=(0, -8.0, sign * 10.0), samples=12, phase=0.15)
        poses["jaw_%s" % side] = common.cycle(walk, amplitude=(0, 0, sign * 6.0), samples=12)
    poses.update(_legs(walk, amplitude=30.0, samples=12))
    common.animation(rig, "walk", walk, poses, space="world")


def _pince(rig) -> None:
    """Pinçada: as tenazes abrem, a cabeça recua e o bote fecha.

    A ficha pede `telegraph: false` — este ataque se lê SÓ pela animação. É o
    caso em que o Preparo tem de ser visível no corpo: tenazes escancaradas,
    cabeça armada para trás, antenas apontando o alvo.
    """
    _attack(rig, "pince", PINCE,
            wind={
                "neck": (0, -14, 0), "head": (0, -10, 0),
                "seg_a": (0, -6, 0), "seg_b": (0, -3, 0),
                "jaw_r": (0, 0, -34), "jaw_l": (0, 0, 34),
                "antenna_r": (0, -16, -12), "antenna_l": (0, -16, 12),
            },
            hit={
                "neck": ((0, 18, 0), (0.18, 0.0, 0.0)), "head": (0, 14, 0),
                "seg_a": (0, 8, 0), "seg_b": (0, 4, 0),
                "jaw_r": (0, 0, 12), "jaw_l": (0, 0, -12),
                "antenna_r": (0, 10, -4), "antenna_l": (0, 10, 4),
            }, amount=0.26)


def _whip(rig) -> None:
    """Chicote Caudal: a metade de trás enrola e desenrola para o lado.

    Cone para trás, arco 2,3 rad. Os segmentos traseiros vêm defasados entre
    si — a ponta do ferrão chega DEPOIS da base, que é o estalo do chicote.
    Some com a Parte: decepado o Ferrão, a Sim tira o ataque e a malha some.
    """
    windup, active, recovery = WHIP
    total = windup + active + recovery
    poses = {}
    back = ["seg_d", "seg_e", "seg_f", "stinger"]
    for index, name in enumerate(back):
        lead = index * 0.035
        poses[name] = [
            (0.0, (0, 0, 0), None, "accel"),
            (windup + lead, (0, -6, 30 + index * 10), None, "hit"),
            (windup + active + lead, (0, 8, -34 - index * 12), None, "ease"),
            (windup + active + lead + 0.30, (0, 2, -10 - index * 3), None, "ease"),
            (total, (0, 0, 0), None, "settle"),
        ]
    # A frente ancora: ela firma a cabeça e gira o corpo em volta dela.
    poses["root"] = [(0.0, (0, 0, 0), None, "accel"), (windup, (0, 0, -10), None, "hit"),
                     (windup + active, (0, 0, 12), None, "ease"),
                     (total, (0, 0, 0), None, "settle")]
    for name in ("seg_b", "seg_a", "neck", "head"):
        poses[name] = [(0.0, (0, 0, 0), None, "accel"), (windup, (0, 0, 8), None, "hit"),
                       (windup + active, (0, 0, -9), None, "ease"),
                       (total, (0, 0, 0), None, "settle")]
    for side, sign in (("r", -1.0), ("l", 1.0)):
        poses["antenna_%s" % side] = [(0.0, (0, 0, 0), None, "accel"),
                                      (windup, (0, -10, sign * 8), None, "ease"),
                                      (total, (0, 0, 0), None, "settle")]
    poses.update(_hold_legs(total))
    common.animation(rig, "whip", total, poses, space="world")


def _serpentine(rig) -> None:
    """Serpenteada: comprime em S, dispara em linha e esparrama.

    O Preparo dobra o corpo para um lado (0,78 s de leitura), o Ativo
    endireita tudo e joga a raiz 0,85 m à frente, e a Recuperação é o corpo
    comprido largado no chão — a punição que a ficha promete (+0,6 s se
    errar, do lado da Sim).
    """
    windup, active, recovery = SERPENTINE
    total = windup + active + recovery
    poses = {
        "root": [
            (0.0, (0, 0, 0), (0.0, 0.0, 0.0), "accel"),
            (windup * 0.6, (0, 0, -16), (-0.16, 0.10, 0.0), "wind"),
            (windup, (0, 0, -10), (-0.22, 0.06, 0.0), "hit"),
            (windup + active * 0.35, (0, 0, 4), (0.36, 0.0, 0.0), "linear"),
            (windup + active, (0, 0, 0), (0.85, 0.0, 0.0), "settle"),
            (windup + active + 0.35, (0, 0, 8), (0.46, -0.06, 0.0), "ease"),
            (total, (0, 0, 0), (0.0, 0.0, 0.0), "settle"),
        ],
    }
    # Cada segmento entra na onda com atraso: o S se forma e se desfaz.
    for index, (name, _px) in enumerate(SEGMENTS):
        if name == "root":
            continue
        swing = 26.0 if index % 2 == 0 else -26.0
        lead = index * 0.025
        poses[name] = [
            (0.0, (0, 0, 0), None, "accel"),
            (windup + lead, (0, 0, swing), None, "hit"),
            (windup + active * 0.5 + lead, (0, 0, -swing * 0.35), None, "ease"),
            (windup + active + lead, (0, 0, swing * 0.12), None, "ease"),
            (total, (0, 0, 0), None, "settle"),
        ]
    poses.update(_legs(total, amplitude=34.0, samples=14))
    common.animation(rig, "serpentine", total, poses, space="world")


def _coil(rig) -> None:
    """Enrodilho: enrola em espiral e abre de uma vez, em círculo.

    0,95 s de Preparo enrolando é o aviso mais generoso dela, e é de
    propósito: a ficha usa este ataque para ENSINAR a interrupção (janela
    0,60 s, limiar 60). Quem fica perto vê o corpo inteiro fechando em volta.
    """
    windup, active, recovery = COIL
    total = windup + active + recovery
    poses = {}
    for index, (name, _px) in enumerate(SEGMENTS):
        if name == "root":
            poses[name] = [(0.0, (0, 0, 0), (0.0, 0.0, 0.0), "accel"),
                           (windup, (0, -8, 0), (0.0, 0.0, 0.10), "hit"),
                           (windup + active, (0, 6, 0), (0.0, 0.0, -0.05), "bounce"),
                           (total, (0, 0, 0), (0.0, 0.0, 0.0), "settle")]
            continue
        # Espiral: o giro por segmento cresce com a distância da raiz.
        curl = 34.0 if index < 4 else -34.0
        poses[name] = [
            (0.0, (0, 0, 0), None, "accel"),
            (windup * 0.55, (0, 0, curl * 0.6), None, "accel"),
            (windup, (0, 0, curl), None, "hit"),
            (windup + active, (0, 0, -curl * 0.45), None, "ease"),
            (windup + active + 0.42, (0, 0, -curl * 0.12), None, "ease"),
            (total, (0, 0, 0), None, "settle"),
        ]
    for side, sign in (("r", -1.0), ("l", 1.0)):
        poses["jaw_%s" % side] = [(0.0, (0, 0, 0), None, "accel"),
                                  (windup, (0, 0, -sign * 26), None, "hit"),
                                  (windup + active, (0, 0, sign * 10), None, "ease"),
                                  (total, (0, 0, 0), None, "settle")]
    poses.update(_hold_legs(total, angle=-18.0))
    common.animation(rig, "coil", total, poses, space="world")


def _static_lash(rig) -> None:
    """Látego Estático: empina a frente e desfere um corredor à frente.

    A frente sobe durante o Preparo (`ry` negativo levanta a ponta de um osso
    que aponta para a frente) e desce em linha reta no Ativo — o corredor
    desenhado no chão é essa descida. As antenas apontam o alvo: com elas
    inteiras, a ficha diz que ela MIRA O PONTO DE FUGA.
    """
    _attack(rig, "static_lash", LASH,
            wind={
                "seg_a": (0, -22, 0), "neck": (0, -30, 0), "head": (0, -24, 0),
                "seg_b": (0, -8, 0),
                "jaw_r": (0, 0, -18), "jaw_l": (0, 0, 18),
                "antenna_r": (0, -24, -6), "antenna_l": (0, -24, 6),
            },
            hit={
                "seg_a": (0, 16, 0), "neck": (0, 26, 0), "head": (0, 22, 0),
                "seg_b": (0, 6, 0),
                "jaw_r": (0, 0, 8), "jaw_l": (0, 0, -8),
                "antenna_r": (0, 18, -2), "antenna_l": (0, 18, 2),
            }, amount=0.24)


def _discharge(rig) -> None:
    """Descarga Plena: 2 s empinada como cobra, estouro e desabamento.

    É o clipe mais importante dela. O Preparo é o maior do jogo e existe para
    ser INTERROMPIDO: a frente sobe em três tempos (sobe, treme, trava no
    alto com as tenazes abertas), e esse tremor é o relógio que o grupo lê
    para decidir quem vai dar o boop. O Ativo é um só quadro de estouro —
    a frente desaba sobre o próprio corpo. A Recuperação de 1,40 s é a maior
    janela de punição da ficha.
    """
    windup, active, recovery = DISCHARGE
    total = windup + active + recovery
    rise = windup * 0.45
    poses = {}
    for name, up in (("seg_b", -16.0), ("seg_a", -34.0), ("neck", -46.0), ("head", -34.0)):
        poses[name] = [
            (0.0, (0, 0, 0), None, "accel"),
            (rise, (0, up * 0.85, 0), None, "ease"),
            # O tremor: duas sacudidas no alto, o relógio do boop.
            (windup * 0.70, (0, up, 4), None, "ease"),
            (windup * 0.86, (0, up * 0.96, -4), None, "ease"),
            (windup, (0, up, 0), None, "hit"),
            (windup + active, (0, -up * 0.55, 0), None, "bounce"),
            (windup + active + recovery * 0.45, (0, -up * 0.18, 0), None, "ease"),
            (total, (0, 0, 0), None, "settle"),
        ]
    poses["root"] = [
        (0.0, (0, 0, 0), (0.0, 0.0, 0.0), "accel"),
        (rise, (0, -6, 0), (-0.10, 0.0, 0.04), "ease"),
        (windup, (0, -8, 0), (-0.12, 0.0, 0.05), "hit"),
        (windup + active, (0, 10, 0), (0.08, 0.0, -0.08), "bounce"),
        (total, (0, 0, 0), (0.0, 0.0, 0.0), "settle"),
    ]
    # A traseira se planta: ela para de andar para disparar isto.
    for index, name in enumerate(("seg_d", "seg_e", "seg_f", "stinger")):
        poses[name] = [
            (0.0, (0, 0, 0), None, "accel"),
            (rise, (0, 6 + index * 3, 0), None, "ease"),
            (windup, (0, 8 + index * 4, 0), None, "hit"),
            (windup + active, (0, -6 - index * 2, 0), None, "bounce"),
            (total, (0, 0, 0), None, "settle"),
        ]
    for side, sign in (("r", -1.0), ("l", 1.0)):
        poses["jaw_%s" % side] = [
            (0.0, (0, 0, 0), None, "accel"),
            (rise, (0, 0, -sign * 30), None, "ease"),
            (windup, (0, 0, -sign * 40), None, "hit"),
            (windup + active, (0, 0, sign * 14), None, "ease"),
            (total, (0, 0, 0), None, "settle"),
        ]
        poses["antenna_%s" % side] = [
            (0.0, (0, 0, 0), None, "accel"),
            (rise, (0, -26, sign * 14), None, "ease"),
            (windup, (0, -32, sign * 18), None, "hit"),
            (windup + active, (0, 16, -sign * 6), None, "ease"),
            (total, (0, 0, 0), None, "settle"),
        ]
    poses.update(_hold_legs(total, angle=-22.0))
    common.animation(rig, "discharge", total, poses, space="world")


def _roar(rig) -> None:
    """Rugido da Fúria: ela se ergue, abre as tenazes e estala o corpo
    inteiro — a ficha diz que em Fúria o núcleo pulsa ao dobro."""
    poses = {}
    for name, up in (("seg_a", -18.0), ("neck", -28.0), ("head", -22.0)):
        poses[name] = [(0.0, (0, 0, 0), None, "accel"),
                       (0.45, (0, up, 0), None, "ease"),
                       (1.0, (0, up * 0.92, 6), None, "ease"),
                       (1.5, (0, up, -6), None, "ease"),
                       (ROAR, (0, 0, 0), None, "settle")]
    for index, name in enumerate(("seg_b", "root", "seg_d", "seg_e", "seg_f", "stinger")):
        poses[name] = [(0.0, (0, 0, 0), None, "accel"),
                       (0.45, (0, 4 + index, 8 - index * 2), None, "ease"),
                       (1.2, (0, 4 + index, -8 + index * 2), None, "ease"),
                       (ROAR, (0, 0, 0), None, "settle")]
    for side, sign in (("r", -1.0), ("l", 1.0)):
        poses["jaw_%s" % side] = [(0.0, (0, 0, 0), None, "accel"),
                                  (0.4, (0, 0, -sign * 38), None, "ease"),
                                  (1.5, (0, 0, -sign * 32), None, "ease"),
                                  (ROAR, (0, 0, 0), None, "settle")]
        poses["antenna_%s" % side] = [(0.0, (0, 0, 0), None, "accel"),
                                      (0.5, (0, -22, sign * 16), None, "ease"),
                                      (1.4, (0, -18, -sign * 10), None, "ease"),
                                      (ROAR, (0, 0, 0), None, "settle")]
    poses.update(_hold_legs(ROAR, angle=-16.0))
    common.animation(rig, "roar", ROAR, poses, space="world")


def _stagger(rig) -> None:
    """Queda do Atordoamento: tomba de lado, o corpo comprido se debate.

    Num corpo de seis segmentos a queda não é um bloco virando: ela tomba em
    onda, da frente para trás, e as pernas de um lado ficam batendo no ar.
    4,5 s é a janela de punição; aqui ela entrega o dorso inteiro.
    """
    roll = 78.0
    poses = {}
    for index, (name, _px) in enumerate(SEGMENTS):
        lead = index * 0.055
        if name == "root":
            # Sem DESCER a raiz: ela já é baixa (0,72 m) e o corpo é largo —
            # tombar 78° joga a borda do dorso 0,78 m abaixo do pivô. Com o
            # deslocamento negativo do quadrúpede, meio corpo entrava no chão
            # (apareceu no preview). Aqui ela SOBE um dedo e desliza de lado.
            poses[name] = [
                (0.0, (0, 0, 0), (0.0, 0.0, 0.0), "accel"),
                (0.22, (-14, 4, 0), (0.0, 0.08, 0.03), "hit"),
                (0.55, (roll, 2, 0), (0.0, -0.26, 0.06), "bounce"),
                (1.8, (roll - 6, 2, -4), (0.0, -0.26, 0.05), "ease"),
                (2.9, (roll + 4, 3, 4), (0.0, -0.27, 0.07), "ease"),
                (3.9, (roll - 8, 2, 0), (0.0, -0.25, 0.05), "wind"),
                (4.25, (22, 1, 0), (0.0, -0.09, 0.02), "ease"),
                (FALL, (0, 0, 0), (0.0, 0.0, 0.0), "settle"),
            ]
            continue
        poses[name] = [
            (0.0, (0, 0, 0), None, "accel"),
            (0.22 + lead, (-10, 3, 6), None, "hit"),
            (0.55 + lead, (14, 2, -12), None, "bounce"),
            (1.8, (10, 2, 10), None, "ease"),
            (2.9, (16, 3, -10), None, "ease"),
            (4.25, (4, 1, 2), None, "ease"),
            (FALL, (0, 0, 0), None, "settle"),
        ]
    for side, sign in (("r", -1.0), ("l", 1.0)):
        poses["jaw_%s" % side] = [(0.0, (0, 0, 0), None, "accel"),
                                  (0.55, (0, 0, -sign * 24), None, "ease"),
                                  (2.9, (0, 0, -sign * 18), None, "ease"),
                                  (FALL, (0, 0, 0), None, "settle")]
        poses["antenna_%s" % side] = [(0.0, (0, 0, 0), None, "accel"),
                                      (0.55, (0, 26, sign * 10), None, "bounce"),
                                      (2.9, (0, 22, -sign * 8), None, "ease"),
                                      (FALL, (0, 0, 0), None, "settle")]
    # Pernas batendo no ar: duas rodadas de espernear durante a queda.
    poses.update(_legs(FALL, amplitude=22.0, bias=-16.0, samples=20))
    common.animation(rig, "stagger_fall", FALL, poses, space="world")


def _death(rig) -> None:
    """Morte: o corpo relaxa num S frouxo, as pernas recolhem e para.

    Congela na última pose — a Godot não dá laço no clipe de morte.
    """
    poses = {}
    for index, (name, _px) in enumerate(SEGMENTS):
        lead = index * 0.06
        swing = 16.0 if index % 2 == 0 else -16.0
        if name == "root":
            poses[name] = [
                (0.0, (0, 0, 0), (0.0, 0.0, 0.0), "wind"),
                (0.40, (-8, 6, 0), (0.0, 0.03, -0.04), "accel"),
                (1.05, (62, 3, 0), (0.0, -0.24, 0.04), "bounce"),
                (1.45, (68, 3, 0), (0.0, -0.26, 0.05), "settle"),
                (DEATH, (70, 3, 0), (0.0, -0.26, 0.05), "settle"),
            ]
            continue
        poses[name] = [
            (0.0, (0, 0, 0), None, "wind"),
            (0.40 + lead, (-6, 4, swing * 0.5), None, "accel"),
            (1.05 + lead, (10, 2, swing), None, "bounce"),
            (DEATH, (12, 2, swing * 0.9), None, "settle"),
        ]
    for side, sign in (("r", -1.0), ("l", 1.0)):
        poses["jaw_%s" % side] = [(0.0, (0, 0, 0), None, "wind"),
                                  (1.05, (0, 0, -sign * 14), None, "bounce"),
                                  (DEATH, (0, 0, -sign * 12), None, "settle")]
        poses["antenna_%s" % side] = [(0.0, (0, 0, 0), None, "wind"),
                                      (1.05, (0, 22, sign * 6), None, "bounce"),
                                      (DEATH, (0, 24, sign * 5), None, "settle")]
    for name, _px in LEG_SEGMENTS:
        for side in ("r", "l"):
            poses["legs_%s_%s" % (name, side)] = [
                (0.0, (0, 0, 0), None, "wind"),
                (0.40, (0, -24, 0), None, "accel"),
                (1.05, (0, -40, 0), None, "bounce"),
                (DEATH, (0, -42, 0), None, "settle"),
            ]
    common.animation(rig, "death", DEATH, poses, space="world")


build()
