"""
Renders animation preview contact sheets from tools/lune/preview_anim.luau output.

    python blender/preview_poses.py blender/out/preview/poses.json blender/out/preview [case ...]

Needs the `bpy` module (pip install bpy). Each case gets two images: <case>_side.png (profile,
character facing right) and <case>_front.png (three-quarter front view).
"""

import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

RES = int(os.environ.get('PREVIEW_RES', '300'))
P = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # Roblox (x, y, z) -> Blender (x, -z, y)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 12
    scene.cycles.use_denoising = False
    scene.cycles.device = "CPU"
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.82, 0.86, 0.92, 1)
    bg.inputs[1].default_value = 1.0
    scene.world = world
    return scene


_materials = {}


def material(color):
    key = tuple(round(c, 3) for c in color)
    if key in _materials:
        return _materials[key]
    m = bpy.data.materials.new(f"m{len(_materials)}")
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*key, 1)
    bsdf.inputs["Roughness"].default_value = 0.6
    _materials[key] = m
    return m


_meshes = {}


def base_mesh(shape):
    if shape in _meshes:
        return _meshes[shape]
    if shape == "Ball":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=24, ring_count=12)
    elif shape == "Cylinder":
        bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=1, vertices=20, rotation=(0, math.pi / 2, 0))
        bpy.ops.object.transform_apply(rotation=True)
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.active_object
    mesh = obj.data
    mesh.materials.append(material((0.5, 0.5, 0.5)))  # one slot, overridden per object
    bpy.data.objects.remove(obj)
    _meshes[shape] = mesh
    return mesh


def add_part(part, offset, yaw=0.0):
    c = part["cf"]
    pos = Vector((c[0], c[1], c[2]))
    rot = Matrix(((c[3], c[4], c[5]), (c[6], c[7], c[8]), (c[9], c[10], c[11])))
    rb = P @ rot @ P.transposed()
    pb = P @ pos
    m = Matrix.Translation(pb) @ rb.to_4x4()
    if yaw:
        m = Matrix.Rotation(yaw, 4, "Z") @ m
    m = Matrix.Translation(offset) @ m
    sx, sy, sz = part["size"]
    shape = part.get("shape", "Block")
    obj = bpy.data.objects.new(part["name"], base_mesh(shape))
    obj.matrix_world = m @ Matrix.Diagonal((sx, sz, sy, 1))
    bpy.context.scene.collection.objects.link(obj)
    obj.material_slots[0].link = "OBJECT"
    obj.material_slots[0].material = material(part["color"])
    return obj


def ground(length, along):
    bpy.ops.mesh.primitive_plane_add(size=1)
    g = bpy.context.active_object
    if along == "x":
        g.scale = (length + 8, 10, 1)
        g.location = (length / 2 - 3, 0, 0)
    else:
        g.scale = (10, length + 8, 1)
        g.location = (0, length / 2 - 3, 0)
    g.active_material = material((0.35, 0.55, 0.3))


def lights():
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.5
    o = bpy.data.objects.new("Sun", sun)
    o.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    bpy.context.scene.collection.objects.link(o)


def camera(loc, look_at, ortho_scale):
    cam = bpy.data.cameras.new("Cam")
    cam.type = "ORTHO"
    cam.ortho_scale = ortho_scale
    o = bpy.data.objects.new("Cam", cam)
    o.location = loc
    direction = Vector(look_at) - Vector(loc)
    o.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(o)
    bpy.context.scene.camera = o


def render(case, out_dir, view):
    scene = reset_scene()
    _materials.clear()
    _meshes.clear()
    frames = case["frames"]
    n = len(frames)
    spacing = 6.0
    length = (n - 1) * spacing
    if view == "side":
        for i, f in enumerate(frames):
            for part in f["parts"]:
                add_part(part, Vector((0, i * spacing, 0)), yaw=0)
        ground(length, "y")
        camera((60, length / 2, 3), (0, length / 2, 3), max(12, length + 7))
    else:
        for i, f in enumerate(frames):
            for part in f["parts"]:
                add_part(part, Vector((i * spacing, 0, 0)), yaw=math.radians(-28))
        ground(length, "x")
        camera((length / 2, 60, 9), (length / 2, 0, 2.6), max(12, length + 7))
    lights()
    scene.render.resolution_x = int(RES * 0.8) * max(2, n)
    scene.render.resolution_y = RES
    scene.render.resolution_percentage = 100
    scene.render.filepath = os.path.join(out_dir, f"{case['name']}_{view}.png")
    bpy.ops.render.render(write_still=True)


def main():
    args = sys.argv[1:]
    data = json.load(open(args[0]))
    out_dir = args[1]
    wanted = set(args[2:])
    os.makedirs(out_dir, exist_ok=True)
    for case in data:
        if wanted and case["name"] not in wanted:
            continue
        for view in os.environ.get("PREVIEW_VIEWS", "side,front").split(","):
            render(case, out_dir, view)
            print("rendered", case["name"], view)


if __name__ == "__main__":
    main()
