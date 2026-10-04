"""Synthesizes the 60s soundtrack (128 BPM, synced to the video's beat grid) plus all SFX listed in sfx.json.
Output: audio.wav (44.1 kHz stereo)."""
import json
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve
from scipy.io import wavfile

SR = 44100
D = json.load(open('sfx.json'))
DUR = D['duration']
BEAT = D['timing']['BEAT']
FEAT0 = D['timing']['FEAT0']
OUT0 = D['timing']['OUT0']
BAR = BEAT * 4
N = int(SR * (DUR + 0.5))
rng = np.random.default_rng(5)

music = np.zeros((2, N))
verb_send = np.zeros((2, N))
fx = np.zeros((2, N))


def t_arr(dur):
    return np.arange(int(dur * SR)) / SR


def lp(x, f, order=2):
    return sosfilt(butter(order, min(f, SR / 2 - 100), 'low', fs=SR, output='sos'), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, 'high', fs=SR, output='sos'), x)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], 'band', fs=SR, output='sos'), x)


def add(buf, sig, t, gain=1.0, pan=0.0):
    i = int(t * SR)
    if i >= N or i + len(sig) <= 0:
        return
    if i < 0:
        sig = sig[-i:]
        i = 0
    sig = sig[: N - i]
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    buf[0, i:i + len(sig)] += sig * gain * l * 1.414
    buf[1, i:i + len(sig)] += sig * gain * r * 1.414


def saw(f, t, phase=0.0):
    return 2 * ((f * t + phase) % 1.0) - 1


def env(t, a=0.005, d=0.2, s=0.0, rel=0.05, length=None):
    length = length if length is not None else t[-1]
    e = np.where(t < a, t / a, s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    e = np.where(t > length - rel, e * np.clip((length - t) / rel, 0, 1), e)
    return e


def note(n):  # midi → Hz
    return 440.0 * 2 ** ((n - 69) / 12)


# ---------------------------------------------------------------- arrangement
# vi–IV–I–V in C: Am F C G (one chord per bar)
CHORDS = [[57, 60, 64], [53, 57, 60], [55, 60, 64], [55, 59, 62]]
BASS = [33, 29, 36, 31]
n_bars = int(DUR / BAR) + 2


def section(t):
    if t < FEAT0:
        return 'intro'
    if t < OUT0:
        return 'main'
    if t < OUT0 + 6 * BEAT:
        return 'outroA'
    return 'outroB'


# kicks & sidechain
kick_times = []
for b in range(int(DUR / BEAT) + 1):
    t = b * BEAT
    s = section(t)
    if s in ('main', 'outroB') or (s == 'intro' and False):
        if t < DUR - 1.2:
            kick_times.append(t)
    if s == 'outroA' and b % 2 == 0:
        kick_times.append(t)
# intro: the three word slams get kicks handled as sfx "hit"

sc = np.ones(N)
tt = np.arange(N) / SR
for k in kick_times:
    i = int(k * SR)
    seg = tt[i:i + int(0.3 * SR)] - k
    sc[i:i + len(seg)] = np.minimum(sc[i:i + len(seg)], 1 - 0.65 * np.exp(-seg / 0.09))


def kick():
    t = t_arr(0.45)
    f = 45 + 110 * np.exp(-t / 0.035)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) * np.exp(-t / 0.16)
    s += 0.5 * rng.standard_normal(len(t)) * np.exp(-t / 0.004)
    return np.tanh(s * 1.6)


KICK = kick()
for k in kick_times:
    add(music, KICK, k, 0.9)

# claps on 2 & 4, hats
def clap():
    t = t_arr(0.3)
    n = rng.standard_normal(len(t))
    e = np.zeros(len(t))
    for o in (0, 0.011, 0.022):
        e += np.where(t >= o, np.exp(-(t - o) / (0.012 if o < 0.02 else 0.09)), 0)
    return bp(n * e, 900, 3500)


CLAP, = [clap()]
HATC = hp(rng.standard_normal(int(0.05 * SR)), 7000) * np.exp(-t_arr(0.05) / 0.012)
HATO = hp(rng.standard_normal(int(0.25 * SR)), 6000) * np.exp(-t_arr(0.25) / 0.07)
for b in range(int(DUR / BEAT) + 1):
    t = b * BEAT
    s = section(t)
    if t > DUR - 1.0:
        break
    if s in ('main', 'outroB'):
        if b % 2 == 1:
            add(music, CLAP, t, 0.5, 0.05)
            add(verb_send, CLAP, t, 0.25)
        add(music, HATO, t + BEAT / 2, 0.22, 0.25)
        for q in range(4):
            add(music, HATC, t + q * BEAT / 4, 0.09 if q % 2 else 0.05, -0.3)
    elif s == 'intro' and t >= 8 * BEAT:
        for q in range(4):
            add(music, HATC, t + q * BEAT / 4, 0.06, -0.3)
    elif s == 'outroA':
        add(music, HATO, t + BEAT / 2, 0.15, 0.25)

