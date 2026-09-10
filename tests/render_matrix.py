#!/usr/bin/env python3
"""Render tests/TESTPLAN.md into tests/matrix.html (the published Artifact page).

TESTPLAN.md is the source of truth; this only reformats it. Re-run after editing
the plan, then republish matrix.html to the same Artifact URL.
"""
import re, html, pathlib

ROOT = pathlib.Path(__file__).resolve().parent
src = (ROOT / 'TESTPLAN.md').read_text()

# ---------------------------------------------------------------- live status
# The cases directory is the truth about what exists; TESTPLAN.md only says what
# is planned. A "[x]" in the plan means "covered by the shipped testcase"; a case
# on disk with a frozen OUTP_REF means built-and-referenced.
CASES_DIR = ROOT / 'cases'
ON_DISK: dict[str, bool] = {}          # case id -> has a frozen reference
N_CASE_DIRS = N_FROZEN = 0             # counted from directories, not aliases
if CASES_DIR.is_dir():
    for d in sorted(CASES_DIR.iterdir()):
        if d.is_dir() and (d / 'case.yml').is_file():
            cid = d.name.split('_')[0]
            frozen = (d / 'OUTP_REF').is_dir()
            N_CASE_DIRS += 1
            N_FROZEN += bool(frozen)
            ON_DISK[cid] = frozen
            # several plan rows are covered by a lettered family of cases
            # (N09a/N09b for plan row N09); a row counts as built once any
            # member of its family is frozen
            base = re.match(r'^([A-Z]{1,2}\d{2})[a-z]$', cid)
            if base:
                ON_DISK[base.group(1)] = ON_DISK.get(base.group(1), False) or frozen

REF_STAMP = {}
stamp = ROOT / 'REFERENCE.txt'
if stamp.is_file():
    for line in stamp.read_text().splitlines():
        k, _, v = line.partition(' ')
        if v.strip():
            REF_STAMP[k.strip()] = v.strip()

# defects recorded in the plan, rendered as their own section
DEFECTS = re.findall(r'^### (D\d+) — (.+?)$\n\n\*(.+?)\*', src, re.M | re.S)

# the retired-cases table: | Case | Input | Defect | Revive when |
_ret = re.search(r'^## Retired cases$(.+?)(?=^## )', src, re.M | re.S)
RETIRED = re.findall(r'^\| (\S.*?) \| (.*?) \| (D\d+) \| (.*?) \|$',
                     _ret.group(1) if _ret else '', re.M)


def live_status(cid: str, planned: str) -> str:
    """Filesystem truth beats the plan.

    built   - a dedicated case exists on disk with a frozen reference
    staged  - a case exists but has not been frozen yet
    covered - no dedicated case, but the shipped Ottawa testcase exercises it
    partial - as above, partially
    todo    - nothing yet
    """
    if planned in ('invariant', 'retired', 'unreachable'):
        return planned            # not a case; the plan is authoritative
    if cid in ON_DISK:
        return 'built' if ON_DISK[cid] else 'staged'
    return {'built': 'covered'}.get(planned, planned)

PARTS = {}         # part label -> [group letters]
GROUPS, order = {}, []
cur = None
part = 'I'
PART_NAMES = {'I': 'Input & option coverage', 'II': 'Kernel coverage',
              'III': 'Version compatibility', 'IV': 'Generated sweeps'}

