#!/usr/bin/env python3
"""Synthesises all game sound effects (original, royalty-free) as 16-bit WAV."""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t(d):
    return np.linspace(0, d, int(SR * d), endpoint=False)


def env(n, a=0.005, r=0.08, curve=3.0):
    e = np.ones(n)
    na = max(1, int(SR * a))
    e[:na] = np.linspace(0, 1, na)
    nr = max(1, int(SR * r))
    e[-nr:] *= np.linspace(1, 0, nr) ** curve
    return e


def bell(freq, d, vol=1.0, decay=7.0):
    x = t(d)
    s = (np.sin(2 * np.pi * freq * x) + 0.45 * np.sin(2 * np.pi * freq * 2.01 * x)
         + 0.2 * np.sin(2 * np.pi * freq * 3.02 * x))
    return vol * s * np.exp(-decay * x) * env(len(x), 0.002, 0.02)


def place(buf, snd, at):
    i = int(SR * at)
    n = min(len(snd), len(buf) - i)
    if n > 0:
        buf[i:i + n] += snd[:n]


def save(name, data, vol=0.8):
    data = np.asarray(data, dtype=np.float64)
    m = np.max(np.abs(data)) or 1
    data = data / m * vol
    pcm = (data * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


# tap: soft pop
x = t(0.09)
f = 640 * np.exp(-9 * x) + 260
save("tap", np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-30 * x) * env(len(x), 0.001, 0.02))

# button: tiny click
x = t(0.06)
save("button", np.sin(2 * np.pi * 900 * x) * np.exp(-55 * x) * env(len(x), 0.0005, 0.01), 0.6)

# send: whoosh (filtered noise sweep)
x = t(0.2)
n = rng.standard_normal(len(x))
k = 60
sm = np.convolve(n, np.ones(k) / k, mode="same")
sweep = np.sin(2 * np.pi * np.cumsum(300 + 1400 * (x / 0.2) ** 2) / SR) * 0.35
save("send", (sm * 6 + sweep) * np.sin(np.pi * x / 0.2) ** 1.5, 0.5)

# deliver: bright ding
save("deliver", bell(988, 0.28, 1.0, 9) + bell(1480, 0.28, 0.4, 11), 0.7)

# complete: rising arpeggio
buf = np.zeros(int(SR * 0.7))
for i, fr in enumerate([523.25, 659.25, 783.99, 1046.5]):
    place(buf, bell(fr, 0.4, 1.0, 6), 0.075 * i)
save("complete", buf, 0.8)

# coin
buf = np.zeros(int(SR * 0.35))
place(buf, bell(1318.5, 0.2, 1, 12), 0.0)
place(buf, bell(1760, 0.3, 1, 9), 0.07)
save("coin", buf, 0.7)

# win fanfare
buf = np.zeros(int(SR * 1.7))
notes = [(523.25, 0.0), (659.25, 0.13), (783.99, 0.26), (1046.5, 0.39), (783.99, 0.62), (1046.5, 0.75), (1318.5, 0.95)]
for fr, at in notes:
    place(buf, bell(fr, 0.7, 0.8, 4.5), at)
for fr in (523.25, 659.25, 783.99, 1046.5):
    place(buf, bell(fr, 0.9, 0.35, 3.0), 0.95)
save("win", buf, 0.85)

# lose: descending sad notes
buf = np.zeros(int(SR * 1.1))
for fr, at in [(392.0, 0.0), (349.2, 0.22), (293.7, 0.46), (261.6, 0.72)]:
    x = t(0.5)
    s = np.sin(2 * np.pi * fr * x) + 0.3 * np.sin(2 * np.pi * fr * 2 * x)
    place(buf, s * np.exp(-4 * x) * env(len(x), 0.01, 0.1), at)
save("lose", buf, 0.7)

# error buzz
x = t(0.16)
sq = np.sign(np.sin(2 * np.pi * 120 * x)) * 0.5 + np.sin(2 * np.pi * 90 * x)
save("error", sq * env(len(x), 0.002, 0.05), 0.55)

# unlock / star pop
buf = np.zeros(int(SR * 0.4))
place(buf, bell(784, 0.3, 1, 8), 0)
place(buf, bell(1175, 0.3, 1, 8), 0.06)
save("star", buf, 0.7)
print("audio written to", os.path.abspath(OUT))
