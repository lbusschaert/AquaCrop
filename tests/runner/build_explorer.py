#!/usr/bin/env python3
"""Build an interactive page to explore the daily differences of a test run.

    python3 tests/runner/build_explorer.py                 # the last run, in tests/work/
    python3 tests/runner/build_explorer.py --work /path/to/work --out explorer.html
    python3 tests/runner/build_explorer.py --vars CC Tr Drain

It writes one self-contained HTML file (default tests/work/explorer.html) holding, for every
case with a working tree, the daily values of the reference and of the new run. Open it in
a browser:

  - a scatter of reference against new, one dot per case, run and day, which you can zoom
    and pan; hovering names the case and the day;
  - click a dot to see that case's time series underneath, with the day you clicked marked;
  - a ranking of the cases whose selected variable moved most;
  - buttons to switch the time series between the selected variable and the standard crop
    and water variables.

The file only needs the internet for the plotting library (Plotly, from a CDN).
Run the suite with --keep first if you also want passing cases in the page.
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
import build_compare_notebook as NB                         # noqa: E402  (the one parser)

CROP = ["CC", "Biomass", "Y(dry)", "HI", "Tr", "Z"]
WATER = ["Wr", "WC01", "Drain", "CR", "E", "Infilt"]
DEFAULT_VARS = CROP + [v for v in WATER if v not in CROP] + ["WC(profile)"]


def _parser():
    """The day-file parser of the results notebook, so both read the files the same way."""
    ns = {"Path": pathlib.Path, "re": re, "np": np, "pd": pd, "json": json, "os": os}
    for kind, src in NB.CELLS:
        if kind == "code" and "def parse_day_file" in src:
            exec(src, ns)                                   # noqa: S102
            return ns["parse_day_file"]
    raise SystemExit("could not find parse_day_file in build_compare_notebook.py")


def _group(case: str) -> str:
    m = re.match(r"^([A-Z]+)", case)
    return m.group(1) if m else "?"


def _values(s: pd.Series) -> list:
    s = s.mask(s <= -9.0)                                   # -9 / -9.9 mean "undefined"
    return [None if pd.isna(x) else float(x) for x in s]


def collect(work: pathlib.Path, variables: list[str]):
    parse_day_file = _parser()
    report = work / "results.json"
    rep = json.loads(report.read_text()) if report.is_file() else {}
    verdict = {c["case"]: c["verdict"] for c in rep.get("cases", [])}
    epoch = pd.Timestamp("1970-01-01")

    cases, runs = [], []
    for d in sorted(p for p in work.iterdir() if (p / "OUTP").is_dir()):
        case = d.name
        ref_dir = TESTS / "cases" / case / "OUTP_REF"
        if not ref_dir.is_dir():
            continue
        day_files = sorted(f.name for f in ref_dir.glob("*day.OUT")
                           if (d / "OUTP" / f.name).is_file())
        if not day_files:
            continue
        ci = len(cases)
        cases.append({"id": case, "g": _group(case), "v": verdict.get(case, "?"),
                      "f": day_files[0]})
        for fname in day_files:
            ref = parse_day_file(ref_dir / fname)
            new = parse_day_file(d / "OUTP" / fname)
            for run in sorted(set(ref) & set(new)):
                a, b = ref[run], new[run]
                if "date" not in a.columns or "date" not in b.columns:
                    continue
                m = a.merge(b, on="date", suffixes=("|o", "|n"))
                if m.empty:
                    continue
                entry = {"c": ci, "r": int(run), "file": fname,
                         "d": [int((t - epoch).days) for t in m["date"]],
                         "o": {}, "n": {}}
                for v in variables:
                    if f"{v}|o" in m.columns and f"{v}|n" in m.columns:
                        entry["o"][v] = _values(m[f"{v}|o"])
                        entry["n"][v] = _values(m[f"{v}|n"])
                if entry["o"]:
                    runs.append(entry)
    source = (f"{report}  ·  finished {rep.get('finished', '?')}  ·  "
              f"binary {rep.get('exe_sha256', '?')}" if rep else f"{work} (no results.json)")
    return {"vars": variables, "crop": CROP, "water": WATER, "cases": cases, "runs": runs,
            "groups": sorted({c["g"] for c in cases}), "source": source,
            "built": datetime.datetime.now().isoformat(" ", "seconds")}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--work", type=pathlib.Path,
                    default=pathlib.Path(os.environ.get("AQUACROP_WORK", TESTS / "work")))
    ap.add_argument("--out", type=pathlib.Path, default=None,
                    help="output file (default: explorer.html in the work folder)")
    ap.add_argument("--vars", nargs="+", default=DEFAULT_VARS,
                    help="daily variables to include (default: the crop and water sets)")
    ap.add_argument("--fragment", action="store_true",
                    help="write the page without its document wrapper, for publishing it "
                         "as a web page (an artifact) rather than opening it locally")
    a = ap.parse_args()
    work = a.work.resolve()
    if not work.is_dir():
        raise SystemExit(f"no work folder at {work} — run run_tests.py first")
    data = collect(work, a.vars)
    if not data["runs"]:
        raise SystemExit(f"no case in {work} has daily output to compare")
    out = (a.out or work / "explorer.html").resolve()
    payload = json.dumps(data, separators=(",", ":"), allow_nan=False)
    page = TEMPLATE.replace("/*DATA*/", payload)
    out.write_text(page if a.fragment else DOCUMENT.replace("{page}", page))
    print(f"wrote {out}  ({len(data['cases'])} cases, {len(data['runs'])} runs, "
          f"{out.stat().st_size / 1e6:.1f} MB)")


DOCUMENT = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
</head><body>
{page}
</body></html>
"""

