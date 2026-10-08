# -*- coding: utf-8 -*-
"""Reclaimer 通用像素帧生成器（洋红底逐帧改姿势策略，源自稷下学院已验证管线）。

策略（2026-06 李白 attack/run/idle/hurt/die 全套验证通过）：
  1. 先生成一张"像素定妆锚"（角色唯一基准，低分辨率像素 STYLE + 洋红底）。
  2. 之后每一帧都拿定妆锚作参考图，prompt 只改姿势描述——帧间一致性靠"同一参考图"。
  3. 武器不举过头（不污染高度基线）；die 横躺特判。
  4. 生成后用 postprocess 逻辑归一化：洋红抠图 → 本体高统一 → 脚底对齐 96x96。

用法:
  python reclaimer_pixel_frames.py --defin <定妆提示词主题> --out <输出根目录>
  python reclaimer_pixel_frames.py --ref <已有定妆锚.png> --out <输出根目录> [--actions idle,run]
"""
import os
import sys
import json
import time
import argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from timiai_client import TimiaiClient

STYLE = ("LOW-RESOLUTION PIXEL ART sprite, tiny chibi machine character about 20 pixels tall, "
         "big visible chunky pixels, limited 16-color palette, hard edges, NO anti-aliasing, "
         "NO smooth gradients, retro 2D RPG sprite look, NOT a high-resolution illustration. "
         "Industrial-folk style: matte color blocks, bold silhouette, six-color palette "
         "(petrol blue, ochre yellow, bone white, tomato red, grey purple, rubber black), "
         "no bolts clutter, no sci-fi panels, no glow except magnetic/repair states.")

# 逐帧姿势模板（相邻帧小幅渐进；武器/工作头横向运动不举过头）
ACTION_FRAMES = {
    "idle": [
        "resting idle, arm lowered, body at neutral height",
        "resting idle, body raised very slightly (breathing in), almost identical to neutral",
        "resting idle, body at highest breathing point, shoulders barely lifted",
        "resting idle, body lowering back slightly (breathing out), almost identical to neutral",
    ],
    "run": [
        "moving right, front leg lifted forward and up, rear leg pushing back, body leaning forward",
        "moving right, front leg reaching forward at peak, rear leg extended back, mid stride",
        "moving right, front foot landing forward, rear leg coming up from back",
        "moving right, opposite leg lifted forward, arms swing opposite",
        "moving right, opposite leg reaching forward at peak, mid stride",
        "moving right, opposite foot landing forward, body forward",
    ],
    "attack": [
        "ready stance, working arm held horizontally in front at waist level pointing right, preparing to strike",
        "wind up, working arm pulled back to the right side at waist level, body coiled to the right",
        "strike start, working arm sweeping horizontally forward from right to left at chest level, body uncoiling",
        "strike mid, working arm extended horizontally straight forward, fully extended, body leaning into strike",
        "strike follow-through, arm swept across to the left side at waist level, body fully turned left",
        "recover, arm returning to horizontal ready position in front, body straightening back",
    ],
    "hurt": [
        "getting hit, upper body just starting to recoil backward, feet planted",
        "getting hit, body recoiled back near maximum, head tilted back, feet planted",
    ],
    "die": [
        "defeat, staggering, body tilting slightly back, losing balance, still standing",
        "defeat, sinking down, body leaning back, weakening, lower posture",
        "defeat, collapsing further, body low and tilted, almost down",
        "defeat, body falling onto the ground, lying mostly down horizontally",
        "defeat, fully collapsed lying flat on the ground horizontally, motionless",
    ],
}


def build_prompt(pose: str, action: str) -> str:
    height_lock = "" if action == "die" else (
        "IMPORTANT: the working arm/tool stays HORIZONTAL or low, NEVER raised above the head, "
        "the character's total height must NOT exceed the reference (tool extends sideways, not upward). ")
    return (f"{STYLE}. "
            f"the EXACT SAME character as the reference image (same design, same colors, "
            f"same head-to-body proportion, same size). "
            f"POSE: {pose}. "
            "CRITICAL: keep the character at the EXACT SAME size, framing, and proportion "
            "as the reference image, only change the pose. "
            f"{height_lock}"
            "FULL BODY head to feet, single character, centered, facing right, complete not cropped. "
            "BACKGROUND: pure solid magenta #FF00FF filling whole frame, no magenta on character, "
            "no ground, no shadow, no text.")


