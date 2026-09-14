"""
build_f00_blockout.py

Run this INSIDE Blender (Scripting tab -> Open -> Run Script) to procedurally
build a flat-colored 3D block-out of the F0 prologue map. Terrain height
stands in for "stepped terraces" -- this is a placeholder to prove the
Blender -> glTF -> Godot pipeline, not final art.

The grid below is a copy of map_f00.txt (kept inline so this script has no
file-path dependency -- Blender may be run from anywhere). If map_f00.txt
changes, paste the updated 16 rows in here too.

Safe to re-run: it deletes any existing mesh objects first.

After running, export manually: File > Export > glTF 2.0 (.glb/.gltf),
format "glTF Binary (.glb)", save as game/assets/f00_blockout.glb in the
repo.
"""

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

# symbol -> (terrain_id suffix, (z_bottom, z_top), (r, g, b) 0-1)
# Colors match the same palette used in Godot's map_grid.gd, for visual
# consistency between the 2D tool and this 3D block-out. Heights are a
# rough "how tall does this read" guess, not authoritative design data --
# there's no height field anywhere in canon.db.
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


def make_material(terrain_id, rgb):
    mat = bpy.data.materials.new(f"terrain_{terrain_id}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    return mat


materials = {sym: make_material(terrain_id, rgb) for sym, (terrain_id, _, rgb) in LEGEND.items()}
material_order = list(materials.keys())  # index -> symbol, for face.material_index

bm = bmesh.new()

for row, line in enumerate(GRID):
    for col, symbol in enumerate(line):
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

print(
    f"Built f00_blockout: {len(GRID)} rows x {len(GRID[0])} cols, "
    f"{len(mesh.polygons)} faces. Now: File > Export > glTF 2.0 (.glb/.gltf), "
    f"format 'glTF Binary (.glb)', save as game/assets/f00_blockout.glb"
)
