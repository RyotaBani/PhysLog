#!/usr/bin/env python3
"""App Store 用スクリーンショット生成 (1320 x 2868 / 6.9インチ)

構成の意図:
  - 上部に大きなキャッチコピー。ストアの一覧では縮小表示されるため、
    小さくなっても読める太さと文字サイズにする
  - 中央に端末フレーム入りのアプリ画面
  - 背景はアプリのテーマカラー（濃紺〜青）のグラデーション
  - 1枚目で「何のアプリか」が完結するようにする
"""
#
# 【注意】このスクリプトの出力は実行環境に依存します。
#
# フォント（macOS: ヒラギノ / Linux: Noto Sans CJK）と Pillow のバージョンが
# 違うと、同じコードでも生成結果のバイト列が変わり、git の差分になります。
#
# リポジトリに入っている画像は Linux 環境で生成したものです。
# 意図的に作り直す場合を除き、実行しないでください。
# 実行する場合は生成環境を固定し、結果を必ず目視で確認してから差し替えてください。
#

from PIL import Image, ImageDraw, ImageFont
import os

W, H = 1320, 2868
SUP = 2                      # スーパーサンプリング

# ---- アプリのテーマカラー -------------------------------------------
BLUE   = (0, 135, 255)
GREEN  = (51, 199, 89)
ORANGE = (255, 148, 0)
PINK   = (255, 46, 84)
PURPLE = (143, 89, 247)
NAVY_T = (16, 32, 62)
NAVY_B = (7, 14, 30)

INK    = (17, 23, 38)
INK2   = (90, 99, 119)
INK3   = (152, 160, 176)
CARD   = (255, 255, 255)
BG     = (242, 243, 247)
LINE   = (228, 230, 237)

# 日本語フォントの候補。環境によって入っているものが違うため順に試す。
# macOS はヒラギノ、Linux は Noto Sans CJK を想定している。
FONT_CANDIDATES = {
    "Bold": [
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
        "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
        "/System/Library/Fonts/Hiragino Sans W6.ttc",
        "/Library/Fonts/NotoSansCJKjp-Bold.otf",
    ],
    "Medium": [
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc",
        "/System/Library/Fonts/ヒラギノ角ゴシック W5.ttc",
        "/System/Library/Fonts/Hiragino Sans W5.ttc",
        "/Library/Fonts/NotoSansCJKjp-Medium.otf",
    ],
    "Regular": [
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc",
        "/System/Library/Fonts/Hiragino Sans W3.ttc",
        "/Library/Fonts/NotoSansCJKjp-Regular.otf",
    ],
}

_font_path_cache = {}

def _resolve_font_path(weight):
    """使えるフォントを1つ選ぶ。見つからなければ分かりやすいエラーにする。"""
    if weight in _font_path_cache:
        return _font_path_cache[weight]

    for path in FONT_CANDIDATES.get(weight, []):
        if os.path.exists(path):
            _font_path_cache[weight] = path
            return path

    # 指定ウェイトが無ければ他のウェイトで代用する
    for alt in ("Bold", "Medium", "Regular"):
        for path in FONT_CANDIDATES[alt]:
            if os.path.exists(path):
                _font_path_cache[weight] = path
                return path

    raise RuntimeError(
        "日本語フォントが見つかりませんでした。\n"
        "macOS なら通常はヒラギノが標準で入っています。\n"
        "Linux の場合は次でインストールしてください:\n"
        "  sudo apt install fonts-noto-cjk"
    )

def font(size, weight="Bold"):
    """日本語フォントを返す。ttc の index=0 が日本語。"""
    return ImageFont.truetype(_resolve_font_path(weight), size, index=0)

def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))

def gradient(draw, box, top, bottom):
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        t = (y - y0) / max(1, (y1 - y0))
        draw.line([(x0, y), (x1, y)], fill=lerp(top, bottom, t))

def rrect(draw, box, r, fill, outline=None, width=2):
    draw.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)

def text_center(draw, cx, y, s, f, fill):
    w = draw.textlength(s, font=f)
    draw.text((cx - w / 2, y), s, font=f, fill=fill)
    return w

