# -*- coding: utf-8 -*-
"""Repetidora low-poly: pistola gorda de tambor, com respiro de éter.

Caráter (ficha `.scratch/hunt-3d/weapons/repeaters.md`): a primeira arma de
alcance, pente de 12, recarga que EMPODERA quando feita colada ao Behemoth.
A silhueta tem de ler como "cano curto + tambor grande": o tambor é o pente,
e o respiro azul é o éter que a recarga de perto suga.

O .glb traz UMA pistola; a HunterView instancia duas (uma por mão), como já
faz com as Lâminas — repetidoras são um PAR.

Convenção das armas: punho na origem, cano apontando +Z (que vira +Y na
Godot). Sem rig — a HunterView prende o .glb num BoneAttachment3D da mão.

Escala: ~0,52 m do cabo à boca do cano. É de longe a menor das seis armas, e
é assim de propósito: com duas na tela, qualquer volume a mais vira uma
parede na frente do peito do Caçador.

Rodar:  blender --background --python tools/models/weapon_repeaters.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common

OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models",
    "weapon_repeaters.glb",
)


def build() -> None:
    common.reset_scene()

    steel = common.material("wpn_steel", "cfd8e2")
    steel_dark = common.material("wpn_steel_dark", "8a97a6")
    grip = common.material("wpn_grip", "5b4332")
    gold = common.material("wpn_gold", "e0a85a")
    aether = common.material("wpn_aether", "56c8ff", roughness=0.3,
                             emission="2f8fd0", emission_strength=1.2)

    # Cabo: curto e inclinado para trás, como punho de pistola.
    common.box("grip", (0.085, 0.10, 0.26), (0.0, -0.03, -0.11), grip,
               rotation=(0.26, 0.0, 0.0))
    common.box("grip_plate", (0.09, 0.05, 0.12), (0.0, -0.10, -0.16), gold,
               rotation=(0.26, 0.0, 0.0))

    # Corpo: o bloco que junta cabo, tambor e cano.
    common.box("frame", (0.11, 0.17, 0.17), (0.0, 0.0, 0.06), steel_dark)
    common.box("hammer", (0.06, 0.07, 0.09), (0.0, -0.10, 0.11), steel_dark,
               rotation=(0.5, 0.0, 0.0))

    # Tambor: o pente de 12, deitado de lado — é a peça que o olho pega.
    common.cylinder("drum", 0.12, 0.17, (0.0, 0.02, 0.17), steel,
                    rotation=(0.0, 1.5708, 0.0), vertices=6)
    common.box("drum_band", (0.19, 0.08, 0.08), (0.0, 0.02, 0.17), gold)

    # Cano curto e grosso, com respiro de éter em cima: a recarga colada ao
    # Behemoth suga éter por aqui, e é o que acende no pente empoderado.
    common.cylinder("barrel", 0.055, 0.30, (0.0, 0.0, 0.36), steel_dark, vertices=6)
    common.box("vent", (0.05, 0.07, 0.16), (0.0, 0.07, 0.36), aether)
    common.box("muzzle", (0.09, 0.09, 0.07), (0.0, 0.0, 0.50), steel)
    common.cone("sight", 0.035, 0.07, (0.0, 0.0, 0.43), gold, vertices=4)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    common.export_glb(os.path.abspath(OUT))


build()
