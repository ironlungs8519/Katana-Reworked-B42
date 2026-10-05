"""Builds the KT_Temper animation on the PZ Bip01 rig (Blender, headless).
Usage: python3 tools/build_temper_anim.py <rig.fbx> <out_dir>
Outputs KT_Temper.fbx and a stick-figure preview (preview.png). Original animation, no third-party data."""
import sys, os, math
import bpy
from mathutils import Matrix, Vector, Euler

rig_fbx, out = sys.argv[-2], sys.argv[-1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=rig_fbx)
arm = bpy.data.objects['Bip01']
bpy.context.view_layer.objects.active = arm
for o in list(bpy.data.objects):          # keep rig + prop empties only
    if o.type == 'MESH': bpy.data.objects.remove(o, do_unlink=True)
# The game derives the animation's skeleton from a skinned mesh inside the FBX ("No such mesh null" / NPE
# "this.skeleton is null" otherwise). Add a tiny dummy mesh with one vertex weighted 100% to each bone.
import bmesh
bpy.ops.object.mode_set(mode='OBJECT')
bm = bmesh.new()
bones = [b.name for b in arm.data.bones]
verts = [bm.verts.new((0.0001 * (i % 6), 0.0001 * (i // 6), 0.0)) for i in range(len(bones))]
for i in range(0, len(verts) - 2, 1):
    try: bm.faces.new((verts[i], verts[i + 1], verts[i + 2]))
    except ValueError: pass
dmesh = bpy.data.meshes.new("KT_SkelMesh"); bm.to_mesh(dmesh); bm.free()
dobj = bpy.data.objects.new("KT_SkelMesh", dmesh); bpy.context.scene.collection.objects.link(dobj)
for i, name in enumerate(bones):
    vg = dobj.vertex_groups.new(name=name); vg.add([i], 1.0, 'REPLACE')
mod = dobj.modifiers.new("Armature", 'ARMATURE'); mod.object = arm
dobj.parent = arm
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')

FPS, N = 30, 90                              # 3 s loop
bpy.context.scene.render.fps = FPS
bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, N

# --- pose spec: armature-space axis rotations (deg) per bone: (x, y, z) applied Z*Y*X
# armature: X lateral (R arm = -X), Y up, Z forward
POSE = {
    "Bip01_Spine1":     (14, 0, 0),
    "Bip01_Neck":       (12, 8, 0),
    "Bip01_R_UpperArm": (-25, 0, 62),
    "Bip01_R_Forearm":  (-70, 0, 8),
    "Bip01_L_UpperArm": (-35, 0, -58),
    "Bip01_L_Forearm":  (-85, 0, -10),
}
SWAY = {"Bip01_Spine1": (1.6, 0.8, 0), "Bip01_R_Forearm": (2.5, 0, 1.0), "Bip01_Neck": (1.0, 1.5, 0)}

def q_for(bone, xyz):
    B = bone.matrix_local.to_3x3()
    R = Euler([math.radians(a) for a in xyz], 'ZYX').to_matrix()
    return (B.inverted() @ R @ B).to_quaternion()

def key_pose(frame, phase):
    for name, rot in POSE.items():
        pb = arm.pose.bones[name]; pb.rotation_mode = 'QUATERNION'
        s = SWAY.get(name, (0, 0, 0))
        xyz = [rot[i] + s[i] * math.sin(phase + i) for i in range(3)]
        pb.rotation_quaternion = q_for(pb.bone, xyz)
        pb.keyframe_insert("rotation_quaternion", frame=frame)

# rest key at frame 1 start of loop, full pose; loop closes by repeating frame 1 at N
for f in range(1, N + 1, 10):
    key_pose(f, 2 * math.pi * (f - 1) / (N - 1))
key_pose(N, 2 * math.pi)
arm.animation_data.action.name = "KT_Temper"

# --- stick-figure preview from evaluated pose
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
def snap(frame):
    bpy.context.scene.frame_set(frame); bpy.context.view_layer.update()
    return {pb.name: (pb.head.copy(), pb.tail.copy()) for pb in arm.pose.bones}
fig, axs = plt.subplots(1, 2, figsize=(8, 5))
s = snap(20)
rest = {b.name: b.head_local.copy() for b in arm.data.bones}
par = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
for ax, (i, j), title in ((axs[0], (0, 1), "front (X,Y)"), (axs[1], (2, 1), "side (Z,Y)")):
    for n, p in par.items():
        if not p or "Dress" in n or "BackPack" in n: continue
        h, ph = rest[n], rest[p]
        ax.plot([h[i], ph[i]], [h[j], ph[j]], color='0.8', lw=5)
        h, ph = s[n][0], s[p][0]
        ax.plot([h[i], ph[i]], [h[j], ph[j]], 'r' if "_R_" in n else 'b' if "_L_" in n else 'k', lw=2)
    ax.set_aspect('equal'); ax.set_title(title); ax.grid(alpha=.3)
plt.savefig(os.path.join(out, "preview.png"), dpi=80)

ad = arm.animation_data
try:
    print("slot:", ad.action_slot, [sl.identifier for sl in ad.action.slots], "layers", len(ad.action.layers))
    if ad.action_slot is None and len(ad.action.slots): ad.action_slot = ad.action.slots[0]
except Exception as e: print("slot err", e)
print("KT action:", ad.action.name if ad and ad.action else None, "frames", ad.action.frame_range[:] if ad and ad.action else None)
bpy.ops.object.mode_set(mode='OBJECT')
arm.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(out, "KT_Temper.fbx"), use_selection=False,
    object_types={'ARMATURE', 'EMPTY', 'MESH'}, add_leaf_bones=False, bake_anim=True, bake_anim_use_nla_strips=False, bake_anim_use_all_actions=False, bake_anim_force_startend_keying=True, bake_anim_use_all_bones=True, bake_anim_simplify_factor=0.0, apply_scale_options='FBX_SCALE_NONE',
    axis_forward='-Z', axis_up='Y')
os._exit(0)
