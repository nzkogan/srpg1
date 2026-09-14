"""
render_temple_vignette.py

Run this INSIDE Blender (Scripting tab -> Open -> Run Script) to build and
render a focused "hero shot" of the F0 temple terrace -- a raised dais, a
ring of columns, and a tapered idol standing in for "the patron's image"
(prologue_structures.str_statue). This is deliberately NOT a literal
humanoid figure: PROJECT_HANDOFF.md is explicit that "the living patron"
is never shown to the player, in the prologue or ever after -- only "the
image," a carved object the army destroys. An abstract standing-stone form
is more faithful to that than a statue with a face would be.

This is a mood/detail study, not the gameplay data-driven block-out --
build_f00_blockout.py is still the one that drives the actual Godot scene.
Positions here are chosen to sit in the same coordinate space (1 Blender
unit = 1 tile) so this could be merged back into the full block-out later.

Renders straight to a PNG next to this script's working directory when run;
also leaves the built scene in the viewport so it can be inspected/exported
like build_f00_blockout.py.
"""

import math

import bpy
import bmesh
from mathutils import Vector

for obj in list(bpy.data.objects):
    if obj.type in ("MESH", "LIGHT", "CAMERA"):
        bpy.data.objects.remove(obj, do_unlink=True)

# --- cropped context strip around the statue tile (col 9, row 1) ----------
GRID = """
xxxxxxxxxxxxx
TTTTTTSTTTTTT
TTTTTT*TTTTTT
TTTTTTTTTTTTT
xxxxxttxxxxxx
""".strip("\n").split("\n")
# columns 3..15 of the real map_f00.txt, S/* re-centered at local col 6

LEGEND = {
	".": ("court",       (0.0, 0.15), (0.792, 0.776, 0.737)),
	"T": ("terrace_high", (0.0, 1.2), (0.545, 0.514, 0.467)),
	"x": ("wall_face",   (0.0, 2.4), (0.239, 0.227, 0.208)),
	"t": ("stair",       (0.0, 0.7), (0.675, 0.659, 0.612)),
	"*": ("seize",       (0.0, 0.15), (0.820, 0.659, 0.318)),
}

STATUE_COL = 6
STATUE_ROW = 1


def make_material(name, rgb, roughness=0.9, emission_rgb=None, emission_strength=0.0):
	mat = bpy.data.materials.new(name)
	mat.use_nodes = True
	bsdf = mat.node_tree.nodes.get("Principled BSDF")
	bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
	bsdf.inputs["Roughness"].default_value = roughness
	if emission_rgb:
		bsdf.inputs["Emission Color"].default_value = (*emission_rgb, 1.0)
		bsdf.inputs["Emission Strength"].default_value = emission_strength
	return mat


materials = {sym: make_material(f"terrain_{tid}", rgb) for sym, (tid, _, rgb) in LEGEND.items()}
material_order = list(materials.keys())

