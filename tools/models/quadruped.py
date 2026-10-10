# -*- coding: utf-8 -*-
"""O quadrúpede mordedor: criatura original da casa, low-poly cartunesca.

Silhueta: corpanzil arredondado de sapo-javali, mandíbula inferior enorme com
dentes em bloco (prognata), placas de pedra nas costas, cauda-clava de osso e
quatro patas curtas e grossas. Paleta: musgo, areia, ardósia, osso e âmbar.

## Rig

    root ─ spine ─ neck ─ head ─ jaw
         ├ tail_a ─ tail_b
         └ leg_fr ─ paw_fr   (e fl, br, bl)

A cauda continua sendo UMA malha chamada "tail" — a Godot a esconde pelo nome
quando a Parte é decepada — mas agora é repartida entre `tail_a` e `tail_b`
por `common.attach_gradient`, então ela chicoteia em vez de girar em bloco.
Os ossos da cauda NÃO se chamam "tail" justamente para não disputarem o nome
com essa malha na importação do glTF.

Todas as poses usam `space="world"`: rx rola, ry inclina a ponta do osso para
a frente, rz gira para a esquerda. Os ângulos se SOMAM ao descer a
hierarquia; o corpo é escrito pensando nisso.

## Animações

As durações dos ataques vêm de src/sim/behemoths.gd (windup+active+recovery):

    bite   = 0.62 + 0.16 + 0.62 = 1.40 s
    charge = 0.82 + 0.42 + 0.85 = 2.09 s
    tail   = 0.52 + 0.20 + 0.70 = 1.42 s
    stomp  = 0.70 + 0.18 + 0.75 = 1.63 s

E de sim_config.gd: stagger_fall = STAGGER_DOWN_DURATION = 4.5 s.

Rodar:  blender --background --python tools/models/quadruped.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common

OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "quadruped.glb"
)

BITE = (0.62, 0.16, 0.62)
CHARGE = (0.82, 0.42, 0.85)
TAIL = (0.52, 0.20, 0.70)
STOMP = (0.70, 0.18, 0.75)
ROAR = 2.0
FALL = 4.5
DEATH = 2.0

LEGS = ["fr", "fl", "br", "bl"]
LEG_AT = {"fr": (0.75, -0.88), "fl": (0.75, 0.88), "br": (-0.75, -0.88), "bl": (-0.75, 0.88)}


def build() -> None:
    common.reset_scene()

    # Paleta viva e contrastada: couro saturado, barriga clara, placas quase
    # pretas, osso claro, goela vermelha, olhos âmbar.
    moss = common.material("quad_moss", "4e9e3f")
    belly = common.material("quad_belly", "f0dca6")
    slate = common.material("quad_slate", "2e343b")
    bone = common.material("quad_bone", "f5ecd8")
    maw = common.material("quad_maw", "b33c3c")
    eye = common.material("quad_eye", "ffc24d", roughness=0.3)

    # Olha para +X. Uma muralha de músculo: ombro a ~2,3 m (o dobro do
    # Caçador), mandíbula inferior maior que o focinho.
    bones = {
        "root": ((0.0, 0.0, 1.35), (0.0, 0.0, 1.95), None),
    }
    bones.update(common.chain(
        ["spine", "neck", "head"],
        [(-0.10, 0.0, 1.45), (0.90, 0.0, 1.48), (1.35, 0.0, 1.48), (2.40, 0.0, 1.45)],
        "root",
    ))
    bones["jaw"] = ((1.35, 0.0, 0.95), (2.60, 0.0, 0.85), "head")
    bones.update(common.chain(
        ["tail_a", "tail_b"],
        [(-1.00, 0.0, 1.40), (-2.10, 0.0, 1.46), (-3.40, 0.0, 1.56)],
        "root",
    ))
    for leg in LEGS:
        px, py = LEG_AT[leg]
        bones.update(common.chain(
            ["leg_%s" % leg, "paw_%s" % leg],
            [(px, py, 1.05), (px + 0.03, py, 0.34), (px + 0.20, py, 0.06)],
            "root",
        ))
    rig = common.armature("Quadruped", bones)

    # --- Corpo: massudo e largo ---
    common.attach(
        common.sphere("m_body", 1.3, (0.0, 0.0, 1.4), moss, subdivisions=2, squash=(1.2, 0.95, 0.72)),
        rig, "root",
    )
    common.attach(
        common.sphere("m_hump", 0.85, (-0.3, 0.0, 1.95), moss, subdivisions=2, squash=(1.1, 0.85, 0.6)),
        rig, "root",
    )
    common.attach(
        common.sphere("m_belly", 1.05, (0.15, 0.0, 1.0), belly, subdivisions=2, squash=(1.15, 0.85, 0.55)),
        rig, "root",
    )
    # Placas dorsais quase pretas, da nuca à garupa. A da frente vai na
    # coluna, para as costas arquearem no rugido e na investida.
    for i, (px, scale, parent) in enumerate([(0.55, 0.62, "spine"), (0.0, 0.72, "root"), (-0.6, 0.58, "root")]):
        common.attach(
            common.box(
                "m_plate_%d" % i,
                (scale, scale * 0.85, 0.34),
                (px, 0.0, 2.2 - abs(px) * 0.18),
                slate,
                rotation=(0.0, 0.35, 0.0),
            ),
            rig, parent,
        )
    # Cicatriz clara no flanco direito: detalhe de leitura.
    common.attach(
        common.box("m_scar", (0.5, 0.06, 0.28), (0.2, -1.12, 1.55), bone, rotation=(0.0, 0.5, 0.3)),
        rig, "root",
    )
    # Pescoço: o anel que esconde a junta quando a cabeça ergue.
    common.attach(
        common.sphere("m_neck", 0.62, (1.05, 0.0, 1.50), moss, subdivisions=1, squash=(1.1, 1.0, 0.9)),
        rig, "neck",
    )

    # --- Cabeça pesada ---
    common.attach(common.box("m_head", (1.3, 1.5, 0.95), (1.95, 0.0, 1.58), moss), rig, "head")
    common.attach(common.box("m_muzzle", (0.55, 1.25, 0.45), (2.45, 0.0, 1.42), belly), rig, "head")
    common.attach(common.box("m_brow", (0.7, 1.6, 0.25), (2.1, 0.0, 2.08), slate), rig, "head")
    common.attach(common.sphere("m_eye_r", 0.14, (2.5, -0.52, 1.82), eye, subdivisions=1), rig, "head")
    common.attach(common.sphere("m_eye_l", 0.14, (2.5, 0.52, 1.82), eye, subdivisions=1), rig, "head")
    common.attach(common.box("m_teeth_top", (0.16, 1.15, 0.2), (2.62, 0.0, 1.16), bone), rig, "head")

    # --- A mandíbula: a alma do monstro. Mais larga que o focinho, lábio à
    # frente, dentões subindo à vista até de costas. ---
    common.attach(common.box("m_jaw", (1.65, 1.95, 0.55), (2.35, 0.0, 0.72), moss), rig, "jaw")
    common.attach(common.box("m_chin", (0.55, 1.25, 0.34), (3.05, 0.0, 0.66), slate), rig, "jaw")
    common.attach(common.box("m_maw", (1.4, 1.6, 0.14), (2.35, 0.0, 1.02), maw), rig, "jaw")
    # Quatro dentões centrais + duas presas de canto mais altas.
    for i, ty in enumerate([-0.45, -0.15, 0.15, 0.45]):
        common.attach(
            common.box("m_tooth_%d" % i, (0.22, 0.24, 0.72), (3.0, ty, 1.26), bone),
            rig, "jaw",
        )
    for i, ty in enumerate([-0.88, 0.88]):
        common.attach(
            common.box("m_tusk_%d" % i, (0.26, 0.28, 1.0), (2.75, ty, 1.4), bone,
                       rotation=(0.22 if ty > 0 else -0.22, -0.12, 0.0)),
            rig, "jaw",
        )

    # --- Cauda-clava: UMA malha "tail" repartida entre dois ossos, com ponta
    # óssea volumosa (o alvo visual de "corte aqui") ---
    tail_parts = [
        common.box("tail_seg_a", (0.95, 0.85, 0.62), (-1.45, 0.0, 1.42), moss),
        common.box("tail_seg_b", (0.85, 0.6, 0.48), (-2.25, 0.0, 1.50), moss),
        common.sphere("tail_club", 0.52, (-3.05, 0.0, 1.58), bone, subdivisions=1, squash=(1.25, 0.9, 1.05)),
        common.box("tail_spike_a", (0.4, 0.16, 0.7), (-3.15, 0.0, 1.98), bone, rotation=(0.0, -0.5, 0.0)),
        common.box("tail_spike_b", (0.5, 0.14, 0.3), (-3.4, 0.0, 1.48), bone, rotation=(0.0, 0.4, 0.0)),
    ]
    tail = common.join(tail_parts, "tail")
    common.attach_gradient(
        tail, rig,
        [("tail_a", -2.10, -0.90), ("tail_b", -4.00, -2.10)],
        axis=0, blend=0.45,
    )

    # --- Patas grossas com garras claras ---
    for leg in LEGS:
        px, py = LEG_AT[leg]
        common.attach(
            common.cylinder("m_leg_%s" % leg, 0.34, 0.80, (px + 0.02, py, 0.72), moss),
            rig, "leg_%s" % leg,
        )
        common.attach(
            common.sphere("m_ankle_%s" % leg, 0.3, (px + 0.03, py, 0.34), moss, subdivisions=1),
            rig, "paw_%s" % leg,
        )
        common.attach(
            common.box("m_foot_%s" % leg, (0.56, 0.6, 0.26), (px + 0.14, py, 0.13), slate),
            rig, "paw_%s" % leg,
        )
        common.attach(
            common.box("m_claws_%s" % leg, (0.26, 0.5, 0.16), (px + 0.48, py, 0.08), bone),
            rig, "paw_%s" % leg,
        )

    _animate(rig)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    common.export_glb(os.path.abspath(OUT))


# --- Ferramentas de pose -------------------------------------------------


def _attack(rig, name, phases, wind, hit, rest=None, amount=0.2, at=0.35,
            wind_ease="accel", hit_ease="hit") -> None:
    """Monta um ataque do Behemoth com as três fases da Sim.

    Mesma ideia do Caçador: o bicho CARREGA o golpe durante o Preparo (curva
    de entrada lenta, que é o que o jogador lê para esquivar), descarrega no
    Ativo (curva de saída seca) e paga a Recuperação passando do ponto antes
    de assentar. A cauda é gerada como arrasto defasado do corpo — massa não
    para junto com o osso que a puxa.
    """
    windup, active, recovery = phases
    total = windup + active + recovery
    rest = rest if rest is not None else {}

    poses = {}
    for key in set(rest) | set(wind) | set(hit):
        base, base_loc = _split(rest.get(key, (0, 0, 0)))
        w_rot, w_loc = _split(wind.get(key, rest.get(key, (0, 0, 0))))
        h_rot, h_loc = _split(hit.get(key, wind.get(key, rest.get(key, (0, 0, 0)))))
        keys = [
            (0.0, base, base_loc, wind_ease),
            (windup, w_rot, w_loc, hit_ease),
            (windup + active, h_rot, h_loc, "ease"),
        ]
        tail = common.settle(windup + active, h_rot, total, rest=base, amount=amount, at=at)
        if h_loc is not None or base_loc is not None:
            end_loc = base_loc if base_loc is not None else (0.0, 0.0, 0.0)
            peak_loc = h_loc if h_loc is not None else end_loc
            over_loc = tuple(end_loc[i] + (peak_loc[i] - end_loc[i]) * 0.3 for i in range(3))
            tail = [(tail[0][0], tail[0][1], over_loc, tail[0][3]),
                    (tail[1][0], tail[1][1], end_loc, tail[1][3])]
        poses[key] = keys + tail

    if "tail_a" not in poses:
        poses["tail_a"] = common.follow(poses["root"], delay=0.09, damping=-0.6, limit=total)
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.07, damping=0.7, limit=total)
    common.animation(rig, name, total, poses, space="world")


def _split(value):
    if len(value) == 2 and isinstance(value[0], (tuple, list)):
        return tuple(value[0]), tuple(value[1])
    return tuple(value), None


def _animate(rig) -> None:
    _idle(rig)
    _walk(rig)
    _bite(rig)
    _charge(rig)
    _tail(rig)
    _stomp(rig)
    _roar(rig)
    _stagger(rig)
    _death(rig)


def _idle(rig) -> None:
    """Respiração pesada: o corpo infla, a cabeça balança, a cauda varre."""
    idle = 2.0
    poses = {
        "root": common.cycle(idle, amplitude=(0, 1.0, 0), loc_amplitude=(0.0, 0.0, 0.035), samples=8),
        "spine": common.cycle(idle, amplitude=(0, -1.6, 0), samples=8),
        "neck": common.cycle(idle, amplitude=(0, -2.0, 1.5), samples=8),
        "head": common.cycle(idle, amplitude=(0, -2.5, 2.5), samples=8),
        "jaw": common.cycle(idle, amplitude=(0, 4.0, 0), bias=(0, 3, 0), samples=8),
    }
    poses["tail_a"] = common.cycle(idle, amplitude=(0, -2.0, 9.0), samples=8)
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.18, damping=0.85, limit=idle)
    for leg in LEGS:
        poses["leg_%s" % leg] = [(0.0, (0, 0, 0), None, "ease"), (idle, (0, 0, 0), None, "ease")]
    common.animation(rig, "idle", idle, poses, space="world")


def _walk(rig) -> None:
    """Andadura diagonal: dianteira direita com traseira esquerda.

    É o passo de quadrúpede pesado — duas patas no chão sempre, corpo
    balançando de lado a cada apoio. A raiz sobe e desce duas vezes por
    ciclo (uma por diagonal), e a cauda arrasta defasada do corpo.
    """
    walk = 0.9
    phases = {"fr": 0.25, "bl": 0.25, "fl": 0.75, "br": 0.75}
    poses = {
        "root": common.cycle(walk, amplitude=(4.0, 0, 0), loc_amplitude=(0.0, 0.05, 0.05),
                             harmonic=2, phase=0.25, samples=8),
        "spine": common.cycle(walk, amplitude=(0, 0, 4.0), samples=8),
        "neck": common.cycle(walk, amplitude=(0, 3.0, -2.0), samples=8),
        "head": common.cycle(walk, amplitude=(0, 4.0, -3.0), bias=(0, 2, 0), samples=8),
        "jaw": [(0.0, (0, 4, 0), None, "ease"), (walk, (0, 4, 0), None, "ease")],
    }
    for leg, phase in phases.items():
        poses["leg_%s" % leg] = common.cycle(walk, amplitude=(0, -26.0, 0), phase=phase, samples=8)
        # A pata dobra só no balanço: meia onda, atrasada em relação à perna.
        poses["paw_%s" % leg] = common.cycle(walk, amplitude=(0, 34.0, 0), bias=(0, -6, 0),
                                             phase=phase - 0.33, rectify=True, samples=8)
    poses["tail_a"] = common.cycle(walk, amplitude=(0, -3.0, 11.0), samples=8)
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.12, damping=0.8, limit=walk)
    common.animation(rig, "walk", walk, poses, space="world")


def _bite(rig) -> None:
    """Mordida: 0,62 s de aviso com a cabeça armada e a goela à mostra.

    A referência pública descreve a mordida do Gnasher como "muito
    telegrafada: ele puxa a cabeça para trás antes do bote". É isso que o
    Preparo longo compra — e é por isso que a cabeça SOBE E RECUA aqui em
    vez de só abrir a boca. Fontes no ANIMACAO.md.
    """
    _attack(rig, "bite", BITE,
            wind={
                "root": ((0, -7, 0), (-0.12, 0.0, 0.03)),
                "spine": (0, -8, 0), "neck": (0, -16, 0), "head": (0, -14, 0),
                "jaw": (0, 50, 0),
                "leg_fr": (0, 14, 0), "leg_fl": (0, 14, 0),
                "leg_br": (0, -10, 0), "leg_bl": (0, -10, 0),
                "paw_fr": (0, -8, 0), "paw_fl": (0, -8, 0),
            },
            hit={
                "root": ((0, 10, 0), (0.20, 0.0, -0.08)),
                "spine": (0, 12, 0), "neck": (0, 18, 0), "head": (0, 16, 0),
                "jaw": (0, -4, 0),
                "leg_fr": (0, -16, 0), "leg_fl": (0, -16, 0),
                "leg_br": (0, 12, 0), "leg_bl": (0, 12, 0),
                "paw_fr": (0, 10, 0), "paw_fl": (0, 10, 0),
            }, amount=0.24)


def _charge(rig) -> None:
    """Investida: agacha, dispara e derrapa.

    O Preparo recua o corpo (0,82 s de leitura), o Ativo joga a raiz 0,55 m
    à frente em flecha com a boca aberta e a Recuperação é a derrapada com
    sacudida de cabeça. O deslocamento é do CLIPE: a posição no mundo quem
    manda é a Sim; isto é só o corpo saindo na frente do centro.
    """
    windup, active, recovery = CHARGE
    total = windup + active + recovery
    poses = {
        "root": [
            (0.0, (0, 0, 0), (0.0, 0.0, 0.0), "accel"),
            (windup * 0.55, (0, -14, 0), (-0.22, 0.0, -0.10), "wind"),
            (windup, (0, -4, 0), (-0.30, 0.0, -0.14), "hit"),
            (windup + active * 0.3, (0, 12, 0), (0.34, 0.0, 0.05), "linear"),
            (windup + active, (0, 9, 0), (0.55, 0.0, 0.0), "settle"),
            (windup + active + 0.30, (0, -6, 0), (0.22, 0.0, -0.04), "ease"),
            (total - 0.25, (0, 3, 0), (0.05, 0.0, 0.0), "ease"),
            (total, (0, 0, 0), (0.0, 0.0, 0.0), "settle"),
        ],
        "spine": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, 10, 0), None, "hit"),
                  (windup + active, (0, -6, 0), None, "ease"), (total, (0, 0, 0), None, "settle")],
        "neck": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, 16, 0), None, "hit"),
                 (windup + active, (0, -10, 0), None, "ease"),
                 (windup + active + 0.35, (0, 12, -14), None, "ease"),
                 (total - 0.2, (0, -6, 12), None, "ease"), (total, (0, 0, 0), None, "settle")],
        "head": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, 14, 0), None, "hit"),
                 (windup + active, (0, -8, 0), None, "ease"),
                 (windup + active + 0.35, (0, 10, -18), None, "ease"),
                 (total - 0.2, (0, -5, 16), None, "ease"), (total, (0, 0, 0), None, "settle")],
        "jaw": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, 34, 0), None, "hit"),
                (windup + active, (0, 26, 0), None, "ease"), (total, (0, 0, 0), None, "settle")],
    }
    for leg, sign in (("fr", 1.0), ("fl", 1.0), ("br", -1.0), ("bl", -1.0)):
        poses["leg_%s" % leg] = [
            (0.0, (0, 0, 0), None, "accel"),
            (windup, (0, 30 * sign, 0), None, "hit"),
            (windup + active * 0.3, (0, -34 * sign, 0), None, "linear"),
            (windup + active, (0, -26 * sign, 0), None, "ease"),
            (total, (0, 0, 0), None, "settle"),
        ]
        poses["paw_%s" % leg] = [
            (0.0, (0, 0, 0), None, "accel"),
            (windup, (0, -16 * sign, 0), None, "hit"),
            (windup + active, (0, 20 * sign, 0), None, "ease"),
            (total, (0, 0, 0), None, "settle"),
        ]
    poses["tail_a"] = common.follow(poses["root"], delay=0.10, damping=-0.7, limit=total)
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.08, damping=0.7, limit=total)
    common.animation(rig, "charge", total, poses, space="world")


def _tail(rig) -> None:
    """Rabada: o corpo torce ao contrário, a cauda vem atrás e ultrapassa.

    A cauda NÃO acompanha o corpo aqui — ela é o golpe. Os dois ossos da
    cauda vêm defasados entre si, o que dá o estalo de chicote na ponta.
    """
    windup, active, recovery = TAIL
    total = windup + active + recovery
    poses = {
        "root": [
            (0.0, (0, 0, 0), (0.0, 0.0, 0.0), "accel"),
            (windup, (0, 0, -34), (0.0, -0.10, 0.02), "hit"),
            (windup + active, (0, 0, 40), (0.0, 0.12, -0.02), "ease"),
            (windup + active + 0.30, (0, 0, 10), (0.0, 0.04, 0.0), "ease"),
            (total, (0, 0, 0), (0.0, 0.0, 0.0), "settle"),
        ],
        "spine": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, 0, -12), None, "hit"),
                  (windup + active, (0, 0, 16), None, "ease"), (total, (0, 0, 0), None, "settle")],
        "neck": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, 0, 14), None, "hit"),
                 (windup + active, (0, 0, -18), None, "ease"), (total, (0, 0, 0), None, "settle")],
        "head": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, -6, 16), None, "hit"),
                 (windup + active, (0, 4, -20), None, "ease"), (total, (0, 0, 0), None, "settle")],
        "jaw": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, 16, 0), None, "ease"),
                (total, (0, 0, 0), None, "settle")],
        # A cauda enrola para um lado no Preparo e desenrola no Ativo.
        "tail_a": [
            (0.0, (0, 0, 0), None, "accel"),
            (windup, (0, -8, 58), None, "hit"),
            (windup + active, (0, 6, -72), None, "ease"),
            (windup + active + 0.34, (0, 0, -22), None, "ease"),
            (total, (0, 0, 0), None, "settle"),
        ],
    }
    for leg, sign in (("fr", -1.0), ("fl", 1.0), ("br", -1.0), ("bl", 1.0)):
        poses["leg_%s" % leg] = [
            (0.0, (0, 0, 0), None, "accel"),
            (windup, (0, 10 * sign, 0), None, "hit"),
            (windup + active, (0, -12 * sign, 0), None, "ease"),
            (total, (0, 0, 0), None, "settle"),
        ]
    # A ponta vem atrás da base: é esse atraso que vira estalo de chicote.
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.10, damping=0.95, limit=total)
    common.animation(rig, "tail", total, poses, space="world")


def _stomp(rig) -> None:
    """Pisão: empina nas patas de trás e desaba. 0,70 s de aviso no alto.

    O impacto usa a curva `hit` (quase todo o movimento no primeiro
    instante do Ativo) e a Recuperação quica: é o peso chegando ao chão.
    """
    windup, active, recovery = STOMP
    total = windup + active + recovery
    poses = {
        "root": [
            (0.0, (0, 0, 0), (0.0, 0.0, 0.0), "accel"),
            (windup * 0.35, (0, 6, 0), (-0.06, 0.0, -0.08), "wind"),
            (windup, (0, -30, 0), (-0.18, 0.0, 0.34), "hit"),
            (windup + active, (0, 8, 0), (0.10, 0.0, -0.20), "bounce"),
            (windup + active + 0.22, (0, -3, 0), (0.0, 0.0, 0.05), "ease"),
            (total - 0.25, (0, 2, 0), (0.0, 0.0, -0.02), "ease"),
            (total, (0, 0, 0), (0.0, 0.0, 0.0), "settle"),
        ],
        "spine": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, -16, 0), None, "hit"),
                  (windup + active, (0, 12, 0), None, "ease"), (total, (0, 0, 0), None, "settle")],
        "neck": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, -20, 0), None, "hit"),
                 (windup + active, (0, 16, 0), None, "ease"), (total, (0, 0, 0), None, "settle")],
        "head": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, -18, 0), None, "hit"),
                 (windup + active, (0, 14, 0), None, "ease"), (total, (0, 0, 0), None, "settle")],
        "jaw": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, 42, 0), None, "hit"),
                (windup + active, (0, 6, 0), None, "ease"), (total, (0, 0, 0), None, "settle")],
    }
    # Dianteiras sobem alto e caem; traseiras se firmam.
    for leg in ("fr", "fl"):
        poses["leg_%s" % leg] = [
            (0.0, (0, 0, 0), None, "accel"),
            (windup, (0, -62, 0), None, "hit"),
            (windup + active, (0, 14, 0), None, "bounce"),
            (total, (0, 0, 0), None, "settle"),
        ]
        poses["paw_%s" % leg] = [
            (0.0, (0, 0, 0), None, "accel"),
            (windup, (0, 44, 0), None, "hit"),
            (windup + active, (0, -10, 0), None, "bounce"),
            (total, (0, 0, 0), None, "settle"),
        ]
    for leg in ("br", "bl"):
        poses["leg_%s" % leg] = [
            (0.0, (0, 0, 0), None, "accel"),
            (windup, (0, 26, 0), None, "hit"),
            (windup + active, (0, -8, 0), None, "ease"),
            (total, (0, 0, 0), None, "settle"),
        ]
    poses["tail_a"] = common.follow(poses["root"], delay=0.10, damping=-0.65, limit=total)
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.08, damping=0.75, limit=total)
    common.animation(rig, "stomp", total, poses, space="world")


def _roar(rig) -> None:
    """Rugido da Fúria: cabeça ao alto, goela escancarada, corpo tremendo."""
    poses = {
        "root": [(0.0, (0, 0, 0), (0.0, 0.0, 0.0), "accel"),
                 (0.35, (0, -12, 0), (-0.08, 0.0, 0.06), "ease"),
                 (0.9, (0, -11, 2), (-0.08, 0.0, 0.07), "ease"),
                 (1.3, (0, -12, -2), (-0.08, 0.0, 0.06), "ease"),
                 (ROAR, (0, 0, 0), (0.0, 0.0, 0.0), "settle")],
        "spine": [(0.0, (0, 0, 0), None, "accel"), (0.35, (0, -14, 0), None, "ease"),
                  (1.3, (0, -13, 0), None, "ease"), (ROAR, (0, 0, 0), None, "settle")],
        "neck": [(0.0, (0, 0, 0), None, "accel"), (0.35, (0, -26, 0), None, "ease"),
                 (0.9, (0, -24, 5), None, "ease"), (1.3, (0, -26, -5), None, "ease"),
                 (ROAR, (0, 0, 0), None, "settle")],
        "head": [(0.0, (0, 0, 0), None, "accel"), (0.35, (0, -22, 0), None, "ease"),
                 (0.9, (0, -20, 6), None, "ease"), (1.3, (0, -22, -6), None, "ease"),
                 (ROAR, (0, 0, 0), None, "settle")],
        "jaw": [(0.0, (0, 0, 0), None, "accel"), (0.3, (0, 56, 0), None, "ease"),
                (1.3, (0, 50, 0), None, "ease"), (ROAR, (0, 0, 0), None, "settle")],
    }
    for leg in LEGS:
        poses["leg_%s" % leg] = [(0.0, (0, 0, 0), None, "accel"),
                                 (0.35, (0, 10 if leg.startswith("f") else -10, 0), None, "ease"),
                                 (ROAR, (0, 0, 0), None, "settle")]
    poses["tail_a"] = [(0.0, (0, 0, 0), None, "accel"), (0.6, (0, -8, 18), None, "ease"),
                       (1.2, (0, -8, -18), None, "ease"), (ROAR, (0, 0, 0), None, "settle")]
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.12, damping=0.9, limit=ROAR)
    common.animation(rig, "roar", ROAR, poses, space="world")


def _stagger(rig) -> None:
    """Queda do Atordoamento: tomba de lado, se debate e se levanta.

    4,5 s (STAGGER_DOWN_DURATION) é a janela de punição mais longa do jogo;
    o corpo precisa parecer REALMENTE caído, não só inclinado.
    """
    down = (62, 6, 0)
    drop = (0.0, -0.30, -0.52)
    poses = {
        "root": [
            (0.0, (0, 0, 0), (0.0, 0.0, 0.0), "accel"),
            (0.18, (-14, 4, 0), (0.0, 0.08, 0.04), "hit"),
            (0.45, down, drop, "bounce"),
            (1.6, (58, 5, -3), (0.0, -0.30, -0.54), "ease"),
            (2.6, (64, 7, 3), (0.0, -0.31, -0.50), "ease"),
            (3.7, (56, 5, 0), (0.0, -0.29, -0.54), "wind"),
            (4.15, (18, 2, 0), (0.0, -0.10, -0.16), "ease"),
            (FALL, (0, 0, 0), (0.0, 0.0, 0.0), "settle"),
        ],
        "spine": [(0.0, (0, 0, 0), None, "accel"), (0.45, (-10, 14, 0), None, "ease"),
                  (2.6, (-8, 10, 0), None, "ease"), (4.15, (0, 6, 0), None, "ease"),
                  (FALL, (0, 0, 0), None, "settle")],
        "neck": [(0.0, (0, 0, 0), None, "accel"), (0.45, (-16, 20, 0), None, "bounce"),
                 (1.6, (-12, 16, -6), None, "ease"), (2.6, (-14, 18, 6), None, "ease"),
                 (4.15, (0, -8, 0), None, "ease"), (FALL, (0, 0, 0), None, "settle")],
        "head": [(0.0, (0, 0, 0), None, "accel"), (0.45, (-12, 16, 0), None, "bounce"),
                 (2.6, (-10, 14, 5), None, "ease"), (4.15, (0, -6, 0), None, "ease"),
                 (FALL, (0, 0, 0), None, "settle")],
        "jaw": [(0.0, (0, 0, 0), None, "accel"), (0.45, (0, 36, 0), None, "ease"),
                (2.6, (0, 28, 0), None, "ease"), (FALL, (0, 0, 0), None, "settle")],
    }
    for leg, sign in (("fr", 1.0), ("fl", -1.0), ("br", 1.0), ("bl", -1.0)):
        poses["leg_%s" % leg] = [
            (0.0, (0, 0, 0), None, "accel"),
            (0.45, (0, 34 * sign, 0), None, "bounce"),
            (1.6, (0, 26 * sign, 0), None, "ease"),
            (2.6, (0, 38 * sign, 0), None, "ease"),
            (4.15, (0, 8 * sign, 0), None, "ease"),
            (FALL, (0, 0, 0), None, "settle"),
        ]
    poses["tail_a"] = common.follow(poses["root"], delay=0.14, damping=-0.5, limit=FALL)
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.10, damping=0.7, limit=FALL)
    common.animation(rig, "stagger_fall", FALL, poses, space="world")


def _death(rig) -> None:
    """Morte: as patas cedem, o corpo desaba de lado e fica. A pose final é a
    última chave — a Godot congela nela."""
    poses = {
        "root": [
            (0.0, (0, 0, 0), (0.0, 0.0, 0.0), "wind"),
            (0.30, (-8, 10, 0), (0.0, 0.03, -0.10), "accel"),
            (0.85, (70, 8, 0), (0.0, -0.34, -0.60), "bounce"),
            (1.25, (76, 9, 0), (0.0, -0.36, -0.64), "settle"),
            (DEATH, (78, 9, 0), (0.0, -0.36, -0.65), "settle"),
        ],
        "spine": [(0.0, (0, 0, 0), None, "wind"), (0.85, (-10, 16, 0), None, "ease"),
                  (DEATH, (-8, 12, 0), None, "settle")],
        "neck": [(0.0, (0, 0, 0), None, "wind"), (0.30, (0, -14, 0), None, "accel"),
                 (0.85, (-14, 26, 0), None, "bounce"), (DEATH, (-10, 22, 0), None, "settle")],
        "head": [(0.0, (0, 0, 0), None, "wind"), (0.85, (-10, 20, 0), None, "bounce"),
                 (DEATH, (-8, 18, 0), None, "settle")],
        "jaw": [(0.0, (0, 0, 0), None, "wind"), (0.30, (0, 46, 0), None, "ease"),
                (DEATH, (0, 40, 0), None, "settle")],
    }
    for leg, sign in (("fr", 1.0), ("fl", -1.0), ("br", 1.0), ("bl", -1.0)):
        poses["leg_%s" % leg] = [
            (0.0, (0, 0, 0), None, "wind"),
            (0.30, (0, 18 * sign, 0), None, "accel"),
            (0.85, (0, 40 * sign, 0), None, "bounce"),
            (DEATH, (0, 42 * sign, 0), None, "settle"),
        ]
    poses["tail_a"] = common.follow(poses["root"], delay=0.16, damping=-0.45, limit=DEATH)
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.12, damping=0.7, limit=DEATH)
    common.animation(rig, "death", DEATH, poses, space="world")


build()
