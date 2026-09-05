#!/usr/bin/env python3
"""
Synthesise original sound effects for the SettlersGM "borntodie" cheat.

Everything is generated from noise and oscillators here; no sample is taken
from any commercial game. Output is 22050 Hz mono, matching the scale of the
project's existing extracted Amiga samples.
"""
import os
import numpy as np
from scipy.signal import butter, lfilter, sosfilt

SR = 22050
rng = np.random.default_rng(20260904)


def t(dur):
    return np.arange(int(SR * dur)) / SR


def noise(dur):
    return rng.uniform(-1.0, 1.0, int(SR * dur))


def env(x, attack, decay, curve=2.0):
    """Percussive envelope: fast attack, exponential-ish decay."""
    n = len(x)
    a = max(1, int(SR * attack))
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    d = np.linspace(0, 1, n - a)
    e[a:] = (1.0 - d) ** curve
    return x * e


def lowpass(x, hz, order=4):
    sos = butter(order, min(hz / (SR / 2), 0.99), btype='low', output='sos')
    return sosfilt(sos, x)


def highpass(x, hz, order=4):
    sos = butter(order, min(hz / (SR / 2), 0.99), btype='high', output='sos')
    return sosfilt(sos, x)


def bandpass(x, lo, hi, order=4):
    sos = butter(order, [min(lo / (SR / 2), 0.98), min(hi / (SR / 2), 0.99)],
                 btype='band', output='sos')
    return sosfilt(sos, x)


def normalise(x, peak=0.86):
    m = np.max(np.abs(x))
    if m < 1e-9:
        return x
    return x * (peak / m)


def sweep(dur, f0, f1, curve=1.0):
    tt = t(dur)
    k = (tt / max(tt[-1], 1e-9)) ** curve
    f = f0 + (f1 - f0) * k
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


# --------------------------------------------------------------- weapons
def rifle():
    """Sharp crack: a bright noise transient, a body thump, a short tail."""
    crack = env(highpass(noise(0.05), 1800), 0.0005, 0.05, curve=4.0)
    body = env(bandpass(noise(0.10), 220, 1400), 0.001, 0.10, curve=3.0) * 0.9
    thump = env(sweep(0.09, 190, 55, curve=0.5), 0.001, 0.09, curve=3.0) * 0.55
    tail = env(lowpass(noise(0.18), 900), 0.02, 0.18, curve=2.5) * 0.16
    out = np.zeros(int(SR * 0.20))
    for part in (crack, body, thump, tail):
        out[:len(part)] += part
    return normalise(out)


def grenade_throw():
    """Cloth-and-air whoosh, rising then falling as it arcs away."""
    d = 0.42
    n = bandpass(noise(d), 300, 3000)
    tt = np.linspace(0, 1, len(n))
    shape = np.sin(np.pi * tt) ** 1.6
    doppler = 1.0 - 0.35 * tt
    out = n * shape * doppler
    pin = env(highpass(noise(0.03), 4000), 0.0005, 0.03, curve=5.0) * 0.5
    out[:len(pin)] += pin
    return normalise(out, 0.55)


def explosion():
    """Grenade burst: crack, low boom, long debris rumble."""
    d = 1.1
    out = np.zeros(int(SR * d))
    crack = env(highpass(noise(0.06), 2500), 0.0003, 0.06, curve=5.0) * 0.8
    boom = env(lowpass(noise(0.55), 260), 0.002, 0.55, curve=2.2)
    sub = env(sweep(0.5, 140, 34, curve=0.4), 0.002, 0.5, curve=2.0) * 0.85
    rumble = env(lowpass(noise(1.05), 600), 0.05, 1.05, curve=1.8) * 0.30
    for part in (crack, boom, sub, rumble):
        out[:len(part)] += part
    return normalise(out)


