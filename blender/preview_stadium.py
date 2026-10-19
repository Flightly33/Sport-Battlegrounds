"""
Renders a preview of the baked stadium (and optionally a crowd) from JSON part lists.

    lune run tools/lune/bake_stadium.luau blender/out/preview/stadium.json
    lune run tools/lune/preview_crowd.luau blender/out/preview/crowd.json      (optional)
    python blender/preview_stadium.py blender/out/preview/stadium.json blender/out/preview [crowd.json]

This is a rough stand-in for Roblox's renderer (no Roblox materials, approximate lighting), good for
checking layout, proportions and colour - not final looks.
"""

import json

# Stadium scale relative to the 3 studs per metre the preview spots were picked at
K = (1 / 0.28) / 3
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

P = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
RES = int(os.environ.get("PREVIEW_RES", "720"))
SAMPLES = int(os.environ.get("PREVIEW_SAMPLES", "24"))

_materials = {}
_meshes = {}


def material(color, mat, transparency):
    key = (tuple(round(c, 2) for c in color), mat, round(transparency, 2))
    if key in _materials:
        return _materials[key]
    m = bpy.data.materials.new(f"m{len(_materials)}")
    m.use_nodes = True
    nodes = m.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    lin = tuple(c ** 2.2 for c in key[0])  # Roblox colours are sRGB
    bsdf.inputs["Base Color"].default_value = (*lin, 1)
    bsdf.inputs["Roughness"].default_value = 0.75
    if mat == "Neon":
        bsdf.inputs["Emission Color"].default_value = (*lin, 1)
        bsdf.inputs["Emission Strength"].default_value = 4.0
    elif mat in ("Metal", "DiamondPlate"):
        bsdf.inputs["Metallic"].default_value = 0.7
        bsdf.inputs["Roughness"].default_value = 0.4
    elif mat == "Glass":
        bsdf.inputs["Transmission Weight"].default_value = 0.7
        bsdf.inputs["Roughness"].default_value = 0.1
    if transparency > 0:
        bsdf.inputs["Alpha"].default_value = 1 - transparency
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else m.blend_method
    _materials[key] = m
    return m


def base_mesh(shape):
    if shape in _meshes:
        return _meshes[shape]
    if shape == "Ball":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=16, ring_count=8)
    elif shape == "Cylinder":
        bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=1, vertices=16, rotation=(0, math.pi / 2, 0))
        bpy.ops.object.transform_apply(rotation=True)
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.active_object
    mesh = obj.data
    mesh.materials.append(material((0.5, 0.5, 0.5), "Plastic", 0))
    bpy.data.objects.remove(obj)
    _meshes[shape] = mesh
    return mesh


def add(part, collection):
    c = part["cf"]
    pos = Vector((c[0], c[1], c[2]))
    rot = Matrix(((c[3], c[4], c[5]), (c[6], c[7], c[8]), (c[9], c[10], c[11])))
    m = Matrix.Translation(P @ pos) @ (P @ rot @ P.transposed()).to_4x4()
    sx, sy, sz = part["size"]
    obj = bpy.data.objects.new("p", base_mesh(part.get("shape", "Block")))
    obj.matrix_world = m @ Matrix.Diagonal((sx, sz, sy, 1))
    collection.objects.link(obj)
    obj.material_slots[0].link = "OBJECT"
    obj.material_slots[0].material = material(part["color"], part.get("material", "Plastic"), part.get("transparency", 0))


def setup(scene):
    scene.render.engine = "CYCLES"
    scene.cycles.samples = SAMPLES
    scene.cycles.device = "CPU"
    scene.cycles.use_denoising = False
    scene.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in scene.view_settings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes["Background"]
    sky = nt.nodes.new("ShaderNodeTexSky")
    try:
        sky.sky_type = "NISHITA"
        sky.sun_elevation = math.radians(14)
        sky.sun_rotation = math.radians(250)
    except Exception:
        pass
    nt.links.new(sky.outputs[0], bg.inputs[0])
    bg.inputs[1].default_value = 0.35
    scene.world = world
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 2.6
    sun.color = (1.0, 0.82, 0.62)
    o = bpy.data.objects.new("Sun", sun)
    o.rotation_euler = (math.radians(72), 0, math.radians(250 - 90))
    scene.collection.objects.link(o)