for line in src.splitlines():
    m = re.match(r'^# Part ([IV]+) ', line)
    if m:
        part = m.group(1)
        continue
    m = re.match(r'^### ([A-Z]{1,2})\. (.+?)\s*$', line)
    if m:
        cur = m.group(1)
        name = m.group(2)
        anchor = ''
        a = re.search(r'\(`(.+)`\)\s*⭐?\s*$', name)
        if a:
            anchor = a.group(1)
            name = name[:a.start()].strip()
        name = name.replace('⭐', '').strip()
        order.append(cur)
        GROUPS[cur] = {'letter': cur, 'name': name, 'anchor': anchor,
                       'part': part, 'rows': []}
        PARTS.setdefault(part, []).append(cur)
        continue
    if re.match(r'^\| ID \| Family \|', line):        # the sweep table
        cur = 'SW'
        order.append(cur)
        GROUPS[cur] = {'letter': 'SW', 'name': 'Generated sweep families',
                       'anchor': 'runner/make_inputs.py', 'part': 'IV', 'rows': []}
        PARTS.setdefault('IV', []).append('SW')
        continue
    m = re.match(r'^\|\s*(SW\d{2})\s*\|(.+?)\|(.+?)\|\s*(\d+)\s*\|\s*(T[0-3])\s*\|\s*\[([x~ ])\]\s*\|\s*$', line)
    if m and cur == 'SW':
        GROUPS['SW']['rows'].append({
            'id': m.group(1), 'case': m.group(2).strip(), 'ex': m.group(3).strip(),
            'tier': m.group(5), 'st': {'x': 'built', '~': 'partial', ' ': 'todo'}[m.group(6)],
            'n': int(m.group(4))})
        continue
    m = re.match(r'^\|\s*([A-Z]{1,2}\d{2}[a-z]?)\s*\|(.+?)\|(.+?)\|\s*(T[0-3])\s*\|\s*\[([x~ i—n])\]\s*\|\s*$', line)
    if m and cur and cur != 'SW':
        GROUPS[cur]['rows'].append({
            'id': m.group(1), 'case': m.group(2).strip(), 'ex': m.group(3).strip(),
            'tier': m.group(4),
            'st': live_status(m.group(1),
                              {'x': 'built', '~': 'partial', ' ': 'todo',
                               'i': 'invariant', '—': 'retired',
                               'n': 'unreachable'}[m.group(5)]),
            'n': 1})


ST_LABEL = {'built': 'built', 'partial': 'partial', 'todo': 'to do',
            'staged': 'staged', 'covered': 'covered', 'retired': 'retired',
            'invariant': 'invariant', 'unreachable': 'not reachable'}


def md(s):
    s = html.escape(s)
    s = re.sub(r'`([^`]+)`', r'<code>\1</code>', s)
    s = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', s)
    return s.replace('→', '&rarr;').replace('×', '&times;').replace('≤', '&le;').replace('≥', '&ge;')


# cases that exist on disk but predate this plan revision still count
rows_all = [r for g in GROUPS.values() for r in g['rows']]
enum = [r for g in GROUPS.values() if g['letter'] != 'SW' for r in g['rows']]
total = sum(r['n'] for r in rows_all)
built = sum(1 for r in enum if r['st'] == 'built')
staged = sum(1 for r in enum if r['st'] == 'staged')
covered = sum(1 for r in enum if r['st'] == 'covered')
unreach = sum(1 for r in enum if r['st'] == 'unreachable')
invariant = sum(1 for r in enum if r['st'] == 'invariant')
part_ = sum(1 for r in enum if r['st'] == 'partial')
frozen = N_FROZEN
todo = sum(1 for r in enum if r['st'] == 'todo')
tiers = {t: sum(r['n'] for r in rows_all if r['tier'] == t) for t in ('T0', 'T1', 'T2', 'T3')}

nav, sections, last_part = [], [], None
for L in order:
    g = GROUPS[L]
    n = sum(r['n'] for r in g['rows'])
    b = sum(1 for r in g['rows'] if r['st'] == 'built')
    p = sum(1 for r in g['rows'] if r['st'] in ('covered', 'partial'))
    if g['part'] != last_part:
        nav.append(f'<span class="navpart">{g["part"]}</span>')
        sections.append(f'<h2 class="partrule"><span>Part {g["part"]}</span>'
                        f'{html.escape(PART_NAMES[g["part"]])}</h2>')
        last_part = g['part']
    nav.append(f'<a class="navchip" href="#g{L}" data-group="{L}">'
               f'<span class="navL">{L}</span>{html.escape(g["name"])}'
               f'<span class="navN">{n}</span></a>')
    trs = []
    for r in g['rows']:
        cnt = f'<span class="mult">&times;{r["n"]}</span>' if r['n'] > 1 else ''
        trs.append(
            f'<tr data-tier="{r["tier"]}" data-st="{r["st"]}" '
            f'data-q="{html.escape((r["id"] + " " + r["case"] + " " + r["ex"]).lower(), quote=True)}">'
            f'<td class="cid">{r["id"]}</td>'
            f'<td class="ccase">{md(r["case"])}{cnt}</td>'
            f'<td class="cex">{md(r["ex"])}</td>'
            f'<td class="ctier"><span class="tier t{r["tier"][1]}">{r["tier"]}</span></td>'
            f'<td class="cst"><span class="st s-{r["st"]}">'
            f'{ST_LABEL[r["st"]]}</span></td></tr>')
    nb = sum(1 for r in g['rows'] if r['st'] in ('built', 'invariant'))
    nu = sum(1 for r in g['rows'] if r['st'] == 'unreachable')
    nc = sum(1 for r in g['rows'] if r['st'] in ('covered', 'partial'))
    pct = round(100 * (nb + 0.4 * nc) / max(len(g['rows']) - nu, 1))
    anchor = (f'<span class="ganchor"><code>{html.escape(g["anchor"])}</code></span>'
              if g['anchor'] else '')
    sections.append(f'''
<section class="group" id="g{L}" data-group="{L}">
  <header class="ghead">
    <div class="gtitle"><span class="gletter">{L}</span><h3>{html.escape(g['name'])}</h3>{anchor}</div>
    <div class="gmeter" title="{b} built, {p} partial of {len(g['rows'])}">
      <div class="bar"><i style="width:{pct}%"></i></div>
      <span class="gcount"><b class="live-n">{n}</b> cases</span>
    </div>
  </header>
  <div class="twrap"><table>
    <thead><tr><th>ID</th><th>Case</th><th>Exercises</th><th>Tier</th><th>Status</th></tr></thead>
    <tbody>{''.join(trs)}</tbody>
  </table></div>
</section>''')

