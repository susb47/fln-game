"""Makes the game's sound effects (assets/sfx/*.wav) from scratch.

Every sound is synthesised here, so there are no licences to track.
Run:  python tools/make_sfx.py      (needs numpy)
Listen, tweak a recipe below, run again.
"""
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx')
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(dur, attack=0.004, decay=6.0):
    t = t_axis(dur)
    return np.minimum(1, t / attack) * np.exp(-t * decay)


def note(freq, dur, kind='bell', vol=1.0, decay=6.0, attack=0.004, glide=0.0):
    """One note. kind: sine, bell, marimba, pluck, brass. glide: pitch change in octaves."""
    t = t_axis(dur)
    f = freq * 2 ** (glide * t / dur)
    phase = 2 * np.pi * np.cumsum(f) / SR
    if kind == 'sine':
        s = np.sin(phase)
    elif kind == 'bell':
        s = np.sin(phase) + 0.45 * np.sin(2.76 * phase) * np.exp(-t * 9) + 0.2 * np.sin(5.4 * phase) * np.exp(-t * 14)
    elif kind == 'marimba':
        s = np.sin(phase) + 0.6 * np.sin(4 * phase) * np.exp(-t * 30) + 0.25 * np.sin(10 * phase) * np.exp(-t * 60)
    elif kind == 'pluck':
        s = sum(np.sin(k * phase) / k ** 1.4 * np.exp(-t * (3 + 5 * k)) for k in range(1, 7))
    elif kind == 'brass':
        s = sum(np.sin(k * phase) / k * (1 - np.exp(-t * 25 * k)) for k in range(1, 9))
    else:
        raise ValueError(kind)
    return vol * s * env(dur, attack, decay)


def noise(dur, lo=0.0, hi=1.0, vol=1.0, decay=8.0, attack=0.003):
    """Noise through a sweeping one-pole filter (lo..hi = cutoff as a share of the band)."""
    n = rng.standard_normal(int(SR * dur))
    cut = np.linspace(lo, hi, n.size)
    out = np.empty_like(n)
    y = 0.0
    for i, x in enumerate(n):
        a = 0.02 + 0.9 * cut[i]
        y += a * (x - y)
        out[i] = y
    return vol * out * env(dur, attack, decay)


def mix(*parts, tail=0.0):
    end = max(int(st * SR) + p.size for st, p in parts) + int(tail * SR)
    buf = np.zeros(end)
    for st, p in parts:
        o = int(st * SR)
        buf[o:o + p.size] += p
    return buf


def reverb(x, amount=0.25):
    """A small room: a few feedback delays."""
    out = np.concatenate([x, np.zeros(int(SR * 0.6))])
    for ms, g in [(29, 0.5), (37, 0.45), (53, 0.4), (71, 0.35)]:
        d = int(SR * ms / 1000)
        y = np.zeros_like(out)
        buf = out.copy()
        for k in range(1, 8):
            shift = d * k
            if shift >= out.size:
                break
            y[shift:] += buf[:-shift] * (g ** k)
        out = out + amount * y / 4
    return out


def save(name, x, peak=0.8):
    x = x / max(1e-9, np.max(np.abs(x))) * peak
    fade = int(SR * 0.01)
    x[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print(f'{name}: {x.size / SR:.2f}s')


def hz(n):  # MIDI note -> Hz
    return 440 * 2 ** ((n - 69) / 12)


C5, D5, E5, G5, A5, C6, E6, G6, C7 = (hz(n) for n in (72, 74, 76, 79, 81, 84, 88, 91, 96))

# Button tap: a soft wooden "tock".
save('tap.wav', mix((0, note(900, 0.08, 'marimba', decay=45, glide=-0.4)), (0, noise(0.02, 0.6, 0.2, 0.25, decay=120))), peak=0.55)

# Objects popping in: a bubble "pop" that glides up.
save('pop.wav', mix((0, note(520, 0.09, 'sine', decay=30, glide=1.2)), (0, noise(0.015, 0.9, 0.5, 0.15, decay=200))), peak=0.5)

# New question slides in: an airy whoosh.
save('whoosh.wav', reverb(noise(0.35, 0.05, 0.6, decay=4, attack=0.15), 0.3), peak=0.4)

# Right answer: a bright marimba "ding-ding" with a little sparkle.
save('correct.wav', reverb(mix(
    (0.00, note(E6, 0.35, 'marimba', decay=9)),
    (0.09, note(C7, 0.55, 'marimba', decay=6)),
    (0.09, note(G6, 0.55, 'bell', 0.4, decay=6)),
    (0.18, note(hz(103), 0.3, 'sine', 0.15, decay=12)),
    (0.24, note(hz(108), 0.3, 'sine', 0.12, decay=12)),
), 0.35))

# Wrong answer: a gentle, low "boop-boop". Never a harsh buzzer.
save('wrong.wav', reverb(mix(
    (0.00, note(hz(64), 0.22, 'pluck', decay=12, glide=-0.05)),
    (0.14, note(hz(60), 0.35, 'pluck', decay=9, glide=-0.08)),
), 0.25), peak=0.55)

# A star: twinkling arpeggio.
save('star.wav', reverb(mix(*[(i * 0.06, note(f, 0.5, 'bell', 0.8, decay=7)) for i, f in enumerate([C6, E6, G6, C7, E6 * 2])]), 0.45))

# Level passed: a short brass fanfare over a drum and a cymbal.
fan = mix(
    (0.00, note(hz(67), 0.16, 'brass', 0.8, decay=5)),
    (0.16, note(hz(67), 0.16, 'brass', 0.8, decay=5)),
    (0.32, note(hz(67), 0.16, 'brass', 0.8, decay=5)),
    (0.48, note(hz(72), 0.9, 'brass', 1.0, decay=2.5)),
    (0.48, note(hz(76), 0.9, 'brass', 0.6, decay=2.5)),
    (0.48, note(hz(79), 0.9, 'brass', 0.5, decay=2.5)),
    (0.00, note(90, 0.25, 'sine', 0.9, decay=18, glide=-0.6)),
    (0.48, note(80, 0.35, 'sine', 1.0, decay=12, glide=-0.6)),
    (0.48, noise(0.9, 0.95, 0.7, 0.35, decay=4)),
    *[(0.6 + i * 0.05, note(f, 0.4, 'bell', 0.25, decay=8)) for i, f in enumerate([C7, E6 * 2, G6 * 2])],
)
save('level_up.wav', reverb(fan, 0.4))

# Level not passed: a soft, hopeful harp going down and back up.
save('try_again.wav', reverb(mix(*[(i * 0.09, note(f, 0.6, 'pluck', 0.8, decay=5)) for i, f in enumerate([G5, E5, C5, E5, G5])]), 0.4), peak=0.6)

# Placement / map: a friendly "hello" chime.
save('hello.wav', reverb(mix((0, note(G5, 0.3, 'marimba', decay=10)), (0.12, note(C6, 0.5, 'marimba', decay=7))), 0.3), peak=0.6)
