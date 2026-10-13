"""Builds the Ball, Goal and Keeper meshes and exports one FBX per model.

Run from the repo root:
    blender --background --python assets/source/build_models.py

Units are studs. Blender is Z-up; models face -Y (Blender's front view) and
are exported facing +Z in Roblox (towards the shooter).
Each model is split into one mesh per colour; colours are applied in Roblox.
Writes assets/source/models.blend and assets/export/<Model>.fbx.
"""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT_DIR = os.path.normpath(os.path.join(HERE, "..", "export"))

# Must match src/shared/config.luau and docs/art-standard.md.
GOAL_WIDTH = 24.0
GOAL_HEIGHT = 8.0
BALL_RADIUS = 0.7


# ---------------------------------------------------------------- helpers


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def link(obj, collection):
    collection.objects.link(obj)
    return obj


def new_collection(name):
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    return col


def bake(obj, name):
    """Replace obj (curve or modified mesh) with a plain mesh object."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    obj.name = name + "_source"  # free the name for the baked object
    baked = bpy.data.objects.new(name, mesh)
    for col in obj.users_collection:
        col.objects.link(baked)
    bpy.data.objects.remove(obj)
    return baked


def mesh_object(name, bm, collection):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return link(bpy.data.objects.new(name, mesh), collection)


def join(objects, name):
    """Merge mesh objects into one."""
    bm = bmesh.new()
    for obj in objects:
        temp = obj.data.copy()
        temp.transform(obj.matrix_world)
        bm.from_mesh(temp)
        bpy.data.meshes.remove(temp)
    collection = objects[0].users_collection[0]
    for obj in objects:
        bpy.data.objects.remove(obj)
    return mesh_object(name, bm, collection)


def smooth(obj, angle_deg=50):
    mesh = obj.data
    mesh.use_auto_smooth = True
    mesh.auto_smooth_angle = math.radians(angle_deg)
    for poly in mesh.polygons:
        poly.use_smooth = True


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def rounded_path(points, radius, steps=6):
    """Polyline with each interior corner replaced by a quadratic arc."""
    pts = [Vector(p) for p in points]
    out = [pts[0]]
    for i in range(1, len(pts) - 1):
        a, p, b = pts[i - 1], pts[i], pts[i + 1]
        r = min(radius, (a - p).length / 2, (b - p).length / 2)
        start = p + (a - p).normalized() * r
        end = p + (b - p).normalized() * r
        for s in range(steps + 1):
            t = s / steps
            out.append(start * (1 - t) ** 2 + p * 2 * (1 - t) * t + end * t * t)
    out.append(pts[-1])
    return out


def tubes(name, paths, radius, collection, sides_resolution=3, caps=True):
    """One mesh of round tubes following each path."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = sides_resolution
    curve.use_fill_caps = caps
    for path in paths:
        spline = curve.splines.new("POLY")
        spline.points.add(len(path) - 1)
        for i, p in enumerate(path):
            spline.points[i].co = (p[0], p[1], p[2], 1)
    obj = link(bpy.data.objects.new(name, curve), collection)
    return bake(obj, name)


def ellipsoid(name, centre, radii, collection, segments=16, rings=10):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1)
    for v in bm.verts:
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2])) + Vector(centre)
    return mesh_object(name, bm, collection)


def rounded_box(name, centre, size, bevel, collection):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(centre)
    bmesh.ops.bevel(
        bm,
        geom=list(bm.edges),
        offset=bevel,
        offset_type="OFFSET",
        segments=3,
        profile=0.5,
        affect="EDGES",
    )
    return mesh_object(name, bm, collection)


# ------------------------------------------------------------------- ball


def build_ball():
    """Classic football: 12 dark pentagons, 20 white hexagons, on a sphere."""
    col = new_collection("Ball")
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1)
    # Cutting each vertex a third of the way along its edges gives a
    # truncated icosahedron; the new faces are the pentagons.
    result = bmesh.ops.bevel(
        bm,
        geom=list(bm.verts),
        offset=100 / 3,
        offset_type="PERCENT",
        segments=1,
        profile=0.5,
        affect="VERTICES",
    )
    pentagons = set(result["faces"])
    for face in bm.faces:
        face.material_index = 1 if face in pentagons else 0

    # Fan each face from its centre, split once more, then push to a sphere.
    bmesh.ops.poke(bm, faces=list(bm.faces))
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=1, use_grid_fill=True)
    for v in bm.verts:
        v.co = v.co.normalized() * BALL_RADIUS
    # Ball sits on the ground: centre at z = radius.
    bmesh.ops.translate(bm, verts=list(bm.verts), vec=(0, 0, BALL_RADIUS))

    parts = []
    for index, name in ((0, "BallWhite"), (1, "BallPanels")):
        piece = bm.copy()
        bmesh.ops.delete(piece, geom=[f for f in piece.faces if f.material_index != index], context="FACES")
        obj = mesh_object(name, piece, col)
        smooth(obj, 80)
        parts.append(obj)
    bm.free()
    return parts


