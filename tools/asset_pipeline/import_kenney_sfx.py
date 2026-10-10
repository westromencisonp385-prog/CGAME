"""把 Kenney CC0 音效导入为游戏事件音（可重复执行）。

来源：Kenney (www.kenney.nl) 音频包，CC0 1.0 公有领域，可商用、无需署名。
  impact-sounds / interface-sounds / sci-fi-sounds / rpg-audio / digital-audio / music-jingles
  下载：https://kenney.nl/media/pages/assets/<pack>/<hash>/kenney_<pack>.zip（见 PACKS）

处理：每个事件挑 1~5 个变体 → 切掉开头静音 → 限制最长时长并淡出 → 响度对齐到
原合成音（assets/generated/audio/<event>.wav）的 RMS，使各调用点的 volume_db 不用重调
→ 峰值限到 -1 dBFS → OGG 写入 game/assets/audio/sfx/，并生成 sfx_manifest.json。

用法：python tools/asset_pipeline/import_kenney_sfx.py [--download]
"""
import io, json, os, subprocess, sys, zipfile, urllib.request
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
GAME = os.path.join(REPO, "game")
OUT = os.path.join(GAME, "assets", "audio", "sfx")
SYNTH = os.path.join(GAME, "assets", "generated", "audio")
CACHE = os.path.join(os.environ.get("TEMP", "/tmp"), "kenney_audio")
SR = 44100

PACKS = {
    "impact-sounds": "87b4ddecda-1677589768",
    "interface-sounds": "fa43c1dd4d-1677589452",
    "sci-fi-sounds": "6b296f9ecf-1677589334",
    "rpg-audio": "8e99002d76-1677590336",
    "digital-audio": "216eac4753-1677590265",
    "music-jingles": "f37e530b9e-1677590399",
}

I, U, S, R, D, J = "impact-sounds/Audio/", "interface-sounds/Audio/", "sci-fi-sounds/Audio/", "rpg-audio/Audio/", "digital-audio/Audio/", "music-jingles/Audio/"
def n5(prefix, ids=range(5)):
    return [f"{prefix}_{i:03d}.ogg" for i in ids]

# event -> (源文件, 最长秒数, 相对原合成音的增益 dB)
MAP = {
    # ---- 战斗：挖斗 / 投掷
    "bite":          (n5(I + "impactMining"), 0.45, -2.0),       # 挖斗出手：铲子凿石
    "bite_hit":      (n5(I + "impactPunch_medium"), 0.35, 0.0),  # 咬中
    "bite_heavy":    (n5(I + "impactPunch_heavy"), 0.5, 1.0),    # 连击收尾
    "throw_launch":  ([R + "knifeSlice.ogg", R + "knifeSlice2.ogg"], 0.35, -2.0),
    "throw_hit":     (n5(I + "impactWood_heavy"), 0.35, 1.0),    # 木货箱砸地
    "throw":         (n5(I + "impactWood_medium"), 0.4, 0.0),
    "pack":          (n5(I + "impactPlate_medium"), 0.45, 0.0),
    "absorb":        (n5(I + "impactSoft_heavy"), 0.45, 0.0),
    "repair":        (n5(I + "impactMetal_light"), 0.4, 0.0),
    # ---- 战斗：模块自动攻击（频繁，短）
    "auto_shot":     (n5(I + "impactGeneric_light"), 0.22, 0.0),
    "auto_boom":     ([S + "explosionCrunch_000.ogg", S + "explosionCrunch_002.ogg"], 0.6, 0.0),
    "auto_zap":      ([D + "zap1.ogg", D + "zap2.ogg"], 0.28, -1.0),
    "ability_cast":  (n5(S + "forceField"), 0.6, 0.0),
    # ---- Boss
    "boss_spawn":    ([S + "lowFrequency_explosion_000.ogg"], 1.8, 1.0),
    "boss_phase":    ([S + "explosionCrunch_000.ogg", S + "explosionCrunch_003.ogg"], 1.2, 0.0),
    "boss_defeat":   ([S + "lowFrequency_explosion_001.ogg"], 1.0, 1.0),
    # ---- 成长 / 奖励
    "xp_tick":       ([U + "glass_002.ogg", U + "glass_003.ogg", U + "glass_005.ogg", U + "glass_006.ogg"], 0.15, 0.0),
    "silver_gain":   ([R + "handleCoins2.ogg"] + n5(I + "impactGlass_light", range(3)), 0.4, 0.0),
    "power_up":      ([D + "powerUp6.ogg", D + "powerUp7.ogg", D + "powerUp11.ogg"], 0.7, 0.0),
    "level_up":      ([J + "8-Bit jingles/jingles_NES13.ogg"], 1.2, 0.0),
    "tier_up":       ([J + "Hit jingles/jingles_HIT11.ogg"], 1.1, 0.0),
    "quest_complete":([U + "confirmation_001.ogg", U + "confirmation_004.ogg"], 0.5, 0.0),
    "victory":       ([J + "8-Bit jingles/jingles_NES00.ogg"], 2.0, 0.0),
    "defeat":        ([J + "Steel jingles/jingles_STEEL01.ogg"], 1.6, 0.0),
    "module_install":([R + "metalLatch.ogg", I + "impactMetal_medium_000.ogg", I + "impactMetal_medium_003.ogg"], 0.4, 0.0),
    # ---- 界面
    "card_pick":     ([U + "confirmation_002.ogg", U + "confirmation_003.ogg"], 0.5, 0.0),
    "ui_open":       ([U + "open_002.ogg", U + "open_003.ogg"], 0.35, 0.0),
    "ui_pick":       ([U + "select_003.ogg", U + "select_004.ogg", U + "select_005.ogg"], 0.25, 0.0),
    "reroll":        ([U + "scratch_001.ogg", U + "scratch_002.ogg"], 0.2, 0.0),
    "change":        ([U + "switch_001.ogg", U + "switch_002.ogg"], 0.3, 0.0),
    "deny":          ([U + "error_004.ogg", U + "error_007.ogg", U + "error_001.ogg"], 0.25, 0.0),
    "work_loop":     ([U + "click_001.ogg", U + "click_003.ogg", U + "click_005.ogg"], 0.12, -3.0),
}


