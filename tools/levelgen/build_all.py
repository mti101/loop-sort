"""Generate, verify and write assets/levels/levels.json (200 levels)."""
import json, os, random, sys, time
from multiprocessing import Pool
from gen import *

N = 200
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "levels", "levels.json")


def work(n):
    r = build(n, max_tries=500)
    if r is None:
        return n, None
    lv, sol, wr, p = r
    assert replay(lv, sol), f"replay failed level {n}"
    tr = trap_ratio(lv, sol)
    d = to_json(n, lv, sol, wr, p, random.Random(n * 31 + 7))
    d["trap"] = None if tr is None else round(tr, 3)
    return n, d


if __name__ == "__main__":
    t = time.time()
    with Pool() as pool:
        res = dict(pool.map(work, range(1, N + 1), chunksize=2))
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
        trs = [l["trap"] for l in chunk if l["trap"] is not None]
        print(f"L{lo+1:3}-{lo+20:3} wr avg {sum(wrs)/len(wrs):.3f} min {min(wrs):.3f} max {max(wrs):.3f} trap avg {sum(trs)/max(1,len(trs)):.3f} sol avg {sum(len(l['sol']) for l in chunk)/len(chunk):.1f}")
