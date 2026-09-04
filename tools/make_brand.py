#!/usr/bin/env python3
"""PhysLog ブランド素材一式の生成

#
# 【注意】このスクリプトの出力は実行環境に依存します。
#
# フォント（macOS: ヒラギノ / Linux: Noto Sans CJK）と Pillow のバージョンが
# 違うと、同じコードでも生成結果のバイト列が変わり、git の差分になります。
#
# リポジトリに入っている画像は Linux 環境で生成したものです。
# 意図的に作り直す場合を除き、実行しないでください。
#

生成物:
  brand/icon_1024.png            App Store 用アイコン（アルファなし）
  brand/logo_horizontal.png      横組みロゴ（透過・Web/SNSプロフィール用）
  brand/logo_stacked.png         縦組みロゴ（透過）
  brand/logo_mark.png            マークのみ（透過）
  brand/sns_ogp_1200x630.png     OGP / X のリンクカード
  brand/sns_x_1200x675.png       X の投稿画像（16:9）
  brand/sns_square_1080.png      Instagram / スレッズ（正方形）
  brand/sns_story_1080x1920.png  Instagram ストーリー

デザインの考え方:
  - マークは「右肩上がりの棒グラフ」と「上向き矢印」を1つの形に統合した。
    要素を減らすことで、ホーム画面の 60px でも形が潰れない。
  - 色は左から右へ青→緑のグラデーション。「積み上がって伸びる」ことを表す。
  - 背景は濃紺。フィットネス系に多い黒よりも硬すぎず、白背景のUIとも馴染む。
"""
from PIL import Image, ImageDraw, ImageFont
import os
import math

# ---- ブランドカラー ---------------------------------------------------
BLUE   = (0, 135, 255)
TEAL   = (26, 170, 172)
GREEN  = (51, 199, 89)
NAVY_T = (18, 34, 64)
NAVY_B = (8, 15, 32)
WHITE  = (255, 255, 255)
MIST   = (176, 196, 226)

SUP = 4  # スーパーサンプリング倍率

FONT_CANDIDATES = {
    "Bold": [
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
        "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
        "/System/Library/Fonts/Hiragino Sans W6.ttc",
    ],
    "Medium": [
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc",
        "/System/Library/Fonts/ヒラギノ角ゴシック W5.ttc",
        "/System/Library/Fonts/Hiragino Sans W5.ttc",
    ],
    "Regular": [
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc",
        "/System/Library/Fonts/Hiragino Sans W3.ttc",
    ],
}
_cache = {}

def _path(weight):
    if weight in _cache:
        return _cache[weight]
    for w in (weight, "Bold", "Medium", "Regular"):
        for p in FONT_CANDIDATES.get(w, []):
            if os.path.exists(p):
                _cache[weight] = p
                return p
    raise RuntimeError(
        "日本語フォントが見つかりません。\n"
        "Linux: sudo apt install fonts-noto-cjk"
    )

def font(size, weight="Bold"):
    return ImageFont.truetype(_path(weight), size, index=0)

def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))

def gradient_v(d, box, top, bottom):
    x0, y0, x1, y1 = box
    for y in range(int(y0), int(y1)):
        t = (y - y0) / max(1, (y1 - y0))
        d.line([(x0, y), (x1, y)], fill=lerp(top, bottom, t))

def text_w(d, s, f):
    return d.textlength(s, font=f)

# =====================================================================
#  マーク（ロゴの図形部分）
# =====================================================================

