"""Deterministic original textures and ambience. Python 3; no dependencies."""
from pathlib import Path
import math
import random
import struct
import wave
import zlib

ROOT = Path(__file__).resolve().parents[1] / "assets"


def png(path, width, height, pixels, channels=3):
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))
    scan = b''.join(b'\0' + bytes(pixels[y * width * channels:(y + 1) * width * channels]) for y in range(height))
    head = struct.pack('!2I5B', width, height, 8, 6 if channels == 4 else 2, 0, 0, 0)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', head) + chunk(b'IDAT', zlib.compress(scan, 8)) + chunk(b'IEND', b''))


def textures():
    rng = random.Random(717)
    n = 512
    maps = {name: bytearray() for name in ['walnut', 'velvet', 'carpet', 'plaster', 'brass']}
    for y in range(n):
        for x in range(n):
            jitter = rng.uniform(-1, 1)
            drift = math.sin(y * math.tau / n) * 4 + math.sin(y * math.tau * 3 / n + x * .012) * 2
            grain = math.sin((x + drift) * math.tau * 34 / n) * .055
            grain += math.sin((x + drift * .3) * math.tau * 91 / n) * .025
            grain += math.sin((x + drift) * math.tau * 6 / n) * .075 + jitter * .035
            for c in (72, 47, 32):
                maps['walnut'].append(int(max(0, min(255, c * (1 + grain)))))
            weave = ((x % 3 == 0) - (y % 3 == 0)) * 2 + jitter * 5
            for c in (35, 76, 68):
                maps['velvet'].append(int(max(0, c + weave)))
            diamond = min((x + y) % 64, (x - y) % 64)
            stitch = 8 if diamond < 2 else 0
            for c in (26 + stitch * 1.5, 43 + stitch, 42 + stitch * .65):
                maps['carpet'].append(int(max(0, c + jitter * 3)))
            for c in (154, 145, 128):
                maps['plaster'].append(int(c + jitter * 6))
            for c in (160, 126, 73):
                maps['brass'].append(int(c + jitter * 9 + math.sin(y * 12) * 5))
    for name, data in maps.items():
        png(ROOT / 'textures' / (name + '.png'), n, n, data)
    sprite = bytearray()
    for y in range(32):
        for x in range(32):
            d = math.hypot(x - 15.5, y - 15.5) / 15.5
            sprite.extend((220, 236, 255, int(max(0, 1 - d) ** 1.8 * 210)))
    png(ROOT / 'textures' / 'snow.png', 32, 32, sprite, 4)


def wav(name, seconds, synth):
    rate = 22050
    rng = random.Random(407)
    data = bytearray()
    for i in range(int(seconds * rate)):
        t = i / rate
        value = synth(t, rng)
        edge = min(1, t / .03, (seconds - t) / .03)
        data.extend(struct.pack('<h', int(max(-1, min(1, value * edge)) * 32767)))
    with wave.open(str(ROOT / 'audio' / (name + '.wav')), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(data)


def audio():
    filtered = [0.0]
    def rail(t, rng):
        filtered[0] = filtered[0] * .95 + rng.uniform(-1, 1) * .05
        rumble = math.sin(math.tau * 47 * t) * .045 + math.sin(math.tau * 71 * t) * .023
        beat = (t % .82)
        click = math.exp(-beat * 54) * math.sin(t * 730) * .18
        second = math.exp(-((t - .15) % .82) * 60) * math.sin(t * 990) * .11
        return filtered[0] * .55 + rumble + click + second
    wav('rail', 8.2, rail)
    low = [0.0]
    def wind(t, rng):
        low[0] = low[0] * .982 + rng.uniform(-1, 1) * .018
        return low[0] * (1.4 + math.sin(math.tau * t / 10) * .4)
    wav('wind', 10, wind)
    wav('step', .22, lambda t, r: r.uniform(-1, 1) * math.exp(-t * 25) * .28 + math.sin(t * 340) * math.exp(-t * 40) * .12)
    wav('touch', .23, lambda t, r: (math.sin(t * 1800) * .14 + r.uniform(-1, 1) * .09) * math.exp(-t * 30))
    notes = [523.25, 659.25, 783.99, 523.25]
    def chime(t, rng):
        index = min(3, int(t / .52))
        u = t - index * .52
        return math.sin(math.tau * notes[index] * t) * math.exp(-u * 5) * .17
    wav('chime', 2.8, chime)


if __name__ == '__main__':
    (ROOT / 'textures').mkdir(parents=True, exist_ok=True)
    (ROOT / 'audio').mkdir(parents=True, exist_ok=True)
    textures()
    audio()
    print('Generated 6 textures and 5 audio clips.')
