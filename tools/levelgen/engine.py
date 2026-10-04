"""Loop Sort v2 reference engine (mirrored by lib/game/engine.dart).

Slots hold stacks of tiles (index 0 = top, the end next to the belt).
Tapping a slot lifts its whole top same-colour run onto a looping conveyor.
Slot i sits at belt position i; the belt flows i -> i+1 -> ... -> 0.
Each belt tile drops into the first slot it passes whose top colour matches
(or that is empty) and that is not full. A full single-colour slot is complete.
Win: every tile is in a complete slot. Lose: no legal move.
"""
from dataclasses import dataclass


@dataclass(frozen=True)
class Level:
    cap: int          # belt capacity (tiles)
    C: int            # slot capacity
    slots: tuple      # tuple of tuples (top first) of colour ints
    colors: int


def complete(stack, C):
    return len(stack) == C and all(c == stack[0] for c in stack)


def initial(lv):
    return (tuple(tuple(s) for s in lv.slots), ())  # (slots, belt) belt: tuple of (colour,next)


def run_len(stack):
    if not stack:
        return 0
    c = stack[0]
    n = 1
    while n < len(stack) and stack[n] == c:
        n += 1
    return n


def accepts(stack, c, C):
    if len(stack) >= C:
        return False
    return (not stack) or stack[0] == c


def is_win(lv, st):
    slots, belt = st
    if belt:
        return False
    return all((not s) or complete(s, lv.C) for s in slots)


def legal_moves(lv, st):
    slots, belt = st
    free = lv.cap - len(belt)
    out = []
    for i, s in enumerate(slots):
        if not s or complete(s, lv.C):
            continue
        if run_len(s) <= free:
            out.append(i)
    return out


def settle(lv, slots, belt):
    """Advance the belt until no tile can drop. Returns (slots, belt, deps).
    deps: list of (index into the input belt list, slot) in drop order."""
    S = len(slots)
    slots = [list(s) for s in slots]
    belt = [[c, n, k] for k, (c, n) in enumerate(belt)]
    deps = []
    idle = 0
    while belt and idle < S:
        dropped = False
        nb = []
        for t in belt:
            c, g, k = t
            if accepts(slots[g], c, lv.C):
                slots[g].insert(0, c)
                deps.append((k, g))
                dropped = True
            else:
                t[1] = (g + 1) % S
                nb.append(t)
        belt = nb
        idle = 0 if dropped else idle + 1
    # after S idle rounds every tile is back at its original next gate
    return (tuple(tuple(s) for s in slots),
            tuple((t[0], t[1]) for t in belt), deps, [t[2] for t in belt])


def apply_move(lv, st, i):
    slots, belt = st
    S = len(slots)
    s = slots[i]
    r = run_len(s)
    run = s[:r]
    new_slots = list(slots)
    new_slots[i] = s[r:]
    nxt = (i + 1) % S
    nb = list(belt) + [(c, nxt) for c in run]
    ns, b2, deps, _ = settle(lv, new_slots, nb)
    return (ns, b2)


def key(st):
    return st


def replay(lv, moves):
    st = initial(lv)
    for m in moves:
        if m not in legal_moves(lv, st):
            return False
        st = apply_move(lv, st, m)
    return is_win(lv, st)
