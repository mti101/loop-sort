"""Generate, verify and write assets/levels/levels.json (200 levels)."""
import json, os, random, sys, time
from multiprocessing import Pool
from gen import *

N = 200
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "levels", "levels.json")


def work(n):
    h = handcrafted(n)
    if h:
        K = len({c for s in h['slots'] for c in s})
        lv = Level(h['cap'], h['C'], tuple(tuple(s) for s in h['slots']), K)
        sol = bfs_shortest(lv)
        p = dict(boss=False, br=False)
        d = to_json(n, lv, sol, 1.0, p, h['layout'], h['shape'], [[0] * len(s) for s in h['slots']])
        d['par'] = len(sol)
        return n, d
    r = build(n)
    if r is None:
        return n, None
    lv, sol, wr, p = r
    assert replay(lv, sol), f"replay failed level {n}"
    rng = random.Random(n * 31 + 7)
    layout, shape = pick_layout(n, len(lv.slots), rng)
    mys = mystery_flags(lv, p['mys'], rng)
    par = bfs_shortest(lv, node_budget=120000)
    d = to_json(n, lv, sol, wr, p, layout, shape, mys)
    d['par'] = len(par) if par else max(2, int(len(sol) * 0.75))
    return n, d


if __name__ == "__main__":
    t = time.time()
    with Pool(2) as pool:
        res = {}
        for n, d in pool.imap_unordered(work, range(1, N + 1)):
            res[n] = d
            if len(res) % 10 == 0:
                print('progress', len(res), round(time.time() - t), flush=True)
    bad = [n for n, d in res.items() if d is None]
    if bad:
        print("FAILED levels:", bad)
        sys.exit(1)
    levels = [res[n] for n in range(1, N + 1)]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(levels, f, separators=(",", ":"))
    print("wrote", len(levels), "levels in", round(time.time() - t, 1), "s")
    for lo in range(0, N, 20):
        chunk = levels[lo:lo + 20]
        wrs = [l["wr"] for l in chunk]
        print(f"L{lo+1:3}-{lo+20:3} wr avg {sum(wrs)/len(wrs):.2f} par avg {sum(l['par'] for l in chunk)/len(chunk):.1f} K {min(l['K'] for l in chunk)}-{max(l['K'] for l in chunk)} cap {min(l['cap'] for l in chunk)}-{max(l['cap'] for l in chunk)}")