# ------------------------------------------------------------------- goal


def build_goal():
    """Round frame, grey supports and a string net. Net goes back along +Y."""
    col = new_collection("Goal")
    post_r = 0.4
    post_x = GOAL_WIDTH / 2 + post_r
    bar_z = GOAL_HEIGHT + post_r
    top_depth, bottom_depth = 2.0, 4.0
    support_r = 0.15
    ground = support_r

    frame_path = rounded_path(
        [(-post_x, 0, 0), (-post_x, 0, bar_z), (post_x, 0, bar_z), (post_x, 0, 0)], radius=0.9, steps=8
    )
    frame = tubes("GoalFrame", [frame_path], post_r, col, sides_resolution=4)

    support_paths = []
    for side in (-1, 1):
        x = side * post_x
        support_paths.append(
            rounded_path(
                [(x, 0, bar_z), (x, top_depth, bar_z), (x, bottom_depth, ground), (x, 0, ground)], radius=0.4
            )
        )
    support_paths.append([(-post_x, top_depth, bar_z), (post_x, top_depth, bar_z)])
    support_paths.append([(-post_x, bottom_depth, ground), (post_x, bottom_depth, ground)])
    supports = tubes("GoalSupports", support_paths, support_r, col, sides_resolution=2)

    # Net strings, 1 stud apart, just inside the frame.
    half, h, spacing = GOAL_WIDTH / 2, GOAL_HEIGHT, 1.0

    def back_y(z):
        return top_depth + (bottom_depth - top_depth) * (1 - z / h)

    lines = []
    steps_x = int(GOAL_WIDTH / spacing)
    for i in range(steps_x + 1):
        x = -half + i * spacing
        lines.append([(x, 0, h), (x, top_depth, h), (x, bottom_depth, 0)])  # roof + back
    for z in [spacing * k for k in range(1, int(h / spacing))]:
        y = back_y(z)
        lines.append([(-half, 0, z), (-half, y, z), (half, y, z), (half, 0, z)])  # sides + back
    for y in [spacing * k for k in range(1, int(top_depth / spacing))]:
        lines.append([(-half, y, h), (half, y, h)])  # roof rows
    for y in [spacing * k for k in range(1, int(bottom_depth / spacing) + 1)]:
        top = h if y <= top_depth else h * (1 - (y - top_depth) / (bottom_depth - top_depth))
        if top > 0.05:
            for side in (-1, 1):
                lines.append([(side * half, y, 0), (side * half, y, top)])  # side columns
    net = tubes("GoalNet", lines, 0.04, col, sides_resolution=0, caps=False)

    for obj in (frame, supports):
        smooth(obj, 60)
    return [frame, supports, net]


# ----------------------------------------------------------------- keeper


# Rest-pose joints in Blender coords (x, y, z); front is -Y. The Roblox side
# sees these as (x, z, -y) and must match KEEPER_JOINTS in src/client/Keeper.luau.
# "L" is the keeper's own left (+X).
KEEPER_JOINTS = {
    "Pelvis": (0, 0, 2.2),
    "Waist": (0, 0, 2.45),
    "Neck": (0, 0, 4.25),
}
for _side, _tag in ((1, "L"), (-1, "R")):
    KEEPER_JOINTS["Shoulder" + _tag] = (_side * 1.0, 0, 4.0)
    KEEPER_JOINTS["Elbow" + _tag] = (_side * 1.35, 0, 3.05)
    KEEPER_JOINTS["Wrist" + _tag] = (_side * 1.6, 0, 2.15)
    KEEPER_JOINTS["Hip" + _tag] = (_side * 0.45, 0, 2.05)
    KEEPER_JOINTS["Knee" + _tag] = (_side * 0.5, 0, 1.2)
    KEEPER_JOINTS["Ankle" + _tag] = (_side * 0.5, 0, 0.42)


def capsule(name, a, b, ra, rb, collection, depth_scale=1.0, segments=16, rings=10):
    """Tapered capsule from a (radius ra) to b (radius rb), optionally flattened in Y."""
    a, b = Vector(a), Vector(b)
    axis = b - a
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1)
    rot = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix()
    for v in bm.verts:
        if v.co.z >= 0:
            local = Vector((v.co.x * rb, v.co.y * rb, v.co.z * rb + axis.length))
        else:
            local = Vector((v.co.x * ra, v.co.y * ra, v.co.z * ra))
        p = rot @ local
        p.y *= depth_scale
        v.co = a + p
    return mesh_object(name, bm, collection)


