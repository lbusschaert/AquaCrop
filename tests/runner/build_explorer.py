#!/usr/bin/env python3
"""Build the run explorer: a set of pages to look at a test run without the notebook.

    python3 tests/runner/run_tests.py -j 8 --keep          # keep the passing cases too
    python3 tests/runner/build_explorer.py                 # writes tests/work/explorer/

It writes a folder, `tests/work/explorer/`, with `index.html` and a `data/` folder next to
it. Open `index.html` in a browser (it needs the internet only for the plotting library and
the fonts). Four views:

  Overview   how many cases pass, per group, and how the others fail
  Daily      reference against new for one daily variable, one dot per case, run and day;
             zoom, click a dot or a ranking row to see that case's time series
  Season     the same for the season totals, including the cases without daily output
  Case       one case in depth: what it is, its verdict, its season totals, and every
             daily output column as a time series, the columns that moved first

Every case with a working tree is included, so run the suite with --keep: without it the
passing cases have no tree and only their reference is known.

--fragment writes index.html without its document wrapper, for publishing the folder as a
web page (a Claude artifact). The data files are the same either way.
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import pathlib
import re
import sys

import numpy as np
import pandas as pd

HERE = pathlib.Path(__file__).resolve().parent
TESTS = HERE.parent
sys.path.insert(0, str(HERE))

CROP = ["CC", "Biomass", "Y(dry)", "HI", "Tr", "Z"]
WATER = ["Wr", "WC01", "Drain", "CR", "E", "Infilt"]
WR_BAND = ["Wr(SAT)", "Wr(FC)", "Wr(PWP)"]
# listed first in the daily view's variable menu; every other column follows, sorted
FIRST = CROP + [v for v in WATER if v not in CROP] + [
    "WC(profile)", "ET", "Tr/Trx", "RO", "Irri", "Surf", "Ex", "Trx", "StExp", "StSto", "StSen",
    "StSalt", "StWeed", "GD", "Kc(Tr)", "WP", "Brelative", "Stage", "DAP"]
SEASON_SKIP = {"run", "Day1", "Month1", "Year1", "DayN", "MonthN", "YearN"}
CHUNK_BYTES = 12_000_000            # a data file stays well under the 16 MB page limit


def _notebook(work: pathlib.Path) -> dict:
    """The results notebook's own code: parser, verdicts and failure kinds, time mode.

    Taking them from the notebook keeps one definition of how the output is read and how a
    failure is classified."""
    os.environ["AQUACROP_WORK"] = str(work)
    import IPython.display as D
    D.display = lambda *a, **k: None
    import build_compare_notebook as NB
    ns: dict = {}
    wanted = ("from pathlib import Path", "def _dedupe", "def _group_names",
              "import yaml")
    import contextlib
    import io
    for kind, src in NB.CELLS:
        if kind == "code" and src.lstrip().startswith(wanted):
            with contextlib.redirect_stdout(io.StringIO()):
                exec(src, ns)                               # noqa: S102
    return ns


def _num(x):
    if x is None:
        return None
    try:
        x = float(x)
    except (TypeError, ValueError):
        return None
    if not np.isfinite(x) or x <= -9.0:                     # -9 / -9.9 mean "undefined"
        return None
    return round(x, 6)


def _col(s: pd.Series) -> list:
    return [_num(x) for x in s]


def _case_inputs(case_dir: pathlib.Path) -> dict:
    """What the case is: its description, runs, patched lines, and the error it expects."""
    import yaml
    spec = yaml.safe_load((case_dir / "case.yml").read_text()) or {}
    desc = " ".join(str(spec.get("desc", "")).split())
    runs = []
    for r in (spec.get("project") or {}).get("runs", []):
        runs.append({k: (list(map(str, v)) if isinstance(v, list) else str(v))
                     for k, v in r.items()})
    patch = {f: {str(k): str(v) for k, v in (lines or {}).items()}
             for f, lines in (spec.get("patch") or {}).items()}
    return {"desc": desc, "runs": runs, "patch": patch, "stage": spec.get("stage", []),
            "daily": spec.get("daily", []), "expect_error": spec.get("expect_error"),
            "tier": spec.get("tier", "")}


def build(work: pathlib.Path):
    nb = _notebook(work)
    results = nb["results"]                                 # one row per case
    parse_day, parse_season = nb["parse_day_file"], nb["parse_season_file"]
    epoch = pd.Timestamp("1970-01-01")

    cases, season_rows, season_cols = [], [], []
    chunks, chunk, chunk_size = [], {}, 0

    def flush():
        nonlocal chunk, chunk_size
        if chunk:
            chunks.append(chunk)
        chunk, chunk_size = {}, 0

    for _, row in results.iterrows():
        case = row["case"]
        cdir = TESTS / "cases" / case
        ref_dir, new_dir = cdir / "OUTP_REF", work / case / "OUTP"
        ci = len(cases)
        info = {"id": case, "g": row["group"], "v": row["verdict"], "k": row["kind"],
                "mode": row.get("mode", ""), "moved": row["moved"], "text": row["text_only"],
                "tree": bool(row["tree"]), "msgs": list(row["messages"])[:40],
                "chunk": None, "day": False, **_case_inputs(cdir)}
        cases.append(info)

        # season totals, one row per run
        for f in sorted(ref_dir.glob("*season.OUT")) if ref_dir.is_dir() else []:
            try:
                a = parse_season(f)
                b = parse_season(new_dir / f.name) if (new_dir / f.name).is_file() else None
            except Exception:                               # noqa: BLE001
                continue
            for c in a.columns:
                if c not in SEASON_SKIP and c not in season_cols:
                    season_cols.append(c)
            for i in range(len(a)):
                o = {c: _num(a[c].iloc[i]) for c in a.columns if c not in SEASON_SKIP}
                n = ({c: _num(b[c].iloc[i]) for c in b.columns if c not in SEASON_SKIP}
                     if b is not None and i < len(b) else None)
                season_rows.append({"c": ci, "r": int(a["run"].iloc[i]), "o": o, "n": n})

        # daily output
        if not ref_dir.is_dir():
            continue
        runs_all = []
        for f in sorted(ref_dir.glob("*day.OUT")):
            if not (new_dir / f.name).is_file():
                continue
            try:
                ref, new = parse_day(f), parse_day(new_dir / f.name)
            except Exception:                               # noqa: BLE001
                continue
            for run in sorted(set(ref) & set(new)):
                a, b = ref[run], new[run]
                if "date" not in a.columns or "date" not in b.columns:
                    continue
                m = a.merge(b, on="date", suffixes=("|o", "|n"))
                if m.empty:
                    continue
                dates = [int((t - epoch).days) for t in m["date"]]
                cols = [c[:-2] for c in m.columns if c.endswith("|o")
                        and c[:-2] + "|n" in m.columns
                        and c[:-2] not in ("Day", "Month", "Year")]
                o = {c: _col(m[c + "|o"]) for c in cols}
                n = {c: _col(m[c + "|n"]) for c in cols}
                # the case page: every column; the new values only where they differ
                runs_all.append({"r": int(run), "file": f.name, "d": dates,
                                 "cols": cols, "o": [o[c] for c in cols],
                                 "n": {str(j): n[c] for j, c in enumerate(cols)
                                       if n[c] != o[c]}})
        if runs_all:
            size = len(json.dumps(runs_all, separators=(",", ":")))
            if chunk_size + size > CHUNK_BYTES:
                flush()
            chunk[str(ci)] = runs_all
            chunk_size += size
            info["chunk"], info["day"] = len(chunks), True
    flush()

    report = work / "results.json"
    rep = json.loads(report.read_text()) if report.is_file() else {}
    meta = {"source": str(report) if rep else f"{work} (no results.json)",
            "finished": rep.get("finished", "?"), "exe": rep.get("exe_sha256", "?"),
            "built": datetime.datetime.now().isoformat(" ", "seconds"),
            "reference": (TESTS / "REFERENCE.txt").read_text()
            if (TESTS / "REFERENCE.txt").is_file() else ""}
    summary = {"meta": meta, "cases": cases, "crop": CROP, "water": WATER,
               "band": WR_BAND, "first": FIRST, "season": {"cols": season_cols, "rows": season_rows},
               "nchunks": len(chunks)}
    return summary, chunks


def _js(name: str, obj) -> str:
    return (f"window.AQ=window.AQ||{{}};window.AQ[{json.dumps(name)}]="
            + json.dumps(obj, separators=(",", ":"), allow_nan=False) + ";\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--work", type=pathlib.Path,
                    default=pathlib.Path(os.environ.get("AQUACROP_WORK", TESTS / "work")))
    ap.add_argument("--out", type=pathlib.Path, default=None,
                    help="output folder (default: explorer/ in the work folder)")
    ap.add_argument("--fragment", action="store_true",
                    help="write index.html without its document wrapper, for publishing "
                         "the folder as a web page (an artifact)")
    a = ap.parse_args()
    work = a.work.resolve()
    if not work.is_dir():
        raise SystemExit(f"no work folder at {work} — run run_tests.py first")
    summary, chunks = build(work)
    out = (a.out or work / "explorer").resolve()
    (out / "data").mkdir(parents=True, exist_ok=True)
    for old in (out / "data").glob("*.js"):
        old.unlink()
    (out / "data" / "summary.js").write_text(_js("summary", summary))
    for k, ch in enumerate(chunks):
        (out / "data" / f"cases-{k}.js").write_text(_js(f"cases-{k}", ch))
    page = PAGE
    (out / "index.html").write_text(page if a.fragment else DOCUMENT.replace("{page}", page))
    size = sum(f.stat().st_size for f in out.rglob("*") if f.is_file()) / 1e6
    ntree = sum(c["tree"] for c in summary["cases"])
    print(f"wrote {out}/index.html  ({len(summary['cases'])} cases, {ntree} with a working "
          f"tree, {len(chunks)} case files, {size:.1f} MB in all)")
    if ntree < len(summary["cases"]) - 20:
        print("note: many cases have no working tree — run the suite with --keep to "
              "include the passing ones")


DOCUMENT = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
</head><body>
{page}
</body></html>
"""

