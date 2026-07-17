#!/usr/bin/env python3
"""Numeric-tolerant comparison of two AquaCrop output files.

Compares two column-formatted output files token by token. Text tokens (project
names, "Tot(1)", ...) must match exactly. Numeric tokens are allowed to differ by
at most --ulp units in their LAST PRINTED digit (default 1), which absorbs the
day-vs-GDD last-digit rounding without hiding real shifts: a genuine 1-day
phenology shift moves many values by well more than their last digit, so it still
shows up as a real difference.

Exit codes:
  0  exact match (after skipping header lines)
  1  differences, but all within the last-digit tolerance
  2  real differences (some token exceeds tolerance / text mismatch)
  3  structural mismatch (line or column count) or I/O error
"""
import argparse
import sys


def parse_num(tok):
    try:
        return float(tok)
    except ValueError:
        return None


def decimals_of(tok):
    """Digits after the decimal point in the printed token (0 for integers)."""
    t = tok.strip()
    if '.' in t and 'e' not in t.lower():
        return len(t.split('.', 1)[1])
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('ref')
    ap.add_argument('out')
    ap.add_argument('--skip', type=int, default=1,
                    help='header lines to skip in each file (default 1: timestamp)')
    ap.add_argument('--ulp', type=int, default=1,
                    help='allowed difference in the last printed digit (default 1)')
    ap.add_argument('--show', type=int, default=8,
                    help='max offending cells to print (default 8)')
    a = ap.parse_args()

    try:
        with open(a.ref) as f:
            ref = f.read().splitlines()[a.skip:]
        with open(a.out) as f:
            out = f.read().splitlines()[a.skip:]
    except OSError as e:
        print(f"  I/O error: {e}")
        sys.exit(3)

    if len(ref) != len(out):
        print(f"  line count differs: ref={len(ref)} out={len(out)}")
        sys.exit(3)

    any_diff = False
    offenders = []      # (line, col, reftok, outtok, ulp_diff|None)
    max_ulp = 0
    n_within = 0        # numeric cells that differ but stay within tolerance

    for i, (rl, ol) in enumerate(zip(ref, out), start=a.skip + 1):
        if rl == ol:
            continue
        any_diff = True
        rt, ot = rl.split(), ol.split()
        if len(rt) != len(ot):
            offenders.append((i, '-', f'{len(rt)} cols', f'{len(ot)} cols', None))
            continue
        for c, (rtok, otok) in enumerate(zip(rt, ot), start=1):
            if rtok == otok:
                continue
            rn, on = parse_num(rtok), parse_num(otok)
            if rn is None or on is None:
                offenders.append((i, c, rtok, otok, None))   # text mismatch
                continue
            d = max(decimals_of(rtok), decimals_of(otok))
            scale = 10 ** d
            ulp = abs(round(rn * scale) - round(on * scale))
            max_ulp = max(max_ulp, ulp)
            if ulp > a.ulp:
                offenders.append((i, c, rtok, otok, ulp))
            else:
                n_within += 1

    if not any_diff:
        sys.exit(0)

    if not offenders:
        # only last-digit differences
        print(f"  within tolerance: {n_within} cell(s) differ by <= {a.ulp} "
              f"ulp (max {max_ulp})")
        sys.exit(1)

    for (ln, col, rtok, otok, ulp) in offenders[:a.show]:
        extra = f'  (delta {ulp} ulp)' if ulp is not None else '  (text)'
        print(f"  line {ln} col {col}: {rtok} vs {otok}{extra}")
    if len(offenders) > a.show:
        print(f"  ... (+{len(offenders) - a.show} more cells)")
    sys.exit(2)


if __name__ == '__main__':
    main()
