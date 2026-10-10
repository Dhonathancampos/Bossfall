# -*- coding: utf-8 -*-
"""Machado low-poly exagerado: cabeça assimétrica enorme, cabo curto.

Caráter (ficha `.scratch/hunt-3d/weapons/axe.md`): a arma mais lenta e mais
forte, arcos largos, carga por golpe. A silhueta tem de dizer PESO e dizer
LÂMINA ao mesmo tempo — uma lua crescente gorda de um lado, um bico de
contrapeso do outro, para o arco ser legível tanto na ida quanto na volta.

Convenção das armas: punho na origem, arma apontando +Z (que vira +Y na
Godot). Sem rig — a HunterView prende o .glb num BoneAttachment3D da mão.

Escala: a arma inteira cabe em ~1,10 m a partir do punho. O Caçador tem 1,9 m
e a mão fica a ~0,85 m do chão; armas mais compridas que isto tapavam a
silhueta do corpo em metade dos arcos (pendência registrada no ANIMACAO.md).

Rodar:  blender --background --python tools/models/weapon_axe.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common

OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "weapon_axe.glb"
)


def build() -> None:
    common.reset_scene()

    steel = common.material("wpn_steel", "cfd8e2")
    steel_dark = common.material("wpn_steel_dark", "8a97a6")
    grip = common.material("wpn_grip", "5b4332")
    gold = common.material("wpn_gold", "e0a85a")

    # Cabo curto e grosso: machado é alavanca, não vara.
    common.cylinder("haft", 0.055, 0.86, (0.0, 0.0, 0.26), grip, vertices=6)
    common.box("haft_wrap", (0.09, 0.09, 0.18), (0.0, 0.0, -0.02), steel_dark)
    common.sphere("butt", 0.085, (0.0, 0.0, -0.20), gold, subdivisions=1)

    # Cabeça: cubo central + a lua crescente de um lado só. A assimetria é o
    # que distingue o machado do martelo na silhueta a dez metros.
    #
    # O crescente é feito de CAIXAS no mesmo plano da lâmina. A primeira
    # versão usava cones inclinados em eixos diferentes e, de três quartos,
    # a cabeça virava um catavento — formas chapadas no mesmo plano leem
    # como uma peça só.
    common.box("head", (0.20, 0.22, 0.32), (0.0, 0.0, 0.70), steel_dark)
    common.box("blade", (0.085, 0.42, 0.46), (0.0, 0.25, 0.68), steel)
    common.box("horn_up", (0.07, 0.30, 0.16), (0.0, 0.33, 0.92), steel,
               rotation=(0.55, 0.0, 0.0))
    common.box("horn_down", (0.07, 0.30, 0.16), (0.0, 0.33, 0.44), steel,
               rotation=(-0.55, 0.0, 0.0))
    # Gume dourado na ponta do crescente: a linha que o olho segue no arco.
    common.box("edge", (0.05, 0.09, 0.66), (0.0, 0.45, 0.68), gold)
    # Contrapeso do lado oposto: dá leitura à VOLTA do golpe.
    common.box("butt_head", (0.11, 0.20, 0.22), (0.0, -0.18, 0.70), steel_dark)
    common.cone("spike", 0.10, 0.22, (0.0, -0.34, 0.70), steel_dark,
                rotation=(1.5708, 0.0, 0.0), vertices=4)
    # Topo: ponta curta, para o vertical do Voo da Ruína ter com que morder.
    common.cone("tip", 0.10, 0.22, (0.0, 0.0, 0.96), steel, vertices=4)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    common.export_glb(os.path.abspath(OUT))


build()
