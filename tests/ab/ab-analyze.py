# Wave 29c (E8) analysis: pairs from one task ledger; credits per plan's published formula.
#   python -X utf8 -I ab-analyze.py <sessions.json> zai|mimo [ratings.json]
import json, statistics, sys

def credits(plan, u):
    inp = int(u.get('input_tokens') or 0); cached = int(u.get('cached_input_tokens') or 0)
    create = int(u.get('cache_creation_input_tokens') or 0); out = int(u.get('output_tokens') or 0)
    miss = max(inp - cached, 0)  # cache creation counts as a miss (conservative)
    if plan == 'zai':   # GLM-5.3: 6.9 input, 1.7 cached, 24 output per 10,000 tokens
        return (miss * 6.9 + cached * 1.7 + out * 24) / 10000.0
    if plan == 'mimo':  # MiMo: 300 per miss token, 2.5 per cache-hit token, 600 per output token (handoff 10/12)
        return miss * 300 + cached * 2.5 + out * 600
    raise SystemExit('plan?')

def main():
    path, plan = sys.argv[1], sys.argv[2]
    ratings = {}
    if len(sys.argv) > 3:
        ratings = json.load(open(sys.argv[3], encoding='utf-8'))  # {"01-codex": 2, ...} blind marks
    d = json.load(open(path, encoding='utf-8'))
    arms = {}
    for c in d['codex']['consults']:
        if not isinstance(c, dict): continue
        name = str(c.get('reply') or '')
        import re
        m = re.search(r'ab-(\d\d)-(codex|claude)', name)
        if not m: continue
        key = (m.group(1), m.group(2))
        usable = str(c.get('bridge_outcome') or '').startswith('usable reply')
        rec = {'usable': usable, 'wall': c.get('wall_seconds'), 'structured': bool(c.get('structured')),
               'format_retry': c.get('format_retry'), 'usage': c.get('usage') or {},
               'credits': credits(plan, c.get('usage') or {}) if usable else None, 'n': c.get('n'),
               'outcome': c.get('bridge_outcome')}
        # the last entry of an arm wins (retries)
        arms[key] = rec
    pairs = sorted({k[0] for k in arms})
    rows = []
    for p in pairs:
        a, b = arms.get((p, 'codex')), arms.get((p, 'claude'))
        if not a or not b: continue
        rows.append((p, a, b))
    print(f'plan {plan}: {len(rows)} complete pairs of {len(pairs)}')
    print('pair  codex: usable struct wall credits | claude: usable struct wall credits | ratio credits wall')
    cr, wr = [], []
    sc = sa = 0; uc = ua = 0
    for p, a, b in rows:
        rc = (b['credits'] / a['credits']) if (a['credits'] and b['credits']) else None
        rw = (b['wall'] / a['wall']) if (a['wall'] and b['wall']) else None
        if rc: cr.append(rc)
        if rw: wr.append(rw)
        uc += a['usable']; ua += b['usable']; sc += a['structured']; sa += b['structured']
        print(f"{p}  {int(a['usable'])} {int(a['structured'])} {a['wall']} {a['credits'] and round(a['credits'])} | "
              f"{int(b['usable'])} {int(b['structured'])} {b['wall']} {b['credits'] and round(b['credits'])} | "
              f"{rc and round(rc, 2)} {rw and round(rw, 2)}")
    n = len(rows)
    if n:
        mc = statistics.median(cr) if cr else None; mw = statistics.median(wr) if wr else None
        print(f'usable: codex {uc}/{n} claude {ua}/{n}; structured first turn: codex {sc}/{n} claude {sa}/{n}')
        print(f'median credits ratio claude/codex: {mc and round(mc, 3)} (gate <= 0.8); median wall ratio: {mw and round(mw, 3)} (gate <= 1.25)')
        if ratings:
            rcx = [ratings.get(f'{p}-codex') for p, _, _ in rows]; rcl = [ratings.get(f'{p}-claude') for p, _, _ in rows]
            rcx = [x for x in rcx if x is not None]; rcl = [x for x in rcl if x is not None]
            if rcx and rcl: print(f'blind marks mean: codex {statistics.mean(rcx):.2f} claude {statistics.mean(rcl):.2f} (gate: not worse)')
        gates = []
        gates.append(('credits <= 0.8x', mc is not None and mc <= 0.8))
        gates.append(('structured rate not lower', sa >= sc))
        gates.append(('wall <= 1.25x', mw is not None and mw <= 1.25))
        print('gates:', ', '.join(f'{g} {"PASS" if ok else "FAIL"}' for g, ok in gates))

main()
