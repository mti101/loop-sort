import json, random, os
from multiprocessing import Pool
from gen import *
import build_all
p=build_all.OUT
L=json.load(open(p))
bad=[l['n'] for l in L if len(l['slots'])>8]
print('regen',bad)
if __name__=='__main__':
    with Pool(2) as pool:
        for n,d in pool.imap_unordered(build_all.work,bad):
            assert d, n
            L[n-1]=d
    for l in L:
        if l['n']>5 and l['n'] in bad:
            rng=random.Random(l['n']*131+3); l['layout'],l['shape']=pick_layout(l['n'],len(l['slots']),rng)
    json.dump(L,open(p,'w'),separators=(',',':'))
    from collections import Counter
    print(Counter(len(l['slots']) for l in L))
