"""Generate the original Banco do Tabuleiro board scene and preview with Blender.

Run from the project root:
  blender -b --python Scripts/generate_board_assets.py -- BancoDoTabuleiro/Art.scnassets

The generated USDZ is bundled by the iOS app. The SwiftUI/SceneKit fallback remains
available when Blender is not installed during local development.
"""

from __future__ import annotations

import math
import os
import sys

import bpy
from mathutils import Vector


def destination() -> str:
    if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1:
        return os.path.abspath(sys.argv[sys.argv.index("--") + 1])
    return os.path.abspath("BancoDoTabuleiro/Art.scnassets")


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def material(name: str, color: tuple[float, float, float, float], roughness: float = 0.34, metallic: float = 0.0):
    value = bpy.data.materials.new(name)
    value.diffuse_color = color
    value.use_nodes = True
    shader = value.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    coat = shader.inputs.get("Coat Weight")
    if coat:
        coat.default_value = 0.28
    return value


def beveled_cube(name: str, location: tuple[float, float, float], scale: tuple[float, float, float], mat, bevel: float = 0.045):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Soft premium edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return obj


def make_token(index: int, color) -> None:
    root = bpy.data.objects.new(f"Token_{index}", None)
    bpy.context.scene.collection.objects.link(root)
    root.empty_display_type = "CIRCLE"
    root.location = (0.0, 0.0, 0.15)

    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.14, depth=0.09, location=(0, 0, 0.05))
    base = bpy.context.object
    base.name = f"Token_{index}_Base"
    base.data.materials.append(color)
    base.parent = root

    bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=0.12, radius2=0.025, depth=0.31, location=(0, 0, 0.23))
    body = bpy.context.object
    body.name = f"Token_{index}_Body"
    body.data.materials.append(color)
    body.parent = root

    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=0.065, location=(0, 0, 0.43))
    head = bpy.context.object
    head.name = f"Token_{index}_Head"
    head.data.materials.append(color)
    head.parent = root

    point = space_position((index - 1) * 2)
    root.location = (point.x, point.y, 0.16)


def space_position(index: int) -> Vector:
    side = index // 5
    offset = (index % 5) * 0.82 - 1.64
    if side == 0:
        return Vector((offset, -1.64, 0.13))
    if side == 1:
        return Vector((1.64, offset, 0.13))
    if side == 2:
        return Vector((-offset, 1.64, 0.13))
    return Vector((-1.64, -offset, 0.13))