def draw_mark(d, cx, cy, size):
    """右肩上がりの3本のバー。最も高いバーの先端が矢印になっている。

    size はマーク全体の一辺。cx, cy は中心。
    要素を3つに絞ることで小サイズでも判別できるようにしている。
    """
    w = size
    h = size
    # 矢頭が上に張り出すぶん、バーの下端を中心よりやや下に置くと
    # 図形全体の重心が中央に来る。
    left = cx - w / 2
    bottom = cy + h * 0.43

    bar_w = w * 0.225
    gap = w * 0.098
    heights = [h * 0.44, h * 0.63, h * 0.82]
    colors = [BLUE, TEAL, GREEN]

    # 左の2本
    for i in range(2):
        x = left + i * (bar_w + gap)
        bh = heights[i]
        d.rounded_rectangle(
            [x, bottom - bh, x + bar_w, bottom],
            radius=bar_w / 2, fill=colors[i]
        )

    # 3本目：先端を矢印にする
    x = left + 2 * (bar_w + gap)
    bh = heights[2]
    shaft_top = bottom - bh + bar_w * 1.15   # 矢頭のぶん下げる
    d.rounded_rectangle(
        [x, shaft_top, x + bar_w, bottom],
        radius=bar_w / 2, fill=GREEN
    )
    # 矢頭
    tip_y = bottom - bh - bar_w * 0.30
    half = bar_w * 0.95
    d.polygon(
        [(x + bar_w / 2, tip_y),
         (x + bar_w / 2 - half, shaft_top + bar_w * 0.15),
         (x + bar_w / 2 + half, shaft_top + bar_w * 0.15)],
        fill=GREEN
    )

def draw_mark_on(img, cx, cy, size):
    d = ImageDraw.Draw(img)
    draw_mark(d, cx, cy, size)

# =====================================================================
#  1. アプリアイコン
# =====================================================================

def build_icon(px=1024):
    W = px * SUP
    img = Image.new("RGB", (W, W), NAVY_B)
    d = ImageDraw.Draw(img)
    gradient_v(d, (0, 0, W, W), NAVY_T, NAVY_B)

    # 斜めの光沢（角度をつけて平板さを避ける）
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.polygon([(0, W * 0.58), (W * 0.68, 0), (W, 0), (0, W)],
               fill=(255, 255, 255, 10))
    img = Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")

    draw_mark_on(img, W / 2, W / 2 + W * 0.015, W * 0.52)
    return img.resize((px, px), Image.LANCZOS)

# =====================================================================
#  2. ロゴ（透過）
# =====================================================================

