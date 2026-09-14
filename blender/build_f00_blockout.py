"""
build_f00_blockout.py

Run this INSIDE Blender (Scripting tab -> Open -> Run Script) to procedurally
build a flat-colored 3D block-out of the F0 prologue map. Terrain height
stands in for "stepped terraces" -- this is a placeholder to prove the
Blender -> glTF -> Godot pipeline, not final art. The statue tile is the one
exception: it's built as a small shrine (raised dais, a ring of columns, a
tiered idol) rather than a flat box, carried over from
render_temple_vignette.py's standalone study once that composition held up.
It's deliberately abstract rather than a literal humanoid figure --
PROJECT_HANDOFF.md is explicit that "the living patron" is never shown to
the player, only "the image," the carved object the army destroys.

The grid below is a copy of map_f00.txt (kept inline so this script has no
file-path dependency -- Blender may be run from anywhere). If map_f00.txt
changes, paste the updated 16 rows in here too.

Safe to re-run: it deletes any existing mesh objects first.

After running, export manually: File > Export > glTF 2.0 (.glb/.gltf),
format "glTF Binary (.glb)", save as game/assets/f00_blockout.glb in the
repo.
"""

import math

import bpy
import bmesh

for obj in list(bpy.data.objects):
    if obj.type == "MESH":
        bpy.data.objects.remove(obj, do_unlink=True)

GRID = """
xxxxxxxxxxxxxxxxxxxxxxxx
TTTTTTTTTSTTTTTTTTTTTTTT
TTTTTTTTT*TTTTTTTTTTTTTT
TTTTTTTTTTTTTTTTTTTTTTTT
xxxxxxxxxxxxxxtttxxxxxxx
gggggggggggggggggggggggg
tttttttttttttttttttttttt
xxxxxtttxxxxxxxxxxxxxxxx
gggggggggggggggggggggggg
tttttttttttttttttttttttt
xxxxxxxxxxxxxxxtttxxxxxx
gggggggggggggggggggggggg
cccccccccccacccccccccccc
........................
WWWWWWWWWWWWWWWWWWWWWWWW
........................
""".strip("\n").split("\n")

STATUE_ROW, STATUE_COL = next(
    (row, line.find("S")) for row, line in enumerate(GRID) if "S" in line
)

# symbol -> (terrain_id suffix, (z_bottom, z_top), (r, g, b) 0-1)
# Colors match the same palette used in Godot's map_grid.gd, for visual
# consistency between the 2D tool and this 3D block-out. Heights are a
# rough "how tall does this read" guess, not authoritative design data --
# there's no height field anywhere in canon.db. "S" keeps its LEGEND entry
# (still needed for map_grid.gd's flat-color 2D render) even though the 3D
# block-out below replaces its box with the shrine.
LEGEND = {
    ".": ("court",       (0.0, 0.15), (0.792, 0.776, 0.737)),
    "a": ("span",        (0.0, 0.15), (0.722, 0.706, 0.659)),
    "T": ("terrace_high", (0.0, 1.2), (0.545, 0.514, 0.467)),
    "x": ("wall_face",   (0.0, 2.4), (0.239, 0.227, 0.208)),
    "W": ("wall",        (0.0, 1.6), (0.627, 0.384, 0.235)),
    "g": ("planted",     (0.0, 0.3), (0.369, 0.545, 0.353)),
    "t": ("stair",       (0.0, 0.7), (0.675, 0.659, 0.612)),
    "S": ("statue",      (0.0, 2.8), (0.165, 0.153, 0.137)),
    "*": ("seize",       (0.0, 0.15), (0.820, 0.659, 0.318)),
    "c": ("channel",     (-0.5, -0.1), (0.290, 0.498, 0.639)),
}


