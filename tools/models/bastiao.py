# -*- coding: utf-8 -*-
"""O Bastião: tanque blindado, criatura original da casa, low-poly cartunesca.

Silhueta: quadrúpede baixo e larguíssimo entre tatu e pangolim, domo de placas
hexagonais chanfradas nas costas, crista frontal em cunha, patas-pilar e uma
cauda-maça poliédrica. Paleta: ardósia azulada nas placas, couro terroso,
musgo nas frestas, carne laranja por baixo da armadura e osso claro na maça.

## O contrato com a apresentação (CreatureView)

Três Partes da ficha viram MALHAS COM NOME PRÓPRIO, porque a Godot precisa
escondê-las/trocá-las quando a Parte quebra — o mesmo contrato que a cauda do
quadrúpede já usa:

    crest       Crista   (placa frontal; some ao quebrar)
    shell       Carapaça (domo dorsal; some ao quebrar)
    tail        Cauda-maça (decepável; some ao decepar)
    raw_head    carne exposta sob a Crista   — nasce ESCONDIDA, aparece na quebra
    raw_shell   carne exposta sob a Carapaça — idem

Por isso a carne (`raw_*`) é modelada por baixo das placas em vez de a placa
simplesmente sumir deixando buraco: quebrar vira troca de camada, legível de
longe, que é o ponto da luta ("o jogador vê qual setor já está aberto").

## Rig

    root ─ spine ─ neck ─ head ─ jaw
         ├ tail_a ─ tail_b
         └ leg_fr ─ paw_fr   (e fl, br, bl)

Os ossos da cauda NÃO se chamam "tail" para não disputarem o nome com a malha
decepável na importação do glTF. Toda pose usa `space="world"`.

## Animações

Durações copiadas de src/sim/behemoths.gd (windup+active+recovery), um clipe
por ataque com o ID EXATO do ataque:

    headbutt = 0.66 + 0.16 + 0.70 = 1.52 s
    roll     = 0.90 + 0.50 + 0.90 = 2.30 s
    mace     = 0.60 + 0.20 + 0.75 = 1.55 s
    quake    = 0.85 + 0.20 + 0.90 = 1.95 s

E de sim_config.gd: stagger_fall = STAGGER_DOWN_DURATION = 4.5 s.

Rodar:  blender --background --python tools/models/bastiao.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common

OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "bastiao.glb"
)

HEADBUTT = (0.66, 0.16, 0.70)
ROLL = (0.90, 0.50, 0.90)
MACE = (0.60, 0.20, 0.75)
QUAKE = (0.85, 0.20, 0.90)
ROAR = 2.0
FALL = 4.5
DEATH = 2.0

LEGS = ["fr", "fl", "br", "bl"]
LEG_AT = {"fr": (0.80, -0.95), "fl": (0.80, 0.95), "br": (-0.85, -0.95), "bl": (-0.85, 0.95)}


def build() -> None:
    common.reset_scene()

    # Couro é o material que a CreatureView tinge pela variante elemental.
    #
    # Paleta da ficha: placa cinza-ardósia, musgo nas frestas, carne laranja
    # sob a armadura. Três valores bem separados (couro médio-quente, pedra
    # fria, borda quase preta) é o que dá silhueta na distância da Arena.
    hide = common.material("bastion_hide", "8a6440")
    plate = common.material("bastion_plate", "6b7584")
    plate_dark = common.material("bastion_plate_dark", "3a4350")
    moss = common.material("bastion_moss", "8cbf5c")
    flesh = common.material("bastion_flesh", "ff9b3d", roughness=0.5)
    bone = common.material("bastion_bone", "e8dcb8")
    eye = common.material("bastion_eye", "ffcc55", roughness=0.25)

    # Olha para +X. Mais baixo e MUITO mais largo que o quadrúpede: o domo é
    # a silhueta, e ele precisa ser lido como uma colina que anda.
    bones = {
        "root": ((0.0, 0.0, 1.15), (0.0, 0.0, 1.80), None),
    }
    bones.update(common.chain(
        ["spine", "neck", "head"],
        [(-0.15, 0.0, 1.25), (0.70, 0.0, 1.26), (1.40, 0.0, 1.22), (2.35, 0.0, 1.10)],
        "root",
    ))
    bones["jaw"] = ((1.45, 0.0, 0.84), (2.45, 0.0, 0.76), "head")
    bones.update(common.chain(
        ["tail_a", "tail_b"],
        [(-1.15, 0.0, 1.20), (-2.10, 0.0, 1.28), (-3.20, 0.0, 1.42)],
        "root",
    ))
    for leg in LEGS:
        px, py = LEG_AT[leg]
        bones.update(common.chain(
            ["leg_%s" % leg, "paw_%s" % leg],
            [(px, py, 0.95), (px + 0.02, py, 0.34), (px + 0.18, py, 0.07)],
            "root",
        ))
    rig = common.armature("Bastiao", bones)

    # --- Corpo: um barril baixo, MENOR que o domo. A silhueta é a Carapaça;
    # o couro só aparece na borda, no ventre e quando a placa cai. ---
    common.attach(
        common.sphere("m_body", 1.25, (0.0, 0.0, 1.15), hide,
                      subdivisions=2, squash=(1.12, 1.0, 0.50)),
        rig, "root",
    )
    common.attach(
        common.sphere("m_belly", 1.10, (0.1, 0.0, 0.78), hide,
                      subdivisions=1, squash=(1.2, 1.0, 0.34)),
        rig, "root",
    )
    # Musgo na fresta: a faixa viva na BORDA do domo, de um lado ao outro.
    # Fica à mostra com a Carapaça inteira e continua ali depois da quebra —
    # a leitura de "couro vivo sob a pedra".
    for sign in (-1.0, 1.0):
        common.attach(
            common.box("m_moss_%s" % ("l" if sign > 0 else "r"),
                       (2.10, 0.22, 0.22), (-0.05, sign * 1.20, 1.00), moss),
            rig, "root",
        )

    # --- Carapaça: UMA malha "shell" (a Godot esconde pelo nome ao quebrar) ---
    #
    # Um DOMO inteiriço mais quatro placas telhadas por cima. A primeira
    # versão era um monte de plaquinhas soltas e, de longe, virava entulho:
    # a leitura "colina que anda" vem da casca contínua, e as placas só dão a
    # textura de pangolim. A borda escura fecha o desenho.
    shell_parts = [
        common.sphere("shell_dome", 1.42, (-0.10, 0.0, 1.30), plate,
                      subdivisions=2, squash=(1.08, 0.92, 0.60)),
    ]
    # Barbatanas da quilha: CAIXAS, não prismas inclinados. Os prismas
    # hexagonais da versão anterior viravam picos triangulares e o domo lia
    # como entulho; três cristas retas dão a mesma ideia e sobrevivem à
    # distância da câmera da Arena.
    for i, (px, pz) in enumerate([(0.72, 1.98), (-0.08, 2.10), (-0.88, 1.96)]):
        shell_parts.append(common.box(
            "shell_fin_%d" % i, (0.50, 0.32, 0.56), (px, 0.0, pz), plate_dark,
        ))
    for i, (px, pz) in enumerate([(0.50, 1.84), (-0.72, 1.80)]):
        for sign in (-1.0, 1.0):
            shell_parts.append(common.box(
                "shell_ridge_%d%s" % (i, "l" if sign > 0 else "r"),
                (1.05, 0.24, 0.32), (px, sign * 0.90, pz), plate_dark,
                rotation=(sign * 0.80, 0.0, 0.0),
            ))
    # Aba escura: a borda do casco, que separa pedra de couro à distância.
    for sign in (-1.0, 1.0):
        shell_parts.append(common.box(
            "shell_rim_%s" % ("l" if sign > 0 else "r"),
            (2.60, 0.28, 0.32), (-0.10, sign * 1.28, 1.34), plate_dark,
            rotation=(sign * 0.22, 0.0, 0.0),
        ))
    shell_parts.append(common.box("shell_rim_b", (0.30, 1.95, 0.32), (-1.52, 0.0, 1.36), plate_dark))
    common.attach(common.join(shell_parts, "shell"), rig, "root")

    # Carne sob a Carapaça: nasce ESCONDIDA (a CreatureView acende na quebra) e
    # mora logo abaixo da casca, para aparecer inteira quando ela cai.
    # Afundada: a carne mora um palmo ABAIXO da superfície do domo. As pontas
    # da icoesfera furavam a casca e apareciam como manchas laranja no modelo
    # inteiro — o domo é poliedro, a superfície real é menor que o raio.
    raw_shell = [
        common.sphere("raw_shell_%d" % i, r, (px, py, pz), flesh,
                      subdivisions=1, squash=(1.0, 1.0, 0.5))
        for i, (px, py, pz, r) in enumerate([(0.75, 0.0, 1.50, 0.48), (-0.10, 0.0, 1.58, 0.60),
                                             (-0.95, 0.0, 1.50, 0.50),
                                             (-0.10, -0.74, 1.34, 0.42),
                                             (-0.10, 0.74, 1.34, 0.42)])
    ]
    common.attach(common.join(raw_shell, "raw_shell"), rig, "root")

    # --- Cabeça: sai inteira na FRENTE do domo. Enfiada demais, a Crista (a
    # Parte que o jogador precisa quebrar) desaparecia atrás da casca. ---
    common.attach(common.box("m_head", (1.00, 1.05, 0.70), (1.90, 0.0, 1.20), hide), rig, "head")
    common.attach(common.box("m_snout", (0.60, 0.80, 0.40), (2.45, 0.0, 1.12), hide), rig, "head")
    common.attach(common.sphere("m_eye_r", 0.14, (2.25, -0.44, 1.38), eye, subdivisions=1), rig, "head")
    common.attach(common.sphere("m_eye_l", 0.14, (2.25, 0.44, 1.38), eye, subdivisions=1), rig, "head")
    common.attach(common.box("m_jaw", (1.00, 0.90, 0.28), (2.10, 0.0, 0.86), plate_dark), rig, "jaw")
    for i, ty in enumerate([-0.28, 0.28]):
        common.attach(
            common.box("m_tooth_%d" % i, (0.20, 0.20, 0.28), (2.45, ty, 0.98), bone),
            rig, "jaw",
        )

    # --- Crista: a cunha frontal. Malha própria, some ao quebrar. ---
    crest_parts = [
        # Cunha de QUATRO faces e baixa: a primeira versão era um cone de seis
        # faces tão alto que, de frente, virava barbatana de tubarão e comia a
        # cabeça inteira na silhueta.
        common.cone("crest_wedge", 0.56, 0.95, (2.18, 0.0, 1.58), plate,
                    rotation=(0.0, 1.50, 0.0), vertices=4),
        common.box("crest_brow", (0.50, 1.16, 0.26), (1.84, 0.0, 1.56), plate_dark,
                   rotation=(0.0, 0.20, 0.0)),
    ]
    for sign in (-1.0, 1.0):
        # Chifres curtos e grossos, varridos para trás como sobrancelha de
        # pedra. Compridos e para a frente viravam antena na silhueta.
        crest_parts.append(common.cone(
            "crest_horn_%s" % ("l" if sign > 0 else "r"), 0.26, 0.66,
            (1.62, sign * 0.52, 1.60), plate_dark,
            rotation=(sign * 0.70, -0.60, 0.0), vertices=5,
        ))
    common.attach(common.join(crest_parts, "crest"), rig, "head")
    common.attach(
        common.join([
            common.sphere("raw_head_a", 0.40, (2.00, 0.0, 1.34), flesh, subdivisions=1,
                          squash=(1.1, 1.05, 0.7)),
            common.box("raw_head_b", (0.34, 0.80, 0.22), (1.74, 0.0, 1.40), flesh),
        ], "raw_head"),
        rig, "head",
    )

    # --- Cauda-maça: UMA malha "tail" repartida entre os dois ossos ---
    # A maça é um BLOCO, não um ouriço: espinhos curtos e gordos. Com
    # espinhos compridos a ponta virava um borrão branco de lado.
    tail_parts = [
        common.box("tail_seg_a", (1.00, 0.72, 0.56), (-1.60, 0.0, 1.24), hide),
        common.box("tail_seg_b", (0.85, 0.56, 0.46), (-2.40, 0.0, 1.32), hide),
        common.box("tail_ring", (0.24, 0.70, 0.64), (-2.00, 0.0, 1.28), plate_dark),
        # A maça é um BLOCO chanfrado, não um ouriço: a versão com esfera e
        # espinhos finos virava um borrão branco amassado de lado.
        common.box("tail_club", (1.10, 1.00, 0.96), (-3.10, 0.0, 1.44), plate),
        common.box("tail_club_band", (0.30, 1.14, 1.10), (-3.10, 0.0, 1.44), plate_dark),
    ]
    for i, (dx, dy, dz, rot) in enumerate([(0.62, 0.0, 0.0, (0.0, 1.57, 0.0)),
                                           (0.0, 0.0, 0.58, (0.0, 0.0, 0.0)),
                                           (0.0, -0.60, 0.0, (1.57, 0.0, 0.0)),
                                           (0.0, 0.60, 0.0, (-1.57, 0.0, 0.0))]):
        tail_parts.append(common.cone(
            "tail_spike_%d" % i, 0.30, 0.44, (-3.10 + dx, dy, 1.44 + dz), bone,
            rotation=rot, vertices=4,
        ))
    tail = common.join(tail_parts, "tail")
    common.attach_gradient(
        tail, rig,
        [("tail_a", -2.05, -1.05), ("tail_b", -3.90, -2.05)],
        axis=0, blend=0.40,
    )

    # --- Patas-pilar: curtas, grossas, com unha de pedra ---
    for leg in LEGS:
        px, py = LEG_AT[leg]
        common.attach(
            common.cylinder("m_leg_%s" % leg, 0.40, 0.70, (px, py, 0.66), hide, vertices=6),
            rig, "leg_%s" % leg,
        )
        common.attach(
            common.box("m_knee_%s" % leg, (0.46, 0.48, 0.30), (px, py, 0.88), plate_dark),
            rig, "leg_%s" % leg,
        )
        common.attach(
            common.sphere("m_ankle_%s" % leg, 0.32, (px + 0.02, py, 0.32), hide, subdivisions=1),
            rig, "paw_%s" % leg,
        )
        common.attach(
            common.box("m_foot_%s" % leg, (0.66, 0.66, 0.24), (px + 0.14, py, 0.12), plate_dark),
            rig, "paw_%s" % leg,
        )
        common.attach(
            common.box("m_claw_%s" % leg, (0.24, 0.56, 0.18), (px + 0.52, py, 0.09), bone),
            rig, "paw_%s" % leg,
        )

    _animate(rig)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    common.export_glb(os.path.abspath(OUT))


# --- Ferramentas de pose -------------------------------------------------


def _attack(rig, name, phases, wind, hit, amount=0.18, at=0.35,
            wind_ease="accel", hit_ease="hit", rest=None) -> None:
    """Um ataque com as três fases da Sim, no molde do quadrúpede.

    O Bastião é mais lento para armar e assenta com MENOS overshoot: ele é
    peso, não elástico. A cauda sai como arrasto defasado do corpo, menos na
    Maçada — ali ela é o golpe.
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
            over_loc = tuple(end_loc[i] + (peak_loc[i] - end_loc[i]) * 0.28 for i in range(3))
            tail = [(tail[0][0], tail[0][1], over_loc, tail[0][3]),
                    (tail[1][0], tail[1][1], end_loc, tail[1][3])]
        poses[key] = keys + tail

    if "tail_a" not in poses:
        poses["tail_a"] = common.follow(poses["root"], delay=0.11, damping=-0.5, limit=total)
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.08, damping=0.65, limit=total)
    common.animation(rig, name, total, poses, space="world")


