#!/usr/bin/env python3
"""Draws the page's pictures as SVG and packs them into data/art.json, which the page rasterizes at the screen's
real resolution (previews go to compare/art/, which Godot ignores).

Two kinds:
- <style>-<shell>: how a style is worn, an ear seen from the side (face to the left) with the aid in place.
- product-<aid id>[-<style>]: each hearing aid as it looks, drawn in the page's style over the outline traced
  from its product photo (tools/outlines.json, made by tools/trace_photo.py). Colours, shading, buttons, lights and
  microphones are drawn here; no photo, logo or lettering is used.
Run: python3 compare/tools/make_art.py
"""
import json
import os
import sys

SHELLS = {
    "silver": ("#c9ccd1", "#8f949b"),
    "graphite": ("#5f636b", "#3c3f45"),
    "graphite_dark": ("#44474d", "#26282c"),
    "beige": ("#dcc3a3", "#a88b68"),
    "rose": ("#e0b2a6", "#ad7d70"),
}

SKIN = "#f4dccb"
SKIN_SHADE = "#e8c4ad"
SKIN_DEEP = "#d9a98f"
LINE = "#b07f66"

EAR = """
  <g id="ear">
    <path d="M78,60 C80,28 120,14 142,26 C166,40 170,80 161,108 C155,128 143,140 138,156
             C133,176 116,186 103,177 C95,171 95,160 100,152 C91,141 85,129 87,118
             C80,112 78,103 84,97 C76,85 74,73 78,60 Z"
          fill="{skin}" stroke="{line}" stroke-width="2.2" stroke-linejoin="round"/>
    <path d="M88,62 C94,38 128,28 146,44 C158,58 157,90 149,112 C144,126 136,136 130,146"
          fill="none" stroke="{line}" stroke-width="1.6" stroke-linecap="round" opacity="0.75"/>
    <path d="M110,56 C131,60 141,84 134,106 C129,122 118,131 108,138"
          fill="none" stroke="{line}" stroke-width="1.6" stroke-linecap="round" opacity="0.7"/>
    <path d="M97,88 C110,80 128,90 130,108 C132,126 119,139 105,139 C96,138 91,129 91,118 C91,105 92,94 97,88 Z"
          fill="{shade}"/>
    <ellipse cx="101" cy="113" rx="7.5" ry="9.5" fill="{deep}"/>
    <ellipse cx="100" cy="114" rx="4.5" ry="6.5" fill="#7a4f3d" opacity="0.55"/>
  </g>"""


def ear():
    return EAR.format(skin=SKIN, line=LINE, shade=SKIN_SHADE, deep=SKIN_DEEP)


def behind_case(fill, edge, long=False):
    # A slim kidney-shaped case lying along the back of the ear's top.
    if long:
        d = ("M132,22 C150,8 182,22 185,58 C186,78 182,94 173,100 C167,103 163,99 165,92 "
             "C171,72 168,44 152,33 C144,28 137,30 133,30 C127,30 127,25 132,22 Z")
    else:
        d = ("M134,24 C150,12 177,26 179,56 C180,70 177,80 171,84 C166,87 163,83 165,78 "
             "C169,64 165,44 152,35 C145,30 139,31 135,31 C130,31 130,27 134,24 Z")
    return (f'<path d="{d}" fill="{fill}" stroke="{edge}" stroke-width="1.6" stroke-linejoin="round"/>'
            # a soft highlight along the top
            f'<path d="M140,25 C152,18 168,28 172,46" fill="none" stroke="#ffffff" stroke-width="2" '
            f'stroke-linecap="round" opacity="0.45"/>'
            # two microphone slots and a button on the top ridge
            f'<circle cx="152" cy="21.5" r="1.5" fill="#1e1f22"/><circle cx="163" cy="27" r="1.5" fill="#1e1f22"/>'
            f'<rect x="168" y="33" width="6" height="9" rx="3" fill="{edge}" transform="rotate(35 171 37)"/>')


