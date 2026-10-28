#!/usr/bin/env python3
"""Rebuild the original outpost kit: textured, atlas-batched GLBs, metres, Y up.

No Blender, downloaded meshes or third-party artwork required. Pillow is used
only to author the shared PBR atlas. Run from any directory with Python 3.
"""
from __future__ import annotations

import json
import math
from pathlib import Path
import random
import struct

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/outpost"
TILE = 128
COLS = 8
PATCHES = [
    ("olive", "#586044", .82, .15), ("dark_olive", "#343d30", .88, .10),
    ("canvas", "#697054", .98, .0), ("sand_canvas", "#a39670", .98, .0),
    ("steel", "#505d62", .45, .8), ("alloy", "#919994", .36, .88),
    ("rubber", "#23282a", .96, .0), ("glass", "#152e3a", .24, .4),
    ("white", "#bdc3b1", .72, .12), ("red", "#98433c", .74, .12),
    ("hazard", "#b9a052", .8, .1), ("crate", "#777e62", .88, .05),
    ("stone", "#97856a", .98, .0), ("gold", "#b69448", .4, .8),
    ("dark_stone", "#4c4c43", .98, .0), ("bronze", "#7d704c", .48, .7),
    ("blue_light", "#70c9df", .35, .1), ("amber_light", "#e2a04a", .4, .1),
    ("red_light", "#db5546", .4, .1), ("crystal", "#409a91", .3, .55),
    ("solar", "#263e50", .32, .55), ("vent", "#303a3b", .65, .6),
    ("tread", "#616862", .66, .7), ("sgc", "#434e3b", .8, .1),
    ("command", "#303e38", .8, .1), ("medical", "#c0c3af", .92, .0),
    ("warning", "#7f743c", .8, .1), ("earth", "#625849", .98, .0),
    ("sandbag", "#8c896b", .99, .0), ("wear", "#737a6b", .7, .2),
    ("glyph", "#927a42", .5, .65), ("scaffold", "#9b7946", .6, .6),
    ("lab", "#b0b9a7", .7, .12), ("power", "#4c5946", .8, .1),
    ("mining", "#857c54", .8, .2), ("medical_sign", "#a8b09c", .8, .05),
]
INDEX = {p[0]: i for i, p in enumerate(PATCHES)}
ROWS = math.ceil(len(PATCHES) / COLS)


