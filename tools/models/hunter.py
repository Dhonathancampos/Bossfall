# -*- coding: utf-8 -*-
"""O Caçador: humanoide low-poly cartunesco, riggado e animado.

Design original da casa: proporções exageradas (ombreiras e mãos grandes,
cabeça marcante), cores chapadas, silhueta legível de longe. O material
"accent" (cachecol e faixa) existe para a Godot recolorir por jogador.

As durações dos Golpes vêm dos números da Espada em src/sim/weapons.gd:
    light_1 = 0.12+0.08+0.22 = 0.42 s
    light_2 = 0.11+0.08+0.24 = 0.43 s
    light_3 = 0.16+0.14+0.36 = 0.66 s
    heavy   = 0.32+0.10+0.42 = 0.84 s
Mudou lá, muda aqui — o corpo conta o tempo exato do Comprometimento.

Rodar:  blender --background --python tools/models/hunter.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common

OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "hunter.glb"
)

# Durações espelhadas de weapons.gd (windup + active + recovery).
LIGHT_1 = 0.42
LIGHT_2 = 0.43
LIGHT_3 = 0.66
HEAVY = 0.84
# E de sim_config.gd: DODGE_DURATION + DODGE_RECOVERY, HURT_DURATION.
DODGE = 0.34
HURT = 0.28


def build() -> None:
    common.reset_scene()

    armor = common.material("hunter_armor", "5a7d9e")
    armor_dark = common.material("hunter_armor_dark", "3c4f63")
    trim = common.material("hunter_trim", "e0a85a")
    skin = common.material("hunter_skin", "efb98c")
    leather = common.material("hunter_leather", "6d5240")
    accent = common.material("accent", "56c8ff")
    eyes = common.material("hunter_eyes", "2b2b33")

    # O Caçador olha para +X (a convenção da cena: o nariz da cápsula era +X).
    # Direita do corpo = -Y.
    rig = common.armature("Hunter", {
        "root": ((0.0, 0.0, 0.92), (0.0, 0.0, 1.12), None),
        "chest": ((0.0, 0.0, 1.12), (0.0, 0.0, 1.45), "root"),
        "head": ((0.0, 0.0, 1.45), (0.0, 0.0, 1.75), "chest"),
        "upper_arm_r": ((0.0, -0.40, 1.38), (0.0, -0.44, 1.12), "chest"),
        "forearm_r": ((0.0, -0.44, 1.12), (0.0, -0.46, 0.84), "upper_arm_r"),
        "hand_r": ((0.0, -0.46, 0.84), (0.12, -0.46, 0.80), "forearm_r"),
        "upper_arm_l": ((0.0, 0.40, 1.38), (0.0, 0.44, 1.12), "chest"),
        "forearm_l": ((0.0, 0.44, 1.12), (0.0, 0.46, 0.84), "upper_arm_l"),
        "thigh_r": ((0.0, -0.14, 0.96), (0.0, -0.14, 0.50), "root"),
        "shin_r": ((0.0, -0.14, 0.50), (0.0, -0.14, 0.08), "thigh_r"),
        "thigh_l": ((0.0, 0.14, 0.96), (0.0, 0.14, 0.50), "root"),
        "shin_l": ((0.0, 0.14, 0.50), (0.0, 0.14, 0.08), "thigh_l"),
    })

    # --- Tronco ---
    # As peças se sobrepõem nas juntas de propósito: boneco de armar sem vão.
    common.attach(common.box("pelvis", (0.36, 0.42, 0.26), (0.0, 0.0, 1.00), leather), rig, "root")
    common.attach(common.box("belt", (0.40, 0.46, 0.08), (0.0, 0.0, 1.12), trim), rig, "root")
    common.attach(common.box("torso", (0.42, 0.52, 0.46), (0.0, 0.0, 1.32), armor), rig, "chest")
    common.attach(common.box("chestplate", (0.10, 0.38, 0.30), (0.19, 0.0, 1.33), armor_dark), rig, "chest")
    common.attach(common.box("scarf", (0.46, 0.50, 0.12), (0.0, 0.0, 1.50), accent), rig, "chest")

    # Ombreiras grandes: a silhueta cartunesca mora aqui.
    common.attach(
        common.sphere("pad_r", 0.19, (0.0, -0.34, 1.44), armor_dark, subdivisions=1, squash=(1.0, 1.0, 0.8)),
        rig, "chest",
    )
    common.attach(
        common.sphere("pad_l", 0.19, (0.0, 0.34, 1.44), armor_dark, subdivisions=1, squash=(1.0, 1.0, 0.8)),
        rig, "chest",
    )

    # --- Cabeça ---
    common.attach(common.box("head", (0.38, 0.40, 0.36), (0.0, 0.0, 1.64), skin), rig, "head")
    common.attach(common.box("hood", (0.34, 0.44, 0.16), (-0.03, 0.0, 1.83), accent), rig, "head")
    common.attach(common.box("eye_r", (0.03, 0.06, 0.08), (0.19, -0.10, 1.66), eyes), rig, "head")
    common.attach(common.box("eye_l", (0.03, 0.06, 0.08), (0.19, 0.10, 1.66), eyes), rig, "head")

    # --- Braços: antebraços e mãos grandes, juntas cobertas por esferas ---
    common.attach(common.sphere("shoulder_r", 0.10, (0.0, -0.40, 1.38), armor, subdivisions=1), rig, "upper_arm_r")
    common.attach(common.box("upper_arm_r", (0.15, 0.16, 0.36), (0.0, -0.41, 1.24), armor), rig, "upper_arm_r")
    common.attach(common.sphere("elbow_r", 0.09, (0.0, -0.44, 1.12), leather, subdivisions=1), rig, "forearm_r")
    common.attach(common.box("forearm_r", (0.18, 0.19, 0.34), (0.0, -0.45, 0.98), leather), rig, "forearm_r")
    common.attach(common.sphere("hand_r", 0.13, (0.0, -0.46, 0.82), skin, subdivisions=1), rig, "hand_r")
    common.attach(common.sphere("shoulder_l", 0.10, (0.0, 0.40, 1.38), armor, subdivisions=1), rig, "upper_arm_l")
    common.attach(common.box("upper_arm_l", (0.15, 0.16, 0.36), (0.0, 0.41, 1.24), armor), rig, "upper_arm_l")
    common.attach(common.sphere("elbow_l", 0.09, (0.0, 0.44, 1.12), leather, subdivisions=1), rig, "forearm_l")
    common.attach(common.box("forearm_l", (0.18, 0.19, 0.34), (0.0, 0.45, 0.98), leather), rig, "forearm_l")
    common.attach(common.sphere("hand_l", 0.13, (0.0, 0.46, 0.82), skin, subdivisions=1), rig, "forearm_l")

    # --- Pernas e botas, com joelhos cobertos ---
    common.attach(common.box("thigh_r", (0.20, 0.21, 0.48), (0.0, -0.14, 0.72), armor_dark), rig, "thigh_r")
    common.attach(common.sphere("knee_r", 0.10, (0.0, -0.14, 0.50), leather, subdivisions=1), rig, "shin_r")
    common.attach(common.box("shin_r", (0.17, 0.18, 0.44), (0.0, -0.14, 0.30), leather), rig, "shin_r")
    common.attach(common.box("boot_r", (0.32, 0.19, 0.14), (0.06, -0.14, 0.07), armor_dark), rig, "shin_r")
    common.attach(common.box("thigh_l", (0.20, 0.21, 0.48), (0.0, 0.14, 0.72), armor_dark), rig, "thigh_l")
    common.attach(common.sphere("knee_l", 0.10, (0.0, 0.14, 0.50), leather, subdivisions=1), rig, "shin_l")
    common.attach(common.box("shin_l", (0.17, 0.18, 0.44), (0.0, 0.14, 0.30), leather), rig, "shin_l")
    common.attach(common.box("boot_l", (0.32, 0.19, 0.14), (0.06, 0.14, 0.07), armor_dark), rig, "shin_l")

    _animate(rig)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    common.export_glb(os.path.abspath(OUT))


def _animate(rig) -> None:
    # Convenções de eixo observadas nos previews (ossos verticais):
    #   Y = girar no próprio eixo · Z = inclinar frente(+)/trás(-) · X = lado
    # Pernas/braços (apontando para baixo): X = balanço frente/trás.

    common.animation(rig, "idle", 1.6, {
        "chest": [(0.0, (0, 0, 0)), (0.8, (0, 0, 2.5)), (1.6, (0, 0, 0))],
        "head": [(0.0, (0, 0, 0)), (0.8, (0, 4, -2)), (1.6, (0, 0, 0))],
        "upper_arm_r": [(0.0, (0, 0, 0)), (0.8, (3, 0, 0)), (1.6, (0, 0, 0))],
        "upper_arm_l": [(0.0, (0, 0, 0)), (0.8, (3, 0, 0)), (1.6, (0, 0, 0))],
    })

    common.animation(rig, "walk", 0.8, {
        "thigh_r": [(0.0, (26, 0, 0)), (0.4, (-26, 0, 0)), (0.8, (26, 0, 0))],
        "thigh_l": [(0.0, (-26, 0, 0)), (0.4, (26, 0, 0)), (0.8, (-26, 0, 0))],
        "shin_r": [(0.0, (-14, 0, 0)), (0.4, (18, 0, 0)), (0.8, (-14, 0, 0))],
        "shin_l": [(0.0, (18, 0, 0)), (0.4, (-14, 0, 0)), (0.8, (18, 0, 0))],
        "upper_arm_r": [(0.0, (-18, 0, 0)), (0.4, (18, 0, 0)), (0.8, (-18, 0, 0))],
        "upper_arm_l": [(0.0, (18, 0, 0)), (0.4, (-18, 0, 0)), (0.8, (18, 0, 0))],
        "chest": [(0.0, (0, 3, 2)), (0.4, (0, -3, 2)), (0.8, (0, 3, 2))],
    })

    common.animation(rig, "sprint", 0.55, {
        "thigh_r": [(0.0, (48, 0, 0)), (0.275, (-44, 0, 0)), (0.55, (48, 0, 0))],
        "thigh_l": [(0.0, (-44, 0, 0)), (0.275, (48, 0, 0)), (0.55, (-44, 0, 0))],
        "shin_r": [(0.0, (-20, 0, 0)), (0.275, (34, 0, 0)), (0.55, (-20, 0, 0))],
        "shin_l": [(0.0, (34, 0, 0)), (0.275, (-20, 0, 0)), (0.55, (34, 0, 0))],
        "upper_arm_r": [(0.0, (-38, 0, 0)), (0.275, (34, 0, 0)), (0.55, (-38, 0, 0))],
        "upper_arm_l": [(0.0, (34, 0, 0)), (0.275, (-38, 0, 0)), (0.55, (34, 0, 0))],
        "chest": [(0.0, (0, 0, 14)), (0.55, (0, 0, 14))],
        "head": [(0.0, (0, -8, 0)), (0.55, (0, -8, 0))],
    })

    # Rolamento: um giro completo com mergulho — leitura instantânea, à prova
    # de eixo. O impulso dura 0.22 s; a recuperação devolve a pose.
    common.animation(rig, "dodge", DODGE, {
        "root": [
            (0.0, (0, 0, 0), (0.0, 0.0, 0.0)),
            (0.11, (0, 180, 0), (0.0, -0.38, 0.0)),
            (0.22, (0, 360, 0), (0.0, -0.1, 0.0)),
            (DODGE, (0, 360, 0), (0.0, 0.0, 0.0)),
        ],
        "chest": [(0.0, (0, 0, 10)), (0.11, (0, 0, 32)), (0.22, (0, 0, 8)), (DODGE, (0, 0, 0))],
        "thigh_r": [(0.0, (20, 0, 0)), (0.11, (58, 0, 0)), (0.22, (10, 0, 0)), (DODGE, (0, 0, 0))],
        "thigh_l": [(0.0, (20, 0, 0)), (0.11, (58, 0, 0)), (0.22, (10, 0, 0)), (DODGE, (0, 0, 0))],
        "shin_r": [(0.0, (-30, 0, 0)), (0.11, (-70, 0, 0)), (DODGE, (0, 0, 0))],
        "shin_l": [(0.0, (-30, 0, 0)), (0.11, (-70, 0, 0)), (DODGE, (0, 0, 0))],
    })

    # --- Golpes da Espada: Preparo → Ativo → Recuperação, nos segundos da Sim ---

    # Corte Horizontal: windup 0.12 / active 0.08 (0.12–0.20) / recovery até 0.42.
    common.animation(rig, "light_1", LIGHT_1, {
        "chest": [(0.0, (0, 0, 0)), (0.12, (0, -38, 0)), (0.20, (0, 34, 0)), (LIGHT_1, (0, 0, 0))],
        "upper_arm_r": [(0.0, (0, 0, 0)), (0.12, (-62, 0, -44)), (0.20, (34, 0, 30)), (LIGHT_1, (0, 0, 0))],
        "forearm_r": [(0.0, (0, 0, 0)), (0.12, (-24, 0, 0)), (0.20, (12, 0, 0)), (LIGHT_1, (0, 0, 0))],
        "head": [(0.0, (0, 0, 0)), (0.12, (0, 0, 14)), (0.20, (0, 0, -8)), (LIGHT_1, (0, 0, 0))],
    })

    # Corte Ascendente: windup 0.11 / active 0.08 (0.11–0.19) / até 0.43.
    common.animation(rig, "light_2", LIGHT_2, {
        "chest": [(0.0, (0, 0, 0)), (0.11, (0, 30, 6)), (0.19, (0, -28, -8)), (LIGHT_2, (0, 0, 0))],
        "upper_arm_r": [(0.0, (0, 0, 0)), (0.11, (44, 0, 20)), (0.19, (-96, 0, -20)), (LIGHT_2, (0, 0, 0))],
        "forearm_r": [(0.0, (0, 0, 0)), (0.11, (18, 0, 0)), (0.19, (-30, 0, 0)), (LIGHT_2, (0, 0, 0))],
    })

    # Giro Cortante: windup 0.16 / active 0.14 (0.16–0.30) / até 0.66.
    # O corpo gira 360° inteiro — o arco do golpe é a tela toda.
    common.animation(rig, "light_3", LIGHT_3, {
        "root": [(0.0, (0, 0, 0)), (0.16, (0, -50, 0)), (0.30, (0, 240, 0)), (0.44, (0, 360, 0)), (LIGHT_3, (0, 360, 0))],
        "upper_arm_r": [(0.0, (0, 0, 0)), (0.16, (-70, 0, -60)), (0.30, (-70, 0, -70)), (0.5, (0, 0, 0)), (LIGHT_3, (0, 0, 0))],
        "forearm_r": [(0.0, (0, 0, 0)), (0.16, (-20, 0, 0)), (0.30, (-20, 0, 0)), (LIGHT_3, (0, 0, 0))],
        "chest": [(0.0, (0, 0, 0)), (0.16, (0, 0, 10)), (0.30, (0, 0, 16)), (LIGHT_3, (0, 0, 0))],
    })

    # Golpe pesado: windup 0.32 (arma vai ao alto) / active 0.10 (0.32–0.42,
    # desce com tudo) / recuperação longa até 0.84.
    common.animation(rig, "heavy", HEAVY, {
        "chest": [(0.0, (0, 0, 0)), (0.32, (0, 0, -22)), (0.42, (0, 0, 30)), (0.6, (0, 0, 22)), (HEAVY, (0, 0, 0))],
        "upper_arm_r": [(0.0, (0, 0, 0)), (0.32, (-166, 0, -12)), (0.42, (28, 0, 0)), (0.6, (24, 0, 0)), (HEAVY, (0, 0, 0))],
        "upper_arm_l": [(0.0, (0, 0, 0)), (0.32, (-150, 0, 12)), (0.42, (20, 0, 0)), (0.6, (18, 0, 0)), (HEAVY, (0, 0, 0))],
        "forearm_r": [(0.0, (0, 0, 0)), (0.32, (-30, 0, 0)), (0.42, (8, 0, 0)), (HEAVY, (0, 0, 0))],
        "root": [(0.0, (0, 0, 0), (0.0, 0.0, 0.0)), (0.42, (0, 0, 0), (0.0, -0.12, 0.0)), (0.6, (0, 0, 0), (0.0, -0.08, 0.0)), (HEAVY, (0, 0, 0), (0.0, 0.0, 0.0))],
    })

    # Pose de carga do Martelo: arma ao alto, tremendo de leve. Loop.
    common.animation(rig, "charge", 1.0, {
        "upper_arm_r": [(0.0, (-160, 0, -10)), (0.5, (-166, 0, -8)), (1.0, (-160, 0, -10))],
        "upper_arm_l": [(0.0, (-146, 0, 10)), (0.5, (-152, 0, 8)), (1.0, (-146, 0, 10))],
        "chest": [(0.0, (0, 0, -16)), (0.5, (0, 0, -18)), (1.0, (0, 0, -16))],
        "root": [(0.0, (0, 0, 0), (0.0, -0.06, 0.0)), (1.0, (0, 0, 0), (0.0, -0.06, 0.0))],
    })

    common.animation(rig, "hurt", HURT, {
        "chest": [(0.0, (0, 0, 0)), (0.08, (8, 0, -34)), (HURT, (0, 0, 0))],
        "head": [(0.0, (0, 0, 0)), (0.08, (0, 0, -26)), (HURT, (0, 0, 0))],
        "upper_arm_r": [(0.0, (0, 0, 0)), (0.08, (-30, 0, -20)), (HURT, (0, 0, 0))],
        "upper_arm_l": [(0.0, (0, 0, 0)), (0.08, (-30, 0, 20)), (HURT, (0, 0, 0))],
    })

    # Abatido: deitado de costas, respirando. Loop parado.
    down_pose = (0, 0, -86)
    down_drop = (0.0, -0.78, 0.0)
    common.animation(rig, "downed", 2.0, {
        "root": [(0.0, down_pose, down_drop), (2.0, down_pose, down_drop)],
        "chest": [(0.0, (0, 0, 4)), (1.0, (0, 0, 8)), (2.0, (0, 0, 4))],
        "thigh_r": [(0.0, (26, 0, 0)), (2.0, (26, 0, 0))],
        "thigh_l": [(0.0, (18, 0, 0)), (2.0, (18, 0, 0))],
        "upper_arm_r": [(0.0, (-18, 0, -40)), (2.0, (-18, 0, -40))],
        "upper_arm_l": [(0.0, (-14, 0, 40)), (2.0, (-14, 0, 40))],
    })

    # Reviver: do chão ao joelho, do joelho ao pé.
    common.animation(rig, "revive", 1.5, {
        "root": [
            (0.0, down_pose, down_drop),
            (0.7, (0, 0, -30), (0.0, -0.45, 0.0)),
            (1.2, (0, 0, 0), (0.0, -0.1, 0.0)),
            (1.5, (0, 0, 0), (0.0, 0.0, 0.0)),
        ],
        "chest": [(0.0, (0, 0, 8)), (0.7, (0, 0, 24)), (1.5, (0, 0, 0))],
        "thigh_r": [(0.0, (26, 0, 0)), (0.7, (70, 0, 0)), (1.5, (0, 0, 0))],
        "shin_r": [(0.0, (0, 0, 0)), (0.7, (-80, 0, 0)), (1.5, (0, 0, 0))],
        "thigh_l": [(0.0, (18, 0, 0)), (0.7, (-20, 0, 0)), (1.5, (0, 0, 0))],
        "upper_arm_r": [(0.0, (-18, 0, -40)), (1.5, (0, 0, 0))],
        "upper_arm_l": [(0.0, (-14, 0, 40)), (1.5, (0, 0, 0))],
    })


build()