def _split(value):
    if len(value) == 2 and isinstance(value[0], (tuple, list)):
        return tuple(value[0]), tuple(value[1])
    return tuple(value), None


def _animate(rig) -> None:
    _idle(rig)
    _walk(rig)
    _headbutt(rig)
    _roll(rig)
    _mace(rig)
    _quake(rig)
    _roar(rig)
    _stagger(rig)
    _death(rig)


def _idle(rig) -> None:
    """Repouso: o domo sobe e desce devagar, a cabeça gira vigiando.

    Mais lento e de amplitude menor que o do quadrúpede — quem é muralha
    respira pouco.
    """
    idle = 2.4
    poses = {
        "root": common.cycle(idle, amplitude=(0, 0.7, 0), loc_amplitude=(0.0, 0.0, 0.03), samples=8),
        "spine": common.cycle(idle, amplitude=(0, -1.1, 0), samples=8),
        "neck": common.cycle(idle, amplitude=(0, -1.4, 3.0), samples=8),
        "head": common.cycle(idle, amplitude=(0, -1.6, 4.0), samples=8),
        "jaw": common.cycle(idle, amplitude=(0, 2.5, 0), bias=(0, 2, 0), samples=8),
    }
    poses["tail_a"] = common.cycle(idle, amplitude=(0, -1.5, 6.0), samples=8)
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.2, damping=0.85, limit=idle)
    for leg in LEGS:
        poses["leg_%s" % leg] = [(0.0, (0, 0, 0), None, "ease"), (idle, (0, 0, 0), None, "ease")]
    common.animation(rig, "idle", idle, poses, space="world")