# =====================================================================
#  アプリ画面の描画（端末の中身）
# =====================================================================

SW, SH = 1080, 2340          # 画面部分の解像度（スーパーサンプリング前提）

def screen_base(title):
    """ステータスバー + ナビゲーションタイトルまでを描いた土台を返す"""
    img = Image.new("RGB", (SW, SH), BG)
    d = ImageDraw.Draw(img)

    # ステータスバー
    d.text((78, 62), "9:41", font=font(44), fill=INK)
    # Dynamic Island
    d.rounded_rectangle([SW/2 - 132, 44, SW/2 + 132, 128], radius=42, fill=(0, 0, 0))
    # 電波・Wi-Fi・電池（簡略）
    for i, h in enumerate([14, 20, 26, 32]):
        d.rounded_rectangle([SW-268+i*20, 92-h, SW-256+i*20, 92], radius=3, fill=INK)
    d.rounded_rectangle([SW-150, 62, SW-78, 96], radius=10, outline=INK, width=4)
    d.rounded_rectangle([SW-146, 66, SW-96, 92], radius=7, fill=INK)

    # ナビゲーションタイトル
    text_center(d, SW/2, 150, title, font(46), INK)
    return img, d

def tab_bar(d, active):
    """下部タブバー"""
    y = SH - 190
    d.rectangle([0, y, SW, SH], fill=(252, 252, 253))
    d.line([(0, y), (SW, y)], fill=LINE, width=2)
    tabs = ["ホーム", "記録", "グラフ", "メニュー", "設定"]
    icons = ["home", "pen", "chart", "list", "gear"]
    for i, (label, ic) in enumerate(zip(tabs, icons)):
        cx = SW / 10 * (2 * i + 1)
        col = BLUE if i == active else INK3
        draw_tab_icon(d, cx, y + 48, ic, col)
        w = d.textlength(label, font=font(26, "Medium"))
        d.text((cx - w / 2, y + 96), label, font=font(26, "Medium"), fill=col)

def ability_icon(d, cx, cy, kind, col):
    """種目に応じた簡易アイコン"""
    s_ = 20
    if kind == "up":
        d.line([(cx, cy + s_), (cx, cy - s_)], fill=col, width=6)
        d.polygon([(cx, cy - s_ - 6), (cx - 11, cy - s_ + 8), (cx + 11, cy - s_ + 8)], fill=col)
    elif kind == "fwd":
        d.line([(cx - s_, cy), (cx + s_, cy)], fill=col, width=6)
        d.polygon([(cx + s_ + 6, cy), (cx + s_ - 8, cy - 11), (cx + s_ - 8, cy + 11)], fill=col)
    elif kind == "run":
        d.ellipse([cx - 4, cy - s_, cx + 12, cy - s_ + 16], fill=col)
        d.line([(cx + 4, cy - 2), (cx - 10, cy + s_)], fill=col, width=6)
        d.line([(cx + 4, cy - 2), (cx + 14, cy + s_)], fill=col, width=6)
        d.line([(cx - 12, cy - 2), (cx + 14, cy - 8)], fill=col, width=6)
    elif kind == "hand":
        d.rounded_rectangle([cx - 14, cy - 16, cx + 14, cy + 16], radius=8, outline=col, width=6)
    elif kind == "bar":
        d.line([(cx - s_, cy), (cx + s_, cy)], fill=col, width=6)
        d.rounded_rectangle([cx - s_ - 6, cy - 12, cx - s_ + 4, cy + 12], radius=4, fill=col)
        d.rounded_rectangle([cx + s_ - 4, cy - 12, cx + s_ + 6, cy + 12], radius=4, fill=col)
    elif kind == "lr":
        d.line([(cx - s_, cy), (cx + s_, cy)], fill=col, width=6)
        d.polygon([(cx - s_ - 6, cy), (cx - s_ + 8, cy - 10), (cx - s_ + 8, cy + 10)], fill=col)
        d.polygon([(cx + s_ + 6, cy), (cx + s_ - 8, cy - 10), (cx + s_ - 8, cy + 10)], fill=col)

