"""Trace a hearing aid packshot into outline data: case contour, wire centreline, receiver contour.
usage: trace.py image name [lum_threshold|-] [crop|-]  -> name.json (coords in a 0..300 box) and name_preview.svg"""
import sys, json, cv2, numpy as np
p, name = sys.argv[1], sys.argv[2]
thr = sys.argv[3] if len(sys.argv) > 3 else '-'
crop = sys.argv[4] if len(sys.argv) > 4 else '-'
im = cv2.imread(p, cv2.IMREAD_UNCHANGED)
if crop != '-':
    x0, y0, x1, y1 = map(int, crop.split(',')); im = im[y0:y1, x0:x1]
if thr == '-' and im.shape[2] == 4:
    mask = (im[:, :, 3] > 110).astype(np.uint8)
else:
    g = cv2.cvtColor(im[:, :, :3], cv2.COLOR_BGR2GRAY); mask = (g > int(thr)).astype(np.uint8)
# Work at about 400 px on the long side.
s = 400.0 / max(mask.shape)
mask = cv2.resize(mask, (int(mask.shape[1] * s), int(mask.shape[0] * s)), interpolation=cv2.INTER_NEAREST)
mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
# Optional cuts (working-scale lines x0,y0,x1,y1;...) to part shapes that touch in the photo.
if len(sys.argv) > 5:
    for seg in sys.argv[5].split(';'):
        x0, y0, x1, y1 = map(int, seg.split(','))
        cv2.line(mask, (x0, y0), (x1, y1), 0, 4)
k = int(sys.argv[6]) if len(sys.argv) > 6 else 11
opened = cv2.morphologyEx(mask, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)))
n, lab, st, _ = cv2.connectedComponentsWithStats(opened)
order = sorted(range(1, n), key=lambda i: -st[i, 4])
blobs = [i for i in order if st[i, 4] > 0.01 * st[order[0], 4]][:2]

def contour(m, eps):
    cs, _ = cv2.findContours(m.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    c = max(cs, key=cv2.contourArea)
    c = cv2.approxPolyDP(c, eps, True)
    return c[:, 0, :].astype(float)

case = contour(lab == blobs[0], 1.6)
recv = contour(lab == blobs[1], 1.2) if len(blobs) > 1 else None
# Wire = the thin parts: mask minus the (slightly grown) blobs.
grown = cv2.dilate(opened, np.ones((5, 5), np.uint8))
wire = ((mask > 0) & (grown == 0)).astype(np.uint8)
n2, lab2, st2, _ = cv2.connectedComponentsWithStats(wire)
wire_pts = []
if n2 > 1:
    w = max(range(1, n2), key=lambda i: st2[i, 4])
    wm = (lab2 == w).astype(np.uint8)
    # Zhang-Suen thinning.
    img = wm.copy()
    def nb(a):
        P = np.pad(a, 1)
        return [P[0:-2, 1:-1], P[0:-2, 2:], P[1:-1, 2:], P[2:, 2:], P[2:, 1:-1], P[2:, 0:-2], P[1:-1, 0:-2], P[0:-2, 0:-2]]
    changed = True
    while changed:
        changed = False
        for step in (0, 1):
            ns = nb(img); B = sum(ns)
            A = sum(((ns[i] == 0) & (ns[(i + 1) % 8] == 1)).astype(int) for i in range(8))
            if step == 0:
                c1 = ns[0] * ns[2] * ns[4]; c2 = ns[2] * ns[4] * ns[6]
            else:
                c1 = ns[0] * ns[2] * ns[6]; c2 = ns[0] * ns[4] * ns[6]
            rm = (img == 1) & (B >= 2) & (B <= 6) & (A == 1) & (c1 == 0) & (c2 == 0)
            if rm.any():
                img[rm] = 0; changed = True
    ys, xs = np.nonzero(img)
    pts = set(zip(xs.tolist(), ys.tolist()))
    def nbrs(q):
        x, y = q
        return [(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx or dy) and (x + dx, y + dy) in pts]
    from collections import deque
    def bfs(a):
        prev = {a: None}; dq = deque([a]); last = a
        while dq:
            q = dq.popleft(); last = q
            for r in nbrs(q):
                if r not in prev:
                    prev[r] = q; dq.append(r)
        return last, prev
    start = next(iter(pts))
    e1, _ = bfs(start); e2, prev = bfs(e1)
    path = []; q = e2
    while q is not None:
        path.append(q); q = prev[q]
    path = np.array(path, float)
    wire_pts = cv2.approxPolyDP(path.reshape(-1, 1, 2).astype(np.float32), 1.5, False)[:, 0, :].astype(float)
# Normalise everything into a 300 x 300 box, keeping proportions.
allp = np.vstack([case] + ([recv] if recv is not None else []) + ([wire_pts] if len(wire_pts) else []))
mn = allp.min(0); mx = allp.max(0); sc = 280.0 / max(mx - mn); off = (300 - (mx - mn) * sc) / 2
f = lambda a: [[round(float(x), 1), round(float(y), 1)] for x, y in ((a - mn) * sc + off)]
out = {'case': f(case), 'recv': f(recv) if recv is not None else [], 'wire': f(wire_pts) if len(wire_pts) else []}
json.dump(out, open(name + '.json', 'w'))
pts = lambda a: ' '.join('%g,%g' % tuple(q) for q in a)
svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 300" width="300" height="300"><rect width="300" height="300" fill="#fff"/>'
svg += '<polygon points="%s" fill="#bbb" stroke="#000"/>' % pts(out['case'])
if out['recv']: svg += '<polygon points="%s" fill="#88f" stroke="#000"/>' % pts(out['recv'])
if out['wire']: svg += '<polyline points="%s" fill="none" stroke="#f00" stroke-width="2"/>' % pts(out['wire'])
open(name + '_preview.svg', 'w').write(svg + '</svg>')
print(name, len(out['case']), len(out['recv']), len(out['wire']))