def _walk(rig) -> None:
    """Andadura diagonal pesada: passada longa, corpo rolando de lado.

    1,15 s por ciclo contra 0,90 do quadrúpede — ele é 20% mais lento na Sim
    (move_speed 120 contra 148) e o passo precisa dizer isso sozinho.
    """
    walk = 1.15
    phases = {"fr": 0.25, "bl": 0.25, "fl": 0.75, "br": 0.75}
    poses = {
        "root": common.cycle(walk, amplitude=(6.0, 0, 0), loc_amplitude=(0.0, 0.06, 0.05),
                             harmonic=2, phase=0.25, samples=10),
        "spine": common.cycle(walk, amplitude=(0, 0, 3.0), samples=10),
        "neck": common.cycle(walk, amplitude=(0, 2.5, -2.0), bias=(0, 2, 0), samples=10),
        "head": common.cycle(walk, amplitude=(0, 3.0, -2.5), bias=(0, 3, 0), samples=10),
        "jaw": [(0.0, (0, 3, 0), None, "ease"), (walk, (0, 3, 0), None, "ease")],
    }
    for leg, phase in phases.items():
        poses["leg_%s" % leg] = common.cycle(walk, amplitude=(0, -20.0, 0), phase=phase, samples=10)
        poses["paw_%s" % leg] = common.cycle(walk, amplitude=(0, 26.0, 0), bias=(0, -5, 0),
                                             phase=phase - 0.33, rectify=True, samples=10)
    poses["tail_a"] = common.cycle(walk, amplitude=(0, -2.0, 7.0), samples=10)
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.14, damping=0.8, limit=walk)
    common.animation(rig, "walk", walk, poses, space="world")


