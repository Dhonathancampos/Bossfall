# -*- coding: utf-8 -*-
"""Espada low-poly exagerada: lâmina larga, guarda grossa, silhueta clara.

Convenção das armas: punho na origem, lâmina apontando +Z (que vira +Y na
Godot). Sem rig — a HunterView prende o .glb num BoneAttachment3D da mão.

Escala: ~0,95 m do punho à ponta. A primeira versão tinha 1,20 m e lâmina de
22 cm de largura; nas capturas dos Golpes ela cruzava o corpo inteiro do
Caçador e TAPAVA a silhueta em metade dos arcos (pendência registrada no
ANIMACAO.md, item 5). Encurtar e afinar resolve sem perder o exagero: a
guarda continua desproporcional, que é o que diz "cartunesco".

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
    common.box("grip", (0.085, 0.085, 0.26), (0.0, 0.0, -0.09), grip)
    common.sphere("pommel", 0.075, (0.0, 0.0, -0.23), gold, subdivisions=1)
    common.box("guard", (0.14, 0.38, 0.09), (0.0, 0.0, 0.05), gold)
    common.box("blade", (0.05, 0.17, 0.72), (0.0, 0.0, 0.42), steel)
    common.box("ridge", (0.06, 0.055, 0.66), (0.0, 0.0, 0.41), steel_dark)
    common.cone("tip", 0.095, 0.20, (0.0, 0.0, 0.86), steel, vertices=4)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    common.export_glb(os.path.abspath(OUT))


build()
