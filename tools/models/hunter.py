# -*- coding: utf-8 -*-
"""O Caçador: humanoide low-poly cartunesco, riggado e animado.

Design original da casa: proporções exageradas (ombreiras e mãos grandes,
cabeça marcante), cores chapadas, silhueta legível de longe. O material
"accent" (cachecol e faixa) existe para a Godot recolorir por jogador.

## Rig

Hierarquia profunda o bastante para o corpo contar a história do golpe:

    root ─ spine_01 ─ spine_02 ─ chest ─ neck ─ head
                                   ├─ scarf            (movimento secundário)
                                   ├─ upper_arm_r ─ forearm_r ─ hand_r
                                   └─ upper_arm_l ─ forearm_l ─ hand_l
    root ─ thigh_r ─ shin_r ─ foot_r
         └ thigh_l ─ shin_l ─ foot_l

Toda pose é escrita em EIXOS DO MUNDO (`space="world"`): rx rola para a
esquerda, ry inclina a ponta do osso para a frente, rz gira para a esquerda.
As malhas levam prefixo `m_` para não disputarem nome com os ossos no glTF —
era o que renomeava `hand_r` para `hand_r_2` na importação.

## Animações

Cada Golpe tem a duração EXATA de `src/sim/weapons.gd`, dividida nas mesmas
três fases, e existe um clipe por arma e por índice de Golpe:

    <arma>_light_<n>   <arma>_heavy_<n>

    Espada  light 0.42 / 0.43 / 0.66      heavy 0.84 / 0.76 / 0.96
    Martelo light 0.66 / 0.68 / 0.94      heavy 0.65 / 0.62 / 1.15
    Lâminas light 0.28 / 0.27 / 0.32 / 0.48   heavy — / 0.54

Mudou lá, muda aqui: o corpo conta o tempo exato do Comprometimento, e a
apresentação só procura o clipe pelo nome e busca o tempo do estado.

Clipes de estado: idle, walk, sprint, dodge, hurt, downed, revive, charge
(armar a Rajada), reload (recarga do Martelo, com a batida dentro da janela
do tiro certo) e special_spin (Dança da Ceifadora) e hook (ser puxado).

Rodar:  blender --background --python tools/models/hunter.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common

OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "hunter.glb"
)

# --- Durações espelhadas de src/sim/weapons.gd (windup, active, recovery) ---
SWORD_LIGHT = [(0.12, 0.08, 0.22), (0.11, 0.08, 0.24), (0.16, 0.14, 0.36)]
SWORD_HEAVY = [(0.32, 0.10, 0.42), (0.28, 0.10, 0.38), (0.36, 0.14, 0.46)]
HAMMER_LIGHT = [(0.22, 0.10, 0.34), (0.20, 0.10, 0.38), (0.30, 0.12, 0.52)]
HAMMER_HEAVY = [(0.10, 0.10, 0.45), (0.18, 0.10, 0.34), (0.30, 0.15, 0.70)]
BLADES_LIGHT = [(0.08, 0.06, 0.14), (0.07, 0.06, 0.14), (0.09, 0.07, 0.16), (0.12, 0.10, 0.26)]
BLADES_HEAVY = [None, (0.14, 0.10, 0.30)]  # índice 0 é o Gancho: não é um Golpe.

# De src/sim/sim_config.gd e do Especial das Lâminas em weapons.gd.
DODGE = 0.34       # DODGE_DURATION 0.22 + DODGE_RECOVERY 0.12
HURT = 0.28        # HURT_DURATION
RELOAD = 1.6       # RELOAD_TIME
RELOAD_WINDOW = (0.5, 0.8)  # RELOAD_QUICK_START / RELOAD_QUICK_END
SPIN = 2.5         # blades.special.duration

WALK = 0.86
SPRINT = 0.58

## Pose de prontidão. Todo clipe de Golpe começa e termina aqui, e os clipes
## de locomoção usam isto como viés — sem um repouso comum, trocar de clipe
## daria um estalo de braço a cada combo.
GUARD = {
    "spine_01": (0, 2, -2),
    "spine_02": (0, 3, -5),
    "chest": (0, 3, -9),
    "neck": (0, -2, 3),
    "head": (0, -2, 7),
    # Braço quase baixo, cotovelo dobrado: a lâmina aponta para a frente e
    # para BAIXO. Com o antebraço na horizontal (o que acontece quando os
    # ângulos dos dois ossos somam -90) a arma virava lança apontada.
    "upper_arm_r": (-16, -12, 0),
    "forearm_r": (0, -44, 0),
    "hand_r": (0, 0, 0),
    "upper_arm_l": (16, -10, 0),
    "forearm_l": (0, -40, 0),
    "hand_l": (0, 0, 0),
    "thigh_r": (0, -4, 0),
    "shin_r": (0, 6, 0),
    "foot_r": (0, -2, 0),
    "thigh_l": (0, 5, 0),
    "shin_l": (0, 4, 0),
    "foot_l": (0, -3, 0),
    "root": ((0, 1, 0), (0.0, 0.0, -0.015)),
}


def build() -> None:
    common.reset_scene()

    armor = common.material("hunter_armor", "5a7d9e")
    armor_dark = common.material("hunter_armor_dark", "3c4f63")
    trim = common.material("hunter_trim", "e0a85a")
    skin = common.material("hunter_skin", "efb98c")
    leather = common.material("hunter_leather", "6d5240")
    accent = common.material("accent", "56c8ff")
    eyes = common.material("hunter_eyes", "2b2b33")

    # O Caçador olha para +X. Direita do corpo = -Y, esquerda = +Y.
    bones = {
        "root": ((0.0, 0.0, 0.92), (0.0, 0.0, 1.06), None),
    }
    bones.update(common.chain(
        ["spine_01", "spine_02", "chest", "neck", "head"],
        [(0.0, 0.0, 1.06), (0.0, 0.0, 1.20), (0.0, 0.0, 1.34),
         (0.0, 0.0, 1.48), (0.0, 0.0, 1.56), (0.0, 0.0, 1.82)],
        "root",
    ))
    # O cachecol é um osso próprio, apontando para trás: é o que permite o
    # arrasto defasado em vez de uma faixa colada no peito.
    bones["scarf"] = ((0.0, 0.0, 1.50), (-0.30, 0.0, 1.40), "chest")
    bones.update(common.chain(
        ["upper_arm_r", "forearm_r", "hand_r"],
        [(0.0, -0.40, 1.40), (0.0, -0.44, 1.14), (0.0, -0.46, 0.88), (0.12, -0.46, 0.84)],
        "chest",
    ))
    bones.update(common.chain(
        ["upper_arm_l", "forearm_l", "hand_l"],
        [(0.0, 0.40, 1.40), (0.0, 0.44, 1.14), (0.0, 0.46, 0.88), (0.12, 0.46, 0.84)],
        "chest",
    ))
    bones.update(common.chain(
        ["thigh_r", "shin_r", "foot_r"],
        [(0.0, -0.14, 0.96), (0.0, -0.14, 0.52), (0.0, -0.14, 0.10), (0.20, -0.14, 0.06)],
        "root",
    ))
    bones.update(common.chain(
        ["thigh_l", "shin_l", "foot_l"],
        [(0.0, 0.14, 0.96), (0.0, 0.14, 0.52), (0.0, 0.14, 0.10), (0.20, 0.14, 0.06)],
        "root",
    ))
    rig = common.armature("Hunter", bones)

    # --- Tronco: peças se sobrepõem nas juntas de propósito, sem vão ---
    common.attach(common.box("m_pelvis", (0.36, 0.42, 0.24), (0.0, 0.0, 0.99), leather), rig, "root")
    common.attach(common.box("m_belt", (0.40, 0.46, 0.08), (0.0, 0.0, 1.09), trim), rig, "root")
    common.attach(common.box("m_abdomen", (0.38, 0.46, 0.18), (0.0, 0.0, 1.14), leather), rig, "spine_01")
    common.attach(common.box("m_ribs", (0.41, 0.50, 0.20), (0.0, 0.0, 1.27), armor), rig, "spine_02")
    common.attach(common.box("m_torso", (0.42, 0.52, 0.22), (0.0, 0.0, 1.40), armor), rig, "chest")
    common.attach(common.box("m_chestplate", (0.10, 0.38, 0.34), (0.19, 0.0, 1.33), armor_dark), rig, "spine_02")
    common.attach(common.box("m_neck", (0.22, 0.26, 0.12), (0.0, 0.0, 1.50), skin), rig, "neck")

    # Cachecol: colarinho no osso do cachecol e uma ponta solta atrás, que é
    # o que o arrasto defasado faz esvoaçar.
    common.attach(
        common.join([
            common.box("m_scarf_collar", (0.44, 0.48, 0.12), (0.0, 0.0, 1.52), accent),
            common.box("m_scarf_tail", (0.26, 0.20, 0.09), (-0.22, 0.0, 1.44), accent),
        ], "m_scarf"),
        rig, "scarf",
    )

    # Ombreiras grandes: a silhueta cartunesca mora aqui.
    common.attach(
        common.sphere("m_pad_r", 0.19, (0.0, -0.34, 1.44), armor_dark, subdivisions=1, squash=(1.0, 1.0, 0.8)),
        rig, "chest",
    )
    common.attach(
        common.sphere("m_pad_l", 0.19, (0.0, 0.34, 1.44), armor_dark, subdivisions=1, squash=(1.0, 1.0, 0.8)),
        rig, "chest",
    )

    # --- Cabeça ---
    common.attach(common.box("m_head", (0.38, 0.40, 0.36), (0.0, 0.0, 1.70), skin), rig, "head")
    common.attach(common.box("m_hood", (0.34, 0.44, 0.16), (-0.03, 0.0, 1.89), accent), rig, "head")
    common.attach(common.box("m_eye_r", (0.03, 0.06, 0.08), (0.19, -0.10, 1.72), eyes), rig, "head")
    common.attach(common.box("m_eye_l", (0.03, 0.06, 0.08), (0.19, 0.10, 1.72), eyes), rig, "head")

    # --- Braços: antebraços e mãos grandes, juntas cobertas por esferas ---
    for side, sign in (("r", -1.0), ("l", 1.0)):
        common.attach(
            common.sphere("m_shoulder_%s" % side, 0.10, (0.0, sign * 0.40, 1.40), armor, subdivisions=1),
            rig, "upper_arm_%s" % side,
        )
        common.attach(
            common.box("m_upper_arm_%s" % side, (0.15, 0.16, 0.30), (0.0, sign * 0.42, 1.27), armor),
            rig, "upper_arm_%s" % side,
        )
        common.attach(
            common.sphere("m_elbow_%s" % side, 0.09, (0.0, sign * 0.44, 1.14), leather, subdivisions=1),
            rig, "forearm_%s" % side,
        )
        common.attach(
            common.box("m_forearm_%s" % side, (0.18, 0.19, 0.28), (0.0, sign * 0.45, 1.01), leather),
            rig, "forearm_%s" % side,
        )
        common.attach(
            common.sphere("m_hand_%s" % side, 0.13, (0.02, sign * 0.46, 0.85), skin, subdivisions=1),
            rig, "hand_%s" % side,
        )

    # --- Pernas, com joelho e pé próprios ---
    for side, sign in (("r", -1.0), ("l", 1.0)):
        common.attach(
            common.box("m_thigh_%s" % side, (0.20, 0.21, 0.46), (0.0, sign * 0.14, 0.74), armor_dark),
            rig, "thigh_%s" % side,
        )
        common.attach(
            common.sphere("m_knee_%s" % side, 0.10, (0.0, sign * 0.14, 0.52), leather, subdivisions=1),
            rig, "shin_%s" % side,
        )
        common.attach(
            common.box("m_shin_%s" % side, (0.17, 0.18, 0.42), (0.0, sign * 0.14, 0.31), leather),
            rig, "shin_%s" % side,
        )
        common.attach(
            common.box("m_boot_%s" % side, (0.32, 0.19, 0.14), (0.08, sign * 0.14, 0.07), armor_dark),
            rig, "foot_%s" % side,
        )

    _animate(rig)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    common.export_glb(os.path.abspath(OUT))


# --- Ferramentas de pose -------------------------------------------------


def _split(value):
    """Uma entrada de pose é (rx,ry,rz) ou ((rx,ry,rz), (x,y,z))."""
    if len(value) == 2 and isinstance(value[0], (tuple, list)):
        return tuple(value[0]), tuple(value[1])
    return tuple(value), None


def _merge(*layers) -> dict:
    """Empilha dicionários de pose: o último manda."""
    out = {}
    for layer in layers:
        out.update(layer)
    return out


## Quanto da inclinação/torção TOTAL do tronco cabe a cada osso da coluna.
## Os ângulos se somam ao descer a hierarquia, então um "30" escrito em cada
## um dos quatro ossos vira 120 na ponta — foi o que dobrou o Caçador ao meio
## na primeira passada. Escreve-se o total e esta tabela reparte.
SPINE_SHARE = {"root": 0.10, "spine_01": 0.18, "spine_02": 0.26, "chest": 0.46}


def _torso(pitch: float, yaw: float = 0.0, loc=None, head: float = 0.55) -> dict:
    """Pose de tronco a partir dos ângulos TOTAIS do peito.

    `pitch` positivo joga o peito para a frente, `yaw` positivo gira para a
    esquerda. `loc` é o deslocamento da raiz em metros de mundo. `head` diz
    quanto do total a cabeça acompanha: 0,55 deixa o olhar subir enquanto o
    corpo mergulha, que é o que mantém o Behemoth na leitura do jogador.
    """
    pose = {}
    for bone, factor in SPINE_SHARE.items():
        pose[bone] = (0.0, pitch * factor, yaw * factor)
    if loc is not None:
        pose["root"] = ((0.0, pitch * SPINE_SHARE["root"], yaw * SPINE_SHARE["root"]), loc)
    rest = 1.0 - head
    pose["neck"] = (0.0, -pitch * rest * 0.4, -yaw * rest * 0.4)
    pose["head"] = (0.0, -pitch * rest * 0.6, -yaw * rest * 0.6)
    return pose


def _strike(rig, name: str, phases, wind: dict, hit: dict,
            rest: dict = None, amount: float = 0.22, at: float = 0.38) -> None:
    """Monta um Golpe: antecipação → impacto → recuperação, nos tempos da Sim.

    `phases` é (windup, active, recovery) copiado de weapons.gd. O corpo sai
    do repouso devagar (curva de entrada), estoura no quadro de contato
    (curva de saída seca) e volta passando um pouco do ponto, via
    `common.settle` — é esse exagero de volta que tira o cheiro de boneco
    de armar.

    O cachecol é gerado sozinho, como arrasto defasado do peito.
    """
    windup, active, recovery = phases
    total = windup + active + recovery
    rest = rest if rest is not None else GUARD

    # Preparo longo pede antecipação mais marcada; preparo curto, estalo.
    wind_ease = "accel" if windup >= 0.18 else "wind"
    hit_ease = "hit" if windup >= 0.18 else "snap"

    poses = {}
    for bone in set(rest) | set(wind) | set(hit):
        base, base_loc = _split(rest.get(bone, (0, 0, 0)))
        w_rot, w_loc = _split(wind.get(bone, rest.get(bone, (0, 0, 0))))
        h_rot, h_loc = _split(hit.get(bone, wind.get(bone, rest.get(bone, (0, 0, 0)))))
        keys = [
            (0.0, base, base_loc, wind_ease),
            (windup, w_rot, w_loc, hit_ease),
            (windup + active, h_rot, h_loc, "ease"),
        ]
        tail = common.settle(windup + active, h_rot, total, rest=base, amount=amount, at=at)
        if h_loc is not None or base_loc is not None:
            end_loc = base_loc if base_loc is not None else (0.0, 0.0, 0.0)
            peak_loc = h_loc if h_loc is not None else end_loc
            over_loc = tuple(end_loc[i] + (peak_loc[i] - end_loc[i]) * 0.35 for i in range(3))
            tail = [
                (tail[0][0], tail[0][1], over_loc, tail[0][3]),
                (tail[1][0], tail[1][1], end_loc, tail[1][3]),
            ]
        poses[bone] = keys + tail

    poses["scarf"] = common.follow(poses["chest"], delay=0.05, damping=-0.5, limit=total)
    common.animation(rig, name, total, poses, space="world")


def _animate(rig) -> None:
    _locomotion(rig)
    _states(rig)
    _sword(rig)
    _hammer(rig)
    _blades(rig)


# --- Locomoção -----------------------------------------------------------


def _locomotion(rig) -> None:
    """Repouso, caminhada e corrida gerados aqui — não na apresentação.

    Os ciclos vêm de `common.cycle`, que amostra uma senoide: coxa e braço
    oscilam uma vez por ciclo, joelho só na fase de balanço (meia onda
    retificada) e a raiz sobe e desce DUAS vezes, uma por passada. É o que
    faz o passo "pisar" em vez de deslizar.
    """
    # Repouso: respiração lenta, peso balançando de um pé ao outro.
    idle = 2.4
    poses = {
        "root": common.cycle(idle, amplitude=(1.2, 0, 1.6), bias=(0, 1, 0),
                             loc_amplitude=(0.0, 0.012, 0.012),
                             loc_bias=(0.0, 0.0, -0.015), samples=8),
        "spine_01": common.cycle(idle, amplitude=(0, 1.4, 0), bias=(0, 2, -2), samples=8),
        "spine_02": common.cycle(idle, amplitude=(0, 1.8, 1.2), bias=(0, 3, -5), samples=8),
        "chest": common.cycle(idle, amplitude=(0, 2.2, 1.6), bias=(0, 3, -9), samples=8),
        "neck": common.cycle(idle, amplitude=(0, -1.4, 0), bias=(0, -2, 3), samples=8),
        "head": common.cycle(idle, amplitude=(0, -1.6, 2.2), bias=(0, -2, 7), samples=8),
        "upper_arm_r": common.cycle(idle, amplitude=(2.0, 2.4, 0), bias=(-16, -12, 0), samples=8),
        "forearm_r": common.cycle(idle, amplitude=(0, -2.0, 0), bias=(0, -44, 0), samples=8),
        "upper_arm_l": common.cycle(idle, amplitude=(-2.0, 2.4, 0), bias=(16, -10, 0), samples=8),
        "forearm_l": common.cycle(idle, amplitude=(0, -2.0, 0), bias=(0, -40, 0), samples=8),
    }
    for bone in ("thigh_r", "shin_r", "foot_r", "thigh_l", "shin_l", "foot_l"):
        rot, _ = _split(GUARD[bone])
        poses[bone] = [(0.0, rot, None, "ease"), (idle, rot, None, "ease")]
    poses["scarf"] = common.follow(poses["chest"], delay=0.12, damping=-0.8, limit=idle)
    common.animation(rig, "idle", idle, poses, space="world")

    # `lean` e `twist` são os ângulos TOTAIS do peito; `_gait` os reparte.
    _gait(rig, "walk", WALK, stride=24.0, knee=44.0, arm=17.0, lift=-14.0, carry=-34.0,
          lean=8.0, bob=0.030, sway=0.018, twist=12.0, ankle=14.0)
    _gait(rig, "sprint", SPRINT, stride=44.0, knee=74.0, arm=34.0, lift=-36.0, carry=-56.0,
          lean=24.0, bob=0.055, sway=0.012, twist=22.0, ankle=24.0)


def _gait(rig, name, duration, stride, knee, arm, lift, carry, lean, bob, sway, twist, ankle) -> None:
    """Um ciclo de passo completo: dois contatos, dois balanços.

    Fase 0 = contato do pé direito (coxa direita à frente). A coxa vai à
    frente com ry NEGATIVO: o osso aponta para baixo, e inclinar a ponta
    para a frente é inclinar o pé para trás.
    """
    share = SPINE_SHARE
    poses = {
        # A raiz sobe e desce duas vezes (harmonic=2) e balança de lado uma.
        "root": common.cycle(duration, amplitude=(0, 0, -twist * share["root"]),
                             bias=(0, lean * share["root"], 0),
                             loc_amplitude=(0.0, 0.0, bob), loc_bias=(0.0, 0.0, -bob * 0.5),
                             harmonic=2, phase=0.25, samples=8),
        "spine_01": common.cycle(duration, amplitude=(0, 0, -twist * share["spine_01"]),
                                 bias=(0, lean * share["spine_01"], -1), samples=8),
        "spine_02": common.cycle(duration, amplitude=(0, 0, -twist * share["spine_02"]),
                                 bias=(0, lean * share["spine_02"], -2), samples=8),
        "chest": common.cycle(duration, amplitude=(0, 0, -twist * share["chest"]),
                              bias=(0, lean * share["chest"], -4), samples=8),
        # Cabeça e pescoço desfazem parte do giro: o olhar fica no alvo.
        "neck": common.cycle(duration, amplitude=(0, 0, twist * 0.22), bias=(0, -lean * 0.18, 2), samples=8),
        "head": common.cycle(duration, amplitude=(0, 0, twist * 0.33), bias=(0, -lean * 0.27, 4), samples=8),
        # Pernas. phase 0.25 = pico positivo no começo do ciclo.
        "thigh_r": common.cycle(duration, amplitude=(0, -stride, 0), phase=0.25, samples=8),
        "thigh_l": common.cycle(duration, amplitude=(0, -stride, 0), phase=0.75, samples=8),
        # Joelho: só dobra na fase de balanço, logo depois do pé sair do chão.
        "shin_r": common.cycle(duration, amplitude=(0, knee, 0), bias=(0, 4, 0),
                               phase=-0.33, rectify=True, samples=8),
        "shin_l": common.cycle(duration, amplitude=(0, knee, 0), bias=(0, 4, 0),
                               phase=0.17, rectify=True, samples=8),
        # Tornozelo: ponta para baixo na impulsão, levantada ao receber o chão.
        "foot_r": common.cycle(duration, amplitude=(0, ankle, 0), bias=(0, -4, 0), phase=0.75, samples=8),
        "foot_l": common.cycle(duration, amplitude=(0, ankle, 0), bias=(0, -4, 0), phase=0.25, samples=8),
        # Braços em contratempo com as pernas do mesmo lado.
        "upper_arm_r": common.cycle(duration, amplitude=(0, arm, 0), bias=(-10, lift, 0), phase=0.25, samples=8),
        "upper_arm_l": common.cycle(duration, amplitude=(0, arm, 0), bias=(10, lift + 2.0, 0), phase=0.75, samples=8),
        "forearm_r": common.cycle(duration, amplitude=(0, carry * 0.12, 0), bias=(0, carry, 0), phase=0.25, samples=8),
        "forearm_l": common.cycle(duration, amplitude=(0, carry * 0.12, 0), bias=(0, carry + 4.0, 0), phase=0.75, samples=8),
    }
    poses["root"] = _side_sway(poses["root"], sway)
    poses["scarf"] = common.follow(poses["chest"], delay=duration * 0.12, damping=-0.75, limit=duration)
    common.animation(rig, name, duration, poses, space="world")


def _side_sway(keys, amount):
    """Acrescenta o gingado lateral à raiz, que é UMA vez por ciclo.

    A subida/descida já vem com o dobro da frequência; somar as duas ondas
    aqui é mais barato que misturar duas trilhas.
    """
    count = len(keys) - 1
    out = []
    for index, key in enumerate(keys):
        wave = math.sin(math.tau * index / count)
        loc = key[2] or (0.0, 0.0, 0.0)
        out.append((key[0], (key[1][0] + wave * 3.0, key[1][1], key[1][2]),
                    (loc[0], loc[1] + wave * amount, loc[2]), key[3]))
    return out


# --- Estados -------------------------------------------------------------


def _states(rig) -> None:
    rest_rot = {bone: _split(GUARD[bone])[0] for bone in GUARD}
    rest_root = _split(GUARD["root"])[1]

    # Rolamento: mergulho para a frente com o corpo encolhido. O impulso
    # dura 0.22 s (DODGE_DURATION) e a recuperação devolve a prontidão.
    # A direção do rolamento é girada pela HunterView; o clipe é sempre
    # para a frente, o que deixa o corpo encolhido legível de qualquer lado.
    common.animation(rig, "dodge", DODGE, {
        "root": [
            (0.0, (0, 10, 0), (0.0, 0.0, -0.06), "accel"),
            (0.05, (0, 70, 0), (0.10, 0.0, -0.18), "linear"),
            (0.11, (0, 185, 0), (0.0, 0.0, -0.32), "linear"),
            (0.17, (0, 300, 0), (-0.06, 0.0, -0.18), "snap"),
            (0.22, (0, 360, 0), (0.0, 0.0, -0.04), "settle"),
            (DODGE, (0, 360, 0), rest_root, "settle"),
        ],
        # Encolhimento: os ângulos da coluna se somam, então o tronco só
        # precisa de uns 36° a mais que a raiz para o corpo virar bola.
        "spine_02": [(0.0, (0, 8, 0), None, "wind"), (0.11, (0, 14, 0), None, "ease"),
                     (0.22, (0, -6, 0), None, "settle"), (DODGE, rest_rot["spine_02"], None, "settle")],
        "chest": [(0.0, (0, 12, -4), None, "wind"), (0.11, (0, 22, 0), None, "ease"),
                  (0.22, (0, -8, -4), None, "settle"), (DODGE, rest_rot["chest"], None, "settle")],
        "head": [(0.0, (0, 10, 0), None, "wind"), (0.11, (0, 20, 0), None, "ease"),
                 (DODGE, rest_rot["head"], None, "settle")],
        "thigh_r": [(0.0, (0, -30, 0), None, "wind"), (0.11, (0, -86, 0), None, "ease"),
                    (0.22, (0, -18, 0), None, "settle"), (DODGE, rest_rot["thigh_r"], None, "settle")],
        "thigh_l": [(0.0, (0, -26, 0), None, "wind"), (0.11, (0, -80, 0), None, "ease"),
                    (0.22, (0, 10, 0), None, "settle"), (DODGE, rest_rot["thigh_l"], None, "settle")],
        "shin_r": [(0.0, (0, 40, 0), None, "wind"), (0.11, (0, 104, 0), None, "ease"),
                   (DODGE, rest_rot["shin_r"], None, "settle")],
        "shin_l": [(0.0, (0, 36, 0), None, "wind"), (0.11, (0, 100, 0), None, "ease"),
                   (DODGE, rest_rot["shin_l"], None, "settle")],
        "upper_arm_r": [(0.0, (-20, -50, 0), None, "wind"), (0.11, (-30, -120, 0), None, "ease"),
                        (DODGE, rest_rot["upper_arm_r"], None, "settle")],
        "upper_arm_l": [(0.0, (20, -42, 0), None, "wind"), (0.11, (30, -112, 0), None, "ease"),
                        (DODGE, rest_rot["upper_arm_l"], None, "settle")],
        "forearm_r": [(0.0, (0, -70, 0), None, "wind"), (0.11, (0, -96, 0), None, "ease"),
                      (DODGE, rest_rot["forearm_r"], None, "settle")],
        "forearm_l": [(0.0, (0, -66, 0), None, "wind"), (0.11, (0, -92, 0), None, "ease"),
                      (DODGE, rest_rot["forearm_l"], None, "settle")],
        "scarf": [(0.0, (0, 0, 0), None, "wind"), (0.09, (0, -46, 0), None, "ease"),
                  (0.26, (0, 16, 0), None, "settle"), (DODGE, (0, 0, 0), None, "settle")],
    }, space="world")

    # Tranco: o golpe empurra o tronco para trás e o corpo se recompõe.
    common.animation(rig, "hurt", HURT, {
        "root": [(0.0, (0, 1, 0), rest_root, "snap"), (0.07, (0, -14, 0), (-0.09, 0.0, -0.05), "ease"),
                 (0.16, (0, 4, 0), (-0.02, 0.0, -0.02), "settle"), (HURT, (0, 1, 0), rest_root, "settle")],
        "spine_02": [(0.0, rest_rot["spine_02"], None, "snap"), (0.07, (3, -10, -6), None, "ease"),
                     (HURT, rest_rot["spine_02"], None, "settle")],
        "chest": [(0.0, rest_rot["chest"], None, "snap"), (0.07, (5, -16, -10), None, "ease"),
                  (0.17, (0, 6, -7), None, "settle"), (HURT, rest_rot["chest"], None, "settle")],
        "head": [(0.0, rest_rot["head"], None, "snap"), (0.07, (0, -16, 10), None, "ease"),
                 (HURT, rest_rot["head"], None, "settle")],
        "upper_arm_r": [(0.0, rest_rot["upper_arm_r"], None, "snap"), (0.07, (-34, -14, 0), None, "ease"),
                        (HURT, rest_rot["upper_arm_r"], None, "settle")],
        "upper_arm_l": [(0.0, rest_rot["upper_arm_l"], None, "snap"), (0.07, (34, -10, 0), None, "ease"),
                        (HURT, rest_rot["upper_arm_l"], None, "settle")],
        "thigh_r": [(0.0, rest_rot["thigh_r"], None, "snap"), (0.07, (0, -22, 0), None, "ease"),
                    (HURT, rest_rot["thigh_r"], None, "settle")],
        "thigh_l": [(0.0, rest_rot["thigh_l"], None, "snap"), (0.07, (0, 20, 0), None, "ease"),
                    (HURT, rest_rot["thigh_l"], None, "settle")],
        "scarf": [(0.0, (0, 0, 0), None, "snap"), (0.10, (0, 34, 0), None, "ease"),
                  (HURT, (0, 0, 0), None, "settle")],
    }, space="world")

    # Abatido: de costas no chão, respirando. Loop parado.
    down_rot = (0, -84, 0)
    down_loc = (-0.12, 0.0, -0.80)
    common.animation(rig, "downed", 2.0, {
        "root": [(0.0, down_rot, down_loc, "ease"), (1.0, (0, -86, 0), (-0.12, 0.0, -0.78), "ease"),
                 (2.0, down_rot, down_loc, "ease")],
        "spine_02": [(0.0, (0, 5, 0), None, "ease"), (1.0, (0, 9, 0), None, "ease"), (2.0, (0, 5, 0), None, "ease")],
        "chest": [(0.0, (0, 8, 0), None, "ease"), (1.0, (0, 13, 0), None, "ease"), (2.0, (0, 8, 0), None, "ease")],
        "head": [(0.0, (0, 20, 0), None, "ease"), (1.0, (0, 15, 6), None, "ease"), (2.0, (0, 20, 0), None, "ease")],
        "thigh_r": [(0.0, (0, 30, 0), None, "ease"), (2.0, (0, 30, 0), None, "ease")],
        "thigh_l": [(0.0, (0, 22, 0), None, "ease"), (2.0, (0, 22, 0), None, "ease")],
        "shin_r": [(0.0, (0, 26, 0), None, "ease"), (2.0, (0, 26, 0), None, "ease")],
        "shin_l": [(0.0, (0, 18, 0), None, "ease"), (2.0, (0, 18, 0), None, "ease")],
        "upper_arm_r": [(0.0, (-44, -18, 0), None, "ease"), (2.0, (-44, -18, 0), None, "ease")],
        "upper_arm_l": [(0.0, (44, -14, 0), None, "ease"), (2.0, (44, -14, 0), None, "ease")],
        "forearm_r": [(0.0, (0, -30, 0), None, "ease"), (2.0, (0, -30, 0), None, "ease")],
        "forearm_l": [(0.0, (0, -26, 0), None, "ease"), (2.0, (0, -26, 0), None, "ease")],
    }, space="world")

    # Reviver: do chão ao joelho, do joelho ao pé.
    common.animation(rig, "revive", 1.5, {
        "root": [(0.0, down_rot, down_loc, "wind"), (0.45, (0, -40, 0), (-0.06, 0.0, -0.58), "ease"),
                 (0.85, (0, 16, 0), (0.0, 0.0, -0.40), "ease"),
                 (1.20, (0, 6, 0), (0.0, 0.0, -0.10), "settle"), (1.5, (0, 1, 0), rest_root, "settle")],
        "spine_02": [(0.0, (0, 5, 0), None, "wind"), (0.85, (0, 14, 0), None, "ease"), (1.5, rest_rot["spine_02"], None, "settle")],
        "chest": [(0.0, (0, 8, 0), None, "wind"), (0.85, (0, 22, 0), None, "ease"),
                  (1.20, (0, -6, -9), None, "settle"), (1.5, rest_rot["chest"], None, "settle")],
        "head": [(0.0, (0, 20, 0), None, "wind"), (0.85, (0, -14, 0), None, "ease"), (1.5, rest_rot["head"], None, "settle")],
        "thigh_r": [(0.0, (0, 30, 0), None, "wind"), (0.85, (0, -74, 0), None, "ease"), (1.5, rest_rot["thigh_r"], None, "settle")],
        "shin_r": [(0.0, (0, 26, 0), None, "wind"), (0.85, (0, 86, 0), None, "ease"), (1.5, rest_rot["shin_r"], None, "settle")],
        "thigh_l": [(0.0, (0, 22, 0), None, "wind"), (0.85, (0, 24, 0), None, "ease"), (1.5, rest_rot["thigh_l"], None, "settle")],
        "shin_l": [(0.0, (0, 18, 0), None, "wind"), (0.85, (0, 40, 0), None, "ease"), (1.5, rest_rot["shin_l"], None, "settle")],
        "upper_arm_r": [(0.0, (-44, -18, 0), None, "wind"), (0.85, (-20, -44, 0), None, "ease"), (1.5, rest_rot["upper_arm_r"], None, "settle")],
        "upper_arm_l": [(0.0, (44, -14, 0), None, "wind"), (0.85, (20, -36, 0), None, "ease"), (1.5, rest_rot["upper_arm_l"], None, "settle")],
        "forearm_r": [(0.0, (0, -30, 0), None, "wind"), (1.5, rest_rot["forearm_r"], None, "settle")],
        "forearm_l": [(0.0, (0, -26, 0), None, "wind"), (1.5, rest_rot["forearm_l"], None, "settle")],
    }, space="world")

    # Armar a Rajada Concussiva: martelo erguido à frente, tremendo. Loop.
    common.animation(rig, "charge", 1.0, {
        "root": [(0.0, (0, -4, 0), (-0.04, 0.0, -0.05), "ease"), (0.25, (0, -5, 0), (-0.04, 0.0, -0.04), "ease"),
                 (0.5, (0, -4, 0), (-0.05, 0.0, -0.05), "ease"), (0.75, (0, -5, 0), (-0.04, 0.0, -0.04), "ease"),
                 (1.0, (0, -4, 0), (-0.04, 0.0, -0.05), "ease")],
        "spine_02": [(0.0, (0, -8, -6), None, "ease"), (0.5, (0, -10, -4), None, "ease"), (1.0, (0, -8, -6), None, "ease")],
        "chest": [(0.0, (0, -12, -8), None, "ease"), (0.5, (0, -15, -6), None, "ease"), (1.0, (0, -12, -8), None, "ease")],
        "head": [(0.0, (0, 6, 6), None, "ease"), (0.5, (0, 8, 4), None, "ease"), (1.0, (0, 6, 6), None, "ease")],
        "upper_arm_r": [(0.0, (-16, -126, 0), None, "ease"), (0.25, (-19, -132, 0), None, "ease"),
                        (0.5, (-16, -128, 0), None, "ease"), (0.75, (-19, -131, 0), None, "ease"),
                        (1.0, (-16, -126, 0), None, "ease")],
        "upper_arm_l": [(0.0, (22, -118, 0), None, "ease"), (0.25, (25, -124, 0), None, "ease"),
                        (0.5, (22, -120, 0), None, "ease"), (0.75, (25, -123, 0), None, "ease"),
                        (1.0, (22, -118, 0), None, "ease")],
        "forearm_r": [(0.0, (0, -46, 0), None, "ease"), (0.5, (0, -52, 0), None, "ease"), (1.0, (0, -46, 0), None, "ease")],
        "forearm_l": [(0.0, (0, -42, 0), None, "ease"), (0.5, (0, -48, 0), None, "ease"), (1.0, (0, -42, 0), None, "ease")],
        "thigh_r": [(0.0, (0, -16, 0), None, "ease"), (1.0, (0, -16, 0), None, "ease")],
        "thigh_l": [(0.0, (0, 18, 0), None, "ease"), (1.0, (0, 18, 0), None, "ease")],
        "shin_r": [(0.0, (0, 20, 0), None, "ease"), (1.0, (0, 20, 0), None, "ease")],
        "shin_l": [(0.0, (0, 16, 0), None, "ease"), (1.0, (0, 16, 0), None, "ease")],
    }, space="world")

    # Recarga do Martelo (RELOAD_TIME). A BATIDA da munição cai dentro da
    # janela do tiro certo (RELOAD_QUICK_START..END): a leitura do ritmo é a
    # própria animação, não só a barra do HUD.
    slam = (RELOAD_WINDOW[0] + RELOAD_WINDOW[1]) * 0.5
    common.animation(rig, "reload", RELOAD, {
        "root": [(0.0, (0, 1, 0), rest_root, "wind"), (slam, (0, -6, 0), (0.0, 0.0, -0.05), "snap"),
                 (slam + 0.12, (0, 4, 0), (0.0, 0.0, -0.01), "settle"), (RELOAD, (0, 1, 0), rest_root, "settle")],
        "spine_02": [(0.0, (0, 3, -5), None, "wind"), (0.32, (0, 10, -12), None, "ease"),
                     (slam, (0, -4, -2), None, "snap"), (RELOAD, (0, 3, -5), None, "settle")],
        "chest": [(0.0, (0, 3, -9), None, "wind"), (0.32, (0, 13, -20), None, "ease"),
                  (slam, (0, -6, -4), None, "snap"), (slam + 0.2, (0, 5, -12), None, "ease"),
                  (RELOAD, (0, 3, -9), None, "settle")],
        "head": [(0.0, (0, -2, 7), None, "wind"), (0.32, (0, 16, 12), None, "ease"),
                 (slam, (0, 6, 8), None, "snap"), (RELOAD, (0, -2, 7), None, "settle")],
        # Braço esquerdo: desce ao cinto, pega a munição, enfia no cano.
        "upper_arm_l": [(0.0, (14, -24, 0), None, "wind"), (0.32, (34, 26, 0), None, "ease"),
                        (RELOAD_WINDOW[0], (26, -20, 0), None, "accel"),
                        (slam, (16, -74, 0), None, "snap"), (slam + 0.18, (18, -58, 0), None, "ease"),
                        (RELOAD, (14, -24, 0), None, "settle")],
        "forearm_l": [(0.0, (0, -52, 0), None, "wind"), (0.32, (0, -16, 0), None, "ease"),
                      (slam, (0, -84, 0), None, "snap"), (RELOAD, (0, -52, 0), None, "settle")],
        # O direito segura a arma e absorve o coice da batida.
        "upper_arm_r": [(0.0, (-14, -32, 0), None, "wind"), (0.32, (-18, -58, 0), None, "ease"),
                        (slam, (-14, -44, 0), None, "snap"), (slam + 0.18, (-16, -62, 0), None, "ease"),
                        (RELOAD, (-14, -32, 0), None, "settle")],
        "forearm_r": [(0.0, (0, -58, 0), None, "wind"), (0.32, (0, -76, 0), None, "ease"),
                      (slam, (0, -62, 0), None, "snap"), (RELOAD, (0, -58, 0), None, "settle")],
        "thigh_r": [(0.0, (0, -4, 0), None, "ease"), (slam, (0, -12, 0), None, "ease"), (RELOAD, (0, -4, 0), None, "settle")],
        "thigh_l": [(0.0, (0, 5, 0), None, "ease"), (slam, (0, 13, 0), None, "ease"), (RELOAD, (0, 5, 0), None, "settle")],
        "shin_r": [(0.0, (0, 6, 0), None, "ease"), (slam, (0, 16, 0), None, "ease"), (RELOAD, (0, 6, 0), None, "settle")],
        "shin_l": [(0.0, (0, 4, 0), None, "ease"), (slam, (0, 14, 0), None, "ease"), (RELOAD, (0, 4, 0), None, "settle")],
    }, space="world")

    _special_spin(rig)
    _hook(rig)


def _special_spin(rig) -> None:
    """Dança da Ceifadora: o Caçador gira e corta tudo em volta por 2,5 s.

    O giro é escrito em passos de 90° porque o conversor de eixos resolve
    cada chave pela anterior: passos maiores que meia volta ficariam
    ambíguos e a volta andaria para trás.
    """
    turns = 3.5
    steps = int(turns * 4)
    step_time = SPIN / steps
    root = [(0.0, (0, 6, 0), (0.0, 0.0, -0.05), "accel")]
    for index in range(1, steps + 1):
        angle = 360.0 * turns * index / steps
        ease = "settle" if index == steps else "linear"
        drop = -0.05 if index == steps else -0.09
        root.append((step_time * index, (0, 4, angle), (0.0, 0.0, drop), ease))
    root.append((SPIN, (0, 1, 360.0 * turns), (0.0, 0.0, -0.015), "settle"))

    held = {
        "spine_02": (0, 6, 0), "chest": (0, 8, 0), "head": (0, -6, 0),
        "upper_arm_r": (-82, -78, 0), "forearm_r": (0, -16, 0),
        "upper_arm_l": (82, -74, 0), "forearm_l": (0, -14, 0),
        "thigh_r": (0, -12, 0), "thigh_l": (0, 10, 0),
        "shin_r": (0, 18, 0), "shin_l": (0, 14, 0),
    }
    poses = {"root": root}
    for bone, pose in held.items():
        rest = _split(GUARD[bone])[0]
        poses[bone] = [
            (0.0, rest, None, "accel"),
            (0.18, pose, None, "ease"),
            (SPIN - 0.25, pose, None, "ease"),
            (SPIN, rest, None, "settle"),
        ]
    poses["scarf"] = [(0.0, (0, 0, 0), None, "accel"), (0.18, (0, -34, 22), None, "ease"),
                      (SPIN - 0.25, (0, -30, 26), None, "ease"), (SPIN, (0, 0, 0), None, "settle")]
    common.animation(rig, "special_spin", SPIN, poses, space="world")


def _hook(rig) -> None:
    """Ser puxado pelo Gancho: corrente esticada à frente, corpo rebocado.

    Dura o que a Sim quiser (a distância manda), então é um laço curto: o
    braço fica estendido e o corpo oscila como quem é arrastado.
    """
    duration = 0.5
    common.animation(rig, "hook", duration, {
        "root": [(0.0, (0, 22, 0), (0.06, 0.0, -0.08), "ease"),
                 (0.25, (0, 26, 0), (0.06, 0.0, -0.05), "ease"),
                 (duration, (0, 22, 0), (0.06, 0.0, -0.08), "ease")],
        "spine_02": [(0.0, (0, 10, 0), None, "ease"), (0.25, (0, 6, 0), None, "ease"), (duration, (0, 10, 0), None, "ease")],
        "chest": [(0.0, (0, 14, -6), None, "ease"), (0.25, (0, 9, -4), None, "ease"), (duration, (0, 14, -6), None, "ease")],
        "head": [(0.0, (0, -18, 4), None, "ease"), (duration, (0, -18, 4), None, "ease")],
        "upper_arm_r": [(0.0, (-6, -148, 0), None, "ease"), (0.25, (-9, -154, 0), None, "ease"), (duration, (-6, -148, 0), None, "ease")],
        "forearm_r": [(0.0, (0, -10, 0), None, "ease"), (duration, (0, -10, 0), None, "ease")],
        "upper_arm_l": [(0.0, (26, -92, 0), None, "ease"), (0.25, (22, -84, 0), None, "ease"), (duration, (26, -92, 0), None, "ease")],
        "forearm_l": [(0.0, (0, -64, 0), None, "ease"), (duration, (0, -64, 0), None, "ease")],
        "thigh_r": [(0.0, (0, 34, 0), None, "ease"), (0.25, (0, 22, 0), None, "ease"), (duration, (0, 34, 0), None, "ease")],
        "thigh_l": [(0.0, (0, 26, 0), None, "ease"), (0.25, (0, 38, 0), None, "ease"), (duration, (0, 26, 0), None, "ease")],
        "shin_r": [(0.0, (0, 30, 0), None, "ease"), (0.25, (0, 46, 0), None, "ease"), (duration, (0, 30, 0), None, "ease")],
        "shin_l": [(0.0, (0, 40, 0), None, "ease"), (0.25, (0, 26, 0), None, "ease"), (duration, (0, 40, 0), None, "ease")],
        "scarf": [(0.0, (0, -52, 6), None, "ease"), (0.25, (0, -44, -6), None, "ease"), (duration, (0, -52, 6), None, "ease")],
    }, space="world")


# --- Espada --------------------------------------------------------------


def _sword(rig) -> None:
    """Espada: arco rápido e limpo, corpo girando com o golpe.

    Referência de comportamento (não de asset): o combo leve da espada
    pré-Awakening é uma série de cortes largos alternando o lado, e o pesado
    é o machadinho vertical que compromete o corpo. Fontes no ANIMACAO.md.
    """
    # Corte Horizontal: cocar sobre o ombro direito, varrer para a esquerda.
    _strike(rig, "sword_light_1", SWORD_LIGHT[0],
            wind=_merge(_torso(-4, -42, (-0.03, 0.0, -0.02)), {
                "upper_arm_r": (-52, -74, 0), "forearm_r": (0, -40, 0),
                "upper_arm_l": (26, -36, 0), "forearm_l": (0, -46, 0),
            }),
            hit=_merge(_torso(8, 46, (0.05, 0.0, -0.02)), {
                "upper_arm_r": (58, -72, 0), "forearm_r": (0, -8, 0),
                "upper_arm_l": (6, -20, 0), "forearm_l": (0, -34, 0),
            }))

    # Corte Ascendente: a lâmina desce ao lado do quadril e sobe em diagonal.
    _strike(rig, "sword_light_2", SWORD_LIGHT[1],
            wind=_merge(_torso(26, 18, (-0.02, 0.0, -0.05)), {
                "upper_arm_r": (-26, 34, 0), "forearm_r": (0, -30, 0),
                "upper_arm_l": (18, 8, 0), "forearm_l": (0, -40, 0),
            }),
            hit=_merge(_torso(-22, -16, (0.04, 0.0, 0.03)), {
                "upper_arm_r": (34, -148, 0), "forearm_r": (0, -20, 0),
                "upper_arm_l": (10, -56, 0), "forearm_l": (0, -40, 0),
            }))

    # Giro Cortante: volta inteira, o arco é a tela toda. O giro precisa de
    # chaves próprias (passos de meia volta), então não passa pelo _strike.
    _spin_strike(rig, "sword_light_3", SWORD_LIGHT[2], turns=1.0,
                 arms={"upper_arm_r": (-74, -86, 0), "forearm_r": (0, -20, 0),
                       "upper_arm_l": (40, -40, 0), "forearm_l": (0, -62, 0)})

    # Corte Pesado: arma ao alto, peso no pé de trás, desce com tudo.
    _strike(rig, "sword_heavy_1", SWORD_HEAVY[0],
            wind=_merge(_torso(-30, 8, (-0.07, 0.0, 0.02)), {
                "upper_arm_r": (-10, -168, 0), "forearm_r": (0, -40, 0),
                "upper_arm_l": (10, -154, 0), "forearm_l": (0, -36, 0),
                "thigh_r": (0, 18, 0), "thigh_l": (0, -14, 0), "shin_r": (0, 26, 0),
            }),
            hit=_merge(_torso(44, -6, (0.09, 0.0, -0.08)), {
                "upper_arm_r": (-6, 20, 0), "forearm_r": (0, -4, 0),
                "upper_arm_l": (6, 14, 0), "forearm_l": (0, -6, 0),
                "thigh_r": (0, -16, 0), "thigh_l": (0, 20, 0), "shin_r": (0, 34, 0),
            }), amount=0.26)

    # Retorno Pesado: desfaz o arco, varrendo da esquerda para a direita.
    _strike(rig, "sword_heavy_2", SWORD_HEAVY[1],
            wind=_merge(_torso(6, 40, (-0.03, 0.0, -0.03)), {
                "upper_arm_r": (64, -80, 0), "forearm_r": (0, -34, 0),
                "upper_arm_l": (-6, -26, 0), "forearm_l": (0, -40, 0),
            }),
            hit=_merge(_torso(12, -38, (0.05, 0.0, -0.03)), {
                "upper_arm_r": (-74, -66, 0), "forearm_r": (0, -6, 0),
                "upper_arm_l": (30, -30, 0), "forearm_l": (0, -44, 0),
            }))

    # Finalizador Pesado: o mesmo arco vertical, maior, com passada à frente.
    _strike(rig, "sword_heavy_3", SWORD_HEAVY[2],
            wind=_merge(_torso(-38, 12, (-0.10, 0.0, 0.05)), {
                "upper_arm_r": (-12, -180, 0), "forearm_r": (0, -50, 0),
                "upper_arm_l": (12, -166, 0), "forearm_l": (0, -44, 0),
                "thigh_r": (0, 26, 0), "thigh_l": (0, -22, 0), "shin_r": (0, 36, 0),
            }),
            hit=_merge(_torso(54, -8, (0.18, 0.0, -0.12)), {
                "upper_arm_r": (-4, 32, 0), "forearm_r": (0, 0, 0),
                "upper_arm_l": (4, 24, 0), "forearm_l": (0, -2, 0),
                "thigh_r": (0, -30, 0), "thigh_l": (0, 34, 0), "shin_r": (0, 46, 0), "shin_l": (0, 22, 0),
            }), amount=0.3, at=0.3)


def _spin_strike(rig, name, phases, turns, arms) -> None:
    """Golpe giratório: a raiz dá voltas inteiras durante a fase Ativa.

    Passos de meia volta no máximo, pela mesma razão do `special_spin`.
    """
    windup, active, recovery = phases
    total = windup + active + recovery
    steps = max(2, int(turns * 3))
    root = [
        (0.0, (0, 2, 0), (0.0, 0.0, -0.015), "accel"),
        (windup, (0, 6, -55), (-0.02, 0.0, -0.05), "snap"),
    ]
    for index in range(1, steps + 1):
        angle = -55.0 + (360.0 * turns + 55.0) * index / steps
        time = windup + active * index / steps
        root.append((time, (0, 6, angle), (0.0, 0.0, -0.06), "linear"))
    root.append((total, (0, 1, 360.0 * turns), (0.0, 0.0, -0.015), "settle"))

    poses = {"root": root}
    for bone, pose in arms.items():
        rest = _split(GUARD[bone])[0]
        poses[bone] = [
            (0.0, rest, None, "accel"),
            (windup, pose, None, "ease"),
            (windup + active, pose, None, "ease"),
        ] + common.settle(windup + active, pose, total, rest=rest, amount=0.18, at=0.4)
    for bone, pose in _torso(16, 0).items():
        if bone == "root":
            continue
        rest = _split(GUARD[bone])[0]
        poses[bone] = [(0.0, rest, None, "accel"), (windup, pose, None, "ease"),
                       (windup + active, pose, None, "ease")] \
            + common.settle(windup + active, pose, total, rest=rest, amount=0.2, at=0.4)
    poses["scarf"] = [(0.0, (0, 0, 0), None, "accel"), (windup + active * 0.4, (0, -28, 30), None, "ease"),
                      (total, (0, 0, 0), None, "settle")]
    common.animation(rig, name, total, poses, space="world")


# --- Martelo -------------------------------------------------------------


def _hammer(rig) -> None:
    """Martelo: tudo mais lento e mais longe do corpo.

    A referência pré-Awakening descreve o combo do martelo como três
    pancadas seguidas de um Estouro, com a arma sempre voltando ao alto e o
    corpo inteiro atrás do peso. É o Comprometimento que a Sim já cobra com
    preparos de 0,20–0,30 s.
    """
    # Pancada Lateral: giro largo das duas mãos, da direita para a esquerda.
    _strike(rig, "hammer_light_1", HAMMER_LIGHT[0],
            wind=_merge(_torso(-8, -48, (-0.05, 0.0, -0.01)), {
                "upper_arm_r": (-62, -96, 0), "forearm_r": (0, -22, 0),
                "upper_arm_l": (-34, -64, 0), "forearm_l": (0, -20, 0),
                "thigh_r": (0, 12, 0), "thigh_l": (0, -8, 0),
            }),
            hit=_merge(_torso(16, 52, (0.06, 0.0, -0.04)), {
                "upper_arm_r": (62, -82, 0), "forearm_r": (0, -10, 0),
                "upper_arm_l": (40, -58, 0), "forearm_l": (0, -8, 0),
                "thigh_r": (0, -14, 0), "thigh_l": (0, 16, 0),
            }), amount=0.28)

    # Retorno Pesado: o mesmo arco de volta, da esquerda para a direita.
    _strike(rig, "hammer_light_2", HAMMER_LIGHT[1],
            wind=_merge(_torso(-6, 50, (-0.04, 0.0, -0.01)), {
                "upper_arm_r": (56, -92, 0), "forearm_r": (0, -24, 0),
                "upper_arm_l": (40, -70, 0), "forearm_l": (0, -22, 0),
            }),
            hit=_merge(_torso(18, -50, (0.05, 0.0, -0.04)), {
                "upper_arm_r": (-66, -80, 0), "forearm_r": (0, -8, 0),
                "upper_arm_l": (-36, -56, 0), "forearm_l": (0, -6, 0),
            }), amount=0.28)

    # Esmagada: martelo ao alto com as duas mãos, o corpo inteiro desaba.
    _strike(rig, "hammer_light_3", HAMMER_LIGHT[2],
            wind=_merge(_torso(-34, 5, (-0.08, 0.0, 0.06)), {
                "upper_arm_r": (-14, -180, 0), "forearm_r": (0, -44, 0),
                "upper_arm_l": (14, -172, 0), "forearm_l": (0, -40, 0),
                "thigh_r": (0, 22, 0), "thigh_l": (0, -18, 0), "shin_r": (0, 30, 0),
            }),
            hit=_merge(_torso(50, 0, (0.08, 0.0, -0.16)), {
                "upper_arm_r": (-8, 28, 0), "forearm_r": (0, -2, 0),
                "upper_arm_l": (8, 24, 0), "forearm_l": (0, -2, 0),
                "thigh_r": (0, -34, 0), "thigh_l": (0, -28, 0),
                "shin_r": (0, 58, 0), "shin_l": (0, 52, 0),
            }), amount=0.3, at=0.28)

    # Rajada Concussiva: sai da pose de carga. Preparo curtíssimo (0,10 s),
    # o cano aponta e dispara; o coice joga o corpo para trás.
    _strike(rig, "hammer_heavy_1", HAMMER_HEAVY[0],
            rest=_merge(GUARD, _torso(-14, -10, (-0.04, 0.0, -0.05)), {
                "upper_arm_r": (-16, -126, 0), "forearm_r": (0, -46, 0),
                "upper_arm_l": (22, -118, 0), "forearm_l": (0, -42, 0),
            }),
            wind=_merge(_torso(-22, -6, (-0.07, 0.0, -0.04)), {
                "upper_arm_r": (-10, -104, 0), "forearm_r": (0, -28, 0),
                "upper_arm_l": (14, -98, 0), "forearm_l": (0, -26, 0),
            }),
            hit=_merge(_torso(-38, -4, (-0.14, 0.0, -0.06)), {
                "upper_arm_r": (-14, -142, 0), "forearm_r": (0, -50, 0),
                "upper_arm_l": (18, -134, 0), "forearm_l": (0, -46, 0),
                "thigh_r": (0, -20, 0), "thigh_l": (0, 24, 0), "shin_r": (0, 26, 0),
            }), amount=0.18, at=0.3)

    # Coronhada: sem munição, o cabo vira porrete. Estocada curta e seca.
    _strike(rig, "hammer_heavy_2", HAMMER_HEAVY[1],
            wind=_merge(_torso(-16, -20, (-0.05, 0.0, -0.02)), {
                "upper_arm_r": (-30, -18, 0), "forearm_r": (0, -104, 0),
                "upper_arm_l": (16, -40, 0), "forearm_l": (0, -86, 0),
            }),
            hit=_merge(_torso(22, 14, (0.07, 0.0, -0.03)), {
                "upper_arm_r": (-10, -86, 0), "forearm_r": (0, -8, 0),
                "upper_arm_l": (10, -70, 0), "forearm_l": (0, -10, 0),
            }))

    # Estouro Aéter: pulo curto e queda com as duas mãos, a munição toda no
    # chão. A recuperação longa (0,70 s) é a punição por errar.
    _strike(rig, "hammer_heavy_3", HAMMER_HEAVY[2],
            wind=_merge(_torso(-40, 0, (-0.06, 0.0, 0.22)), {
                "upper_arm_r": (-16, -188, 0), "forearm_r": (0, -50, 0),
                "upper_arm_l": (16, -182, 0), "forearm_l": (0, -46, 0),
                "thigh_r": (0, -44, 0), "thigh_l": (0, -40, 0),
                "shin_r": (0, 72, 0), "shin_l": (0, 66, 0),
            }),
            hit=_merge(_torso(58, 0, (0.06, 0.0, -0.24)), {
                "upper_arm_r": (-6, 34, 0), "forearm_r": (0, 2, 0),
                "upper_arm_l": (6, 30, 0), "forearm_l": (0, 2, 0),
                "thigh_r": (0, -46, 0), "thigh_l": (0, -42, 0),
                "shin_r": (0, 78, 0), "shin_l": (0, 74, 0),
            }), amount=0.32, at=0.24)


# --- Lâminas Correntes ---------------------------------------------------


def _blades(rig) -> None:
    """Lâminas: duas mãos, arcos curtos, quase sem recuperação.

    O combo leve pré-Awakening é descrito como a sequência mais rápida do
    jogo, com alcance curtíssimo; é isso que os 0,27–0,32 s por Golpe da Sim
    traduzem. Aqui o corpo mal volta ao repouso entre um e outro: cada clipe
    termina já inclinado para o lado do próximo.
    """
    # Talho Cruzado: direita cruza para dentro, esquerda abre.
    _strike(rig, "blades_light_1", BLADES_LIGHT[0],
            wind=_merge(_torso(8, -24, (-0.02, 0.0, -0.02)), {
                "upper_arm_r": (-58, -64, 0), "forearm_r": (0, -40, 0),
                "upper_arm_l": (46, -40, 0), "forearm_l": (0, -46, 0),
            }),
            hit=_merge(_torso(12, 28, (0.04, 0.0, -0.02)), {
                "upper_arm_r": (54, -70, 0), "forearm_r": (0, -12, 0),
                "upper_arm_l": (-26, -48, 0), "forearm_l": (0, -20, 0),
            }), amount=0.16, at=0.45)

    # Talho Reverso: o espelho do primeiro, mantendo o ritmo do combo.
    _strike(rig, "blades_light_2", BLADES_LIGHT[1],
            wind=_merge(_torso(8, 26, (-0.02, 0.0, -0.02)), {
                "upper_arm_r": (52, -62, 0), "forearm_r": (0, -38, 0),
                "upper_arm_l": (-40, -44, 0), "forearm_l": (0, -44, 0),
            }),
            hit=_merge(_torso(12, -26, (0.04, 0.0, -0.02)), {
                "upper_arm_r": (-56, -68, 0), "forearm_r": (0, -10, 0),
                "upper_arm_l": (34, -50, 0), "forearm_l": (0, -18, 0),
            }), amount=0.16, at=0.45)

    # Tesoura: as duas lâminas abrem e fecham no mesmo quadro.
    _strike(rig, "blades_light_3", BLADES_LIGHT[2],
            wind=_merge(_torso(16, 0, (-0.03, 0.0, -0.04)), {
                "upper_arm_r": (-76, -56, 0), "forearm_r": (0, -36, 0),
                "upper_arm_l": (76, -52, 0), "forearm_l": (0, -34, 0),
            }),
            hit=_merge(_torso(24, 0, (0.05, 0.0, -0.03)), {
                "upper_arm_r": (40, -84, 0), "forearm_r": (0, -8, 0),
                "upper_arm_l": (-40, -80, 0), "forearm_l": (0, -6, 0),
            }), amount=0.2, at=0.4)

    # Redemoinho: fecha o combo com uma volta inteira, as duas lâminas abertas.
    _spin_strike(rig, "blades_light_4", BLADES_LIGHT[3], turns=1.0,
                 arms={"upper_arm_r": (-86, -88, 0), "forearm_r": (0, -12, 0),
                       "upper_arm_l": (86, -86, 0), "forearm_l": (0, -12, 0)})

    # Golpe de Corrente: colado no Behemoth, as duas correntes vêm de cima.
    _strike(rig, "blades_heavy_2", BLADES_HEAVY[1],
            wind=_merge(_torso(-28, 0, (-0.05, 0.0, 0.05)), {
                "upper_arm_r": (-20, -172, 0), "forearm_r": (0, -36, 0),
                "upper_arm_l": (20, -168, 0), "forearm_l": (0, -34, 0),
                "thigh_r": (0, 16, 0), "thigh_l": (0, -14, 0),
            }),
            hit=_merge(_torso(48, 0, (0.07, 0.0, -0.14)), {
                "upper_arm_r": (-8, 26, 0), "forearm_r": (0, -2, 0),
                "upper_arm_l": (8, 22, 0), "forearm_l": (0, -2, 0),
                "thigh_r": (0, -30, 0), "thigh_l": (0, -26, 0),
                "shin_r": (0, 54, 0), "shin_l": (0, 48, 0),
            }), amount=0.28, at=0.3)


build()