def draw_tab_icon(d, cx, cy, kind, col):
    s = 22
    if kind == "home":
        d.polygon([(cx, cy - s), (cx - s, cy), (cx + s, cy)], outline=col, width=5)
        d.rectangle([cx - s * 0.7, cy - 2, cx + s * 0.7, cy + s * 0.8], outline=col, width=5)
    elif kind == "pen":
        d.rectangle([cx - s * 0.8, cy - s * 0.8, cx + s * 0.8, cy + s * 0.8], outline=col, width=5)
        d.line([(cx - 6, cy + 8), (cx + 10, cy - 10)], fill=col, width=6)
    elif kind == "chart":
        d.line([(cx - s, cy + s * 0.6), (cx - s * 0.2, cy - s * 0.2),
                (cx + s * 0.3, cy + s * 0.2), (cx + s, cy - s * 0.8)], fill=col, width=6, joint="curve")
    elif kind == "list":
        for k in range(3):
            yy = cy - s * 0.7 + k * s * 0.7
            d.line([(cx - s * 0.7, yy), (cx + s * 0.8, yy)], fill=col, width=5)
    elif kind == "gear":
        d.ellipse([cx - s * 0.55, cy - s * 0.55, cx + s * 0.55, cy + s * 0.55], outline=col, width=5)
        for k in range(6):
            import math
            a = math.radians(k * 60)
            d.line([(cx + math.cos(a) * s * 0.75, cy + math.sin(a) * s * 0.75),
                    (cx + math.cos(a) * s * 1.05, cy + math.sin(a) * s * 1.05)], fill=col, width=6)

def ad_slot(d):
    """画面下部の広告枠（実際のアプリと同じ位置）"""
    y = SH - 190
    d.rectangle([0, y - 110, SW, y], fill=(238, 240, 244))
    d.line([(0, y - 110), (SW, y - 110)], fill=LINE, width=2)
    w = d.textlength("広告", font=font(24, "Medium"))
    d.text((SW/2 - w/2, y - 72), "広告", font=font(24, "Medium"), fill=INK3)

def category_tabs(d, labels, active, colors):
    """記録タブのカテゴリ切り替え"""
    n = len(labels)
    pad, gap = 32, 16
    tw = (SW - pad * 2 - gap * (n - 1)) / n
    for i, lb in enumerate(labels):
        x = pad + i * (tw + gap)
        on = (i == active)
        rrect(d, [x, 216, x + tw, 336], 28, colors[i] if on else CARD)
        col = (255, 255, 255) if on else INK
        w = d.textlength(lb, font=font(25, "Medium"))
        d.text((x + tw/2 - w/2, 292), lb, font=font(25, "Medium"), fill=col)
        # アイコン代わりの丸
        d.ellipse([x + tw/2 - 17, 240, x + tw/2 + 17, 274],
                  fill=(255, 255, 255) if on else colors[i])

# ---------------------------------------------------------------- 画面1
def screen_ability():
    """身体能力の記録一覧"""
    img, d = screen_base("記録")
    category_tabs(d, ["身体測定", "身体能力", "トレーニング", "コンディション"],
                  1, [BLUE, GREEN, ORANGE, PINK])

    rows = [("垂直跳び", "67.0", "cm", True, "up"),
            ("50m走", "6.55", "秒", True, "run"),
            ("握力（右）", "47.0", "kg", False, "hand"),
            ("ベンチプレス(MAX)", "85.0", "kg", True, "bar"),
            ("立ち幅跳び", "245.0", "cm", False, "fwd"),
            ("反復横跳び", "58.0", "回", False, "lr"),
            ("スクワット(MAX)", "115.0", "kg", True, "bar"),
            ("シャトルラン", "96.0", "回", False, "run"),
            ("懸垂", "18.0", "回", False, "up")]
    y = 380
    for name, val, unit, best, kind in rows:
        rrect(d, [32, y, SW - 32, y + 168], 34, CARD)
        rrect(d, [64, y + 42, 148, y + 126], 22, (232, 248, 236))
        ability_icon(d, 106, y + 84, kind, GREEN)
        d.text((186, y + 44), name, font=font(31, "Medium"), fill=INK)
        if best:
            bw = d.textlength("自己ベスト", font=font(21)) + 28
            rrect(d, [186, y + 96, 186 + bw, y + 140], 20, (255, 240, 218))
            d.text((200, y + 104), "自己ベスト", font=font(21), fill=ORANGE)
        vw = d.textlength(val, font=font(46))
        d.text((SW - 64 - vw - 46, y + 60), val, font=font(46), fill=GREEN)
        d.text((SW - 60 - 40, y + 78), unit, font=font(26, "Medium"), fill=INK2)
        y += 186

    ad_slot(d); tab_bar(d, 1)
    return img

