import random
from gen import *
def find(K,C,S,cap,seed,minsol,wrmax,mincomp=True,tries=3000):
    rng=random.Random(seed)
    for _ in range(tries):
        slots=deal(K,C,S,rng)
        if trivial(slots,C): continue
        lv=Level(cap,C,slots,K)
        try: sol=solve(lv,node_budget=20000)
        except Budget: continue
        if not sol or len(sol)<minsol: continue
        wr=playout_win_rate(lv,200,rng)
        if wr<=wrmax: return slots,sol,wr
for args in [(3,4,4,7,1,5,0.7),(3,4,4,8,2,6,0.5),(4,4,5,8,3,7,0.6)]:
    print(args, find(*args))