def _headbutt(rig) -> None:
    """Cabeçada: 0,66 s enfiando a cabeça no peito, com a Crista de frente.

    A leitura é a Crista: ele a aponta para o alvo durante o Preparo (cabeça
    baixa, traseiras comprimidas) e empurra o corpo INTEIRO atrás dela. Quem
    quebrou a Crista vê a carne laranja mirando — e a quebra é feita na cara.
    """
    _attack(rig, "headbutt", HEADBUTT,
            wind={
                "root": ((0, -9, 0), (-0.16, 0.0, -0.05)),
                "spine": (0, -6, 0), "neck": (0, 16, 0), "head": (0, 12, 0),
                "jaw": (0, 18, 0),
                "leg_fr": (0, 20, 0), "leg_fl": (0, 20, 0),
                "leg_br": (0, -16, 0), "leg_bl": (0, -16, 0),
                "paw_fr": (0, -12, 0), "paw_fl": (0, -12, 0),
            },
            hit={
                "root": ((0, 12, 0), (0.30, 0.0, 0.04)),
                "spine": (0, 10, 0), "neck": (0, -14, 0), "head": (0, -10, 0),
                "jaw": (0, -2, 0),
                "leg_fr": (0, -24, 0), "leg_fl": (0, -24, 0),
                "leg_br": (0, 18, 0), "leg_bl": (0, 18, 0),
                "paw_fr": (0, 16, 0), "paw_fl": (0, 16, 0),
            }, amount=0.16)


