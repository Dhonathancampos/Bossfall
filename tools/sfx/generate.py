# -*- coding: utf-8 -*-
"""Efeitos sonoros do jogo, sintetizados do zero.

Asset é código: nenhum .wav é gravado ou baixado — todos nascem deste script,
em Python puro (wave/math/struct/random, sem dependências). Rodar de novo
regenera a pasta inteira, byte a byte (semente fixa).

    python tools/sfx/generate.py

Técnicas usadas: ruído branco filtrado (passa-baixa de um polo com varredura),
senos com envelope exponencial e varredura de frequência, modulação de
amplitude para rugido, distorção suave (tanh) e normalização com headroom.
"""

import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "sfx")

random.seed(20251009)


# --- blocos de síntese ----------------------------------------------------


def n_samples(seconds):
    return int(SR * seconds)


def silence(seconds):
    return [0.0] * n_samples(seconds)


def white(seconds):
    return [random.uniform(-1.0, 1.0) for _ in range(n_samples(seconds))]


def lowpass(samples, cutoff_start, cutoff_end=None):
    """Passa-baixa de um polo; o corte pode varrer no tempo (log)."""
    if cutoff_end is None:
        cutoff_end = cutoff_start
    out = []
    y = 0.0
    total = max(1, len(samples) - 1)
    log_a = math.log(max(20.0, cutoff_start))
    log_b = math.log(max(20.0, cutoff_end))
    for i, x in enumerate(samples):
        fc = math.exp(log_a + (log_b - log_a) * (i / total))
        a = 1.0 - math.exp(-2.0 * math.pi * fc / SR)
        y += a * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    out = []
    y = 0.0
    prev = 0.0
    a = math.exp(-2.0 * math.pi * cutoff / SR)
    for x in samples:
        y = a * (y + x - prev)
        prev = x
        out.append(y)
    return out


def sine_sweep(seconds, f0, f1, decay=0.0, vibrato_hz=0.0, vibrato_depth=0.0):
    """Seno com varredura exponencial de f0 a f1 e decaimento opcional."""
    n = n_samples(seconds)
    out = []
    phase = 0.0
    log_a = math.log(max(1.0, f0))
    log_b = math.log(max(1.0, f1))
    for i in range(n):
        t = i / SR
        f = math.exp(log_a + (log_b - log_a) * (i / max(1, n - 1)))
        if vibrato_hz > 0.0:
            f *= 1.0 + vibrato_depth * math.sin(2.0 * math.pi * vibrato_hz * t)
        phase += 2.0 * math.pi * f / SR
        amp = math.exp(-decay * t) if decay > 0.0 else 1.0
        out.append(math.sin(phase) * amp)
    return out


def exp_decay(samples, k):
    return [x * math.exp(-k * (i / SR)) for i, x in enumerate(samples)]


def bell_envelope(samples):
    """Envelope em sino (sin^2): sobe e desce suave — o formato de um whoosh."""
    n = max(1, len(samples) - 1)
    return [x * math.sin(math.pi * i / n) ** 2 for i, x in enumerate(samples)]


def attack(samples, seconds):
    n = max(1, n_samples(seconds))
    return [x * min(1.0, i / n) for i, x in enumerate(samples)]


def gain(samples, g):
    return [x * g for x in samples]


def drive(samples, amount):
    """Distorção suave: espessa o grave sem serrilhar."""
    return [math.tanh(x * amount) for x in samples]


def am(samples, hz, depth):
    """Modulação de amplitude: a textura de um rugido."""
    return [
        x * (1.0 - depth + depth * 0.5 * (1.0 + math.sin(2.0 * math.pi * hz * i / SR)))
        for i, x in enumerate(samples)
    ]


def mix(*tracks):
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for track in tracks:
        for i, x in enumerate(track):
            out[i] += x
    return out


def place(seconds_offset, samples):
    return silence(seconds_offset) + samples


def normalize(samples, peak=0.82):
    top = max(1e-9, max(abs(x) for x in samples))
    return [x * peak / top for x in samples]


def fade_out(samples, seconds=0.04):
    n = min(len(samples), n_samples(seconds))
    total = len(samples)
    out = list(samples)
    for i in range(n):
        out[total - n + i] *= 1.0 - (i + 1) / n
    return out


def write(name, samples, fade=0.04):
    data = fade_out(normalize(samples), fade)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(x * 32767)))) for x in data
        )
        f.writeframes(frames)
    print("WROTE %s (%.2fs)" % (path, len(data) / SR))


# --- os sons ----------------------------------------------------------------


def swing():
    """Corte de ar: ruído com passa-baixa varrendo para cima, envelope em sino."""
    whoosh = bell_envelope(lowpass(white(0.28), 300.0, 2600.0))
    write("swing", highpass(whoosh, 180.0))


def hit():
    """Impacto carnudo: baque de seno caindo + estalo curto de ruído."""
    thump = drive(sine_sweep(0.2, 160.0, 55.0, decay=26.0), 2.5)
    crack = gain(exp_decay(highpass(lowpass(white(0.1), 3200.0), 300.0), 60.0), 0.7)
    write("hit", mix(thump, crack))


