# -*- coding: utf-8 -*-
"""O quadrúpede mordedor: criatura original da casa, low-poly cartunesca.

Silhueta: corpanzil arredondado de sapo-javali, mandíbula inferior enorme com
dentes em bloco (prognata), placas de pedra nas costas, cauda-clava de osso e
quatro patas curtas e grossas. Paleta: musgo, areia, ardósia, osso e âmbar.

A cauda é UMA malha chamada "tail", presa ao osso "tail": a Godot a esconde
quando a Parte é decepada.

As durações das animações de ataque vêm de src/sim/behemoths.gd
(windup + active + recovery):
    bite  = 0.62+0.16+0.62 = 1.40 s
    charge= 0.82+0.42+0.85 = 2.09 s
    tail  = 0.52+0.20+0.70 = 1.42 s
    stomp = 0.70+0.18+0.75 = 1.63 s
E de sim_config.gd: stagger_fall = STAGGER_DOWN_DURATION = 4.5 s.

Rodar:  blender --background --python tools/models/quadruped.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common

OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "quadruped.glb"
)

BITE = 1.40
CHARGE = 2.09
TAIL = 1.42
STOMP = 1.63
ROAR = 2.0
FALL = 4.5
DEATH = 2.0


def build() -> None:
    common.reset_scene()

    # Paleta viva e contrastada: couro saturado, barriga clara, placas quase
    # pretas, osso claro, goela vermelha, olhos âmbar.
    moss = common.material("quad_moss", "4e9e3f")
    belly = common.material("quad_belly", "f0dca6")
    slate = common.material("quad_slate", "2e343b")
    bone = common.material("quad_bone", "f5ecd8")
    maw = common.material("quad_maw", "b33c3c")
    eye = common.material("quad_eye", "ffc24d", roughness=0.3)

    # Olha para +X. Uma muralha de músculo: ombro a ~2,3 m (o dobro do
    # Caçador), mandíbula inferior maior que o focinho.
    rig = common.armature("Quadruped", {
        "root": ((0.0, 0.0, 1.1), (0.0, 0.0, 1.8), None),
        "head": ((1.3, 0.0, 1.45), (2.4, 0.0, 1.45), "root"),
        "jaw": ((1.35, 0.0, 0.95), (2.6, 0.0, 0.85), "head"),
        "tail": ((-1.4, 0.0, 1.35), (-3.3, 0.0, 1.55), "root"),
        "leg_fr": ((0.75, -0.85, 1.0), (0.78, -0.88, 0.05), "root"),
        "leg_fl": ((0.75, 0.85, 1.0), (0.78, 0.88, 0.05), "root"),
        "leg_br": ((-0.75, -0.85, 1.0), (-0.78, -0.88, 0.05), "root"),
        "leg_bl": ((-0.75, 0.85, 1.0), (-0.78, 0.88, 0.05), "root"),
    })

    # --- Corpo: massudo e largo ---
    common.attach(
        common.sphere("body", 1.3, (0.0, 0.0, 1.4), moss, subdivisions=2, squash=(1.2, 0.95, 0.72)),
        rig, "root",
    )
    common.attach(
        common.sphere("hump", 0.85, (-0.3, 0.0, 1.95), moss, subdivisions=2, squash=(1.1, 0.85, 0.6)),
        rig, "root",
    )
    common.attach(
        common.sphere("belly", 1.05, (0.15, 0.0, 1.0), belly, subdivisions=2, squash=(1.15, 0.85, 0.55)),
        rig, "root",
    )
    # Placas dorsais quase pretas, da nuca à garupa.
    for i, (px, scale) in enumerate([(0.55, 0.62), (0.0, 0.72), (-0.6, 0.58)]):
        common.attach(
            common.box(
                "plate_%d" % i,
                (scale, scale * 0.85, 0.34),
                (px, 0.0, 2.2 - abs(px) * 0.18),
                slate,
                rotation=(0.0, 0.35, 0.0),
            ),
            rig, "root",
        )
    # Cicatriz clara no flanco direito: detalhe de leitura.
    common.attach(
        common.box("scar", (0.5, 0.06, 0.28), (0.2, -1.12, 1.55), bone, rotation=(0.0, 0.5, 0.3)),
        rig, "root",
    )

    # --- Cabeça pesada ---
    common.attach(common.box("head", (1.3, 1.5, 0.95), (1.95, 0.0, 1.58), moss), rig, "head")
    common.attach(common.box("muzzle", (0.55, 1.25, 0.45), (2.45, 0.0, 1.42), belly), rig, "head")
    common.attach(common.box("brow", (0.7, 1.6, 0.25), (2.1, 0.0, 2.08), slate), rig, "head")
    common.attach(common.sphere("eye_r", 0.14, (2.5, -0.52, 1.82), eye, subdivisions=1), rig, "head")
    common.attach(common.sphere("eye_l", 0.14, (2.5, 0.52, 1.82), eye, subdivisions=1), rig, "head")
    common.attach(common.box("teeth_top", (0.16, 1.15, 0.2), (2.62, 0.0, 1.16), bone), rig, "head")

    # --- A mandíbula: a alma do monstro. Mais larga que o focinho, lábio à
    # frente, dentões subindo à vista até de costas. ---
    common.attach(common.box("jaw", (1.65, 1.95, 0.55), (2.35, 0.0, 0.72), moss), rig, "jaw")
    common.attach(common.box("chin", (0.55, 1.25, 0.34), (3.05, 0.0, 0.66), slate), rig, "jaw")
    common.attach(common.box("maw", (1.4, 1.6, 0.14), (2.35, 0.0, 1.02), maw), rig, "jaw")
    # Quatro dentões centrais + duas presas de canto mais altas.
    for i, ty in enumerate([-0.45, -0.15, 0.15, 0.45]):
        common.attach(
            common.box("tooth_%d" % i, (0.22, 0.24, 0.72), (3.0, ty, 1.26), bone),
            rig, "jaw",
        )
    for i, ty in enumerate([-0.88, 0.88]):
        common.attach(
            common.box("tusk_%d" % i, (0.26, 0.28, 1.0), (2.75, ty, 1.4), bone, rotation=(0.22 if ty > 0 else -0.22, -0.12, 0.0)),
            rig, "jaw",
        )

    # --- Cauda-clava: UMA malha "tail", com ponta óssea volumosa (o alvo
    # visual de "corte aqui") ---
    tail_parts = [
        common.box("tail_a", (0.95, 0.85, 0.62), (-1.85, 0.0, 1.42), moss),
        common.box("tail_b", (0.85, 0.6, 0.48), (-2.55, 0.0, 1.52), moss),
        common.sphere("tail_club", 0.52, (-3.25, 0.0, 1.6), bone, subdivisions=1, squash=(1.25, 0.9, 1.05)),
        common.box("tail_spike_a", (0.4, 0.16, 0.7), (-3.35, 0.0, 2.0), bone, rotation=(0.0, -0.5, 0.0)),
        common.box("tail_spike_b", (0.5, 0.14, 0.3), (-3.6, 0.0, 1.5), bone, rotation=(0.0, 0.4, 0.0)),
    ]
    tail = common.join(tail_parts, "tail")
    common.attach(tail, rig, "tail")

    # --- Patas grossas com garras claras ---
    for bone_name, px, py in [
        ("leg_fr", 0.75, -0.88), ("leg_fl", 0.75, 0.88),
        ("leg_br", -0.75, -0.88), ("leg_bl", -0.75, 0.88),
    ]:
        common.attach(
            common.cylinder("%s_leg" % bone_name, 0.34, 1.05, (px + 0.02, py, 0.6), moss),
            rig, bone_name,
        )
        common.attach(
            common.box("%s_foot" % bone_name, (0.56, 0.6, 0.24), (px + 0.12, py, 0.12), slate),
            rig, bone_name,
        )
        common.attach(
            common.box("%s_claws" % bone_name, (0.26, 0.5, 0.16), (px + 0.46, py, 0.08), bone),
            rig, bone_name,
        )

    _animate(rig)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    common.export_glb(os.path.abspath(OUT))


def _animate(rig) -> None:
    # Eixos (validados nos previews do Caçador):
    #   root vertical: Y = girar · Z = inclinar frente/trás · X = rolar de lado
    #   ossos horizontais (head/jaw/tail): X = pitch · Z = yaw · Y = rolar
    #   patas (apontando para baixo): X = balanço frente/trás

    common.animation(rig, "idle", 2.0, {
        "root": [(0.0, (0, 0, 0), (0.0, 0.0, 0.0)), (1.0, (0, 0, 1), (0.0, 0.04, 0.0)), (2.0, (0, 0, 0), (0.0, 0.0, 0.0))],
        "jaw": [(0.0, (0, 0, 0)), (1.0, (6, 0, 0)), (2.0, (0, 0, 0))],
        "tail": [(0.0, (0, 0, 0)), (1.0, (0, 0, 7)), (2.0, (0, 0, 0))],
        "head": [(0.0, (0, 0, 0)), (1.0, (-3, 0, 2)), (2.0, (0, 0, 0))],
    })

    common.animation(rig, "walk", 0.9, {
        "leg_fr": [(0.0, (22, 0, 0)), (0.45, (-22, 0, 0)), (0.9, (22, 0, 0))],
        "leg_bl": [(0.0, (22, 0, 0)), (0.45, (-22, 0, 0)), (0.9, (22, 0, 0))],
        "leg_fl": [(0.0, (-22, 0, 0)), (0.45, (22, 0, 0)), (0.9, (-22, 0, 0))],
        "leg_br": [(0.0, (-22, 0, 0)), (0.45, (22, 0, 0)), (0.9, (-22, 0, 0))],
        "root": [(0.0, (2, 0, 0)), (0.45, (-2, 0, 0)), (0.9, (2, 0, 0))],
        "head": [(0.0, (0, 0, 3)), (0.45, (0, 0, -3)), (0.9, (0, 0, 3))],
        "tail": [(0.0, (0, 0, 9)), (0.45, (0, 0, -9)), (0.9, (0, 0, 9))],
    })

    # Mordida: windup 0.62 (cabeça ergue, boca escancara) / active 0.62–0.78
    # (bote para baixo, boca fecha) / recuperação até 1.40.
    common.animation(rig, "bite", BITE, {
        "head": [(0.0, (0, 0, 0)), (0.62, (-26, 0, 0)), (0.78, (16, 0, 0)), (1.0, (10, 0, 0)), (BITE, (0, 0, 0))],
        "jaw": [(0.0, (0, 0, 0)), (0.62, (44, 0, 0)), (0.78, (2, 0, 0)), (BITE, (0, 0, 0))],
        "root": [(0.0, (0, 0, 0), (0.0, 0.0, 0.0)), (0.62, (0, 0, -7), (0.0, 0.0, 0.0)), (0.78, (0, 0, 9), (0.0, -0.1, 0.0)), (BITE, (0, 0, 0), (0.0, 0.0, 0.0))],
        "leg_fr": [(0.0, (0, 0, 0)), (0.62, (-14, 0, 0)), (0.78, (10, 0, 0)), (BITE, (0, 0, 0))],
        "leg_fl": [(0.0, (0, 0, 0)), (0.62, (-14, 0, 0)), (0.78, (10, 0, 0)), (BITE, (0, 0, 0))],
    })

    # Investida: windup 0.82 (agacha e arma) / active 0.82–1.24 (corpo em
    # flecha, patas para trás) / recuperação longa com sacudida.
    common.animation(rig, "charge", CHARGE, {
        "root": [
            (0.0, (0, 0, 0), (0.0, 0.0, 0.0)),
            (0.82, (0, 0, -12), (0.0, -0.12, 0.0)),
            (1.0, (0, 0, 10), (0.0, 0.05, 0.0)),
            (1.24, (0, 0, 8), (0.0, 0.0, 0.0)),
            (1.7, (0, 0, -4), (0.0, 0.0, 0.0)),
            (CHARGE, (0, 0, 0), (0.0, 0.0, 0.0)),
        ],
        "head": [(0.0, (0, 0, 0)), (0.82, (12, 0, 0)), (1.0, (-8, 0, 0)), (1.24, (-6, 0, 0)), (CHARGE, (0, 0, 0))],
        "jaw": [(0.0, (0, 0, 0)), (0.82, (30, 0, 0)), (1.24, (18, 0, 0)), (CHARGE, (0, 0, 0))],
        "leg_fr": [(0.0, (0, 0, 0)), (0.82, (26, 0, 0)), (1.0, (-30, 0, 0)), (1.24, (-26, 0, 0)), (CHARGE, (0, 0, 0))],
        "leg_fl": [(0.0, (0, 0, 0)), (0.82, (26, 0, 0)), (1.0, (-30, 0, 0)), (1.24, (-26, 0, 0)), (CHARGE, (0, 0, 0))],
        "leg_br": [(0.0, (0, 0, 0)), (0.82, (-20, 0, 0)), (1.0, (30, 0, 0)), (1.24, (26, 0, 0)), (CHARGE, (0, 0, 0))],
        "leg_bl": [(0.0, (0, 0, 0)), (0.82, (-20, 0, 0)), (1.0, (30, 0, 0)), (1.24, (26, 0, 0)), (CHARGE, (0, 0, 0))],
        "tail": [(0.0, (0, 0, 0)), (0.82, (14, 0, 0)), (1.24, (-10, 0, 0)), (CHARGE, (0, 0, 0))],
    })

    # Rabada: windup 0.52 (torce e enrola a cauda) / active 0.52–0.72
    # (destorce com tudo) / recuperação até 1.42.
    common.animation(rig, "tail", TAIL, {
        "root": [(0.0, (0, 0, 0)), (0.52, (0, -38, 0)), (0.72, (0, 48, 0)), (1.1, (0, 14, 0)), (TAIL, (0, 0, 0))],
        "tail": [(0.0, (0, 0, 0)), (0.52, (0, 55, 0)), (0.72, (0, -70, 0)), (1.1, (0, -20, 0)), (TAIL, (0, 0, 0))],
        "head": [(0.0, (0, 0, 0)), (0.52, (0, 0, 18)), (0.72, (0, 0, -16)), (TAIL, (0, 0, 0))],
    })

    # Pisão: windup 0.70 (empina) / active 0.70–0.88 (desaba) / até 1.63.
    common.animation(rig, "stomp", STOMP, {
        "root": [
            (0.0, (0, 0, 0), (0.0, 0.0, 0.0)),
            (0.70, (0, 0, -30), (0.0, 0.35, 0.0)),
            (0.88, (0, 0, 6), (0.0, -0.18, 0.0)),
            (1.1, (0, 0, 2), (0.0, 0.0, 0.0)),
            (STOMP, (0, 0, 0), (0.0, 0.0, 0.0)),
        ],
        "leg_fr": [(0.0, (0, 0, 0)), (0.70, (-52, 0, 0)), (0.88, (6, 0, 0)), (STOMP, (0, 0, 0))],
        "leg_fl": [(0.0, (0, 0, 0)), (0.70, (-52, 0, 0)), (0.88, (6, 0, 0)), (STOMP, (0, 0, 0))],
        "head": [(0.0, (0, 0, 0)), (0.70, (-18, 0, 0)), (0.88, (10, 0, 0)), (STOMP, (0, 0, 0))],
        "jaw": [(0.0, (0, 0, 0)), (0.70, (36, 0, 0)), (0.88, (8, 0, 0)), (STOMP, (0, 0, 0))],
    })

    # Rugido da Fúria: cabeça ao alto, boca escancarada, sacudida.
    common.animation(rig, "roar", ROAR, {
        "head": [(0.0, (0, 0, 0)), (0.4, (-34, 0, 0)), (0.9, (-30, 0, 6)), (1.3, (-32, 0, -6)), (ROAR, (0, 0, 0))],
        "jaw": [(0.0, (0, 0, 0)), (0.4, (52, 0, 0)), (1.3, (46, 0, 0)), (ROAR, (0, 0, 0))],
        "root": [(0.0, (0, 0, 0)), (0.4, (0, 0, -14)), (1.3, (0, 0, -12)), (ROAR, (0, 0, 0))],
        "tail": [(0.0, (0, 0, 0)), (0.7, (0, 0, 16)), (1.2, (0, 0, -16)), (ROAR, (0, 0, 0))],
    })

    # Queda do Atordoamento: tomba de lado, fica estirado, levanta no fim.
    fall_roll = (58, 0, 4)
    fall_drop = (0.0, -0.45, 0.0)
    common.animation(rig, "stagger_fall", FALL, {
        "root": [
            (0.0, (0, 0, 0), (0.0, 0.0, 0.0)),
            (0.35, fall_roll, fall_drop),
            (2.0, (54, 0, 4), fall_drop),
            (3.6, fall_roll, fall_drop),
            (4.1, (10, 0, 0), (0.0, -0.1, 0.0)),
            (FALL, (0, 0, 0), (0.0, 0.0, 0.0)),
        ],
        "leg_fr": [(0.0, (0, 0, 0)), (0.35, (30, 0, 0)), (2.0, (36, 0, 0)), (4.1, (6, 0, 0)), (FALL, (0, 0, 0))],
        "leg_fl": [(0.0, (0, 0, 0)), (0.35, (-26, 0, 0)), (2.0, (-20, 0, 0)), (4.1, (-4, 0, 0)), (FALL, (0, 0, 0))],
        "leg_br": [(0.0, (0, 0, 0)), (0.35, (24, 0, 0)), (2.0, (18, 0, 0)), (4.1, (4, 0, 0)), (FALL, (0, 0, 0))],
        "leg_bl": [(0.0, (0, 0, 0)), (0.35, (-28, 0, 0)), (2.0, (-24, 0, 0)), (4.1, (-6, 0, 0)), (FALL, (0, 0, 0))],
        "jaw": [(0.0, (0, 0, 0)), (0.35, (30, 0, 0)), (2.0, (22, 0, 0)), (FALL, (0, 0, 0))],
        "head": [(0.0, (0, 0, 0)), (0.35, (8, 0, -10)), (2.0, (6, 0, -8)), (FALL, (0, 0, 0))],
    })

    # Morte: desaba e fica. A pose final é a última chave — a Godot congela nela.
    common.animation(rig, "death", DEATH, {
        "root": [
            (0.0, (0, 0, 0), (0.0, 0.0, 0.0)),
            (0.5, (74, 0, 6), (0.0, -0.5, 0.0)),
            (DEATH, (78, 0, 6), (0.0, -0.55, 0.0)),
        ],
        "leg_fr": [(0.0, (0, 0, 0)), (0.5, (34, 0, 0)), (DEATH, (38, 0, 0))],
        "leg_fl": [(0.0, (0, 0, 0)), (0.5, (-30, 0, 0)), (DEATH, (-34, 0, 0))],
        "leg_br": [(0.0, (0, 0, 0)), (0.5, (28, 0, 0)), (DEATH, (30, 0, 0))],
        "leg_bl": [(0.0, (0, 0, 0)), (0.5, (-26, 0, 0)), (DEATH, (-28, 0, 0))],
        "jaw": [(0.0, (0, 0, 0)), (0.5, (40, 0, 0)), (DEATH, (44, 0, 0))],
        "head": [(0.0, (0, 0, 0)), (0.5, (12, 0, 0)), (DEATH, (14, 0, 0))],
        "tail": [(0.0, (0, 0, 0)), (0.5, (0, 0, 20)), (DEATH, (0, 0, 22))],
    })


build()
