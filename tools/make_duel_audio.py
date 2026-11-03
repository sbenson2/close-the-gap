"""Reproduce the project's original pebble and reload effects, using only stdlib."""
import math
from pathlib import Path
import random
import struct
import wave

OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
RATE = 44100


def write(name, seconds, pulses):
    rng = random.Random(177)
    samples = []
    previous = 0.0
    for index in range(round(seconds * RATE)):
        t = index / RATE
        noise = rng.uniform(-1, 1)
        high = noise - previous * 0.8
        previous = noise
        value = 0.0
        for start, gain, decay, frequency in pulses:
            age = t - start
            if age >= 0:
                value += gain * math.exp(-age * decay) * (
                    high * 0.48 + math.sin(age * frequency * math.tau) * 0.52)
        samples.append(max(-0.95, min(0.95, value)))
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as output:
        output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes(struct.pack(f'<{len(samples)}h', *(round(value * 32767) for value in samples)))


def ambient(name, seconds, smoothing):
    rng = random.Random(9103)
    previous = 0.0
    values = []
    for i in range(round(seconds * RATE)):
        previous = smoothing * previous + (1 - smoothing) * rng.uniform(-1, 1)
        values.append(round(max(-0.9, min(0.9, previous * 2.4)) * 32767))
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as output:
        output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes(struct.pack(f'<{len(values)}h', *values))


if __name__ == '__main__':
    write('pebble', 0.48, [(0, 0.55, 85, 1650), (0.052, 0.23, 80, 2200), (0.14, 0.11, 70, 1850)])
    write('reload', 0.95, [(0, 0.45, 42, 310), (0.24, 0.33, 32, 480),
                           (0.56, 0.5, 52, 680), (0.79, 0.35, 70, 1150)])
    write('step_wood', 0.35, [(0,.6,28,170),(.045,.22,40,510)])
    write('step_gravel', 0.38, [(0,.4,30,770),(.055,.18,35,1300)])
    write('step_brush', 0.45, [(0,.24,18,1450),(.08,.14,20,2200)])
    write('step_mud', 0.38, [(0,.5,18,110),(.075,.14,24,230)])
    write('alarm', 1.2, [(0,.6,4,880),(.3,.38,5,1170),(.6,.25,6,880)])
    write('relay', 0.75, [(0,.4,14,460),(.2,.3,16,690),(.4,.25,18,920)])
    ambient('wind', 5, .94)
    ambient('rain', 5, .25)