def atlas() -> None:
    folder = OUT / "textures"
    folder.mkdir(parents=True, exist_ok=True)
    size = (COLS * TILE, ROWS * TILE)
    albedo = Image.new("RGB", size)
    normal = Image.new("RGB", size, (128, 128, 255))
    orm = Image.new("RGB", size)
    emission = Image.new("RGB", size)
    rng = random.Random(2087)
    font_path = str(ROOT / "assets/fonts/Rajdhani-Bold.ttf")
    for i, (name, color, roughness, metal) in enumerate(PATCHES):
        tile = Image.new("RGB", (TILE, TILE), color)
        base = tile.getpixel((0, 0))
        pixels = tile.load()
        for y in range(TILE):
            for x in range(TILE):
                noise = rng.uniform(-5, 5)
                if name in ("canvas", "sand_canvas", "sandbag"):
                    noise += (4 if x % 4 < 2 else -4) + (3 if y % 4 < 2 else -3)
                elif name in ("steel", "alloy", "gold", "bronze"):
                    noise += math.sin(y * 2.4) * 3
                elif name in ("stone", "dark_stone"):
                    noise += math.sin(x * .09 + math.sin(y * .07)) * 8
                pixels[x, y] = tuple(max(0, min(255, int(c + noise))) for c in base)
        d = ImageDraw.Draw(tile)
        if name == "hazard":
            for x in range(-TILE, TILE * 2, 38):
                d.polygon([(x, 0), (x + 17, 0), (x + 17 - TILE, TILE), (x - TILE, TILE)], fill="#30362f")
        elif name == "vent":
            for y in range(12, 120, 10):
                d.rectangle((10, y, 118, y + 5), fill="#151f22")
                d.line((12, y + 6, 116, y + 6), fill="#7b857b")
        elif name == "tread":
            for y in range(12, 120, 20):
                for x in range(12, 120, 20):
                    d.line((x, y, x + 8, y - 6), fill="#899080", width=2)
        elif name == "solar":
            for x in range(12, 120, 18):
                d.line((x, 10, x, 118), fill="#6c8290")
            for y in range(12, 120, 22):
                d.line((10, y, 118, y), fill="#3f5363")
        elif name in ("glyph", "bronze"):
            for x in range(20, 110, 24):
                for y in range(15, 112, 27):
                    d.line((x, y, x + 8, y + 9, x - 2, y + 17, x + 10, y + 20), fill="#413f2b", width=2)
                    d.line((x + 10, y + 2, x + 10, y + 13), fill="#d7ba71", width=2)
        elif name == "sgc":
            d.ellipse((19, 16, 109, 106), outline="#c6cbb6", width=3)
            d.line((34, 78, 64, 34, 94, 78), fill="#c6cbb6", width=5)
            d.line((41, 68, 87, 68), fill="#c6cbb6", width=3)
            d.ellipse((61, 83, 67, 89), fill="#c6cbb6")
        elif name in ("medical", "medical_sign"):
            bg = "#e0dfc8" if name == "medical" else "#b8bfa7"
            d.rectangle((14, 14, 114, 114), fill=bg)
            d.rectangle((51, 29, 77, 99), fill="#a4453a")
            d.rectangle((29, 51, 99, 77), fill="#a4453a")
        elif name in ("command", "lab", "power", "mining", "warning"):
            words = {"command": ("SGC", "COMMAND"), "lab": ("SCIENCE", "FIELD LAB"),
                     "power": ("NAQUADAH", "POWER UNIT"), "mining": ("SGC", "EXTRACTION"),
                     "warning": ("CAUTION", "HIGH VOLTAGE")}[name]
            for y, text in zip((29, 69), words):
                font = ImageFont.truetype(font_path, 22 if len(text) > 9 else 27)
                box = d.textbbox((0, 0), text, font=font)
                d.text(((128 - (box[2] - box[0])) / 2, y), text, font=font, fill="#d2d3b7")
        # Subtle weathering: no source image or external decal is used.
        if name not in ("glass", "blue_light", "amber_light", "red_light", "crystal"):
            for _ in range(14):
                x, y = rng.randrange(10, 115), rng.randrange(10, 115)
                d.line((x, y, x + rng.randrange(2, 11), y + rng.randrange(-1, 2)), fill=tuple(int(c * .7) for c in base))
        offset = (i % COLS * TILE, i // COLS * TILE)
        albedo.paste(tile, offset)
        orm.paste(Image.new("RGB", (TILE, TILE), (255, int(roughness * 255), int(metal * 255))), offset)
        if name.endswith("_light"):
            emission.paste(Image.new("RGB", (TILE, TILE), base), offset)
        if name in ("canvas", "sand_canvas", "sandbag", "tread", "vent"):
            nd = ImageDraw.Draw(normal)
            ox, oy = offset
            for y in range(0, TILE, 4):
                nd.line((ox, oy + y, ox + TILE - 1, oy + y), fill=(128, 137, 254))
            for x in range(0, TILE, 4):
                nd.line((ox + x, oy, ox + x, oy + TILE - 1), fill=(137, 128, 254))
    for name, image in (("albedo", albedo), ("normal", normal), ("orm", orm), ("emission", emission)):
        image.save(folder / f"field_{name}.png", optimize=True)


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def unit(v):
    length = math.sqrt(sum(x * x for x in v))
    return tuple(x / length for x in v)


def transform(p, center, rotation):
    x, y, z = p
    for axis, angle in enumerate(rotation):
        c, s = math.cos(angle), math.sin(angle)
        if axis == 0:
            y, z = y * c - z * s, y * s + z * c
        elif axis == 1:
            x, z = x * c + z * s, -x * s + z * c
        else:
            x, y = x * c - y * s, x * s + y * c
    return add((x, y, z), center)


class Mesh:
    def __init__(self):
        self.positions, self.normals, self.uvs, self.indices = [], [], [], []

    def face(self, points, patch, normal=None):
        normal = normal or unit(cross(sub(points[1], points[0]), sub(points[2], points[0])))
        start = len(self.positions)
        i = INDEX[patch]
        u0, v0 = ((i % COLS * TILE + 8) / (COLS * TILE), (i // COLS * TILE + 8) / (ROWS * TILE))
        u1, v1 = ((i % COLS * TILE + 120) / (COLS * TILE), (i // COLS * TILE + 120) / (ROWS * TILE))
        uvs = [(u0, v1), (u1, v1), (u1, v0), (u0, v0)]
        for n, p in enumerate(points):
            self.positions.append(p)
            self.normals.append(normal)
            self.uvs.append(uvs[n % 4])
        for n in range(1, len(points) - 1):
            self.indices.extend((start, start + n, start + n + 1))

    def polygon(self, points, normal, patch):
        center = tuple(sum(p[a] for p in points) / len(points) for a in range(3))
        normal = unit(normal)
        u = unit(sub(points[0], center))
        v = cross(normal, u)
        points = sorted(points, key=lambda p: math.atan2(sum(x * y for x, y in zip(sub(p, center), v)),
                                                       sum(x * y for x, y in zip(sub(p, center), u))))
        self.face(points, patch, normal)

    def box(self, center, size, patch="olive", bevel=0, rotation=(0, 0, 0)):
        h = [s / 2 for s in size]
        b = min(bevel, min(h) * .8)
        def emit(points, normal):
            self.polygon([transform(p, center, rotation) for p in points], transform(normal, (0, 0, 0), rotation), patch)
        for a in range(3):
            other = [axis for axis in range(3) if axis != a]
            for sign in (-1, 1):
                points = []
                for sb, sc in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    p = [0, 0, 0]
                    p[a] = sign * h[a]
                    p[other[0]], p[other[1]] = sb * (h[other[0]] - b), sc * (h[other[1]] - b)
                    points.append(tuple(p))
                normal = [0, 0, 0]
                normal[a] = sign
                emit(points, normal)
        if b <= 0:
            return
        for a, bb in ((0, 1), (0, 2), (1, 2)):
            c = 3 - a - bb
            for sa in (-1, 1):
                for sb in (-1, 1):
                    points = []
                    for tip in (0, 1):
                        for sc in (-1, 1):
                            p = [0, 0, 0]
                            p[a] = sa * (h[a] if tip == 0 else h[a] - b)
                            p[bb] = sb * (h[bb] - b if tip == 0 else h[bb])
                            p[c] = sc * (h[c] - b)
                            points.append(tuple(p))
                    normal = [0, 0, 0]
                    normal[a], normal[bb] = sa, sb
                    emit(points, normal)
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    points = [(sx * h[0], sy * (h[1] - b), sz * (h[2] - b)),
                              (sx * (h[0] - b), sy * h[1], sz * (h[2] - b)),
                              (sx * (h[0] - b), sy * (h[1] - b), sz * h[2])]
                    emit(points, (sx, sy, sz))

    def cyl(self, center, radius, height, patch="steel", segments=12, top=None, rotation=(0, 0, 0)):
        top = radius if top is None else top
        rings = [[transform((r * math.cos(i * math.tau / segments), y, r * math.sin(i * math.tau / segments)), center, rotation)
                  for i in range(segments)] for r, y in ((radius, -height / 2), (top, height / 2))]
        for i in range(segments):
            j = (i + 1) % segments
            self.face([rings[0][i], rings[1][i], rings[0][j]] if top == 0 else
                      [rings[0][i], rings[1][i], rings[1][j], rings[0][j]], patch)
        for ring, normal in ((rings[0], (0, -1, 0)), (rings[1], (0, 1, 0))):
            if top == 0 and normal[1] > 0:
                continue
            self.polygon(ring, transform(normal, (0, 0, 0), rotation), patch)

    def beam(self, a, b, radius=.035, patch="steel", segments=6):
        direction = unit(sub(b, a))
        u = unit(cross(direction, (0, 1, 0) if abs(direction[1]) < .95 else (1, 0, 0)))
        v = cross(direction, u)
        rings = [[add(p, tuple(radius * (u[k] * math.cos(i * math.tau / segments) + v[k] * math.sin(i * math.tau / segments))
                                for k in range(3))) for i in range(segments)] for p in (a, b)]
        for i in range(segments):
            j = (i + 1) % segments
            self.face([rings[0][i], rings[1][i], rings[1][j], rings[0][j]], patch)

    def sign(self, center, size, patch, rotation=(0, 0, 0)):
        w, h = size
        self.face([transform(p, center, rotation) for p in ((-w/2, -h/2, 0), (w/2, -h/2, 0), (w/2, h/2, 0), (-w/2, h/2, 0))], patch)


def crate(m, p, scale=1):
    x, y, z = p
    m.box((x, y + .3*scale, z), (.8*scale, .6*scale, .62*scale), "crate", .04*scale)
    for side in (-1, 1):
        m.box((x + side*.25*scale, y + .3*scale, z), (.055*scale, .62*scale, .64*scale), "dark_olive")
    m.box((x, y + .62*scale, z), (.84*scale, .055*scale, .66*scale), "olive", .02*scale)


def module(m, patch="olive"):
    for x in (-1.4, 1.4):
        for z in (-1.15, 1.15):
            m.box((x, .13, z), (.35, .26, .4), "steel", .04)
    m.box((0, 1.35, 0), (3.4, 2.25, 2.8), patch, .12)
    m.box((0, .3, 0), (3.58, .18, 2.95), "dark_olive", .04)
    m.box((0, 2.5, 0), (3.6, .15, 3.0), "dark_olive", .05)
    for x in (-1.65, 1.65):
        m.box((x, 1.4, 0), (.12, 2.2, 2.85), "steel", .025)
    for x in (-1.2, -.8, -.4, 0, .4, .8, 1.2):
        m.box((x, 1.3, -1.415), (.035, 1.9, .045), "wear")
    m.box((-.85, 1.2, 1.43), (.95, 1.85, .08), "dark_olive", .035)
    m.box((-.85, 1.25, 1.48), (.76, 1.65, .035), patch, .025)
    m.box((-.56, 1.1, 1.52), (.045, .24, .05), "alloy", .01)
    m.box((.65, 1.55, 1.44), (1.35, .8, .04), "rubber", .03)
    m.box((.65, 1.55, 1.47), (1.19, .64, .035), "glass", .02)
    m.box((.65, 1.55, 1.5), (.055, .7, .04), "steel")
    m.box((-.85, 2.16, 1.52), (.75, .08, .1), "blue_light", .02)
    m.box((-.85, .18, 1.62), (1.1, .18, .5), "tread", .035)


def damage(m):
    for x, z in ((-1.5, 1.1), (1.45, -.8), (1.15, 1.4)):
        m.box((x, .12, z), (.5, .22, .38), "rubber", .06, (.1, x, .2))
        m.beam((x, .2, z), (x + .2, .55, z - .1), .03, "steel")


def hq():
    m = Mesh()
    module(m)
    m.sign((.65, 1.55, -1.445), (1.3, 1.1), "command", (0, math.pi, 0))
    m.sign((1.724, 1.35, .1), (1.2, 1.2), "sgc", (0, math.pi/2, 0))
    m.box((-.9, 2.7, -.5), (.95, .35, 1.1), "steel", .06)
    m.sign((-.9, 2.885, -.5), (.75, .8), "vent", (-math.pi/2, 0, 0))
    m.beam((1.1, 2.55, -.7), (1.1, 4.35, -.7), .035, "alloy")
    for yy, length in ((3.7, .9), (4.15, .6)):
        m.beam((1.1-length/2, yy, -.7), (1.1+length/2, yy, -.7), .025)
    # A small faceted parabolic dish and its feed, not a placeholder sphere.
    for i in range(16):
        a, b = i*math.tau/16, (i+1)*math.tau/16
        m.face([(0, 2.95, .5), (.63*math.cos(b), 3.12, .5+.63*math.sin(b)),
                (.63*math.cos(a), 3.12, .5+.63*math.sin(a))], "alloy")
    m.beam((0, 2.58, .5), (0, 3.45, .5), .04)
    m.cyl((0, 3.42, .5), .08, .12, "rubber")
    crate(m, (1.25, 0, 1.3), .65)
    return {"Structure": m}


def generator():
    m, rotor = Mesh(), Mesh()
    m.box((0, .18, 0), (3.2, .28, 2.7), "steel", .06)
    m.box((0, .9, 0), (2.8, 1.3, 2.2), "dark_olive", .13)
    m.box((0, 1.58, 0), (2.9, .16, 2.3), "olive", .06)
    for x in (-1.42, 1.42):
        m.sign((x, .95, .0), (1.6, .8), "vent", (0, math.copysign(math.pi/2, x), 0))
    m.sign((0, .96, 1.12), (1.15, .75), "power")
    for x in (-1.1, 1.1):
        m.box((x, .45, 1.13), (.15, .25, .06), "amber_light", .02)
    m.box((0, .35, 1.18), (2.65, .12, .04), "hazard")
    m.cyl((-.9, 1.9, -.7), .1, 1.15, "steel")
    m.cyl((-.9, 2.48, -.7), .17, .08, "rubber")
    m.cyl((0, 1.7, 0), .68, .08, "rubber", 20)
    for angle in (0, math.pi/2, math.pi, math.pi*1.5):
        rotor.box((math.cos(angle)*.28, 0, math.sin(angle)*.28), (.55, .035, .16), "alloy", .01, (0, -angle, .15))
    m.cyl((.7, 1.8, .5), .2, .25, "blue_light")
    for side in (-1, 1):
        m.beam((side*1.25, 1.7, -.9), (side*1.25, 1.7, .9), .04)
    return {"Structure": m, "Rotor": rotor}


def infirmary():
    m = Mesh()
    m.box((0, .12, 0), (3.8, .18, 3.6), "tread", .03)
    sections = [(math.cos(i*math.pi/8)*1.75, .45+math.sin(i*math.pi/8)*1.9) for i in range(9)]
    for i in range(8):
        a, b = sections[i], sections[i+1]
        m.face([(a[0], a[1], -1.6), (b[0], b[1], -1.6), (b[0], b[1], 1.6), (a[0], a[1], 1.6)], "canvas")
        for z in (-1.61, 0, 1.61):
            m.beam((a[0], a[1]+.025, z), (b[0], b[1]+.025, z), .035, "dark_olive")
    for z, normal in ((-1.6, (0, 0, -1)), (1.6, (0, 0, 1))):
        m.polygon([(x, y, z) for x, y in sections] + [(-1.75, .2, z), (1.75, .2, z)], normal, "canvas")
    m.box((0, 1.03, 1.625), (1.08, 1.7, .045), "rubber", .05)
    for x in (-.68, .68):
        m.box((x, 1.03, 1.67), (.22, 1.75, .08), "canvas", .025, (0, 0, x*.08))
    m.sign((0, 2.05, 1.66), (.5, .5), "medical")
    for x in (-1, 1):
        m.sign((x*1.32, 1.55, -.02), (.9, .9), "medical", (0, x*math.pi/2, x*-.55))
    for x in (-1.75, 1.75):
        for z in (-1.55, 1.55):
            m.beam((x*.9, .8, z*.88), (x*1.08, .05, z*1.05), .015, "sand_canvas")
    crate(m, (-1.35, .2, 1.28), .7)
    m.sign((-1.35, .52, 1.51), (.36, .36), "medical_sign")
    return {"Structure": m}


def laboratory():
    m = Mesh()
    module(m, "white")
    m.sign((1.724, 1.4, 0), (1.25, .9), "lab", (0, math.pi/2, 0))
    for x in (-.8, .8):
        m.box((x, 2.68, -.25), (1.25, .12, 1.8), "steel", .035, (.14, 0, 0))
        m.sign((x, 2.77, -.25), (1.12, 1.65), "solar", (-math.pi/2+.14, 0, 0))
    m.box((1.42, .7, 1.45), (.6, .95, .5), "alloy", .05)
    m.sign((1.42, 1.0, 1.71), (.4, .38), "blue_light")
    m.beam((-1.4, 2.6, -.95), (-1.4, 3.45, -.95), .025)
    m.cyl((-1.4, 3.5, -.95), .14, .18, "blue_light", 8)
    return {"Structure": m}


def turret():
    m, aim = Mesh(), Mesh()
    m.cyl((0, .15, 0), 1.15, .3, "tread", 20)
    # Offset courses of sandbags, open at the rear for access.
    for row in range(2):
        for i in range(12):
            a = math.radians(-55 + i*24 + row*8)
            m.box((math.sin(a)*1.5, .22+row*.32, math.cos(a)*1.5), (.68, .33, .44), "sandbag", .10, (0, a, 0))
    m.cyl((0, .7, 0), .32, .9, "steel", 12)
    m.cyl((0, 1.18, 0), .48, .16, "dark_olive", 16)
    aim.box((0, 1.42, 0), (.9, .5, 1.0), "dark_olive", .08)
    aim.box((0, 1.52, -.38), (1.25, .85, .12), "olive", .06, (.1, 0, 0))
    for x in (-.22, .22):
        aim.cyl((x, 1.52, -1.02), .09, 1.25, "steel", 10, rotation=(math.pi/2, 0, 0))
        aim.cyl((x, 1.52, -1.66), .12, .22, "rubber", 10, rotation=(math.pi/2, 0, 0))
    aim.box((.63, 1.15, .1), (.45, .6, .65), "crate", .035)
    aim.box((0, 1.91, -.1), (.23, .18, .4), "rubber", .03)
    aim.sign((0, 1.91, -.315), (.13, .09), "red_light", (0, math.pi, 0))
    return {"Structure": m, "Aim": aim}


def mine():
    m, drill = Mesh(), Mesh()
    m.box((0, .18, 0), (3.6, .32, 3.6), "steel", .05)
    m.cyl((0, .39, 0), .7, .12, "rubber", 16)
    for x in (-1.25, 1.25):
        for z in (-1.05, 1.05):
            m.box((x, .3, z), (.6, .18, .6), "hazard", .025)
            m.beam((x, .4, z), (x*.65, 4.0, z*.65), .09, "steel", 8)
        for y in (1.2, 2.5, 3.8):
            m.beam((x*(1-y*.08), y, -.95), (x*(1-y*.08), y, .95), .045, "scaffold")
        m.beam((x, .6, -.95), (x*.7, 3.6, .7), .045, "scaffold")
    m.box((0, 4.05, 0), (2.0, .3, 1.8), "olive", .055)
    m.box((0, 3.78, .65), (1.6, .12, .1), "hazard")
    drill.cyl((0, 2, 0), .15, 3.8, "alloy", 12)
    drill.cyl((0, .55, 0), .34, .8, "steel", 12, top=.12)
    for i in range(30):
        a, b = i*.5, (i+1)*.5
        drill.beam((math.cos(a)*.22, .65+i*.08, math.sin(a)*.22),
                   (math.cos(b)*.22, .65+(i+1)*.08, math.sin(b)*.22), .055, "alloy")
    m.box((1.38, 1, 0), (.55, 1.35, 1.1), "dark_olive", .05)
    m.sign((1.67, 1.1, 0), (.85, .85), "mining", (0, math.pi/2, 0))
    m.box((-1.3, .65, .6), (.7, .7, 1.0), "crate", .05)
    return {"Structure": m, "Drill": drill}


def camp():
    m = Mesh()
    for i in range(3):
        m.box((0, .12+i*.2, 0), (4.7-i*.3, .22, 4.7-i*.3), "stone", .035)
    base_y, tip = .6, (0, 4.9, 0)
    corners = [(-2, base_y, -2), (2, base_y, -2), (2, base_y, 2), (-2, base_y, 2)]
    for i in range(4):
        m.face([corners[(i+1)%4], corners[i], tip], "bronze")
        m.beam(corners[i], tip, .055, "gold", 6)
    # Monumental stone portal in front of the armoured pyramid.
    for x in (-.9, .9):
        m.box((x, 1.65, 1.8), (.42, 2.1, .8), "gold", .045)
        m.sign((x, 1.65, 2.215), (.27, 1.65), "glyph")
    m.box((0, 2.82, 1.75), (2.25, .35, 1.0), "gold", .06)
    m.box((0, 1.6, 1.99), (1.4, 1.95, .08), "dark_stone", .025)
    m.box((0, 2.5, 2.06), (.8, .07, .06), "amber_light")
    m.box((0, 2.97, 1.8), (1.65, .12, .65), "glyph", .02)
    for x in (-1.9, 1.9):
        m.cyl((x, 1.55, 1.9), .17, 1.8, "gold", 8)
        m.cyl((x, 2.5, 1.9), .22, .28, "amber_light", 8, top=.06)
    return {"Structure": m}


def supplies():
    m = Mesh()
    crate(m, (-.45, 0, 0))
    crate(m, (.45, 0, -.1))
    crate(m, (-.4, .64, 0), .85)
    for x in (.3, .7):
        m.box((x, .9, -.1), (.28, .5, .32), "olive", .035)
    return {"Structure": m}


def barrier():
    m = Mesh()
    for row in range(3):
        for i in range(4):
            m.box(((i-1.5)*.58+(row%2)*.13, .17+row*.3, 0), (.62, .32, .48), "sandbag", .09)
    return {"Structure": m}


def construction():
    m = Mesh()
    for x in (-1.65, 1.65):
        for z in (-1.5, 1.5):
            m.beam((x, .03, z), (x, 2.8, z), .035, "scaffold")
            m.box((x, .08, z), (.22, .16, .22), "steel")
    for y in (.4, 1.5, 2.7):
        for z in (-1.5, 1.5):
            m.beam((-1.65, y, z), (1.65, y, z), .03, "steel")
        for x in (-1.65, 1.65):
            m.beam((x, y, -1.5), (x, y, 1.5), .03, "steel")
    m.beam((-1.65, .4, -1.5), (1.65, 2.7, -1.5), .025)
    crate(m, (-.8, 0, .6))
    crate(m, (.3, 0, .8), .7)
    m.box((0, .05, 1.6), (3.0, .08, .18), "hazard")
    return {"Structure": m}


def deposit():
    m = Mesh()
    m.cyl((0, .1, 0), 1.45, .24, "dark_stone", 12, top=1.25)
    for i in range(9):
        a = i*2.4
        x, z = math.sin(a)*(.5+i*.07), math.cos(a)*(.5+i*.07)
        height = .65+(i%4)*.34
        m.cyl((x, height/2+.15, z), .18+(i%3)*.07, height, "crystal", 5, top=.1,
              rotation=(.12*math.sin(a), a, .15*math.cos(a)))
        m.cyl((x, height+.22, z), .14, .35, "crystal", 5, top=0)
    return {"Structure": m}


def ruins():
    m = Mesh()
    m.box((0, .12, 0), (4.3, .24, 3.4), "dark_stone", .04)
    for x, z, height in ((-1.45, -.8, 3.5), (1.45, -.8, 3.1), (-1.45, .9, 2.2), (1.45, .9, 1.4)):
        m.box((x, .3, z), (.85, .2, .85), "stone", .06)
        m.box((x, height/2+.4, z), (.5, height, .5), "stone", .045)
        m.sign((x, 1.4, z+.255), (.35, 1.1), "glyph")
    m.box((0, 3.7, -.8), (3.4, .35, .7), "stone", .06, (0, 0, -.06))
    m.box((0, .6, 0), (1.1, .9, .9), "dark_stone", .08)
    m.box((0, 1.1, 0), (1.25, .16, 1.1), "glyph", .035)
    m.cyl((0, 1.3, 0), .2, .35, "blue_light", 6, top=.08)
    m.box((1, .35, 1.3), (.6, .4, .8), "stone", .1, (.1, .4, -.3))
    return {"Structure": m}


def gate_platform():
    m = Mesh()
    m.box((0, .05, 0), (8, .32, 3.6), "dark_stone", .05)
    for i in range(3):
        m.box((0, -.04-i*.06, 2.0+i*.3), (5.8+i*.3, .15, .65), "stone", .025)
    for x in (-3.65, 3.65):
        m.box((x, .32, .5), (.35, .25, 3.0), "stone", .025)
    for x in (-2.3, 2.3):
        m.box((x, .28, 1.5), (.3, .16, .4), "blue_light", .035)
    # DHD, offset beside the approach, with separate keys and the red activator.
    m.cyl((3.1, .65, 2.4), .4, 1.1, "dark_stone", 12, top=.28)
    m.cyl((3.1, 1.22, 2.4), .7, .18, "bronze", 18)
    for i in range(16):
        a = i*math.tau/16
        m.box((3.1+math.cos(a)*.5, 1.33, 2.4+math.sin(a)*.5), (.12, .055, .15), "glyph", .01, (0, -a, 0))
    m.cyl((3.1, 1.38, 2.4), .17, .1, "red_light", 12, top=.1)
    return {"Structure": m}


BUILDERS = {"hq": hq, "generator": generator, "infirmary": infirmary, "lab": laboratory,
            "turret": turret, "mine": mine, "camp": camp, "supplies": supplies,
            "barrier": barrier, "construction": construction, "deposit": deposit,
            "ruins": ruins, "gate_platform": gate_platform}


def export(name: str, parts: dict[str, Mesh]) -> dict:
    if name in ("hq", "generator", "infirmary", "lab", "turret", "mine", "camp"):
        damage_mesh = Mesh()
        damage(damage_mesh)
        parts["Damage"] = damage_mesh
    data = bytearray()
    doc = {"asset": {"version": "2.0", "generator": "SG-1 original outpost kit"},
           "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [],
           "buffers": [{"byteLength": 0}], "bufferViews": [], "accessors": [],
           "images": [{"uri": f"../textures/field_{k}.png"} for k in ("albedo", "normal", "orm", "emission")],
           "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071}],
           "textures": [{"source": i, "sampler": 0} for i in range(4)],
           "materials": [{"name": "Field kit shared PBR atlas", "pbrMetallicRoughness": {
               "baseColorTexture": {"index": 0}, "metallicRoughnessTexture": {"index": 2},
               "metallicFactor": 1, "roughnessFactor": 1},
               "normalTexture": {"index": 1, "scale": .3}, "emissiveTexture": {"index": 3},
               "emissiveFactor": [1, 1, 1]}]}

    def accessor(values, components, kind, component_type=5126):
        while len(data) % 4:
            data.append(0)
        offset = len(data)
        flat = [x for value in values for x in value] if components > 1 else values
        data.extend(struct.pack("<" + ("f" if component_type == 5126 else "I") * len(flat), *flat))
        view = len(doc["bufferViews"])
        doc["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(data)-offset})
        record = {"bufferView": view, "componentType": component_type, "count": len(values), "type": kind}
        if kind == "VEC3":
            record["min"] = [min(v[a] for v in values) for a in range(3)]
            record["max"] = [max(v[a] for v in values) for a in range(3)]
        index = len(doc["accessors"])
        doc["accessors"].append(record)
        return index

    triangles = 0
    for part_name, mesh in parts.items():
        assert mesh.positions and all(math.isfinite(v) for p in mesh.positions for v in p)
        p = accessor(mesh.positions, 3, "VEC3")
        n = accessor(mesh.normals, 3, "VEC3")
        uv = accessor(mesh.uvs, 2, "VEC2")
        indices = accessor(mesh.indices, 1, "SCALAR", 5125)
        node = {"name": part_name, "mesh": len(doc["meshes"])}
        if name == "generator" and part_name == "Rotor":
            node["translation"] = [0, 1.76, 0]
        doc["scenes"][0]["nodes"].append(len(doc["nodes"]))
        doc["nodes"].append(node)
        doc["meshes"].append({"name": f"{name}_{part_name}", "primitives": [{
            "attributes": {"POSITION": p, "NORMAL": n, "TEXCOORD_0": uv}, "indices": indices, "material": 0}]})
        triangles += len(mesh.indices)//3
    doc["buffers"][0]["byteLength"] = len(data)
    encoded = json.dumps(doc, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    data.extend(b"\0" * (-len(data) % 4))
    glb = struct.pack("<III", 0x46546C67, 2, 12+8+len(encoded)+8+len(data))
    glb += struct.pack("<II", len(encoded), 0x4E4F534A) + encoded
    glb += struct.pack("<II", len(data), 0x004E4942) + data
    (OUT / "models").mkdir(parents=True, exist_ok=True)
    (OUT / "models" / f"{name}.glb").write_bytes(glb)
    return {"file": f"models/{name}.glb", "triangles": triangles, "mesh_surfaces": len(parts), "bytes": len(glb)}


def thumbnail(name: str, parts: dict[str, Mesh]) -> None:
    """Portable orthographic UI previews. The optional Godot baker can refine them."""
    eye = unit((5, 4.8, 6))
    right = unit(cross((0, 1, 0), eye))
    up = cross(eye, right)
    light = unit((-3, 7, 5))
    source = Image.open(OUT / "textures/field_albedo.png")
    faces = []
    for part_name, mesh in parts.items():
        if part_name == "Damage":
            continue
        translation = (0, 1.76, 0) if name == "generator" and part_name == "Rotor" else (0, 0, 0)
        for i in range(0, len(mesh.indices), 3):
            ids = mesh.indices[i:i+3]
            normal = mesh.normals[ids[0]]
            if sum(a*b for a, b in zip(normal, eye)) <= 0:
                continue
            vertices = [add(mesh.positions[j], translation) for j in ids]
            projection = [(sum(a*b for a, b in zip(p, right)), -sum(a*b for a, b in zip(p, up))) for p in vertices]
            u, v = (sum(mesh.uvs[j][a] for j in ids)/3 for a in (0, 1))
            color = source.getpixel((min(source.width-1, int(u*source.width)), min(source.height-1, int(v*source.height))))
            shade = .5+.65*max(0, sum(a*b for a, b in zip(normal, light)))
            color = tuple(min(255, int(c*shade)) for c in color)
            depth = sum(sum(a*b for a, b in zip(p, eye)) for p in vertices)/3
            faces.append((depth, projection, color))
    points = [p for _, vertices, _ in faces for p in vertices]
    xmin, xmax = min(p[0] for p in points), max(p[0] for p in points)
    ymin, ymax = min(p[1] for p in points), max(p[1] for p in points)
    scale = 330/max(xmax-xmin, ymax-ymin)
    cx, cy = (xmin+xmax)/2, (ymin+ymax)/2
    image = Image.new("RGBA", (384, 384))
    draw = ImageDraw.Draw(image)
    for _, vertices, color in sorted(faces, key=lambda f: f[0]):
        draw.polygon([((x-cx)*scale+192, (y-cy)*scale+192) for x, y in vertices], fill=color+(255,))
    folder = OUT / "icons"
    folder.mkdir(exist_ok=True)
    image.resize((192, 192), Image.Resampling.LANCZOS).save(folder / f"{name}.png", optimize=True)


def main():
    atlas()
    manifest = {"version": 1, "units": "metres", "up_axis": "Y", "front": "+Z; turret muzzle -Z",
                "source": "dev/build_outpost_assets.py", "third_party_artwork": False,
                "note": "Original geometry and textures authored for this unofficial fan project. Stargate belongs to its rights holders.",
                "models": {}}
    for name, builder in BUILDERS.items():
        parts = builder()
        record = export(name, parts)
        thumbnail(name, parts)
        manifest["models"][name] = record
        print(f"{name:16s} {record['triangles']:5d} triangles  {record['mesh_surfaces']} surfaces")
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