# ---------------------------------------------------------------- 画面2
def screen_graph():
    """成長グラフ"""
    img, d = screen_base("グラフ")

    # 指標チップ 3列×2行
    labels = ["体重", "体脂肪率", "筋肉量", "身体能力", "挙上量", "体調"]
    cols = [BLUE, ORANGE, GREEN, PURPLE, ORANGE, PINK]
    pad, gap = 32, 16
    tw = (SW - pad*2 - gap*2) / 3
    for i, lb in enumerate(labels):
        r, c = divmod(i, 3)
        x = pad + c * (tw + gap); yy = 214 + r * 96
        on = (i == 3)
        rrect(d, [x, yy, x + tw, yy + 80], 22, cols[i] if on else CARD)
        w = d.textlength(lb, font=font(27, "Medium"))
        d.text((x + tw/2 - w/2, yy + 24), lb, font=font(27, "Medium"),
               fill=(255,255,255) if on else INK)

    # 期間セグメント
    rrect(d, [32, 418, SW-32, 494], 18, (232, 234, 240))
    segs = ["1ヶ月", "3ヶ月", "6ヶ月", "1年", "全期間"]
    sw_ = (SW - 64) / 5
    for i, sgm in enumerate(segs):
        x = 32 + i * sw_
        if i == 2:
            rrect(d, [x+5, 423, x+sw_-5, 489], 15, CARD)
        w = d.textlength(sgm, font=font(26, "Medium"))
        d.text((x + sw_/2 - w/2, 440), sgm, font=font(26, "Medium"),
               fill=INK if i == 2 else INK2)

    # グラフカード
    rrect(d, [32, 522, SW-32, 1330], 34, CARD)
    d.text((72, 566), "垂直跳び の推移", font=font(34), fill=INK)

    gx0, gy0, gx1, gy1 = 108, 660, SW-80, 1250
    pts = [(0,58.0),(1,60.5),(2,61.0),(3,63.5),(4,64.0),(5,66.0),(6,67.0)]
    ymin, ymax = 55.0, 69.0
    for i in range(5):
        yy = gy1 - (gy1-gy0)*i/4
        d.line([(gx0, yy), (gx1, yy)], fill=LINE, width=2)
        lbl = f"{ymin + (ymax-ymin)*i/4:.1f}"
        w = d.textlength(lbl, font=font(22, "Regular"))
        d.text((gx0 - w - 16, yy - 14), lbl, font=font(22, "Regular"), fill=INK3)

    def px(i): return gx0 + (gx1-gx0)*i/6
    def py(v): return gy1 - (gy1-gy0)*(v-ymin)/(ymax-ymin)

    # 面
    poly = [(px(i), py(v)) for i, v in pts] + [(px(6), gy1), (px(0), gy1)]
    area = Image.new("RGBA", (SW, SH), (0,0,0,0))
    ad = ImageDraw.Draw(area)
    ad.polygon(poly, fill=(*PURPLE, 46))
    img = Image.alpha_composite(img.convert("RGBA"), area).convert("RGB")
    d = ImageDraw.Draw(img)
    for i in range(5):
        yy = gy1 - (gy1-gy0)*i/4
        d.line([(gx0, yy), (gx1, yy)], fill=LINE, width=2)
        lbl = f"{ymin + (ymax-ymin)*i/4:.1f}"
        w = d.textlength(lbl, font=font(22, "Regular"))
        d.text((gx0 - w - 16, yy - 14), lbl, font=font(22, "Regular"), fill=INK3)

    d.line([(px(i), py(v)) for i, v in pts], fill=PURPLE, width=8, joint="curve")
    for i, v in pts:
        d.ellipse([px(i)-11, py(v)-11, px(i)+11, py(v)+11], fill=PURPLE)

    # サマリー
    rrect(d, [32, 1358, SW-32, 1542], 34, CARD)
    items = [("最新","67.0",PURPLE),("最高","67.0",GREEN),("最低","58.0",BLUE),("変化","+9.0",GREEN)]
    for i,(lb,v,c) in enumerate(items):
        cx = 32 + (SW-64)/8*(2*i+1)
        w = d.textlength(lb, font=font(24, "Regular")); d.text((cx-w/2, 1398), lb, font=font(24,"Regular"), fill=INK2)
        w = d.textlength(v, font=font(40)); d.text((cx-w/2, 1442), v, font=font(40), fill=c)
        if i < 3: d.line([(32+(SW-64)/4*(i+1), 1388),(32+(SW-64)/4*(i+1), 1512)], fill=LINE, width=2)

    # 分析への導線カード
    rrect(d, [32, 1570, SW-32, 1730], 34, CARD)
    d.text((72, 1612), "コンディション分析を見る", font=font(32, "Medium"), fill=INK)
    d.text((72, 1662), "睡眠・疲労との関係を確認できます", font=font(25, "Regular"), fill=INK2)
    d.line([(SW-104, 1650),(SW-84, 1670)], fill=INK3, width=5)
    d.line([(SW-104, 1690),(SW-84, 1670)], fill=INK3, width=5)

    ad_slot(d); tab_bar(d, 2)
    return img

