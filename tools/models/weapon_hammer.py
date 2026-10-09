# -*- coding: utf-8 -*-
"""Martelo low-poly exagerado: cabeça desproporcional, cabo longo.

Punho na origem, cabeça no topo (+Z). Sem rig.

Rodar:  blender --background --python tools/models/weapon_hammer.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common

OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "weapon_hammer.glb"
)


def build() -> None:
    common.reset_scene()

    iron = common.material("wpn_iron", "7d8691")
    iron_dark = common.material("wpn_iron_dark", "4a525c")
    grip = common.material("wpn_grip", "5b4332")
    gold = common.material("wpn_gold", "e0a85a")

    common.cylinder("handle", 0.05, 1.1, (0.0, 0.0, 0.33), grip, vertices=6)
    common.sphere("butt", 0.08, (0.0, 0.0, -0.2), gold, subdivisions=1)
    # A cabeça deitada no topo: um bloco enorme com faces de batida douradas,
    # tudo sobreposto para não haver vão.
    common.box("head", (0.36, 0.62, 0.36), (0.0, 0.0, 0.86), iron)
    common.box("face_r", (0.3, 0.1, 0.3), (0.0, -0.3, 0.86), gold)
    common.box("face_l", (0.3, 0.1, 0.3), (0.0, 0.3, 0.86), gold)
    common.box("crown", (0.18, 0.52, 0.12), (0.0, 0.0, 1.0), iron_dark)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    common.export_glb(os.path.abspath(OUT))


build()