def _roll(rig) -> None:
    """Rolamento de Pedra: encolhe, vira bola e rola duas voltas inteiras.

    O Preparo de 0,90 s é o mais longo do repertório dele: ele recolhe as
    patas, baixa a cabeça e BALANÇA para trás antes de disparar — é o aviso
    que a Sim cobra. No Ativo a raiz dá 720° em `ry` (duas voltas completas,
    com chaves a cada meia volta para a curva sair redonda) e avança 0,6 m
    dentro do clipe; a posição no mundo quem manda é a Sim.

    A Carapaça quebrada muda a LEITURA sem mudar o clipe: quem já abriu o
    domo vê a carne laranja girando. É o mesmo movimento com outra cara.
    """
    windup, active, recovery = ROLL
    total = windup + active + recovery
    tuck = windup * 0.62
    poses = {
        # O +0,55 m de altura no Ativo não é enfeite: a bola gira em torno da
        # raiz, e o ponto mais distante dela (a maça enrolada por cima) passa
        # por baixo. Sem subir o centro, meio corpo atravessava o chão no meio
        # do giro — apareceu no primeiro preview.
        "root": [
            (0.0, (0, 0, 0), (0.0, 0.0, 0.0), "wind"),
            (tuck, (0, -22, 0), (-0.26, 0.0, -0.12), "accel"),
            (windup, (0, -8, 0), (-0.34, 0.0, 0.10), "linear"),
            (windup + active * 0.25, (0, 172, 0), (-0.10, 0.0, 0.55), "linear"),
            (windup + active * 0.50, (0, 352, 0), (0.14, 0.0, 0.55), "linear"),
            (windup + active * 0.75, (0, 532, 0), (0.38, 0.0, 0.55), "linear"),
            (windup + active, (0, 720, 0), (0.60, 0.0, 0.12), "settle"),
            (windup + active + 0.34, (0, 742, 0), (0.30, 0.0, -0.08), "ease"),
            (total - 0.28, (0, 714, 0), (0.08, 0.0, 0.02), "ease"),
            (total, (0, 720, 0), (0.0, 0.0, 0.0), "settle"),
        ],
        "spine": [(0.0, (0, 0, 0), None, "wind"), (tuck, (0, -14, 0), None, "accel"),
                  (windup + active, (0, -6, 0), None, "ease"),
                  (windup + active + 0.4, (0, 8, 0), None, "ease"),
                  (total, (0, 0, 0), None, "settle")],
        # Cabeça enfiada para dentro: é o que transforma o bicho em bola.
        "neck": [(0.0, (0, 0, 0), None, "wind"), (tuck, (0, 44, 0), None, "accel"),
                 (windup, (0, 52, 0), None, "hold"),
                 (windup + active, (0, 50, 0), None, "ease"),
                 (windup + active + 0.45, (0, -14, 0), None, "ease"),
                 (total, (0, 0, 0), None, "settle")],
        "head": [(0.0, (0, 0, 0), None, "wind"), (tuck, (0, 38, 0), None, "accel"),
                 (windup + active, (0, 42, 0), None, "ease"),
                 (windup + active + 0.45, (0, -12, 0), None, "ease"),
                 (total, (0, 0, 0), None, "settle")],
        "jaw": [(0.0, (0, 0, 0), None, "wind"), (tuck, (0, -8, 0), None, "accel"),
                (windup + active, (0, -8, 0), None, "ease"),
                (windup + active + 0.4, (0, 26, 0), None, "ease"),
                (total, (0, 0, 0), None, "settle")],
        # A cauda se enrola POR CIMA do domo (ry positivo levanta a ponta de um
        # osso que aponta para trás) e só se solta na derrapada. Com o sinal
        # trocado ela enfiava a maça no chão durante o giro inteiro.
        "tail_a": [(0.0, (0, 0, 0), None, "wind"), (tuck, (0, 96, 0), None, "accel"),
                   (windup + active, (0, 104, 0), None, "ease"),
                   (windup + active + 0.4, (0, -14, 0), None, "ease"),
                   (total, (0, 0, 0), None, "settle")],
    }
    for leg in LEGS:
        sign = 1.0 if leg.startswith("f") else -1.0
        poses["leg_%s" % leg] = [
            (0.0, (0, 0, 0), None, "wind"),
            (tuck, (0, 62 * sign, 0), None, "accel"),
            (windup, (0, 68 * sign, 0), None, "hold"),
            (windup + active, (0, 66 * sign, 0), None, "ease"),
            (windup + active + 0.42, (0, -16 * sign, 0), None, "ease"),
            (total, (0, 0, 0), None, "settle"),
        ]
        poses["paw_%s" % leg] = [
            (0.0, (0, 0, 0), None, "wind"),
            (tuck, (0, -54 * sign, 0), None, "accel"),
            (windup + active, (0, -56 * sign, 0), None, "ease"),
            (windup + active + 0.42, (0, 14 * sign, 0), None, "ease"),
            (total, (0, 0, 0), None, "settle"),
        ]
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.07, damping=0.8, limit=total)
    common.animation(rig, "roll", total, poses, space="world")