# ---------------------------------------------------------------- 画面3
def screen_insight():
    """コンディション分析"""
    img, d = screen_base("コンディション分析")

    d.text((44, 216), "コンディション", font=font(24, "Regular"), fill=INK2)
    chips = ["睡眠時間", "疲労度", "体調"]
    pad, gap = 32, 16
    tw = (SW - pad*2 - gap*2)/3
    for i, c in enumerate(chips):
        x = pad + i*(tw+gap)
        on = (i == 0)
        rrect(d, [x, 258, x+tw, 338], 22, PURPLE if on else CARD)
        w = d.textlength(c, font=font(28, "Medium"))
        d.text((x+tw/2-w/2, 282), c, font=font(28, "Medium"), fill=(255,255,255) if on else INK)

    d.text((44, 366), "パフォーマンス", font=font(24, "Regular"), fill=INK2)
    chips2 = ["総挙上量", "垂直跳び", "50m走"]
    for i, c in enumerate(chips2):
        x = pad + i*(tw+gap)
        on = (i == 0)
        rrect(d, [x, 408, x+tw, 488], 22, GREEN if on else CARD)
        w = d.textlength(c, font=font(28, "Medium"))
        d.text((x+tw/2-w/2, 432), c, font=font(28, "Medium"), fill=(255,255,255) if on else INK)

    # 所見カード
    rrect(d, [32, 528, SW-32, 872], 34, CARD)
    d.text((72, 566), "わかったこと", font=font(32), fill=INK)
    lines = ["睡眠時間が長い日ほど、総挙上量が", "高い傾向がありました", "（強い関係・24日分のデータ）"]
    yy = 626
    for ln in lines:
        d.text((72, yy), ln, font=font(31, "Regular"), fill=INK); yy += 52
    d.line([(72, 792), (SW-72, 792)], fill=LINE, width=2)
    d.text((72, 812), "7.0時間以上の日は平均 4,820kg", font=font(27, "Regular"), fill=INK2)

    # 散布図
    rrect(d, [32, 900, SW-32, 1900], 34, CARD)
    d.text((72, 942), "散布図", font=font(32), fill=INK)
    rw = d.textlength("相関係数 0.78", font=font(26, "Medium"))
    d.text((SW-72-rw, 948), "相関係数 0.78", font=font(26, "Medium"), fill=PURPLE)

    gx0, gy0, gx1, gy1 = 120, 1030, SW-80, 1830
    for i in range(5):
        yy = gy1-(gy1-gy0)*i/4
        d.line([(gx0, yy),(gx1, yy)], fill=LINE, width=2)
    pts = [(5.6,3980),(6.1,4210),(6.4,4050),(6.8,4460),(7.0,4620),(7.2,4530),
           (7.5,4880),(7.8,5010),(8.0,4940),(8.3,5220),(6.6,4320),(7.3,4700),
           (5.9,4100),(8.1,5150),(6.9,4400),(7.6,4790)]
    xs=[p[0] for p in pts]; ys=[p[1] for p in pts]
    x0,x1=min(xs)-0.3,max(xs)+0.3; y0,y1=min(ys)-200,max(ys)+200
    def PX(v): return gx0+(gx1-gx0)*(v-x0)/(x1-x0)
    def PY(v): return gy1-(gy1-gy0)*(v-y0)/(y1-y0)
    # 回帰直線
    n=len(pts); mx=sum(xs)/n; my=sum(ys)/n
    num=sum((a-mx)*(b-my) for a,b in pts); den=sum((a-mx)**2 for a in xs)
    sl=num/den; ic=my-sl*mx
    for k in range(0, 40, 2):
        t0=min(xs)+(max(xs)-min(xs))*k/40; t1=min(xs)+(max(xs)-min(xs))*(k+1)/40
        d.line([(PX(t0),PY(sl*t0+ic)),(PX(t1),PY(sl*t1+ic))], fill=ORANGE, width=6)
    for a,b in pts:
        d.ellipse([PX(a)-14, PY(b)-14, PX(a)+14, PY(b)+14], fill=(*PURPLE,), outline=None)

    d.text((72, 1856), "横軸: 睡眠時間", font=font(23, "Regular"), fill=INK3)
    tw2 = d.textlength("縦軸: 総挙上量", font=font(23, "Regular"))
    d.text((SW-72-tw2, 1856), "縦軸: 総挙上量", font=font(23, "Regular"), fill=INK3)

    ad_slot(d); tab_bar(d, 2)
    return img