out = (ROOT / 'matrix_template.html').read_text()
defect_html = ''
if DEFECTS:
    items = ''.join(
        f'<li><b>{d[0]}</b> &mdash; {html.escape(d[1])}'
        f'<span class="dmeta">{html.escape(d[2].split(".")[0])}</span></li>'
        for d in DEFECTS)
    defect_html = (f'<section class="note"><h2>Defects found by the suite</h2>'
                   f'<p>Recorded in <code>tests/TESTPLAN.md</code>. The suite carries no '
                   f'case that is known to fail &mdash; a finding is written up and its '
                   f'case removed, so a red run always means a real regression.</p>'
                   f'<ul class="defects">{items}</ul></section>')

retired_html = ''
if RETIRED:
    rows = ''.join(
        f'<tr><td class="cid">{html.escape(c)}</td><td class="ccase"><code>'
        f'{html.escape(i)}</code></td><td class="ctier">'
        f'<span class="tier t2">{d}</span></td>'
        f'<td class="cex">{md(w)}</td></tr>' for c, i, d, w in RETIRED)
    retired_html = (
        '<section class="note"><h2>Retired cases</h2>'
        '<p>Removed because they cannot pass until AquaCrop changes. Each is one '
        'line in a <code>RETIRED</code> table in its generator, so reviving one '
        'after a fix is a copy-paste. Every input they need is still generated.</p>'
        '<div class="twrap"><table><thead><tr><th>Case</th><th>Input</th>'
        '<th>Defect</th><th>Revive when</th></tr></thead><tbody>'
        f'{rows}</tbody></table></div></section>')

ref_html = ''
if REF_STAMP:
    ref_html = (f"frozen {REF_STAMP.get('frozen', '?')} &middot; "
                f"binary sha {REF_STAMP.get('sha256', '?')} &middot; "
                f"commit {REF_STAMP.get('commit', '?')[:12]}")

for k, v in {'NAV': '\n'.join(nav), 'SECTIONS': '\n'.join(sections),
             'TOTAL': total, 'BUILT': built, 'PARTIAL': part_, 'TODO': todo,
             'STAGED': staged, 'FROZEN': frozen, 'COVERED': covered,
             'INVARIANT': invariant, 'UNREACH': unreach,
             'DEFECTS': defect_html + retired_html, 'REFSTAMP': ref_html,
             'RETIREDCOUNT': len(RETIRED),
             'DEFECTCOUNT': len(DEFECTS),
             'ENUM': len(enum), 'GEN': total - len(enum),
             'T0': tiers['T0'], 'T1': tiers['T1'],
             'T2': tiers['T2'], 'T3': tiers['T3']}.items():
    out = out.replace('{{%s}}' % k, str(v))
(ROOT / 'matrix.html').write_text(out)
print(f'total={total} enumerated={len(enum)} generated={total-len(enum)} '
      f'built={built} invariant={invariant} staged={staged} covered={covered} '
      f'partial={part_} unreachable={unreach} todo={todo} '
      f'frozen-refs={frozen} defects={len(DEFECTS)} '
      f'retired={len(RETIRED)} groups={len(order)}')
