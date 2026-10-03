import json
import random
import sys
import time
from engine import *
from solver import *


def make_level(rng, K, S, depth, cap, slots, sizes, nlocks, run_bias):
    """Random level; returns Level (not yet validated)."""
    total_target = S * depth
    orders, total = [], 0
    per_color = [0] * K
    while total < total_target:
        # pick colour with fewest tiles so far (keeps colours balanced), random tie
        mn = min(per_color)
        cands = [c for c in range(K) if per_color[c] <= mn + 3]
        c = rng.choice(cands)
        need = rng.choice(sizes)
        orders.append((c, need))
        per_color[c] += need
        total += need
    rng.shuffle(orders)
    tiles = []
    for c in range(K):
        tiles += [c] * per_color[c]
    rng.shuffle(tiles)
    # run bias: pull same-colour tiles together
    if run_bias > 0:
        for idx in range(1, len(tiles)):
            if rng.random() < run_bias:
                # find a later tile with same colour as previous and swap next to it
                prev = tiles[idx - 1]
                for k in range(idx, len(tiles)):
                    if tiles[k] == prev:
                        tiles[idx], tiles[k] = tiles[k], tiles[idx]
                        break
    n = len(tiles)
    base, extra = divmod(n, S)
    sizes_s = [base + (1 if i < extra else 0) for i in range(S)]
    stacks, p = [], 0
    for sz in sizes_s:
        stacks.append(tiles[p:p + sz])
        p += sz
    locks = [0] * S
    if nlocks:
        idxs = rng.sample(range(S), nlocks)
        no = len(orders)
        for k, i in enumerate(idxs):
            locks[i] = max(1, int(no * (0.15 + 0.5 * (k + 1) / (nlocks + 1)) + rng.randint(-1, 1)))
    return Level(K, cap, slots, stacks, locks, orders)


def profile(n):
    """Difficulty parameters for level n (1-based)."""
    # (K, S, depth, cap, slots, sizes, nlocks, run_bias, mystery_p, band(lo,hi))
    boss = (n % 10 == 0 and n >= 20) or (n % 25 == 0)
    breather = (n % 10 == 5 and n > 10)
    if n <= 3:
        p = dict(K=3, S=3, depth=4, cap=8, slots=2, sizes=[2, 3], nlocks=0, run=0.5, myst=0.0, band=(0.55, 1.0))
    elif n <= 10:
        p = dict(K=3, S=4, depth=4, cap=7, slots=2, sizes=[2, 3], nlocks=0, run=0.35, myst=0.0, band=(0.40, 0.95))
    elif n <= 25:
        p = dict(K=4, S=4, depth=5, cap=7, slots=3, sizes=[2, 3, 4], nlocks=0, run=0.3, myst=0.15 if n > 14 else 0.0, band=(0.25, 0.8))
    elif n <= 50:
        p = dict(K=5, S=5, depth=5, cap=6, slots=3, sizes=[2, 3, 4], nlocks=1 if n > 35 else 0, run=0.25, myst=0.25, band=(0.12, 0.6))
    elif n <= 90:
        p = dict(K=5, S=5, depth=6, cap=6, slots=3, sizes=[3, 4], nlocks=1 + (n > 70), run=0.2, myst=0.35, band=(0.06, 0.4))
    elif n <= 140:
        p = dict(K=6, S=6, depth=6, cap=6, slots=3, sizes=[3, 4], nlocks=2, run=0.2, myst=0.45, band=(0.03, 0.25))
    else:
        p = dict(K=6, S=6, depth=7, cap=5 if n % 3 else 6, slots=3, sizes=[3, 4, 5], nlocks=2 + (n > 175), run=0.15, myst=0.5, band=(0.015, 0.15))
    if boss:
        p['band'] = (p['band'][0] * 0.3, p['band'][1] * 0.5)
    if breather:
        p['band'] = (min(0.9, p['band'][0] * 2), 1.0)
    p['boss'] = boss
    p['breather'] = breather
    return p


def min_trap(n):
    if n <= 10:
        return 0.0
    if n <= 30:
        return 0.04
    return 0.08


def build(n, seed_base=1000, max_tries=1500, verbose=False):
    p = profile(n)
    rng = random.Random(seed_base + n * 7919)
    best, best_key = None, None
    lo, hi = p['band']
    for t in range(max_tries):
        lv = make_level(rng, p['K'], p['S'], p['depth'], p['cap'], p['slots'], p['sizes'], p['nlocks'], p['run'])
        sv = Solver(lv, 120000)
        try:
            sol = sv.solve(initial_state(lv))
        except Budget:
            continue
        if sol is None:
            continue
        wr = playout_win_rate(lv, 200, seed=n)
        gap = 0 if lo <= wr <= hi else min(abs(wr - lo), abs(wr - hi))
        tr = None
        if gap == 0:
            tr = trap_ratio(lv, sol)
            tpen = 0 if (tr is None or tr >= min_trap(n)) else (min_trap(n) - tr)
        else:
            tpen = 1
        key = (round(gap, 3) + tpen, -(tr or 0))
        if best_key is None or key < best_key:
            best, best_key = (lv, sol, wr), key
        if gap == 0 and tpen == 0:
            break
    if best is None:
        return None
    lv, sol, wr = best
    return lv, sol, wr, p


def to_json(n, lv, sol, wr, p, rng):
    stacks = []
    for i, s in enumerate(lv.stacks):
        m = [0] + [1 if rng.random() < p['myst'] else 0 for _ in s[1:]]
        stacks.append({"t": s, "m": m, "lock": lv.locks[i]})
    return {
        "id": n, "colors": lv.colors, "cap": lv.cap, "slots": lv.slots,
        "stacks": stacks, "orders": [list(o) for o in lv.orders],
        "sol": sol, "wr": round(wr, 3),
        "tag": "boss" if p['boss'] else ("breather" if p['breather'] else ""),
    }


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "probe":
        for n in [1, 5, 12, 30, 60, 100, 160, 200]:
            t = time.time()
            r = build(n, max_tries=60)
            if r is None:
                print(n, "FAILED", round(time.time() - t, 1))
                continue
            lv, sol, wr, p = r
            print(n, "wr", round(wr, 3), "band", p['band'], "len", len(sol), "tiles", sum(len(s) for s in lv.stacks), "orders", len(lv.orders), "t", round(time.time() - t, 1))
