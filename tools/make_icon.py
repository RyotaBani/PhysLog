#!/usr/bin/env python3
"""PhysLog アプリアイコン生成 (1024x1024)

デザイン意図:
  - 濃紺の背景に、右肩上がりの棒グラフ + 成長ラインを重ねる
  - 「身体データが伸びていく」ことを一目で伝える
  - 小サイズでも潰れないよう要素は4つまで、線は太めに
"""
from PIL import Image, ImageDraw
import math

S = 1024
SUP = 4                      # アンチエイリアス用スーパーサンプリング倍率
W = S * SUP

# アプリのテーマカラー
NAVY_TOP = (16, 30, 58)
NAVY_BOT = (9, 17, 36)
BLUE = (0, 135, 255)
GREEN = (51, 199, 89)
WHITE = (255, 255, 255)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def rounded_bar(draw, x, y, w, h, r, fill):
    """上端だけ丸めた棒"""
    r = min(r, w // 2, h)
    draw.rectangle([x, y + r, x + w, y + h], fill=fill)
    draw.rectangle([x + r, y, x + w - r, y + r], fill=fill)
    draw.pieslice([x, y, x + 2 * r, y + 2 * r], 180, 270, fill=fill)
    draw.pieslice([x + w - 2 * r, y, x + w, y + 2 * r], 270, 360, fill=fill)


def build():
    img = Image.new("RGB", (W, W), NAVY_BOT)
    d = ImageDraw.Draw(img)

    # 背景グラデーション（縦方向）
    for i in range(W):
        d.line([(0, i), (W, i)], fill=lerp(NAVY_TOP, NAVY_BOT, i / W))

    # 斜めの光沢を薄く重ねる
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.polygon(
        [(0, W * 0.55), (W * 0.62, 0), (W, 0), (0, W)],
        fill=(255, 255, 255, 8),
    )
    img = Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")
    d = ImageDraw.Draw(img)

    # ── 棒グラフ（3本・右肩上がり）──────────────────
    bar_w = int(W * 0.115)
    gap = int(W * 0.055)
    base_y = int(W * 0.735)
    heights = [0.155, 0.255, 0.355]           # 全体幅に対する高さ比
    colors = [
        lerp(BLUE, GREEN, 0.0),
        lerp(BLUE, GREEN, 0.5),
        lerp(BLUE, GREEN, 1.0),
    ]
    total_w = bar_w * 3 + gap * 2
    start_x = (W - total_w) // 2

    for i, (hr, c) in enumerate(zip(heights, colors)):
        h = int(W * hr)
        x = start_x + i * (bar_w + gap)
        rounded_bar(d, x, base_y - h, bar_w, h, bar_w // 2, c)

    # ── 成長ライン（棒の頂点をつなぐ）─────────────
    pts = []
    for i, hr in enumerate(heights):
        x = start_x + i * (bar_w + gap) + bar_w // 2
        y = base_y - int(W * hr) - int(W * 0.075)
        pts.append((x, y))

    # 右端に伸びる矢印方向へ1点追加
    pts.append((start_x + total_w + int(W * 0.045), pts[-1][1] - int(W * 0.085)))

    d.line(pts, fill=WHITE, width=int(W * 0.026), joint="curve")

    # 頂点のドット
    dot_r = int(W * 0.028)
    for (x, y) in pts[:-1]:
        d.ellipse([x - dot_r, y - dot_r, x + dot_r, y + dot_r], fill=WHITE)

    # 終端の矢頭
    tip = pts[-1]
    prev = pts[-2]
    ang = math.atan2(tip[1] - prev[1], tip[0] - prev[0])
    L = int(W * 0.072)
    spread = math.radians(30)
    d.polygon(
        [
            tip,
            (tip[0] - L * math.cos(ang - spread), tip[1] - L * math.sin(ang - spread)),
            (tip[0] - L * math.cos(ang + spread), tip[1] - L * math.sin(ang + spread)),
        ],
        fill=WHITE,
    )

    # ── ベースライン ──────────────────────────────
    d.rounded_rectangle(
        [start_x - int(W * 0.02), base_y, start_x + total_w + int(W * 0.02),
         base_y + int(W * 0.017)],
        radius=int(W * 0.009),
        fill=(255, 255, 255, 255),
    )

    return img.resize((S, S), Image.LANCZOS)


if __name__ == "__main__":
    out = "PhysLog/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
    icon = build()
    icon.save(out, "PNG")
    # 見た目確認用に小サイズも書き出す
    icon.resize((180, 180), Image.LANCZOS).save("/tmp/icon_180.png")
    icon.resize((60, 60), Image.LANCZOS).save("/tmp/icon_60.png")
    print("saved:", out, icon.size, icon.mode)