def build_keeper():
    """Stylised goalkeeper split into rigid segments that the game poses.

    About 5.9 studs tall, feet at z = 0, facing -Y. Segments overlap with
    rounded ends at the joints so they bend without gaps.
    """
    col = new_collection("Keeper")
    j = KEEPER_JOINTS
    parts = []

    parts.append(capsule("Torso", (0, 0, 2.35), (0, 0, 3.95), 0.74, 0.92, col, depth_scale=0.72))
    parts.append(capsule("Shorts", (0, 0, 1.95), (0, 0, 2.45), 0.76, 0.76, col, depth_scale=0.78))

    head = ellipsoid("HeadSkin", (0, 0, 5.0), (0.78, 0.74, 0.8), col, segments=24, rings=14)
    neck = capsule("Neck", (0, 0, 4.0), (0, 0, 4.6), 0.36, 0.36, col, segments=12, rings=6)
    parts.append(join([head, neck], "Head"))

    hair = ellipsoid("Hair", (0, 0.03, 5.06), (0.82, 0.78, 0.82), col, segments=24, rings=14)
    hbm = bmesh.new()
    hbm.from_mesh(hair.data)
    # Keep a cap above a tilted plane: clear of the eyes, lower at the back.
    geom = list(hbm.verts) + list(hbm.edges) + list(hbm.faces)
    bmesh.ops.bisect_plane(
        hbm, geom=geom, dist=0.0001, plane_co=(0, 0, 5.3), plane_no=(0, 0.5, 1), clear_inner=True
    )
    hbm.to_mesh(hair.data)
    hbm.free()
    eyes = [ellipsoid("Eye", (s * 0.27, -0.7, 5.1), (0.09, 0.05, 0.14), col, segments=10, rings=6) for s in (-1, 1)]
    parts.append(join([hair] + eyes, "HeadDark"))

    for tag in ("L", "R"):
        shoulder, elbow, wrist = Vector(j["Shoulder" + tag]), Vector(j["Elbow" + tag]), Vector(j["Wrist" + tag])
        parts.append(capsule("UpperArm" + tag, shoulder, elbow, 0.4, 0.32, col))
        parts.append(capsule("Forearm" + tag, elbow, wrist, 0.31, 0.27, col))
        # Glove: a padded mitt continuing past the wrist.
        direction = (wrist - elbow).normalized()
        glove = ellipsoid("Glove" + tag, (0, 0, 0), (0.36, 0.3, 0.48), col, segments=16, rings=10)
        rot = Vector((0, 0, 1)).rotation_difference(direction).to_matrix().to_4x4()
        glove.data.transform(Matrix.Translation(wrist + direction * 0.32) @ rot)
        parts.append(glove)

        hip, knee, ankle = Vector(j["Hip" + tag]), Vector(j["Knee" + tag]), Vector(j["Ankle" + tag])
        parts.append(capsule("Thigh" + tag, hip, knee, 0.45, 0.36, col))
        shin = capsule("ShinPart" + tag, knee, ankle, 0.35, 0.29, col)
        boot = rounded_box("Boot" + tag, (ankle.x, -0.15, 0.22), (0.62, 0.95, 0.44), 0.12, col)
        parts.append(join([shin, boot], "Shin" + tag))

    for obj in parts:
        smooth(obj, 70)
    return parts


# ----------------------------------------------------------------- export


def export(name, objects):
    # Roblox ignores the FBX axis settings and maps Blender +Y to +Z, so turn
    # the meshes 180 degrees for export: the model front (-Y) becomes +Z.
    turn = Matrix.Rotation(math.pi, 4, "Z")
    for obj in objects:
        obj.data.transform(turn)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    path = os.path.join(EXPORT_DIR, name + ".fbx")
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        use_mesh_modifiers=True,
        bake_anim=False,
    )
    for obj in objects:
        obj.data.transform(turn.inverted())
    return path


def main():
    reset_scene()
    os.makedirs(EXPORT_DIR, exist_ok=True)
    models = {"Ball": build_ball(), "Goal": build_goal(), "Keeper": build_keeper()}
    report = {}
    for name, objects in models.items():
        export(name, objects)
        report[name] = {obj.name: triangles(obj) for obj in objects}
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "models.blend"))
    for name, counts in report.items():
        print(f"{name}: {sum(counts.values())} triangles {counts}")


if __name__ == "__main__":
    main()
