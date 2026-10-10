# -*- coding: utf-8 -*-
"""Lâmina corrente low-poly: foice curva curta com elo de corrente no cabo.

O .glb traz UMA lâmina; a HunterView instancia duas (uma por mão) quando a
arma do Caçador for o par de Lâminas. Punho na origem, gume para +Z.

Escala: ~0,66 m. Já era a menor das três armas antigas; encolheu um pouco
mais junto com a revisão de escala de espada e martelo (ANIMACAO.md, item 5),
porque com DUAS na tela o volume conta dobrado — e a leitura delas é
velocidade, não tamanho.

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

    common.box("grip", (0.075, 0.075, 0.26), (0.0, 0.0, 0.02), grip)
    common.sphere("ring", 0.065, (0.0, 0.0, -0.13), gold, subdivisions=1)
    # Elos de corrente pendurados no cabo.
    common.box("link_a", (0.045, 0.045, 0.09), (0.0, 0.0, -0.20), steel_dark)
    common.box("link_b", (0.045, 0.045, 0.09), (0.03, 0.0, -0.27), steel_dark)
    # A foice: corpo reto que vira num gancho curvo, tudo sobreposto.
    common.box("blade", (0.055, 0.14, 0.46), (0.0, 0.0, 0.34), steel)
    common.box("hook", (0.055, 0.30, 0.14), (0.0, 0.10, 0.52), steel, rotation=(-0.5, 0.0, 0.0))
    common.cone("hook_tip", 0.08, 0.19, (0.0, 0.25, 0.44), steel,
                rotation=(2.2, 0.0, 0.0), vertices=4)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    common.export_glb(os.path.abspath(OUT))


build()