# snare roll into the drop
for i in range(16):
    t = FEAT0 - 2 * BEAT + i * BEAT / 8
    add(music, CLAP, t, 0.12 + 0.35 * i / 16)

# bass (offbeat 8ths, sidechained)
def bass_note(f, dur):
    t = t_arr(dur)
    s = 0.6 * saw(f, t) + 0.25 * saw(f * 1.005, t) + 0.6 * np.sin(2 * np.pi * f * t)
    return lp(s, 520) * env(t, 0.004, 0.25, 0.6, 0.03, dur)


bass_buf = np.zeros((2, N))
for bar in range(n_bars):
    t0 = bar * BAR
    if t0 >= DUR - 1.0:
        break
    s = section(t0 + 0.01)
    if s == 'intro' and t0 < 2 * BAR:
        continue
    f = note(BASS[bar % 4])
    for e in range(8):
        t = t0 + e * BEAT / 2
        if section(t) == 'outroA':
            continue
        if s == 'intro':
            if e % 2 == 0:
                add(bass_buf, bass_note(f, BEAT * 0.9), t, 0.35)
        elif e % 2 == 1 or e == 0:
            add(bass_buf, bass_note(f * (2 if e in (3, 7) else 1), BEAT * 0.48), t, 0.55)
music += bass_buf * sc

# pads (supersaw) — filter opens across the intro
pad_buf = np.zeros((2, N))
for bar in range(n_bars):
    t0 = bar * BAR
    if t0 >= DUR:
        break
    dur = BAR + 0.1
    t = t_arr(dur)
    for n in CHORDS[bar % 4]:
        f = note(n)
        for d, pan in ((-0.12, -0.7), (-0.05, -0.3), (0, 0), (0.06, 0.35), (0.13, 0.7)):
            s = saw(f * 2 ** (d / 12), t, rng.random()) * env(t, 0.08, 1.0, 0.8, 0.12, dur)
            add(pad_buf, s, t0, 0.035, pan)
# time-varying filter: render in blocks
pad = np.zeros_like(pad_buf)
blk = int(SR * BEAT / 2)
for i in range(0, N, blk):
    tm = i / SR
    cut = 600 + 3400 * min(1, tm / FEAT0) if tm < FEAT0 else (3800 if tm < OUT0 else 2400)
    sl = slice(max(0, i - 2048), min(N, i + blk))
    filt = np.stack([lp(pad_buf[c, sl], cut) for c in range(2)])
    pad[:, i:min(N, i + blk)] = filt[:, (i - sl.start):(i - sl.start) + min(blk, N - i)]
music += pad * (0.55 + 0.45 * sc)
verb_send += pad * 0.35

# pluck arpeggio (16ths) in main sections
def pluck(f, dur=0.22):
    t = t_arr(dur)
    s = 0.6 * saw(f, t) + 0.4 * np.sign(np.sin(2 * np.pi * f * t))
    return lp(s, 2600) * np.exp(-t / 0.07)


PAT = [0, 1, 2, 1, 2, 0, 1, 2, 0, 2, 1, 2, 0, 1, 2, 1]
for bar in range(n_bars):
    t0 = bar * BAR
    s = section(t0 + 0.01)
    if s not in ('main', 'outroB') and not (s == 'intro' and bar >= 1):
        continue
    if t0 > DUR - 2:
        break
    ch = CHORDS[bar % 4]
    for q in range(16):
        t = t0 + q * BEAT / 4
        if section(t) == 'outroA':
            continue
        n = ch[PAT[q]] + 12 + (12 if q in (6, 14) else 0)
        g = 0.07 if s == 'intro' else 0.11
        p = pluck(note(n))
        add(music, p, t, g, -0.4 if q % 2 else 0.4)
        add(verb_send, p, t, g * 0.8)

