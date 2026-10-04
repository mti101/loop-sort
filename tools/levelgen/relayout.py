import json, random, os
from gen import pick_layout
p=os.path.join(os.path.dirname(__file__),'..','..','assets','levels','levels.json')
L=json.load(open(p))
for l in L:
    if l['n']<=5: continue
    rng=random.Random(l['n']*131+3)
    l['layout'],l['shape']=pick_layout(l['n'],len(l['slots']),rng)
json.dump(L,open(p,'w'),separators=(',',':'))
from collections import Counter
print(Counter(l['layout'] for l in L), Counter(l['shape'] for l in L))
