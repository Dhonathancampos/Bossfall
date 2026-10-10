# -*- coding: utf-8 -*-
"""Lança de Guerra low-poly: haste longa, ponta de três lâminas, canhão no meio.

Caráter (ficha `.scratch/hunt-3d/weapons/pike.md`): estocadas perfurantes
rápidas e lineares, a arma que FERE Partes e converte o medidor em munição de
canhão. A silhueta tem de ler como LINHA (o oposto dos arcos do machado) e
precisa mostrar o canhão: a Conversão Aetérica é o que a distingue de uma
lança qualquer, então a câmara fica à vista, logo acima da mão.

Convenção das armas: punho na origem, arma apontando +Z (que vira +Y na
Godot). Sem rig — a HunterView prende o .glb num BoneAttachment3D da mão.

Escala: ~1,45 m da ponta ao contrapeso, com a mão a um terço do comprimento
(a haste desce até -0,42). Fina de propósito: comprimento aqui é leitura de
alcance, mas qualquer VOLUME a mais nesta arma tapa o corpo na estocada, que
é frontal para a câmera.

Rodar:  blender --background --python tools/models/weapon_pike.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common

OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "weapon_pike.glb"
)


def build() -> None:
    common.reset_scene()

    steel = common.material("wpn_steel", "cfd8e2")
    steel_dark = common.material("wpn_steel_dark", "8a97a6")
    grip = common.material("wpn_grip", "5b4332")
    gold = common.material("wpn_gold", "e0a85a")
    aether = common.material("wpn_aether", "56c8ff", roughness=0.3,
                             emission="2f8fd0", emission_strength=1.2)

    # Haste: fina, com a mão a um terço — sobra atrás para a estocada ter
    # recuo visível em vez de nascer do nada.
    common.cylinder("shaft", 0.042, 1.42, (0.0, 0.0, 0.30), grip, vertices=6)
    common.box("grip_wrap", (0.075, 0.075, 0.26), (0.0, 0.0, 0.0), steel_dark)
    common.cone("butt", 0.07, 0.18, (0.0, 0.0, -0.46), steel_dark,
                rotation=(3.14159, 0.0, 0.0), vertices=4)

    # Câmara aetérica logo acima da mão: é o medidor virando munição, e é o
    # que faz esta silhueta não ser "uma lança qualquer".
    common.cylinder("chamber", 0.095, 0.26, (0.0, 0.0, 0.26), steel_dark, vertices=6)
    common.box("chamber_window", (0.07, 0.21, 0.16), (0.0, 0.0, 0.26), aether)
    common.box("chamber_fin", (0.05, 0.26, 0.09), (0.0, 0.0, 0.40), gold)

    # Ponta: três lâminas estreitas em volta de um núcleo — PERFURAR, não
    # cortar. O colar dourado marca onde a ponta começa.
    common.box("collar", (0.11, 0.11, 0.10), (0.0, 0.0, 0.84), gold)
    common.box("head_core", (0.07, 0.07, 0.40), (0.0, 0.0, 1.03), steel_dark)
    for i, angle in enumerate((0.0, 2.0944, 4.1888)):
        common.box("fin_%d" % i, (0.035, 0.17, 0.38), (0.0, 0.0, 1.02), steel,
                   rotation=(0.0, 0.0, angle))
    common.cone("tip", 0.085, 0.30, (0.0, 0.0, 1.32), steel, vertices=4)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    common.export_glb(os.path.abspath(OUT))


build()
