import time, random
from gen import *
for n in (1,2,3,4,5):
    h=handcrafted(n); K=len({c for s in h['slots'] for c in s})
    lv=Level(h['cap'],h['C'],tuple(tuple(s) for s in h['slots']),K)
    t=time.time(); s=solve(lv); print(n,K,s, round(time.time()-t,2), 'tot',sum(len(x) for x in h['slots']))
for n in (6,12,24,40,80,120,160,200):
    t=time.time(); r=build(n)
    if r is None: print(n,'FAIL'); continue
    lv,sol,wr,p=r
    print(n,'K',lv.colors,'S',len(lv.slots),'C',lv.C,'cap',lv.cap,'sol',len(sol),'wr',round(wr,2),'t',round(time.time()-t,1))
