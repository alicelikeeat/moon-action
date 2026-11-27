"""
Moon Action — GLB optimizer for Blender (run headless, no UI needed).

Usage (Blender 4.2+ / 5.x):
  blender -b -P tools/optimize_glb.py -- --in big.glb --out kai.glb \
      [--target-tris 60000] [--max-tex 2048] [--report report.json] [--preview previews/]

What it does
  1. Inspect: triangles, meshes, shape keys, textures (sizes), armatures, bone names,
     and how many of the game's 10 retarget joints the skeleton maps to.
  2. Decimate meshes proportionally to reach --target-tris (keeps vertex groups /
     skin weights; the Decimate modifier is placed before the Armature modifier).
     Meshes with shape keys are skipped (Blender cannot apply modifiers on them).
  3. Downscale textures larger than --max-tex (aspect ratio kept).
  4. Export an UNCOMPRESSED .glb (no Draco / no KTX2) that Moon Action can load.
  5. Optional before/after preview renders (Workbench) and a JSON report.
"""
import argparse
import json
import math
import os
import sys
import time

import bpy
from mathutils import Vector

# --- same joint name table as MoonAction/Render/ModelImport.swift (Retargeter) ---
NAMES = {
    "spine": ["spine1", "spine01", "spine2", "chest", "spine", "upperchest", "ccbasespine01"],
    "head": ["head", "ccbasehead"],
    "shoulderL": ["leftarm", "leftupperarm", "upperarml", "upperarmleft", "luparm", "lupperarm", "ccbaselupperarm", "arml"],
    "elbowL": ["leftforearm", "leftlowerarm", "forearml", "lowerarml", "lforearm", "ccbaselforearm"],
    "shoulderR": ["rightarm", "rightupperarm", "upperarmr", "upperarmright", "ruparm", "rupperarm", "ccbaserupperarm", "armr"],
    "elbowR": ["rightforearm", "rightlowerarm", "forearmr", "lowerarmr", "rforearm", "ccbaserforearm"],
    "hipL": ["leftupleg", "leftupperleg", "thighl", "upperlegl", "lthigh", "leftthigh", "ccbaselthigh"],
    "kneeL": ["leftleg", "leftlowerleg", "calfl", "lowerlegl", "shinl", "lcalf", "leftshin", "ccbaselcalf"],
    "hipR": ["rightupleg", "rightupperleg", "thighr", "upperlegr", "rthigh", "rightthigh", "ccbaserthigh"],
    "kneeR": ["rightleg", "rightlowerleg", "calfr", "lowerlegr", "shinr", "rcalf", "rightshin", "ccbasercalf"],
}


def normalize(name):
    n = name
    for sep in (":", "|"):
        if sep in n:
            n = n.rsplit(sep, 1)[1]
    n = n.lower().replace("mixamorig", "")
    return "".join(ch for ch in n if ch.isalnum())


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="inp", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--target-tris", type=int, default=60000)
    p.add_argument("--max-tex", type=int, default=2048)
    p.add_argument("--report", default=None)
    p.add_argument("--preview", default=None, help="folder for before.png / after.png")
    return p.parse_args(argv)


def mesh_objects():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def tri_count(objs):
    total = 0
    for o in objs:
        me = o.data
        me.calc_loop_triangles()
        total += len(me.loop_triangles)
    return total


def inspect(label):
    meshes = mesh_objects()
    bones = []
    for o in bpy.context.scene.objects:
        if o.type == "ARMATURE":
            bones += [b.name for b in o.data.bones]
    norm = {normalize(b) for b in bones}
    mapped = [k for k, cands in NAMES.items() if any(c in norm for c in cands)]
    images = []
    for img in bpy.data.images:
        if img.size[0] > 0:
            images.append({"name": img.name, "w": img.size[0], "h": img.size[1]})
    info = {
        "stage": label,
        "meshes": len(meshes),
        "triangles": tri_count(meshes),
        "shape_key_meshes": [o.name for o in meshes if o.data.shape_keys],
        "armatures": sum(1 for o in bpy.context.scene.objects if o.type == "ARMATURE"),
        "bones": len(bones),
        "retarget_mapped": f"{len(mapped)}/10",
        "retarget_missing": [k for k in NAMES if k not in mapped],
        "textures": images,
        "decoded_texture_mb": round(sum(i["w"] * i["h"] * 4 for i in images) / 1048576, 1),
    }
    print(f"[{label}] tris={info['triangles']:,} meshes={info['meshes']} textures={len(images)} "
          f"(~{info['decoded_texture_mb']} MB decoded) bones={info['bones']} retarget={info['retarget_mapped']}")
    return info


