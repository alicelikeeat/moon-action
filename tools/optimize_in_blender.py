# Moon Action — 在 Blender 界面里直接优化"当前打开的模型"
# 用法：Blender 顶部切到「Scripting / 脚本」→ 新建 → 粘贴本脚本 → 点 ▶ 运行
# 结果写在左侧文本编辑器的「MA_报告」里，并导出 GLB 到下面的 OUT_PATH。

import bpy, os

TARGET_TRIS = 60000      # 目标三角面数（手游角色建议 3万~8万）
MAX_TEX = 2048           # 贴图最大边长
OUT_PATH = os.path.join(os.path.expanduser("~"), "Desktop", "moon_model.glb")   # 导出位置（默认桌面）

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
LABEL = {"spine": "脊柱", "head": "头", "shoulderL": "左上臂", "elbowL": "左前臂", "shoulderR": "右上臂",
         "elbowR": "右前臂", "hipL": "左大腿", "kneeL": "左小腿", "hipR": "右大腿", "kneeR": "右小腿"}

lines = []
def log(s):
    print(s)
    lines.append(s)

def norm(n):
    for sep in (":", "|"):
        if sep in n:
            n = n.rsplit(sep, 1)[1]
    n = n.lower().replace("mixamorig", "")
    return "".join(c for c in n if c.isalnum())

def meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]

def tris(objs):
    t = 0
    for o in objs:
        o.data.calc_loop_triangles()
        t += len(o.data.loop_triangles)
    return t

def inspect(title):
    ms = meshes()
    bones = [b.name for o in bpy.context.scene.objects if o.type == "ARMATURE" for b in o.data.bones]
    nb = {norm(b) for b in bones}
    mapped = [k for k, c in NAMES.items() if any(x in nb for x in c)]
    imgs = [i for i in bpy.data.images if i.size[0] > 0]
    mb = sum(i.size[0] * i.size[1] * 4 for i in imgs) / 1048576
    log(f"【{title}】三角面 {tris(ms):,} · 网格 {len(ms)} · 贴图 {len(imgs)} 张（解码后约 {mb:.0f} MB）· 骨骼 {len(bones)} 根")
    for i in sorted(imgs, key=lambda i: -i.size[0] * i.size[1])[:8]:
        log(f"   贴图 {i.name}: {i.size[0]}x{i.size[1]}")
    log(f"   游戏可识别关节 {len(mapped)}/10" + ("" if len(mapped) == 10 else "，缺少：" + "、".join(LABEL[k] for k in NAMES if k not in mapped)))
    sk = [o.name for o in ms if o.data.shape_keys]
    if sk:
        log(f"   含表情形变(shape keys)的网格（无法减面，将跳过）：{', '.join(sk)}")

if bpy.context.object and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")

inspect("处理前")

# 1) 减面（放在骨架修改器之前，保留蒙皮权重）
ms = meshes()
total = tris(ms)
if total > TARGET_TRIS:
    ratio = max(0.01, TARGET_TRIS / total)
    for o in ms:
        if o.data.shape_keys:
            continue
        m = o.modifiers.new("MA_Decimate", "DECIMATE")
        m.decimate_type = "COLLAPSE"
        m.ratio = ratio
        m.use_collapse_triangulate = True
        with bpy.context.temp_override(object=o, active_object=o, selected_objects=[o], selected_editable_objects=[o]):
            bpy.ops.object.modifier_move_to_index(modifier=m.name, index=0)
            bpy.ops.object.modifier_apply(modifier=m.name)
    log(f"减面：比例 {ratio:.3f}")
else:
    log("减面：已低于目标，跳过")

# 2) 缩小贴图
for i in bpy.data.images:
    w, h = i.size
    if w and max(w, h) > MAX_TEX:
        k = MAX_TEX / max(w, h)
        i.scale(max(1, int(w * k)), max(1, int(h * k)))
        try:
            i.pack()
        except RuntimeError:
            pass
        log(f"贴图缩小：{i.name} {w}x{h} → {i.size[0]}x{i.size[1]}")

# 3) 导出不压缩的 GLB（Moon Action 可直接导入）
bpy.ops.export_scene.gltf(filepath=OUT_PATH, export_format="GLB", export_draco_mesh_compression_enable=False,
                          export_skins=True, export_animations=True, export_yup=True, export_apply=False)
log(f"已导出：{OUT_PATH}（{os.path.getsize(OUT_PATH) / 1048576:.1f} MB）")
inspect("处理后")

t = bpy.data.texts.get("MA_报告") or bpy.data.texts.new("MA_报告")
t.clear()
t.write("\n".join(lines))
log("完成。报告在左侧文本编辑器「MA_报告」里。")