def camera(scene, loc, target, lens=24):
    cam = bpy.data.cameras.new("Cam")
    cam.lens = lens
    cam.clip_end = 5000
    o = bpy.data.objects.new("Cam", cam)
    o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(o)
    scene.camera = o


def rb(x, y, z):
    """Roblox coordinates -> Blender."""
    return (x, -z, y)


def figure(collection, x, z, yaw_deg):
    """A blocky R15-sized player (about 5.2 studs tall) standing at (x, z), for judging scale."""
    yaw = math.radians(yaw_deg)
    c, s = math.cos(yaw), math.sin(yaw)

    def block(dx, y, dz, size, color):
        # offset in the figure's frame (x right, -z forward), rotated by yaw, Roblox axes
        wx = x + dx * c + dz * s
        wz = z - dx * s + dz * c
        cf = [wx, y, wz, c, 0, s, 0, 1, 0, -s, 0, c]
        add({"cf": cf, "size": list(size), "color": color, "material": "SmoothPlastic", "shape": "Block"}, collection)

    skin, shirt, pants = [0.96, 0.80, 0.19], [0.05, 0.41, 0.67], [0.29, 0.59, 0.29]
    block(-0.5, 1.0, 0, (1, 2, 1), pants)
    block(0.5, 1.0, 0, (1, 2, 1), pants)
    block(0, 3.0, 0, (2, 2, 1), shirt)
    block(-1.5, 3.0, 0, (1, 2, 1), skin)
    block(1.5, 3.0, 0, (1, 2, 1), skin)
    block(0, 4.6, 0, (1.2, 1.2, 1.2), skin)


def main():
    args = sys.argv[1:]
    stadium = json.load(open(args[0]))
    out = args[1]
    crowd = json.load(open(args[2])) if len(args) > 2 else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    setup(scene)
    col = scene.collection
    for p in stadium:
        add(p, col)
    for p in crowd:
        add(p, col)
    # Life-size players for scale: on the pitch, by the west goal, on the north touchline
    # Spots were picked at 3 studs per metre; K moves them with the stadium's scale (Layout.STUDS_PER_METER)
    figure(col, -90 * K, 20 * K, 90)
    figure(col, -150 * K, 6 * K, 90)
    figure(col, 0, -96 * K, 0)
    os.makedirs(out, exist_ok=True)
    scene.render.resolution_x = int(RES * 16 / 9)
    scene.render.resolution_y = RES
    views = {
        "aerial": (rb(-420, 330, 380), rb(0, 0, 0), 22),
        "pitch": (rb(-60, 7, 60), rb(120, 30, -60), 20),
        "stand": (rb(40, 6, 60), rb(60, 50, -250), 24),
        # Roblox's default follow camera, behind the player on the pitch looking at the west goal
        # (camera offsets from the figure stay fixed, so the figure frames the same at any scale)
        "player": (rb(-90 * K + 14, 7.5, 20 * K), rb(-90 * K - 20, 3.5, 20 * K), 24),
        # Standing next to a goal
        "goal": (rb(-150 * K + 22, 5.5, 6 * K + 16), rb(-150 * K - 5, 3.5, 6 * K - 4), 30),
        # On the touchline, looking up at the stands
        "touchline": (rb(0, 6, -96 * K + 14), rb(0, 22, -96 * K - 64), 22),
    }
    wanted = os.environ.get("PREVIEW_VIEWS", "aerial,pitch,stand").split(",")
    for name in wanted:
        loc, target, lens = views[name]
        camera(scene, loc, target, lens)
        scene.render.filepath = os.path.join(out, f"stadium_{name}.png")
        bpy.ops.render.render(write_still=True)
        print("rendered", name)


if __name__ == "__main__":
    main()
