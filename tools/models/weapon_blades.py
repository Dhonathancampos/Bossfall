# -*- coding: utf-8 -*-
"""Lâmina corrente low-poly: foice curva curta com elo de corrente no cabo.

O .glb traz UMA lâmina; a HunterView instancia duas (uma por mão) quando a
arma do Caçador for o par de Lâminas. Punho na origem, gume para +Z.

Rodar:  blender --background --python tools/models/weapon_blades.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common

OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "weapon_blades.glb"
)


def build() -> None:
    common.reset_scene()

    steel = common.material("wpn_steel", "cfd8e2")
    steel_dark = common.material("wpn_steel_dark", "8a97a6")
    grip = common.material("wpn_grip", "5b4332")
    gold = common.material("wpn_gold", "e0a85a")

    common.box("grip", (0.08, 0.08, 0.3), (0.0, 0.0, 0.02), grip)
    common.sphere("ring", 0.07, (0.0, 0.0, -0.14), gold, subdivisions=1)
    # Elos de corrente pendurados no cabo.
    common.box("link_a", (0.05, 0.05, 0.1), (0.0, 0.0, -0.22), steel_dark)
    common.box("link_b", (0.05, 0.05, 0.1), (0.03, 0.0, -0.3), steel_dark)
    # A foice: corpo reto que vira num gancho curvo, tudo sobreposto.
    common.box("blade", (0.06, 0.16, 0.56), (0.0, 0.0, 0.4), steel)
    common.box("hook", (0.06, 0.36, 0.16), (0.0, 0.12, 0.62), steel, rotation=(-0.5, 0.0, 0.0))
    common.cone("hook_tip", 0.09, 0.22, (0.0, 0.3, 0.52), steel, rotation=(2.2, 0.0, 0.0), vertices=4)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    common.export_glb(os.path.abspath(OUT))


build()
