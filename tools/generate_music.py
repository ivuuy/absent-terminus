"""Render the original 'A Light in the Snow' loop using only Python 3.

66 BPM, 3/4, 24 bars. Felt piano, a slightly imperfect music box and warm
bowed-glass chords: a familiar lullaby with a little uncertainty at its edges.
Every note and echo wraps into the beginning, preserving the reverb at the seam.
"""
from array import array
from pathlib import Path
import math
import random
import sys
import wave


RATE = 44100
BEAT = 60 / 66
BAR = BEAT * 3
FRAMES = round(24 * BAR * RATE)
OUTPUT = Path(__file__).resolve().parents[1] / "assets/audio/snow_lullaby.wav"


def render_music():
    left = array("f", [0.0]) * FRAMES
    right = array("f", [0.0]) * FRAMES
    rng = random.Random(71707)
    sin, exp, tau = math.sin, math.exp, math.tau

    def voice(start, midi, seconds, gain, pan, instrument):
        frequency = 440 * 2 ** ((midi - 69) / 12)
        step = tau * frequency / RATE
        offset = round(start * RATE) % FRAMES
        count = round(seconds * RATE)
        gain_l = gain * math.sqrt((1 - pan) * 0.5)
        gain_r = gain * math.sqrt((1 + pan) * 0.5)
        phase = rng.uniform(0, tau)
        for i in range(count):
            t = i / RATE
            angle = step * i
            # The release reaches zero before each voice's final sample.
            release = min(1.0, (count - 1 - i) / (RATE * 0.45))
            if instrument == "felt":
                attack = 1 - exp(-t * 65)
                sample = sin(angle) * exp(-t * 1.12)
                sample += 0.27 * sin(angle * 2.001) * exp(-t * 1.9)
                sample += 0.09 * sin(angle * 3.003) * exp(-t * 3.1)
                sample += 0.025 * sin(angle * 6.008) * exp(-t * 7.0)
                sample *= attack
            elif instrument == "box":
                attack = 1 - exp(-t * 95)
                sample = sin(angle) * exp(-t * 1.05)
                sample += 0.20 * sin(angle * 2.002) * exp(-t * 1.7)
                sample += 0.10 * sin(angle * 3.996) * exp(-t * 2.5)
                sample += 0.035 * sin(angle * 6.012) * exp(-t * 4.2)
                # A very quiet, four-cent detuned tine gives the old box a wobble.
                sample += 0.13 * sin(angle * 1.0023) * exp(-t * 1.3)
                sample *= attack
            else:
                attack = min(1.0, t / 1.25)
                tail = min(1.0, (count - 1 - i) / (RATE * 1.65))
                envelope = sin(attack * math.pi / 2) ** 2
                envelope *= sin(tail * math.pi / 2) ** 2
                drift = 0.07 * sin(tau * 0.23 * t + phase)
                sample = sin(angle + drift)
                sample += 0.28 * sin(angle * 1.0014 - drift)
                sample += 0.12 * sin(angle * 2 + phase)
                sample *= envelope * (0.93 + 0.07 * sin(tau * 0.16 * t + phase))
            sample *= release
            index = (offset + i) % FRAMES
            left[index] += sample * gain_l
            right[index] += sample * gain_r

    # Cmaj9 - Am9 - Fmaj7 - C/E - Dm9 - Am/E - Fmaj7 - G6.
    # Open voicings and added seconds keep the harmony tender but unresolved.
    harmony = [
        (48, (55, 59, 64)), (45, (55, 60, 64)),
        (41, (57, 60, 64)), (40, (55, 60, 62)),
        (38, (53, 57, 64)), (40, (57, 59, 64)),
        (41, (57, 60, 64)), (43, (55, 59, 64)),
    ]
    melody = [
        ((0.15, 76), (1.25, 79), (2.15, 83)),
        ((0.20, 81), (1.80, 76)),
        ((0.45, 79), (1.55, 76), (2.40, 72)),
        ((0.15, 74), (1.20, 76), (2.35, 78)),
        ((0.30, 77), (1.55, 76), (2.40, 74)),
        ((0.20, 76), (1.65, 71), (2.45, 69)),
        ((0.40, 72), (1.55, 76), (2.45, 71)),
        ((0.20, 74), (1.45, 69), (2.35, 67)),
    ]
    for bar in range(24):
        phrase, chord = divmod(bar, 8)
        start = bar * BAR
        root, notes = harmony[chord]
        # Close, low piano notes give the tune a steady, rocking three-beat pulse.
        voice(start + 0.02, root, 3.5, 0.135, -0.20, "felt")
        voice(start + BEAT * 1.03, notes[0], 2.8, 0.072, 0.12, "felt")
        voice(start + BEAT * 2.02, notes[1], 2.5, 0.052, -0.08, "felt")
        for j, note in enumerate(notes):
            voice(start - 0.35, note, BAR + 1.6, 0.025,
                  (-0.58, 0.48, -0.12)[j], "glass")
        for j, (beat, note) in enumerate(melody[chord]):
            # The middle phrase answers an octave lower; the last leaves more air.
            if phrase == 2 and chord in (1, 5) and j == 1:
                continue
            pitch = note - (12 if phrase == 1 else 0)
            onset = start + beat * BEAT + rng.uniform(-0.018, 0.018)
            gain = (0.083 if phrase == 1 else 0.095) * rng.uniform(0.88, 1.06)
            voice(onset, pitch, 4.0, gain, rng.uniform(-0.32, 0.32), "box")
        if phrase == 2 and chord in (0, 3, 6):
            voice(start + 1.65 * BEAT, notes[2] + 12, 3.4, 0.032, -0.42, "felt")
        print("Composed bar %d/24" % (bar + 1), flush=True)

    # Filter before the room reflections so even the upper tines stay soft.
    for channel in (left, right):
        previous = 0.0
        # Warm up the filter from the end of the loop, avoiding a startup edge.
        for value in channel[-4096:]:
            previous += 0.24 * (value - previous)
        for i in range(FRAMES):
            previous += 0.24 * (channel[i] - previous)
            channel[i] = previous

    wet_l, wet_r = array("f", left), array("f", right)
    for seconds, level in ((0.173, 0.14), (0.311, 0.115), (0.479, 0.09),
                           (0.719, 0.07), (1.137, 0.05), (1.813, 0.03)):
        delay = round(seconds * RATE)
        for i in range(FRAMES):
            source = (i - delay) % FRAMES
            wet_l[i] += right[source] * level
            wet_r[i] += left[source] * level

    peak = max(max(map(abs, wet_l)), max(map(abs, wet_r)))
    # Leave 3 dB of headroom; in-game gain sits beneath positional clues.
    scale = 10 ** (-3 / 20) / peak
    pcm = array("h")
    for l_value, r_value in zip(wet_l, wet_r):
        pcm.append(round(l_value * scale * 32767))
        pcm.append(round(r_value * scale * 32767))
    if sys.byteorder != "little":
        pcm.byteswap()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUTPUT), "wb") as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())
    print("Wrote %s (%.2f seconds, stereo, seamless loop)" % (OUTPUT, FRAMES / RATE))


if __name__ == "__main__":
    render_music()