def download():
    os.makedirs(CACHE, exist_ok=True)
    for pack, h in PACKS.items():
        dest = os.path.join(CACHE, pack)
        if os.path.isdir(dest):
            continue
        url = f"https://kenney.nl/media/pages/assets/{pack}/{h}/kenney_{pack}.zip"
        print("download", url)
        data = urllib.request.urlopen(url, timeout=120).read()
        zipfile.ZipFile(io.BytesIO(data)).extractall(dest)


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def body_rms_db(x):
    peak = float(np.max(np.abs(x))) + 1e-9
    nz = np.nonzero(np.abs(x) > peak * 0.05)[0]
    b = x[nz[0]: nz[-1] + 1] if nz.size else x
    return 20 * np.log10(float(np.sqrt(np.mean(b ** 2))) + 1e-9)


def process(src, max_len):
    x = decode(src)
    peak = float(np.max(np.abs(x))) + 1e-9
    nz = np.nonzero(np.abs(x) > peak * 0.03)[0]
    start = max(0, nz[0] - int(0.004 * SR)) if nz.size else 0   # 留 4ms 起音
    x = x[start:]
    n = min(x.size, int(max_len * SR))
    x = x[:n]
    fade = min(int(0.04 * SR), n // 3)
    if fade > 0 and n >= int(max_len * SR) - 1:
        x[-fade:] *= np.linspace(1.0, 0.0, fade, dtype=np.float32)
    x[: min(64, n)] *= np.linspace(0.0, 1.0, min(64, n), dtype=np.float32)
    return x


def encode(x, dest):
    p = subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                        "-c:a", "libvorbis", "-q:a", "6", dest], input=x.astype(np.float32).tobytes())
    if p.returncode != 0:
        raise RuntimeError("ffmpeg encode failed: " + dest)


def main():
    if "--download" in sys.argv or not os.path.isdir(CACHE):
        download()
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".ogg") or f.endswith(".ogg.import"):
            os.remove(os.path.join(OUT, f))
    manifest = {}
    report = []
    for event, (files, max_len, gain_db) in MAP.items():
        ref_path = os.path.join(SYNTH, event + ".wav")
        target = body_rms_db(decode(ref_path)) if os.path.exists(ref_path) else -16.0
        target = float(np.clip(target, -24.0, -10.0)) + gain_db
        paths = []
        for i, rel in enumerate(files):
            src = os.path.join(CACHE, rel)
            if not os.path.exists(src):
                raise FileNotFoundError(src)
            x = process(src, max_len)
            x *= 10 ** ((target - body_rms_db(x)) / 20.0)
            pk = float(np.max(np.abs(x))) + 1e-9
            lim = 10 ** (-1.0 / 20.0)
            if pk > lim:
                x *= lim / pk
            name = f"{event}_{i}.ogg"
            encode(x, os.path.join(OUT, name))
            paths.append("res://assets/audio/sfx/" + name)
            report.append(f"{name:22s} {x.size / SR:5.2f}s rms={body_rms_db(x):6.1f}dB  <- {rel}")
        manifest[event] = paths
    with open(os.path.join(OUT, "sfx_manifest.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump({"source": "Kenney (www.kenney.nl) audio packs, CC0 1.0", "events": manifest}, fh, ensure_ascii=False, indent=1)
    with open(os.path.join(OUT, "LICENSE_Kenney.txt"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("Sound effects in this folder are derived from Kenney audio packs\n"
                 "(Impact Sounds, Interface Sounds, Sci-fi Sounds, RPG Audio, Digital Audio, Music Jingles)\n"
                 "Created/distributed by Kenney (www.kenney.nl)\n"
                 "License: Creative Commons Zero, CC0 1.0 — http://creativecommons.org/publicdomain/zero/1.0/\n"
                 "Free to use in personal, educational and commercial projects. Credit is appreciated, not required.\n"
                 "Processing: trimmed, faded, loudness-matched, re-encoded to Ogg Vorbis by tools/asset_pipeline/import_kenney_sfx.py\n")
    print("\n".join(report))
    print(f"events={len(manifest)} files={sum(len(v) for v in manifest.values())}")


if __name__ == "__main__":
    main()
