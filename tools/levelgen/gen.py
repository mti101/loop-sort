import random, json
from engine import *
from solver import *

LAYOUT_RANGE = {          # layout -> (min slots, max slots)
    'bar': (2, 6), 'ring': (3, 7), 'rows': (2, 5), 'split': (4, 8), 'dual': (4, 8),
}
SHAPES = ['round', 'oct', 'bump', 'pill']


L3 = [[1, 1, 0, 1], [0], [2, 2, 2], [0, 0, 1, 2]]
L5 = [[2, 2, 0], [1, 2, 0, 0], [0, 1, 2], [1, 1]]


def is_boss(n):
    return (n % 10 == 0 and n >= 20) or n % 25 == 0


def is_breather(n):
    return n % 10 == 5 and n > 10


def profile(n):
    """Difficulty profile for level n (1-based)."""
    boss = is_boss(n); br = is_breather(n)
    if n < 20: K = 3
    elif n < 50: K = 4
    elif n < 90: K = 5
    elif n < 140: K = 6
    else: K = 7
    if n >= 50 and n % 4 == 1 and not br: K = max(3, K - 1)    # easier variety
    if boss: K = min(7, K + 1)
    if br: K = max(3, K - 1)
    C = 4
    if n >= 60 and n % 3 == 0 and K <= 6: C = 5
    if n >= 150 and n % 2 == 0 and K <= 6: C = 5
    if n < 35: E = 2
    elif n < 100: E = 1 if n % 3 == 0 else 2
    else: E = 1 if n % 4 else 2
    if br: E = 2
    if boss: E = 1
    cap = {3: 9, 4: 8, 5: 7, 6: 7, 7: 6}[K] + (1 if C == 5 else 0)
    if br: cap += 2
    if boss: cap -= 1
    cap = max(C + 1, cap)
    t = min(1.0, (n - 1) / 199)
    mys = 0.0 if n < 22 else min(0.45, 0.06 + t * 0.4)
    if br: mys *= 0.4
    wr = max(0.05, 0.95 - t * 0.9)
    if boss: wr *= 0.6
    if br: wr = min(0.98, wr * 1.5 + 0.1)
    return dict(K=K, C=C, E=E, cap=cap, mys=mys, wr=wr, boss=boss, br=br)


def pick_layout(n, S, rng):
    opts = [k for k, (lo, hi) in LAYOUT_RANGE.items() if lo <= S <= hi]
    if n <= 12:
        pref = {2: 'bar', 3: 'ring', 4: 'ring'}.get(S)
        if pref in opts: return pref, rng.choice(SHAPES)
    w = {'bar': 3, 'ring': 4, 'rows': 3, 'split': 3, 'dual': 2}
    return rng.choices(opts, [w[o] for o in opts])[0], rng.choice(SHAPES)


def deal(K, C, S, rng, max_fill=None):
    tiles = [c for c in range(K) for _ in range(C)]
    rng.shuffle(tiles)
    sizes = [0] * S
    left = K * C
    # random sizes: pick slot with remaining room
    while left > 0:
        i = rng.randrange(S)
        if sizes[i] < C:
            sizes[i] += 1; left -= 1
    slots = []
    p = 0
    for sz in sizes:
        slots.append(tuple(tiles[p:p + sz])); p += sz
    return tuple(slots)


def trivial(slots, C):
    return any(complete(s, C) for s in slots)


def metrics(lv, rng):
    try:
        sol = solve(lv, node_budget=60000)
    except Budget:
        return None
    if sol is None:
        return None
    return sol


def build(n, rng=None, max_tries=160):
    rng = rng or random.Random(n * 7919 + 13)
    p = profile(n)
    K, C = p['K'], p['C']
    best = None
    for _ in range(max_tries):
        S = min(8, K + p['E'])
        slots = deal(K, C, S, rng)
        if trivial(slots, C):
            continue
        cap = p['cap']
        lv = Level(cap, C, slots, K)
        sol = metrics(lv, rng)
        if sol is None:
            continue
        wr = playout_win_rate(lv, 150, rng)
        # accept inside the band (looser on retries)
        lo, hi = p['wr'] * 0.45, min(1.0, p['wr'] * 1.8 + 0.04)
        if len(sol) < 2:
            continue
        score = abs(wr - p['wr'])
        if best is None or score < best[0]:
            best = (score, lv, sol, wr)
        if lo <= wr <= hi and len(sol) >= max(2, K):
            best = (score, lv, sol, wr)
            break
    if best is None:
        return None
    _, lv, sol, wr = best
    return lv, sol, wr, p


def mystery_flags(lv, frac, rng):
    out = []
    for s in lv.slots:
        fl = []
        for k in range(len(s)):
            fl.append(1 if (k >= 1 and rng.random() < frac) else 0)
        out.append(fl)
    return out


def handcrafted(n):
    """Tutorial levels, mirroring the pacing of the reference video."""
    R, B, G, Y = 0, 1, 2, 3
    if n == 1:
        return dict(layout='bar', shape='round', C=4, cap=4, slots=[[Y, Y], [Y, Y]])
    if n == 2:
        return dict(layout='ring', shape='oct', C=4, cap=8, slots=[[R, R], [B, B], [R, R, B, B]])
    if n == 3:
        return dict(layout='ring', shape='bump', C=4, cap=7, slots=L3)
    if n == 4:
        return dict(layout='rows', shape='round', C=4, cap=7,
                    slots=[[Y, Y, R, R], [R, B, B, Y], [R, Y, B, B]])
    if n == 5:
        return dict(layout='split', shape='tear', C=4, cap=9, slots=L5)
    return None


def to_json(n, lv, sol, wr, p, layout, shape, mys):
    tag = 'boss' if p['boss'] else ('breather' if p['br'] else '')
    return dict(n=n, layout=layout, shape=shape, C=lv.C, cap=lv.cap, K=lv.colors,
                slots=[list(s) for s in lv.slots], mys=mys, sol=sol, wr=round(wr, 3), tag=tag)
