"""Quiet, original psychological-horror cues. Python standard library only.

Only writes the horror clips; existing music and ambience are untouched.
"""
import math
from generate_assets import ROOT, wav


def generate():
    (ROOT / 'audio').mkdir(parents=True, exist_ok=True)

    def drone(t, rng):
        # Frequencies and modulation complete whole cycles in eight seconds.
        breath = 0.72 + 0.28 * math.cos(math.tau * t / 8)
        return breath * (0.075 * math.sin(math.tau * 48 * t)
                         + 0.040 * math.sin(math.tau * 48.375 * t)
                         + 0.022 * math.sin(math.tau * 96.125 * t))

    def steps(t, rng):
        value = 0.0
        for at in (0.18, 1.00, 1.91):
            u = t - at
            if 0 <= u < 0.38:
                attack = min(1.0, u / 0.018)
                value += attack * (math.sin(math.tau * 94 * u) * math.exp(-u * 19) * 0.22
                                   + rng.uniform(-1, 1) * math.exp(-u * 28) * 0.085)
        return value

    def creak(t, rng):
        envelope = math.sin(math.pi * t / 3.8) ** 2
        phase = math.tau * (126 * t - 5.0 * t * t + 0.3 * math.sin(t * 4))
        return envelope * (math.sin(phase) * 0.095 + math.sin(phase * 2.03) * 0.025
                           + rng.uniform(-1, 1) * 0.009)

    wav('horror_drone', 8.0, drone)
    wav('horror_steps', 2.8, steps)
    wav('horror_creak', 3.8, creak)

    def sting(t, rng):
        envelope = min(1.0, t / 0.008) * math.exp(-t * 5.5)
        bass = math.sin(math.tau * (72 * t - 16 * t * t)) * 0.27
        scrape = math.sin(math.tau * (530 * t + 150 * t * t)) * 0.12
        return envelope * (bass + scrape + rng.uniform(-1, 1) * 0.11)

    wav('horror_sting', 1.05, sting)
    print('Generated horror_drone, horror_steps, horror_creak, horror_sting.')


if __name__ == '__main__':
    generate()