# lead hook: simple motif every 2 bars in main
MOTIF = [(0, 76, 1), (1.5, 74, 0.5), (2, 72, 1), (3, 69, 1), (4, 72, 1.5), (5.5, 74, 0.5), (6, 76, 2)]
for bar in range(0, n_bars, 2):
    t0 = bar * BAR
    if section(t0 + 0.01) != 'main' or (bar // 2) % 2 == 0:
        continue
    for off, n, ln in MOTIF:
        dur = ln * BEAT
        t = t_arr(dur + 0.2)
        f = note(n)
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t)
        s = (saw(f * vib, t) * 0.5 + np.sin(2 * np.pi * f * t) * 0.5)
        s = lp(s, 3200) * env(t, 0.01, 0.4, 0.55, 0.12, dur + 0.2)
        add(music, s, t0 + off * BEAT, 0.07, 0.1)
        add(verb_send, s, t0 + off * BEAT, 0.08)

# crashes at structure points
CRASH = hp(rng.standard_normal(int(2.2 * SR)), 4500) * np.exp(-t_arr(2.2) / 0.55)
for t in [FEAT0, FEAT0 + 4 * BAR * 2, FEAT0 + 8 * BAR * 2, OUT0 + 6 * BEAT]:
    add(music, CRASH, t, 0.22)

# final chord ring-out
t = t_arr(4.0)
for n in [57, 60, 64, 69, 72]:
    s = sum(saw(note(n) * 2 ** (d / 12), t, rng.random()) for d in (-0.1, 0, 0.1)) / 3
    add(music, lp(s, 1800) * np.exp(-t / 1.6), DUR - 3.4, 0.05)

# power-cut: muffle the music while the lights are out (feature 1)
pc0, pc1 = FEAT0 + 0.12, FEAT0 + 2.95
a, b = int(pc0 * SR), int(pc1 * SR)
muf = np.stack([lp(music[c], 450) for c in range(2)])
fade = np.ones(N)
ramp = int(0.08 * SR)
fade[a:b] = 0
fade[a - ramp:a] = np.linspace(1, 0, ramp)
fade[b:b + ramp] = np.linspace(0, 1, ramp)
music = music * fade + muf * (1 - fade) * 0.8

# ---------------------------------------------------------------- SFX
def sine_sweep(f0, f1, dur, decay=None, curve='exp'):
    t = t_arr(dur)
    f = f0 * (f1 / f0) ** (t / dur) if curve == 'exp' else f0 + (f1 - f0) * t / dur
    s = np.sin(2 * np.pi * np.cumsum(f) / SR)
    return s * (np.exp(-t / decay) if decay else 1)


def bell(f, dur=1.2, partials=((1, 1), (2.76, 0.4), (5.4, 0.2), (8.9, 0.08))):
    t = t_arr(dur)
    return sum(a * np.sin(2 * np.pi * f * p * t) * np.exp(-t / (dur / (1 + p * 0.6))) for p, a in partials) * env(t, 0.002, 10)


def noise(dur):
    return rng.standard_normal(int(dur * SR))


def whoosh(dur=0.45, lo=300, hi=4000, rev=False):
    t = t_arr(dur)
    n = noise(dur)
    out = np.zeros_like(n)
    steps = 24
    L = len(n) // steps
    for i in range(steps):
        p = i / steps
        p = 1 - p if rev else p
        fc = lo * (hi / lo) ** p
        seg = slice(i * L, (i + 1) * L if i < steps - 1 else len(n))
        out[seg] = bp(n, max(60, fc * 0.6), min(18000, fc * 1.6))[seg]
    e = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    return out * e


def S_tap():
    t = t_arr(0.05)
    return np.sin(2 * np.pi * 1700 * t) * np.exp(-t / 0.008) * 0.6 + hp(noise(0.05), 3000) * np.exp(-t / 0.003) * 0.3


def S_pop():
    return sine_sweep(380, 980, 0.09, 0.035)


def S_key():
    t = t_arr(0.03)
    return hp(noise(0.03), 2500) * np.exp(-t / 0.004)


def S_success():
    out = np.zeros(int(1.4 * SR))
    for i, n in enumerate((84, 88, 91, 96)):
        b = bell(note(n), 1.0)
        out[int(i * 0.07 * SR):int(i * 0.07 * SR) + len(b)] += b * 0.5
    return out


def S_cash():
    out = np.zeros(int(1.5 * SR))
    for i, base in enumerate((2093, 2637)):
        b = bell(base, 1.2, ((1, 1), (1.34, 0.6), (1.73, 0.5), (2.41, 0.3), (3.3, 0.2)))
        out[int(i * 0.11 * SR):int(i * 0.11 * SR) + len(b)] += b * 0.45
    t = t_arr(0.4)
    coins = hp(noise(0.4), 5000) * np.exp(-t / 0.12) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 23 * t)))
    out[:len(coins)] += coins * 0.25
    return out