def make_board() -> None:
    felt = material("Deep evergreen felt", (0.10, 0.28, 0.20, 1), roughness=0.7)
    walnut = material("Warm walnut edge", (0.20, 0.085, 0.035, 1), roughness=0.3)
    ivory = material("Ivory board paper", (0.94, 0.88, 0.72, 1), roughness=0.52)
    gold = material("Brushed antique gold", (0.73, 0.48, 0.13, 1), roughness=0.25, metallic=0.55)
    brick = material("Terracotta accent", (0.58, 0.19, 0.13, 1), roughness=0.36)
    sage = material("Sage green accent", (0.39, 0.57, 0.37, 1), roughness=0.44)
    blue = material("Slate blue accent", (0.23, 0.39, 0.52, 1), roughness=0.38)
    print_ink = material("Board space lettering", (0.08, 0.15, 0.12, 1), roughness=0.5)

    beveled_cube("Board_Walnut_Base", (0, 0, -0.05), (4.55, 4.55, 0.30), walnut, 0.10)
    beveled_cube("Board_Felt_Inlay", (0, 0, 0.12), (4.20, 4.20, 0.10), felt, 0.07)
    beveled_cube("Board_Center", (0, 0, 0.20), (3.38, 3.38, 0.055), ivory, 0.04)

    accents = [gold, ivory, brick, sage, blue]
    for index in range(20):
        point = space_position(index)
        tile = beveled_cube(
            f"Space_{index:02d}",
            (point.x, point.y, 0.24),
            (0.66, 0.66, 0.10),
            accents[index % len(accents)],
            0.035,
        )
        tile["space_index"] = index
        label_size = 0.09 if index == 0 else 0.15
        label_text = "INICIO" if index == 0 else f"{index:02d}"
        edge_rotation = (0, math.pi / 2, math.pi, -math.pi / 2)[index // 5]
        bpy.ops.object.text_add(location=(point.x, point.y, 0.30))
        label = bpy.context.object
        label.name = f"SpaceLabel_{index:02d}"
        label.data.body = label_text
        label.data.align_x = "CENTER"
        label.data.align_y = "CENTER"
        label.data.size = label_size
        label.data.extrude = 0.001
        label.data.materials.append(print_ink)
        label.rotation_euler.z = edge_rotation
        bpy.ops.object.convert(target="MESH")
        bpy.context.object.name = f"SpaceLabel_{index:02d}"

    # Small original town hall and abstract city blocks; no protected board art.
    city_white = material("Town hall limestone", (0.88, 0.79, 0.59, 1), roughness=0.42)
    town = beveled_cube("TownHall", (0, 0, 0.46), (0.62, 0.58, 0.48), city_white, 0.035)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.49, radius2=0.0, depth=0.32, location=(0, 0, 0.86))
    roof = bpy.context.object
    roof.name = "TownHall_Roof"
    roof.data.materials.append(brick)
    roof.rotation_euler[2] = math.pi / 4
    buildings = [
        ((-0.92, -0.62, 0.38), (0.38, 0.44, 0.35)),
        ((0.87, -0.62, 0.40), (0.34, 0.48, 0.39)),
        ((-0.91, 0.67, 0.41), (0.36, 0.36, 0.40)),
        ((0.88, 0.62, 0.36), (0.42, 0.36, 0.30)),
    ]
    for index, (location, size) in enumerate(buildings):
        house = beveled_cube(f"City_Block_{index + 1}", location, size, [sage, blue, ivory, brick][index], 0.025)
        house.parent = town
    del town

    for index, color in enumerate([
        material("Player ruby", (0.72, 0.075, 0.08, 1), roughness=0.22),
        material("Player emerald", (0.035, 0.38, 0.22, 1), roughness=0.22),
        material("Player sapphire", (0.08, 0.24, 0.65, 1), roughness=0.22),
        material("Player violet", (0.42, 0.14, 0.59, 1), roughness=0.22),
        material("Player amber", (0.84, 0.43, 0.07, 1), roughness=0.22),
        material("Player teal", (0.04, 0.44, 0.50, 1), roughness=0.22),
    ], 1):
        make_token(index, color)

    die_mat = material("Ivory dice", (0.96, 0.91, 0.78, 1), roughness=0.22)
    pip_mat = material("Dice pip enamel", (0.055, 0.075, 0.063, 1), roughness=0.28)
    pip_layouts = {
        1: [(0, 0)],
        2: [(-0.075, -0.075), (0.075, 0.075)],
        3: [(-0.075, -0.075), (0, 0), (0.075, 0.075)],
        4: [(-0.075, -0.075), (0.075, -0.075), (-0.075, 0.075), (0.075, 0.075)],
        5: [(-0.075, -0.075), (0.075, -0.075), (0, 0), (-0.075, 0.075), (0.075, 0.075)],
        6: [(-0.075, -0.075), (0, -0.075), (0.075, -0.075), (-0.075, 0.075), (0, 0.075), (0.075, 0.075)],
    }
    for index, (x, value) in enumerate(((-0.25, 5), (0.25, 2)), 1):
        die = beveled_cube(f"Die_{index}", (x, -0.86, 0.40), (0.34, 0.34, 0.34), die_mat, 0.055)
        for pip_index, (pip_x, pip_y) in enumerate(pip_layouts[value], 1):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=0.026, location=(0, 0, 0))
            pip = bpy.context.object
            pip.name = f"Die_{index}_Pip_{pip_index:02d}"
            pip.data.materials.append(pip_mat)
            pip.parent = die
            pip.location = (pip_x, pip_y, 0.174)
        die.rotation_euler = (0.28, -0.22, 0.18 * index)


def setup_camera_and_lights() -> None:
    bpy.ops.object.camera_add(location=(6.1, -7.4, 8.6))
    camera = bpy.context.object
    camera.name = "Board_Studio_Camera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 7.6
    camera.rotation_euler = (Vector((0, 0, 0.1)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera

    for name, location, energy, size, color in [
        ("Warm key", (-4, -4, 8), 1000, 5.0, (1.0, 0.78, 0.48)),
        ("Soft fill", (4, -1, 6), 650, 4.0, (0.55, 0.78, 1.0)),
        ("Gold rim", (0, 5, 5), 900, 3.0, (1.0, 0.55, 0.20)),
    ]:
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        light.data.color = color
        light.rotation_euler = (Vector((0, 0, 0)) - light.location).to_track_quat("-Z", "Y").to_euler()

    world = bpy.data.worlds.new("Board studio world") if not bpy.data.worlds else bpy.data.worlds[0]
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.025, 0.045, 0.035, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.32


def export_assets(output_dir: str) -> None:
    os.makedirs(output_dir, exist_ok=True)
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    blender_dir = os.path.join(project_root, "Blender")
    os.makedirs(blender_dir, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 1280
    scene.render.resolution_percentage = 70
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.filepath = os.path.join(blender_dir, "PIX-Board-preview.png")
    scene.view_settings.view_transform = "AgX"

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "EMPTY"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects.get("Board_Walnut_Base")

    bpy.ops.wm.usd_export(
        filepath=os.path.join(output_dir, "BoardScene.usdz"),
        selected_objects_only=True,
        export_animation=False,
        export_materials=True,
        generate_preview_surface=True,
        export_lights=False,
        export_cameras=False,
        export_curves=False,
    )
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(blender_dir, "PIX-Board-Studio.blend"))
    bpy.ops.render.render(write_still=True)


def main() -> None:
    clear_scene()
    make_board()
    setup_camera_and_lights()
    export_assets(destination())
    print("Generated BoardScene.usdz and Blender board preview.")


if __name__ == "__main__":
    main()