PAGE = r"""<title>AquaCrop Run Explorer</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&display=swap">
<script src="https://cdn.jsdelivr.net/npm/plotly.js-dist-min@2.35.2/plotly.min.js"></script>
<style>
:root{--ground:#f2f5f8;--paper:#ffffff;--sunk:#e9eef3;--ink:#0f1720;--ink2:#3b4754;--mut:#66737f;
  --line:#d6dde4;--acc:#0077d9;--ref:#f07c19;--new:#0077d9;--band:#8a97a4;
  --pass:#1ea55a;--tol:#d99a00;--fail:#e5383b;--err:#8e3ccb;
  --sans:"IBM Plex Sans",system-ui,-apple-system,"Segoe UI",sans-serif;
  --mono:"IBM Plex Mono",ui-monospace,Menlo,Consolas,monospace}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--ground:#0b1016;--paper:#121a22;
  --sunk:#18222c;--ink:#e8eef4;--ink2:#aab6c2;--mut:#8795a3;--line:#243241;--acc:#3aa0ff;
  --ref:#ff9a45;--new:#3aa0ff;--band:#7b8896;--pass:#34c77b;--tol:#ffc53d;--fail:#ff5d5f;--err:#b57bff}}
:root[data-theme="dark"]{--ground:#0b1016;--paper:#121a22;--sunk:#18222c;--ink:#e8eef4;
  --ink2:#aab6c2;--mut:#8795a3;--line:#243241;--acc:#3aa0ff;--ref:#ff9a45;--new:#3aa0ff;
  --band:#7b8896;--pass:#34c77b;--tol:#ffc53d;--fail:#ff5d5f;--err:#b57bff}
*{box-sizing:border-box}
body{margin:0;background:var(--ground);color:var(--ink);font:14px/1.45 var(--sans)}
a{color:var(--acc)}
.top{position:sticky;top:env(safe-area-inset-top,0px);z-index:10;background:var(--paper);
  border-bottom:1px solid var(--line);padding:10px 16px 0}
.top h1{font-size:17px;margin:0;font-weight:600}
.top .meta{color:var(--mut);font:12px var(--mono);overflow-wrap:anywhere;margin:2px 0 6px}
nav{display:flex;gap:2px;flex-wrap:wrap}
nav a{padding:7px 14px;border-radius:7px 7px 0 0;text-decoration:none;color:var(--ink2);
  font-weight:500;border:1px solid transparent;border-bottom:none}
nav a.on{background:var(--ground);color:var(--ink);border-color:var(--line)}
main{padding:14px 16px 40px;max-width:1500px;margin:0 auto}
section[hidden]{display:none}
.row{display:grid;gap:12px}
.two{grid-template-columns:minmax(0,3fr) minmax(260px,1fr)}
.half{grid-template-columns:repeat(auto-fit,minmax(min(520px,100%),1fr))}
@media (max-width:900px){.two{grid-template-columns:1fr}}
.card{background:var(--paper);border:1px solid var(--line);border-radius:8px;padding:10px 12px}
.card h2{font-size:14px;margin:0 0 8px;font-weight:600}
.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:10px;margin-bottom:12px}
.tile{background:var(--paper);border:1px solid var(--line);border-radius:8px;padding:10px 12px}
.tile b{display:block;font:600 24px/1.1 var(--mono);font-variant-numeric:tabular-nums}
.tile span{color:var(--mut);font-size:12px}
.tile.pass b{color:var(--pass)}.tile.tol b{color:var(--tol)}.tile.fail b{color:var(--fail)}
.tile.err b{color:var(--err)}
.bar{display:flex;flex-wrap:wrap;gap:8px 14px;align-items:center;margin-bottom:10px}
.bar label{font-size:13px;color:var(--ink2)}
select,input{font:inherit;color:var(--ink);background:var(--sunk);border:1px solid var(--line);
  border-radius:6px;padding:4px 7px}
input[type=search]{width:min(280px,100%)}
select:focus-visible,input:focus-visible,button:focus-visible,a:focus-visible{outline:2px solid var(--acc);outline-offset:1px}
.plot{height:560px}
.scroll{max-height:560px;overflow:auto}
table{border-collapse:collapse;width:100%;font-size:12.5px;font-variant-numeric:tabular-nums}
th{position:sticky;top:0;background:var(--paper);text-align:left;color:var(--mut);font-weight:600;
  font-size:11px;padding:4px 6px;white-space:nowrap}
td{padding:3px 6px;border-top:1px solid var(--line);white-space:nowrap}
tr.click{cursor:pointer}tr.click:hover td{background:var(--sunk)}
td.id{font-family:var(--mono);font-size:12px;max-width:260px;overflow:hidden;text-overflow:ellipsis}
td.num{text-align:right}
.pill{display:inline-block;border-radius:10px;padding:0 8px;font-size:11.5px;font-weight:500;
  color:var(--paper)}
.pill.pass{background:var(--pass)}.pill.tol{background:var(--tol)}.pill.fail{background:var(--fail)}
.pill.err{background:var(--err)}.pill.none{background:var(--mut)}
.views{display:flex;gap:6px;flex-wrap:wrap;margin:6px 0}
.views button,.btn{font:inherit;font-size:12.5px;border:1px solid var(--line);background:var(--sunk);
  color:var(--ink2);border-radius:14px;padding:3px 11px;cursor:pointer}
.views button.on{background:var(--acc);border-color:var(--acc);color:var(--paper)}
.note{color:var(--mut);font-size:12.5px}
.msgs{font:12px var(--mono);background:var(--sunk);border-radius:6px;padding:8px;
  white-space:pre-wrap;overflow-x:auto;max-height:220px;overflow-y:auto;margin:6px 0 0}
dl{display:grid;grid-template-columns:max-content 1fr;gap:3px 12px;margin:0;font-size:13px}
dt{color:var(--mut)}dd{margin:0;font-family:var(--mono);font-size:12.5px;overflow-wrap:anywhere}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(460px,100%),1fr));gap:10px}
.mini{background:var(--paper);border:1px solid var(--line);border-radius:8px;padding:4px}
.mini .p{height:230px}
.loading{color:var(--mut);padding:20px}
</style>

<div class="top">
  <h1>AquaCrop Run Explorer</h1>
  <div class="meta" id="meta"></div>
  <nav id="nav">
    <a href="#overview" data-v="overview">Overview</a>
    <a href="#daily" data-v="daily">Daily</a>
    <a href="#season" data-v="season">Season</a>
    <a href="#case" data-v="case">Case</a>
  </nav>
</div>
<main>
<section id="v-overview">
  <div class="tiles" id="tiles"></div>
  <div class="row half">
    <div class="card"><h2>Cases per group</h2><div id="ovGroups" class="plot" style="height:520px"></div></div>
    <div class="card"><h2>How the cases that do not pass differ</h2><div id="ovKinds" class="plot" style="height:260px"></div>
      <h2 style="margin-top:12px">Crop time mode</h2><div id="ovModes"></div></div>
  </div>
  <div class="card" style="margin-top:12px"><h2>All cases</h2>
    <div class="bar"><label for="ovFilter">show</label>
      <select id="ovFilter"><option value="notpass">not passing</option><option value="all">all</option>
      <option value="pass">passing</option></select>
      <label for="ovFind">find</label><input type="search" id="ovFind" placeholder="case id or words of its description"></div>
    <div class="scroll" id="ovTable"></div></div>
</section>

<section id="v-daily" hidden>
  <div class="bar">
    <label for="dVar">variable</label><select id="dVar"></select>
    <label for="dGrp">group</label><select id="dGrp"></select>
    <label><input type="checkbox" id="dMoved" checked> only days that moved</label>
    <label for="dColour">colour</label><select id="dColour"><option value="group">by group</option>
      <option value="delta">by relative difference</option></select>
  </div>
  <div class="row two">
    <div class="card"><h2 id="dTitle"></h2><div id="dScatter" class="plot"></div></div>
    <div class="card"><h2>Cases that moved most</h2><div class="scroll" id="dRank"></div></div>
  </div>
  <div class="card" style="margin-top:12px">
    <div id="dCaseTitle" class="note">Click a dot or a row to see the time series here.</div>
    <div class="views" id="dViews"></div><div id="dMissing" class="note"></div><div id="dSeries"></div>
  </div>
</section>

<section id="v-season" hidden>
  <div class="bar">
    <label for="sVar">variable</label><select id="sVar"></select>
    <label for="sGrp">group</label><select id="sGrp"></select>
    <label><input type="checkbox" id="sMoved" checked> only cases that moved</label>
  </div>
  <div class="row two">
    <div class="card"><h2 id="sTitle"></h2><div id="sScatter" class="plot"></div></div>
    <div class="card"><h2>Cases that moved most</h2><div class="scroll" id="sRank"></div></div>
  </div>
</section>

<section id="v-case" hidden>
  <div class="bar"><label for="cFind">case</label>
    <input type="search" id="cFind" list="caseList" placeholder="type a case id, e.g. F14">
    <datalist id="caseList"></datalist></div>
  <div id="cBody" class="note">Choose a case above, or click one anywhere on the other pages.</div>
</section>
</main>

<script>
const AQ = window.AQ = window.AQ || {};
const $ = id => document.getElementById(id);
const css = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim();
const esc = s => String(s ?? "").replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const fmtDate = d => new Date(d * 864e5).toISOString().slice(0, 10);
const GROUP_COLOURS = ["#0077d9","#f07c19","#1ea55a","#e5383b","#8e3ccb","#00a7b5","#d4a100",
  "#e0529c","#5b6bff","#7a9a01","#b5651d","#0f9d8a","#c2185b","#546e7a"];
const VCLASS = {"pass":"pass","within tolerance":"tol","fail":"fail","error":"err"};
const load = src => new Promise((ok, bad) => {
  const s = document.createElement("script"); s.src = src; s.onload = ok;
  s.onerror = () => bad(new Error("could not load " + src)); document.head.appendChild(s); });
const layoutBase = extra => Object.assign({paper_bgcolor: "rgba(0,0,0,0)",
  plot_bgcolor: "rgba(0,0,0,0)", font: {color: css("--ink"), size: 12,
  family: "IBM Plex Sans, system-ui, sans-serif"}}, extra);
const cfg = {responsive: true, displaylogo: false};
const pill = v => `<span class="pill ${VCLASS[v] || "none"}">${esc(v)}</span>`;
const caseLink = (ci, label) => `<a href="#case=${encodeURIComponent(AQ.summary.cases[ci].id)}">${esc(label ?? AQ.summary.cases[ci].id)}</a>`;

function relScore(o, n) {
  let lo = Infinity, hi = -Infinity, best = 0, at = -1, first = -1;
  for (let i = 0; i < o.length; i++) for (const x of [o[i], n[i]])
    if (x !== null && x !== undefined) { lo = Math.min(lo, x); hi = Math.max(hi, x); }
  let rng = hi - lo; if (!(rng > 1e-12)) rng = Math.max(Math.abs(hi), Math.abs(lo), 1e-12);
  for (let i = 0; i < o.length; i++) {
    if (o[i] === null || n[i] === null) continue;
    const dd = Math.abs(n[i] - o[i]);
    if (dd > 0 && first < 0) first = i;
    if (dd > best) { best = dd; at = i; }
  }
  return {score: best / rng, at, first, rng};
}

/* ---------------------------------------------------------------- overview */
function overview() {
  const S = AQ.summary, C = S.cases, count = v => C.filter(c => c.v === v).length;
  const tiles = [["cases", C.length, ""], ["pass", count("pass"), "pass"],
    ["within tolerance", count("within tolerance"), "tol"], ["fail", count("fail"), "fail"],
    ["error", count("error"), "err"],
    ["invariant broken", C.filter(c => c.k === "invariant broken").length, "fail"]];
  const cal = C.filter(c => c.mode === "calendar");
  tiles.push(["calendar cases unchanged", `${cal.filter(c => c.v === "pass").length}/${cal.length}`,
              cal.every(c => c.v === "pass") ? "pass" : "fail"]);
  $("tiles").innerHTML = tiles.map(([l, v, k]) => `<div class="tile ${k}"><b>${v}</b><span>${l}</span></div>`).join("");
  const groups = [...new Set(C.map(c => c.g))].sort();
  const order = ["pass", "within tolerance", "fail", "error"];
  const colour = {"pass": css("--pass"), "within tolerance": css("--tol"), "fail": css("--fail"), "error": css("--err")};
  Plotly.react("ovGroups", order.map(v => ({type: "bar", orientation: "h", name: v, y: groups,
    x: groups.map(g => C.filter(c => c.g === g && c.v === v).length), marker: {color: colour[v]}})),
    layoutBase({barmode: "stack", margin: {l: 40, r: 10, t: 10, b: 30},
      legend: {orientation: "h", y: 1.05}, yaxis: {autorange: "reversed", gridcolor: css("--line")},
      xaxis: {gridcolor: css("--line"), title: "cases"}}), cfg);
  const kinds = {}; for (const c of C) if (c.k) kinds[c.k] = (kinds[c.k] || 0) + 1;
  const ks = Object.keys(kinds).sort((a, b) => kinds[b] - kinds[a]);
  Plotly.react("ovKinds", [{type: "bar", orientation: "h", y: ks, x: ks.map(k => kinds[k]),
    marker: {color: css("--acc")}, text: ks.map(k => kinds[k]), textposition: "outside"}],
    layoutBase({margin: {l: 130, r: 30, t: 5, b: 30}, yaxis: {autorange: "reversed"},
      xaxis: {gridcolor: css("--line")}}), cfg);
  const modes = {}; for (const c of C) { const m = c.mode || "?"; modes[m] = modes[m] || {}; modes[m][c.v] = (modes[m][c.v] || 0) + 1; }
  $("ovModes").innerHTML = `<table><thead><tr><th>mode</th>${order.map(v => `<th>${v}</th>`).join("")}</tr></thead><tbody>` +
    Object.entries(modes).map(([m, o]) => `<tr><td>${esc(m)}</td>${order.map(v => `<td class="num">${o[v] || 0}</td>`).join("")}</tr>`).join("") +
    `</tbody></table><p class="note">A change to growing-degree-day mode must leave every calendar case passing.</p>`;
  ovTable();
}
function ovTable() {
  const C = AQ.summary.cases, f = $("ovFilter").value, q = $("ovFind").value.trim().toLowerCase();
  const rows = C.map((c, i) => [c, i]).filter(([c]) => (f === "all" || (f === "pass" ? c.v === "pass" : c.v !== "pass"))
    && (!q || c.id.toLowerCase().includes(q) || c.desc.toLowerCase().includes(q)));
  $("ovTable").innerHTML = `<table><thead><tr><th>case</th><th>verdict</th><th>how</th><th>files that moved</th><th>mode</th><th>description</th></tr></thead><tbody>` +
    rows.slice(0, 1000).map(([c, i]) => `<tr class="click" data-ci="${i}"><td class="id">${esc(c.id)}</td><td>${pill(c.v)}</td><td>${esc(c.k)}</td>` +
      `<td>${esc(c.moved || c.text)}</td><td>${esc(c.mode)}</td><td style="white-space:normal">${esc(c.desc)}</td></tr>`).join("") +
    `</tbody></table>` + (rows.length > 1000 ? `<p class="note">${rows.length - 1000} more — narrow the search.</p>` : "");
  for (const tr of $("ovTable").querySelectorAll("tr[data-ci]"))
    tr.onclick = () => { location.hash = "case=" + encodeURIComponent(C[+tr.dataset.ci].id); };
}

/* ---------------------------------------------------------------- daily */
const D = {v: "Tr", g: "(all)", open: null, view: "var"};
function buildDaily() {
  const S = AQ.summary, runs = [], names = new Set();
  for (let k = 0; k < S.nchunks; k++) {
    for (const [ci, list] of Object.entries(AQ["cases-" + k] || {})) for (const r of list) {
      const o = {}, n = {};
      r.cols.forEach((c, j) => { o[c] = r.o[j]; n[c] = r.n[String(j)] || r.o[j]; names.add(c); });
      runs.push({c: +ci, r: r.r, file: r.file, d: r.d, o, n});
    }
  }
  runs.sort((a, b) => a.c - b.c || a.r - b.r);
  const band = new Set(S.band), first = S.first.filter(v => names.has(v));
  const rest = [...names].filter(v => !band.has(v) && !first.includes(v)).sort();
  AQ.daily = {vars: first.concat(rest), first, runs};
}
function dailyInit() {
  buildDaily();
  const X = AQ.daily;
  const g1 = document.createElement("optgroup"), g2 = document.createElement("optgroup");
  g1.label = "main variables"; g2.label = "every other column";
  for (const v of X.vars) (X.first.includes(v) ? g1 : g2).appendChild(new Option(v, v));
  $("dVar").appendChild(g1); $("dVar").appendChild(g2);
  if (!X.vars.includes(D.v)) D.v = X.vars[0];
  $("dVar").value = D.v;
  $("dGrp").add(new Option("(all)", "(all)"));
  for (const g of [...new Set(AQ.summary.cases.map(c => c.g))].sort()) $("dGrp").add(new Option(g, g));
  $("dVar").onchange = () => { D.v = $("dVar").value; dailyScatter(); dailySeries(); };
  $("dGrp").onchange = () => { D.g = $("dGrp").value; dailyScatter(); };
  $("dMoved").onchange = dailyScatter; $("dColour").onchange = dailyScatter;
  dailyScatter();
  const first = $("dRank").querySelector("tr[data-ri]");
  if (first) dailyOpen(+first.dataset.ri, +first.dataset.i);
  $("dScatter").on("plotly_click", ev => { const p = ev.points && ev.points[0];
    if (p && p.customdata) dailyOpen(p.customdata[0], p.customdata[1]); });
}
function dailyScatter() {
  const X = AQ.daily, C = AQ.summary.cases, v = D.v, movedOnly = $("dMoved").checked;
  const byGroup = $("dColour").value === "group", tr = {}, groups = [...new Set(C.map(c => c.g))].sort();
  let lo = Infinity, hi = -Infinity, count = 0;
  X.runs.forEach((r, ri) => {
    const c = C[r.c]; if (D.g !== "(all)" && c.g !== D.g) return;
    const o = r.o[v], n = r.n[v]; if (!o) return;
    const s = byGroup ? null : relScore(o, n);
    for (let i = 0; i < o.length; i++) {
      if (o[i] === null || n[i] === null || (movedOnly && o[i] === n[i])) continue;
      const k = byGroup ? c.g : "all", t = tr[k] || (tr[k] = {x: [], y: [], cd: [], txt: [], col: []});
      t.x.push(o[i]); t.y.push(n[i]); t.cd.push([ri, i]);
      t.txt.push(`${c.id}<br>run ${r.r} · ${fmtDate(r.d[i])}<br>ref ${o[i]} → new ${n[i]}`);
      if (!byGroup) t.col.push(Math.abs(n[i] - o[i]) / s.rng);
      lo = Math.min(lo, o[i], n[i]); hi = Math.max(hi, o[i], n[i]); count++;
    }
  });
  const data = Object.entries(tr).sort().map(([k, t]) => ({type: "scattergl", mode: "markers",
    name: byGroup ? k : "relative Δ", x: t.x, y: t.y, customdata: t.cd, text: t.txt, hoverinfo: "text",
    marker: byGroup ? {size: 5, color: GROUP_COLOURS[groups.indexOf(k) % GROUP_COLOURS.length], opacity: .75}
      : {size: 5, color: t.col, colorscale: "Turbo", cmin: 0, colorbar: {title: "|Δ|/range", thickness: 10}}}));
  if (isFinite(lo)) data.push({type: "scatter", mode: "lines", x: [lo, hi], y: [lo, hi], hoverinfo: "skip",
    showlegend: false, line: {color: css("--mut"), dash: "dot", width: 1}});
  $("dTitle").textContent = `${v}: reference (x) against new (y) · ${count.toLocaleString()} day(s)${movedOnly ? " that moved" : ""}`;
  Plotly.react("dScatter", data, layoutBase({margin: {l: 55, r: 10, t: 10, b: 45},
    xaxis: {title: "reference " + v, gridcolor: css("--line"), zeroline: false},
    yaxis: {title: "new " + v, gridcolor: css("--line"), zeroline: false},
    legend: {orientation: "h", y: -0.16}, hovermode: "closest"}), cfg);
  const rows = [];
  X.runs.forEach((r, ri) => { const c = C[r.c]; if (D.g !== "(all)" && c.g !== D.g) return;
    if (!r.o[v]) return; const s = relScore(r.o[v], r.n[v]);
    if (s.score > 0) rows.push({ri, c: r.c, run: r.r, s: s.score, at: s.at, first: s.first}); });
  rows.sort((a, b) => b.s - a.s);
  $("dRank").innerHTML = rows.length ? `<table><thead><tr><th>case</th><th>run</th><th>max Δ/range</th><th>first moved</th></tr></thead><tbody>` +
    rows.slice(0, 300).map(r => `<tr class="click" data-ri="${r.ri}" data-i="${r.at}"><td class="id" title="${esc(C[r.c].id)}">${esc(C[r.c].id)}</td>` +
      `<td class="num">${r.run}</td><td class="num">${(100 * r.s).toFixed(1)} %</td><td>${r.first >= 0 ? fmtDate(X.runs[r.ri].d[r.first]) : ""}</td></tr>`).join("") + `</tbody></table>`
    : `<p class="note">Nothing moved for ${esc(v)}.</p>`;
  for (const t of $("dRank").querySelectorAll("tr[data-ri]")) t.onclick = () => dailyOpen(+t.dataset.ri, +t.dataset.i);
}
function dailyOpen(ri, i) { D.open = {ri, i}; dailySeries(); }
function dailySeries() {
  if (!D.open) return;
  const X = AQ.daily, S = AQ.summary, {ri, i} = D.open, r = X.runs[ri];
  $("dViews").innerHTML = [["var", `this variable (${D.v})`], ["crop", "crop"], ["water", "water"]]
    .map(([k, l]) => `<button data-k="${k}" class="${D.view === k ? "on" : ""}">${l}</button>`).join("");
  for (const b of $("dViews").querySelectorAll("button")) b.onclick = () => { D.view = b.dataset.k; dailySeries(); };
  const want = D.view === "var" ? [D.v] : S[D.view], vars = want.filter(v => r.o[v]);
  $("dMissing").textContent = want.length > vars.length ? "not written by this case: " + want.filter(v => !r.o[v]).join(", ") : "";
  $("dCaseTitle").innerHTML = `<b>${caseLink(r.c)}</b> · ${esc(r.file)} · run ${r.r} · ${pill(S.cases[r.c].v)}` +
    (i >= 0 ? ` · clicked ${fmtDate(r.d[i])}` : "") + ` · <a href="#case=${encodeURIComponent(S.cases[r.c].id)}">open the case page →</a>`;
  stacked("dSeries", r.d, vars.map(v => ({name: v, o: r.o[v], n: r.n[v],
    band: v === "Wr" ? S.band.map(b => ({name: b, o: r.o[b], n: r.n[b]})).filter(b => b.o) : null})), i);
}
/* several variables stacked, each with its difference underneath */
function stacked(div, days, series, mark) {
  const x = days.map(fmtDate), data = [], n = series.length, gap = .04, h = (1 - gap * (n - 1)) / Math.max(n, 1);
  const L = layoutBase({height: Math.max(270, 240 * n), margin: {l: 60, r: 10, t: 22, b: 35},
    hovermode: "x unified", legend: {orientation: "h", y: 1.0, yanchor: "bottom"}, shapes: [], annotations: []});
  series.forEach((sv, k) => {
    const top = 1 - k * (h + gap), mid = top - h * .7, xa = k ? "x" + (k + 1) : "x";
    const ya = "y" + (2 * k + 1), yd = "y" + (2 * k + 2);
    if (sv.band) for (const b of sv.band) {
      const lab = b.name.replace("Wr(", "").replace(")", "");
      data.push({x, y: b.n, xaxis: xa, yaxis: ya, name: lab, showlegend: false, hoverinfo: "skip",
        line: {color: css("--band"), width: 1, dash: lab === "FC" ? "dash" : lab === "SAT" ? "dot" : "dashdot"}});
      const last = b.n.length - 1;
      L.annotations.push({x: x[last], y: b.n[last], xref: xa, yref: ya, text: lab, showarrow: false,
        xanchor: "left", font: {size: 10, color: css("--band")}});
    }
    const delta = sv.o.map((a, j) => a === null || sv.n[j] === null ? null : sv.n[j] - a);
    data.push({x, y: sv.o, xaxis: xa, yaxis: ya, name: "reference", legendgroup: "o", showlegend: k === 0,
      line: {color: css("--ref"), dash: "dash", width: 2}});
    data.push({x, y: sv.n, xaxis: xa, yaxis: ya, name: "new", legendgroup: "n", showlegend: k === 0,
      line: {color: css("--new"), width: 2}});
    data.push({x, y: delta, xaxis: xa, yaxis: yd, name: "Δ " + sv.name, showlegend: false,
      line: {color: css("--mut"), width: 1.2}, fill: "tozeroy"});
    const s = relScore(sv.o, sv.n);
    L["yaxis" + (2 * k + 1)] = {domain: [mid, top], title: sv.name, gridcolor: css("--line"), zeroline: false};
    L["yaxis" + (2 * k + 2)] = {domain: [top - h, mid - .012], title: "Δ", gridcolor: css("--line"),
      zeroline: true, zerolinecolor: css("--mut")};
    L["xaxis" + (k ? k + 1 : "")] = {anchor: yd, matches: k ? "x" : undefined, showticklabels: k === n - 1,
      gridcolor: css("--line")};
    L.annotations.push({text: s.score > 0 ? `max Δ ${(100 * s.score).toFixed(1)} % of its range` : "unchanged",
      xref: "paper", yref: "paper", x: 1, y: top, xanchor: "right", yanchor: "bottom", showarrow: false,
      font: {size: 11, color: css("--mut")}});
  });
  if (mark >= 0) L.shapes.push({type: "line", xref: "x", yref: "paper", x0: x[mark], x1: x[mark], y0: 0, y1: 1,
    line: {color: css("--ink"), width: 1, dash: "dot"}});
  Plotly.react(div, data, L, cfg);
}

/* ---------------------------------------------------------------- season */
const SV = {v: "BioMass", g: "(all)"};
function seasonInit() {
  const cols = AQ.summary.season.cols;
  for (const v of cols) $("sVar").add(new Option(v, v));
  if (!cols.includes(SV.v)) SV.v = cols[0];
  $("sVar").value = SV.v;
  $("sGrp").add(new Option("(all)", "(all)"));
  for (const g of [...new Set(AQ.summary.cases.map(c => c.g))].sort()) $("sGrp").add(new Option(g, g));
  $("sVar").onchange = () => { SV.v = $("sVar").value; seasonDraw(); };
  $("sGrp").onchange = () => { SV.g = $("sGrp").value; seasonDraw(); };
  $("sMoved").onchange = seasonDraw;
  seasonDraw();
  $("sScatter").on("plotly_click", ev => { const p = ev.points && ev.points[0];
    if (p && p.customdata !== undefined) location.hash = "case=" + encodeURIComponent(AQ.summary.cases[p.customdata].id); });
}
function seasonDraw() {
  const S = AQ.summary, C = S.cases, v = SV.v, movedOnly = $("sMoved").checked, tr = {}, rows = [];
  const groups = [...new Set(C.map(c => c.g))].sort();
  let lo = Infinity, hi = -Infinity;
  for (const r of S.season.rows) {
    const c = C[r.c]; if (SV.g !== "(all)" && c.g !== SV.g) continue;
    const o = r.o[v], n = r.n ? r.n[v] : undefined;
    if (o === null || o === undefined || n === null || n === undefined) continue;
    if (movedOnly && o === n) continue;
    const t = tr[c.g] || (tr[c.g] = {x: [], y: [], cd: [], txt: []});
    t.x.push(o); t.y.push(n); t.cd.push(r.c);
    t.txt.push(`${c.id}<br>run ${r.r}<br>ref ${o} → new ${n}`);
    lo = Math.min(lo, o, n); hi = Math.max(hi, o, n);
    const rel = Math.abs(n - o) / Math.max(Math.abs(o), Math.abs(n), 1e-12);
    if (n !== o) rows.push({c: r.c, run: r.r, o, n, rel});
  }
  const data = Object.entries(tr).sort().map(([g, t]) => ({type: "scattergl", mode: "markers", name: g,
    x: t.x, y: t.y, customdata: t.cd, text: t.txt, hoverinfo: "text",
    marker: {size: 7, color: GROUP_COLOURS[groups.indexOf(g) % GROUP_COLOURS.length], opacity: .8}}));
  if (isFinite(lo)) data.push({type: "scatter", mode: "lines", x: [lo, hi], y: [lo, hi], hoverinfo: "skip",
    showlegend: false, line: {color: css("--mut"), dash: "dot", width: 1}});
  $("sTitle").textContent = `${v} season total: reference (x) against new (y) · ${rows.length} run(s) moved`;
  Plotly.react("sScatter", data, layoutBase({margin: {l: 55, r: 10, t: 10, b: 45},
    xaxis: {title: "reference " + v, gridcolor: css("--line"), zeroline: false},
    yaxis: {title: "new " + v, gridcolor: css("--line"), zeroline: false},
    legend: {orientation: "h", y: -0.16}, hovermode: "closest"}), cfg);
  rows.sort((a, b) => b.rel - a.rel);
  $("sRank").innerHTML = rows.length ? `<table><thead><tr><th>case</th><th>run</th><th>ref</th><th>new</th><th>Δ</th></tr></thead><tbody>` +
    rows.slice(0, 300).map(r => `<tr class="click" data-ci="${r.c}"><td class="id" title="${esc(C[r.c].id)}">${esc(C[r.c].id)}</td>` +
      `<td class="num">${r.run}</td><td class="num">${r.o}</td><td class="num">${r.n}</td><td class="num">${(100 * r.rel).toFixed(1)} %</td></tr>`).join("") + `</tbody></table>`
    : `<p class="note">No season total of ${esc(v)} moved.</p>`;
  for (const t of $("sRank").querySelectorAll("tr[data-ci]")) t.onclick = () => { location.hash = "case=" + encodeURIComponent(C[+t.dataset.ci].id); };
}

/* ---------------------------------------------------------------- case page */
const CASEVIEW = {showAll: false};
async function casePage(id) {
  const S = AQ.summary, ci = S.cases.findIndex(c => c.id === id || c.id.startsWith(id + "_"));
  if (ci < 0) { $("cBody").innerHTML = `<p class="note">No case called ${esc(id)}.</p>`; return; }
  const c = S.cases[ci];
  const runsTable = c.runs.length ? `<table><thead><tr>${Object.keys(c.runs[0]).map(k => `<th>${esc(k)}</th>`).join("")}</tr></thead><tbody>` +
    c.runs.map(r => `<tr>${Object.values(r).map(v => `<td>${esc(Array.isArray(v) ? v.join(" → ") : v)}</td>`).join("")}</tr>`).join("") + `</tbody></table>` : "";
  const patch = Object.entries(c.patch || {}).map(([f, lines]) => Object.entries(lines).map(([l, t]) => `${f}:${l}  ${t}`).join("\n")).join("\n");
  const seasonRows = S.season.rows.filter(r => r.c === ci);
  const seasonTable = seasonRows.length ? `<div class="scroll" style="max-height:none;overflow-x:auto"><table><thead><tr><th>run</th><th></th>${S.season.cols.map(k => `<th>${esc(k)}</th>`).join("")}</tr></thead><tbody>` +
    seasonRows.map(r => ["ref", "new"].map(w => `<tr><td>${r.r}</td><td>${w}</td>${S.season.cols.map(k => {
      const o = r.o[k], n = r.n ? r.n[k] : undefined, val = w === "ref" ? o : n;
      const moved = w === "new" && n !== undefined && o !== n;
      return `<td class="num" style="${moved ? "color:var(--fail);font-weight:600" : ""}">${val ?? ""}</td>`; }).join("")}</tr>`).join("")).join("") +
    `</tbody></table></div>` : `<p class="note">No season output.</p>`;
  $("cBody").innerHTML = `
    <div class="card"><h2><span style="font-family:var(--mono)">${esc(c.id)}</span> ${pill(c.v)}</h2>
      <p style="margin:0 0 8px;max-width:75ch">${esc(c.desc)}</p>
      <dl><dt>group</dt><dd>${esc(c.g)}</dd><dt>crop time mode</dt><dd>${esc(c.mode)}</dd>
        <dt>how it differs</dt><dd>${esc(c.k || "—")}</dd><dt>files that moved</dt><dd>${esc(c.moved || "—")}</dd>
        <dt>only text moved</dt><dd>${esc(c.text || "—")}</dd><dt>daily blocks</dt><dd>${esc((c.daily || []).join(", ") || "none")}</dd>
        ${c.expect_error ? `<dt>must stop with</dt><dd>${esc(c.expect_error)}</dd>` : ""}
        <dt>input files</dt><dd>${esc((c.stage || []).join(", "))}</dd></dl>
      ${patch ? `<p class="note" style="margin:8px 0 0">lines changed in the inputs</p><div class="msgs">${esc(patch)}</div>` : ""}
      ${c.msgs.length ? `<p class="note" style="margin:8px 0 0">what the run reported</p><div class="msgs">${esc(c.msgs.join("\n"))}</div>` : ""}
    </div>
    <div class="card" style="margin-top:12px"><h2>Runs</h2><div style="overflow-x:auto">${runsTable}</div></div>
    <div class="card" style="margin-top:12px"><h2>Season totals</h2>${seasonTable}</div>
    <div class="card" style="margin-top:12px"><h2>Every daily column</h2><div id="cDaily" class="loading">loading…</div></div>`;
  if (!c.day) { $("cDaily").innerHTML = c.tree ? "No daily output." :
    "No working tree for this case — run the suite with --keep and rebuild the explorer to see its daily output."; return; }
  const key = "cases-" + c.chunk;
  try { if (!AQ[key]) await load(`data/${key}.js`); }
  catch (e) { $("cDaily").textContent = e.message; return; }
  caseDaily(ci);
}
function caseDaily(ci) {
  const runs = AQ["cases-" + AQ.summary.cases[ci].chunk][String(ci)], box = $("cDaily");
  box.className = ""; box.innerHTML = runs.map((r, k) => `<div id="cRun${k}"></div>`).join("");
  runs.forEach((r, k) => {
    const cols = r.cols.map((name, j) => {
      const o = r.o[j], n = r.n[String(j)] || o, s = relScore(o, n);
      return {name, o, n, s: s.score};
    }).filter(c => c.o.some(x => x !== null));
    const moved = cols.filter(c => c.s > 0).sort((a, b) => b.s - a.s), same = cols.filter(c => !(c.s > 0));
    const band = name => name === "Wr" ? AQ.summary.band.map(b => { const j = r.cols.indexOf(b);
      return j < 0 ? null : {name: b, o: r.o[j], n: r.n[String(j)] || r.o[j]}; }).filter(Boolean) : null;
    const el = $("cRun" + k);
    el.innerHTML = `<h3 style="font-size:13px;margin:10px 0 6px">${esc(r.file)} · run ${r.r} · ${moved.length} of ${cols.length} columns moved</h3>` +
      `<div class="grid">${moved.map((c, j) => `<div class="mini"><div class="p" id="m${k}_${j}"></div></div>`).join("")}</div>` +
      (same.length ? `<p><button class="btn" id="cShow${k}">${CASEVIEW.showAll ? "hide" : "show"} the ${same.length} unchanged columns</button></p>` +
        `<div class="grid" id="cSame${k}" ${CASEVIEW.showAll ? "" : "hidden"}>${same.map((c, j) => `<div class="mini"><div class="p" id="u${k}_${j}"></div></div>`).join("")}</div>` : "");
    const draw = (list, prefix) => list.forEach((c, j) => miniPlot(prefix + k + "_" + j, r.d, c, band(c.name), prefix === "m" ? j + 1 : null));
    draw(moved, "m");
    if (same.length) {
      if (CASEVIEW.showAll) draw(same, "u");
      $("cShow" + k).onclick = () => { CASEVIEW.showAll = !CASEVIEW.showAll; caseDaily(ci); };
    }
  });
}
function miniPlot(div, days, c, band, rank) {
  const x = days.map(fmtDate), data = [];
  if (band) for (const b of band) data.push({x, y: b.n, name: b.name.replace("Wr", ""), hoverinfo: "skip",
    line: {color: css("--band"), width: 1, dash: b.name === "Wr(FC)" ? "dash" : b.name === "Wr(SAT)" ? "dot" : "dashdot"}});
  data.push({x, y: c.o, name: "reference", line: {color: css("--ref"), dash: "dash", width: 1.8}});
  data.push({x, y: c.n, name: "new", line: {color: css("--new"), width: 1.8}});
  const title = (rank ? `#${rank} ` : "") + c.name + (c.s > 0 ? ` · max Δ ${(100 * c.s).toFixed(1)} % of its range` : " · unchanged");
  Plotly.react(div, data, layoutBase({margin: {l: 45, r: 8, t: 26, b: 28}, showlegend: !!band,
    legend: {orientation: "h", y: -0.2, font: {size: 10}},
    title: {text: title, font: {size: 12}, x: 0.01, xanchor: "left"}, hovermode: "x unified",
    xaxis: {gridcolor: css("--line")}, yaxis: {gridcolor: css("--line"), zeroline: false}}),
    {responsive: true, displaylogo: false, displayModeBar: false});
}

/* ---------------------------------------------------------------- routing */
const done = {};
function route() {
  const h = decodeURIComponent(location.hash.slice(1) || "overview");
  const view = h.startsWith("case") ? "case" : (["overview", "daily", "season"].includes(h) ? h : "overview");
  for (const v of ["overview", "daily", "season", "case"]) $("v-" + v).hidden = v !== view;
  for (const a of $("nav").querySelectorAll("a")) a.classList.toggle("on", a.dataset.v === view);
  if (view === "overview" && !done.overview) { overview(); done.overview = true; }
  if (view === "daily" && !done.daily) {
    done.daily = true; $("dTitle").textContent = "loading the daily output of every case…";
    const files = [];
    for (let k = 0; k < AQ.summary.nchunks; k++) if (!AQ["cases-" + k]) files.push(load(`data/cases-${k}.js`));
    Promise.all(files).then(dailyInit).catch(e => { $("dTitle").textContent = e.message; });
  }
  if (view === "season" && !done.season) { seasonInit(); done.season = true; }
  if (view === "case" && h.startsWith("case=")) casePage(h.slice(5));
  if (view !== "overview") window.dispatchEvent(new Event("resize"));
}
async function start() {
  try { await load("data/summary.js"); }
  catch (e) { document.querySelector("main").innerHTML = `<p class="note">${esc(e.message)} — keep index.html and the data folder together.</p>`; return; }
  const m = AQ.summary.meta;
  $("meta").textContent = `run finished ${m.finished} · binary ${m.exe} · page built ${m.built} · ${AQ.summary.cases.length} cases`;
  for (const c of AQ.summary.cases) $("caseList").appendChild(new Option(c.id));
  $("ovFilter").onchange = ovTable; $("ovFind").oninput = ovTable;
  $("cFind").onchange = () => { if ($("cFind").value) location.hash = "case=" + encodeURIComponent($("cFind").value); };
  window.addEventListener("hashchange", route);
  route();
  const redraw = () => { for (const k in done) delete done[k];
    for (const id of ["dVar", "dGrp", "sVar", "sGrp"]) $(id).innerHTML = ""; route(); };
  try { matchMedia("(prefers-color-scheme: dark)").addEventListener("change", redraw); } catch (e) {}
  new MutationObserver(redraw).observe(document.documentElement, {attributes: true, attributeFilter: ["data-theme"]});
}
start();
</script>
"""

if __name__ == "__main__":
    main()
