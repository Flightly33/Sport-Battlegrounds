"""
Builds the optional VFX asset pack for Sports Battlegrounds.

    python blender/build_pack.py [out_dir]          (needs the `bpy` module: pip install bpy)

Writes, under out_dir (default blender/out):
  meshes/*.obj    ring, crescent, spiral, bolt, burst, dome. OBJ has no units, so 1 unit imports as
                  1 stud: every mesh is built at the native size the FX code scales from.
  textures/*.png  white-on-transparent particle textures and flipbooks (tinted per character in game).

Upload them in Studio (Asset Manager -> Bulk Import, or the 3D Importer for meshes), copy each asset id
into src/shared/AssetIds.luau, and the matching effect switches over. Nothing in the game needs them.
"""

import math
import os
import random
import struct
import sys
import zlib

import bpy
import numpy as np

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "out")
MESH_DIR = os.path.join(OUT, "meshes")
TEX_DIR = os.path.join(OUT, "textures")
random.seed(7)
RNG = np.random.default_rng(7)


# ----------------------------------------------------------------------------------------------
# Meshes. Coordinates are Roblox-style (x right, y up, -z forward) and converted on export.
# ----------------------------------------------------------------------------------------------
def new_mesh(name, verts, faces, double_sided=True):
    """verts in Roblox axes; faces as vertex index tuples (counter-clockwise seen from outside)."""
    if double_sided:
        n = len(verts)
        verts = list(verts) + list(verts)
        faces = list(faces) + [tuple(i + n for i in reversed(f)) for f in faces]
    mesh = bpy.data.meshes.new(name)
    # Roblox (x, y, z) -> Blender (x, -z, y); the OBJ exporter maps back with forward -Z, up Y
    mesh.from_pydata([(x, -z, y) for (x, y, z) in verts], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def ring(segments=64, outer=0.5, inner=0.42, height=1.0):
    """Flat band in the XZ plane: outer diameter 1, height 1 (FX scales Y to the ring width)."""
    verts, faces = [], []
    for i in range(segments):
        a = 2 * math.pi * i / segments
        c, s = math.cos(a), math.sin(a)
        verts += [(c * outer, -height / 2, s * outer), (c * outer, height / 2, s * outer),
                  (c * inner, -height / 2, s * inner), (c * inner, height / 2, s * inner)]
    for i in range(segments):
        j = (i + 1) % segments
        a, b = 4 * i, 4 * j
        faces += [(a, b, b + 1, a + 1),          # outer wall
                  (a + 3, b + 3, b + 2, a + 2),  # inner wall
                  (a + 1, b + 1, b + 3, a + 3),  # top
                  (a + 2, b + 2, b, a)]          # bottom
    return new_mesh("ring", verts, faces, double_sided=False)


def crescent(segments=48, thickness=0.12):
    """Slash arc in the XZ plane spanning x -0.5..0.5, bulging towards -z; thin in y, tapered tips."""
    verts, faces = [], []
    for i in range(segments + 1):
        t = i / segments
        a = math.pi * t
        width = math.sin(a) ** 0.8  # 0 at the tips, 1 in the middle
        x = -0.5 * math.cos(a)
        z_out = -0.5 * math.sin(a)
        z_in = z_out + 0.45 * width
        h = thickness * (0.3 + 0.7 * width) / 2
        verts += [(x, -h, z_out), (x, h, z_out), (x, -h * 0.4, z_in), (x, h * 0.4, z_in)]
    for i in range(segments):
        a, b = 4 * i, 4 * (i + 1)
        faces += [(a + 1, b + 1, b + 3, a + 3), (a + 2, b + 2, b, a),
                  (a, b, b + 1, a + 1), (a + 3, b + 3, b + 2, a + 2)]
    return new_mesh("crescent", verts, faces, double_sided=False)


def spiral(turns=2.0, strands=2, steps=120, sides=6, tube=0.05):
    """Helix strands around the forward axis: z 0..-1, diameter 1, tapering at both ends."""
    verts, faces = [], []
    for s in range(strands):
        base = len(verts)
        phase = 2 * math.pi * s / strands
        for i in range(steps + 1):
            t = i / steps
            a = phase + 2 * math.pi * turns * t
            r = 0.5 * (0.55 + 0.45 * t)
            center = (r * math.cos(a), r * math.sin(a), -t)
            # Frame: radial and the helix tangent
            radial = (math.cos(a), math.sin(a), 0.0)
            tan = (-r * math.sin(a) * 2 * math.pi * turns, r * math.cos(a) * 2 * math.pi * turns, -1.0)
            tl = math.sqrt(sum(c * c for c in tan))
            tan = tuple(c / tl for c in tan)
            binormal = (tan[1] * radial[2] - tan[2] * radial[1],
                        tan[2] * radial[0] - tan[0] * radial[2],
                        tan[0] * radial[1] - tan[1] * radial[0])
            thick = tube * math.sin(math.pi * t) ** 0.6 + 0.004
            for k in range(sides):
                b = 2 * math.pi * k / sides
                verts.append(tuple(center[c] + thick * (math.cos(b) * radial[c] + math.sin(b) * binormal[c])
                                   for c in range(3)))
        for i in range(steps):
            for k in range(sides):
                k2 = (k + 1) % sides
                a0 = base + i * sides
                a1 = base + (i + 1) * sides
                faces.append((a0 + k, a0 + k2, a1 + k2, a1 + k))
    return new_mesh("spiral", verts, faces, double_sided=False)


def bolt(segments=9, width=0.16):
    """Jagged lightning strip, y -0.5..0.5, as two crossed planes so it reads from any angle."""
    points = [(0.0, -0.5)]
    for i in range(1, segments):
        points.append(((random.random() - 0.5) * 0.35, -0.5 + i / segments))
    points.append((0.0, 0.5))
    verts, faces = [], []
    for plane in range(2):
        base = len(verts)
        for i, (x, y) in enumerate(points):
            w = width * (0.35 + 0.65 * math.sin(math.pi * i / segments)) / 2
            if plane == 0:
                verts += [(x - w, y, 0.0), (x + w, y, 0.0)]
            else:
                verts += [(x, y, -w), (x, y, w)]
        for i in range(len(points) - 1):
            a = base + 2 * i
            faces.append((a, a + 1, a + 3, a + 2))
    return new_mesh("bolt", verts, faces, double_sided=True)


def burst(spikes=14, thickness=0.04):
    """Anime impact star facing +z: diameter 1, uneven spikes."""
    verts = [(0.0, 0.0, thickness / 2), (0.0, 0.0, -thickness / 2)]
    rim = []
    for i in range(spikes * 2):
        a = 2 * math.pi * i / (spikes * 2)
        r = (0.5 * (0.75 + 0.25 * random.random())) if i % 2 == 0 else 0.17 + 0.05 * random.random()
        rim.append((r * math.cos(a), r * math.sin(a)))
    for x, y in rim:
        verts.append((x, y, 0.0))
    faces = []
    n = len(rim)
    for i in range(n):
        a, b = 2 + i, 2 + (i + 1) % n
        faces.append((0, a, b))
        faces.append((1, b, a))
    return new_mesh("burst", verts, faces, double_sided=False)


def dome(rings=12, segments=40):
    """Hemisphere shell: base on y=0, diameter 1, height 0.5; seen from outside and inside."""
    verts, faces = [], []
    for r in range(rings + 1):
        phi = (math.pi / 2) * r / rings
        for s in range(segments):
            th = 2 * math.pi * s / segments
            verts.append((0.5 * math.cos(phi) * math.cos(th), 0.5 * math.sin(phi), 0.5 * math.cos(phi) * math.sin(th)))
    for r in range(rings):
        for s in range(segments):
            s2 = (s + 1) % segments
            a, b = r * segments + s, r * segments + s2
            c, d = (r + 1) * segments + s2, (r + 1) * segments + s
            faces.append((a, d, c, b))
    return new_mesh("dome", verts, faces, double_sided=True)


def export_meshes():
    os.makedirs(MESH_DIR, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    builders = [ring, crescent, spiral, bolt, burst, dome]
    for build in builders:
        obj = build()
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        path = os.path.join(MESH_DIR, obj.name + ".obj")
        bpy.ops.wm.obj_export(filepath=path, export_selected_objects=True, export_materials=False,
                              export_uv=False, forward_axis="NEGATIVE_Z", up_axis="Y")
        print("mesh", path, len(obj.data.vertices), "verts")


# ----------------------------------------------------------------------------------------------
# Textures (numpy, written as RGBA PNG). White with alpha so particle Color tints them.
# ----------------------------------------------------------------------------------------------
def write_png(path, rgba):
    rgba = (np.clip(rgba, 0, 1) * 255).astype(np.uint8)
    h, w, _ = rgba.shape
    raw = b"".join(b"\x00" + rgba[y].tobytes() for y in range(h))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
    print("texture", path, f"{w}x{h}")


def grid(n):
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    return (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1  # -1..1


def value_noise(n, cells, seed):
    rng = np.random.default_rng(seed)
    lattice = rng.random((cells + 1, cells + 1)).astype(np.float32)
    lattice[-1, :] = lattice[0, :]
    lattice[:, -1] = lattice[:, 0]
    t = np.linspace(0, cells, n, endpoint=False, dtype=np.float32)
    i = t.astype(int)
    f = t - i
    f = f * f * (3 - 2 * f)
    a = lattice[i][:, i]
    b = lattice[i][:, i + 1]
    c = lattice[i + 1][:, i]
    d = lattice[i + 1][:, i + 1]
    fx, fy = f[None, :], f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(n, seed, octaves=5, base=4):
    out = np.zeros((n, n), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        out += value_noise(n, base * 2 ** o, seed + o) * amp
        total += amp
        amp *= 0.5
    return out / total


def white(alpha, brightness=None):
    v = np.ones_like(alpha) if brightness is None else brightness
    return np.dstack([v, v, v, alpha])


def sheet(frames, cols):
    rows = [np.concatenate(frames[r * cols:(r + 1) * cols], axis=1) for r in range(cols)]
    return np.concatenate(rows, axis=0)


def explosion_frames(cols=8, size=128):
    x, y = grid(size)
    r = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    noise = fbm(size, 11)
    noise2 = fbm(size, 23, octaves=4, base=3)
    frames = []
    count = cols * cols
    for i in range(count):
        t = i / (count - 1)
        radius = 0.42 + 0.48 * (1 - (1 - t) ** 2.2)
        churn = noise * (1 - t) + noise2 * t  # the billows roll as it grows
        billow = (churn - 0.5) * 0.7 + 0.03 * np.sin(ang * 5 + t * 6)
        edge = radius * (1 + billow)
        body = np.clip((edge - r) / 0.12, 0, 1)
        # Burns out from the middle as it expands: hot core early, ragged hole late
        burn = max(0.0, (t - 0.15) / 0.85) ** 1.3  # grows from nothing, so the hole never pops in
        hole = np.clip((r - radius * burn * 0.85 + (noise2 - 0.5) * 0.5 * burn) / 0.18, 0, 1)
        alpha = body * hole * (1 - t ** 3)
        brightness = np.clip(1.0 - r / max(edge.max(), 1e-3) * (0.25 + 0.6 * t), 0.35, 1)
        frames.append(white(alpha, brightness))
    return sheet(frames, cols)


def smoke_frames(cols=4, size=128):
    x, y = grid(size)
    r = np.sqrt(x * x + y * y)
    frames = []
    count = cols * cols
    for i in range(count):
        t = i / (count - 1)
        noise = fbm(size, 40 + i % 3, octaves=4, base=3)
        radius = 0.45 + 0.4 * t
        soft = np.clip((radius * (0.8 + noise * 0.5) - r) / 0.35, 0, 1)
        alpha = soft * (0.55 + 0.45 * noise) * (1 - t ** 1.5)
        frames.append(white(alpha, 0.85 + 0.15 * noise))
    return sheet(frames, cols)


def lightning_frames(cols=4, size=128):
    frames = []
    for i in range(cols * cols):
        img = np.zeros((size, size), np.float32)
        yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)

        def stroke(p0, p1, depth, width):
            if depth == 0:
                # Distance from each pixel to the segment
                d = np.array(p1) - np.array(p0)
                L = max(np.dot(d, d), 1e-6)
                t = np.clip(((xx - p0[0]) * d[0] + (yy - p0[1]) * d[1]) / L, 0, 1)
                dist = np.hypot(xx - (p0[0] + t * d[0]), yy - (p0[1] + t * d[1]))
                np.maximum(img, np.clip(1 - dist / width, 0, 1) ** 2, out=img)
                np.maximum(img, np.exp(-(dist / (width * 4)) ** 2) * 0.35, out=img)
                return
            mid = ((p0[0] + p1[0]) / 2 + (random.random() - 0.5) * size * 0.16 * (depth / 4),
                   (p0[1] + p1[1]) / 2 + (random.random() - 0.5) * size * 0.16 * (depth / 4))
            stroke(p0, mid, depth - 1, width)
            stroke(mid, p1, depth - 1, width)
            if depth == 3 and random.random() < 0.7:
                end = (min(max(mid[0] + (random.random() - 0.5) * size * 0.4, size * 0.1), size * 0.9),
                       min(max(mid[1] + (random.random() - 0.5) * size * 0.4, size * 0.1), size * 0.9))
                stroke(mid, end, 2, width * 0.6)

        a = random.random() * math.pi
        c, s = math.cos(a) * size * 0.34, math.sin(a) * size * 0.34
        stroke((size / 2 - c, size / 2 - s), (size / 2 + c, size / 2 + s), 4, 2.2)
        frames.append(white(img))
    return sheet(frames, cols)


def spark(size=128):
    x, y = grid(size)
    r = np.sqrt(x * x + y * y)
    glow = np.exp(-(r / 0.18) ** 2)
    cross = np.exp(-(np.abs(x) / 0.025)) * np.exp(-(np.abs(y) / 0.6)) + np.exp(-(np.abs(y) / 0.025)) * np.exp(-(np.abs(x) / 0.6))
    diag = (np.exp(-(np.abs(x - y) / 0.03)) + np.exp(-(np.abs(x + y) / 0.03))) * np.exp(-(r / 0.3)) * 0.5
    return white(np.clip(glow + cross + diag, 0, 1) * np.clip(1 - r, 0, 1))


def shockwave(size=256):
    x, y = grid(size)
    r = np.sqrt(x * x + y * y)
    band = np.exp(-((r - 0.82) / 0.05) ** 2) + np.clip((r - 0.45) / 0.37, 0, 1) ** 3 * (r < 0.82) * 0.5
    noise = fbm(size, 90, octaves=3, base=6)
    return white(np.clip(band * (0.75 + 0.25 * noise), 0, 1) * (r < 1))


def impact_star(size=256):
    x, y = grid(size)
    r = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    spikes = 12
    rng = np.random.default_rng(5)
    lengths = 0.65 + 0.35 * rng.random(spikes)
    k = (ang + math.pi) / (2 * math.pi) * spikes
    idx = np.floor(k).astype(int) % spikes
    frac = k - np.floor(k)
    tip = lengths[idx] * (1 - np.abs(frac - 0.5) * 2) ** 1.6
    edge = 0.22 + tip * 0.78
    body = np.clip((edge - r) / 0.03, 0, 1)
    inner = np.clip((edge * 0.72 - r) / 0.03, 0, 1)
    return white(np.clip(body * 0.85 + inner * 0.15, 0, 1), 0.85 + 0.15 * inner)


def speed_lines(size=1024, count=150):
    x, y = grid(size)
    r = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    rng = np.random.default_rng(3)
    alpha = np.zeros_like(r)
    for _ in range(count):
        a0 = rng.random() * 2 * math.pi
        width = 0.002 + rng.random() * 0.006
        start = 0.55 + rng.random() * 0.35
        d = np.abs(np.angle(np.exp(1j * (ang - a0))))
        line = np.clip(1 - d / width, 0, 1) * np.clip((r - start) / 0.25, 0, 1)
        np.maximum(alpha, line, out=alpha)
    return white(alpha)


def export_textures():
    os.makedirs(TEX_DIR, exist_ok=True)
    write_png(os.path.join(TEX_DIR, "explosion_8x8.png"), explosion_frames())
    write_png(os.path.join(TEX_DIR, "smoke_4x4.png"), smoke_frames())
    write_png(os.path.join(TEX_DIR, "lightning_4x4.png"), lightning_frames())
    write_png(os.path.join(TEX_DIR, "spark.png"), spark())
    write_png(os.path.join(TEX_DIR, "shockwave.png"), shockwave())
    write_png(os.path.join(TEX_DIR, "impact_star.png"), impact_star())
    write_png(os.path.join(TEX_DIR, "speedlines.png"), speed_lines())


if __name__ == "__main__":
    export_meshes()
    export_textures()
