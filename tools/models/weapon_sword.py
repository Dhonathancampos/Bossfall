# -*- coding: utf-8 -*-
"""Espada low-poly exagerada: lâmina larga, guarda grossa, silhueta clara.

Convenção das armas: punho na origem, lâmina apontando +Z (que vira +Y na
Godot). Sem rig — a HunterView prende o .glb num BoneAttachment3D da mão.

Rodar:  blender --background --python tools/models/weapon_sword.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common

OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "weapon_sword.glb"
)


def build() -> None:
    common.reset_scene()

    steel = common.material("wpn_steel", "cfd8e2")
    steel_dark = common.material("wpn_steel_dark", "8a97a6")
    grip = common.material("wpn_grip", "5b4332")
    gold = common.material("wpn_gold", "e0a85a")

    # Peças sobrepostas: lâmina entra na guarda, ponta entra na lâmina.
    common.box("grip", (0.09, 0.09, 0.3), (0.0, 0.0, -0.1), grip)
    common.sphere("pommel", 0.08, (0.0, 0.0, -0.26), gold, subdivisions=1)
    common.box("guard", (0.16, 0.44, 0.1), (0.0, 0.0, 0.06), gold)
    common.box("blade", (0.06, 0.22, 0.95), (0.0, 0.0, 0.5), steel)
    common.box("ridge", (0.07, 0.07, 0.86), (0.0, 0.0, 0.48), steel_dark)
    common.cone("tip", 0.12, 0.24, (0.0, 0.0, 1.05), steel, vertices=4)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    common.export_glb(os.path.abspath(OUT))


build()