def normalize_frame(img_path: str, out_path: str, canvas=96, body_h=19, foot_y=57):
    """洋红抠图 → 本体高统一 → 脚底对齐。规格对齐原作 swordman 量化硬规格。"""
    import numpy as np
    from PIL import Image
    a = np.array(Image.open(img_path).convert("RGBA"))
    r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
    is_bg = (r > 120) & (b > 120) & (g < r - 40) & (g < b - 40)
    a[:, :, 3] = np.where(is_bg, 0, 255).astype(np.uint8)
    ys, xs = np.where(a[:, :, 3] > 20)
    if len(ys) == 0:
        return False
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    crop = Image.fromarray(a[y0:y1 + 1, x0:x1 + 1], "RGBA")
    cw, ch = crop.size
    is_lying = cw > ch * 1.15
    scale = body_h / max(cw, ch) if is_lying else body_h / ch
    nw, nh = max(1, round(cw * scale)), max(1, round(ch * scale))
    crop = crop.resize((nw, nh), Image.NEAREST)
    arr = np.array(crop)
    arr[:, :, 3] = np.where(arr[:, :, 3] > 110, 255, 0)
    crop = Image.fromarray(arr, "RGBA")
    cv = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    cv.paste(crop, ((canvas - nw) // 2, foot_y - nh), crop)
    cv.save(out_path)
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref", help="已有定妆锚图路径；不给则先自动生成一张")
    ap.add_argument("--defin", default="a cute small excavator machine character with whale-jaw bucket, "
                                      "petrol blue body with ochre yellow accents, chunky tracks, "
                                      "big expressive cab window", help="定妆主题描述")
    ap.add_argument("--out", default=r"D:\工作\InverseGame\WaWa\CGAME\artifacts\ai_candidates\_pixel_frames")
    ap.add_argument("--actions", default=",".join(ACTION_FRAMES))
    args = ap.parse_args()

    c = TimiaiClient()
    c.check_key()
    os.makedirs(args.out, exist_ok=True)

    ref = args.ref
    if not ref:
        ref = os.path.join(args.out, "_dingzhuang.png")
        prompt = (f"{STYLE}. Character design sheet, FULL BODY, single character, centered, "
                  f"facing right, standing neutral pose. SUBJECT: {args.defin}. "
                  "BACKGROUND: pure solid magenta #FF00FF filling whole frame, no magenta on character, "
                  "no ground, no shadow, no text.")
        c.gen_image_nano(prompt, ref, aspect_ratio="1:1", image_size="1K")
        print(f"[OK] 定妆锚: {ref}")

    for act in [a for a in args.actions.split(",") if a in ACTION_FRAMES]:
        outdir = os.path.join(args.out, act)
        pxdir = os.path.join(args.out, "_px_frames", act)
        os.makedirs(outdir, exist_ok=True)
        os.makedirs(pxdir, exist_ok=True)
        print(f"=== {act}: {len(ACTION_FRAMES[act])}帧 ===")
        for fi, pose in enumerate(ACTION_FRAMES[act]):
            raw = os.path.join(outdir, f"{act}_{fi:02d}.png")
            for attempt in range(2):
                try:
                    c.gen_image_nano(build_prompt(pose, act), raw, ref_paths=[ref],
                                     aspect_ratio="1:1", image_size="1K")
                    normalize_frame(raw, os.path.join(pxdir, f"{act}_{fi:02d}.png"))
                    print(f"  [OK] {act}_{fi:02d}")
                    break
                except Exception as e:
                    print(f"  [FAIL] {act}_{fi:02d} (try{attempt}): {e}")
                    time.sleep(2)
            time.sleep(0.8)
    print(f"done. 产出: {args.out}/_px_frames/")


if __name__ == "__main__":
    main()