# --- ground context (same box-per-tile approach as build_f00_blockout.py) -
bm = bmesh.new()
for row, line in enumerate(GRID):
	for col, symbol in enumerate(line):
		if row == STATUE_ROW and col == STATUE_COL:
			continue  # replaced by the dais + idol below
		_, (z0, z1), _ = LEGEND[symbol]
		x0, x1 = col, col + 1
		y0, y1 = -row - 1, -row
		v = [
			bm.verts.new((x0, y0, z0)), bm.verts.new((x1, y0, z0)),
			bm.verts.new((x1, y1, z0)), bm.verts.new((x0, y1, z0)),
			bm.verts.new((x0, y0, z1)), bm.verts.new((x1, y0, z1)),
			bm.verts.new((x1, y1, z1)), bm.verts.new((x0, y1, z1)),
		]
		box_faces = [(0,1,2,3),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
		mat_idx = material_order.index(symbol)
		for f in box_faces:
			face = bm.faces.new([v[i] for i in f])
			face.material_index = mat_idx
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
ground_mesh = bpy.data.meshes.new("temple_ground")
bm.to_mesh(ground_mesh)
bm.free()
for sym in material_order:
	ground_mesh.materials.append(materials[sym])
ground_obj = bpy.data.objects.new("temple_ground", ground_mesh)
bpy.context.collection.objects.link(ground_obj)

# --- the shrine: dais, columns, idol --------------------------------------
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
	obj = bpy.context.active_object
	obj.name = name
	obj.data.materials.append(mat)
	return obj


# dais: a wide low base flush with the terrace, then a smaller raised step
add_cylinder("dais_base", 1.05, 1.05, TERRACE_H, CX, CY, TERRACE_H / 2, stone_mat, sides=12)
DAIS_TOP = TERRACE_H + 0.3
add_cylinder("dais_step", 0.75, 0.75, 0.3, CX, CY, TERRACE_H + 0.15, stone_mat, sides=12)

# a ring of six columns around the dais
COLUMN_H = 1.6
for i in range(6):
	angle = i * (2 * math.pi / 6)
	px = CX + math.cos(angle) * 0.9
	py = CY + math.sin(angle) * 0.9
	add_cylinder(f"column_{i}", 0.12, 0.08, COLUMN_H, px, py, DAIS_TOP + COLUMN_H / 2, stone_mat, sides=8)

# the idol: three stacked, TIERED segments (each bottom radius wider than the
# previous top, so real ledges break the silhouette instead of one smooth
# cone) plus a glowing finial. Tiered/stepped over a single smooth taper on
# purpose -- it reads closer to the setting's ziggurat/ancient-Near-East
# lineage than a plain obelisk would.
z = DAIS_TOP
seg1 = add_cylinder("idol_base", 0.55, 0.42, 1.0, CX, CY, z + 0.5, idol_mat, sides=8)
z += 1.0
seg2 = add_cylinder("idol_mid", 0.34, 0.24, 1.0, CX, CY, z + 0.5, idol_mat, sides=8)
z += 1.0
seg3 = add_cylinder("idol_upper", 0.20, 0.12, 0.8, CX, CY, z + 0.4, idol_mat, sides=8)
z += 0.8
bpy.ops.mesh.primitive_ico_sphere_add(radius=0.2, subdivisions=2, location=(CX, CY, z + 0.2))
finial = bpy.context.active_object
finial.name = "idol_finial"
finial.data.materials.append(idol_glow_mat)
IDOL_TOP = z + 0.4

# --- lighting: key sun + cool fill (rain-sky bounce) + warm glow on the idol's head ---
bpy.ops.object.light_add(type="SUN", location=(CX - 6, CY - 4, 8))
sun = bpy.context.active_object
sun.data.energy = 3.5
sun.data.angle = math.radians(4)  # soft-ish shadow edge, not razor sharp
sun.rotation_euler = (math.radians(55), 0, math.radians(-40))

# cool fill roughly from the camera's side, standing in for bounced sky/rain
# light -- without it the camera-facing side of the idol is pure silhouette
bpy.ops.object.light_add(type="SUN", location=(CX, CY + 6, 6))
fill = bpy.context.active_object
fill.data.energy = 2.6
fill.data.color = (0.55, 0.65, 0.85)
fill.rotation_euler = (math.radians(-40), 0, 0)

# rim/back light from beyond the idol (opposite the camera) so its tapered
# silhouette actually reads as layered segments, not one flat black shape
bpy.ops.object.light_add(type="SUN", location=(CX, CY - 6, 5))
rim = bpy.context.active_object
rim.data.energy = 3.0
rim.data.color = (0.65, 0.72, 0.95)
rim.rotation_euler = (math.radians(120), 0, 0)

bpy.ops.object.light_add(type="POINT", location=(CX + 0.6, CY - 0.6, IDOL_TOP - 0.3))
glow = bpy.context.active_object
glow.data.energy = 55
glow.data.color = (1.0, 0.75, 0.4)
glow.data.shadow_soft_size = 0.3

bpy.context.scene.eevee.use_gtao = True
bpy.context.scene.eevee.gtao_distance = 1.5

# stormy night sky via the world background
world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
bpy.context.scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
bg.inputs["Color"].default_value = (0.05, 0.06, 0.09, 1.0)
bg.inputs["Strength"].default_value = 0.6

# --- camera: low, close, looking up at the idol for an imposing angle -----
# (kept well outside the ground strip's Y range of [-5,0] and the shrine's
# ~1.5-unit radius, after an earlier attempt landed the eye INSIDE a tall
# border tile -- verified via a bbox/position dump, not just recomputed math)
eye = Vector((CX - 1.5, 6.5, 3.4))
target = Vector((CX, CY, DAIS_TOP + (IDOL_TOP - DAIS_TOP) / 2))
bpy.ops.object.camera_add(location=eye)
cam = bpy.context.active_object
cam.rotation_mode = "QUATERNION"
cam.rotation_quaternion = (target - eye).to_track_quat("-Z", "Y")
cam.data.lens = 42
bpy.context.scene.camera = cam

# --- render ----------------------------------------------------------------
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene.eevee.taa_render_samples = 96
scene.render.filepath = "//temple_vignette.png"
bpy.ops.render.render(write_still=True)

print("Rendered temple_vignette.png next to this .blend/script's working directory.")