def S_print(dur):
    t = t_arr(dur)
    motor = np.sign(np.sin(2 * np.pi * 190 * t)) * (0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 24 * t)))
    s = bp(motor, 250, 2500) * 0.5 + bp(noise(dur), 1500, 6000) * 0.12
    return s * env(t, 0.02, 10, 1, 0.05, dur)


def S_error():
    t = t_arr(0.36)
    s = np.sign(np.sin(2 * np.pi * 140 * t)) * ((t < 0.14) | ((t > 0.19) & (t < 0.33)))
    return lp(s, 1800) * 0.55


def S_notif():
    out = np.zeros(int(0.9 * SR))
    for i, n in enumerate((83, 88)):
        b = bell(note(n), 0.6)
        out[int(i * 0.12 * SR):int(i * 0.12 * SR) + len(b)] += b * 0.5
    return out


def S_impact(big=True):
    t = t_arr(2.0)
    boom = sine_sweep(110, 38, 2.0) * np.exp(-t / (0.5 if big else 0.25))
    crack = hp(noise(2.0), 1500) * np.exp(-t / 0.08)
    return np.tanh((boom * 1.2 + crack * 0.5) * 1.3)


def S_hit():
    t = t_arr(0.45)
    return np.tanh(KICK[:len(t)] * 1.3 + bp(noise(0.45), 800, 5000) * np.exp(-t / 0.05) * 0.6)


def S_riser(dur):
    t = t_arr(dur)
    s = whoosh(dur, 200, 9000) * (t / dur) ** 1.5 * 1.4
    s += sine_sweep(200, 1600, dur) * (t / dur) ** 2 * 0.2
    return s


def S_scratch():
    t = t_arr(0.35)
    f = 900 + 700 * np.sin(2 * np.pi * 9 * t)
    s = bp(noise(0.35), 400, 3000) * (0.6 + 0.4 * np.sin(np.cumsum(2 * np.pi * f / SR)))
    return s * env(t, 0.005, 0.2)


def S_power(down):
    t = t_arr(0.6)
    f0, f1 = (700, 50) if down else (60, 900)
    sw = sine_sweep(f0, f1, 0.6)
    hum = np.sin(2 * np.pi * 100 * t) * 0.3
    e = np.exp(-t / 0.35) if down else np.clip(t / 0.4, 0, 1) * np.exp(-np.clip(t - 0.4, 0, None) / 0.05)
    return lp(sw + hum, 3000) * e


def S_truck():
    t = t_arr(0.9)
    rum = lp(noise(0.9), 180) * 3 * (0.7 + 0.3 * np.sin(2 * np.pi * 11 * t))
    horn = (np.sign(np.sin(2 * np.pi * 330 * t)) + np.sign(np.sin(2 * np.pi * 415 * t))) * ((t > 0.45) & (t < 0.6) | (t > 0.68) & (t < 0.83))
    return rum * env(t, 0.05, 10, 1, 0.2, 0.9) + lp(horn, 2500) * 0.18


def S_thud():
    t = t_arr(0.3)
    return sine_sweep(140, 55, 0.3) * np.exp(-t / 0.08) + lp(noise(0.3), 600) * np.exp(-t / 0.03) * 0.5


def S_lock():
    t = t_arr(0.15)
    c = hp(noise(0.15), 2000) * (np.exp(-t / 0.004) + 0.7 * np.where(t > 0.05, np.exp(-(t - 0.05) / 0.006), 0))
    return c + np.sin(2 * np.pi * 220 * t) * np.exp(-t / 0.03) * 0.4


def S_tick():
    t = t_arr(0.06)
    return np.sin(2 * np.pi * 2400 * t) * np.exp(-t / 0.012)


def S_blip():
    t = t_arr(0.12)
    return np.sin(2 * np.pi * 1320 * t) * np.exp(-t / 0.04)


def S_count(dur):
    out = np.zeros(int((dur + 0.1) * SR))
    t = 0.0
    k = 0
    while t < dur:
        tk = S_tick() * 0.6
        i = int(t * SR)
        out[i:i + len(tk)] += tk[: len(out) - i]
        k += 1
        t += 0.035 + 0.06 * (t / dur) ** 2
    return out