def hit_blunt():
    """Impacto grave: baque fundo com distorção + ronco baixo."""
    thump = drive(sine_sweep(0.3, 100.0, 38.0, decay=13.0), 3.5)
    rumble = gain(exp_decay(lowpass(white(0.35), 220.0), 11.0), 0.5)
    snap = gain(exp_decay(white(0.04), 120.0), 0.3)
    write("hit_blunt", mix(thump, rumble, snap))


def hurt():
    """Dano sofrido: dois senos dissonantes caindo + sopro de ruído."""
    a = sine_sweep(0.32, 330.0, 180.0, decay=9.0)
    b = gain(sine_sweep(0.32, 311.0, 170.0, decay=9.0), 0.7)
    breath = gain(exp_decay(lowpass(white(0.25), 1200.0), 22.0), 0.4)
    write("hurt", drive(mix(a, b, breath), 1.4))


def dodge():
    """Rolamento: whoosh baixo e discreto."""
    whoosh = bell_envelope(lowpass(white(0.3), 200.0, 900.0))
    write("dodge", gain(highpass(whoosh, 120.0), 0.8))


def roar():
    """Rugido de Fúria: pilha de harmônicos graves com vibrato, modulado a 14 Hz
    (o tremor de garganta) e distorcido; sopro de ruído por baixo."""
    dur = 2.3
    base = sine_sweep(dur, 70.0, 62.0, vibrato_hz=5.0, vibrato_depth=0.04)
    h2 = gain(sine_sweep(dur, 141.4, 125.0, vibrato_hz=5.0, vibrato_depth=0.04), 0.6)
    h3 = gain(sine_sweep(dur, 212.1, 188.0, vibrato_hz=5.0, vibrato_depth=0.05), 0.35)
    h4 = gain(sine_sweep(dur, 287.0, 254.0, vibrato_hz=5.0, vibrato_depth=0.05), 0.2)
    voice = drive(am(mix(base, h2, h3, h4), 14.0, 0.45), 4.0)
    breath = gain(lowpass(white(dur), 900.0), 0.22)
    growl = attack(exp_decay(mix(voice, breath), 0.9), 0.12)
    write("roar", growl, fade=0.25)


def stagger_fall():
    """Tombo pesado: dois baques (corpo, depois cabeça) sobre ronco de poeira."""
    thump1 = drive(sine_sweep(0.35, 90.0, 40.0, decay=15.0), 3.0)
    thump2 = place(0.28, gain(drive(sine_sweep(0.3, 70.0, 35.0, decay=15.0), 3.0), 0.7))
    dust = gain(exp_decay(lowpass(white(1.0), 150.0), 5.0), 0.5)
    write("stagger_fall", mix(thump1, thump2, dust), fade=0.1)


def part_break():
    """Quebra de Parte: estalo seco, segundo estalo, e um rasgo modulado."""
    snap1 = gain(exp_decay(highpass(white(0.07), 1500.0), 85.0), 0.95)
    snap2 = place(0.045, gain(exp_decay(highpass(white(0.06), 1200.0), 70.0), 0.7))
    tear = place(
        0.07,
        gain(exp_decay(am(lowpass(white(0.5), 2500.0, 500.0), 30.0, 0.6), 7.0), 0.55),
    )
    write("part_break", mix(snap1, snap2, tear))


def affliction():
    """Sinal mágico: sino de três parciais com brilho ascendente, sem peso."""
    bell = mix(
        sine_sweep(0.85, 880.0, 870.0, decay=5.5),
        gain(sine_sweep(0.85, 1318.0, 1310.0, decay=6.5), 0.5),
        gain(sine_sweep(0.85, 1760.0, 1750.0, decay=7.5), 0.3),
    )
    shimmer = gain(sine_sweep(0.7, 1200.0, 2400.0, decay=5.0), 0.15)
    write("affliction", gain(mix(bell, shimmer), 0.7), fade=0.12)


def special():
    """Liberação de energia: subida tensa, explosão, brilho residual."""
    riser = attack(gain(sine_sweep(0.5, 180.0, 900.0), 0.5), 0.4)
    burst = place(0.48, drive(sine_sweep(0.45, 500.0, 120.0, decay=11.0), 2.0))
    blast = place(0.48, gain(exp_decay(lowpass(white(0.5), 4000.0), 16.0), 0.8))
    tail = place(0.6, gain(sine_sweep(0.7, 1500.0, 1480.0, decay=4.0), 0.2))
    write("special", mix(riser, burst, blast, tail), fade=0.1)


def death():
    """Queda final: baque enorme, ronco longo e um tom escuro descendo."""
    thump = drive(sine_sweep(0.5, 75.0, 30.0, decay=7.0), 3.5)
    rumble = gain(exp_decay(lowpass(white(2.5), 120.0), 2.0), 0.6)
    tone = gain(sine_sweep(1.9, 160.0, 55.0, decay=2.2), 0.35)
    write("death", mix(thump, rumble, tone), fade=0.3)


def click():
    """Clique de interface: tique curto e limpo."""
    tick = exp_decay(sine_sweep(0.09, 1800.0, 1750.0), 80.0)
    top = gain(exp_decay(highpass(white(0.05), 2000.0), 140.0), 0.4)
    write("click", gain(mix(tick, top), 0.6), fade=0.02)


def main():
    swing()
    hit()
    hit_blunt()
    hurt()
    dodge()
    roar()
    stagger_fall()
    part_break()
    affliction()
    special()
    death()
    click()
    print("OK")


main()
