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
            # a case that must stop with a message has no reference by design
            frozen = ((d / 'OUTP_REF').is_dir()
                      or 'expect_error:' in (d / 'case.yml').read_text())
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
DEFECTS = re.findall(r'^### (BUG-\d+) — (.+?)$\n\n\*(.+?)\*', src, re.M | re.S)

# the retired-cases table: | Case | Input | Defect | Revive when |
_ret = re.search(r'^## Retired cases$(.+?)(?=^## )', src, re.M | re.S)
RETIRED = re.findall(r'^\| (\S.*?) \| (.*?) \| (BUG-\d+) \| (.*?) \|$',
                     _ret.group(1) if _ret else '', re.M)


# every case id named in the retired table, expanded from "D02, D08" and
# "F54a-F54d" into the individual ids, mapped to the defect holding it up
BLOCKED: dict[str, str] = {}
for _cases, _inp, _bug, _when in RETIRED:
    for _part in re.split(r',\s*', _cases):
        _part = _part.strip().strip('`')
        _m = re.match(r'^([A-Z]{1,2})(\d{2})([a-z])?[–-]([A-Z]{1,2})?(\d{2})?([a-z])?$',
                      _part)
        if _m and _m.group(3) and _m.group(6):          # F54a-F54d
            for _c in range(ord(_m.group(3)), ord(_m.group(6)) + 1):
                BLOCKED[f'{_m.group(1)}{_m.group(2)}{chr(_c)}'] = _bug
            BLOCKED[f'{_m.group(1)}{_m.group(2)}'] = _bug
        elif _part:
            BLOCKED[_part] = _bug
            _b = re.match(r'^([A-Z]{1,2}\d{2})[a-z]$', _part)
            if _b:
                BLOCKED.setdefault(_b.group(1), _bug)

# defects fixed on the fix branch: | BUG-n | what changed |
_fix = re.search(r'^## Fixed on the fix branch$(.+?)(?=^## )', src, re.M | re.S)
FIXED = dict(re.findall(r'^\| (BUG-\d+) \| (.+?) \|$',
                        _fix.group(1) if _fix else '', re.M))

#: observations: recorded behaviour that is not a defect to fix
OBS = []
for _m in re.finditer(r'^#{2,3} (O\d+) — (.+?)$\n\n\*?(.*?)\*?\n\n(.+?)(?=\n\n)',
                      src, re.M | re.S):
    _body = re.sub(r'\s+', ' ', _m.group(4)).strip()
    if len(_body) > 340:                       # cut on a word, not mid-token
        _body = _body[:340].rsplit(' ', 1)[0]
        if _body.count('**') % 2:              # never leave a bold half-open
            _body = _body[:_body.rfind('**')].rstrip()
        if _body.count('`') % 2:
            _body = _body[:_body.rfind('`')].rstrip()
        _body += '…'
    OBS.append({'id': _m.group(1), 'title': _m.group(2),
                'meta': _m.group(3).strip(),
                'body': _body,
                'retracted': 'RETRACTED' in _m.group(2).upper()})
OBS.sort(key=lambda o: int(o['id'][1:]))


def severity_of(meta: str, title: str) -> tuple[str, str]:
    """(class, plain word) for a defect, from its recorded severity line."""
    # whole words only: "the model c-hang-es" is not a hang, and "be-low" is
    # not a low severity. Read the recorded Severity: clause first, since the
    # title often names the symptom of a defect whose severity is elsewhere.
    t = (meta + ' ' + title).lower()

    def has(*words):
        return any(re.search(r'\b' + w + r'\b', t) for w in words)

    if has('harness'):
        return 'harness', 'test code'
    if has('cosmetic'):
        return 'low', 'minor'
    if has('hangs?', 'hanging', 'infinite'):
        return 'crit', 'hangs'
    if has('segfaults?', 'crash(es|ed)?', 'aborts?'):
        return 'crit', 'crashes'
    if has('undefined') or 'out-of-bounds' in t or has('out of bounds'):
        return 'high', 'undefined'
    if has('floating-point', 'sigfpe', 'exceptions?'):
        return 'high', 'arithmetic'
    if re.search(r'severity:\s*low\b', t):
        return 'low', 'minor'
    return 'med', 'wrong output'


def live_status(cid: str, planned: str) -> str:
    """Filesystem truth beats the plan.

    built   - a dedicated case exists on disk with a frozen reference
    staged  - a case exists but has not been frozen yet
    covered - no dedicated case, but the shipped Ottawa testcase exercises it
    partial - as above, partially
    todo    - nothing yet
    """
    if planned in ('invariant', 'unreachable'):
        return planned            # not a case; the plan is authoritative
    if planned == 'retired' or (planned == 'todo' and cid in BLOCKED):
        return 'blocked'          # a defect is in the way; the plan says which
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
            'bug': BLOCKED.get(m.group(1), ''),
            'n': 1})