# ---------------------------------------------------------------- 画面4
def screen_training():
    """トレーニング記録"""
    img, d = screen_base("記録")
    category_tabs(d, ["身体測定", "身体能力", "トレーニング", "コンディション"],
                  2, [BLUE, GREEN, ORANGE, PINK])

    sessions = [
        ("ウェイトトレーニング", "8/20（木）", "5,240 kg",
         [("ベンチプレス", "80.0kg × 8回 × 4セット"),
          ("インクラインプレス", "55.0kg × 10回 × 3セット"),
          ("ショルダープレス", "45.0kg × 10回 × 3セット")]),
        ("ウェイトトレーニング", "8/18（火）", "6,180 kg",
         [("デッドリフト", "120.0kg × 5回 × 4セット"),
          ("ラットプルダウン", "60.0kg × 10回 × 4セット")]),
        ("バスケットボール", "8/17（月）", None,
         [("シュート練習", "—"), ("1on1", "—")]),
        ("ウェイトトレーニング", "8/15（土）", "5,960 kg",
         [("スクワット", "105.0kg × 8回 × 4セット"),
          ("レッグプレス", "150.0kg × 12回 × 3セット"),
          ("カーフレイズ", "45.0kg × 15回 × 3セット")]),
    ]
    y = 380
    for title, date, vol, exs in sessions:
        h = 200 + len(exs) * 52
        rrect(d, [32, y, SW-32, y+h], 34, CARD)
        d.text((72, y+40), title, font=font(32, "Medium"), fill=INK)
        d.text((72, y+92), date, font=font(26, "Regular"), fill=INK2)
        if vol:
            w = d.textlength("総挙上量", font=font(23, "Regular"))
            d.text((SW-72-w, y+42), "総挙上量", font=font(23,"Regular"), fill=INK2)
            w2 = d.textlength(vol, font=font(32))
            d.text((SW-72-w2, y+80), vol, font=font(32), fill=ORANGE)
        d.line([(72, y+146), (SW-72, y+146)], fill=LINE, width=2)
        yy = y + 168
        for nm, sm in exs:
            d.text((72, yy), nm, font=font(26, "Regular"), fill=INK)
            w = d.textlength(sm, font=font(26, "Regular"))
            d.text((SW-72-w, yy), sm, font=font(26, "Regular"), fill=INK2)
            yy += 52
        y += h + 22

    # FAB
    d.ellipse([SW-186, SH-430, SW-58, SH-302], fill=BLUE)
    d.line([(SW-122-30, SH-366), (SW-122+30, SH-366)], fill=(255,255,255), width=10)
    d.line([(SW-122, SH-366-30), (SW-122, SH-366+30)], fill=(255,255,255), width=10)

    ad_slot(d); tab_bar(d, 1)
    return img