def build_logo_horizontal(height=400):
    """マーク + ワードマークの横組み。透過PNG。"""
    H = height * SUP
    mark = H * 0.72
    f_name = font(int(H * 0.40))
    f_sub = font(int(H * 0.15), "Medium")

    tmp = Image.new("RGBA", (10, 10))
    td = ImageDraw.Draw(tmp)
    # textlength は送り幅なので、字形の右端がはみ出ることがある。
    # 実際の外接矩形で測って余白を確保する。
    name_box = td.textbbox((0, 0), "PhysLog", font=f_name)
    sub_box = td.textbbox((0, 0), "身体データ記録", font=f_sub)
    text_block = max(name_box[2], sub_box[2])

    pad = H * 0.14
    gap = H * 0.22
    W = int(pad * 2 + mark + gap + text_block)

    img = Image.new("RGBA", (W, int(H)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    draw_mark(d, pad + mark / 2, H / 2, mark)

    tx = pad + mark + gap
    d.text((tx, H * 0.13), "PhysLog", font=f_name, fill=NAVY_T)
    d.text((tx + 2, H * 0.70), "身体データ記録", font=f_sub, fill=(110, 122, 145))

    return img.resize((int(W / SUP), height), Image.LANCZOS)

def build_logo_stacked(width=500):
    W = width * SUP
    mark = W * 0.42
    f_name = font(int(W * 0.20))
    f_sub = font(int(W * 0.072), "Medium")

    H = int(mark + W * 0.34)
    img = Image.new("RGBA", (int(W), H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    draw_mark(d, W / 2, mark / 2 + W * 0.02, mark)

    nw = text_w(d, "PhysLog", f_name)
    d.text(((W - nw) / 2, mark + W * 0.045), "PhysLog", font=f_name, fill=NAVY_T)
    sw = text_w(d, "身体データ記録", f_sub)
    d.text(((W - sw) / 2, mark + W * 0.235), "身体データ記録",
           font=f_sub, fill=(110, 122, 145))

    return img.resize((width, int(H / SUP)), Image.LANCZOS)

def build_mark_only(px=512):
    W = px * SUP
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_mark(d, W / 2, W / 2, W * 0.86)
    return img.resize((px, px), Image.LANCZOS)

# =====================================================================
#  3. SNS 画像
# =====================================================================

def sns_base(w, h):
    """濃紺グラデーション + 斜めアクセントの共通背景"""
    W, H = w * 2, h * 2
    img = Image.new("RGB", (W, H), NAVY_B)
    d = ImageDraw.Draw(img)
    gradient_v(d, (0, 0, W, H), NAVY_T, NAVY_B)

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.polygon([(0, H * 0.55), (W * 0.72, 0), (W, 0), (W, H * 0.30), (0, H)],
               fill=(0, 135, 255, 16))
    img = Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")
    return img, ImageDraw.Draw(img), W, H

def draw_headline(d, W, y, lines, size, color=WHITE, center=True, x=0, lh=1.30):
    f = font(size)
    for line in lines:
        if center:
            d.text(((W - text_w(d, line, f)) / 2, y), line, font=f, fill=color)
        else:
            d.text((x, y), line, font=f, fill=color)
        y += size * lh
    return y

def draw_centered_text(d, box, s, f, fill):
    """矩形の中央に文字を置く。

    PIL の既定の描画基準はフォントの上端であり、CJK フォントは
    仮想ボディに対して字形が小さいため、そのまま置くと上寄りに見える。
    実際の字形の外接矩形を測って中央に合わせる。
    """
    x0, y0, x1, y1 = box
    bbox = d.textbbox((0, 0), s, font=f)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text((x0 + (x1 - x0 - tw) / 2 - bbox[0],
            y0 + (y1 - y0 - th) / 2 - bbox[1]),
           s, font=f, fill=fill)

def draw_chips(d, W, y, items, size, center=True, x=0):
    """特徴を並べた小さなチップ"""
    f = font(size, "Medium")
    pad_x, pad_y, gap = size * 0.85, size * 0.52, size * 0.5
    h = size + pad_y * 2
    widths = [text_w(d, s, f) + pad_x * 2 for s in items]
    total = sum(widths) + gap * (len(items) - 1)
    cx = (W - total) / 2 if center else x
    for s, w in zip(items, widths):
        d.rounded_rectangle([cx, y, cx + w, y + h], radius=h / 2,
                            fill=(255, 255, 255, 255), outline=None)
        draw_centered_text(d, (cx, y, cx + w, y + h), s, f, NAVY_T)
        cx += w + gap
    return y + h

def build_sns(w, h, kind):
    img, d, W, H = sns_base(w, h)

    if kind == "ogp":          # 1200x630：リンクカード。ロゴ主体で読みやすく
        draw_mark(d, W / 2, H * 0.30, H * 0.30)
        y = draw_headline(d, W, H * 0.50, ["PhysLog"], int(H * 0.135))
        f = font(int(H * 0.052), "Medium")
        t = "垂直跳び・50m走・握力まで記録できる身体データアプリ"
        d.text(((W - text_w(d, t, f)) / 2, y + H * 0.02), t, font=f, fill=MIST)
        draw_chips(d, W, y + H * 0.13, ["完全無料", "登録不要", "iOS"], int(H * 0.045))

    elif kind == "x":          # 1200x675：投稿画像。差別化点を主役に
        y = draw_headline(
            d, W, H * 0.16,
            ["垂直跳び、50m走、握力。", "競技の数字を、残す。"],
            int(H * 0.105)
        )
        f = font(int(H * 0.045), "Medium")
        for i, t in enumerate([
            "一般的な筋トレアプリにはない項目まで記録",
            "睡眠とパフォーマンスの関係も自動で分析",
        ]):
            d.text(((W - text_w(d, t, f)) / 2, y + H * 0.035 + i * H * 0.065),
                   t, font=f, fill=MIST)
        draw_chips(d, W, H * 0.68, ["完全無料", "登録不要", "端末内保存"], int(H * 0.042))
        draw_mark(d, W / 2, H * 0.90, H * 0.11)

    elif kind == "square":     # 1080x1080：Instagram / Threads
        draw_mark(d, W / 2, H * 0.24, H * 0.20)
        y = draw_headline(
            d, W, H * 0.38,
            ["垂直跳び、50m走、握力。", "競技の数字を、残す。"],
            int(H * 0.075)
        )
        f = font(int(H * 0.036), "Medium")
        for i, t in enumerate([
            "スポーツ選手のための身体データアプリ",
            "睡眠とパフォーマンスの関係も分析できる",
        ]):
            d.text(((W - text_w(d, t, f)) / 2, y + H * 0.03 + i * H * 0.055),
                   t, font=f, fill=MIST)
        draw_chips(d, W, H * 0.755, ["完全無料", "登録不要"], int(H * 0.036))
        f2 = font(int(H * 0.034))
        n = "PhysLog"
        d.text(((W - text_w(d, n, f2)) / 2, H * 0.885), n, font=f2, fill=WHITE)

    else:                      # story 1080x1920
        draw_mark(d, W / 2, H * 0.20, H * 0.12)
        # 見出しが4行あるため、後続要素は draw_headline の戻り値を基準に置く。
        # 固定座標にすると行数を変えたときに重なる。
        y = draw_headline(
            d, W, H * 0.32,
            ["垂直跳び、", "50m走、握力。", "競技の数字を、", "残す。"],
            int(H * 0.050)
        )
        f = font(int(H * 0.023), "Medium")
        t = "スポーツ選手のための身体データアプリ"
        d.text(((W - text_w(d, t, f)) / 2, y + H * 0.025), t, font=f, fill=MIST)
        y = draw_chips(d, W, y + H * 0.085, ["完全無料", "登録不要"], int(H * 0.023))
        f2 = font(int(H * 0.026))
        n = "PhysLog"
        d.text(((W - text_w(d, n, f2)) / 2, H * 0.82), n, font=f2, fill=WHITE)

    return img.resize((w, h), Image.LANCZOS)


# =====================================================================
#  4. アプリ画面入りの SNS 画像
# =====================================================================

def _load_screens():
    """make_screenshots.py の画面描画をそのまま借りる。

    同じコードから生成することで、App Store 用スクリーンショットと
    SNS 画像で見た目がずれないようにしている。
    """
    import importlib.util
    here = os.path.dirname(os.path.abspath(__file__))
    spec = importlib.util.spec_from_file_location(
        "make_screenshots", os.path.join(here, "make_screenshots.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

def paste_phone(img, screen, cx, top, height, cut_bottom=False):
    """端末フレームに画面をはめ込んで貼る。

    cut_bottom=True のとき下端を画像の外へ逃がし、
    「画面が続いている」印象にする。
    """
    ratio = 1080 / 2340
    h = int(height)
    w = int(h * ratio)
    frame_r = int(w * 0.092)
    bezel = max(2, int(w * 0.014))

    card = Image.new("RGBA", (w + bezel * 2, h + bezel * 2), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle([0, 0, w + bezel * 2, h + bezel * 2],
                         radius=frame_r + bezel, fill=(24, 28, 38, 255))

    inner = screen.resize((w, h), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w, h], radius=frame_r, fill=255)
    card.paste(inner, (bezel, bezel), mask)

    # 端末のごく薄い縁取り
    cd.rounded_rectangle([0, 0, w + bezel * 2 - 1, h + bezel * 2 - 1],
                         radius=frame_r + bezel, outline=(70, 80, 100, 160), width=bezel)

    img.alpha_composite(card, (int(cx - card.width / 2), int(top)))
    return card.width, card.height

def build_sns_with_app(w, h, kind):
    img, d, W, H = sns_base(w, h)
    img = img.convert("RGBA")
    d = ImageDraw.Draw(img)
    ms = _load_screens()

    if kind == "x_app":        # 1200x675：左に文言、右に画面
        left_x = W * 0.065
        f_h = font(int(H * 0.088))
        y = H * 0.17
        for line in ["垂直跳び、50m走、握力。", "競技の数字を、残す。"]:
            d.text((left_x, y), line, font=f_h, fill=WHITE)
            y += H * 0.115
        f_s = font(int(H * 0.040), "Medium")
        for i, t in enumerate([
            "一般的な筋トレアプリにはない項目まで記録",
            "睡眠とパフォーマンスの関係も自動で分析",
        ]):
            d.text((left_x, y + H * 0.03 + i * H * 0.058), t, font=f_s, fill=MIST)
        draw_chips(d, W, y + H * 0.19, ["完全無料", "登録不要"],
                   int(H * 0.038), center=False, x=left_x)
        draw_mark(d, left_x + H * 0.055, H * 0.885, H * 0.11)

        paste_phone(img, ms.screen_ability(), W * 0.775, H * 0.10, H * 0.86)

    elif kind == "square_app": # 1080x1080：上に文言、下に画面を見切れさせる
        y = draw_headline(d, W, H * 0.075,
                          ["垂直跳び、50m走、握力。", "競技の数字を、残す。"],
                          int(H * 0.062))
        f_s = font(int(H * 0.032), "Medium")
        t = "スポーツ選手のための身体データアプリ"
        d.text(((W - text_w(d, t, f_s)) / 2, y + H * 0.022), t, font=f_s, fill=MIST)
        draw_chips(d, W, y + H * 0.075, ["完全無料", "登録不要"], int(H * 0.030))
        paste_phone(img, ms.screen_ability(), W / 2, H * 0.40, H * 0.78)

    else:                      # story 1080x1920
        y = draw_headline(d, W, H * 0.075,
                          ["垂直跳び、50m走、握力。", "競技の数字を、残す。"],
                          int(H * 0.036))
        f_s = font(int(H * 0.019), "Medium")
        t = "スポーツ選手のための身体データアプリ"
        d.text(((W - text_w(d, t, f_s)) / 2, y + H * 0.014), t, font=f_s, fill=MIST)
        draw_chips(d, W, y + H * 0.045, ["完全無料", "登録不要"], int(H * 0.018))
        paste_phone(img, ms.screen_insight(), W / 2, H * 0.245, H * 0.60)
        f2 = font(int(H * 0.026))
        n = "PhysLog"
        d.text(((W - text_w(d, n, f2)) / 2, H * 0.885), n, font=f2, fill=WHITE)

    return img.convert("RGB").resize((w, h), Image.LANCZOS)

# =====================================================================

if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "brand")
    os.makedirs(out, exist_ok=True)

    icon = build_icon(1024)
    icon.save(os.path.join(out, "icon_1024.png"), "PNG")
    # アプリ本体のアイコンも同じものに揃える
    icon.save(os.path.join(
        root, "PhysLog/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"), "PNG")

    build_logo_horizontal(400).save(os.path.join(out, "logo_horizontal.png"), "PNG")
    build_logo_stacked(500).save(os.path.join(out, "logo_stacked.png"), "PNG")
    build_mark_only(512).save(os.path.join(out, "logo_mark.png"), "PNG")

    for name, (w, h, kind) in {
        "sns_ogp_1200x630":    (1200, 630, "ogp"),
        "sns_x_1200x675":      (1200, 675, "x"),
        "sns_square_1080":     (1080, 1080, "square"),
        "sns_story_1080x1920": (1080, 1920, "story"),
    }.items():
        build_sns(w, h, kind).save(os.path.join(out, f"{name}.png"), "PNG")

    # アプリ画面入り（実際の画面を見せたいとき用）
    for name, (w, h, kind) in {
        "app_x_1200x675":      (1200, 675, "x_app"),
        "app_square_1080":     (1080, 1080, "square_app"),
        "app_story_1080x1920": (1080, 1920, "story_app"),
    }.items():
        build_sns_with_app(w, h, kind).save(os.path.join(out, f"{name}.png"), "PNG")

    for f in sorted(os.listdir(out)):
        if not f.endswith(".png"):
            continue
        p = os.path.join(out, f)
        print(f"  {f:28s} {Image.open(p).size}")