def S_toggle():
    a, b = S_tap() * 0.8, S_pop() * 0.4
    out = np.zeros(max(len(a), len(b)))
    out[:len(a)] += a
    out[:len(b)] += b
    return out


def S_qr():
    out = np.zeros(int(0.5 * SR))
    for i in range(3):
        b = S_blip()
        out[int(i * 0.08 * SR):int(i * 0.08 * SR) + len(b)] += b * (0.5 + 0.2 * i)
    return out


def S_save():
    out = np.zeros(int(0.9 * SR))
    for i, n in enumerate((76, 81)):
        b = bell(note(n), 0.7)
        out[int(i * 0.1 * SR):int(i * 0.1 * SR) + len(b)] += b * 0.4
    return out


GAIN = dict(tap=0.35, pop=0.3, key=0.18, whoosh=0.42, swish=0.32, sheet=0.25, success=0.4, cash=0.5, print=0.22,
            error=0.32, notif=0.45, impact=0.8, hit=0.6, riser=0.45, drop=0.9, scratch=0.4, powerdown=0.55, powerup=0.45,
            truck=0.45, thud=0.45, lock=0.4, tick=0.16, blip=0.2, count=0.2, toggle=0.35, qr=0.3, save=0.4, ding=0.4)
for ev in D['sfx']:
    ty, t = ev['type'], ev['t']
    g = GAIN.get(ty, 0.3)
    pan = 0.0
    if ty == 'tap': s = S_tap(); pan = 0.15
    elif ty == 'pop': s = S_pop()
    elif ty == 'key': s = S_key(); pan = 0.2
    elif ty == 'whoosh': s = whoosh(0.5, 250, 6000); t -= 0.15
    elif ty == 'swish': s = whoosh(0.32, 600, 8000)
    elif ty == 'swoosh-up': s = whoosh(0.4, 400, 7000)
    elif ty == 'sheet': s = whoosh(0.3, 200, 2500)
    elif ty == 'success': s = S_success(); add(verb_send, s, t, 0.3)
    elif ty == 'cash': s = S_cash(); add(verb_send, s, t, 0.3)
    elif ty == 'print': s = S_print(ev.get('dur', 2.0)); pan = 0.5
    elif ty == 'error': s = S_error()
    elif ty == 'notif': s = S_notif(); add(verb_send, s, t, 0.2)
    elif ty == 'impact': s = S_impact(); add(verb_send, s, t, 0.4)
    elif ty == 'drop': s = S_impact(); add(verb_send, s, t, 0.4)
    elif ty == 'hit': s = S_hit()
    elif ty == 'riser': s = S_riser(ev.get('dur', 1.8))
    elif ty == 'scratch': s = S_scratch()
    elif ty == 'powerdown': s = S_power(True)
    elif ty == 'powerup': s = S_power(False)
    elif ty == 'truck': s = S_truck(); pan = 0.3
    elif ty == 'thud': s = S_thud()
    elif ty == 'lock': s = S_lock(); pan = 0.35
    elif ty == 'tick': s = S_tick()
    elif ty == 'blip': s = S_blip(); pan = -0.2
    elif ty == 'count': s = S_count(ev.get('dur', 1.2))
    elif ty == 'toggle': s = S_toggle()
    elif ty == 'qr': s = S_qr()
    elif ty == 'save': s = S_save()
    elif ty == 'ding': s = bell(note(88), 0.8) * 0.6
    else: continue
    add(fx, s, t, g, pan)

# ---------------------------------------------------------------- mixdown
ir_t = t_arr(1.6)
ir = np.stack([rng.standard_normal(len(ir_t)) * np.exp(-ir_t / 0.35) for _ in range(2)])
ir[:, : int(0.012 * SR)] = 0
verb = np.stack([fftconvolve(lp(hp(verb_send[c], 300), 6000), ir[c])[:N] for c in range(2)]) * 0.025

mix = music * 0.8 + verb + fx * 1.0
# fades
fi = int(0.02 * SR)
mix[:, :fi] *= np.linspace(0, 1, fi)
end = int(DUR * SR)
fo = int(1.2 * SR)
mix[:, end - fo:end] *= np.linspace(1, 0, fo) ** 1.5
mix[:, end:] = 0
mix = mix[:, :end]
mix /= np.max(np.abs(mix)) + 1e-9
mix = np.tanh(mix * 1.5) / np.tanh(1.5) * 0.89
wavfile.write('audio.wav', SR, (mix.T * 32767).astype(np.int16))
print('audio.wav', mix.shape[1] / SR, 's')