def _mace(rig) -> None:
    """Maçada: a cauda sobe por cima do domo e desce atrás como um malho.

    Cone para TRÁS com arco largo (2,2 rad): a maça entra alta, varre e bate.
    A cauda não acompanha o corpo aqui — ela É o golpe, e a ponta chega
    depois da base (estalo). Some junto com a Parte quando a cauda é decepada:
    a Sim tira o ataque do repertório, a malha "tail" some do corpo.
    """
    windup, active, recovery = MACE
    total = windup + active + recovery
    poses = {
        "root": [
            (0.0, (0, 0, 0), (0.0, 0.0, 0.0), "accel"),
            (windup, (-6, -10, -22), (0.06, -0.06, 0.05), "hit"),
            (windup + active, (4, 8, 26), (-0.04, 0.08, -0.06), "ease"),
            (windup + active + 0.30, (0, 2, 8), (0.0, 0.02, 0.0), "ease"),
            (total, (0, 0, 0), (0.0, 0.0, 0.0), "settle"),
        ],
        "spine": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, -6, -10), None, "hit"),
                  (windup + active, (0, 6, 12), None, "ease"), (total, (0, 0, 0), None, "settle")],
        "neck": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, 8, 16), None, "hit"),
                 (windup + active, (0, -4, -18), None, "ease"), (total, (0, 0, 0), None, "settle")],
        "head": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, 10, 18), None, "hit"),
                 (windup + active, (0, -6, -20), None, "ease"), (total, (0, 0, 0), None, "settle")],
        "jaw": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, 22, 0), None, "ease"),
                (total, (0, 0, 0), None, "settle")],
        # Preparo: a maça SOBE (ry positivo levanta a ponta de um osso que
        # aponta para trás) e torce para um lado. Ativo: desce varrendo para o
        # outro — e para em -14°, não mais fundo: a cauda tem 2,1 m, e um
        # ângulo maior enterraria a maça no chão em vez de bater nele.
        "tail_a": [
            (0.0, (0, 0, 0), None, "accel"),
            (windup * 0.5, (0, 44, 26), None, "accel"),
            (windup, (0, 72, 46), None, "hit"),
            (windup + active, (0, -14, -54), None, "ease"),
            (windup + active + 0.32, (0, 6, -18), None, "ease"),
            (total, (0, 0, 0), None, "settle"),
        ],
    }
    for leg, sign in (("fr", -1.0), ("fl", 1.0), ("br", -1.0), ("bl", 1.0)):
        poses["leg_%s" % leg] = [
            (0.0, (0, 0, 0), None, "accel"),
            (windup, (0, 14 * sign, 0), None, "hit"),
            (windup + active, (0, -16 * sign, 0), None, "ease"),
            (total, (0, 0, 0), None, "settle"),
        ]
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.09, damping=0.95, limit=total)
    common.animation(rig, "mace", total, poses, space="world")


