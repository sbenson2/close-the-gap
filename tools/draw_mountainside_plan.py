"""Draw the measured terrain and authored routes; no invented geometry."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/mountainside'
data = json.loads((OUT / 'nav-audit.json').read_text())
cells = {(p[0], p[1]): p for p in data['cells']}
image = Image.new('RGB', (1000, 940), '#ebece3')
draw = ImageDraw.Draw(image)
font_path = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
small = ImageFont.truetype(font_path, 15)
body = ImageFont.truetype(font_path, 17)
title = ImageFont.truetype(font_path, 27)

def point(x, z):
    return (64 + (x + 34) * 8, 122 + (z + 44) * 8)

draw.text((50, 32), "Crow's Ridge / mountainside plan", fill='#20372c', font=title)
draw.text((50, 76), 'Actual height field · 2 m contours · north/uphill at top', fill='#415d4b', font=body)
for (x, z), p in cells.items():
    t = max(0, min(1, p[2] / 31))
    color = tuple(round(a + (b - a) * t) for a, b in zip((87, 119, 94), (203, 197, 158)))
    a, b = point(x, z), point(x + 1, z + 1)
    draw.rectangle((*a, *b), fill=color)

# Marching triangle contours follow the same diagonal as the Godot terrain.
for z in range(-44, 44):
    for x in range(-34, 34):
        corners = [(x, z), (x + 1, z), (x, z + 1), (x + 1, z + 1)]
        for indices in [(0, 1, 2), (1, 3, 2)]:
            triangle = [corners[i] for i in indices]
            heights = [cells[p][2] for p in triangle]
            for level in range(2, 36, 2):
                crossings = []
                for i, j in [(0, 1), (1, 2), (2, 0)]:
                    a, b = heights[i], heights[j]
                    if (a <= level < b) or (b <= level < a):
                        t = (level - a) / (b - a)
                        crossings.append(point(triangle[i][0] + (triangle[j][0] - triangle[i][0]) * t,
                                               triangle[i][1] + (triangle[j][1] - triangle[i][1]) * t))
                if len(crossings) == 2:
                    draw.line(crossings, fill='#728369', width=1)

for a, b in data['edges']:
    start, finish = data['nests'][a], data['nests'][b]
    draw.line([point(start[0], start[2]), point(finish[0], finish[2])], fill='#314c43', width=34)
    draw.line([point(start[0], start[2]), point(finish[0], finish[2])], fill='#dec897', width=4)
for route in data['flanks']:
    draw.line([point(p[0], p[2]) for p in route], fill='#f5eee0', width=5)
for i, (x, height, z) in enumerate(data['nests']):
    cx, cy = point(x, z)
    draw.ellipse((cx - 32, cy - 32, cx + 32, cy + 32), outline='#314c43', width=3)
    draw.ellipse((cx - 15, cy - 15, cx + 15, cy + 15), fill='#d29157', outline='#2b3e31', width=2)
    draw.text((cx, cy), str(i + 1), fill='#192c22', font=body, anchor='mm')
    draw.text((672, 158 + i * 71), f'{i + 1}  {data["names"][i]}', fill='#20372c', font=body)
    draw.text((699, 185 + i * 71), f'{height:g} m elevation', fill='#50664f', font=small)
draw.text((670, 682), 'Dark band: sniper contour', fill='#20372c', font=small)
draw.text((670, 709), 'Pale lines: stalking ascents', fill='#20372c', font=small)
draw.text((670, 754), 'Lower central drainage', fill='#20372c', font=small)
draw.text((670, 779), 'Screens and logs at each nest', fill='#20372c', font=small)
draw.text((50, 878), 'Both roles use the same terrain. The sniper can move between all seven outlooks.', fill='#20372c', font=body)
image.save(OUT / 'layout.png')
print(OUT / 'layout.png')