def ric(fill, edge):
    wire = ('<path d="M134,27 C114,19 96,28 93,48 C90,68 96,90 100,105" fill="none" stroke="#7b8088" '
            'stroke-width="1.8" stroke-linecap="round"/>')
    receiver = (f'<rect x="96" y="103" width="8" height="12" rx="3" fill="{edge}" transform="rotate(-12 100 109)"/>'
                '<ellipse cx="101" cy="116" rx="6.5" ry="4.5" fill="#ffffff" opacity="0.75" '
                'stroke="#b9bec5" stroke-width="1"/>')
    return behind_case(fill, edge) + wire + receiver


def bte(fill, edge):
    t = "M133,27 C112,17 95,27 92,48 C89,70 96,92 100,107"
    tube = (f'<path d="{t}" fill="none" stroke="#8fa6ba" stroke-width="4.5" stroke-linecap="round" opacity="0.6"/>'
            f'<path d="{t}" fill="none" stroke="#ffffff" stroke-width="1.2" stroke-linecap="round" opacity="0.8"/>')
    dome = ('<ellipse cx="101" cy="113" rx="7" ry="5" fill="#ffffff" opacity="0.8" stroke="#b9bec5" '
            'stroke-width="1"/>')
    return behind_case(fill, edge, long=True) + tube + dome


def itc(fill, edge):
    # A kidney-shaped shell filling the lower bowl of the ear, its flat face towards us.
    shell = (f'<path d="M94,104 C97,95 110,93 119,99 C127,105 127,119 120,127 C113,134 99,134 94,126 '
             f'C91,120 92,110 94,104 Z" fill="{fill}" stroke="{edge}" stroke-width="1.6"/>')
    shine = ('<path d="M98,102 C104,97 113,97 118,101" fill="none" stroke="#ffffff" stroke-width="1.6" '
             'stroke-linecap="round" opacity="0.45"/>')
    # Battery door seam along the lower edge, one microphone inlet, a vent hole.
    # Battery door (a rounded rectangle with its pull notch) and a microphone slot.
    parts = (f'<rect x="104" y="111" width="14" height="11" rx="3" fill="none" stroke="{edge}" stroke-width="1.1"/>'
             f'<rect x="115" y="114" width="3" height="5" rx="1" fill="{edge}"/>'
             '<rect x="98" y="104" width="6" height="2" rx="1" fill="#1e1f22"/>')
    return shell + shine + parts


def cic(fill, edge):
    # Only the small face shows at the canal opening, with its pull line.
    face = (f'<ellipse cx="101" cy="113" rx="6" ry="7.5" fill="{fill}" stroke="{edge}" stroke-width="1.2"/>')
    pull = ('<path d="M102,119 C104,124 108,127 112,127" fill="none" stroke="#2b2c30" stroke-width="1.3" '
            'stroke-linecap="round"/><circle cx="112.5" cy="127" r="1.5" fill="#2b2c30"/>')
    return face + pull


STYLES = {"ric": ric, "bte": bte, "itc": itc, "cic": cic}
# Which pictures the page uses (style, shell).
WANTED = [("ric", s) for s in SHELLS] + [("bte", "beige"), ("itc", "graphite_dark"), ("cic", "graphite_dark"),
                                          ("itc", "beige"), ("cic", "beige")]


def svg(style, shell):
    fill, edge = SHELLS[shell]
    body = STYLES[style](fill, edge)
    if style in ("ric", "bte"):
        # The case sits behind the ear (drawn first, so the helix overlaps it); the wire or tube and the dome lie
        # over the ear (drawn after it).
        case = behind_case(fill, edge, long=style == "bte")
        inner = case + ear() + body[len(case):]
    else:
        inner = ear() + body
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="60 4 140 190" width="280" height="380">'
            f'{inner}</svg>\n')


# ---------------------------------------------------------------- the products, from their traced outlines

INK = "#2e2442"