#: the six states a plan row can be in, in the words the page uses. Every row
#: is in exactly one, and no two mean anything close to the same thing.
ST_LABEL = {'built': 'Tested', 'partial': 'Partly tested',
            'covered': 'Covered elsewhere', 'invariant': 'Checked by rule',
            'blocked': 'Blocked', 'unreachable': 'Not testable',
            'todo': 'Not written', 'staged': 'Awaiting freeze'}

ST_HELP = {
    'built': 'A test case of its own. Its output is frozen and compared on every run.',
    'partial': 'A case exists, but it covers only part of what this row describes.',
    'covered': 'No case of its own — another case already exercises this exact path.',
    'invariant': 'No case of its own — a rule in group Z checks it on every run instead.',
    'blocked': 'Cannot pass until a defect is fixed. The bug is named on the row.',
    'unreachable': 'No input file can reach it — the value is fixed in the source.',
    'todo': 'Still to write. Nothing is stopping it.',
    'staged': 'The case exists but has no stored output yet. Run freeze.py.',
}


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
blocked = sum(1 for r in enum if r['st'] == 'blocked')
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
            f'data-q="{html.escape((r["id"] + " " + r["case"] + " " + r["ex"] + " " + r.get("bug", "")).lower(), quote=True)}">'
            f'<td class="cid">{r["id"]}</td>'
            f'<td class="ccase">{md(r["case"])}{cnt}</td>'
            f'<td class="cex">{md(r["ex"])}</td>'
            f'<td class="ctier"><span class="tier t{r["tier"][1]}">{r["tier"]}</span></td>'
            f'<td class="cst"><span class="st s-{r["st"]}" '
            f'title="{html.escape(ST_HELP[r["st"]], quote=True)}">'
            f'{ST_LABEL[r["st"]]}</span>'
            + (f'<span class="bugref">{r["bug"]}</span>'
               if r.get('bug') else '')
            + '</td></tr>')
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

# ------------------------------------------------------------------ defects
# One list, ordered so the worst is first, each saying what it breaks, which
# cases are waiting on it, and what has to change.
WAITING: dict[str, list[str]] = {}
for _c, _bug in BLOCKED.items():
    if not re.match(r'^[A-Z]{1,2}\d{2}$', _c):
        continue
    WAITING.setdefault(_bug, []).append(_c)

SEV_ORDER = {'crit': 0, 'high': 1, 'med': 2, 'low': 3, 'harness': 4, 'fixed': 5}
SEV_NAME = {'crit': 'Stops the run', 'high': 'Undefined behaviour',
            'med': 'Wrong or missing output', 'low': 'Minor',
            'harness': 'Test code (already fixed)',
            'fixed': 'Fixed on fix/7.4_fixes_testsuite'}

defects = []
for bid, title, meta in DEFECTS:
    sev, word = severity_of(meta, title)
    first = re.sub(r'\s+', ' ', meta.split('Severity:')[-1]).strip(' .*')
    if bid in FIXED:
        first = 'Fixed: ' + FIXED[bid]
    if bid in FIXED:
        sev = 'fixed'
    defects.append({'id': bid, 'n': int(bid.split('-')[1]), 'title': title,
                    'sev': sev, 'word': word, 'note': first,
                    'waiting': sorted(WAITING.get(bid, []))})
defects.sort(key=lambda d: (SEV_ORDER[d['sev']], d['n']))

dgroups = []
for sev in ('crit', 'high', 'med', 'low', 'harness', 'fixed'):
    rows = [d for d in defects if d['sev'] == sev]
    if not rows:
        continue
    items = ''
    for d in rows:
        wait = ''
        if d['waiting']:
            chips = ''.join(f'<span class="wait">{c}</span>' for c in d['waiting'])
            wait = (f'<div class="dwait"><span class="waitlbl">'
                    f'{len(d["waiting"])} case{"s" if len(d["waiting"]) > 1 else ""} '
                    f'waiting</span>{chips}</div>')
        items += (f'<article class="defect" id="{d["id"]}">'
                  f'<div class="dhead"><span class="dnum">{d["id"]}</span>'
                  f'<h4>{md(d["title"])}</h4></div>'
                  f'<p class="dnote">{md(d["note"])}</p>{wait}</article>')
    dgroups.append(f'<div class="sevgroup s-{sev}">'
                   f'<h3 class="sevname"><span class="sevdot"></span>'
                   f'{SEV_NAME[sev]}<span class="sevn">{len(rows)}</span></h3>'
                   f'<div class="dgrid">{items}</div></div>')

