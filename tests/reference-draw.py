#!/usr/bin/env python3
# The independent reference implementation of the routed panel's draw (wave 26, decision D4 of the
# companions design round; wave 26b, D3: the length-prefixed seed text) - Python standard library
# only, written from the README's description, never from the PowerShell code. The golden values of
# tests/harness-companions.ps1 (DRAW, ROUTED) are what this script prints; run it after any change
# to the draw and paste its numbers into the harness:
#
#   python tests/reference-draw.py
#
# The draw:
#   seed text  every field written <len>:<value> (len = the value's UTF-8 byte count), joined by
#              '|': task | purpose | brief sha256 | lineages | nonce, where lineages = the eligible
#              lineages sorted ordinally (by UTF-16 code units, as .NET's ordinal comparer; for the
#              ASCII lineages of the harness the same as Python's sort), each <len>:<lineage>,
#              joined by ','
#   seed       SHA-256 of the seed text's UTF-8 bytes
#   slot s     SHA-256(seed || s as 4 bytes big-endian); the top 53 bits of bytes 0..7 / 2^53 pick,
#              of bytes 8..15 explore (< 0.2: a uniform pick from the slot's pool)
#   seats      pinned candidates first (rule required, roster order); the lab reserve = min(K - the
#              pinned, labs with a candidate weighing >= neutral that the pins did not seat): while
#              fewer reserve seats are taken, the pool is the candidates of labs not yet seated that
#              weigh >= neutral (lab-draw / lab-explore); else every candidate left (rank-*). The
#              weighted pick: the first candidate, in roster order, whose running weight sum
#              exceeds pick x the pool's weight sum.
#   score      0.25 + 1.75 * (yes + 0.5 partly + 2p) / (n + 4p), p = 0.5; neutral 0.25 + 1.75 * 0.5
import hashlib
import struct

NEUTRAL = 0.25 + 1.75 * 0.5
EXPLORE = 0.2


def lp(value):
    return '%d:%s' % (len(value.encode('utf-8')), value)


def seed(task, purpose, brief_sha, lineages, nonce):
    joined = ','.join(lp(x) for x in sorted(lineages, key=lambda s: s.encode('utf-16-be')))
    text = '|'.join([lp(task), lp(purpose), lp(brief_sha), lp(joined), lp(nonce)])
    return hashlib.sha256(text.encode('utf-8')).digest(), text


def uniform53(h, off):
    v = int.from_bytes(h[off:off + 8], 'big') >> 11
    return v / 9007199254740992.0


def slot_uniforms(seed_bytes, slot):
    h = hashlib.sha256(seed_bytes + struct.pack('>I', slot)).digest()
    return uniform53(h, 0), uniform53(h, 8)


def draw(cands, k, seed_bytes):
    # cands: list of (position, lab, weight, pinned) in roster order
    seats = []
    left = []
    for c in cands:
        if c[3]:
            seats.append((c, 'required'))
        else:
            left.append(c)
    good = []
    for c in cands:
        if c[2] >= NEUTRAL and c[1] not in good:
            good.append(c[1])
    pinned_labs = set(c[1] for c, _ in seats)
    reserve = min(max(0, k - len(seats)), len([l for l in good if l not in pinned_labs]))
    taken = 0
    while len(seats) < k and left:
        slot = len(seats) + 1
        seated = set(c[1] for c, _ in seats)
        pool = []
        kind = 'rank'
        if taken < reserve:
            pool = [c for c in left if c[1] not in seated and c[2] >= NEUTRAL]
            if pool:
                kind = 'lab'
        if not pool:
            pool = list(left)
            kind = 'rank'
        pick, explore = slot_uniforms(seed_bytes, slot)
        if explore < EXPLORE:
            idx = int(pick * len(pool))
            if idx >= len(pool):
                idx = len(pool) - 1
            winner = pool[idx]
            rule = kind + '-explore'
        else:
            total = 0.0
            for c in pool:
                total += c[2]
            target = pick * total
            acc = 0.0
            winner = None
            for c in pool:
                acc += c[2]
                if target < acc:
                    winner = c
                    break
            if winner is None:
                winner = pool[-1]
            rule = kind + '-draw'
        if kind == 'lab':
            taken += 1
        seats.append((winner, rule))
        left.remove(winner)
    return seats


def rate(yes, partly, n):
    p = 0.5
    w = (yes + 0.5 * partly + 2 * p) / (n + 4 * p)
    return 0.25 + 1.75 * w


def picks(seats):
    return ' '.join('%d/%s' % (c[0], r) for c, r in seats)


if __name__ == '__main__':
    s, text = seed('t', 'framing', 'abc', ['b :: y', 'a :: x', 'c :: z'], '42')
    pick, explore = slot_uniforms(s, 1)
    print('DRAW seed text   : %s' % text)
    print('DRAW seed        : %s' % s.hex())
    print('DRAW slot 1      : pick %r explore %r' % (pick, explore))
    four = [(1, 'openai', 1.125, False), (2, 'zhipu', 1.9, False), (3, 'zhipu', 0.6, False), (4, 'xiaomi', 1.5, False)]
    golden = []
    for n in range(1, 6):
        sb, _ = seed('t', 'framing', '', ['x'], str(n))
        golden.append(picks(draw(four, 3, sb)))
    print('DRAW golden      : %s' % ' ; '.join(golden))
    exp = 0
    for n in range(1, 2001):
        sb, _ = seed('t', 'x', '', ['x'], str(n))
        if slot_uniforms(sb, 1)[1] < EXPLORE:
            exp += 1
    print('DRAW explore     : %d of 2000' % exp)
    # ROUTED: the five of the harness's roster, purpose framing, task t, no brief; the ratings of
    # Routing-Ratings (ZAI 4 yes, mimo 3 no, kimi 3 yes 1 partly; openai and qwen none)
    five = [
        (1, 'openai', NEUTRAL, False, 'openai :: gpt-5.1'),
        (2, 'zhipu', rate(4.0, 0.0, 4.0), False, 'ZAI :: glm-5.3'),
        (3, 'xiaomi', rate(0.0, 0.0, 3.0), False, 'mimo :: mimo-v2.6-pro'),
        (4, 'moonshot', rate(3.0, 1.0, 4.0), False, 'byteplus :: kimi-k2.5'),
        (5, 'alibaba', NEUTRAL, False, 'alibaba :: qwen3.8-max'),
    ]
    lineages = [c[4] for c in five]
    cands = [c[:4] for c in five]
    for nonce in ('15', '18'):
        sb, _ = seed('t', 'framing', '', lineages, nonce)
        print('ROUTED nonce %-3s : seed %s picks %s' % (nonce, sb.hex()[:12], picks(draw(cands, 3, sb))))
