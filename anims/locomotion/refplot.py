"""Plot reference clip curves (top channels) and print phase lags between chained joints."""
import json, math, os
from PIL import Image, ImageDraw
SP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(SP, 'c9')
data = json.load(open(os.path.join(SP, 'current_anims.json')))
SHORT = {'Fall': 'fall', 'Idle fix': 'idle', 'Idle2': 'idle2', 'Jump': 'jump', 'Run': 'run', 'Walk2': 'walk'}


def key_for(name):
    for k, v in SHORT.items():
        if k in name and not (k == 'Idle fix' and 'Idle2' in name):
            return v


def ev(keys, t):
    if t <= keys[0][0]: return keys[0][1]
    if t >= keys[-1][0]: return keys[-1][1]
    lo, hi = 0, len(keys) - 1
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if keys[mid][0] <= t: lo = mid
        else: hi = mid
    t0, v0 = keys[lo][0], keys[lo][1]; t1, v1 = keys[hi][0], keys[hi][1]
    return v0 + (v1 - v0) * ((t - t0) / (t1 - t0) if t1 > t0 else 0)


def series(joints, joint, ch, dur, n):
    keys = joints.get(joint, {}).get(ch)
    if not keys: return [0.0] * n
    s = [ev(keys, i * dur / n) for i in range(n)]
    if ch.startswith('Rot'): s = [math.degrees(v) for v in s]
    return s


