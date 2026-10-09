# -*- coding: utf-8 -*-
"""Utilidades compartilhadas por todos os geradores de modelo.

Todo asset 3D deste projeto nasce de um script: malha, materiais, rig e
animações são construídos aqui dentro do Blender headless e exportados em
.glb para a Godot. Nenhum binário é editado à mão — modelo é código.

Rodar:  blender --background --python tools/models/<modelo>.py

Convenções:
- Unidade: metros na cena do Blender. A Sim usa centímetros no plano de
  chão; a conversão (x100) mora na apresentação da Godot, num lugar só.
- Low-poly com cores chapadas (flat shading), sem textura: o estilo da
  Onda 2 inteira, escolhido porque é o que um gerador por script faz bem.
- Peças rígidas usam `attach` (um osso, peso 1). Peças que precisam dobrar —
  cauda, cachecol — usam `attach_gradient`, que reparte os vértices entre
  dois ossos com transição suave sem sair do pipeline por script.
- Cada animação vira uma trilha NLA com o nome dela; o exportador glTF
  transforma cada trilha numa animação nomeada, que é o que a Godot lê.

Recursos de animação (todos documentados em detalhe junto de cada função):
- **Easing por chave**: o 4º elemento de uma chave escolhe a curva de saída
  daquela chave (antecipação lenta, impacto seco, assentamento macio...).
- **Translação em espaço de mundo**: `space="world"` deixa escrever o
  deslocamento de raiz em metros do mundo, sem pensar no eixo do osso.
- **Movimento secundário barato**: `follow` (defasagem amortecida para
  cachecol/cauda) e `settle` (passar do ponto e assentar no fim do golpe).
- **Ciclos**: `cycle` gera um ciclo senoidal amostrado, para locomoção boa
  sem precisar de código procedural na apresentação.
"""

import math

import bpy
from mathutils import Euler, Vector

FPS = 30


# --- Cena --------------------------------------------------------------