def fire_loop():
    """Crackling fire bed, seamless enough to loop under a burning building."""
    d = 2.4
    bed = lowpass(noise(d), 1500) * 0.30
    bed += bandpass(noise(d), 200, 700) * 0.22
    out = bed
    # scattered crackles
    for _ in range(90):
        pos = int(rng.uniform(0, d - 0.05) * SR)
        ln = int(rng.uniform(0.004, 0.030) * SR)
        c = env(highpass(noise(ln / SR), rng.uniform(1500, 5000)),
                0.0005, ln / SR, curve=4.0)
        out[pos:pos + len(c)] += c * rng.uniform(0.15, 0.75)
    # cross-fade the ends so it loops without a seam
    xf = int(0.15 * SR)
    ramp = np.linspace(0, 1, xf)
    out[:xf] = out[:xf] * ramp + out[-xf:] * (1 - ramp)
    out = out[:-xf]
    return normalise(out, 0.55)


# --------------------------------------------------------------- voices
def voice(f0, dur, formants, bend=-0.25, rasp=0.35, attack=0.008, curve=2.0):
    """
    Crude two-formant vocal synth: a buzzing glottal pulse train pushed through
    band-pass formants. Deliberately rough - it wants to sound like a 16-pixel
    soldier, not a recorded human.
    """
    tt = t(dur)
    k = tt / max(tt[-1], 1e-9)
    f = f0 * (1.0 + bend * k)
    phase = 2 * np.pi * np.cumsum(f) / SR
    # glottal-ish pulse: narrow positive spikes
    glottis = np.clip(np.sin(phase), 0, 1) ** 3.0
    glottis = glottis - glottis.mean()
    src = glottis + rasp * noise(dur) * 0.5
    out = np.zeros_like(src)
    for hz, bw, amp in formants:
        out += bandpass(src, max(80, hz - bw), hz + bw) * amp
    return env(out, attack, dur, curve=curve)


def hurt_a():
    """Short winded grunt - 'uh'."""
    v = voice(148, 0.26, [(640, 180, 1.0), (1180, 300, 0.55), (2500, 600, 0.18)],
              bend=-0.30, rasp=0.45, curve=2.6)
    return normalise(v, 0.75)


def hurt_b():
    """Higher, sharper - 'agh', so hits do not all sound identical."""
    v = voice(196, 0.30, [(780, 200, 1.0), (1450, 340, 0.60), (2900, 700, 0.22)],
              bend=-0.42, rasp=0.55, curve=2.2)
    return normalise(v, 0.75)


def death_cry():
    """Longer falling cry that trails off into breath."""
    v = voice(210, 0.62, [(720, 220, 1.0), (1300, 340, 0.65), (2700, 700, 0.25)],
              bend=-0.62, rasp=0.5, attack=0.012, curve=1.5)
    breath = env(bandpass(noise(0.30), 400, 2600), 0.05, 0.30, curve=1.6) * 0.22
    out = np.zeros(int(SR * 0.74))
    out[:len(v)] += v
    out[-len(breath):] += breath
    return normalise(out, 0.8)


# --------------------------------------------------------------- build
SOUNDS = {
    "snd_cf_rifle": rifle,
    "snd_cf_grenade": grenade_throw,
    "snd_cf_explosion": explosion,
    "snd_cf_fire": fire_loop,
    "snd_cf_hurt1": hurt_a,
    "snd_cf_hurt2": hurt_b,
    "snd_cf_death": death_cry,
}


def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cf_build", "sfx")
    os.makedirs(out, exist_ok=True)
    for name, fn in SOUNDS.items():
        x = fn().astype(np.float32)
        # short fades so nothing clicks on start/stop
        f = min(64, len(x) // 8)
        x[:f] *= np.linspace(0, 1, f)
        x[-f:] *= np.linspace(1, 0, f)
        pcm = np.clip(x, -1, 1)
        raw = (pcm * 32767).astype("<i2").tobytes()
        wav = os.path.join(out, name + ".wav")
        import wave
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(raw)
        print("%-20s %5.2f s" % (name, len(x) / SR))


if __name__ == "__main__":
    main()