# Per drawing: the outline key, the case's light and dark colours, wire, receiver and dome colours, and the details,
# placed by eye from the photo (in the outline's 300 x 300 box): ("shine", path), ("button", x, y, w, h, angle),
# ("led", x, y), ("mic", x, y), ("dome", x, y, r) and ("core", x, y, r) for a round dome and its speaker,
# ("plate", x, y, w, h, angle) for an in-ear faceplate, ("receiver", x, y, angle) where the photo hides it.
PRODUCTS = {
    "product-sonite_rise": dict(outline="sonite_rise", case=("#eceef1", "#a9adb4"), wire="#dfe3e8",
                                recv="#9aa0a8", dome="#dfe6ee",
                                details=[("shine", "M110,60 C100,110 96,170 98,240"), ("mic", 141, 40),
                                         ("button", 129, 90, 13, 18, -10), ("button", 116, 156, 13, 18, -6),
                                         ("mic", 104, 205)]),
    "product-jabra_pro30": dict(outline="jabra_pro30", case=("#6a6b72", "#2a2b30"), wire="#e6eaf0",
                                recv="#3a3c42", dome="#8fa5c6",
                                details=[("shine", "M30,60 C24,110 22,180 26,250"), ("mic", 34, 58),
                                         ("button", 34, 205, 16, 46, 0), ("mic", 76, 251)]),
    "product-philips_9050": dict(outline="philips_9050", case=("#e6dccd", "#a8987f"), wire="#e9a7a2",
                                 recv="#3a5a9c", dome="#e3ecf6",
                                 details=[("shine", "M50,80 C40,130 38,200 44,260"), ("mic", 70, 66),
                                          ("led", 58, 98), ("button", 52, 205, 18, 92, 0),
                                          ("dome", 226, 206, 31), ("core", 226, 206, 12)]),
    "product-rexton_rplus": dict(outline="rexton_rplus", case=("#5b5d63", "#232428"), wire="#e3e8ee",
                                 recv="#4a4d54", dome="#d9e2ec",
                                 details=[("shine", "M90,60 C66,100 56,160 56,240"), ("led", 156, 28),
                                          ("button", 44, 112, 9, 18, 25), ("button", 37, 177, 9, 18, 10),
                                          ("mic", 112, 140)]),
    "product-soundgear_amp": dict(outline="soundgear_amp", case=("#f3cdbd", "#b97f6c"), wire="#d9dde3",
                                  recv="#3a3c42", dome="#9aa1aa",
                                  details=[("shine", "M40,70 C24,110 22,170 34,220"), ("led", 50, 128),
                                           ("button", 52, 172, 16, 34, 0)]),
    "product-soundgear_amp-cic": dict(outline="soundgear_amp-cic", case=("#55575d", "#1f2024"), wire="#9aa0a8",
                                      recv="#3a3c42", dome="#9aa1aa",
                                      details=[("plate", 104, 160, 60, 150, 8), ("mic", 104, 110),
                                               ("mic", 104, 205), ("button", 104, 158, 22, 36, 0)]),
}


def _smooth(pts, closed=True, t=0.5):
    """A Catmull-Rom curve through the traced points, as an SVG path."""
    n = len(pts)
    if n < 3:
        return "M" + " L".join("%g,%g" % tuple(q) for q in pts)
    def at(i):
        return pts[i % n] if closed else pts[max(0, min(n - 1, i))]
    d = "M%g,%g" % tuple(pts[0])
    last = n if closed else n - 1
    for i in range(last):
        p0, p1, p2, p3 = at(i - 1), at(i), at(i + 1), at(i + 2)
        c1 = (p1[0] + (p2[0] - p0[0]) * t / 3, p1[1] + (p2[1] - p0[1]) * t / 3)
        c2 = (p2[0] - (p3[0] - p1[0]) * t / 3, p2[1] - (p3[1] - p1[1]) * t / 3)
        d += " C%.1f,%.1f %.1f,%.1f %g,%g" % (c1[0], c1[1], c2[0], c2[1], p2[0], p2[1])
    return d + (" Z" if closed else "")


