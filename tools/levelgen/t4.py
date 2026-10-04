import random
from gen import *
def search(K,C,S,cap,seed,lo,hi):
    rng=random.Random(seed)
    for _ in range(4000):
        slots=deal(K,C,S,rng)
        if trivial(slots,C): continue
        # at least 3 non-empty slots, top colors vary
        lv=Level(cap,C,slots,K)
        b=bfs_shortest(lv,node_budget=60000)
        if b is None or not (lo<=len(b)<=hi): continue
        return slots,b
print('L3',search(3,4,4,7,11,4,5))
print('L5',search(3,4,4,9,12,6,8))
