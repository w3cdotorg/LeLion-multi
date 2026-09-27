#!/usr/bin/env python3
"""Synthétise les effets sonores du jeu dans Assets/Sons (WAV 44,1 kHz mono 16 bits).

Usage : python3 tools/generer_sons.py [nom…]   (depuis la racine du projet)
Sans nom, tous les effets ; avec des noms, ceux-là seulement (ex. : boing tic fin etourdi). Le bruit
de « mort » n'est pas semé : le regénérer change son fichier.
"""
import math
import random
import struct
import sys
import wave
from pathlib import Path

SR = 44100
DOSSIER = Path(__file__).resolve().parent.parent / "Assets" / "Sons"


def ecrire(nom, samples, gain=0.8):
    DOSSIER.mkdir(parents=True, exist_ok=True)
    m = max(1e-9, max(abs(x) for x in samples))
    data = b"".join(struct.pack("<h", int(max(-1, min(1, x / m * gain)) * 32767)) for x in samples)
    with wave.open(str(DOSSIER / f"{nom}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(f"{nom}.wav  {len(samples) / SR:.2f} s")


def env(t, dur, a=0.005, r=0.08):
    if t < a:
        return t / a
    if t > dur - r:
        return max(0.0, (dur - t) / r)
    return 1.0


def pickup():
    dur, out = 0.28, []
    for i in range(int(SR * dur)):
        t = i / SR
        f = 660 if t < 0.09 else 990
        x = math.sin(2 * math.pi * f * t) * 0.7 + math.sin(2 * math.pi * f * 2 * t) * 0.2
        out.append(x * env(t, dur, r=0.15) * math.exp(-4 * t))
    ecrire("pickup", out)


def vomi():
    """Glouglou bruité d'une seconde, bouclable (fondu croisé aux extrémités)."""
    dur, out, lp = 1.0, [], 0.0
    n = int(SR * dur)
    random.seed(7)
    for i in range(n):
        t = i / SR
        lp += (random.uniform(-1, 1) - lp) * 0.08
        burble = 1.0 + 0.6 * math.sin(2 * math.pi * 17 * t) + 0.3 * math.sin(2 * math.pi * 5.3 * t)
        grave = 0.25 * math.sin(2 * math.pi * (90 + 20 * math.sin(2 * math.pi * 3 * t)) * t)
        out.append(lp * burble + grave)
    fade = int(SR * 0.02)
    for i in range(fade):
        a = i / fade
        out[i] = out[i] * a + out[n - fade + i] * (1 - a)
    ecrire("vomi", out[: n - fade], gain=0.6)


def mort():
    dur, out, ph = 0.7, [], 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        f = 320 * (1 - t / dur) ** 2 + 50
        ph += 2 * math.pi * f / SR
        x = (1 if math.sin(ph) > 0 else -1) * 0.5 + random.uniform(-1, 1) * 0.3
        out.append(x * env(t, dur, r=0.25))
    ecrire("mort", out)


def victoire():
    notes, out = [523.25, 659.25, 783.99, 1046.5], []
    for f in notes:
        d = 0.14
        for i in range(int(SR * d)):
            t = i / SR
            out.append((math.sin(2 * math.pi * f * t) + 0.4 * math.sin(2 * math.pi * f * 2 * t)) * env(t, d, r=0.03))
    d = 0.9
    for i in range(int(SR * d)):
        t = i / SR
        x = sum(math.sin(2 * math.pi * f * t) for f in notes[:3]) / 3 + 0.3 * math.sin(2 * math.pi * notes[3] * t)
        out.append(x * env(t, d, r=0.5))
    ecrire("victoire", out)


def boss():
    """Grondement grave qui monte : le peintre arrive."""
    dur, out, ph = 0.9, [], 0.0
    random.seed(3)
    for i in range(int(SR * dur)):
        t = i / SR
        f = 55 + 40 * (t / dur)
        ph += 2 * math.pi * f / SR
        x = math.sin(ph) * 0.6 + math.sin(ph * 2.01) * 0.25 + random.uniform(-1, 1) * 0.12
        out.append(x * env(t, dur, a=0.05, r=0.3) * (0.6 + 0.4 * math.sin(2 * math.pi * 9 * t)))
    ecrire("boss", out, gain=0.9)


def pret():
    """Deux bips « prêt » puis un « go » plus aigu."""
    out = []
    for f, d in [(660, 0.12), (660, 0.12), (990, 0.3)]:
        for i in range(int(SR * d)):
            t = i / SR
            out.append((1 if math.sin(2 * math.pi * f * t) > 0 else -1) * 0.5 * env(t, d, r=0.06))
        for _ in range(int(SR * 0.08)):
            out.append(0.0)
    ecrire("pret", out, gain=0.7)


def boing():
    """« Boing » des auto-tamponneuses : une note qui plonge vers le grave en vibrant, comme un ressort."""
    dur, out, ph = 0.35, [], 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        f = 420 * math.exp(-5 * t) + 110 + 25 * math.sin(2 * math.pi * 22 * t) * math.exp(-6 * t)
        ph += 2 * math.pi * f / SR
        x = math.sin(ph) + 0.3 * math.sin(2 * ph)
        out.append(x * env(t, dur, r=0.12) * math.exp(-3 * t))
    ecrire("boing", out)


def tic():
    """Tic du chrono dans les dix dernières secondes : un clic sec et bref."""
    dur, out = 0.06, []
    for i in range(int(SR * dur)):
        t = i / SR
        x = math.sin(2 * math.pi * 1800 * t) * 0.8 + math.sin(2 * math.pi * 3600 * t) * 0.2
        out.append(x * math.exp(-70 * t))
    ecrire("tic", out, gain=0.6)


def fin():
    """Gong de fin de manche : des partiels inharmoniques qui s'éteignent lentement."""
    dur, out = 1.6, []
    partiels = [(196.0, 1.0), (293.7, 0.6), (392.0, 0.5), (523.3, 0.3), (659.3, 0.2)]
    for i in range(int(SR * dur)):
        t = i / SR
        x = sum(a * math.sin(2 * math.pi * f * t) * math.exp(-(1.5 + k) * t) for k, (f, a) in enumerate(partiels))
        out.append(x * env(t, dur, a=0.003, r=0.3))
    ecrire("fin", out)


def etourdi():
    """Étourdissement : trois tintements qui descendent, les étoiles qui tournent."""
    out = []
    for f in [1320.0, 990.0, 740.0]:
        d = 0.11
        for i in range(int(SR * d)):
            t = i / SR
            out.append((math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * f * 2.76 * t)) * math.exp(-18 * t))
    ecrire("etourdi", out, gain=0.6)


EFFETS = {
    "pickup": pickup,
    "vomi": vomi,
    "mort": mort,
    "victoire": victoire,
    "boss": boss,
    "pret": pret,
    "boing": boing,
    "tic": tic,
    "fin": fin,
    "etourdi": etourdi,
}


if __name__ == "__main__":
    for nom in sys.argv[1:] or list(EFFETS):
        EFFETS[nom]()
