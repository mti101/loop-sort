"""Loop Sort puzzle engine (reference implementation).

The Dart engine in lib/game/engine.dart MUST mirror this file exactly.
Levels ship with a stored solution which a Dart unit test replays, so any
divergence between the two engines is caught in CI.

Rules
-----
* Stacks hold tiles (colour ints). Index 0 is the FRONT (the tappable end).
* Tapping an unlocked stack sends its whole front run (maximal prefix of the
  same colour) towards the loop, one tile at a time.
* A tile is delivered straight into the first ACTIVE order of its colour that
  still needs tiles. Otherwise it rides the loop.
* A completed order is replaced by the next order in the queue; loop tiles
  are then re-absorbed by the active orders (cascading).
* After the move the loop must hold <= cap tiles, otherwise the move is
  illegal ("loop full").
* A stack with lock=n stays locked until n orders have been completed.
* Win = all orders completed. Lose = no legal move.
"""
from dataclasses import dataclass
from typing import List, Optional, Tuple

State = Tuple[tuple, tuple, tuple, int, int]  # stacks, loop, active, qi, done


@dataclass
class Level:
    colors: int
    cap: int
    slots: int
    stacks: List[List[int]]
    locks: List[int]
    orders: List[Tuple[int, int]]


def initial_state(lv: Level) -> State:
    n = min(lv.slots, len(lv.orders))
    active = tuple(lv.orders[:n])
    return (
        tuple(tuple(s) for s in lv.stacks),
        tuple([0] * lv.colors),
        active,
        n,
        0,
    )


def is_win(lv: Level, st: State) -> bool:
    return st[4] == len(lv.orders)


def _settle(lv: Level, loop: list, active: list, qi: int, done: int):
    changed = True
    while changed:
        changed = False
        for j in range(len(active)):
            a = active[j]
            if a is None:
                continue
            c, need = a
            if loop[c] > 0:
                take = min(loop[c], need)
                loop[c] -= take
                need -= take
                active[j] = (c, need)
                changed = True
                if need == 0:
                    done += 1
                    if qi < len(lv.orders):
                        active[j] = lv.orders[qi]
                        qi += 1
                    else:
                        active[j] = None
    return qi, done


def front_run(stack: tuple) -> int:
    if not stack:
        return 0
    c = stack[0]
    n = 1
    while n < len(stack) and stack[n] == c:
        n += 1
    return n


def apply_move(lv: Level, st: State, i: int) -> Optional[State]:
    stacks, loop_t, active_t, qi, done = st
    s = stacks[i]
    if not s or done < lv.locks[i]:
        return None
    c = s[0]
    n = front_run(s)
    loop = list(loop_t)
    active = list(active_t)
    for _ in range(n):
        delivered = False
        for j in range(len(active)):
            a = active[j]
            if a is not None and a[0] == c and a[1] > 0:
                need = a[1] - 1
                active[j] = (c, need)
                delivered = True
                if need == 0:
                    done += 1
                    if qi < len(lv.orders):
                        active[j] = lv.orders[qi]
                        qi += 1
                    else:
                        active[j] = None
                    qi, done = _settle(lv, loop, active, qi, done)
                break
        if not delivered:
            loop[c] += 1
    if sum(loop) > lv.cap:
        return None
    new_stacks = stacks[:i] + (s[n:],) + stacks[i + 1:]
    # normalise: drop finished slots (None) to the end, keep order
    return (new_stacks, tuple(loop), tuple(active), qi, done)


def legal_moves(lv: Level, st: State):
    out = []
    for i in range(len(st[0])):
        ns = apply_move(lv, st, i)
        if ns is not None:
            out.append((i, ns))
    return out


def remaining_tiles(st: State) -> int:
    return sum(len(s) for s in st[0])