def lag(a, b, dur):
    """lag (s) of b relative to a maximizing cross-correlation (circular)."""
    n = len(a); ma = sum(a) / n; mb = sum(b) / n
    a = [x - ma for x in a]; b = [x - mb for x in b]
    best = (0, -1e18)
    for sh in range(-n // 2, n // 2):
        c = sum(a[i] * b[(i + sh) % n] for i in range(n))
        if c > best[1]: best = (sh, c)
    na = math.sqrt(sum(x * x for x in a)) or 1; nb = math.sqrt(sum(x * x for x in b)) or 1
    return best[0] * dur / n, best[1] / (na * nb)


PLOT = {
    'idle': [('LowerTorso', 'Position.Y'), ('LowerTorso', 'Position.X'), ('LowerTorso', 'Rotation.Y'), ('UpperTorso', 'Rotation.Y'), ('Head', 'Rotation.Y'), ('Head', 'Rotation.Z'), ('Head', 'Rotation.X'),
             ('RightUpperArm', 'Rotation.Y'), ('RightUpperArm', 'Rotation.X'), ('RightLowerArm', 'Rotation.X'), ('RightHand', 'Rotation.X'), ('RightHand', 'Rotation.Z'),
             ('LeftUpperLeg', 'Rotation.X'), ('LeftLowerLeg', 'Rotation.X'), ('LeftFoot', 'Rotation.X'), ('LeftLowerLeg', 'Position.Y')],
    'run': [('LowerTorso', 'Position.Y'), ('LowerTorso', 'Position.Z'), ('LowerTorso', 'Rotation.Z'), ('LowerTorso', 'Rotation.X'), ('UpperTorso', 'Rotation.Y'), ('UpperTorso', 'Rotation.Z'), ('Head', 'Rotation.Y'), ('Head', 'Rotation.X'),
            ('RightUpperArm', 'Rotation.X'), ('RightUpperArm', 'Rotation.Z'), ('RightLowerArm', 'Rotation.X'), ('RightHand', 'Rotation.X'),
            ('RightUpperLeg', 'Rotation.X'), ('RightLowerLeg', 'Rotation.X'), ('RightFoot', 'Rotation.X'), ('RightUpperLeg', 'Position.Y'), ('RightUpperLeg', 'Position.Z'), ('RightLowerLeg', 'Position.Y')],
    'jump': [('LowerTorso', 'Position.Y'), ('LowerTorso', 'Position.Z'), ('LowerTorso', 'Rotation.X'), ('UpperTorso', 'Rotation.X'), ('Head', 'Rotation.X'),
             ('RightUpperArm', 'Rotation.X'), ('RightUpperArm', 'Position.Y'), ('RightLowerArm', 'Rotation.X'), ('RightHand', 'Rotation.X'),
             ('RightUpperLeg', 'Rotation.X'), ('RightLowerLeg', 'Rotation.X'), ('RightFoot', 'Rotation.X')],
    'fall': [('LowerTorso', 'Position.Y'), ('LowerTorso', 'Rotation.X'), ('UpperTorso', 'Rotation.X'), ('Head', 'Rotation.X'),
             ('RightUpperArm', 'Rotation.X'), ('RightUpperArm', 'Rotation.Y'), ('RightLowerArm', 'Rotation.X'), ('RightHand', 'Rotation.X'), ('RightHand', 'Rotation.Y'),
             ('LeftUpperLeg', 'Rotation.X'), ('RightLowerLeg', 'Rotation.X'), ('LeftFoot', 'Rotation.X')],
    'walk': [('LowerTorso', 'Position.Y'), ('LowerTorso', 'Position.Z'), ('LowerTorso', 'Rotation.X'), ('UpperTorso', 'Rotation.Y'), ('Head', 'Rotation.X'), ('Head', 'Rotation.Y'),
             ('RightUpperArm', 'Rotation.X'), ('RightUpperArm', 'Position.Z'), ('RightLowerArm', 'Rotation.X'), ('LeftHand', 'Rotation.X'),
             ('RightUpperLeg', 'Rotation.X'), ('RightLowerLeg', 'Rotation.X'), ('RightFoot', 'Rotation.X'), ('RightLowerLeg', 'Position.Y')],
}
PAIRS = [(('UpperTorso', 'Rotation.Y'), ('Head', 'Rotation.Y')), (('LowerTorso', 'Rotation.Y'), ('UpperTorso', 'Rotation.Y')),
         (('RightUpperArm', 'Rotation.X'), ('RightLowerArm', 'Rotation.X')), (('RightLowerArm', 'Rotation.X'), ('RightHand', 'Rotation.X')),
         (('UpperTorso', 'Rotation.Y'), ('RightUpperArm', 'Rotation.Y')), (('LowerTorso', 'Position.Y'), ('Head', 'Rotation.X')),
         (('LowerTorso', 'Position.Y'), ('LeftLowerLeg', 'Rotation.X')), (('RightUpperLeg', 'Rotation.X'), ('RightLowerLeg', 'Rotation.X')),
         (('RightLowerLeg', 'Rotation.X'), ('RightFoot', 'Rotation.X')), (('LowerTorso', 'Rotation.Z'), ('UpperTorso', 'Rotation.Z')),
         (('UpperTorso', 'Rotation.Z'), ('Head', 'Rotation.Z'))]

for name, joints in data.items():
    key = key_for(name)
    if key == 'idle2' or key not in PLOT: continue
    dur = max(k[-1][0] for j in joints.values() for kk in j.values() if kk for k in [kk])
    n = int(dur * 120)
    chans = PLOT[key]
    W, H = 1400, 70 * len(chans) + 30
    img = Image.new('RGB', (W, H), (24, 24, 28)); d = ImageDraw.Draw(img)
    d.text((6, 6), f'{name}  dur={dur:.3f}s   (each row: value over time; grey = zero; number = range)', fill=(230, 230, 230))
    for r, (joint, ch) in enumerate(chans):
        s = series(joints, joint, ch, dur, n)
        y0 = 30 + r * 70; lo, hi = min(s), max(s); span = max(hi - lo, 1e-6)
        d.line((120, y0 + 30, W - 10, y0 + 30), fill=(70, 70, 80))
        unit = 'deg' if ch.startswith('Rot') else 'st'
        d.text((6, y0 + 8), f'{joint}', fill=(200, 200, 255)); d.text((6, y0 + 22), f'{ch[0]}{ch[-1]} {lo:.2f}..{hi:.2f} {unit}', fill=(180, 180, 180))
        zero_y = y0 + 60 - (0 - lo) / span * 55 if lo <= 0 <= hi else None
        if zero_y: d.line((120, zero_y, W - 10, zero_y), fill=(90, 90, 100))
        pts = [(120 + i * (W - 130) / n, y0 + 60 - (s[i] - lo) / span * 55) for i in range(n)]
        col = (255, 170, 80) if ch.startswith('Rot') else (100, 220, 140)
        d.line(pts, fill=col, width=2)
        # tick every 0.25 s
        t = 0.0
        while t <= dur + 1e-6:
            x = 120 + t / dur * (W - 130); d.line((x, y0 + 60, x, y0 + 64), fill=(120, 120, 120)); t += 0.25
    path = os.path.join(OUT, f'ref_{key}.png'); img.save(path)
    print('saved', path)
    print(f'--- lags in {key} (positive = second lags first; corr)')
    for (ja, ca), (jb, cb) in PAIRS:
        a = series(joints, ja, ca, dur, n); b = series(joints, jb, cb, dur, n)
        if max(a) - min(a) < 1e-3 or max(b) - min(b) < 1e-3: continue
        lg, c = lag(a, b, dur)
        print(f'   {ja}.{ca[-1]} -> {jb}.{cb[-1]}: lag {lg:+.3f}s corr {c:+.2f}  amp {max(a)-min(a):.1f} -> {max(b)-min(b):.1f}')