# ---------------------------------------------------------------- 画面5
def screen_menu():
    """メニュー提案"""
    img, d = screen_base("メニュー提案")

    d.text((44, 214), "目的", font=font(30), fill=INK)
    goals = [("筋力・筋量UP", BLUE), ("スピード・瞬発力", PURPLE),
             ("持久力UP", GREEN), ("体脂肪を落とす", PINK)]
    pad, gap = 32, 20
    cw = (SW - pad*2 - gap)/2
    for i, (lb, c) in enumerate(goals):
        r, cidx = divmod(i, 2)
        x = pad + cidx*(cw+gap); y = 268 + r*230
        on = (i == 0)
        rrect(d, [x, y, x+cw, y+206], 30, CARD, outline=c if on else None, width=5)
        d.ellipse([x+cw/2-46, y+38, x+cw/2+46, y+130],
                  fill=c if on else tuple(lerp(c, (255,255,255), 0.86)))
        w = d.textlength(lb, font=font(28, "Medium"))
        d.text((x+cw/2-w/2, y+148), lb, font=font(28, "Medium"), fill=INK)

    d.text((44, 748), "トレーニング歴", font=font(30), fill=INK)
    rrect(d, [32, 800, SW-32, 916], 30, CARD)
    lv = [("初心者","〜6ヶ月"),("中級者","6ヶ月〜2年"),("上級者","2年以上")]
    lw = (SW-88)/3
    for i,(a,b) in enumerate(lv):
        x = 44 + i*lw
        if i == 0: rrect(d, [x, 812, x+lw-12, 904], 22, BLUE)
        col = (255,255,255) if i==0 else INK
        w = d.textlength(a, font=font(29, "Medium")); d.text((x+(lw-12)/2-w/2, 826), a, font=font(29,"Medium"), fill=col)
        w = d.textlength(b, font=font(21, "Regular")); d.text((x+(lw-12)/2-w/2, 866), b, font=font(21,"Regular"),
               fill=(255,255,255) if i==0 else INK2)

    d.text((44, 956), "週あたりの実施日数", font=font(30), fill=INK)
    rrect(d, [32, 1008, SW-32, 1112], 30, CARD)
    dw = (SW-88)/4
    for i, n_ in enumerate(["2", "3", "4", "5"]):
        x = 44 + i*dw
        if i == 1: rrect(d, [x, 1018, x+dw-12, 1102], 22, BLUE)
        col = (255,255,255) if i==1 else INK
        w = d.textlength(n_, font=font(38)); d.text((x+(dw-12)/2-w/2, 1030), n_, font=font(38), fill=col)
        w = d.textlength("日", font=font(21,"Regular")); d.text((x+(dw-12)/2-w/2, 1072), "日", font=font(21,"Regular"),
               fill=(255,255,255) if i==1 else INK2)

    # 生成されたメニュー
    d.text((44, 1152), "Day 1  プッシュ（胸・肩・三頭）", font=font(30), fill=BLUE)
    ex = [("ベンチプレス","4セット × 6〜8回","肩甲骨を寄せて下制する"),
          ("インクラインダンベルプレス","3セット × 8〜12回","胸の上部を狙う"),
          ("ショルダープレス","3セット × 8〜12回","腰を反らせず真上に押す"),
          ("プレスダウン","3セット × 10〜15回","肘の位置を固定する")]
    y = 1208
    rrect(d, [32, y, SW-32, y+22+len(ex)*152], 30, CARD)
    yy = y + 26
    for i,(nm, rep, tip) in enumerate(ex):
        d.text((72, yy), nm, font=font(30, "Medium"), fill=INK)
        w = d.textlength(rep, font=font(26, "Medium"))
        d.text((SW-72-w, yy+4), rep, font=font(26, "Medium"), fill=BLUE)
        d.text((72, yy+48), tip, font=font(25, "Regular"), fill=INK2)
        if i < len(ex)-1:
            d.line([(72, yy+118), (SW-72, yy+118)], fill=LINE, width=2)
        yy += 152

    ad_slot(d); tab_bar(d, 3)
    return img