def reset_scene() -> None:
    """Começa do zero: cena vazia, sem câmera, sem luz, fps fixo."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


# --- Materiais ----------------------------------------------------------


def material(name: str, hex_color: str, roughness: float = 0.9) -> bpy.types.Material:
    """Cor chapada. Reusa se já existir, para o .glb ter um material por cor."""
    existing = bpy.data.materials.get(name)
    if existing is not None:
        return existing

    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = _hex_to_rgba(hex_color)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def _hex_to_rgba(hex_color: str):
    value = hex_color.lstrip("#")
    r = int(value[0:2], 16) / 255.0
    g = int(value[2:4], 16) / 255.0
    b = int(value[4:6], 16) / 255.0
    return (r, g, b, 1.0)


# --- Peças de corpo ------------------------------------------------------


def box(
    name: str,
    size,
    location,
    mat: bpy.types.Material,
    rotation=(0.0, 0.0, 0.0),
) -> bpy.types.Object:
    """Um paralelepípedo. `size` é a dimensão total em cada eixo."""
    # O cubo base tem aresta 1.0, então a escala é a dimensão direta. (A
    # primeira versão multiplicava por 0.5 e TODA caixa saía com metade do
    # tamanho pedido — descoberto medindo os vértices no Blender.)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0], size[1], size[2])
    bpy.ops.object.transform_apply(scale=True)
    obj.data.materials.append(mat)
    return obj


def sphere(
    name: str,
    radius: float,
    location,
    mat: bpy.types.Material,
    subdivisions: int = 2,
    squash=(1.0, 1.0, 1.0),
) -> bpy.types.Object:
    """Uma icoesfera low-poly, opcionalmente achatada por eixo."""
    bpy.ops.mesh.primitive_ico_sphere_add(
        radius=radius, subdivisions=subdivisions, location=location
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = squash
    bpy.ops.object.transform_apply(scale=True)
    obj.data.materials.append(mat)
    return obj


def cone(
    name: str,
    radius: float,
    depth: float,
    location,
    mat: bpy.types.Material,
    rotation=(0.0, 0.0, 0.0),
    vertices: int = 8,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius, depth=depth,
        location=location, rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def cylinder(
    name: str,
    radius: float,
    depth: float,
    location,
    mat: bpy.types.Material,
    rotation=(0.0, 0.0, 0.0),
    vertices: int = 8,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth,
        location=location, rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def join(objects: list, name: str) -> bpy.types.Object:
    """Funde várias malhas num objeto só, com o nome dado.

    Serve para peças que a apresentação precisa tratar como uma coisa única —
    a cauda decepável, por exemplo, que a Godot esconde pelo nome do nó.
    """
    with bpy.context.temp_override(
        active_object=objects[0],
        selected_editable_objects=objects,
        selected_objects=objects,
    ):
        bpy.ops.object.join()
    merged = objects[0]
    merged.name = name
    return merged


# --- Rig -----------------------------------------------------------------


def armature(name: str, bones: dict) -> bpy.types.Object:
    """Cria o esqueleto.

    `bones` é {nome: (head, tail, parent_ou_None)}. A ordem do dicionário é
    respeitada, então declare os pais antes dos filhos.

    Hierarquia profunda é suportada sem limite de níveis: o Caçador usa
    raiz → duas vértebras → peito → pescoço → cabeça, e braço → antebraço →
    mão. Use `chain` para declarar uma sequência dessas em uma linha.
    """
    data = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj

    bpy.ops.object.mode_set(mode="EDIT")
    created = {}
    for bone_name, (head, tail, parent) in bones.items():
        bone = data.edit_bones.new(bone_name)
        bone.head = Vector(head)
        bone.tail = Vector(tail)
        if parent is not None:
            bone.parent = created[parent]
        created[bone_name] = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def chain(names: list, points: list, parent) -> dict:
    """Declara uma corrente de ossos ligados ponta a ponta.

    `names` tem N nomes e `points` tem N+1 posições: o osso i vai de
    points[i] a points[i+1] e tem o anterior como pai (o primeiro usa
    `parent`). Devolve um dicionário pronto para somar ao de `armature`.

    É o açúcar que torna barato subdividir uma articulação: trocar
    ["thigh_r", "shin_r"] por ["thigh_r", "shin_r", "foot_r"] é acrescentar
    um nome e um ponto.
    """
    out = {}
    previous = parent
    for index, bone_name in enumerate(names):
        out[bone_name] = (points[index], points[index + 1], previous)
        previous = bone_name
    return out


def attach(obj: bpy.types.Object, rig: bpy.types.Object, bone: str) -> None:
    """Prende a malha inteira a um osso, com peso 1.

    Estilo boneco de armar: a peça segue o osso rigidamente. Sem pesos
    pintados — é o que mantém o pipeline inteiro gerável por script.
    """
    group = obj.vertex_groups.new(name=bone)
    group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    modifier = obj.modifiers.new(name="Armature", type="ARMATURE")
    modifier.object = rig
    obj.parent = rig


def attach_gradient(
    obj: bpy.types.Object,
    rig: bpy.types.Object,
    segments: list,
    axis: int = 0,
    blend: float = 0.25,
) -> None:
    """Prende UMA malha a VÁRIOS ossos, repartindo os vértices por posição.

    `segments` é [(osso, início, fim), ...] em metros de mundo ao longo de
    `axis` (0=X, 1=Y, 2=Z). Cada vértice recebe peso 1 no segmento em que
    cai e a transição entre segmentos vizinhos é suavizada numa faixa de
    `blend` metros, para a peça dobrar em vez de quebrar.

    Por que existe: a cauda do quadrúpede precisa ser UMA malha chamada
    "tail" (a Godot a esconde pelo nome ao decepar a Parte), mas também
    precisa chicotear com defasagem. Um osso só não chicoteia; duas malhas
    quebrariam o contrato com a apresentação. Esta função resolve os dois.
    """
    groups = {name: obj.vertex_groups.new(name=name) for name, _, _ in segments}
    matrix = obj.matrix_world
    for vertex in obj.data.vertices:
        coord = (matrix @ vertex.co)[axis]
        weights = []
        for name, start, end in segments:
            low, high = (start, end) if start <= end else (end, start)
            # Peso 1 dentro do segmento, caindo linearmente na faixa de mistura.
            if low <= coord <= high:
                weight = 1.0
            else:
                distance = low - coord if coord < low else coord - high
                weight = max(0.0, 1.0 - distance / max(blend, 1e-5))
            weights.append((name, weight))
        total = sum(w for _, w in weights)
        if total <= 0.0:
            # Fora de tudo: cai no segmento de centro mais próximo.
            name = min(
                segments,
                key=lambda s: abs(coord - (s[1] + s[2]) * 0.5),
            )[0]
            weights = [(name, 1.0)]
            total = 1.0
        for name, weight in weights:
            if weight > 0.0:
                groups[name].add([vertex.index], weight / total, "REPLACE")

    modifier = obj.modifiers.new(name="Armature", type="ARMATURE")
    modifier.object = rig
    obj.parent = rig


# --- Animação ------------------------------------------------------------

## Vocabulário de interpolação por chave.
##
## A curva escolhida vale para o TRECHO QUE SAI da chave, até a próxima —
## é assim que o Blender guarda interpolação, e é o que permite descrever um
## golpe como "sai devagar (antecipação), chega seco (impacto), relaxa
## (recuperação)" sem desenhar curva nenhuma à mão.
EASING = {
    ## Suave dos dois lados. Era o comportamento implícito do pipeline antigo.
    "auto": ("BEZIER", "AUTO"),
    ## Velocidade constante: útil para giros e esteiras.
    "linear": ("LINEAR", "AUTO"),
    ## Degrau: a pose troca de uma vez, sem transição (poses de leitura).
    "hold": ("CONSTANT", "AUTO"),
    ## Antecipação: começa quase parado e vai acelerando. O preparo do golpe.
    "wind": ("QUAD", "EASE_IN"),
    ## Antecipação forte, para preparos longos (pesado, pisão).
    "accel": ("CUBIC", "EASE_IN"),
    ## Impacto: parte no talo e trava. É o que dá peso ao quadro de contato.
    "snap": ("EXPO", "EASE_OUT"),
    ## Impacto brutal (martelo, pisão): ainda mais frontal que `snap`.
    "hit": ("QUINT", "EASE_OUT"),
    ## Assentamento: chega desacelerando. Fim de recuperação.
    "settle": ("QUAD", "EASE_OUT"),
    ## Macio dos dois lados, mas com mais miolo que `auto`.
    "ease": ("SINE", "EASE_IN_OUT"),
    ## Recua antes de ir: antecipação exagerada e automática.
    "anticip": ("BACK", "EASE_IN"),
    ## Passa do ponto e volta: inércia no fim de um movimento rápido.
    "overshoot": ("BACK", "EASE_OUT"),
    ## Quica até parar: queda de corpo pesado no chão.
    "bounce": ("BOUNCE", "EASE_OUT"),
}


def animation(
    rig: bpy.types.Object,
    name: str,
    seconds: float,
    poses: dict,
    space: str = "bone",
) -> None:
    """Grava uma animação como trilha NLA nomeada.

    `poses` é {osso: [chave, ...]}, e cada chave é uma tupla de 2 a 4 campos:

        (tempo_s, (rx, ry, rz))
        (tempo_s, (rx, ry, rz), (tx, ty, tz))
        (tempo_s, (rx, ry, rz), (tx, ty, tz), "easing")

    - Rotação sempre em GRAUS, ordem XYZ.
    - Translação opcional (`None` para só girar).
    - Easing opcional: um nome da tabela EASING, que descreve como a pose
      SAI desta chave rumo à próxima. Sem easing, vale "auto" (o
      comportamento do pipeline antigo), então modelos existentes não mudam.

    `space` escolhe como ler a translação:

    - "bone" (padrão): no espaço local do osso, como o Blender guarda. O eixo
      Y aponta ao longo do osso; para um osso em pé isso significa que "para
      cima" é +Y e "para a frente" é +X. Confuso, mas é o legado.
    - "world": em METROS DE MUNDO (x = frente do personagem, y = lado,
      z = cima). A conversão para o espaço do osso usa a matriz de repouso.
      É o que torna escrevível o deslocamento de raiz dentro do clipe — o pé
      que pisa, a investida que avança o corpo, o salto do pisão.

    A duração do clipe é `seconds`, mesmo que a última chave venha antes: é o
    que faz a animação do Golpe casar exatamente com os números da Sim.
    """
    if rig.animation_data is None:
        rig.animation_data_create()

    action = bpy.data.actions.new(name)
    rig.animation_data.action = action

    for bone_name, keys in poses.items():
        pose_bone = rig.pose.bones[bone_name]
        pose_bone.rotation_mode = "XYZ"
        to_bone = None
        if space == "world":
            to_bone = rig.data.bones[bone_name].matrix_local.to_3x3().inverted()
        frame_easing = {}
        for key in keys:
            time = key[0]
            degrees = key[1]
            offset = key[2] if len(key) > 2 and key[2] is not None else None
            ease = key[3] if len(key) > 3 and key[3] else "auto"
            frame = 1 + int(round(time * FPS))
            frame_easing[frame] = ease
            pose_bone.rotation_euler = Euler(
                (math.radians(degrees[0]), math.radians(degrees[1]), math.radians(degrees[2])),
                "XYZ",
            )
            pose_bone.keyframe_insert("rotation_euler", frame=frame)
            if offset is not None:
                vector = Vector(offset)
                pose_bone.location = to_bone @ vector if to_bone is not None else vector
                pose_bone.keyframe_insert("location", frame=frame)
        _apply_easing(action, pose_bone, frame_easing)

    # O fim da trilha marca a duração exata, mesmo que a última chave venha
    # antes — é o que deixa a animação do Golpe casar com os números da Sim.
    end_frame = 1 + int(round(seconds * FPS))
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, action)
    strip.action_frame_end = max(float(end_frame), strip.action_frame_end)
    rig.animation_data.action = None


def _apply_easing(action, pose_bone, frame_easing: dict) -> None:
    """Carimba a curva escolhida em cada chave deste osso.

    O exportador glTF amostra as curvas quadro a quadro, então a forma da
    curva (antecipação, estalo, assentamento) chega inteira na Godot mesmo
    que o formato glTF só saiba de chaves lineares.
    """
    prefix = pose_bone.path_from_id()
    for fcurve in action.fcurves:
        if not fcurve.data_path.startswith(prefix):
            continue
        for point in fcurve.keyframe_points:
            ease = frame_easing.get(int(round(point.co.x)))
            if ease is None:
                continue
            interpolation, easing = EASING[ease]
            point.interpolation = interpolation
            point.easing = easing
        fcurve.update()


def settle(peak_time: float, peak, end_time: float, rest=(0.0, 0.0, 0.0),
           amount: float = 0.22, at: float = 0.38) -> list:
    """Movimento secundário no fim de um golpe: passa do ponto e assenta.

    Devolve duas chaves para colar depois do quadro de impacto: uma que
    ultrapassa o repouso no sentido contrário ao pico (fração `amount` do
    arco percorrido, no instante `at` da recuperação) e a do repouso, que
    chega desacelerando.

    É o que impede o braço de voltar em linha reta como um boneco de armar:
    a massa do golpe continua um pouco além e só então o corpo se recompõe.
    """
    over_time = peak_time + (end_time - peak_time) * at
    over = tuple(rest[i] - (peak[i] - rest[i]) * amount for i in range(3))
    return [(over_time, over, None, "ease"), (end_time, rest, None, "settle")]


def follow(keys: list, delay: float, damping: float = 0.55,
           limit: float = None, rest=(0.0, 0.0, 0.0)) -> list:
    """Defasagem amortecida: o cachecol/a cauda chegam depois do corpo.

    Recebe as chaves do osso que PUXA e devolve chaves atrasadas em `delay`
    segundos e reduzidas a `damping` do ângulo — o jeito mais barato de ter
    movimento secundário sem simulação nenhuma. `limit` corta no fim do
    clipe (a última chave é reposicionada ali, não descartada).

    A primeira chave é o repouso no instante original, para a peça começar
    parada e só então ser arrastada.
    """
    out = [(keys[0][0], rest, None, "ease")]
    for key in keys[1:]:
        time = key[0] + delay
        if limit is not None and time >= limit:
            time = limit
        rotation = tuple(rest[i] + (key[1][i] - rest[i]) * damping for i in range(3))
        ease = key[3] if len(key) > 3 and key[3] else "ease"
        out.append((time, rotation, None, ease))
        if limit is not None and time >= limit:
            break
    return out


def cycle(duration: float, amplitude=(0.0, 0.0, 0.0), bias=(0.0, 0.0, 0.0),
          phase: float = 0.0, samples: int = 8, rectify: bool = False,
          harmonic: int = 1, loc_amplitude=None, loc_bias=(0.0, 0.0, 0.0),
          ease: str = "ease") -> list:
    """Um ciclo senoidal amostrado — a espinha dorsal da locomoção.

    `phase` está em voltas (0.5 = oposto, para a perna de trás). `rectify`
    mantém só a metade positiva da onda, que é como um joelho dobra: flexiona
    na fase de balanço e trava na fase de apoio. `harmonic` multiplica a
    frequência: a raiz sobe e desce DUAS vezes por ciclo de passo (harmonic=2),
    porque cada passada tem seu próprio pico.

    `loc_amplitude`/`loc_bias` acrescentam deslocamento por chave, lido no
    mesmo espaço que a `animation` que receber estas chaves.

    Gerar o ciclo aqui — e não em código na apresentação — é o que devolve a
    caminhada ao asset: o clipe exportado já é bom, e a Godot só toca.
    """
    keys = []
    for index in range(samples + 1):
        time = duration * index / samples
        wave = math.sin(math.tau * (harmonic * index / samples + phase))
        if rectify:
            wave = max(0.0, wave)
        rotation = tuple(bias[i] + amplitude[i] * wave for i in range(3))
        offset = None
        if loc_amplitude is not None:
            offset = tuple(loc_bias[i] + loc_amplitude[i] * wave for i in range(3))
        keys.append((time, rotation, offset, ease))
    return keys


# --- Exportação ----------------------------------------------------------


def export_glb(path: str) -> None:
    """Exporta a cena inteira num .glb que a Godot importa nativamente.

    A amostragem forçada é o que preserva o easing: o glTF só guarda chaves
    lineares/step, então o exportador avalia as curvas quadro a quadro.
    """
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_animation_mode="NLA_TRACKS",
        export_force_sampling=True,
        export_frame_range=False,
        export_yup=True,
    )
    print("EXPORTED %s" % path)