defect_html = (
    '<section class="block" id="bugs"><div class="blockhead">'
    '<h2>Defects</h2>'
    f'<p>{len(defects)} found by the suite, {len(defects) - sum(d["sev"] == "fixed" for d in defects)} '
    'still open, worst first; the fixed ones are listed last. The suite carries no case '
    'that is known to fail: when one finds a defect the finding is written up and '
    'the case is removed, so a red run always means a new regression. '
    'Full write-ups, with the source lines and the proposed fix, are in '
    '<code>tests/TESTPLAN.md</code>.</p></div>'
    + ''.join(dgroups) + '</section>')

# ------------------------------------------------------------- observations
obs_items = ''
for o in OBS:
    cls = ' retracted' if o['retracted'] else ''
    ttl = o['title'].replace('RETRACTED: ', '')
    obs_items += (f'<article class="obs{cls}"><div class="ohead">'
                  f'<span class="onum">{o["id"]}</span>'
                  f'<h4>{md(ttl)}</h4>'
                  + ('<span class="otag">withdrawn</span>' if o['retracted'] else '')
                  + f'</div><p>{md(o["body"])}</p></article>')
obs_html = (
    '<section class="block" id="notes"><div class="blockhead">'
    '<h2>Observations</h2>'
    f'<p>{len(OBS)} things the suite established about how AquaCrop behaves. These are '
    'not defects and there is nothing to fix in them &mdash; they are here because '
    'each one changed how a test had to be written, and would mislead anyone who '
    'did not know it. Numbering starts at O2; there is no O1.</p></div>'
    f'<div class="ogrid">{obs_items}</div></section>')

retired_html = ''
if RETIRED:
    rows = ''.join(
        f'<tr><td class="cid">{html.escape(c)}</td><td class="ccase"><code>'
        f'{html.escape(i)}</code></td><td class="ctier">'
        f'<span class="bugref">{d}</span></td>'
        f'<td class="cex">{md(w)}</td></tr>' for c, i, d, w in RETIRED)
    retired_html = (
        '<section class="block" id="retired"><div class="blockhead">'
        '<h2>Cases waiting on a fix</h2>'
        '<p>Written, then removed because they cannot pass until AquaCrop changes. '
        'Each is one line in a <code>RETIRED</code> table in its generator and every '
        'input file it needs is still built, so reviving one after a fix is a '
        'copy-paste. The right-hand column is the test that will then hold.</p></div>'
        '<div class="twrap"><table class="wide"><thead><tr><th>Case</th><th>Input</th>'
        '<th>Blocked by</th><th>Passes once&hellip;</th></tr></thead><tbody>'
        f'{rows}</tbody></table></div></section>')

# the legend only advertises states that rows are actually in, so it can never
# describe a category the plan no longer uses
_used = [st for st in ('built', 'blocked', 'covered', 'invariant', 'partial',
                       'unreachable', 'todo', 'staged')
         if any(r['st'] == st for r in enum)]
legend_html = ''.join(
    f'<div class="leg"><span class="st s-{st}">{ST_LABEL[st]}</span>'
    f'<p>{html.escape(ST_HELP[st])}</p></div>' for st in _used)

ref_html = ''
if REF_STAMP:
    ref_html = (f"frozen {REF_STAMP.get('frozen', '?')} &middot; "
                f"binary sha {REF_STAMP.get('sha256', '?')} &middot; "
                f"commit {REF_STAMP.get('commit', '?')[:12]}")

for k, v in {'NAV': '\n'.join(nav), 'SECTIONS': '\n'.join(sections),
             'TOTAL': total, 'BUILT': built, 'PARTIAL': part_, 'TODO': todo,
             'STAGED': staged, 'FROZEN': frozen, 'COVERED': covered,
             'INVARIANT': invariant, 'UNREACH': unreach,
             'DEFECTS': defect_html, 'OBS': obs_html, 'RETIRED': retired_html,
             'BLOCKED': blocked, 'REFSTAMP': ref_html, 'LEGEND': legend_html,
             'OBSCOUNT': len(OBS),
             'RETIREDCOUNT': len(RETIRED),
             'DEFECTCOUNT': len(DEFECTS),
             'ENUM': len(enum), 'GEN': total - len(enum),
             'T0': tiers['T0'], 'T1': tiers['T1'],
             'T2': tiers['T2'], 'T3': tiers['T3']}.items():
    out = out.replace('{{%s}}' % k, str(v))
(ROOT / 'matrix.html').write_text(out)
print(f'total={total} enumerated={len(enum)} generated={total-len(enum)} '
      f'built={built} invariant={invariant} staged={staged} covered={covered} '
      f'partial={part_} unreachable={unreach} blocked={blocked} todo={todo} '
      f'frozen-refs={frozen} defects={len(DEFECTS)} '
      f'retired={len(RETIRED)} groups={len(order)}')