# =====================================================================
#  端末フレーム + キャッチコピー
# =====================================================================

def compose(screen_img, headline, sub, accent):
    img = Image.new("RGB", (W*SUP, H*SUP), NAVY_B)
    d = ImageDraw.Draw(img)
    gradient(d, (0, 0, W*SUP, H*SUP), NAVY_T, NAVY_B)

    # 斜めのアクセント光
    glow = Image.new("RGBA", (W*SUP, H*SUP), (0,0,0,0))
    gd = ImageDraw.Draw(glow)
    gd.polygon([(0, H*SUP*0.42), (W*SUP*0.75, 0), (W*SUP, 0), (0, H*SUP*0.72)],
               fill=(*accent, 22))
    img = Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")
    d = ImageDraw.Draw(img)

    # キャッチコピー
    fh = font(int(78*SUP))
    y = int(196*SUP)
    for line in headline:
        text_center(d, W*SUP/2, y, line, fh, (255,255,255))
        y += int(102*SUP)

    fs = font(int(38*SUP), "Medium")
    text_center(d, W*SUP/2, y + int(18*SUP), sub, fs, (176, 196, 226))

    # 端末フレーム
    fw, fh_ = int(940*SUP), int(2020*SUP)
    fx = int((W*SUP - fw)/2); fy = int(560*SUP)
    d.rounded_rectangle([fx-int(14*SUP), fy-int(14*SUP), fx+fw+int(14*SUP), fy+fh_+int(14*SUP)],
                        radius=int(96*SUP), fill=(28, 32, 42))
    d.rounded_rectangle([fx, fy, fx+fw, fy+fh_], radius=int(86*SUP), fill=(255,255,255))

    # 画面をはめ込む
    inner = screen_img.resize((fw-int(12*SUP), fh_-int(12*SUP)), Image.LANCZOS)
    mask = Image.new("L", inner.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0,0,inner.size[0],inner.size[1]],
                                           radius=int(80*SUP), fill=255)
    img.paste(inner, (fx+int(6*SUP), fy+int(6*SUP)), mask)

    return img.resize((W, H), Image.LANCZOS)

# =====================================================================

SHOTS = [
    (screen_ability,
     ["垂直跳び、50m走、握力。", "競技の数字を、残す。"],
     "一般的な筋トレアプリにはない項目まで記録できます", GREEN),
    (screen_graph,
     ["伸びているか、", "ひと目でわかる。"],
     "体重・体脂肪率から身体能力まで、6指標をグラフ化", PURPLE),
    (screen_insight,
     ["よく眠れた日は、", "重さが上がる。"],
     "睡眠・疲労とパフォーマンスの関係を自動で分析", BLUE),
    (screen_training,
     ["重量 × 回数 × セット。", "総挙上量は自動計算。"],
     "その日の練習量が数字で残ります", ORANGE),
    (screen_menu,
     ["目的を選べば、", "メニューが決まる。"],
     "5つの目的 × 経験レベル × 週の日数で提案", BLUE),
]

if __name__ == "__main__":
    # プロジェクトルート直下の screenshots/ に出力する
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "screenshots")
    os.makedirs(out, exist_ok=True)
    for i, (fn, head, sub, acc) in enumerate(SHOTS, 1):
        s = fn()
        img = compose(s, head, sub, acc)
        path = f"{out}/{i:02d}_appstore_1320x2868.png"
        img.save(path, "PNG")
        print(f"saved {path}  {img.size}")
        # 目視確認用の縮小版が必要なら以下を有効化
        # img.resize((330, 717), Image.LANCZOS).save(f"{out}/preview_{i}.png")
