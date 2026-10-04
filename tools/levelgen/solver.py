import random, sys
from engine import *

sys.setrecursionlimit(10000)


class Budget(Exception):
    pass


def solve(lv, st=None, node_budget=200000):
    """DFS with memo. Returns move list or None (proved unsolvable) ; raises Budget."""
    if st is None:
        st = initial(lv)
    seen = set()
    nodes = [0]

    def h(st):
        slots, belt = st
        # fewer incomplete slots first
        return sum(1 for s in slots if s and not complete(s, lv.C)) + len(belt)

    def dfs(st):
        if is_win(lv, st):
            return []
        if st in seen:
            return None
        seen.add(st)
        nodes[0] += 1
        if nodes[0] > node_budget:
            raise Budget()
        cand = []
        for m in legal_moves(lv, st):
            ns = apply_move(lv, st, m)
            if ns == st or ns in seen:
                continue
            cand.append((h(ns), m, ns))
        cand.sort(key=lambda x: x[0])
        for _, m, ns in cand:
            r = dfs(ns)
            if r is not None:
                return [m] + r
        return None

    return dfs(st)


def bfs_shortest(lv, st=None, node_budget=300000):
    """Shortest solution length via BFS (for star targets). None if budget exceeded."""
    from collections import deque
    if st is None:
        st = initial(lv)
    if is_win(lv, st):
        return []
    q = deque([(st, [])])
    seen = {st}
    while q:
        cur, path = q.popleft()
        for m in legal_moves(lv, cur):
            ns = apply_move(lv, cur, m)
            if ns in seen:
                continue
            if is_win(lv, ns):
                return path + [m]
            seen.add(ns)
            if len(seen) > node_budget:
                return None
            q.append((ns, path + [m]))
    return None


def playout_win_rate(lv, n=300, rng=None):
    rng = rng or random.Random(1)
    wins = 0
    for _ in range(n):
        st = initial(lv)
        for _ in range(60):
            if is_win(lv, st):
                wins += 1
                break
            lm = legal_moves(lv, st)
            if not lm:
                break
            st = apply_move(lv, st, rng.choice(lm))
    return wins / n
