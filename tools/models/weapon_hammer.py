# -*- coding: utf-8 -*-
"""Martelo low-poly exagerado: cabeça desproporcional, cabo longo.

Punho na origem, cabeça no topo (+Z). Sem rig.

Escala: ~0,95 m do punho ao topo da cabeça, com a cabeça em 46 cm de largura.
A primeira versão media 1,25 m com cabeça de 62 cm: nas capturas da Rajada e
do Estouro a cabeça cobria o tronco inteiro do Caçador e o arco sumia
(pendência do ANIMACAO.md, item 5). A cabeça continua desproporcional em
relação ao cabo — é a assinatura da arma — só que agora cabe no quadro.

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

    common.cylinder("handle", 0.048, 0.92, (0.0, 0.0, 0.26), grip, vertices=6)
    common.sphere("butt", 0.075, (0.0, 0.0, -0.18), gold, subdivisions=1)
    # A cabeça deitada no topo: um bloco enorme com faces de batida douradas,
    # tudo sobreposto para não haver vão.
    common.box("head", (0.28, 0.46, 0.30), (0.0, 0.0, 0.70), iron)
    common.box("face_r", (0.24, 0.08, 0.25), (0.0, -0.23, 0.70), gold)
    common.box("face_l", (0.24, 0.08, 0.25), (0.0, 0.23, 0.70), gold)
    common.box("crown", (0.15, 0.40, 0.10), (0.0, 0.0, 0.82), iron_dark)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    common.export_glb(os.path.abspath(OUT))


build()
