# -*- coding: utf-8 -*-
"""Modelo de prova do pipeline: um totem de pedra com olho que balança.

Não aparece no jogo. Existe para o teste automatizado provar o caminho
inteiro — script → Blender headless → .glb → importação na Godot → animações
com os nomes esperados. Se este arquivo gera e importa, qualquer modelo gera.

Rodar:  blender --background --python tools/models/totem.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common

OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "totem.glb"
)


def build() -> None:
    common.reset_scene()

    stone = common.material("totem_stone", "6d6a63")
    moss = common.material("totem_moss", "5a6b47")
    eye = common.material("totem_eye", "ffd98a")

    # Esqueleto: raiz no chão, topo que balança.
    rig = common.armature("Totem", {
        "root": ((0.0, 0.0, 0.0), (0.0, 0.0, 0.6), None),
        "top": ((0.0, 0.0, 0.6), (0.0, 0.0, 1.2), "root"),
    })

    # Base e tronco presos à raiz.
    base = common.box("base", (0.7, 0.7, 0.3), (0.0, 0.0, 0.15), stone)
    trunk = common.box("trunk", (0.5, 0.5, 0.5), (0.0, 0.0, 0.5), moss)
    common.attach(base, rig, "root")
    common.attach(trunk, rig, "root")

    # Cabeça e olho presos ao osso do topo.
    head = common.box("head", (0.6, 0.6, 0.45), (0.0, 0.0, 0.95), stone)
    pupil = common.sphere("eye", 0.09, (0.0, -0.31, 0.98), eye, subdivisions=1)
    common.attach(head, rig, "top")
    common.attach(pupil, rig, "top")

    # idle: a cabeça balança. Prova que a animação chega nomeada na Godot.
    common.animation(rig, "idle", 2.0, {
        "top": [
            (0.0, (0.0, 0.0, 0.0)),
            (0.5, (0.0, 8.0, 0.0)),
            (1.0, (0.0, 0.0, 0.0)),
            (1.5, (0.0, -8.0, 0.0)),
            (2.0, (0.0, 0.0, 0.0)),
        ],
    })

    # wobble: segunda animação, prova que várias trilhas viajam juntas.
    common.animation(rig, "wobble", 1.0, {
        "root": [
            (0.0, (0.0, 0.0, 0.0)),
            (0.25, (6.0, 0.0, 0.0)),
            (0.75, (-6.0, 0.0, 0.0)),
            (1.0, (0.0, 0.0, 0.0)),
        ],
    })

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    common.export_glb(os.path.abspath(OUT))


build()