def make_material(name, rgb, roughness=0.9, emission_rgb=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if emission_rgb:
        bsdf.inputs["Emission Color"].default_value = (*emission_rgb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


materials = {sym: make_material(f"terrain_{terrain_id}", rgb) for sym, (terrain_id, _, rgb) in LEGEND.items()}
material_order = list(materials.keys())  # index -> symbol, for face.material_index

bm = bmesh.new()

for row, line in enumerate(GRID):
    for col, symbol in enumerate(line):
        if row == STATUE_ROW and col == STATUE_COL:
            continue  # replaced by the shrine built below
        _, (z0, z1), _ = LEGEND[symbol]
        x0, x1 = col, col + 1
        y0, y1 = -row - 1, -row
        v = [
            bm.verts.new((x0, y0, z0)), bm.verts.new((x1, y0, z0)),
            bm.verts.new((x1, y1, z0)), bm.verts.new((x0, y1, z0)),
            bm.verts.new((x0, y0, z1)), bm.verts.new((x1, y0, z1)),
            bm.verts.new((x1, y1, z1)), bm.verts.new((x0, y1, z1)),
        ]
        box_faces = [
            (0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4),
            (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7),
        ]
        mat_idx = material_order.index(symbol)
        for f in box_faces:
            face = bm.faces.new([v[i] for i in f])
            face.material_index = mat_idx

bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))

mesh = bpy.data.meshes.new("f00_blockout")
bm.to_mesh(mesh)
bm.free()
for sym in material_order:
    mesh.materials.append(materials[sym])

obj = bpy.data.objects.new("f00_blockout", mesh)
bpy.context.collection.objects.link(obj)

# --- the shrine: dais, ring of columns, tiered idol -------------------------
# Carried over from render_temple_vignette.py once that stood on its own;
# see that script's header for how the camera/lighting version was tuned.
CX = STATUE_COL + 0.5
CY = -STATUE_ROW - 0.5
TERRACE_H = 1.2

stone_mat = make_material("shrine_stone", (0.86, 0.83, 0.76), roughness=0.7)
idol_mat = make_material("idol_stone", (0.14, 0.10, 0.075), roughness=0.5)
idol_glow_mat = make_material(
    "idol_glow", (0.12, 0.10, 0.09), roughness=0.4,
    emission_rgb=(0.9, 0.6, 0.25), emission_strength=1.4,
)


def add_cylinder(name, radius1, radius2, depth, x, y, z_center, mat, sides=10):
    bpy.ops.mesh.primitive_cone_add(
        radius1=radius1, radius2=radius2, depth=depth, vertices=sides,
        location=(x, y, z_center),
    )
    cyl_obj = bpy.context.active_object
    cyl_obj.name = name
    cyl_obj.data.materials.append(mat)
    return cyl_obj


# dais: a wide low base flush with the terrace, then a smaller raised step
add_cylinder("shrine_dais_base", 1.05, 1.05, TERRACE_H, CX, CY, TERRACE_H / 2, stone_mat, sides=12)
DAIS_TOP = TERRACE_H + 0.3
add_cylinder("shrine_dais_step", 0.75, 0.75, 0.3, CX, CY, TERRACE_H + 0.15, stone_mat, sides=12)

# a ring of six columns around the dais
COLUMN_H = 1.6
for i in range(6):
    angle = i * (2 * math.pi / 6)
    px = CX + math.cos(angle) * 0.9
    py = CY + math.sin(angle) * 0.9
    add_cylinder(f"shrine_column_{i}", 0.12, 0.08, COLUMN_H, px, py, DAIS_TOP + COLUMN_H / 2, stone_mat, sides=8)

# the idol: three stacked, TIERED segments (each bottom radius wider than the
# previous top, so real ledges break the silhouette instead of one smooth
# cone) plus a glowing finial.
z = DAIS_TOP
add_cylinder("shrine_idol_base", 0.55, 0.42, 1.0, CX, CY, z + 0.5, idol_mat, sides=8)
z += 1.0
add_cylinder("shrine_idol_mid", 0.34, 0.24, 1.0, CX, CY, z + 0.5, idol_mat, sides=8)
z += 1.0
add_cylinder("shrine_idol_upper", 0.20, 0.12, 0.8, CX, CY, z + 0.4, idol_mat, sides=8)
z += 0.8
bpy.ops.mesh.primitive_ico_sphere_add(radius=0.2, subdivisions=2, location=(CX, CY, z + 0.2))
finial = bpy.context.active_object
finial.name = "shrine_idol_finial"
finial.data.materials.append(idol_glow_mat)

print(
    f"Built f00_blockout: {len(GRID)} rows x {len(GRID[0])} cols, "
    f"{len(mesh.polygons)} faces, plus a shrine at ({STATUE_COL},{STATUE_ROW}). "
    f"Now: File > Export > glTF 2.0 (.glb/.gltf), format 'glTF Binary (.glb)', "
    f"save as game/assets/f00_blockout.glb"
)