def _quake(rig) -> None:
    """Tremor: empina, segura no alto e DESPENCA com as duas dianteiras.

    0,85 s no alto é o aviso mais longo depois do Rolamento, e o círculo sai
    de onde as patas batem. A Recuperação quica duas vezes: o peso não para
    de uma vez, e é dessa sobra que vem a janela de punição.
    """
    windup, active, recovery = QUAKE
    total = windup + active + recovery
    poses = {
        "root": [
            (0.0, (0, 0, 0), (0.0, 0.0, 0.0), "accel"),
            (windup * 0.3, (0, 7, 0), (-0.05, 0.0, -0.09), "wind"),
            (windup, (0, -34, 0), (-0.22, 0.0, 0.40), "hit"),
            (windup + active, (0, 10, 0), (0.12, 0.0, -0.22), "bounce"),
            (windup + active + 0.26, (0, -4, 0), (0.0, 0.0, 0.07), "ease"),
            (total - 0.30, (0, 3, 0), (0.0, 0.0, -0.03), "ease"),
            (total, (0, 0, 0), (0.0, 0.0, 0.0), "settle"),
        ],
        "spine": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, -18, 0), None, "hit"),
                  (windup + active, (0, 14, 0), None, "bounce"), (total, (0, 0, 0), None, "settle")],
        "neck": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, -24, 0), None, "hit"),
                 (windup + active, (0, 20, 0), None, "bounce"), (total, (0, 0, 0), None, "settle")],
        "head": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, -20, 0), None, "hit"),
                 (windup + active, (0, 18, 0), None, "bounce"), (total, (0, 0, 0), None, "settle")],
        "jaw": [(0.0, (0, 0, 0), None, "accel"), (windup, (0, 40, 0), None, "hit"),
                (windup + active, (0, 4, 0), None, "ease"), (total, (0, 0, 0), None, "settle")],
    }
    for leg in ("fr", "fl"):
        poses["leg_%s" % leg] = [
            (0.0, (0, 0, 0), None, "accel"),
            (windup * 0.55, (0, -52, 0), None, "wind"),
            (windup, (0, -70, 0), None, "hit"),
            (windup + active, (0, 16, 0), None, "bounce"),
            (total, (0, 0, 0), None, "settle"),
        ]
        poses["paw_%s" % leg] = [
            (0.0, (0, 0, 0), None, "accel"),
            (windup, (0, 50, 0), None, "hit"),
            (windup + active, (0, -12, 0), None, "bounce"),
            (total, (0, 0, 0), None, "settle"),
        ]
    for leg in ("br", "bl"):
        poses["leg_%s" % leg] = [
            (0.0, (0, 0, 0), None, "accel"),
            (windup, (0, 30, 0), None, "hit"),
            (windup + active, (0, -10, 0), None, "ease"),
            (total, (0, 0, 0), None, "settle"),
        ]
    poses["tail_a"] = common.follow(poses["root"], delay=0.11, damping=-0.6, limit=total)
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.08, damping=0.7, limit=total)
    common.animation(rig, "quake", total, poses, space="world")


def _roar(rig) -> None:
    """Rugido da Fúria: ele se LEVANTA no lugar e as placas arrepiam.

    Diferente do rugido do quadrúpede (que escancara a goela): o Bastião
    arqueia o domo, estufa e troveja — fantasia de muralha, não de predador.
    """
    poses = {
        "root": [(0.0, (0, 0, 0), (0.0, 0.0, 0.0), "accel"),
                 (0.40, (0, -9, 0), (-0.06, 0.0, 0.14), "ease"),
                 (0.95, (0, -8, 3), (-0.06, 0.0, 0.15), "ease"),
                 (1.40, (0, -9, -3), (-0.06, 0.0, 0.14), "ease"),
                 (ROAR, (0, 0, 0), (0.0, 0.0, 0.0), "settle")],
        "spine": [(0.0, (0, 0, 0), None, "accel"), (0.40, (0, -12, 0), None, "ease"),
                  (1.40, (0, -11, 0), None, "ease"), (ROAR, (0, 0, 0), None, "settle")],
        "neck": [(0.0, (0, 0, 0), None, "accel"), (0.40, (0, -30, 0), None, "ease"),
                 (0.95, (0, -28, 4), None, "ease"), (1.40, (0, -30, -4), None, "ease"),
                 (ROAR, (0, 0, 0), None, "settle")],
        "head": [(0.0, (0, 0, 0), None, "accel"), (0.40, (0, -24, 0), None, "ease"),
                 (0.95, (0, -22, 5), None, "ease"), (1.40, (0, -24, -5), None, "ease"),
                 (ROAR, (0, 0, 0), None, "settle")],
        "jaw": [(0.0, (0, 0, 0), None, "accel"), (0.35, (0, 46, 0), None, "ease"),
                (1.40, (0, 40, 0), None, "ease"), (ROAR, (0, 0, 0), None, "settle")],
    }
    for leg in LEGS:
        poses["leg_%s" % leg] = [(0.0, (0, 0, 0), None, "accel"),
                                 (0.40, (0, -14 if leg.startswith("f") else 14, 0), None, "ease"),
                                 (1.40, (0, -12 if leg.startswith("f") else 12, 0), None, "ease"),
                                 (ROAR, (0, 0, 0), None, "settle")]
    poses["tail_a"] = [(0.0, (0, 0, 0), None, "accel"), (0.6, (0, -16, 14), None, "ease"),
                       (1.3, (0, -16, -14), None, "ease"), (ROAR, (0, 0, 0), None, "settle")]
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.12, damping=0.9, limit=ROAR)
    common.animation(rig, "roar", ROAR, poses, space="world")