def with_object(obj, fn):
    with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj], selected_editable_objects=[obj]):
        return fn()


def decimate(target):
    meshes = [o for o in mesh_objects()]
    total = tri_count(meshes)
    if total <= target:
        print(f"[decimate] {total:,} tris already <= target {target:,}, skipped")
        return []
    ratio = max(0.01, target / total)
    skipped = []
    for o in meshes:
        if o.data.shape_keys:
            skipped.append(o.name)
            print(f"[decimate] skip {o.name}: has shape keys")
            continue
        mod = o.modifiers.new(name="MA_Decimate", type="DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        # Decimate must run on the rest mesh, before the Armature deform.
        with_object(o, lambda: bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0))
        with_object(o, lambda: bpy.ops.object.modifier_apply(modifier="MA_Decimate"))
    print(f"[decimate] ratio {ratio:.3f}")
    return skipped


def downscale_textures(max_tex):
    changed = []
    for img in bpy.data.images:
        w, h = img.size
        if w == 0 or max(w, h) <= max_tex:
            continue
        k = max_tex / max(w, h)
        nw, nh = max(1, int(w * k)), max(1, int(h * k))
        img.scale(nw, nh)
        if img.packed_file is not None or img.source == "FILE":
            try:
                img.pack()
            except RuntimeError:
                pass
        changed.append(f"{img.name}: {w}x{h} -> {nw}x{nh}")
        print(f"[texture] {changed[-1]}")
    return changed


def render_preview(path):
    scene = bpy.context.scene
    objs = mesh_objects()
    if not objs:
        return
    lo = Vector((math.inf,) * 3)
    hi = Vector((-math.inf,) * 3)
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    center = (lo + hi) / 2
    height = max(hi.z - lo.z, hi.y - lo.y, 0.01)
    cam_data = bpy.data.cameras.new("MA_Cam")
    cam = bpy.data.objects.new("MA_Cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = center + Vector((height * 0.6, -height * 2.2, height * 0.15))
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x, scene.render.resolution_y = 720, 1080
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)
    print(f"[preview] {path}")


def main():
    a = parse_args()
    t0 = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.inp)
    report = {"input": a.inp, "input_mb": round(os.path.getsize(a.inp) / 1048576, 1)}
    report["before"] = inspect("before")
    if a.preview:
        os.makedirs(a.preview, exist_ok=True)
        render_preview(os.path.join(a.preview, "before.png"))

    report["shape_key_meshes_skipped"] = decimate(a.target_tris)
    report["textures_resized"] = downscale_textures(a.max_tex)

    bpy.ops.export_scene.gltf(
        filepath=a.out,
        export_format="GLB",
        export_draco_mesh_compression_enable=False,
        export_skins=True,
        export_animations=True,
        export_yup=True,
        export_apply=False,
    )
    report["output"] = a.out
    report["output_mb"] = round(os.path.getsize(a.out) / 1048576, 1)

    # Re-import the result to verify what the game will actually get.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.out)
    report["after"] = inspect("after")
    if a.preview:
        render_preview(os.path.join(a.preview, "after.png"))
    report["seconds"] = round(time.time() - t0, 1)

    print(f"[done] {report['input_mb']} MB -> {report['output_mb']} MB, "
          f"{report['before']['triangles']:,} -> {report['after']['triangles']:,} tris, "
          f"retarget {report['after']['retarget_mapped']}, {report['seconds']} s")
    if a.report:
        with open(a.report, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