TEMPLATE = r"""<title>AquaCrop Run Explorer</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&display=swap">
<script src="https://cdn.jsdelivr.net/npm/plotly.js-dist-min@2.35.2/plotly.min.js"></script>
<style>
/* the palette of the suite's overview page (matrix.html) */
:root{--bg:#eef0f2;--paper:#ffffff;--ink:#12171c;--ink2:#3f4a54;--line:#d9dfe4;--acc:#1b6079;
      --ref:#8a4a12;--new:#1b6079;--mut:#6b7885;
      --sans:"IBM Plex Sans",system-ui,-apple-system,"Segoe UI",sans-serif;
      --mono:"IBM Plex Mono",ui-monospace,Menlo,Consolas,monospace}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#0d1114;--paper:#151b20;
      --ink:#e4e9ed;--ink2:#a9b5be;--line:#28323a;--acc:#6ab5d2;--ref:#d8a066;--new:#6ab5d2;
      --mut:#8d99a3}}
:root[data-theme="dark"]{--bg:#0d1114;--paper:#151b20;--ink:#e4e9ed;--ink2:#a9b5be;
      --line:#28323a;--acc:#6ab5d2;--ref:#d8a066;--new:#6ab5d2;--mut:#8d99a3}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:14px/1.45 var(--sans)}
header{padding:14px 16px 8px;border-bottom:1px solid var(--line);background:var(--paper)}
h1{font-size:18px;margin:0;font-weight:600;text-wrap:balance}
.src{color:var(--mut);font:12px var(--mono);margin-top:3px;overflow-wrap:anywhere}
.bar{display:flex;flex-wrap:wrap;gap:8px 16px;align-items:center;padding:10px 16px;
     background:var(--paper);border-bottom:1px solid var(--line);position:sticky;
     top:env(safe-area-inset-top,0px);z-index:5}
.bar label{font-size:13px;color:var(--ink2)}
select,input{font:inherit;color:var(--ink);background:var(--bg);border:1px solid var(--line);
             border-radius:5px;padding:4px 6px}
input[type=search]{width:min(260px,100%)}
select:focus-visible,input:focus-visible,button:focus-visible{outline:2px solid var(--acc);outline-offset:1px}
.grid{display:grid;grid-template-columns:minmax(0,3fr) minmax(260px,1fr);gap:12px;padding:12px 16px}
@media (max-width:900px){.grid{grid-template-columns:1fr}}
.card{background:var(--paper);border:1px solid var(--line);border-radius:8px;padding:8px}
.card h2{font-size:14px;margin:4px 6px 6px}
#scatter{height:560px}
#rank{max-height:560px;overflow:auto;font-size:12.5px;font-variant-numeric:tabular-nums}
#rank table{width:100%;border-collapse:collapse}
#rank th{position:sticky;top:0;background:var(--paper);text-align:left;color:var(--mut);
         font-weight:600;font-size:11px;padding:4px}
#rank td{padding:3px 4px;border-top:1px solid var(--line);cursor:pointer;white-space:nowrap}
#rank tr:hover td{background:var(--bg)}
#rank td.c{max-width:180px;overflow:hidden;text-overflow:ellipsis}
.detail{margin:0 16px 24px}
.views{display:flex;gap:6px;flex-wrap:wrap;margin:4px 6px 8px}
.views button{font:inherit;font-size:12.5px;border:1px solid var(--line);background:var(--bg);
              color:var(--ink2);border-radius:14px;padding:3px 11px;cursor:pointer}
.views button.on{background:var(--acc);border-color:var(--acc);color:var(--paper)}
#dtitle{font-size:14px;margin:6px}
#dmsg{color:var(--mut);margin:6px}
</style>
<header><h1>AquaCrop Run Explorer</h1><div class="src" id="src"></div></header>
<div class="bar">
  <label for="var">variable</label> <select id="var"></select>
  <label for="grp">group</label> <select id="grp"></select>
  <label><input type="checkbox" id="movedOnly" checked> only days that moved</label>
  <label>colour <select id="colour"><option value="group">by group</option>
      <option value="delta">by relative difference</option></select></label>
  <label>case <input type="search" id="find" list="caselist" placeholder="type a case id, e.g. F14"></label>
  <datalist id="caselist"></datalist>
</div>
<div class="grid">
  <div class="card"><h2 id="stitle"></h2><div id="scatter"></div></div>
  <div class="card"><h2>Cases that moved most</h2><div id="rank"></div></div>
</div>
<div class="card detail">
  <div id="dtitle">Click a dot, a row of the ranking, or pick a case above.</div>
  <div class="views" id="views"></div>
  <div id="dmsg"></div>
  <div id="series"></div>
</div>
<script>
const D = /*DATA*/;
const $ = id => document.getElementById(id);
const css = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim();
const day = d => new Date(d * 864e5);
const fmtDate = d => day(d).toISOString().slice(0, 10);
const PALETTE = ["#1b6079","#b4541f","#2a6349","#8a4a12","#6b4c9a","#a32c22","#3d7f8a",
                 "#8a6a10","#5c6771","#2f5aa8","#9a3f6f","#4d7a2a"];
let state = {v: D.vars.includes("Tr") ? "Tr" : D.vars[0], g: "(all)", open: null, view: "var"};

$("src").textContent = `${D.source} · page built ${D.built} · ${D.cases.length} cases`;
for (const v of D.vars) $("var").add(new Option(v, v));
$("var").value = state.v;
$("grp").add(new Option("(all)", "(all)"));
for (const g of D.groups) $("grp").add(new Option(g, g));
for (const c of D.cases) $("caselist").appendChild(new Option(c.id));

function relScore(o, n) {
  let lo = Infinity, hi = -Infinity, best = 0, at = -1;
  for (let i = 0; i < o.length; i++) {
    for (const x of [o[i], n[i]]) if (x !== null) { lo = Math.min(lo, x); hi = Math.max(hi, x); }
  }
  let rng = hi - lo;
  if (!(rng > 1e-12)) rng = Math.max(Math.abs(hi), Math.abs(lo), 1e-12);
  let first = -1;
  for (let i = 0; i < o.length; i++) {
    if (o[i] === null || n[i] === null) continue;
    const dd = Math.abs(n[i] - o[i]);
    if (dd > 0 && first < 0) first = i;
    if (dd > best) { best = dd; at = i; }
  }
  return {score: best / rng, at, first, rng};
}

function drawScatter() {
  const v = state.v, g = state.g, movedOnly = $("movedOnly").checked;
  const byGroup = $("colour").value === "group";
  const traces = {}, all = {x: [], y: [], cd: [], col: [], txt: []};
  let lo = Infinity, hi = -Infinity, count = 0;
  D.runs.forEach((r, ri) => {
    const c = D.cases[r.c];
    if (g !== "(all)" && c.g !== g) return;
    const o = r.o[v], n = r.n[v];
    if (!o) return;
    const s = byGroup ? null : relScore(o, n);
    for (let i = 0; i < o.length; i++) {
      if (o[i] === null || n[i] === null) continue;
      if (movedOnly && o[i] === n[i]) continue;
      const key = byGroup ? c.g : "all";
      const t = traces[key] || (traces[key] = {x: [], y: [], cd: [], txt: [], col: []});
      t.x.push(o[i]); t.y.push(n[i]); t.cd.push([ri, i]);
      t.txt.push(`${c.id}<br>run ${r.r} · ${fmtDate(r.d[i])}<br>ref ${o[i]} → new ${n[i]}` +
                 ` (Δ ${(n[i] - o[i]).toPrecision(3)})`);
      if (!byGroup) t.col.push(Math.abs(n[i] - o[i]) / s.rng);
      lo = Math.min(lo, o[i], n[i]); hi = Math.max(hi, o[i], n[i]); count++;
    }
  });
  const data = Object.entries(traces).sort().map(([k, t], i) => ({
    type: "scattergl", mode: "markers", name: byGroup ? k : "relative Δ",
    x: t.x, y: t.y, customdata: t.cd, text: t.txt, hoverinfo: "text",
    marker: byGroup ? {size: 5, color: PALETTE[i % PALETTE.length], opacity: .7}
                    : {size: 5, color: t.col, colorscale: "Viridis", cmin: 0,
                       colorbar: {title: "|Δ| / range", thickness: 10}, opacity: .8}
  }));
  if (isFinite(lo)) data.push({type: "scatter", mode: "lines", x: [lo, hi], y: [lo, hi],
                               line: {color: css("--mut"), dash: "dot", width: 1},
                               hoverinfo: "skip", showlegend: false});
  $("stitle").textContent = `${v}: reference (x) against new (y) · ${count.toLocaleString()} ` +
      `day(s)${movedOnly ? " that moved" : ""}${g !== "(all)" ? " · group " + g : ""}`;
  Plotly.react("scatter", data, {
    margin: {l: 55, r: 10, t: 10, b: 45}, paper_bgcolor: "rgba(0,0,0,0)",
    plot_bgcolor: "rgba(0,0,0,0)", font: {color: css("--ink"), size: 12},
    xaxis: {title: `reference ${v}`, gridcolor: css("--line"), zeroline: false},
    yaxis: {title: `new ${v}`, gridcolor: css("--line"), zeroline: false},
    legend: {orientation: "h", y: -0.18}, hovermode: "closest", dragmode: "zoom"
  }, {responsive: true, displaylogo: false});
  drawRank();
}

function drawRank() {
  const v = state.v, g = state.g, rows = [];
  D.runs.forEach((r, ri) => {
    const c = D.cases[r.c];
    if (g !== "(all)" && c.g !== g) return;
    if (!r.o[v]) return;
    const s = relScore(r.o[v], r.n[v]);
    if (s.score > 0) rows.push({ri, id: c.id, run: r.r, s: s.score, first: s.first, at: s.at});
  });
  rows.sort((a, b) => b.s - a.s);
  const top = rows.slice(0, 200);
  $("rank").innerHTML = `<table><thead><tr><th>case</th><th>run</th><th>max Δ/range</th>` +
    `<th>first moved</th></tr></thead><tbody>` + top.map(r =>
      `<tr data-ri="${r.ri}" data-i="${r.at}"><td class="c" title="${r.id}">${r.id}</td>` +
      `<td>${r.run}</td><td>${(100 * r.s).toFixed(1)} %</td>` +
      `<td>${r.first >= 0 ? fmtDate(D.runs[r.ri].d[r.first]) : ""}</td></tr>`).join("") +
    `</tbody></table>` + (rows.length > 200 ? `<p style="margin:6px">${rows.length - 200} more…</p>` : "") +
    (rows.length ? "" : `<p style="margin:6px">nothing moved for ${v}</p>`);
  for (const tr of $("rank").querySelectorAll("tr[data-ri]"))
    tr.onclick = () => openRun(+tr.dataset.ri, +tr.dataset.i);
}

function openRun(ri, i) {
  state.open = {ri, i};
  drawSeries();
}

function drawSeries() {
  if (!state.open) return;
  const {ri, i} = state.open, r = D.runs[ri], c = D.cases[r.c];
  const views = [["var", `this variable (${state.v})`], ["crop", "crop"], ["water", "water"]];
  $("views").innerHTML = views.map(([k, lab]) =>
    `<button data-k="${k}" class="${state.view === k ? "on" : ""}">${lab}</button>`).join("");
  for (const b of $("views").querySelectorAll("button"))
    b.onclick = () => { state.view = b.dataset.k; drawSeries(); };
  const want = state.view === "var" ? [state.v] : D[state.view];
  const vars = want.filter(v => r.o[v]);
  const missing = want.filter(v => !r.o[v]);
  $("dtitle").innerHTML = `<b>${c.id}</b> · ${r.file} · run ${r.r} · verdict ${c.v}` +
      (i >= 0 ? ` · clicked ${fmtDate(r.d[i])}` : "");
  $("dmsg").textContent = missing.length ? `not written by this case: ${missing.join(", ")}` : "";
  const x = r.d.map(fmtDate), data = [], n = vars.length, gap = 0.035;
  const h = (1 - gap * (n - 1)) / Math.max(n, 1), layout = {
    height: Math.max(260, 230 * n), margin: {l: 60, r: 10, t: 10, b: 35},
    paper_bgcolor: "rgba(0,0,0,0)", plot_bgcolor: "rgba(0,0,0,0)",
    font: {color: css("--ink"), size: 12}, hovermode: "x unified", showlegend: true,
    legend: {orientation: "h", y: 1.02, yanchor: "bottom"}, shapes: []};
  vars.forEach((v, k) => {
    const top = 1 - k * (h + gap), mid = top - h * 0.7;
    const ya = `y${2 * k + 1}`, yd = `y${2 * k + 2}`, xa = k ? `x${k + 1}` : "x";
    const o = r.o[v], nn = r.n[v], delta = o.map((a, j) => a === null || nn[j] === null ? null : nn[j] - a);
    data.push({x, y: o, xaxis: xa, yaxis: ya, name: "reference", legendgroup: "ref",
               showlegend: k === 0, line: {color: css("--ref"), dash: "dash", width: 2}});
    data.push({x, y: nn, xaxis: xa, yaxis: ya, name: "new", legendgroup: "new",
               showlegend: k === 0, line: {color: css("--new"), width: 2}});
    data.push({x, y: delta, xaxis: xa, yaxis: yd, name: `Δ ${v}`, showlegend: false,
               line: {color: css("--mut"), width: 1.2}, fill: "tozeroy"});
    const s = relScore(o, nn);
    layout[`yaxis${2 * k + 1}`] = {domain: [mid, top], title: v, gridcolor: css("--line"),
                                  zeroline: false};
    layout[`yaxis${2 * k + 2}`] = {domain: [top - h, mid - 0.01], title: "Δ",
                                  gridcolor: css("--line"), zeroline: true,
                                  zerolinecolor: css("--mut")};
    layout[`xaxis${k ? k + 1 : ""}`] = {anchor: yd, matches: k ? "x" : undefined,
                                       showticklabels: k === n - 1, gridcolor: css("--line")};
    layout.annotations = (layout.annotations || []).concat([{
      text: s.score > 0 ? `max Δ ${(100 * s.score).toFixed(1)} % of range` : "unchanged",
      xref: "paper", yref: "paper", x: 1, y: top, xanchor: "right", yanchor: "top",
      showarrow: false, font: {size: 11, color: css("--mut")}}]);
  });
  if (i >= 0) layout.shapes.push({type: "line", xref: "x", yref: "paper", x0: x[i], x1: x[i],
                                  y0: 0, y1: 1, line: {color: css("--ink"), width: 1, dash: "dot"}});
  Plotly.react("series", data, layout, {responsive: true, displaylogo: false});
}

$("var").onchange = () => { state.v = $("var").value; drawScatter(); drawSeries(); };
$("grp").onchange = () => { state.g = $("grp").value; drawScatter(); };
$("movedOnly").onchange = drawScatter;
$("colour").onchange = drawScatter;
$("find").onchange = () => {
  const ri = D.runs.findIndex(r => D.cases[r.c].id === $("find").value ||
                                   D.cases[r.c].id.startsWith($("find").value + "_"));
  if (ri >= 0) openRun(ri, -1);
};
drawScatter();
const firstRow = $("rank").querySelector("tr[data-ri]");
if (firstRow) openRun(+firstRow.dataset.ri, +firstRow.dataset.i);
const redraw = () => { drawScatter(); drawSeries(); };
try { matchMedia("(prefers-color-scheme: dark)").addEventListener("change", redraw); } catch (e) {}
new MutationObserver(redraw).observe(document.documentElement,
                                     {attributes: true, attributeFilter: ["data-theme"]});
document.getElementById("scatter").on("plotly_click", ev => {
  const p = ev.points && ev.points[0];
  if (p && p.customdata) openRun(p.customdata[0], p.customdata[1]);
});
</script>
"""

if __name__ == "__main__":
    main()
