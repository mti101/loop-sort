import random, collections
from gen import *
for (K,C,S,cap) in [(3,4,4,7),(3,4,5,7),(4,4,5,6),(4,4,5,8),(5,4,6,6),(6,4,7,6),(7,4,8,6),(7,5,8,6)]:
    rng=random.Random(5); st=collections.Counter(); sl=[]; wrs=[]; uns=0; bud=0
    for _ in range(60):
        slots=deal(K,C,S,rng)
        if trivial(slots,C): continue
        lv=Level(cap,C,slots,K)
        try: sol=solve(lv,node_budget=20000)
        except Budget: bud+=1; continue
        if sol is None: uns+=1; continue
        sl.append(len(sol)); wrs.append(playout_win_rate(lv,60,rng))
    print((K,C,S,cap),'solv',len(sl),'unsolv',uns,'budget',bud,'sol avg',sum(sl)/max(1,len(sl)),'wr avg',sum(wrs)/max(1,len(wrs)))