def _stagger(rig) -> None:
    """Queda do Atordoamento: tomba de lado e fica de barriga à mostra.

    Para um bicho cujo dorso é parede, o castigo da queda é EXPOR O VENTRE:
    ele rola ~74° (mais que o quadrúpede, que para em 62°), bate as patas no
    ar e precisa de impulso para se endireitar. 4,5 s é a maior janela de
    punição do jogo — o corpo precisa parecer realmente virado.
    """
    down = (74, 4, 0)
    # O domo é mais largo (1,31 m) do que a raiz é alta (1,15 m): tombado 74°,
    # a borda da casca fica ABAIXO do pivô. Por isso o corpo SOBE um palmo em
    # vez de descer — com o deslocamento negativo do quadrúpede (cuja raiz é
    # bem mais alta), meia carapaça entrava no chão.
    drop = (0.0, -0.34, 0.12)
    poses = {
        "root": [
            (0.0, (0, 0, 0), (0.0, 0.0, 0.0), "accel"),
            (0.20, (-16, 5, 0), (0.0, 0.10, 0.05), "hit"),
            (0.50, down, drop, "bounce"),
            (1.7, (70, 3, -3), (0.0, -0.34, 0.10), "ease"),
            (2.8, (78, 5, 3), (0.0, -0.35, 0.15), "ease"),
            (3.8, (68, 3, 0), (0.0, -0.33, 0.10), "wind"),
            (4.2, (22, 2, 0), (0.0, -0.12, 0.04), "ease"),
            (FALL, (0, 0, 0), (0.0, 0.0, 0.0), "settle"),
        ],
        "spine": [(0.0, (0, 0, 0), None, "accel"), (0.50, (-8, 12, 0), None, "ease"),
                  (2.8, (-6, 9, 0), None, "ease"), (4.2, (0, 5, 0), None, "ease"),
                  (FALL, (0, 0, 0), None, "settle")],
        "neck": [(0.0, (0, 0, 0), None, "accel"), (0.50, (-14, 22, 0), None, "bounce"),
                 (1.7, (-10, 18, -6), None, "ease"), (2.8, (-12, 20, 6), None, "ease"),
                 (4.2, (0, -10, 0), None, "ease"), (FALL, (0, 0, 0), None, "settle")],
        "head": [(0.0, (0, 0, 0), None, "accel"), (0.50, (-10, 18, 0), None, "bounce"),
                 (2.8, (-8, 16, 5), None, "ease"), (4.2, (0, -8, 0), None, "ease"),
                 (FALL, (0, 0, 0), None, "settle")],
        "jaw": [(0.0, (0, 0, 0), None, "accel"), (0.50, (0, 32, 0), None, "ease"),
                (2.8, (0, 24, 0), None, "ease"), (FALL, (0, 0, 0), None, "settle")],
    }
    for leg, sign in (("fr", 1.0), ("fl", -1.0), ("br", 1.0), ("bl", -1.0)):
        poses["leg_%s" % leg] = [
            (0.0, (0, 0, 0), None, "accel"),
            (0.50, (0, 40 * sign, 0), None, "bounce"),
            (1.7, (0, 30 * sign, 0), None, "ease"),
            (2.8, (0, 46 * sign, 0), None, "ease"),
            (4.2, (0, 10 * sign, 0), None, "ease"),
            (FALL, (0, 0, 0), None, "settle"),
        ]
    poses["tail_a"] = common.follow(poses["root"], delay=0.15, damping=-0.45, limit=FALL)
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.10, damping=0.7, limit=FALL)
    common.animation(rig, "stagger_fall", FALL, poses, space="world")


def _death(rig) -> None:
    """Morte: as patas cedem de uma vez e o domo desaba. Congela na última
    pose — a Godot para o clipe ali."""
    poses = {
        "root": [
            (0.0, (0, 0, 0), (0.0, 0.0, 0.0), "wind"),
            (0.35, (-6, 12, 0), (0.0, 0.04, -0.12), "accel"),
            (0.95, (66, 6, 0), (0.0, -0.36, 0.08), "bounce"),
            (1.35, (72, 7, 0), (0.0, -0.38, 0.12), "settle"),
            (DEATH, (74, 7, 0), (0.0, -0.38, 0.12), "settle"),
        ],
        "spine": [(0.0, (0, 0, 0), None, "wind"), (0.95, (-8, 14, 0), None, "ease"),
                  (DEATH, (-6, 10, 0), None, "settle")],
        "neck": [(0.0, (0, 0, 0), None, "wind"), (0.35, (0, -12, 0), None, "accel"),
                 (0.95, (-12, 24, 0), None, "bounce"), (DEATH, (-9, 20, 0), None, "settle")],
        "head": [(0.0, (0, 0, 0), None, "wind"), (0.95, (-9, 18, 0), None, "bounce"),
                 (DEATH, (-7, 16, 0), None, "settle")],
        "jaw": [(0.0, (0, 0, 0), None, "wind"), (0.35, (0, 40, 0), None, "ease"),
                (DEATH, (0, 34, 0), None, "settle")],
    }
    for leg, sign in (("fr", 1.0), ("fl", -1.0), ("br", 1.0), ("bl", -1.0)):
        poses["leg_%s" % leg] = [
            (0.0, (0, 0, 0), None, "wind"),
            (0.35, (0, 20 * sign, 0), None, "accel"),
            (0.95, (0, 44 * sign, 0), None, "bounce"),
            (DEATH, (0, 46 * sign, 0), None, "settle"),
        ]
    poses["tail_a"] = common.follow(poses["root"], delay=0.16, damping=-0.45, limit=DEATH)
    poses["tail_b"] = common.follow(poses["tail_a"], delay=0.12, damping=0.7, limit=DEATH)
    common.animation(rig, "death", DEATH, poses, space="world")


build()
