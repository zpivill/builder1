"""Renders a preview PNG of each model in models.blend for checking by eye.

Run from the repo root after build_models.py:
    blender --background assets/source/models.blend --python assets/source/render_previews.py

Writes assets/source/previews/<Model>.png. Colours match the in-game palette.
"""

import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "previews")

# Same palette as src/client/Visuals.luau and src/server/Pitch.luau.
COLOURS = {
    "BallWhite": (0.92, 0.92, 0.92),
    "BallPanels": (0.02, 0.02, 0.03),
    "GoalFrame": (0.92, 0.92, 0.92),
    "GoalSupports": (0.3, 0.33, 0.38),
    "GoalNet": (0.75, 0.77, 0.8),
    "Torso": (0.8, 0.06, 0.03),
    "UpperArm": (0.8, 0.06, 0.03),
    "Forearm": (0.8, 0.06, 0.03),
    "Head": (0.6, 0.27, 0.15),
    "Glove": (1.0, 0.58, 0.02),
    "HeadDark": (0.02, 0.02, 0.03),
    "Shorts": (0.02, 0.02, 0.03),
    "Thigh": (0.02, 0.02, 0.03),
    "Shin": (0.02, 0.02, 0.03),
}

# Camera direction per model: front three-quarter view from the -Y side.
VIEWS = {"Ball": 4, "Goal": 38, "Keeper": 13}


def setup():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "OBJECT"
    shading.show_shadows = True
    shading.show_cavity = True
    scene.render.resolution_x = 900
    scene.render.resolution_y = 700
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("World")
    world.color = (0.55, 0.7, 0.85)
    scene.world = world
    for obj in scene.objects:
        if obj.type == "MESH":
            # Limb segments end in L/R; match on the name without the side.
            base = obj.name.split(".")[0]
            key = base if base in COLOURS else base.rstrip("LR")
            obj.color = (*COLOURS.get(key, (0.5, 0.5, 0.5)), 1)


def render(model):
    scene = bpy.context.scene
    col = bpy.data.collections[model]
    for c in bpy.data.collections:
        c.hide_render = c is not col
    objs = [o for o in col.objects if o.type == "MESH"]
    lo = Vector((min(min((o.matrix_world @ Vector(b))[i] for b in o.bound_box) for o in objs) for i in range(3)))
    hi = Vector((max(max((o.matrix_world @ Vector(b))[i] for b in o.bound_box) for o in objs) for i in range(3)))
    centre = (lo + hi) / 2
    distance = VIEWS[model]

    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    direction = Vector((math.sin(math.radians(25)), -math.cos(math.radians(25)), 0.35)).normalized()
    cam.location = centre + direction * distance
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = 50
    scene.camera = cam

    scene.render.filepath = os.path.join(OUT_DIR, model + ".png")
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    setup()
    for model in VIEWS:
        render(model)


if __name__ == "__main__":
    main()
