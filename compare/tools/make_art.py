#!/usr/bin/env python3
"""Draws the side-view pictures of each hearing aid style sitting on an ear, as SVG files in compare/art/.

Generic drawings of a style, never a product: an ear seen from the side (face to the left), with the aid where it
is worn. One file per style and shell colour: art/<style>-<shell>.svg. Also packs them into data/art.json, which the page rasterizes at the screen's real resolution.
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
    with open(os.path.join(root, "data", "art.json"), "w") as f:
        json.dump({"_comment": "Generated by tools/make_art.py: do not edit by hand.", "art": pack}, f, indent=1)
        f.write("\n")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
