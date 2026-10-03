import random
import sys
from engine import *

sys.setrecursionlimit(100000)


class Budget(Exception):
    pass


class Solver:
    def __init__(self, lv: Level, node_budget=200000):
        self.lv = lv
        self.dead = set()
        self.nodes = 0
        self.budget = node_budget

    def solve(self, st: State):
        """Return list of stack indexes (a winning line) or None.
        Raises Budget when the node budget is exhausted."""
        lv = self.lv
        if is_win(lv, st):
            return []
        if st in self.dead:
            return None
        self.nodes += 1
        if self.nodes > self.budget:
            raise Budget()
        moves = legal_moves(lv, st)
        base = remaining_tiles(st)
        moves.sort(key=lambda m: (remaining_tiles(m[1]) - base, sum(m[1][1])))
        for i, ns in moves:
            r = self.solve(ns)
            if r is not None:
                return [i] + r
        self.dead.add(st)
        return None


def playout_win_rate(lv: Level, n=300, seed=1):
    rng = random.Random(seed)
    wins = 0
    for _ in range(n):
        st = initial_state(lv)
        while True:
            if is_win(lv, st):
                wins += 1
                break
            mv = legal_moves(lv, st)
            if not mv:
                break
            st = rng.choice(mv)[1]
    return wins / n


def trap_ratio(lv: Level, sol, budget=60000):
    """Average fraction of legal moves that are fatal along the solution."""
    sv = Solver(lv, budget)
    st = initial_state(lv)
    fracs = []
    try:
        for i in sol:
            mv = legal_moves(lv, st)
            if len(mv) > 1:
                bad = 0
                for j, ns in mv:
                    if sv.solve(ns) is None:
                        bad += 1
                fracs.append(bad / len(mv))
            st = apply_move(lv, st, i)
    except Budget:
        return None
    return sum(fracs) / len(fracs) if fracs else 0.0


def replay(lv: Level, sol):
    st = initial_state(lv)
    for i in sol:
        st = apply_move(lv, st, i)
        if st is None:
            return False
    return is_win(lv, st)