def product_svg(key, outlines):
    spec = PRODUCTS[key]
    o = outlines[spec["outline"]]
    light, dark = spec["case"]
    gid = key.replace("-", "_")
    xs = [q[0] for q in o["case"]]
    x0, x1 = min(xs), max(xs)
    parts = [
        f'<defs><linearGradient id="{gid}" x1="{x0}" y1="0" x2="{x1}" y2="0" gradientUnits="userSpaceOnUse">'
        f'<stop offset="0" stop-color="{light}"/><stop offset="0.45" stop-color="{light}"/>'
        f'<stop offset="1" stop-color="{dark}"/></linearGradient></defs>',
        # A soft shadow on the "table".
        f'<ellipse cx="150" cy="292" rx="120" ry="6" fill="{INK}" opacity="0.12"/>',
    ]
    if o["wire"]:
        w = _smooth(o["wire"], closed=False)
        parts.append(f'<path d="{w}" fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round" '
                     'stroke-linejoin="round"/>')
        parts.append(f'<path d="{w}" fill="none" stroke="{spec["wire"]}" stroke-width="3.2" '
                     'stroke-linecap="round" stroke-linejoin="round"/>')
    if o["recv"]:
        parts.append(f'<path d="{_smooth(o["recv"])}" fill="{spec["dome"]}" stroke="{INK}" stroke-width="4" '
                     'stroke-linejoin="round"/>')
    parts.append(f'<path d="{_smooth(o["case"])}" fill="url(#{gid})" stroke="{INK}" stroke-width="4.5" '
                 'stroke-linejoin="round"/>')
    for det in spec["details"]:
        kind = det[0]
        if kind == "button":
            _, x, y, w, h, a = det
            parts.append(f'<rect x="{x - w / 2}" y="{y - h / 2}" width="{w}" height="{h}" rx="{min(w, h) / 2}" '
                         f'fill="{dark}" stroke="{INK}" stroke-width="2.5" transform="rotate({a} {x} {y})"/>')
        elif kind == "led":
            _, x, y = det
            parts.append(f'<circle cx="{x}" cy="{y}" r="4.5" fill="#57e389" stroke="{INK}" stroke-width="1.5"/>')
        elif kind == "mic":
            _, x, y = det
            parts.append(f'<circle cx="{x}" cy="{y}" r="3.2" fill="{INK}"/>')
        elif kind == "shine":
            _, d = det
            parts.append(f'<path d="{d}" fill="none" stroke="#ffffff" stroke-width="5" stroke-linecap="round" '
                         'opacity="0.55"/>')
        elif kind == "dome":
            _, x, y, r = det
            parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{spec["dome"]}" stroke="{INK}" stroke-width="4"/>'
                         f'<circle cx="{x}" cy="{y}" r="{r * 0.62}" fill="none" stroke="{INK}" stroke-width="1.5" '
                         'opacity="0.35"/>')
        elif kind == "core":
            _, x, y, r = det
            parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{spec["recv"]}" stroke="{INK}" stroke-width="2.5"/>')
        elif kind == "plate":
            _, x, y, w, h, a = det
            parts.append(f'<rect x="{x - w / 2}" y="{y - h / 2}" width="{w}" height="{h}" rx="{w / 2.4}" '
                         f'fill="{light}" stroke="{INK}" stroke-width="2.5" transform="rotate({a} {x} {y})"/>')
        elif kind == "receiver":
            _, x, y, a = det
            parts.append(f'<g transform="translate({x} {y}) rotate({a})">'
                         f'<rect x="-7" y="-4" width="20" height="13" rx="5" fill="{spec["recv"]}" stroke="{INK}" '
                         f'stroke-width="3"/><path d="M13,-6 C27,-6 31,2 31,2.5 C31,3 27,11 13,11 Z" '
                         f'fill="{spec["dome"]}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/></g>')
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 300" width="380" height="380">'
            + "".join(parts) + "</svg>\n")


def main(root):
    """Writes art/<style>-<shell>.svg (previews; Godot ignores the folder) and data/art.json (what the page loads)."""
    art = os.path.join(root, "art")
    os.makedirs(art, exist_ok=True)
    with open(os.path.join(art, ".gdignore"), "w") as f:
        f.write("")
    pack = {}
    for style, shell in WANTED:
        text = svg(style, shell)
        pack[f"{style}-{shell}"] = text
        with open(os.path.join(art, f"{style}-{shell}.svg"), "w") as f:
            f.write(text)
    with open(os.path.join(root, "tools", "outlines.json")) as f:
        outlines = json.load(f)
    for key in PRODUCTS:
        text = product_svg(key, outlines)
        pack[key] = text
        with open(os.path.join(art, key + ".svg"), "w") as f:
            f.write(text)
    with open(os.path.join(root, "data", "art.json"), "w") as f:
        json.dump({"_comment": "Generated by tools/make_art.py: do not edit by hand.", "art": pack}, f, indent=1)
        f.write("\n")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
