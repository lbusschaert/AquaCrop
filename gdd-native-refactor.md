# GDD-native phenology refactor

Working notes / design rationale. Status as of **2026-08-03**.

## Goal

In GDD mode, drive phenology from accumulated GDD directly and stop consuming the
calendar-day values produced by the planting-time look-ahead conversion
(`AdjustCalendarDays` / `SumCalendarDays` / `AdjustCalendarCrop`), so the full temperature
record need not be known in advance. End goal: delete that conversion.

**Current strategy (2026-07-16 pivot, still in force):** peel look-ahead consumers off one
at a time. Calendar mode must stay **bit-identical**; GDD mode may diverge, but only in ways
we understand and can bound. The constant-temperature projects are the oracle (see below),
and `testcase/compare_outputs.sh` now tolerates ≤ 0.1 % relative differences so last-digit
GDD rounding doesn't drown out real regressions.

---

## START HERE — picking this up cold

### Where the tree is (end of 2026-07-30)

Branch `dev/remove_Trecord`, clean apart from the usual `testcase/SIMUL/*.SIM` churn (rewritten by
every run, never commit it). Six commits are this refactor; today's three:

| commit | what |
|---|---|
| `dff43fe` | **§15 group B keystone** — `Crop_DayN` = declared end of cropping period. First deliberately output-moving step. `OttawaVeg` run 3 went 0.000 → 9.825 t/ha. |
| `893b5f4` | §14 item 2 — rooting depth off the calendar clock. Byte-identical. |
| `250ed5c` | §14 item 1 — `AdjustEpotMulchWettedSurface` off the calendar clock. Byte-identical. |
| `a681e17` | §11 `Crop_DayN` group A. `c91d332` §12 stale-read fix. `b1a09ec` §10 cleanup. |

Untracked and intentionally **not** committed: `crop-dayn-groupA*.patch` (superseded, but the
`GATEDBG` probe hunks are worth keeping — re-apply if a gate needs re-measuring),
`testcase/gate_debug.py` (the probe parser, still useful), `testcase/compare_runs.ipynb`.

**Both earlier developer questions are answered and both are now implemented** — run length (the
simulation period may extend beyond the crop cycle) and insufficient GDD.

### Developer decisions — 2026-08-03 meeting

Five directions, not options. Each supersedes whatever this document said before.

| # | decision | what it changes |
|---|---|---|
| 1 | **Taking `RatDGDD` from the reference climatology is approved.** | Confirms `9cf093d` / §9. One loose end surfaced while checking it — the two *calibration* sites still compute `RatDGDD` by a different formula than the four runtime sites. See "Still to do". |
| 2 | **`SeasonalSumOfKcPot` does not need the full-season sum** — accumulating to today is acceptable. | Would remove the last reason this walk needs a season length at all, superseding §17's day thresholds. **One reading still to confirm before implementing — see §17.** |
| 3 | **Perennials keep `Crop_DayN` from the declared end of season, permanently.** The internal perennial calendar is a **GUI** feature; the standalone only consumes the date it writes into the PRM. | Confirms the 2026-07-29 decision and settles the §-"Still to do" finding: the engine having no season-generation code is *by design*, not a gap to close. |
| 4 | **Starting a run inside the growing period is no longer maintained.** Those routines and variables can be **dropped**. | Turns §18 / §14 item 4 from "convert, then validate somehow" into "delete". Closes the GUI open question outright. |
| 5 | **Go unbanked everywhere, consistently — as a single pass at the end.** | Supersedes the 2026-07-23 "keep the banked `+1`-day convention for now". See "Banked before today". |

Nothing is waiting on a decision except the one clarification under item 2.

### What is left — the whole list

**The critical path is still one item: finish step A of the deletion (§20).** Items 1 and 2 landed;
detail in §14 (the audit) and the CRITICAL PATH section below. The 2026-08-03 decisions add four
items *behind* it, listed under "Queued by the 2026-08-03 decisions" below — none of them changes
what step A needs.

> **PICK UP HERE (2026-08-21).** The tree is at **`fee3cfa`** — A1 landed and is byte-identical
> (§21). `src/` is clean; nothing is applied. One item is parked, one is closed:
>
> 1. **A2 (§22) is CLOSED — consensus 2026-08-21: `SeasonalSumOfKcPot` keeps the season sum and
>    takes it from the reference climatology, i.e. §17's answer stands.** The season-length question
>    that decision 2 opened is therefore settled, not pending: there is no replacement coming, and
>    §17's conversion is the permanent form. The A2 code stays out of the tree as
>    `a2-gdd-measure.patch` (re-applies cleanly to `fee3cfa`), and §22 is kept only as the record of
>    why three variants were rejected — do not resurrect it without a new decision.
> 2. **Step A is still parked** as `step-a-lookahead-uncalled.patch`, blocked on the one unfound
>    GDD-mode reader of `Crop_DaysToGermination`. **A new instrument is ready and is better than the
>    gdb recipe**: `lookdbg-germination-backtrace.patch` at the repo root prints a real call stack
>    for the first 40 in-loop reads. See §20. **Do not restart by reading code; that has failed twice
>    on this question.**

1. ~~**§14 item 3 — the germination day gate.**~~ **APPLIED 2026-07-31, NOT BUILT — see §16.** New
   `GerminationDay` in `global.f90`; both sites (`run.f90` ~5190, ~7067) converted. It is the first
   gate deliberately **not** built to reproduce the calendar day: it mirrors `DetermineCCiGDD`'s own
   germination test (unbanked, `>`, first-crossing) because its only job is handing that routine its
   starting `CCiPrev`, and firing on the banked calendar day was found to be *destructive* — one day
   of canopy growth overwritten, on every GDD annual run. **Expected to move output**; §16 gives a
   per-project prediction, with `OttawaVegConst` as the case that must stay byte-identical.
2. ~~**§14 item 5 — season length in days for the stress calibration.**~~ **APPLIED 2026-07-31, NOT
   BUILT — see §17.** The audit's scope was wrong both ways: the two `Reference*Relationship` sites
   are dead (they overwrite their day arguments), and a live one it never listed (`Dayi >= L12` in
   `SeasonalSumOfKcPot`) had to be converted. `run.f90` ~4900 now derives its day thresholds on the
   reference climatology via `AdjustCalendarDaysReferenceTnx`, the step the two sibling callers
   already do. Also closes the second half of upstream bug (1). **Expected to move output** on
   variable-T GDD projects. Original text: `SeasonalSumOfKcPot`'s loop
   bound `do Dayi = 1, Lend` with `Lend = DaysToHarvest` (`run.f90` 4900–4901 passes it twice), plus
   the same day set into `ReferenceStressBiomassRelationship` /
   `ReferenceCCxSaltStressRelationship` (`run.f90` 3912–3917, 3979–3984, 4006). The weather half is
   already solved — `run.f90` 4898 passes `ReferenceClimate = .true.`, so these walk the reference
   climatology (§9). Only the day count is still look-ahead, and the inverse function to produce it
   weather-independently already exists: `SumCalendarDaysReferenceTnx(GDDaysToHarvest)`.
3. ~~**Then delete** `AdjustCalendarCrop`, `AdjustCalendarDays`, `SumCalendarDays`, and the
   `MaxAvailableGDD` scan.~~ **STEP A APPLIED 2026-07-31, NOT BUILT — see §20.** The look-ahead is
   no longer *called*: the `MaxAvailableGDD` scan, its guard and the `AdjustCalendarDays` call are
   gone, so in GDD mode the day twins keep their `.CRO` nominal values. `AdjustCalendarCrop` keeps
   only the `GDDaysToFullCanopy` geometry, which needs no weather. **Expected byte-identical — that
   run is the test of sections 11–19.** Step B then deletes the uncalled routines. Note
   `SumCalendarDays` **cannot** be deleted: the forage walk in `AdjustCropFileParameters` keeps it,
   by the §13 finding and the 2026-07-29 decision.

**Queued by the 2026-08-03 decisions — all sit BEHIND step A, in this order:**

- ~~**A1. Delete the mid-season-start path**~~ **APPLIED 2026-08-03, NOT BUILT — see §21.** Done
  ahead of step A rather than behind it: it is pure removal, it does not touch anything step A
  touches, and it shrinks the surface step A has to be validated against. It also takes a **164-line
  temperature-record walk** (`GetSumGDDBeforeSimulation`) out of the tree, which is the branch's own
  goal. `Tadj`/`GDDTadj` were **not** removed — the §18 banner's warning was right, they are the
  forage regrowth inputs and that block is untouched.
- ~~**A2. `SeasonalSumOfKcPot` off the season length**~~ (decision 2). **CLOSED 2026-08-21 —
  consensus is to keep the season sum on the reference climatology, which is what §17 already
  landed (`6b8619c`).** No code change is owed; `a2-gdd-measure.patch` stays out of the tree and
  §22 is kept as the record of the rejected variants. Decision 2's "count to today" is superseded.
- **A3. Step B of the deletion** — remove `AdjustCalendarDays` and `MaxAvailableGDD` once step A is
  byte-identical. `SumCalendarDays` stays (forage). See §20's table.
- **A4. The global unbank** (decision 5). **Last, and in one pass.** Every gate converted in §§11–19
  reproduces the *banked* calendar day by construction, so unbanking earlier mixes two sources of
  movement in a single run and makes the diff uninterpretable. Regenerate `OUTP_REF` with it. Scope
  includes the committed flowering anchor (`DayNrFlowering`'s `crossingDay + 1`), not just the gates.

**Convertible but not on the critical path:**

- ~~**§14 item 4 — `ScorAT1`/`ScorAT2`.**~~ **APPLIED 2026-07-31, NOT BUILT — see §18.** Converted
  with its GDD arm unvalidated by construction; the banking is the open part. Original text: Reads
  `DaysToFlowering`, `LengthFlowering`,
  `DaysToSenescence`, `dHIdt` unconditionally to rebuild the HI accumulators when a run *starts*
  after flowering. Still suite-invisible: no project starts mid-season. Note the new
  `OttawaMaizeDelay` does **not** cover this — a delayed germination is not a late run start.
  **SUPERSEDED 2026-08-03 (developer decision 4): DELETE this path, do not convert it.** Starting a
  run inside the growing period is no longer maintained, so the open GUI question is answered
  ("not supported") and the §18 conversion is replaced by removal. Removal list in the §18 banner.
- **The rooting-depth gate's banking** (§14 item 2). Shipped unbanked and explicitly unvalidated
  because it cannot fire yet. **It goes live the moment the run outlasts the cycle**, which group B
  has made possible. **2026-08-03 (decision 5): unbanked is now the target convention everywhere**,
  so this gate is already in the right form and the open question dissolves — it stops being a
  one-off judgement call and becomes part of the single global unbank pass. Still worth a probe when
  it first fires, to confirm it behaves, but no longer a decision to make.

**Blocked or out of scope, not pending work:**

- ~~**§14 item 6 — `CropStressParametersSoilSalinity`**~~ **APPLIED 2026-07-31 — see §19.** The old
  note here said "fix bug (4) first; converting the reads without it is meaningless". That was
  wrong on both counts: bug (4) *cannot* be fixed without the upstream `.CRO` change (the merged
  `CDecline` is multiplied by `RatDGDD`, so a per-GDD term converts twice), and the reads convert
  perfectly well without it — the denominator stays a day span, and only *which* days changes.
- **`CDecline`** — needs a per-GDD decline magnitude in the `.CRO` (upstream format change). **It
  does NOT block deletion**: since `9cf093d` (`RatDGDD` from the reference climatology) and §12, the
  GDD `CDecline` path reads no look-ahead product. Fidelity item, not a look-ahead item.
- **Forage** — permanently keeps the record, by decision (2026-07-29). So the honest goal statement
  is **"annuals no longer need the temperature record in advance"**, not "the engine doesn't".
  `AdjustCropFileParameters` walks the record and §13 established that walk is *correct*.
- **Irrigation season offsets — CLOSED, no longer a semantics problem.** They read `Crop_DayN`, and
  since §15 that is the user's declared end of season, not a weather-derived maturity date. "Irrigate
  N days before the end" is now a legitimate weather-independent read. No conversion needed.

### Two things this session cost us twice — read before trusting any result

1. **"Zero diff" is only evidence when the changed branch executes.** The
   `AdjustEpotMulchWettedSurface` conversion passed a clean 13-project run that proved *nothing*:
   every project had `Mulch = 0`, no OFF file and 100 % wetted irrigation, so all five edited gates
   were unreachable. Before believing an output-neutral result, check that the guards *upstream* of
   the edited lines can be satisfied by the test data at all. Fix is coverage, then **prove the
   coverage lit** with a measurement (§14: in-season `Ex` fell by exactly the mulch factor while
   off-season `Ex` stayed bit-identical).
2. **Do not diagnose a gate by reading it — measure the output.** §11 finding 4 confidently
   described the insufficient-GDD case as a fertility-stress flip that would collapse the canopy.
   Both the mechanism and the *sign* were wrong: the real effect was `CalculateRootingDepth` never
   being called, and the fix made the crop grow, not die. One glance at the season row — the year
   with the **most** GDD producing **nothing** — would have exposed it. Sanity-check phenology
   claims against the seasonal totals before writing them down.

### CRITICAL PATH to a look-ahead-free GDD mode (2026-07-30)

Goal restated honestly: **annuals no longer need the temperature record in advance**, i.e.
`MaxAvailableGDD` / `AdjustCalendarCrop` / `AdjustCalendarDays` / `SumCalendarDays` can be deleted.
Forage keeps the record by decision. Three steps, in order.

> **Step A LANDED 2026-07-30 (`dff43fe`, §15).** Kept below because the reasoning is the design
> record for why B and C are now possible. Step B is items 1–2 of "What is left" above; step C is
> the deletion.

**A. The keystone — `Crop_DayN` becomes the *planned* end of the cropping period.** Authorised by
the 2026-07-30 run-length decision. It is all in one routine, `ResetCropAndSimulationPeriod`
(`run.f90` ~8072–8095), which today *is* the look-ahead: `MaxAvailableGDD` scans the whole record →
`AdjustCalendarCrop` fills the day twins → `DayN = Day1 + DaysToHarvest - 1` → `Simulation_ToDayNr`
is extended to it, with `AdjustClimRecordTo` / `NextSimFromDayNr` hanging off that.

The replacement already exists in the tree, for forage: `SetCrop_DayN(GetCrop_LastDayNr())`
(`tempprocessing.f90` 2238), where `Crop_LastDayNr` is the PRM's *Last day of cropping period*
(`project_input.f90` 259 → `tempprocessing.f90` 2122, set **unconditionally for every crop**). Every
project in the suite already supplies it. So in GDD mode, do for all crops what forage does:

- `Crop_DayN = Crop_LastDayNr` — a **user-declared, weather-independent** horizon, not a look-ahead
  product. `GetCrop_LastDayNr()` currently has exactly **one** consumer, so this is a small change.
- `Simulation_ToDayNr` then needs no extension: the horizon is known before day 1.
- `MaxAvailableGDD` and `AdjustCalendarCrop` become dead in GDD mode.
- The crop's *actual* end stays the thermal gate — `AfterCropCycle` (§11) and `NoMoreCrop` — which
  is exactly the "run may outlast the cycle" model the decision authorises.

**This also dissolves the irrigation season offsets**, previously filed as an unresolvable semantics
question. "Irrigate N days before the end of the season" is only look-ahead while the end is a
*weather-derived maturity date*. Once `DayN` is the user's declared season end, those reads
(`run.f90` 6229–6230, 4509, 6322, 7935–7943, 6306/6313, `simul.f90` 5672) are reading a legitimate
planned date and need no conversion at all. Strike that item.

Must be **GDD-mode-only** so calendar stays bit-identical. Expect output to move where `DayN` is
read: the irrigation-offset family, and the `EndGrowingPeriod` output string.

**B. The mechanical remainder** — §14 items 2, 3 and 5; items 2 (§14) and 3 (§16) have landed, 5 is
what remains. Item 4 (`ScorAT1/AT2`) is convertible but suite-invisible; item 6 is blocked behind
upstream bug (4), not behind the look-ahead.

**C. Delete** `AdjustCalendarCrop`, `AdjustCalendarDays`, `SumCalendarDays` — only after A and B.

**Correction to a claim carried in the session memory:** `CDecline` does **not** block this goal. It
is blocked on an upstream `.CRO` format change for *physical fidelity* (a per-GDD decline magnitude),
but since `9cf093d` took `RatDGDD` from the reference climatology and §12 forked the last day-based
gate, the GDD `CDecline` path reads **no look-ahead product**. It is a fidelity item, not a
look-ahead item, and deletion does not wait on it.

### Three things not to re-derive

- **Do not** move `AdjustCropFileParameters` onto the reference climatology. Tried, broke Ottawa,
  reverted — §13. A warning comment sits at the call site.
- **Do not** re-investigate `DelayedDays` as the cause of a gate off-by-one. It is 0 in all 39
  runs — §11 finding 1.
- **Do not** derive a gate's arithmetic by reading a nearby routine. Two derived forms were each
  wrong by exactly one day and only the *daily* output showed it. Probe, measure, then write —
  §11.

### Method that works, when a gate has to change

Re-apply the `GATEDBG` hunks from `crop-dayn-groupA-2026-07-29.patch`, run the suite, and parse
with `python3 testcase/gate_debug.py run.log`. It evaluates every candidate gate every day
without affecting the run and prints MATCH / OFF-BY per run. Note `Crop_Day1` does **not**
identify a run — all 13 projects share one calendar — which is why the `GATEDBGRUN` marker
exists. Strip all of it before committing.

---

## What has been done

### 1. Flowering stage → GDD-native (committed, `d042ad1`)

The first landed step. Replaced the flowering look-ahead with an **event + counter**: a
per-run global `Simulation%DayNrFlowering` (Get/Set in `global.f90`; reset to `undef_int` at
`run.f90` ~5019, next to the `SumGDD` reset), **set when `SumGDDadjCC >= GDDaysToFlowering`**,
after which days-after-flowering is derived from it instead of the look-ahead
`DaysToFlowering`. This is the one carried-day-to-day global the refactor needed.

Converted through a shared `FloweringDayNr` + `HasFlowered` (grain/tuber only):

- **WP-decline block** in `DeterminePotentialBiomass`.
- **HI build-up block** in `DetermineBiomassAndYield` (routed `HarvestIndexDay`, WP
  reproductive, main yield gate, pollination window, `tmax1`, `DayCor`×2, `tmax2`, both
  `FractionFlowering` uses).
- **veg/forage yield gate:** dropped the `+ DaysToFlowering` term (provably 0 for
  veg/forage — forced to 0 at crop-file load, never a look-ahead product).
- **fertility-stress + determinancy gate:**
  `subkind_grain .and. DeterminancyLinked .and. HasFlowered .and. dayi > FloweringDayNr + tmax1`
  (the single `HasFlowered` keeps calendar mode exactly, drops the pre-flowering quirk in GDD).

Bit-identical in calendar mode; validated 0-diff on the constant-T oracles at season/harvest.

### 2. CalculateETpot → GDD-native (committed, `3bb4efe`)

`CalculateETpot` (`global.f90` ~8026) now carries **GDD twin arguments** alongside the
calendar ones and builds a single generic stage clock, forking on `ModeCycleVal`:

- New args: `ModeCycleVal, SumGDDpos, GDDL0, GDDL12, GDDL123, GDDLHarvest, SumGDDsinceCut`.
- Generic clock locals `Pos, P0, P12, P123, PHarvest, PsinceCut`:
  - **GDD branch:** `Pos = SumGDDpos - GDDayi` (banked, see "banked before today"), stage
    thresholds from the `GDDL*`, `PsinceCut = SumGDDsinceCut`; `Pos` clamped to 0 on day 1;
    for **non-cutting** crops `PsinceCut = Pos` (since-cut degenerates to since-planting).
  - **Calendar branch:** the old `real()`-of-integer day expressions verbatim → bit-identical.
- The gate, the Kc ageing decline, and the late-season block all read the generic clock.

Both call sites updated to pass the GDD twins (`simul.f90`): `DeterminePotentialBiomass`
(~506) and `BUDGET_module` (~5824). Calendar callers and the look-ahead builders keep
passing Calendar and stay unchanged. Fixed along the way: the `GDDL12` slot now passes
`GDDaysToFullCanopy` (was `GDDaysToFlowering`), and the position uses `SumGDDadjCC`.

**Accepted, understood differences in GDD mode** (calendar mode is 0-diff):

1. **Kc ageing interpolation.** `tRel = (PsinceCut - P12)/(PHarvest - P12)` interpolates the
   ageing decline in GDD, legacy did it in days. Even at constant T a gap remains because the
   day thresholds `L12`/`LHarvest` are *rounded* `SumCalendarDays` conversions of the GDD
   thresholds; the `exp()` ageing curve then amplifies a ~5 % `tRel` offset into ~0.06 (≈8 %)
   in `Kc` near stage end, ≈3 % in the biomass accumulator (measured on OttawaConst). This is
   irreducible without re-introducing the rounded day thresholds — it *is* the refactor.
2. **Off-season transpiration when the cycle can't complete.** If a season can't bank enough
   GDD to reach harvest, the look-ahead leaves `DaysToHarvest = -9` (see "insufficient-GDD
   safety") so the calendar gate `VirtualDay > LHarvest(-9)` masks transpiration
   (`Kc(Tr) = -9`). The GDD gate can't fire (`Pos < GDDLHarvest`), so it keeps a tiny live Kc.
   On OttawaVeg 2016: **CC is bit-identical every day** (crop does *not* die differently);
   only the off-season water balance shifts (`Drain` +9.7 %, `E` −4.1 %), no yield change.
   The `-9` is itself a look-ahead artifact; keeping the crop marginally alive is the honest
   GDD-native answer. **Accepted.**

### 3. Tooling: relative-tolerance comparison

- `testcase/compare_numeric.py` — token-wise comparator. Text tokens must match exactly;
  numeric tokens may differ by ≤ `--rtol` (default **0.001 = 0.1 %**) relative,
  `reldiff = |a-b| / max(|a|,|b|)` (0 for both-zero, 1 for one-zero). Exit 0 exact / 1
  within-tolerance / 2 real-diff / 3 structural.
- `testcase/compare_outputs.sh` — per-file wrapper, classifies `=` / `~` / `x`; only real
  diffs fail. `--rtol R` to tighten/loosen.

### 4. New test: `OttawaConst`

`testcase/LIST/OttawaConst.PRM` (added to `ListProjects.txt`) — the alfalfa perennial
`Ottawa.PRM` with the **temperature file set to `(None)`** instead of a constant `.Tnx`.
`(None)` makes AquaCrop use `SimulParam_Tmin/Tmax` (default 12/28) as a constant for the
whole run (`run.f90` ~3855), so it should reproduce a constant 12/28 record — a check that
the `(None)` path and a constant record agree, plus a constant-T oracle for the perennial.

---

### 5. Landed 2026-07-18 → 07-27 (summary; see commit messages for detail)

| Commit | What |
| --- | --- |
| `e50afb0` | revert DBY + DPB to pristine v7.3, to redo the stage clock without committed scaffolding |
| `fdaf4b5` | DBY/DPB `fSwitch` GDD-native (E1/E2) + the **calendar** test case `OttawaMaizeCal` |
| `ee03839` | HI part 1 (E3): sections 2.5–2.7 + `VegPeriodExceeded`, and the `HItimesAT` exact-HI fix via `Simulation%SumGDDatFlowering` |
| `6ba523d` | HI part 2 (E4): `HarvestIndexDay` on `HImax/GDDaysToHIo`; DPB look-ahead cleanup |
| `9cf093d` | `RatDGDD` from the reference climatology (mean rate + dormant-day exclusion; subkind fork deleted) |

### 6. `TimeToMaxCanopySF` → on the crop's own clock (committed, `1cf7caf`)

New `TimeToMaxCanopySFOnCycleClock` (`global.f90`) runs the same geometry natively on whichever
clock the crop uses and writes `GDDaysToFullCanopySF` directly. Works because
`TimeToMaxCanopySF` is pure canopy geometry (`DaysToReachCCwithGivenCGC` inverts the CC curve
analytically), so fed `GDDCGC` + the GDD stage params it returns a GDD position. **Call it once,
never once per clock** — it mutates `RedCGC`/`RedCCX`. Both `GrowingDegreeDays()` round-trips
deleted; 4 call sites became one-liners. `DaysToFullCanopySF` is no longer maintained in GDD
mode — **and the audit that called this safe was WRONG**: it claimed the remaining readers were
day-slot args to `ModeCycle`-forking callees or dead `DetermineCCi` branches, but
`CCiNoWaterStressSF`'s *entry gate* was not forked, making the unmaintained day value live in
GDD mode. Fixed 2026-07-29 by forking that gate; see *Upstream bug (7)*.

**Why the results change — a weather-dependent answer to a weather-independent question.**
"Does the canopy reach full cover before flowering + `LengthFlowering/2`?" depends only on crop
parameters, so it must be the same every year. On the day clock it wasn't: maize peak CC across
2014/15/16 went **86.9 / 62.9 / 85.8** → **86.9 / 86.1 / 86.6**. In 2015 the day-clock loops ran
`RedCGC 2→0` and `RedCCX 5→32` — a 32 % CCx cut — that never fired in the other two years from
identical crop parameters. See *Upstream bug (3)* for the mechanism.

Season effects: maize 2015 biomass/yield **+11 %**, with `E −46 mm` against `Tr +44 mm` — a
partition shift into transpiration under the larger canopy, water balance conserved. 2014
unchanged. Const-T maize −0.6 % (sign flips: there the day clock walked `RedCGC 3→1`).
Forage/tuber/veg ≤ 0.12 % at season/harvest. `OttawaMaizeCal` exact.

### 7. `DetermineGrowthStage` → on the crop's own clock (committed, `5a0095d`)

The reported growth stage was entirely day-clock. One `ModeCycle` fork now sets the position
(`SumGDD - GDDayi`, banked) and the within-cycle boundaries from the GDD spans. Calendar mode
wraps the same integers in `real(dp)` → bit-identical.

**End of the cropping period is now the end of the crop's thermal cycle**
(`SumGDD >= GDDaysToHarvest`, tested on the sum *including* today, matching the section-7 gate
and `DetermineCCiGDD`). It deliberately does **not** reproduce the day-clock end
(`sum(Crop%Length)`), which is the end of the nominal canopy stages of a single **uncut** cycle
— unrelated to when a perennial stops. `OttawaConst` used to report "after cropping period" for
its last 9 days while CC was ~58 % **and rising** and biomass still accruing 10.44 → 10.70 t/ha.
The thermal end also closes the stage on two dormant days at the end of `Ottawa` run 2 (zero
GDD, zero Tr, flat biomass) that the day clock counted as crop days.

`StageCode` is read only by the two daily-output writers, and the run confirms it: across all
projects the only cells that move are `Stage` and the `DAP` column the writer blanks when
`StageCode == 0`. Biomass, yield, CC, Tr and the water balance byte-identical.

*Dead ends, do not retry:* `GDDaysToSenescence + LengthCanopyDecline(CCx, GDDCDC)` clamped to
`GDDaysToHarvest` fires a day late for grain/tuber (the clamp lands exactly on the cycle end);
adding a `Dayi - DelayedDays > Crop_DayN` clause fires two days early on the perennial.
`Crop%Length` has **no GDD counterpart** — converting it belongs with
`DetermineLengthGrowthStages`, not here.

### 8. Salinity + irrigation test coverage (committed, `5340d50`)

Both subsystems were completely dark: every salt column was `0.000` and every PRM had
`(None)` in the irrigation slot. Note `SalinityConsidered` is already true whenever the crop has
`ECemin < ECemax`, so the *calibration* half ran all along — what was missing is the **runtime**
half, gated on `SaltStress > 0.1`. Added `MaizeSalinity.CRO` (calendar) + `MaizeSalinityGDD.CRO`
(GDD twin, differs only in the cycle-mode line), `SalineSoil.SW0` / `SalineSoilMild.SW0`,
`IrriGen.IRR` (Generate mode, `ECw = 4.0`), and four projects. Suite is now 13 projects.

Result: `SaltProf` 3.8–9.1, `SaltStr` **22–47 %**, `Irri` 117–257 mm. Two stress levels, which
is what the `CCxRed < 10` / `>= 10` branches of `CropStressParametersSoilSalinity` need.

*Gotchas found while building it:* `IrriMode_Inet` sets `SalinityConsidered = .false.` outright,
so net irrigation and salinity are mutually exclusive — use Manual or Generate. Initial `ECe`
above the crop's `ECemax` saturates `CCxRed` at 100 and lands in the `CDecline = 0.001`
fallback rather than the real formula. Initial water below WP makes water stress dominate and
confounds the salinity signal. `Ottawa.SOL` is a single 1.50 m horizon (SAT 46 / FC 29 / WP 13).

### 9. Reference-climate conversion bug fix (committed, `3a727e9`, `43b7966`)

*Upstream bug (1) below.* `GrowingDegreeDays` gained a `ReferenceClimate` logical; when true it
walks the mean daily Tnx of the reference year from day 1 of the cycle (with an exact
`roundc(ValPeriod*DayGDD)` branch when `TnxReferenceFile` is `(None)`). Both
`...ForTnxReference` sites now convert days→GDD **on the reference**; the three non-bug call
sites pass `.false.` and are behaviour-preserving.

Validated first on **pristine** (worktree off `main`, which *is* v7.3) so the measurement was
uncontaminated by this refactor, then cherry-picked. Both codebases show the **same footprint** —
forage, tuber and the three GDD salinity projects move; veg, `MaizeConst` and both calendar
projects do not — which is the evidence the port is faithful. Season/harvest 0.13–0.64 %.
`OttawaMaizeCal` and `OttawaMaizeSaltCal` exact, as required: the fix is inside
`modeCycle_GDDays` blocks.

The new branch is a structural mirror of its inverse `SumCalendarDaysReferenceTnx` — same
`(None)` gate, inverse formula, same array, same wrap. Both `GDDL12SF`/`GDDL12SS` are
initialised before their loops, which matters because Fortran does **not** guarantee
short-circuit `.and.`. Two asymmetries left deliberately: the pair is **not inverse at zero**
(`SumCalendarDaysReferenceTnx(0) = 0`, `GrowingDegreeDays(0) = undef_int`), and the new
function has **no `StartDayNr`** so it can only anchor at day 1.

### 10. Last live day-conversion removed + dead code deleted (2026-07-29)

Two free ones, landed together because of what they do to the census.

- **`simul.f90` §11.1 (`BUDGET_module`)** — the per-day
  `DAP = SumCalendarDays(roundc(SumGDDadjCC), ...) + DelayedDays` in the GDD branch is gone;
  `DAP = undef_int`. Inert: `DAP` is local to `BUDGET_module` and its **only** consumer is the
  `CalculateETpot` call immediately below, which since `3bb4efe` ignores `DAP` in GDD mode.
  This was the identical cleanup already made at the other `CalculateETpot` call site in
  `DeterminePotentialBiomass` (`6ba523d`) and simply missed. `SumCalendarDays` dropped from
  `simul.f90`'s `use ac_tempprocessing` list — no longer referenced there.
- **Sentinel convention:** both sites now write `undef_int` (= -9), not `0` — a dummy DAP should
  look like a dummy. The DPB site was changed `0` → `undef_int` to match. Both equally inert.
- **`RoundedOffGDD` (`tempprocessing.f90` ~1760) deleted** — zero callers anywhere in the tree.
  Takes two `GrowingDegreeDays` sites with it. (`tempprocessing.f90` has no explicit `public`
  list, so it was public-by-default and exported to nothing.)

**Milestone — the record-walking census.** Live call sites before → after:
`SumCalendarDays` **14 → 12**, `GrowingDegreeDays` **5 → 3**. Of the 12 `SumCalendarDays`,
11 are inside the look-ahead itself (`AdjustCalendarDays`, `GDDCDCToCDC`) and die with it;
1 is forage. Of the 3 `GrowingDegreeDays`, **two are the reference-climatology sites**
(`preparefertilitysalinity.f90` 414/630, both passing `ReferenceClimate = .true.` per §9 —
weather-independent by construction) and one is forage.

So: **nothing walks the actual temperature record days→GDD any more except forage
`AdjustCropFileParameters`**, and the running simulation performs no per-day record conversion
at all. That makes the forage item (below) the lone holdout in that direction.

This census stays accurate — the holdout is **not** removable by conversion. §13 tried moving it
to the reference climatology and it broke Ottawa; that call is a legitimate record walk, because
it runs days→GDD (weather-dependent) rather than GDD→days. Freeing perennials needs the online
end-of-season criterion instead; see "Still to do".

### 11. `Crop_DayN` group A — LANDED AND VALIDATED (2026-07-29)

**Applied on the post-§12 baseline (`c91d332`). Output byte-identical across all 13 projects ×
3 runs.** Three attempts were made; the first two guessed the gate arithmetic and were wrong, the
third was measured first and is the one that landed. The earlier attempts were never validated end
to end because bug (7) was polluting every comparison at the time — fixing it first (§12) is what
made this run trustworthy.

**The durable lesson: measure the gate, do not derive it.** Two plausible-looking forms
(`DetermineCCiGDD`'s unbanked `>`, then banked `>`) both failed, and the failure was a single day's
shift that only the daily output revealed. The third form was read off a probe that evaluated every
candidate every day. Cost: one probe, one parser, three iterations — against two silent wrong
answers.

`AfterCropCycle` lives in `global.f90` after `TimeToMaxCanopySFOnCycleClock`. **Six sites
converted**: `run.f90` 7071 (rooting depth) and `simul.f90` 2493 / 2541 / 2596 / 3028 / 4239,
threading `SumGDDadjCC` + `GDDayi` through `CheckWaterSaltBalance`, `calculate_saltcontent`,
`calculate_surfacestorage` and `EffectSoilFertilitySalinityStress` — all reached only from
`BUDGET_module`, which already holds both. No instrumentation was carried over.

**Deliberately NOT converted, beyond the irrigation family:** the two `InitializeSimulationRunPart2`
sites (`run.f90` 5192 / 5290, `GetDayNri() > GetCrop_DayN()`). The parked patch converted them
using `Simulation_SumGDD`; that is unsound. They ask "does this run *start* after the crop end?",
which is a **run-bounds** question asked before the crop clock has advanced — there is no "crop's
position today" yet. The nearby `SumGDDforDayCC` is not a substitute either: it is *already*
banked (`SumGDDfromDay1 - GDDayi`) and clamped at `GDDaysToHarvest`, so passing it would
double-subtract and then never fire. These are group B. They measured MATCH only because no run
in the suite starts after crop end.

**The split (durable — this is the real result of the session).** `Crop_DayN` is not
independent: `run.f90` 8081 is `DayN = Day1 + DaysToHarvest - 1`, so it inherits the look-ahead.
Its 44 reads answer **two unrelated questions**:

- **Group A (~16): "am I inside the cycle *today*?"** — a per-day boolean, answerable online.
- **Group B (~25): "how long is this run?"** — genuinely needed before day 1, still open.

The biophysics is almost all group A, so **`DayN` is not needed for the processes**;
`DetermineCCiGDD` already never consults it.

**The gate, measured over 39 runs** (`gAdj`, MATCH on all **24 GDD annual runs**):

```fortran
if ((ModeCycle == modeCycle_GDDays) .and. (subkind /= subkind_Forage)) then
    AfterCropCycle = ((SumGDDpos - GDDayi) >= real(GDDaysToHarvest, kind=dp))
else
    AfterCropCycle = (VirtualDay > (Crop_DayN - Crop_Day1))
end if
```

Banked (`- GDDayi`) because `DaysToHarvest` counts days needed to *bank* the target, so the
calendar gate fires the day after the sum reaches it. `>=` not `>` because at constant
temperature the banked position lands on the threshold **exactly** (`OttawaVegConst`: 10 GDD/day,
threshold 1400, position 1400.00) and `>` then slips a day. `SumGDDpos` is the crop's own
position (`SumGDDadjCC`), not `Simulation_SumGDD` — they differ for regrowth. Both it and
`GDDayi` must be arguments: `GDDayi` lives in `ac_run`, below `ac_global`.

Left on `Crop_DayN` deliberately: `DetermineCCi` (`simul.f90` 4825, calendar-only routine) and the
whole irrigation season-offset family (`simul.f90` 5669 and the `run.f90` sites — they need an end
*date* or an offset from it, not a boolean).

**As shipped the gate has three arms, not two** — Forage and insufficient-GDD both fall back to the
calendar expression, for the reasons in findings 3 and 4 below. Because Fortran does not guarantee
short-circuit `.and.`, the three conditions are separate `if` statements rather than one chain.

**Findings that must shape a retry:**

1. **`DelayedDays` is a dead end** — it is 0 in all 39 runs. Struck; do not re-investigate.
2. **Constant-temperature projects are the oracle for off-by-one bugs.** They are where
   thresholds are hit exactly; a variable-T suite hides the `>` vs `>=` class entirely.
3. **Forage is excluded — and this is now a SANCTIONED DESIGN DECISION, not a shortcut.**
   *Developer decision, 2026-07-29: perennials may keep taking their end from the project file's
   `Crop_LastDayNr`; the requirement is only that **annuals** no longer need `Crop_DayN`.*
   This removes the last blocker on group A — it no longer waits on upstream bug (5) or on the
   forage `.CRO` design question.

   The technical reason the exclusion is *also* correct: `AdjustCalendarDays` skips `DHarvest` for
   `subkind_Forage`, so its `DaysToHarvest` is the declared season length with `GDDaysToHarvest`
   derived *from* it. Measured: `gOld` never fires on any perennial run, while `gAdj` does — on
   **dormant days**, because `SumGDDadjCC` is clamped exactly at `GDDaysToHarvest` so `>=` is
   trivially true once `GDDayi = 0`. `OttawaConst` is the control: constant 12/28 means 15 GDD
   every day, never zero, and it never fires. A gate that fires on winter dormancy is not a
   cycle-end signal. See *Upstream bug (5)*.

   Consequence: for forage, `Crop_DayN` (and therefore `Crop_LastDayNr` from the PRM) is a
   **permanent input**, not a look-ahead artefact to be removed. §13 already showed its GDD
   budget cannot be made weather-independent. Freeing perennials would need the online
   end-of-season criterion (see "Still to do") and is explicitly **out of scope**.
4. **Insufficient-GDD veg is a whole-season flip that KILLS THE CROP — CONTAINED, not resolved.**
   `OttawaVeg` run 3 has `DaysToHarvest = -9` → `DayN = Day1 - 10`, so `gOld` is true from day 1
   and legacy applies *no* fertility stress all season; `gAdj` never fires, stress applies all
   season, and the canopy collapses (daily `Stage` goes to `-9`, "no growth stage"). Same family
   as §2 accepted difference 2, but far bigger. **Shipped containment:** `DaysToHarvest ==
   undef_int` falls back to the calendar expression, exactly like Forage, so legacy behaviour is
   preserved bit-for-bit and the flip cannot land silently inside an output-neutral refactor.

   **RETIRED 2026-07-30 — and this finding was WRONG about the mechanism.** The diagnosis above
   ("legacy applies no fertility stress; the GDD gate collapses the canopy") mis-identified the
   dominant effect and got the sign of the outcome backwards. What the `-9` actually did is in
   §15: `DayN = Day1 - 10` made `AfterCropCycle` true from day 1, which switched off
   **`CalculateRootingDepth`** (`run.f90` ~7071) for the whole season — no roots, no uptake,
   `Tr = 0`, stomatal stress pinned at 100 %, **zero biomass**. The fertility-stress exemption was
   real but secondary.

   So there was never a choice between two defensible behaviours. Group B gave `DayN` a real date,
   the run started behaving normally (**0.000 → 9.825 t/ha**, `StoStr` 100 % → 0 %), and the
   containment arm was removed as **redundant** — with a sane `DayN` the calendar arm and the
   thermal gate agree that the crop is never past its cycle in such a season. The developer
   decision ("apply stress all season") is satisfied, but by dissolving the dilemma rather than
   picking a side.

   *Lesson worth keeping:* the finding was written from reading the gates, not from measuring the
   output. One look at the season row — the year with the **most** GDD producing **nothing** — would
   have shown immediately that the story was wrong.
5. **In calendar mode `GDDaysToHarvest` is `-9`.** Harmless *because* the fork exists — which
   makes the fork load-bearing, not stylistic.

**Tooling (kept out of the tree; still in `crop-dayn-groupA-2026-07-29.patch`).** A `GATEDBG` probe
in `BUDGET_module` evaluating all candidate gates per day without affecting the run, a `GATEDBGRUN`
marker + `GATEDBGSET` setup dump in `RunSimulation`, and `testcase/gate_debug.py` to parse them
(`--setup` mode diffs per-run setup state between two logs). **`Crop_Day1` does not identify a
run** — every project shares the same calendar — which is why the marker exists; grouping by
`Day1` silently merges all 13 projects. Re-apply the probe hunks if a gate needs re-measuring;
`gate_debug.py` is already in `testcase/`.

**Validation result: byte-identical, all 13 projects × 3 runs.** No reference regeneration needed —
unlike §9/§12 this commit moves nothing. The GDD arm reproduces the gate it replaces exactly;
Forage and insufficient-GDD take the untouched calendar arm; calendar mode is unchanged by
construction. In particular `OttawaVeg` run 3 is identical, confirming the `DaysToHarvest ==
undef_int` fallback catches the insufficient-GDD case rather than letting it flip.

### 12. `DaysToFullCanopySF` stale read fixed (2026-07-29, `global.f90` only)

`CCiNoWaterStressSF` guarded its fertility canopy-decline block with **two** day-based tests
that were never forked on `ModeCycle` — the outer one deciding whether decline applies at all,
the inner one picking before-senescence vs late-season:

```fortran
if ((Dayi > L12SF) .and. (SFCDecline > 0) .and. (L12SF < L123))
    if (Dayi < L123)
```

Everything they guard already forked, so this was the one place where the calendar
`DaysToFullCanopySF` stayed **live in GDD mode**. Harmless until `1cf7caf` stopped maintaining
it there (`TimeToMaxCanopySFOnCycleClock` writes `GDDaysToFullCanopySF` only; the other writers
are calendar-only and no-stress-only). After that, in GDD mode with stress active nothing
assigns it and the gates read whatever was in the `Crop` record — **in a multi-project run, the
previous project's value**. Measured on `OttawaConst`: `L12SF = 5` in the suite (left by
`OttawaVeg`) against `50` run alone.

Both gates now fork into `DeclineActive` / `BeforeSenescence`; calendar keeps its expressions
verbatim, GDD tests `SumGDD` against `GDDL12SF`/`GDDL123`. Interiors untouched.

**Three distinct behaviours — the fix does not, and cannot, restore the old output:**

| | gate reads | |
| --- | --- | --- |
| pre-`1cf7caf` | a **real** day threshold (day-clock geometry + record scan) | the look-ahead being removed |
| `1cf7caf`→`b1a09ec` | a **stale** day threshold | the bug |
| now | the native **GDD** threshold | the only defensible one in GDD mode |

The unforked gate is an upstream v7.3 design flaw; `1cf7caf` only removed the accident that kept
it harmless. So there is **no earlier commit to use as an oracle here**.

**Validation.** All annuals byte-identical including both calendar oracles — their day and GDD
gates flipped on the same day anyway. Only the two perennials move, which is exactly where the
stale value was measured: `Ottawa` season biomass 9.259 → 9.267 t/ha (**+0.09 %**) and
12.091 → 12.092; `OttawaConst` a single last digit on `Y(fresh)`. Largest daily deviation 0.1 mm
on `Ex`, a rounding boundary. **The acceptance test is that `OttawaConst` now gives the same
answer in the suite as run alone** — the property that was broken, and the one that cannot be
explained any other way. Confirmed.

`OUTP_REF` needs regenerating for the two perennials (separate commit, as with `43b7966`).

**Corrects §6's audit**, which listed `CCiNoWaterStressSF` among the callees that fork.

---


### 13. Forage GDD budget onto the reference climatology — TRIED, WRONG, REVERTED (2026-07-29)

**Do not retry this.** The record walk in `AdjustCropFileParameters` (`tempprocessing.f90` ~2065)
is correct and must stay. A warning comment now sits at the call site.

What was tried: `GrowingDegreeDays(LseasonDays, ..., .true.)` and the matching
`SumCalendarDaysReferenceTnx` for `L123`, on the theory that `GDDaysToHarvest` coming out as
**1803 / 2048 / 2104** across 2014/15/16 from identical crop parameters was the same pathology
`TimeToMaxCanopySF` had before `1cf7caf`.

**Why it was wrong — the two cases run in opposite directions.**

| | asks | so the answer must be |
|---|---|---|
| `TimeToMaxCanopySF` (§9) | GDD given → how many **days**? | weather-**independent** (crop property) |
| `AdjustCropFileParameters` | days given → how much **GDD**? | weather-**dependent** |

For a perennial the days are *not* a crop property. `Crop_DayN = Crop_LastDayNr` is read straight
from the project file (`tempprocessing.f90:2245`, "Perennials have their own end of season based
on Temperature"), and `DaysToHarvest = DayN - Day1 + 1`. Ottawa's PRM fixes the cropping period at
21 May → 31 Oct in all three runs, so `LseasonDays = 164` every year and the 1803/2048/2104 spread
is simply the true GDD banked over those 164 days in three different years. That is the right
answer, not a bug.

`GDD1234` and `L1234` are twin descriptions of *the same* season, and the simulation banks GDD off
the actual record. A `GDD1234` measured on any other climate describes a different season, so the
two clocks come apart.

**Measured result.** Ottawa: big diffs, **no production in year 1**. 2014 was the cold year (1803);
the reference climatology sets a budget the crop cannot reach in its 164 days, so the GDD clock
never gets to maturity and everything keyed to fractions of it — senescence at `GDD123`, canopy
decline, HI build-up — is pushed past the end of the season.

**`OttawaConst` was byte-identical, and that is the confirmation, not a reassurance.** Its
temperature file is `(None)`, so `.false.` takes the "given average Tmin/Tmax" branch
(`tempprocessing.f90:977`) and `.true.` takes the `GetTnxReferenceFile() == '(None)'` branch
(`:953`) — both `roundc(ValPeriod * DayGDD)` with the same `DayGDD`. Identical by construction.
The change is a no-op exactly when there is no record and diverges exactly when there is one.

**Correction to the §13 milestone claim (now struck):** the record-walking census is *not* empty
and should not be. This call is a legitimate record walk. The two §9 sites remain the only ones
that had to move to the reference climatology.

**What this did surface — see "Still to do".** The `.CRO` already carries the perennial
end-of-season rule (`AirTCriterion_GDDPeriod`), and the engine reads it and never uses it.

---

### 14. The calendar-twin audit — DONE (2026-07-30)

The task §-"What is left" item 2 asked for: of the **249** `GetCrop_DaysTo*()` / `GetCrop_LengthFlowering()`
read sites across `run.f90` (95), `simul.f90` (82), `global.f90` (60), `tempprocessing.f90` (12),
**which are genuinely live in GDD mode?** Answer: the large counts are almost entirely dead, and
the live set is **six items**, listed below. Method: attribute every site to its enclosing
routine, then for each site decide whether it is (a) inside a calendar `else`/`case default`
branch, (b) a day-slot argument to a callee that forks on `ModeCycle`, or (c) unguarded.

**The §12 lesson was applied:** for category (b) it is not enough that the callee forks — every
*use of the day dummy inside* the callee must be calendar-guarded. Verified at that level for
`CanopyCoverNoStressSF` (total fork; day dummies reach only the `case default` inner function
`CanopyCoverNoStressDaysSF`), `CCiNoWaterStressSF` (fork-complete **only post-§12**; every use of
`Dayi`/`L0`/`L12SF`/`L123`/`L1234` is now calendar-guarded apart from the pass-through to
`CanopyCoverNoStressSF`), `CalculateETpot` (§2), `GetWeedRC`, `HarvestIndexDay` (§6 — ignores
`DaysToFlowerLoc` in GDD), `CCiniTotalFromTimeToCCini` (computes `Tadj`/`DayCC` unconditionally,
but they only feed `CCiNoWaterStressSF`), `CalculateTimeToReachZmin` (`tDaysZmin` is read only in
`CalculateRootingDepth`'s calendar branch).

**Dead in GDD mode — roughly 100 sites, no work needed.** `DetermineCCi` (37, the whole routine is
the `case default` arm of the `simul.f90` 5745–5759 fork, contained `GetNewCCxandCDC` included),
`DetermineCCiGDD` (15 — all day-slot args), `DeterminePotentialBiomass` (5),
`DetermineBiomassAndYield` (6), `DetermineGrowthStage` (3, §7's calendar branch), `GetPotValSF` (3),
`BUDGET_module` (3), `TimeToMaxCanopySFOnCycleClock` (3, both clocks by design),
`AdvanceOneTimeStep` 7022–7026 / 7416–7417 / 7442–7443, `CalculateRootingDepth` 6612–6613
(calendar branch), `EffectSoilFertilitySalinityStress` 4246,
`InitializeSimulationRunPart2` 5119–5128 / 5170–5172 / 5197–5199.

**Look-ahead-internal, load path, writers, group B — not this item.** `AdjustCalendarCrop` (8, dies
with the look-ahead), `CompleteCropDescription` (17, crop-file load), `SaveCrop` (24, file writer),
`LoadCrop` (3), `LoadSimulationRunProject` (4), `ResetCropAndSimulationPeriod` (3),
`EndGrowingPeriod` (1, `DayN = Day1 + DaysToHarvest - 1`), the 8 getter bodies.

**Regrowth/forage-only → OUT OF SCOPE** by the 2026-07-29 decision: `AdvanceOneTimeStep`
6968–6982 (the regrowth adjusted-time-scale block — this *is* upstream bug (5)),
`InitializeSimulationRunPart2` 5073–5081 (`Tadj`, consumed by that same block),
`GetNextHarvest` 3712 (cuttings).

#### The live set — six items

1. **`AdjustEpotMulchWettedSurface` (`simul.f90` 4474, 4499, 4504, 4513, 4521) — 5 sites, group-A
   convertible right now. This is the actionable result.** All five are the same idiom,
   `dayi < GetCrop_Day1() + GetCrop_DaysToHarvest()` = "in season", guarding mulch cover
   (in/off-season), the three `EvapoEntireSoilSurface` decisions and the wetted-surface correction.
   Unguarded, so **live in GDD mode**.

   It is exactly the group-A question and is **algebraically identical to `.not. AfterCropCycle`**:
   `DayN = Day1 + DaysToHarvest - 1`, so `dayi < Day1 + DaysToHarvest` ⟺ `dayi - Day1 <= DayN - Day1`
   ⟺ `.not. (VirtualDay > DayN - Day1)`. The identity holds **even for `DaysToHarvest = -9`**
   (`DayN = Day1 - 10`: both sides say "in season" ⟺ `dayi < Day1 - 9`), and `AfterCropCycle`
   takes its calendar arm there anyway. The caller is `BUDGET_module` (`simul.f90` 5809), which
   §11 already gave `SumGDDadjCC` and `GDDayi` — so the conversion is `dayi` and two arguments,
   the §11 pattern verbatim.

   **Why §11 missed it:** it spells the gate `Crop_Day1 + DaysToHarvest` rather than `Crop_DayN`,
   so the `Crop_DayN` grep that drove §11 never saw it. Expect byte-identical output — §11
   measured `gAdj` MATCH on all 24 GDD annual runs, and this is the same predicate.

2. **`ActualRootingDepthGDDays` (`global.f90` 7757) — a day-clock gate inside the GDD branch.**
   `if ((VirtualDay < 1) .or. (VirtualDay > L1234)) ActualRootingDepthGDDays = 0`, where
   `L1234 = DaysToHarvest`. `ActualRootingDepth` forks at 7676, but it passes **`DAP` and `L1234`
   into the GDD arm**, so the day value is live there.

   Currently masked, and the reason matters: the caller (`run.f90` 7066–7072) has a double gate —
   a `ModeCycle` fork on `SumGDD < GDDaysToHarvest` *plus* §11's `.not. AfterCropCycle` — so
   `VirtualDay > DaysToHarvest` is unreachable **only because `DaysToHarvest` is the true day-count
   of `GDDaysToHarvest` over the same record**. That is precisely the coupling this refactor
   removes. So: converting it is output-neutral today, and **it must be converted before the
   look-ahead can be deleted**, or rooting depth silently collapses to 0.
   Reached from `InitializeSimulationRunPart2` 5295–5297 / 5331–5333 as well.

   **APPLIED 2026-07-30, not yet built.** The plumbing turned out to be free: `GDDL1234` was
   **already a dummy of `AdjustedRootingDepth`** (`rootunit.f90` 53) and **never used** — the caller
   `CalculateRootingDepth` (`run.f90` ~6621) has been passing `GetCrop_GDDaysToHarvest()` into a dead
   parameter all along. So it only needed threading one level down: `GDDL1234` added to
   `ActualRootingDepth` (12 dummies now), passed at all 6 call sites (4 in `rootunit.f90`, plus
   `run.f90` 5294 / 5331 which now pass `GetCrop_GDDaysToHarvest()`), and the contained
   `ActualRootingDepthGDDays` swapped its dead `L1234` dummy for `GDDL1234`. **No calendar twin
   remains in the GDD arm.** `VirtualDay < 1` stays a day test deliberately — "before day 1" is a
   run-bounds question with no look-ahead product in it.

   **Banking left unbanked and UNVALIDATED, on purpose.** The gate cannot fire today (the caller's
   double gate), so the change is output-neutral *and* the suite cannot measure which form is right.
   `AfterCropCycle` banks, but `GDDayi` is not available here without further threading. The comment
   at the site says so explicitly: when group B makes the run outlast the cycle, this gate goes live
   and the banking must be settled **then, with a probe** — §11's lesson — not by derivation. Do not
   assume it agrees with `AfterCropCycle` to the day.

3. **`InitializeSimulationRunPart2` 5188 and `AdvanceOneTimeStep` 7058–7061 — day-clock
   germination.** `GetDayNri() == (GetCrop_Day1() + GetCrop_DaysToGermination())` sets `CCiPrev`
   to `CCoTotal` on the germination day, unforked. Note this is a `==` on an exact day, so it is
   the one gate where the banking convention cannot paper over a mismatch: on the GDD clock the
   crossing is `SumGDD >= GDDaysToGermination` and the "banked before today" rule for a `<`/onset
   direction gate applies (see "Reference facts" — germination matches calendar **unbanked**).

   **APPLIED 2026-07-31, not yet built — §16.** The audit's framing was right about the direction
   and wrong about the target: the gate must agree with `DetermineCCiGDD`, not with the calendar
   day, and matching the calendar day turned out to *destroy* a day of canopy growth rather than
   preserve behaviour.

4. **`ScorAT1`/`ScorAT2` (`run.f90` ~5440–5490) — confirmed live, suite-invisible.** Reads
   `DaysToFlowering`, `LengthFlowering`, `DaysToSenescence`, `dHIdt` unconditionally to rebuild
   the HI accumulators when a run *starts* after flowering. Already known; the audit confirms it
   and adds that `dHIdt` (set from day values in `CompleteCropDescription`) rides along with it.

   **The exact trigger** (established 2026-07-31, so it does not need re-deriving):
   `Simulation_FromDayNr > (DelayedDays + Crop_Day1 + DaysToFlowering)`. Below that the routine
   takes the `ScorAT1 = ScorAT2 = 0` "not yet flowering" arm and reads nothing.

   **Can a project file even reach it? Yes — the engine supports it; whether the GUI offers it is
   OPEN.** Evidence gathered, both directions:

   - There *is* a clamp, `if (Simulation_FromDayNr > Crop_Day1) Simulation_FromDayNr = Crop_Day1`
     (`global.f90` ~5108) — but `AdjustSimPeriod` has **exactly one caller**,
     `initialsettings.f90` ~436, the default startup state. **It is not on the project path.**
     There, `Simulation_FromDayNr` comes verbatim from the PRM (`tempprocessing.f90` 2122 / 2397),
     and `project_input.f90` ~256 reads all four period dates with no cross-validation.
   - Three pieces of machinery exist *only* for this scenario: `GetSumGDDBeforeSimulation`
     (`run.f90` 3730, called at 5083 under exactly `Crop_Day1 < DayNri`, walking the record to
     reconstruct `SumGDD` between planting and the run start), `InitializeSimulationRunPart2`'s
     rebuild of `CCiPrev` from the canopy curve, and this item. That is a designed case, not an
     accident.

   ~~**Open question for the main developer (2026-07-31): does the GUI let a user create a project
   whose simulation period starts after the cropping period?**~~ **ANSWERED 2026-08-03 — starting a
   run inside the growing period is NO LONGER MAINTAINED, and the routines and variables serving it
   can be dropped.** So this item is not a conversion at all: it is a deletion. See the banner on
   §18 for what goes with it and the one shared piece (`Tadj`/`GDDTadj`) that must not. The recipe
   below is retained only as the record of what the path *was*.

   **Recipe for the test project, if it is ever wanted** — worked out and then parked, so it is not
   re-derived. Clone `OttawaMaize.PRM`, leave the cropping period at 21 May – 31 Oct, and set
   *First day of simulation period* to **27 June** in all three runs. Measured adjusted flowering
   dates and the `ScorAT1` interpolation window (`LengthFlowering/2`):

   | run | flowers | window ends | 27 Jun lands |
   |---|---|---|---|
   | 2014 | 24 Jun | 28 Jun | inside → interpolation arm |
   | 2015 | 26 Jun | 2 Jul | inside → interpolation arm |
   | 2016 | 21 Jun | 25 Jun | past → `ScorAT1 = 1` arm |

   Both arms from one project; `ScorAT2`'s window (858 GDD of HI build-up, ~60–70 days)
   interpolates in all three. A calendar twin on `MaizeCalwpy.CRO` would give the bit-identity
   oracle the conversion needs, the way `OttawaMaizeCal` does. Bonus coverage: it is the only way
   to light `InitializeSimulationRunPart2`'s mid-season branch, dark today because every project
   starts on or before `Crop_Day1`. Expect it to surface pre-existing bugs on that dark path —
   upstream findings, not regressions.

5. **Season *length* in days for the stress calibration.** `SeasonalSumOfKcPot`'s main loop is
   `do Dayi = 1, Lend` with `Lend = DaysToHarvest` (`run.f90` 4900–4901 passes it twice, as
   `L1234` and as `Lend`), and `RelationshipsForFertilityAndSaltStress` (`run.f90` 3912–3917,
   3979–3984, 4006) passes the same day set into `ReferenceStressBiomassRelationship` /
   `ReferenceCCxSaltStressRelationship`. **Live, but the weather half is already solved:**
   `run.f90` 4898 passes `ReferenceClimate = .true.`, so these walk the reference climatology, not
   the record (§9). What is still look-ahead is only the *day count*, and the inverse function to
   produce it weather-independently already exists — `SumCalendarDaysReferenceTnx(GDDaysToHarvest)`.
   So this is a real conversion path, not a blocker.

6. **`CropStressParametersSoilSalinity` (`simul.f90` 4280–4283) — live via upstream bug (4).**
   The day args reach `L12SS` in GDD mode because `L12Double`/`L12SSmax` are only assigned in the
   calendar branch and keep their init value `L12`. Already logged as upstream bug (4); recorded
   here so the audit is complete. Converting the reads without fixing the bug would be meaningless.

#### Item 1 APPLIED 2026-07-30 — awaiting build + suite

`AdjustEpotMulchWettedSurface` now takes `SumGDDadjCC_in` + `GDDayi` and evaluates
`AfterCropCycle` **once** into a local `AfterCycle` (a function call must not sit inside the
`.and.` chains — Fortran does not guarantee short-circuit). All five tests became
`.not. AfterCycle`, except the after-season one at the old 4504 which became `AfterCycle` — it is
the exact complement (`dayi >= Day1 + DaysToHarvest` ⟺ `dayi - Day1 > DayN - Day1`). The single
call site `BUDGET_module` (`simul.f90` ~5830) passes its existing `SumGDDadjCC` / `GDDayi` dummies;
no threading needed, no other caller exists. The routine now contains no `DaysToHarvest` read.

**Built and run 2026-07-30: zero diff, all 13 projects × 3 runs — AND THAT RESULT IS VACUOUS.**
The developer spotted why: there are no mulches in the testcase. Investigated, and it is worse than
mulch alone — **all five converted gates are unreachable in the suite**, so the run proves only that
nothing else was perturbed:

| gate | guard | why it cannot show |
|---|---|---|
| 1 mulch in/off-season | `Epot × (1 − EffectMulch·Cover)` | `Mulch = 0` in **both** `Ottawa.MAN` and `Ottawa2.MAN`, and every project has `(None)` for the OFF file so `NoManagementOffSeason` sets `SoilCoverBefore/After = 0` → all three arms give `Epot = EpotTot` |
| 2 in-season wetted | `IrriFwInSeason < 100` | `IrriGen.IRR` (the only IRR file) declares **100 %** wetted |
| 3 off-season wetted | `IrriFwOffSeason < 100` | no OFF file → `NoManagementOffSeason` default **100** |
| 4 in-season `Inet` | `IrriMode_Inet` | the only IRR file is Generate mode; §8 excluded Inet because it forces `SalinityConsidered = .false.` |
| 5 wetted correction | `.not. EvapoEntireSoilSurface` | gates 2/3 are the **only** writes that can set it `.false.` (the sole other write is `run.f90` 4808, `.true.`), so it stays `.true.` for the whole suite |

**Durable lesson, worth more than the patch: "zero diff" is only evidence when the changed branch
executes.** Before believing an output-neutral result, check that the guards *upstream* of the
changed lines can be satisfied by the test data at all. This is the §8 failure mode recurring —
there, whole subsystems were dark; here, five gates inside a live routine are.

**Coverage added 2026-07-30** (mirrors how §8 lit up salinity/irrigation):

- `testcase/DATA/OttawaMulch.MAN` — `Ottawa2.MAN` with mulch cover `0 → 50 %`. With
  `EffectMulchInS = 50` the in-season factor becomes `0.75` while the off-season factor stays
  `1.0` (`SoilCoverAfter = 0`), so **gate 1 becomes observable** — and deliberately without an OFF
  file, so the difference is purely the in/off-season split being tested.
- `testcase/DATA/IrriGenFw.IRR` — `IrriGen.IRR` with wetted fraction `100 → 50 %`, so
  `IrriFwInSeason < 100` and **gates 2 and 5 fire** once irrigation occurs in season (Generate mode
  delivers 117–257 mm per §8).
- `testcase/LIST/OttawaMaizeMulch.PRM` — `OttawaMaize.PRM` (GDD maize, `MaizeGDDwpy.CRO`) rewired to
  those two files in all three runs. Added to `ListProjects.txt`; the suite is now **14** projects.

**Gates 3 and 4 remain uncovered**, deliberately: gate 3 needs an OFF file carrying off-season
irrigation events *and* `IrriFwOffSeason < 100`; gate 4 needs an `Inet` project. Mitigating fact —
all five gates read the **same** local `AfterCycle`, computed once, so what is untested in 3 and 4
is only the `.not.` polarity, which is settled by inspection and by the algebra above.

#### VALIDATED 2026-07-30 — and this time the result means something

Protocol used: `OUTP_REF` for `OttawaMaizeMulch` generated on **HEAD** (i.e. the legacy day gate),
then the `simul.f90` patch reinstated and re-run → **zero diff**. That isolates this change alone,
which a pristine comparison could not (see below).

**Proof the gates actually executed** (this is the part the first run lacked):

| evidence | measurement |
|---|---|
| IRR file loaded, `Irrigation > 0` in season → **gate 2 fires** | Irri totals **183.5 / 106.8 / 246.1 mm** across runs 1/2/3 |
| the in/off-season transition falls **mid-run**, so the gate decides a real boundary | 345 in-season vs 147 off-season day-rows; run 1 turns `DAP = -9, Stage = 0` on 17 Oct 2014 |
| **gate 1 routes a 25 % swing**, and only in season | mean `Ex` in-season `0.997 → 0.726` (ratio 0.728 ≈ the exact `1 − 0.5·0.5 = 0.75` mulch factor) while off-season `Ex` is **1.539 → 1.539, unchanged** (`SoilCoverAfter = 0`) |

The off-season column being bit-identical while the in-season column moves 25 % is the clincher:
it is the **gate**, not the mulch parameter, that separates the two regimes. So zero diff now means
the GDD cycle-end gate selects the *same transition day* as `Day1 + DaysToHarvest` — the real
confirmation §11's `gAdj` MATCH predicted, on a path where a one-day error would have shown as a
0.27 mm step in `Ex`.

**Coverage actually achieved: gates 1 (both arms), 2, and 5 (both arms** — once gate 2 sets
`EvapoEntireSoilSurface = .false.`, the gate-5 block sits *outside* the `Irrigation > 0` guard and
so runs every day, off-season included**). Gates 3 and 4 still never fire:** gate 3 needs
`Irrigation > 0` **after** the season (off-season `Irri` is 0.0 on every day, since off-season
irrigation events live in the absent OFF file) and gate 4 needs an `Inet` project. Both remain
covered only by inspection plus the shared-local argument above.

**Original protocol note — do NOT use `OUTP_ORIG`/`compare_pristine.sh` here.**
For a GDD project a pristine diff bundles *every* conversion landed since `d042ad1`, so it cannot
isolate this one. Isolate it instead by running `OttawaMaizeMulch` **twice on the current build**,
with and without the `simul.f90` patch (`git stash` it), and diffing those two outputs:

- **zero diff** ⇒ the GDD cycle-end gate flips on the same day as `Day1 + DaysToHarvest` on paths
  that now genuinely matter — the real confirmation §11's `gAdj` MATCH predicted.
- **any diff** ⇒ the day and GDD cycle-ends disagree here; that is the interesting case and must be
  understood before committing, not tolerated.

Then adopt the with-patch output as this project's `OUTP_REF`, and (separately, for completeness)
add the pristine output to `OUTP_ORIG`. Look at `E`, `Ex` and `Drain` first — these five gates only
steer soil evaporation and wetted fraction, nothing in the canopy or yield path.

**Ordering that falls out of this.** Items 1 and 2 are mechanical, output-neutral and unblocked —
do them together, 1 first because it is the pure §11 pattern and 2 needs a decision about whether
to pass a boolean in or thread `GDDayi` down into `rootunit.f90`. Item 3 is small but is a genuine
behaviour question (unbanked onset gate). Item 5 is a real conversion with an existing inverse
function. Item 4 is convertible but untestable by the suite. Item 6 is blocked on an upstream bug.

**None of the six is blocked on the group-B run-length question.** That question still gates group
B, but it does not gate any of this.

---


### 15. Group B keystone — `Crop_DayN` is now the declared horizon (2026-07-30, APPLIED, not built)

Per the critical path above. **GDD mode only**, so calendar stays bit-identical.

Both `DayN` assignments now fork:

- **`tempprocessing.f90` ~2279 (`LoadSimulationRunProject`)** — the live one. `Crop_DayN =
  Crop_LastDayNr`, the project file's *Last day of cropping period*, instead of
  `Day1 + DaysToHarvest - 1`. Safe here because `Crop_LastDayNr` is still the PRM value at this
  point (set unconditionally at ~2122); the runtime overwrite in `InitializeSimulation`
  (`global.f90` 5055/5057) happens later. Forage is unaffected — it already set `DayN` from
  `Crop_LastDayNr` and then `DaysToHarvest = DayN - Day1 + 1`, so the old expression round-tripped.
- **`run.f90` ~8083 (`ResetCropAndSimulationPeriod`)** — same fork. Arguably *more* correct here:
  this routine runs after a delayed germination shifted `Crop_Day1`, and the old expression dragged
  the end of the cropping period along with it, translating the whole declared period later in the
  calendar because the seed sat in dry soil.

**`Crop_LastDayNr` is a runtime working variable, not a durable input** — worth knowing before
reading it anywhere else. `global.f90` 5055/5057 overwrites it with either `Crop_DayN` or
`DayNrPrematureEnd - 1`. The PRM value survives only in `ProjectInput(NrRun)%Crop_LastDayNr` and in
the load-path window used above.

**Consequence — the identity is broken on purpose.** In GDD mode
`DayN /= Day1 + DaysToHarvest - 1` any more: `DayN` is the declared horizon, `DaysToHarvest` stays
the crop's own cycle length. Anything assuming the identity must be rechecked. Two known spots:
`EndGrowingPeriod` (`global.f90` ~6865) still recomputes the old expression locally for its output
string and will now disagree with `Crop_DayN`; and §14 item 1's gates are safe *only* because they
went through `AfterCropCycle`, whose GDD arm is thermal and never reads `DayN`.

**Moves output** — the first deliberately non-neutral step. `EndGrowingPeriod` turned out to have
**zero callers** (dead code, like the §13 perennial-block getters), so the movers are the irrigation
season-offset family and the case below. `OttawaMaizeCal` / `OttawaMaizeSaltCal` must stay exact
against pristine — that is the check that the fork is correctly scoped.

#### The result that mattered: `OttawaVeg` run 3 went from dead to normal

Measured, build of 2026-07-30. Runs 1 and 2 unchanged (8.630 / 9.428 t/ha). Run 3 (2016):

| | Tr/Trx | StoStr | BioMass | Brelative | Y(dry) | Cycle |
|---|---|---|---|---|---|---|
| before | **0 %** | **100 %** | **0.000** | −9 | 0.000 | 155 |
| after | 100 % | 0 % | **9.825 t/ha** | 75 | 8.3 | 156 |

**Mechanism, and it is not what §11 finding 4 claimed.** `DaysToHarvest = -9` gave
`DayN = Day1 - 10` — a date ten days *before planting* — so `AfterCropCycle` answered "past the end
of the cycle" on **every day from day 1**. The lethal consequence is the rooting-depth gate at
`run.f90` ~7071, `if (... .and. (.not. AfterCropCycle(...)))`: always-true gate → `.not.` always
false → **`CalculateRootingDepth` never called all season**. No roots, no water uptake, `Tr = 0`,
stomatal stress pinned at 100 %, zero biomass. The fertility-stress exemption at `simul.f90` 4239 is
real but secondary.

**Why the new answer is the physical one:** 2016 has the **most** GDD of the three years (1283 vs
1042 / 1139) and now produces the largest biomass, with sensible stresses (`TempStr` 33 %,
`ExpStr` 5 %) instead of a degenerate 100 % stomatal. A warm year producing nothing was the tell.

The `-9` never meant "this crop fails" — it meant "the look-ahead could not find a harvest date",
and that sentinel leaked into a gate asking an entirely different question.

#### `AfterCropCycle` third arm removed (same step)

With `DayN` a real date the `DaysToHarvest == undef_int` arm is **redundant, not load-bearing**:
the calendar arm reads false all season, and the thermal gate does too (a season that cannot bank
`GDDaysToHarvest` never reaches it). Dropped from `global.f90` ~2403, leaving the two-arm
GDD/Forage fork. Expected near-zero-diff on top of group B — if `OttawaVeg` run 3 moves *again*
when the arm goes, the two arms disagree somewhere and that needs explaining before committing.

#### New coverage: `OttawaMaizeDelay.PRM` — delayed germination

`run.f90` ~8083 sits in `ResetCropAndSimulationPeriod`, which only runs when
`DelayedDays > 0 .and. Germinate`. §11 finding 1 established `DelayedDays = 0` in all suite runs —
which was recorded as a reason to *stop investigating it*, and was about to be reused as a reason to
ship the site untested. **Wrong instinct, and the same one as the vacuous mulch zero-diff: a blind
spot is to be closed, not documented.** (Developer's call, 2026-07-30.)

`CheckGermination` (`simul.f90` 1316) delays while
`RootZoneWC_Actual < WP + (FC - WP) * TAWGermination/100`, measured over `Zroot = Crop_RootMin`, and
pins `SumGDD = 0` for each delayed day. With `Ottawa.SOL` (SAT 46 / FC 29 / WP 13),
`Ottawa.PPn` `TAWGermination = 20 %` and maize `RootMin = 0.30 m`, the threshold is
**16.2 vol%**. So:

- `testcase/DATA/DryTopSoil.SW0` — a single 1.50 m layer at **14.00 vol%**, below the threshold, so
  sown maize cannot germinate on day 1 and waits for rain (~6.6 mm over the top 0.30 m). 14 rather
  than 13 (WP) deliberately: far enough below to guarantee a delay, close enough that germination
  reliably happens rather than the season failing outright.
- `testcase/LIST/OttawaMaizeDelay.PRM` — `OttawaMaize.PRM` with that SW0 in all three runs. Suite is
  now **15** projects.

**Verify the coverage before trusting the result** — the lesson of §14. `DelayedDays > 0` is
confirmed by germination happening later than in `OttawaMaize`: first day with `CC > 0` should be
later, and the season `Cycle` length shorter. If it germinates on day 1 anyway, lower the SW0 water
content toward 13.00; if it never germinates, raise it toward 15.00.

### 16. §14 item 3 — the germination day gate (2026-07-31, APPLIED, not built)

Critical-path item 1. New `GerminationDay(DayNri, SumGDDpos, GDDayi)` in `global.f90`, immediately
after `AfterCropCycle`, replacing `GetDayNri() == (GetCrop_Day1() + GetCrop_DaysToGermination())`
at both sites — `InitializeSimulationRunPart2` (`run.f90` ~5190) and `AdvanceOneTimeStep`
(`run.f90` ~7067). Calendar arm is the old expression verbatim → bit-identical. The two sites
partition on `DayNri > Simulation_FromDayNr` (the run's first day belongs to the initialiser), which
is a run-bounds test with no look-ahead in it and stays a day test.

**The GDD arm is deliberately NOT built to reproduce the calendar day.** Every gate converted so far
was; this one must not be, and that is the whole finding:

```fortran
GerminationDay = (SumGDDpos > GDDtarget) .and. ((SumGDDpos - GDDayi) <= GDDtarget)
```

Unbanked, `>`, plus an edge detector — because `SumGDDpos - GDDayi` *is* yesterday's sum, so the
crossing day is identifiable without carrying state (no `DayNrFlowering`-style anchor needed).

**Why unbanked here when everything else banks.** The gate exists for exactly one purpose: to hand
`DetermineCCiGDD` its starting `CCiPrev` on the day it starts growing the canopy. That routine's own
entry gate is `SumGDDadjCC <= GDDaysToGermination → CCiActual = 0` (`simul.f90` ~3518) — unbanked,
strict `>`. The handoff and the engine must agree by construction, so the gate is that same test.
This is the `<`/onset direction the "Reference facts" section already flags as matching calendar
**unbanked**, opposite to every harvest-direction gate converted so far.

**And firing on the calendar day is not neutral, it is destructive.** `SumCalendarDays` returns the
days needed to *bank* the target, so the day expression fires **one day after** the GDD engine
started growing. By then `CCiPrev` carries yesterday's `CCiActual` (`run.f90` 7288 sets it at end of
day), and writing `CCoTotal` over it throws the first day of canopy growth away. Traced on
`OttawaMaizeConst` (12 GDD/day, `GDDaysToGermination = 20`), `d = DayNri - Day1`:

| day | `SumGDD` | engine (`simul.f90` 3518) | old gate | effect |
|---|---|---|---|---|
| `d=0` | 12 | `12 <= 20` → CC = 0 | — | |
| `d=1` | 24 | `24 > 20` → grows to `CCo·e^(12·CGC)` | — | `CCiPrev` was 0, branch 2.a |
| `d=2` | 36 | grows | **fires** → `CCiPrev := CCoTotal` | branch 2.a again → **CC(d=2) = CC(d=1)** |

Calendar mode cannot have this: `DetermineCCi` germinates on the same banked day (`VirtualTimeCC ==
DaysToGermination`) and repairs `CCiPrev` itself at `simul.f90` 4911. GDD mode's counterpart repair
(`simul.f90` 3567) is **dead code in v7.3** — it sits inside the `else` of `SumGDDadjCC <=
GDDaysToGermination` yet tests `abs(SumGDDadjCC - GDDaysToGermination) < epsilon`, which the entry
gate has already excluded. So in GDD mode the day-clock reset stood alone, and the conversion
removes it. Left in place; noted for the upstream list.

**No Forage arm**, unlike `AfterCropCycle`: both sites are in the `DaysToCCini == 0` (sown or
transplanted) branch, which regrowth never reaches, so the clamped regrowth position that forced
that exclusion cannot occur here. A perennial's **sowing year** does go through it —
`AlfOttawaGDD.CRO` is "crop is sown in 1st year" — so `Ottawa`/`OttawaConst` **run 1** is in scope
and runs 2/3 are not.

#### VALIDATED 2026-07-31 — measured footprint, and the prediction that was wrong

Built and run over all 15 projects × 3 runs. **The falsifiable prediction held** (`OttawaVegConst`
byte-identical) and **both calendar oracles are byte-identical**, so the fork is correctly scoped.
But the *size* of the footprint was over-predicted, and the reason is a mechanism the derivation
missed — §11's lesson again, in a milder form.

| moved | unchanged |
|---|---|
| `OttawaTuber`, `OttawaTuberConst` (all 3 runs) | `OttawaVegConst`, `OttawaMaizeConst`, `OttawaMaizeSaltConst` |
| `OttawaVeg` (all 3 runs) | `Ottawa`, `OttawaConst` (perennial, **including the sown year 1**) |
| all five GDD maize projects — **run 2 (2015) only** | `OttawaMaizeCal`, `OttawaMaizeSaltCal` (calendar) |

Predicted-but-did-not-move: `OttawaMaizeConst` and `OttawaConst` run 1. Both are **sown**, and that
is the whole explanation:

**The reset is only destructive outside the protected-seedling branch.** `CheckGermination` sets
`Simulation%ProtectedSeedling = .true.` for `plant_Seed` and `.false.` for a transplant. In
`DetermineCCiGDD` branch 2.a (`simul.f90` ~3618) a protected seedling gets CC from the **analytic**
`CanopyCoverNoStressSF` curve — a function of `SumGDDadjCC` alone, which never reads `CCiPrev` — so
overwriting `CCiPrev` there changes nothing. An unprotected one gets
`CCoAdjusted * exp(CGCGDDSF · GDDayi)`, which *is* the increment form, and there the overwrite costs
a day. So:

- **transplanted crops (tuber, veg) are never protected** → every run moves, wherever the banked and
  unbanked crossing days differ;
- **sown crops (maize, alfalfa) are protected** until `CCiActual > 1.25·CCoTotal`, which normally
  still holds on the reset day → no effect. Maize 2015 is the exception because its first canopy day
  banked 13.5 GDD in one step, jumping CC past `1.25·CCoTotal` immediately and ending protection
  before the reset landed.

**The clearest single piece of evidence is `OttawaMaizeDelay` run 2**, where the reference output
has the canopy going *backwards* during establishment:

| date | GD | CC before | CC after |
|---|---|---|---|
| 27-5-2015 (DAP 3) | 13.4 | 0.7 | 0.7 |
| 28-5-2015 (DAP 4) | 9.2 | **0.6** | **0.9** |

CC falling 0.7 → 0.6 while the crop is establishing is not a model behaviour, it is the reset
recomputing `CCo·exp(CGC·GDDayi)` on a day with less GDD than the day before. That row is the
artifact, isolated.

**The entry gate was not touched, and the measurement confirms it:** the first day with `CC > 0` is
the same in both runs everywhere. Only the *value* on the reset day and after it changes.

Magnitudes, all in one direction (canopy a day less penalised → `Tr` up, `Ex` down, biomass up):

| project | run | BioMass t/ha | Y | Tr |
|---|---|---|---|---|
| `OttawaTuberConst` | 1 | 7.552 → 7.690 (+1.8 %) | 5.664 → 5.768 | 157.9 → 160.6 |
| `OttawaTuber` | 1 | 7.549 → 7.661 (+1.5 %) | 5.662 → 5.746 | 157.8 → 160.2 |
| `OttawaVeg` | 1 / 2 / 3 | 8.630 → 8.763 / 9.428 → 9.498 / 9.825 → 9.829 | | |
| `OttawaMaize` | 2 | 20.645 → 20.949 (+1.5 %) | 9.909 → 10.056 | 258.3 → 262.8 |

Cycle lengths, row counts and the perennial `*evaluation.OUT` files are unchanged; `harvests.OUT`
moves exactly where `season.OUT` does. No phenology shifted — this is canopy magnitude only.

**Correction to what this section claimed before the run:** "one day of canopy growth thrown away, on
every GDD annual run" was too strong. It is thrown away on every run where the reset day falls
*outside* the protected-seedling analytic branch. The claim was derived from `CCiPrev` and the branch
structure at `simul.f90` 3612 without noticing that 3618 discards `CCiPrev` entirely.

`OUTP_REF` needs regenerating for the eight moved GDD projects. The calendar oracles are untouched,
so their pristine-generated references stay as they are.

#### Predicted footprint — and one prediction that can falsify the form

**This step moves output** (the second deliberate one, after §15): GDD canopy development starts one
day earlier for sown/transplanted crops. Const-T arithmetic, `d = DayNri - Crop_Day1`:

| project | GDD/day | target | old gate | new gate | expected |
|---|---|---|---|---|---|
| `OttawaVegConst` | 10 | 70 | `d=7` | `d=7` | **byte-identical** |
| `OttawaMaizeConst` | 12 | 20 | `d=2` | `d=1` | 1 day earlier |
| `OttawaTuberConst` | 17 | 200 | `d=12` | `d=11` | 1 day earlier |
| `OttawaConst` run 1 | 15 | 5 | `d=1` | `d=0` | 1 day earlier |
| `OttawaMaizeCal`, `OttawaMaizeSaltCal` | — | — | — | — | **exact** (calendar arm) |

**`OttawaVegConst` is the discriminating case**: 10 GDD/day against a target of 70 lands on the
threshold exactly, so banked and unbanked coincide and *nothing may move*. If it moves, the edge
detector is wrong — that is the §11 lesson turned into a prediction that can be checked without a
probe. `OttawaMaizeDelay` should move furthest: the day expression ignores `DelayedDays` entirely
while `CheckGermination` zeroes `Simulation%SumGDD` for every delayed day, so the GDD gate waits for
the real germination and the day gate never did.

Direction of the move: canopy one day ahead through the exponential phase → biomass/yield up
slightly. Check `CC`, then `BioMass`; the water balance follows the canopy.

*(Kept as written before the run, because the measured result above is only interesting against it:
the const-T gate days were right, but "gate day moved" turned out not to imply "output moved".)*

---

### 17. §14 item 5 — season length for the stress calibration (2026-07-31, APPLIED, not built)

> **SETTLED 2026-08-21 — THIS SECTION IS THE ANSWER.** Consensus: `SeasonalSumOfKcPot` keeps the
> **full-season** Kc sum and takes it from the **reference climatology**, which is exactly what this
> section landed (`6b8619c`). Decision 2's "counting up to today would be fine" is superseded, and
> the clarification recorded below is now moot — kept only because it is the measurement that ruled
> reading (a) out at −11.5 %. **Nothing here is provisional any more; do not revert it, and do not
> resurrect §22 without a new decision.**
>
> The rest of this banner is the 2026-08-03 state, kept for the record:
>
> **DEVELOPER DIRECTION 2026-08-03 (decision 2): `SeasonalSumOfKcPot` does not need the full-season
> sum — "counting up to today would be fine".** If implemented, this removes the *reason* this
> section exists: with no season length in the walk there is no day threshold to put on the
> reference climatology.
>
> The conversion below is **live and needed** either way: it is what keeps the *calendar* arm
> correct, and §19 uses the `AdjustCalendarDaysReferenceTnx` block for `Simulation%RefDaysTo*`.
>
> **THE CLARIFICATION (now moot).** The data flow was re-traced 2026-08-03 and the
> quantity named in the meeting is not the one `SeasonalSumOfKcPot` feeds. Verified chain:
>
> - `SumKcTop` = `SeasonalSumOfKcPot(...)` (`run.f90` ~4960) — the whole-season walk.
> - Its **only** consumer: `SumKcTopStress = (1 - StressSFadjNEW/100)*SumKcTop` (`simul.f90` 1203),
>   recomputed every day so it tracks the dynamic fertility stress.
> - `SumKcTopStress`'s **only** consumer: the fertility WP ramp (`simul.f90` 797–806) as the
>   **denominator** of `SumKci/SumKcTopStress`, where `SumKci` is the running sum of `Tact/ETo`
>   **to today**. The ramp is `WPi*(1 - (RedWP/100)*exp(k*log(SumKci/SumKcTopStress)))`.
> - The `RatioBM = Biomass/BiomassPot` → `HImultiplier` path named in the meeting is
>   `simul.f90` 924/931 and does **not** read `SumKcTop`: `BiomassPot = FracBiomassPotSF*BiomassUnlim`
>   (`simul.f90` 903). Different quantity, different consumer.
>
> So "count to today" has two readings, and they are not equivalent:
>
> **(a) Make the denominator a to-today sum of the same `SumKcTop`.** Then numerator and denominator
> both accumulate to today, the ratio sits at ~1 from early on, the `< 1` guard stops firing and the
> **full** `RedWP` reduction applies all season instead of ramping. That is not hypothetical — it is
> exactly the degenerate state §17 measured and fixed: `Lend = -9` gave `SumKcTop = 0`, the guard
> never fired, and `OttawaVeg` run 3 came out **9.829 vs 10.962 t/ha (-11.5 %)**. So reading (a) is a
> real, and sizeable, behaviour change in the direction of *less* biomass under fertility stress.
>
> **(b) Accumulate the potential Kc day by day alongside the actual and compare like with like** —
> actual-vs-potential transpiration *so far*, rather than fraction-of-the-whole-season. This needs no
> look-ahead, stays naturally ≤ 1, and matches the `Biom/BiomPot` shape the meeting described. It
> changes what the ramp *means* (water-stress-to-date rather than season progress), so it also moves
> output, but it is not degenerate.
>
> **Ask which is intended.** (b) is the one that matches the stated rationale; (a) is what the words
> most literally describe. Whichever is chosen, predict the footprint before the run and name a
> project that must not move — the §16/§19 discipline.

Critical-path item 2, and the last look-ahead read before deletion. **The audit was wrong about this
item's scope, in both directions** — two of the three sites it named are dead, and one live site it
did not name.

**Dead: `ReferenceStressBiomassRelationship` and `ReferenceCCxSaltStressRelationship`** (`run.f90`
3912–3917, 3979–3984, 4006). Both copy their day arguments into `*_loc` locals and then, in GDD
mode, **unconditionally overwrite them** with `AdjustCalendarDaysReferenceTnx`
(`preparefertilitysalinity.f90` 823–836 and 957 ff.) before doing anything with them. The values
passed in from `run.f90` never reach a calculation. Nothing to convert.

**So the live set is one call: `SeasonalSumOfKcPot` at `run.f90` ~4900.** And inside that function
only **two** of its day arguments are live in GDD mode:

1. the loop bound — `do Dayi = 1, Lend`, `Lend = DaysToHarvest`;
2. **`if (Dayi >= L12) CCxWitheredForB = CCx`** at step 3.3 (`global.f90` ~5936), which the audit did
   not list. Every other day argument reaches only `CanopyCoverNoStressSF` / `CalculateETpot` day
   slots (both fork on `ModeCycle`) or the calendar branch at 3.2. Missed for the same reason §14
   item 1 was: it is spelled `Dayi >= L12`, not `Crop_DaysTo*`.

**This is the second half of upstream bug (1).** §9 moved this walk onto the reference climatology
(`ReferenceClimate = .true.`) but left its day thresholds as `AdjustCalendarCrop` products — days
measured on the **actual record**. So the fertility calibration has been walking reference weather
against actual-weather stage boundaries. Fixing the thresholds removes the look-ahead *and* the
inconsistency in one move.

**The fix is the step the two sibling callers already perform.** In GDD mode `run.f90` now derives
`RefCropDay1` from `Crop_Day1` (the same two lines, anchored in 1901 so it is not tied to a year) and
calls `AdjustCalendarDaysReferenceTnx` to produce `L0/L12/L123/L1234/CGC/CDC` on the reference
climatology, then passes those to `SeasonalSumOfKcPot`. Calendar mode skips the block entirely and
passes the crop values verbatim → bit-identical.

Two design points worth keeping:

- **All the day arguments are converted, not just the two live ones.** An inert read of a value that
  is about to stop being maintained is exactly the §12 stale-read landmine, and these reads are what
  block deleting `AdjustCalendarDays`. `Crop_CGC`/`Crop_CDC` go with them — `AdjustCalendarCrop`
  overwrites those too in GDD mode, so they are look-ahead products as well.
- **Forage is handled by the shared routine, not by a special case here.**
  `AdjustCalendarDaysReferenceTnx` skips `L123`/`L1234` for `subkind_Forage` (its line 151), so a
  perennial keeps the declared season length — the same rule `AdjustCalendarDays` applies, and
  consistent with the 2026-07-29 decision. The perennial can still move slightly through `L12`.

**Dependency, deliberately relied on:** `SumCalendarDaysReferenceTnx` reads the
`TminCropReferenceRun` arrays that `DailyTnxReferenceFileCoveringCropPeriod` fills. Those are filled
by `RelationshipsForFertilityAndSaltStress` immediately above, which runs under
`StressResponse_Calibrated` — the same condition guarding this block. No new fragility:
`SeasonalSumOfKcPot(.true.)` already opens `TCropReference.SIM` from that same setup.

#### Expected footprint

Moves `SumKcTop` → `SumKcTopStress` → the WP reduction under fertility stress → biomass. Only where
`StressResponse_Calibrated` **and** `FertilityStress > 0` (the whole suite: `Ottawa2.MAN` runs
fertility 50 → 21).

- **Calendar projects: bit-identical**, by the fork.
- **`OttawaConst`: expected identical.** Its temperature file is `(None)`, so `TnxReferenceFile` is
  `(None)` too, and both `SumCalendarDays` and `SumCalendarDaysReferenceTnx` take their
  `roundc(ValGDDays/DayGDD)` branch with the same 12/28 — identical by construction, the §13
  confirmation pattern.
- **The other const-T projects: expected identical but NOT by construction.** Their reference file is
  the monthly mean of a constant record, so the GDD/day matches — but the two functions count the
  final partial day by *different rules* (`SumCalendarDays` counts every day it consumes;
  `SumCalendarDaysReferenceTnx` drops the last day when the overshoot is large relative to the
  remainder). If a const-T project moves by exactly one stage day, that is the reason, not a bug in
  this change.
- **Variable-T GDD projects: expected to move**, and by more than §16 did — the reference
  climatology is monthly means, so its day counts differ from the actual record's for real.

#### VALIDATED 2026-07-31 — and it found a third leak of the `-9` sentinel

Every prediction held. **Identical:** both calendar oracles, and **all five const-T projects** —
including the four whose agreement was *not* guaranteed by construction, so the two counting rules
do agree in practice at constant temperature. **Moved:** the eight variable-T GDD projects.

Almost all of the movement is tiny — the genuine reference-vs-record day-count effect:

| project | run 3 BioMass | others |
|---|---|---|
| `OttawaMaize` | 18.360 → 18.458 (+0.5 %) | runs 1–2 ≤ 0.02 % |
| `OttawaTuber` | 7.345 → 7.355 (+0.14 %) | runs 1–2 ≤ 0.01 % |
| `Ottawa` (perennial) | — | ≤ 0.01 %, via `L12` only |
| **`OttawaVeg`** | **9.829 → 10.962 (+11.5 %)** | runs 1–2 ≤ 0.15 % |

**`OttawaVeg` run 3 is the insufficient-GDD season again.** 2016 banks 1283 GDD against
`GDDaysToHarvest = 1400`, so `run.f90` ~8058 skips `AdjustCalendarCrop` and `DaysToHarvest` keeps
its `-9`. That went straight into the loop bound:

```fortran
do Dayi = 1, Lend          ! Lend = DaysToHarvest = -9  ->  zero iterations
```

`SumKcPot` never accumulates → `SumKcTop = 0` → `SumKcTopStress = 0` (`simul.f90` 1201) → the guard
at `simul.f90` 795, `(SumKci/SumKcTopStress) < 1`, is `0/0` or `+Inf` and **never true** → the
`else` at 804 applies the **full** `RedWP` fertility reduction every single day, instead of the
intended `exp(k·log(SumKci/SumKcTopStress))` ramp that starts near zero and approaches the full
reduction as the season's Kc sum approaches the reference.

**The loop lengths, measured** (veg, 1400 GDD; `Lend` is only the number of days the calibration
loop runs, nothing physical):

| veg run | old `Lend` = `DaysToHarvest`, walked on the **actual record** | new `Lend` = walked on the **reference year** | biomass |
|---|---|---|---|
| 1 (2014) | 409 | 402 | +0.0 % |
| 2 (2015) | 398 | 402 | +0.15 % |
| 3 (2016) | **−9** | 402 | **+11.5 %** |

That is the whole story in one table. Runs 1 and 2 change their loop length by ~2 %, hence a
negligible biomass change. Run 3 goes from **zero iterations to 402** — that is the +11.5 %.

Note what the numbers say about the crop: 1400 GDD against an Ottawa season delivering 1042–1283
means "days to harvest" is **over a year** — the crop would have to grow through a winter. All three
old values are meaningless as season lengths; they were only ever loop bounds. And `MaxAvailableGDD`
for 2016 computes to **1283.4**, exactly the `GD` printed in the season output, which is the
cross-check that this reconstruction of the arithmetic is the model's own.

**Measured signature, which is what identifies the mechanism rather than a story about it:** biomass
diverges from the *first* day of canopy (DAP 10: 0.004 → 0.005) while **CC and Tr are identical**,
and season `WPet` goes 2.30 → 2.56 (+11 %) with `Tr` slightly **down** (199.3 → 197.8). More biomass
per unit water, from day one, with no canopy or water change — that is the WP term and nothing else.
CC only drifts later (72.0 → 70.3 by mid-August), which is the in-season fertility-stress feedback
reacting to the higher biomass, not a cause.

**This is the third place the same `-9` has leaked**, after §11 finding 4 / §15 (`Crop_DayN` →
rooting depth never called → zero biomass). The pattern is now clear enough to state as a rule:
**the insufficient-GDD sentinel corrupts any site that consumes a look-ahead day value as a
quantity — a loop bound, a length, a divisor — rather than as a date.** It is not a "cool year"
behaviour; it is a sentinel escaping into arithmetic. Each conversion that takes a site off the
look-ahead removes one such leak for free, which is a stronger argument for finishing the deletion
than the look-ahead-freedom argument itself.

`OUTP_REF` needs regenerating for the eight moved projects; the const-T and calendar references are
untouched.

---

### 18. §14 item 4 — `ScorAT1`/`ScorAT2` (2026-07-31, APPLIED, not built)

> **DELETED 2026-08-03 — see §21.** The conversion recorded below is gone from the tree; the section
> is kept because §21's "pure removal" argument rests on knowing exactly what the seeding computed.
>
> **SUPERSEDED 2026-08-03 (developer decision 4): starting a run inside the growing period is no
> longer maintained, so this whole path should be DELETED, not converted.** That resolves the open
> GUI question in §14 item 4 — the answer is "not supported" — and it retires the unsettled banking
> question below, which was the only part of this conversion that could not be validated.
>
> **What goes with it** (audit before deleting — this list is the starting point, not the whole
> answer): the `ScorAT1`/`ScorAT2` block itself (`run.f90` ~5440–5490) and the `ScorAT*` /
> `HItimesAT*` state it seeds; `GetSumGDDBeforeSimulation` (`run.f90` 3730 and its call at ~5083
> under `Crop_Day1 < DayNri`); `InitializeSimulationRunPart2`'s rebuild of `CCiPrev` from the canopy
> curve; the `Tadj` / `GDDTadj` mid-season path at `InitializeSimulationRunPart2` 5073–5081 insofar
> as it is only reachable this way. **Careful:** `Tadj`/`GDDTadj` are *also* the regrowth
> adjusted-time-scale inputs (§14, upstream bug (5)), which forage still needs — so that one is
> shared and must not be removed wholesale.
>
> Also drop the parked test-project recipe below: with the path deleted there is nothing to cover.
> Keep the *paragraph* explaining that the engine once supported it, because `project_input.f90`
> ~256 still reads the four period dates with no cross-validation, so a hand-written PRM can still
> declare such a period. Decide explicitly whether that now warrants a **validation error** rather
> than silently running a path that no longer exists.

Converted on the developer's call ("just convert it, later we'll see if it's a problem") rather than
waiting on the GUI question in item 4.

Both accumulators answer the same question — *how far into its period of effect is the crop on the
run's first day*, as a fraction clamped to 1 — so it is a ratio of two spans on the crop's clock.
One `ModeCycle` fork now sets `PosAfterFlor` + `SpanAT1` + `SpanAT2` and the arithmetic below is
shared. `tHImax` is gone.

| | calendar | GDD |
|---|---|---|
| position | `FromDayNr - (DelayedDays + Day1 + DaysToFlowering)` | `Simulation%SumGDD - GDDaysToFlowering` |
| `SpanAT1` (determinancy) | `roundc(LengthFlowering/2)` or `DaysToSenescence - DaysToFlowering` | `roundc(GDDLengthFlowering/2)` or `GDDaysToSenescence - GDDaysToFlowering` |
| `SpanAT2` (yield formation) | `roundc(HI/dHIdt)`, 0 if `dHIdt > 99` | `GDDaysToHIo` |

Two points worth keeping:

- **`GDDaysToHIo` is the twin of `roundc(HI/dHIdt)`, not a new derivation.** `dHIdt` is
  `HI/DaysToHIo` (`global.f90` ~6116), so the day expression *is* `DaysToHIo`. This is the same
  substitution `HarvestIndexDay`'s GDD arm already makes (§6: `dHIdt_local = HImax/GDDaysToHIo`).
  The `Span > 0` guards take the "after period of effect" arm for a non-positive span, exactly as
  `tHImax = 0` did for `dHIdt > 99`.
- **The GDD position is reconstructed, not looked ahead to.** `GetSumGDDBeforeSimulation`
  (`run.f90` 3730, called at ~5083 under `Crop_Day1 < DayNri`) already walks the record from
  planting to the run start for precisely this case, and it runs before this block.

**Calendar mode is bit-identical by construction**: same operation order (`1._dp/Span` first, then
multiply by the position — *not* `Pos/Span`, which can differ in the last bit), same operand values,
integers widened to `real(dp)` exactly.

**The GDD arm is reasoned, not measured — and this suite cannot measure it.** No project starts
mid-season, so the block is unreachable (item 4). **Expect byte-identical output everywhere, and
treat that zero diff as vacuous** — it shows only that nothing else was perturbed, the §14 lesson
stated in advance. In particular **the banking is unsettled**: whether `SumGDD` should be banked
(`- GDDayi`) here shifts the fraction by one day's GDD, and there is no way to tell from this suite.
Settle it with a probe on a mid-season project — recipe in item 4 — before trusting the GDD arm.
Same treatment as the rooting-depth banking in §14 item 2, and the comment at the site says so.

---

### 19. §14 item 6 — salinity stress day spans onto the reference climatology (2026-07-31, APPLIED, not built)

> **Developer principle, 2026-07-31: everything in the fertility/salinity calibration family takes
> its day spans from the reference climatology.** §17 was the first instance; this is the second and
> generalises it. Apply it to anything else in that family rather than re-deriving the argument.

**Bug (4) is NOT fixed and must not be.** The obvious repair — fork the canopy-decline block
(`tempprocessing.f90` ~1898) and use `GDDL123 - GDDL12SS` — is the trap the BLOCKED note describes:
`CDecline` is merged with the fertility term by `max()` in `simul.f90`, and the merged value is
multiplied by `RatDGDD` in `CCiNoWaterStressSF`'s GDD branch. A term already expressed per GDD
would be converted twice (~12× wrong), and after the `max()` the two cannot be told apart to exempt
one. **The decline denominator has to stay a DAY span.** So this change does not touch the units —
it only changes *which days*.

**What was live.** Of the four day arguments, only two: `L12` (`DaysToFullCanopy`) and the `L123`
slot, which the runtime call fills with `DaysToHarvest`. `LFlor`/`LengthFlor` reach only the
calendar branch. Both live ones feed the unforked decline block, where GDD mode collapses
`L12SS` to `L12`.

**The fix.** Two new fields, `Simulation%RefDaysToFullCanopy` / `RefDaysToHarvest`, following the
`SumGDDatFlowering` precedent (§6). `InitializeSimulationRunPart1` now derives the reference day
spans **outside** the fertility guard — under `GDD .and. (StressResponse_Calibrated .or.
SalinityConsidered)`, which is exactly when `RelationshipsForFertilityAndSaltStress` above has
populated `TminCropReferenceRun` — and publishes those two. In calendar mode the locals stay at the
crop values, so the fields equal `Crop.DaysTo*` and the call site needs **no `ModeCycle` fork**.
`EffectSoilFertilitySalinityStress` (`simul.f90` ~4289) reads them; it lives in `ac_simul` and
cannot see `ac_run` locals, which is why this goes through the globals rather than more threading.

**The treatment is confirmed by its own sibling.** `CCxSaltStressRelationshipForTnxReference`
(`preparefertilitysalinity.f90` 612) calls the *same routine* and already passes reference-derived
days. Until now the runtime call disagreed with the calibration call about which climate its stage
boundaries came from; now they agree.

**Side effect worth knowing:** with a delayed germination, `ResetCropAndSimulationPeriod` re-runs
`AdjustCalendarCrop` mid-run and rewrites `Crop.DaysTo*`. The `Ref*` pair is computed once at run
init and does **not** follow, which is the intended behaviour — a weather-independent calibration
span should not shift because the seed sat in dry soil.

#### Expected footprint

Sharp, because the consumer is doubly gated (`SalinityConsidered` *and* `SaltStress > 0.1`, which
per §8 only the salt projects reach):

- `OttawaMaizeSaltCal` — **bit-identical** (calendar arm).
- `OttawaMaizeSaltConst` — **expected identical**: constant record, so reference and record day
  counts coincide, the same built-in check §17 had.
- `OttawaMaizeSalt`, `OttawaMaizeSaltIrri` — **expected to move**, via the `CDecline` denominator
  `L123 - L12SS`.
- Everything else — unchanged; nothing else consumes these fields.

If a non-salt project moves, the guard on the derivation is wrong.

#### VALIDATED 2026-07-31 by probe — and one prediction was wrong

Built and run. `OttawaMaizeSaltCal` bit-identical, nothing outside the salt family moved, so the
guard is right. But **`OttawaMaizeSaltConst` moved (−0.25 % biomass) when this section predicted
byte-identical**, and the first two explanations offered for it were both wrong. A `SALTDBG` probe
inside `CropStressParametersSoilSalinity` (+ a per-run marker) settled it in one run. **Probe
stripped 2026-07-31**; the parser `testcase/salt_debug.py` is kept untracked alongside
`gate_debug.py`, so re-measuring needs only the two print hunks back.

*Caught while stripping:* the local `CGCRef` in `InitializeSimulationRunPart1` shadowed the
module-level `CGCref` of `ac_run` (`run.f90` 609) — Fortran is case-insensitive. Harmless only
because that routine never reads it; renamed to `CGCRefTnx`/`CDCRefTnx`. Worth remembering when
adding locals to the big `ac_run` routines: the module has many short global names.

**Upstream bug (4), measured rather than argued.** Every GDD row prints
`L12Double = L12SSmax = L12SS = L12` exactly (e.g. all three `40.0000` when `L12 = 40`). So
`CCsaltDistortion` genuinely has zero effect on the decline denominator in GDD mode. That is the
bug, visible.

**The denominator is `L123 - L12` — and here is what it did.** Measured `cropL12/cropL1234` versus
`refL12/refL1234`:

| project | run | crop (record) | reference | denominator | biomass |
|---|---|---|---|---|---|
| `OttawaMaizeSalt` | 2014 | 37 / 129 | 36 / 112 | 92 → 76 (**−17 %**) | **−2.8 %** |
| | 2015 | 41 / 113 | 36 / 112 | 72 → 76 (+5.6 %) | +0.9 % |
| | 2016 | 35 / 103 | 36 / 112 | 68 → 76 (+12 %) | +1.8 % |
| `OttawaMaizeSaltConst` | all | 27 / 101 | 27 / 100 | 74 → 73 (−1.4 %) | −0.25 % |

Smaller denominator → larger `CDecline` → more canopy decline → less biomass. **Every sign and
relative magnitude matches.** The ±3 % is not drift: the day span sits in a *denominator* and drives
decline all season, so a 17 % change in the span is a 17 % change in the decline rate.

**So the const-T movement is the counting-rule difference after all** — but on `L1234` only
(101 → 100), with `L12` unchanged at 27. The earlier arithmetic here got the sign backwards purely
by assuming `L12` shifted too. §17 already recorded this failure mode ("expected identical but NOT
by construction... if a const-T project moves by exactly one stage day, that is the reason"); the
mistake was writing that caveat and then not applying it. See upstream bug (10).

**`DaysToHarvest` of 129 / 113 / 103 days from identical crop parameters** is the pathology being
removed, in one line — the same shape as §6's `TimeToMaxCanopySF` finding. A salinity decline
*calibration* parameter should not depend on whether 2014 was cold.

**Two incidental confirmations.** The perennial's `L12` does change (39→40, 44→52, 45→50) while its
`L1234` does not — `AdjustCalendarDaysReferenceTnx` skips `L123`/`L1234` for Forage, as designed —
and `Ottawa` still did not move, because the runtime salinity call needs `SaltStress > 0.1`, which
only the salt projects reach (§8). And `OttawaVeg` run 3 prints `cropL1234 = -9` outright, which is
§17's sentinel visible in the log.

*Probe flaw worth knowing if it is reused:* `GetProjectFile()` returns `(None)` at that point, so
the marker does not name the project. Runs were attributed by `ListProjects.txt` order plus the crop
day values.

---

### 20. The look-ahead is no longer called (2026-07-31, APPLIED, not built) — STEP A

Critical-path item 3, split in two so the interesting question gets asked on its own.

**Step A (this): stop *calling* the look-ahead, delete nothing.** That makes the suite answer the
only question that matters — *does anything still read the calendar day twins in GDD mode?* An audit
cannot answer it; §14 missed live sites twice (item 1's spelling, item 5's `Dayi >= L12`) and
wrongly listed dead ones (item 5's two siblings). A byte-identical suite run can.

**Step B (after A passes): delete the now-uncalled routines.** Dead-code removal only.

#### What was removed

- `ResetCropAndSimulationPeriod` (`run.f90` ~8168): the `MaxAvailableGDD` scan, the
  `GDDAvailable >= GDDaysToHarvest` guard, and the locals they needed.
- `AdjustCalendarCrop`: the `AdjustCalendarDays` call and all thirteen day-twin write-backs
  (`DaysToGermination/FullCanopy/Flowering/LengthFlowering/Senescence/Harvest/MaxRooting/HIo/
  Length/CGC/CDC/dHIdt` and `GDDaysToHIo`).

**Consequence: in GDD mode the day twins keep the nominal values the `.CRO` declares.** They are not
undefined and not stale — `veg.CRO` says `140 : Calendar Days: from transplanting to maturity`, and
that is now what `DaysToHarvest` holds instead of 409 / 398 / **−9**. Every leak of that sentinel
(§15 rooting depth, §17 loop bound) becomes structurally impossible rather than individually fixed.

#### What was kept, and why it is not a look-ahead

`AdjustCalendarCrop` still recomputes `GDDaysToFullCanopy`:

```fortran
GDDaysToFullCanopy = GDDaysToGermination + roundc(log((0.25·CCx²/CCo)/(CCx − 0.98·CCx))/GDDCGC)
```

That is the analytic inverse of the CC curve on the GDD clock — pure crop geometry, no temperature
record, same answer every year. Verified to be the **identical expression** `CompleteCropDescription`
already uses for GDD crops (`global.f90` ~6177, via `DaysToReachCCwithGivenCGC`, which expands to
`L0 + roundc(log((0.25·CCx²/CCo)/(CCx − CCToReach))/CGC)`). The only thing `AdjustCalendarCrop` adds
is the clamp to `GDDaysToHarvest`, which is why the call is kept rather than dropped outright —
folding the clamp into `CompleteCropDescription` is a step-B decision, not a step-A one.

Calendar mode is bit-identical **by construction**: `AdjustCalendarCrop`'s `case default` did
nothing but set an unused local, so removing what the GDD case did cannot reach it.

#### RESULT 2026-07-31 — the prediction FAILED, and that is the value of the step

Built and run. **Not byte-identical.** Both calendar oracles were, so the fork is intact and this is
purely a GDD-mode reader — exactly the thing step A exists to expose, found before anything was
deleted. **Step A is PARKED as `step-a-lookahead-uncalled.patch` at the repo root** (apply with
`git apply`); the branch tip `bae7b52` is a clean, complete, validated state through §19.

**The bisect result is sharp: for annuals, `DaysToGermination` is the ONLY field that matters.**
Restoring just that one (leaving all others nominal) made **all 13 annual projects byte-identical**,
including every const-T oracle. So `DaysToFullCanopy`, `DaysToSenescence`, `DaysToHarvest`,
`DaysToFlowering`, `LengthFlowering`, `DaysToMaxRooting`, `DaysToHIo`, `Length`, `CGC`, `CDC` and
`dHIdt` can all go nominal with **zero** effect. `GDDaysToHIo` — the only GDD field the look-ahead
wrote — is unchanged either way (118/118, 858/858). §§11–19 did their job; one reader survived.

**What remains after restoring it:** `Ottawa` runs 2–3 only, one digit in the last decimal
(BioMass 4.019 → 4.018). `OttawaConst` is fully clean, so it is weather-path sensitivity on the
**forage regrowth** path — which the 2026-07-29 decision already puts out of scope.

**Half of it is explained.** `AdjustCalendarDaysReferenceTnx` recomputes `L0` **only** when
`DaysToCCini == 0`; the regrowth branch instead computes `L12 = L0 + TheDaysToCCini + ExtraDays`
from the **incoming** `L0`. So forage regrowth reads the day twin through §19's own path, and the
`Simulation%RefDaysTo*` pair is weather-independent for annuals but **not** for perennials. Worth
fixing or documenting in §19 regardless of how the annual hunt ends.

**The annual half is UNFOUND — do not restart by reading code.** Ruled out by inspection *and*
confirmed clean under gdb: `CanopyCoverNoStressSF`, `CCiNoWaterStressSF` (post-§12), `CalculateETpot`
(`P0 = GDDL0`), `DeterminePotentialBiomass`, `GetPotValSF`, `CalculateRootingDepth`,
`ActualRootingDepth`/`AdjustedRootingDepth`, `CalculateTimeToReachZmin` (`tDaysZmin` really is
calendar-only), `GetWeedRC`, `CCmultiplierWeedAdjusted`, `TimeToMaxCanopySFOnCycleClock`, and the
stage-clock gates. `CGCref`/`GDDCGCref` turn out to be **dead parameters** — declared in
`DeterminePotentialBiomass` and `DetermineBiomassAndYield`, never referenced. `Crop_Length` has **no
readers at all**. Classification-by-inspection failed twice here; it is the wrong instrument.

**Resume from inside the daily loop.** Four gdb hits were collected and all four
are init-phase reads that are provably dead (`SaveCrop`, `CompleteCropDescription`,
`AdjustCalendarCrop`, the `ReferenceStressBiomassRelationship` argument list, and §17's own
`L0Ref = GetCrop_DaysToGermination()`). A `DayNri`-based break condition does **not** skip
initialisation, because `DayNri` carries over from the previous run.

**Use the in-tree probe, not gdb — `lookdbg-germination-backtrace.patch` at the repo root**
(2026-08-03, `git apply`). It puts a module flag `LOOKDBG_InLoop` in `ac_global`, flips it on at the
top of `BUDGET_module` (which runs once per simulated day), and makes `GetCrop_DaysToGermination`
print `call backtrace()` for the first 40 reads taken while the flag is on. So every stack it prints
is a read from **inside the daily loop** — the init-phase reads already cleared cannot appear at all,
which is the exact filter the gdb recipe was hand-rolling.

```
git apply lookdbg-germination-backtrace.patch
git apply step-a-lookahead-uncalled.patch     # the probe is only interesting with step A in
# build with -g -fbacktrace, then, in testcase/:
./aquacrop > look.log 2>&1
grep -A12 LOOKDBG look.log | head -80
```

Two things to know before trusting a null result: `backtrace()` is a **gfortran extension** (fine for
this build, it would not survive a port), and the build must keep `-g -fbacktrace` or the frames come
out as bare addresses. If the probe prints **nothing at all**, that is itself the answer — the read
is not reached through the getter, and the next suspects are whole-record copies of `Crop`
(`GetCrop()` has one live call site, `calculate_sink_values` at `simul.f90` 1439) rather than any
field reader. That path has already been checked once by grep and does not touch the day fields, so a
silent probe would mean the bisect's premise needs re-examining before more searching.

The gdb recipe, kept because it still works if the probe is unavailable:

```
(gdb) break ac_simul::budget_module     # runs once per simulated day
(gdb) continue
(gdb) delete
(gdb) break global.f90:11550            # GetCrop_DaysToGermination
(gdb) continue
(gdb) bt 8
```

The probe (`LOOKDBG` in `AdjustCalendarCrop`, which calls the still-present `AdjustCalendarDays`
into scratch variables to print now/was for every field) is in the parked patch, with the restore
and poison lines commented at the site. Poison = 60 makes the consumer's column swing hard.

#### RESULT 2026-08-27 — STEP A PASSES

With §24's germination-term conversion in, step A was re-run. **All 13 annual projects, both
calendar oracles and `OttawaConst` are byte-identical**, with the look-ahead never called and the
day twins sitting at their `.CRO` nominal values. `AdjustCalendarDays` and `MaxAvailableGDD` now
have **zero callers** (after stripping the patch's own `LOOKDBG` probe block, which ran the
look-ahead into scratch variables only to print `now/was`).

**`Ottawa` runs 2–3 move, and only they** — the perennial on the real-weather path:

| quantity | new | ref | rel. diff |
|---|---|---|---|
| Biomass run 2 | 12.091 | 12.093 | 0.017 % |
| Biomass run 3 | 12.738 | 12.741 | 0.024 % |
| Yield run 3 | 63.692 | 63.706 | 0.022 % |

**No phenology shift: `DAP` and `Stage` are unchanged on all 904 daily rows**, cut dates and cycle
lengths identical, run 1 byte-identical. What moves is canopy magnitude, plus three integer columns
by one unit (`E/Ex`, `ET/ETx`) and a `StExp` reporting flag flipping between `0` and `-9` on 14
late-season days — adjacent-day alternation, the signature of a value sitting on a reporting
boundary, not a `-9` sentinel leak.

This is the residual §20 named in advance ("`Ottawa` runs 2–3 only, one digit in the last decimal
… weather-path sensitivity on the forage regrowth path"), and the 2026-07-29 decision puts perennial
regrowth out of scope. **Two known sources, both regrowth-only, if it is ever closed:**

1. `AdjustCalendarDaysReferenceTnx` recomputes `L0` **only** when `TheDaysToCCini == 0`
   (`preparefertilitysalinity.f90` 135), so a regrowth reads the incoming `L0` — §20's half.
2. `run.f90` ~6792: the regrowth arm builds `VirtualTimeCC` itself as
   `(DayNri - DelayedDays - Crop_Day1) + Tadj + Crop_DaysToGermination()`, unforked — the other half,
   found 2026-08-27 while enumerating for §24.

#### The prediction as written before the run

**Byte-identical across all 15 projects × 3 runs.** Sections 11–19 exist to make that true: every
live GDD-mode read of a day twin was converted (`AfterCropCycle`, mulch/wetted surface, rooting
depth, germination, the HI restart accumulators, the fertility calibration, the salinity spans).

**Any diff means a reader was missed, and the diff says where** — that is the point of running it
before deleting anything. Check `OttawaVeg` run 3 first: it is the run whose `DaysToHarvest` was
`−9` and is now 140, so it is where an unconverted reader would show up most violently.

#### What step B can and cannot delete

| routine | callers after step A | step B |
|---|---|---|
| `AdjustCalendarDays` | **0** | delete |
| `MaxAvailableGDD` | **0** | delete |
| `AdjustCalendarCrop` | 2, geometry only | keep (or fold the clamp into `CompleteCropDescription`) |
| `GDDCDCToCDC` | 1 — `AdjustCalendarDaysReferenceTnx` | **keep**; its `Reference = .false.` branch dies with `AdjustCalendarDays` |
| `SumCalendarDays` | **1** — the forage walk in `AdjustCropFileParameters` | **KEEP** |

**Correction to the critical path as written since §14:** `SumCalendarDays` cannot be deleted. §10's
census already said so ("1 is forage") and §13 established that walk is *correct* and must stay —
it runs days→GDD, which is genuinely weather-dependent. The goal was always "annuals no longer need
the temperature record in advance", and that is what step A delivers.

---

### 21. A1 — the mid-season-start path deleted (2026-08-03, COMMITTED `fee3cfa`)

Developer decision 4, 2026-08-03: **starting a run inside the growing period is no longer
maintained.** So the §18 conversion is replaced by removal, and with it every other arm in the run
initialisation that existed to reconstruct a crop already standing on the run's first day.

Done **ahead** of step A, not behind it as the queue originally said: it touches nothing step A
touches (`ResetCropAndSimulationPeriod`, `AdjustCalendarCrop`), it is pure removal, and it shrinks
what step A has to be validated against. `run.f90` only: **−322 lines, +52.**

**The invariant this establishes, and everything below follows from it:**
`DayNri <= Crop_Day1` on the run's first day. A run starts at or before planting.

#### What was removed

| site | was | now |
|---|---|---|
| `GetSumGDDBeforeSimulation` (`run.f90` 3732–3892) | 164 lines walking the temperature record from `Crop_Day1` to the run start, in all three record formats | **deleted** |
| its call, `InitializeSimulationRunPart2` (~5098) | under `GDD .and. Crop_Day1 < DayNri` | deleted; `Simulation_SumGDD` / `SumGDDfromDay1` just start at 0 |
| the first-day GDD gate (~5112) | `if (DayNri >= Crop_Day1)` with an inner `== ` for one of the two sums | one `if (DayNri == Crop_Day1)` — the two sums only ever differed for a mid-season start |
| 13.1d `CCiPrev` (~5248–5264) | an `else` arm rebuilding `CCiPrev` from `CCiNoWaterStressSF` at an arbitrary point in the cycle, plus an "after cropping period" arm | deleted; the `DaysToCCini` fork (regrowth vs sown/transplanted) is now the only fork |
| 16.1 `Ziprev` (~5352–5370) | same shape, rebuilding rooting depth via `ActualRootingDepth` | `Ziprev = undef_int`, unconditionally |
| the `ScorAT1`/`ScorAT2` seeding (§18, ~5446–5504) | the whole `ModeCycle` fork + `PosAfterFlor`/`SpanAT1`/`SpanAT2` arithmetic | `ScorAT1 = ScorAT2 = 0` |
| `InitializeSimulationRunPart1` germination (~4664) | `plant_Seed .and. FromDayNr <= Crop_Day1` | `plant_Seed` — a sown crop always still has to germinate |

`Tadj` / `GDDTadj` and the whole of section 12 are **untouched**. The §18 banner flagged them as
shared with forage regrowth and it was right: that block is gated on `DaysToCCini /= 0`, which is
regrowth, not a late run start.

#### Two things that make this a *pure* removal rather than a behaviour change

1. **The `ScorAT` collapse reproduces what the seeding computed.** For a run starting at or before
   planting the crop is not past flowering on day 1, so `PosAfterFlor <= 0` and the old block set
   both accumulators to 0 — which is what is now written directly.

   **One exception, and it was an artefact of §18's own GDD arm.** Veg and forage have
   `DaysToFlowering = GDDLengthFlowering = GDDaysToFlowering = 0`, forced at crop-file load
   (`global.f90` 5471/5560). The calendar arm then gave `PosAfterFlor = 0` exactly, but the GDD arm
   gave `PosAfterFlor = Simulation_SumGDD` = **the first day's GDD**, so the accumulators were seeded
   non-zero for every GDD veg/forage run. Harmless, because `ScorAT1`/`ScorAT2` are read only inside
   `DetermineBiomassAndYield`'s `subkind_Tuber .or. subkind_Grain` block (`simul.f90` 906) — veg and
   forage never reach them. Removing the seeding removes the artefact for free.

2. **`Simulation_CCini` / `Bini` / `Zrini` were deliberately left alone.** They are the initial
   conditions read from the `.SW0` file ("initial CC at start of simulation period", "B produced
   before start of simulation period", "initial rooting depth"), i.e. the *inputs* to the path just
   deleted. Removing them is a **file-format change** and belongs upstream, not here. Two of the
   three are now structurally unreachable anyway — 13.2 needs `CCiPrev > 0`, 16.2 needs `Ziprev > 0`,
   and both are 0 / `undef_int` for a sown crop at planting. `Bini` (section 14) still fires whenever
   it is non-zero. **Open item for the main developer**, not a gap in this change.

#### VALIDATED 2026-08-03 — byte-identical, as predicted

Built and run. **No diff anywhere**, calendar and GDD alike. So the invariant
(`DayNri <= Crop_Day1` on the run's first day) holds across the whole suite and every removed arm
really was unreachable. No `OUTP_REF` regeneration needed.

#### The prediction

**Byte-identical, all 15 projects × 3 runs, calendar and GDD alike.** Stronger than the usual
"expected identical": the removed arms are unreachable for the whole suite, and that was *measured*
rather than assumed — across every run block of all 15 PRMs, no `First day of simulation period` is
later than the matching `First day of cropping period`. Both perennial projects (`Ottawa`,
`OttawaConst`) start their runs 2 and 3 *before* the cropping period (41578 vs 41759), which is the
supported direction and the arm that was already being taken.

Any diff therefore means the invariant is violated somewhere the PRM scan did not look — check
`Simulation_FromDayNr` against `Crop_Day1` at the top of the run, not the deleted code.

#### The open question this creates

`project_input.f90` ~256 reads the four period dates with **no cross-validation**, so a hand-written
PRM can still declare `FromDayNr > Crop_Day1`. Before this change that ran a supported (if
unmaintained) path; now it silently runs a path that no longer exists — the crop will simply be
treated as planted on the run's first day. The §18 banner asked for an explicit decision on whether
this warrants a **validation error**. It is not implemented here because it is user-facing and
touches the GUI contract. **Recommendation: make it a hard validation error**, since the alternative
is a silently wrong answer with no signal at all.

---

### 22. A2 — the fertility WP ramp on the GDD measure (2026-08-03, NOT ADOPTED — closed 2026-08-21)

Developer decision 2 (2026-08-03): `SeasonalSumOfKcPot` does not need the whole-season Kc sum.

> **CLOSED 2026-08-21. Consensus went the other way: keep the season sum, take it from the reference
> climatology — §17's conversion, already committed as `6b8619c`.** So this section describes a
> **road not taken**. It was written, removed from the tree 2026-08-05, and never built or run — the
> prediction at the end is and will stay un-tested. The code remains parked at the repo root as
> **`a2-gdd-measure.patch`** (applies cleanly to `fee3cfa`); the equations, symbols and units
> prepared for the developer discussion are in **`fertility-wp-ramp.md`**. Keep this section: it is
> the record of *why* three earlier variants were rejected, which is the expensive part to
> re-derive, and of the `Bnormalized` calibration trap that any future change here must respect.

> **A2 is NOT on the critical path — check this before spending time on it.** Since §17 the runtime
> call passes `ReferenceClimate = .true.` and takes every day threshold from
> `AdjustCalendarDaysReferenceTnx`, so it reads **no actual-record look-ahead**. It does not block
> step A, step B or the deletion. A2 is a modelling improvement the developer asked for on
> theoretical grounds; it can be deferred or dropped at zero cost to the refactor.

#### The idea: change the measure, not the formula

Legacy integrates over **days**, which is the only reason the denominator needs a season length:

```
              Σ_to-date (Tact/ETo)·GDDayi
ratio  =  ─────────────────────────────────────────
          (1−SF/100) · Σ_cycle (KcPot)·GDDi
```

In GDD mode each day's Kc is weighted by that day's GDD, on **both** sides, and the walk that builds
the denominator runs until the cycle's GDD budget is spent instead of for `Lend` days.

Everything else is untouched — the `k = 2` shape, the `< 1` guard, the latch, the `else` arm, the
`(1−SF/100)` scaling, `run.f90`'s init. This is the smallest change that answers the decision.

#### Why this and not the two variants tried first

| variant | why it was dropped |
|---|---|
| (a) same `SumKcTop`, truncated to today | degenerate — measured at −11.5 % biomass in §17 |
| (b) potential Kc to today | drops the season-position factor entirely; the ramp stops ramping |
| shortfall × `SumGDD/GDDaysToHarvest` | **the developer's objection, and it is correct**: thermal position ≠ transpiration position. `Tpot ∝ Kc·CC`, so almost no transpiration accumulates while the canopy is small but GDD accrues from day one. The raw thermal fraction overstates progress early — exactly where `k = 2` is most sensitive |

The measure change avoids all three because `KcPot` stays inside the integrand, so the position
factor stays canopy-weighted without ever being separated out.

#### What "the season length dies" means here, concretely

`SeasonalSumOfKcPot`'s loop was `do Dayi = 1, Lend`. It is now a `walk:` loop that exits on
`SumGDDfromDay1 >= GDDL1234` in GDD mode, and on `Dayi > Lend` in calendar mode. **`Lend` becomes a
calendar-mode-only input.** That is the last day count in the fertility calibration path.

The exit test is **banked** — today runs if the GDD banked *before* today is still short of budget —
which is the convention everywhere else until decision 5's global unbank pass (A4).

#### The four sites, and why all four had to move together

| file | what |
|---|---|
| `global.f90` `SeasonalSumOfKcPot` step 3 / 3.5 | GDD-terminated walk; `SumKcPot += (TpotForB/EToStandard)*GDDi` |
| `tempprocessing.f90` `Bnormalized` step 5 / 5.4 | the same two changes |
| `simul.f90` `DetermineBiomassAndYield` §1.1d | `SumKci += KcStep(Tact, ETo, GDDayi)`, a new contained function holding the fork |

**`Bnormalized` is not optional, and this is the part that is easy to miss.** It is the *same ramp*,
and it is what **fits** the fertility curve `Coeffb0/b1/b2` that the runtime then **inverts** at
`simul.f90` ~1201 (`StressSFadjNEW = roundc(Coeffb0 + Coeffb1·BioAdj + Coeffb2·BioAdj²)`), whose
output scales the denominator two lines later. The loop closes:

```
Bnormalized fits the curve using ramp B  →  Coeffb0/b1/b2
                                                 ↓
runtime reads it back (simul.f90 ~1201)  →  StressSFadjNEW  →  SumKcTopStress
                                                 ↓
                                          runtime applies ramp A
```

Change one measure and not the other and the runtime applies a WP schedule the curve was never
fitted against. **The failure is silent** — no crash, no sentinel, just a wrong biomass. Developer
sign-off obtained 2026-08-03 for the calibration curve itself moving.

#### The termination guarantee

Dropping `Lend` drops the only thing that made these loops terminate. If `GDDi` came out 0 every day
the budget would never be spent — and the reference-climate branch **rewinds the file on EOF**
(`global.f90` ~5859), so it would not even run out of data. Both walks therefore carry
`MaxWalkDays = 3*365` and **abort** via `assert` rather than silently truncating the sum. Three
reference years: Ottawa banks ~1000–1300 GDD/year (§17's table) against a largest budget of ~2000, so
a legitimate walk is at most ~2 years. It is a termination guarantee, not a modelling parameter.

#### The prediction — and it is a sharp one

**Every const-T project must be byte-identical.** At constant temperature `GDDi` is a constant that
appears in both the numerator and the denominator and cancels exactly, so the ratio — and therefore
`WPi`, the biomass, everything — is unchanged. That covers `OttawaMaizeConst`, `OttawaVegConst`,
`OttawaTuberConst`, `OttawaConst` and `OttawaMaizeSaltConst`. Both calendar oracles are identical by
the fork. **Only the eight variable-T GDD projects move.**

That is a much stronger check than §16–§19 had: it tests the *algebra* of the change, not just its
guard. If a const-T project moves, the weighting is wrong somewhere — most likely one of the four
sites was missed, or one side is still on the day measure.

**One admissible exception**, and only this one: the loop-bound change can shift the walk by a single
iteration through the counting rule of upstream bug (10) — `SumCalendarDaysReferenceTnx` drops the
last day when the overshoot is large relative to the remainder, so `Lend` and the GDD budget need not
agree on the final partial day. §19 hit exactly this on `OttawaMaizeSaltConst`. A const-T move of one
stage day is that; anything larger is not.

**Behaviour worth knowing before accepting it:** dormant days (`GDDi = 0`) now contribute to neither
side, so for the `Ottawa` perennial winter no longer advances the fertility penalty at all. That is
consistent with how §9 already excludes dormant days from `RatDGDD`, and is almost certainly right,
but it is a real change and it is specific to forage.

`OUTP_REF` will need regenerating for the eight variable-T GDD projects; the const-T and calendar
references should be untouched, and if they are not, see the prediction above.

---

### 23. `RatDGDD` folded into `CDecline` (2026-08-21, VALIDATED — byte-identical, as predicted)

Developer suggestion, 2026-08-21: `Simulation%EffectStress%CDecline` may stay a per-DAY rate where
the shape factors produce it, but it should be **stored on the clock its readers use** — %/GDD in
GDD mode. What is conserved is the **total canopy decline over the decline window**, which is the
calibrated quantity, and the climatology is the right source for it because that is the weather the
crop was calibrated against.

This is a **pure regrouping**, not a modelling change. The decline term reads

```
calendar   CCi -= (CDecline/100) · (Dayi-L12SF)² / (L123-L12SF)
GDD (was)  CCi -= (RatDGDD·CDecline/100) · (SumGDD-GDDL12SF)² / (GDDL123-GDDL12SF)
GDD (now)  CCi -= (CDecline/100) · (SumGDD-GDDL12SF)² / (GDDL123-GDDL12SF)
```

with `CDecline` multiplied by `RatDGDDReference()` once, at the point the stress level is set. Both
forms carry the same total: `CDecline/100 · dayspan = (RatDGDD·CDecline)/100 · GDDspan`.

#### What went away

`RatDGDD` was **only ever multiplied with `CDecline`** — it reached no other expression. It is gone
as a dummy argument from three routines and as a local from four:

| removed from | was |
|---|---|
| `CCiNoWaterStressSF` (`global.f90`) | argument; three uses, all `RatDGDD*SFCDecline` |
| `CCiniTotalFromTimeToCCini` (`global.f90`) | argument, pure pass-through |
| `Bnormalized` (`tempprocessing.f90`) | argument, pure pass-through |
| `InitializeSimulationRunPart2` §13.1a, `GetPotValSF`, `AdvanceOneTimeStep` (`run.f90`) | local + `RatDGDDReference()` call |
| `DetermineCCiGDD` (`simul.f90`) | local + `RatDGDDReference()` call |
| `DetermineCCi` (`simul.f90`) | the hardcoded `1._dp` at the calendar call site |

`RatDGDDReference()` itself **stays** — a conversion still needs a factor — but it is now called at
three writer sites instead of being threaded through six signatures.

#### The five writers, and the ordering rule that makes this exact

The factor is measured over `[GDDaysToFullCanopySF .. GDDaysToSenescence]`, so it must be applied
**after that window is settled**, which is what `TimeToMaxCanopySFOnCycleClock` does:

1. `run.f90` `InitializeSimulationRunPart1` — after `TimeToMaxCanopySFOnCycleClock`. Nothing touches
   the window between there and the Part 2 consumer (checked).
2. `run.f90` regrowth day 1 — after `CropStressParametersSoilFertility`; the window does not move
   there, which is why the old code could compute `RatDGDD` *before* the call.
3. `simul.f90` `EffectSoilFertilitySalinityStress` — after `TimeToMaxCanopySFOnCycleClock`, i.e. the
   last statement of the stress arm. This is the daily one.
4. The no-stress arm sets `CDecline = 0`, where the factor is moot.
5. `preparefertilitysalinity.f90` — both calibration routines fold their **own per-stress-level**
   ratio `(L123-L12SF)/(GDDL123-GDDL12SF)` into `StressResponse%CDecline` before calling
   `Bnormalized`. They cannot use `RatDGDDReference()`: it reads the global crop window, while these
   loop over eight stress levels each with its own `L12SF`.

**`ResetCropAndSimulationPeriod` (`run.f90` §5) moves the window without re-deriving `CDecline`** —
the one place where a stored per-GDD value could go stale against its window. It cannot bite: it
fires at the end of 14.c, after that day's last consumer (`GetPotValSF`), and the next day's step 9
re-derives and re-converts before anything reads. Worth re-checking if the daily order ever changes.

#### The prediction

**Byte-identical, all 15 projects × 3 runs, both modes.** Calendar mode multiplies by exactly
`1._dp`, which is bit-preserving; GDD mode forms the same product `RatDGDD*CDecline` it formed
before, and in the same association — every old expression was written `RatDGDD*SFCDecline/100`,
which evaluates left to right as `(RatDGDD*SFCDecline)/100`, so pre-multiplying changes no rounding.

**If a GDD project moves, the fault is an ordering slip, not the algebra** — a writer applying the
factor over a different window than the consumer would have used. Look at the five sites above in
that order, `ResetCropAndSimulationPeriod` last.

**VALIDATED 2026-08-21 — byte-identical, all 15 projects, as predicted.** `OUTP_REF` untouched.
The ordering rule is what the result confirms: the five writers do fire on exactly the occasions
the old per-use `RatDGDDReference()` calls would have picked up a new window.

---

### 24. The missing GDD-mode reader — FOUND (2026-08-27, VALIDATED)

**§20's open question is closed.** The one field still read in GDD mode after step A,
`Crop_DaysToGermination`, was read at exactly one live site: the germination term of the
fertility/salinity gate in `EffectSoilFertilitySalinityStress` (`simul.f90` ~4237).

```fortran
if ((VirtualTimeCC < GetCrop_DaysToGermination()) &        ! day clock, NOT forked
        .or. AfterCropCycle(VirtualTimeCC, SumGDDadjCC_in, GDDayi) &   ! converted in §11
        .or. (GetSimulation_Germinate() .eqv. .false.) &
        .or. ((StressSFAdjNEW == 0) .and. (SaltStress <= 0.1_dp))) then
```

**Why three passes of inspection missed it, and how it was finally found.** It is the §14 item 1
spelling trap for the third time: it does not say `Crop_DaysTo*` inside a canopy routine, it is a
bare `<` sitting immediately beside a term §11 had already converted — which makes the line look
done. What found it was **not** another chain-walk but an *exhaustive enumeration* of all 47 call
sites of `GetCrop_DaysToGermination()`, each classified as init-phase, inside a `ModeCycle` fork's
calendar arm, inside the calendar-only `DetermineCCi` (4847–5554), or a day-slot argument to a
callee that forks. Exactly one survived. **Enumerate, then eliminate — do not follow chains.**

**The arithmetic was measured, not derived** (the §11 rule). A `GERMDBG` probe was inserted above
the gate and run on the tip *with the look-ahead still present*, so `Crop_DaysToGermination` was
the reference. It evaluated four candidate forms on every early-season day of every run. Only the
union matters, since the gate is a chain of `.or.`:

| candidate | form | failing runs (of 73) |
|---|---|---|
| **c3** | `(SumGDDadjCC − GDDayi) < GDDaysToGermination` — **banked, crop's own clock** | **1** |
| c1 | banked, absolute clock (`SumGDD`) | 5 |
| c2 / c4 | unbanked | 34 each |

Banked with a strict `<` is also what the theory says: `SumCalendarDays` returns the day the target
is **banked**, as `GerminationDay`'s note records. c3 reproduces the gate on **all 65 annual runs**.

**Its single failure is a perennial regrowth run** (`dtg=0`, `gdtg=5` — `AlfOttawaGDD.CRO`).
`AdjustCalendarDays` assigns `D0` **only** when `TheDaysToCCini == 0`, so on a regrowth the day
value is carried in rather than derived — and on a regrowth there is no germination to test at all.

#### VALIDATED 2026-08-27 — exactly one project moved

Both calendar oracles and **all 13 annual projects byte-identical**; **`OttawaConst` alone moved**
(`OttawaConst.PRM` → `AlfOttawaGDD.CRO`, the const-T alfalfa), on the regrowth run the probe had
named in advance. `Ottawa` — same crop, real weather — did **not** move, because its regrowth runs
carry `dtg=2` rather than `0`.

**Open, for the developer:** on a regrowth the germination term is meaningless either way. A third
form — `NotYetGerminated = .false.` whenever `DaysToCCini /= 0` — would drop the read entirely and
is semantically cleaner; it would be byte-identical on `OttawaConst` (where `dtg=0` makes the term
never fire) but must be **measured** on `Ottawa` before being believed. Deferred: perennial regrowth
is out of scope by the 2026-07-29 decision, and it does not block step A.

**Next, and this is the whole test:** apply `step-a-lookahead-uncalled.patch` on top. If the 13
annual projects are byte-identical with the day twins at their `.CRO` nominal values, the look-ahead
has no readers left and step B is pure deletion.

---

## Reference facts — do not re-derive

### The `DayNrFlowering` event+counter technique (gotchas)

- **`SumCalendarDays` counts inclusively**, so the legacy calendar onset is the day *after*
  GDD reaches the target: the anchor must be `crossingDay + 1`, and `FloweringStarted` gated
  on `DayNri >= DayNrFlowering` (else a spurious negative `DayiAfterFlowering`; Brelative
  differed 68 vs 67 without it).
- **Zero-target trap:** `SumCalendarDays` returns 0 (not 1) for a target of 0. Ottawa alfalfa
  is GDD + Forage + `GDDaysToFlowering = 0`, so `DayNrFlowering` gets a bogus day-1 `+1`;
  harmless only because every `FloweringDayNr` consumer is grain/tuber-gated. Anything routing
  veg/forage through it must handle `target <= 0` first.
- `FloweringDayNr` freezes `DelayedDays` at flowering (fine for grain — germination settles
  first — but not for a day-1 anchor).

### "Banked before today" (the `- GDDayi` in `Pos`)

`SumCalendarDays` returns *the number of days needed to **bank** the target*, so the legacy
onset fires the day **after** GDD reaches the target (today's GDD is not part of the test).
Therefore `Pos = SumGDDadjCC - GDDayi` reproduces the legacy stage onset exactly, for **any**
temperature record. Verified on tuber at constant T: `banked >= 550` first fires at
`VirtualTimeCC = 33` = `ceil(550/17)`; `SumGDD` including today crosses at 32 (one day early).

**Two gate directions need opposite banking** — a single `Pos` can't satisfy both:
- **Germination** (`Pos < P0`, a `<` test) matches calendar with the **unbanked** sum.
- **Harvest** (`Pos > PHarvest`) matches with the **banked** sum and `>=`.
The germination half only bites **maize** (only sown crop with a `CCi==0` bare-soil phase);
transplanted crops have `CCi>0` from day 1 so that half of the gate never fires.

**`DetermineCCiGDD` is NOT the banking authority — do not copy its gate.** Its end-of-cycle test
is `roundc(SumGDDadjCC) > GDDaysToHarvest` on the **unbanked** sum (`simul.f90` ~3503). That is
upstream v7.3 code, not refactor code, and it fires **one day earlier** than the calendar path
it is supposed to mirror. Copying it into `AfterCropCycle` (§11, first attempt) shifted the WP
column one line early across most runs. The authority for a `>` harvest-direction gate is
`CalculateETpot` (§2): `Pos = SumGDDpos - GDDayi`, test `Pos > PHarvest`. The consequence is
that the canopy engine still dies one day before every gate that mirrors the calendar — a
pre-existing upstream inconsistency this refactor has not touched, and a candidate for the
global unbank below.

**But banking alone was not sufficient** — §11 attempt 2 used exactly this form and the veg WP
shift survived. Two things also matter and are easy to miss: the position must be the crop's own
(`SumGDDadjCC`, which for regrowth is *clamped* to `GDDaysToHarvest`, so only `>=` can ever
fire), and `DelayedDays` offsets the calendar position (`VirtualTimeCC`) without offsetting the
GDD sum. See §11 findings 2 and 3.

> **SUPERSEDED 2026-08-03 (developer decision 5): go UNBANKED everywhere, consistently, as a
> single pass at the end.** The "clean-slate alternative" described at the end of this section is
> now the plan, not an option. Everything below is kept because it is the record of *why* banking
> was there and what has to move together when it goes — in particular, the unbank must be one
> pass over **all** gates plus the committed flowering anchor, never stage by stage, and
> `OUTP_REF` is regenerated with it. Do it after the deletion (§20 step B), not before: every gate
> converted so far reproduces the banked calendar day by construction, so unbanking earlier would
> mix two sources of movement in one run.

**Design decision (2026-07-23, NOW SUPERSEDED): keep the banked `+1`-day convention for now;
global unbank is a later option.** The banked `- GDDayi` is deliberate — it makes the `>` gates (harvest,
late-season, the flowering anchor's `crossingDay + 1`) land on the *same day* as the legacy
calendar path, so residual GDD-mode diffs stay *within-stage magnitude* drift (Kc ageing,
HItimesAT, fSwitch) rather than *discrete stage-boundary shifts*. Unbanking would fix only the
minority germination `<` gate (maize-only, and already masked by the `roundc(100·CCi)==0` guard
since CCi is driven by the GDD canopy engine), while shifting every `>` crossing one day early.
Not worth it piecemeal, and it would desync this routine from the already-committed banked
flowering anchor. **The clean-slate alternative** — redefine GDD semantics as "today's GDD
counts, fire on `>=`", unbanked *everywhere at once* + regenerate `OUTP_REF` — is defensible
(arguably the more honest GDD-native convention) and now **cheap**, because `OUTP_REF` is
already regenerated (self-referential, no frozen pre-refactor anchor). Do it, if at all, as a
single pass once **all** `DaysToXXX` reads are converted — never one stage at a time.

### Insufficient-GDD safety (`DaysToHarvest = -9`)

**Where the `-9` actually comes from — traced 2026-07-31, and it is NOT the `GDDAvailable` guard.**
The guard at `run.f90` ~8125 (`if (GDDAvailable >= GetCrop_GDDaysToHarvest()) call
AdjustCalendarCrop(...)`) only *declines to repair* the value, and it lives in
`ResetCropAndSimulationPeriod`, which runs only for delayed germination. The sentinel is written on
the ordinary load path:

1. `LoadSimulationRunProject` calls `AdjustCalendarCrop(Crop_Day1)` **unconditionally**
   (`tempprocessing.f90` 2281) — there is no availability guard there.
2. It sets `DaysToHarvest = SumCalendarDays(GDDaysToHarvest, Crop_Day1, ...)`.
3. `SumCalendarDays` walks the **actual temperature record** subtracting each day's GDD, and stops
   on either "target banked" **or "record exhausted"**. If it exits with `RemainingGDDays > 0` it
   returns `undef_int` (`tempprocessing.f90` ~1342).

So `-9` means **"I ran off the end of the temperature file"** — a statement about the *file's
length*, not about the crop or the climate. `OttawaVeg` run 3 is planted 21 May 2016 and the record
ends 31 Dec 2016 with 1283.4 of the needed 1400 GDD banked; runs 1 and 2 are only spared because
there are one or two more years of file left to borrow.

**And the value it overwrites is perfectly good.** `veg.CRO` declares `140 : Calendar Days: from
transplanting to maturity`. The look-ahead replaces that 140 with `409` (run 1), `398` (run 2) and
`-9` (run 3). So deleting `AdjustCalendarCrop` does not leave the day twins undefined — it leaves
them at the crop file's own nominal values, which is what the remaining readers (§14 items 4 and 6)
would see. That is a materially safer starting point than §12's stale-read case.

Detecting "can't complete" *in advance* is inherently a look-ahead question, unanswerable online —
but the online answer is simply that the crop does not reach its threshold before the season ends,
which needs no sentinel at all. Distinct from `NoMoreCrop` (only trips at `CCiActual <= 0`,
`simul.f90` ~5377) and from the crop-file `PrematureEnd` frost date (zeros `CCiActual`).

### The step-weight trap

Any quantity **accumulated once per day** but normalised by a **stage span** must be weighted
by the step taken on the stage clock (`StageStep = GDDayi` in GDD, `1._dp` in calendar).
Legacy hides this because the step is 1 day. In GDD the span is ~12× bigger, so anything
missing the weight comes out ~12× too small. Scale-free ratios (`fSwitch`,
`HItimesAT1 = (tmax1/pos)*Scor` where `tmax1` cancels) must **not** get the weight — under
constant T they stay identical, a useful self-check.

### The three irreducible within-stage terms

Driving phenology off `SumGDDadjCC` directly is 0-diff at season & harvest for the const
oracles *once within-stage terms use the day clock*. Only three terms genuinely diverge
day-vs-GDD; everything else can stay 0-diff:

1. **`fSwitch` (unlinked)** → biomass. Still irreducible.
2. **`HItimesAT` (sections 2.5–2.7)** → HI/yield. **SOLVED 2026-07-23 (`ee03839`) — this is no
   longer irreducible.** The ~1.5 % HI shortfall was *not* the window length: `HItimesAT` was
   normalising by the banked position `StageAfterFlor`, which overshoots the true step-sum by
   the GDD banked past the flowering threshold on the onset day. Normalising by
   `SumGDDadjCC - SumGDDatFlowering` instead equals the step-sum **exactly at any temperature**
   → `HItimesAT = 1.0` with no stress. Needed the new `Simulation%SumGDDatFlowering` field.
3. **Kc ageing** (`CalculateETpot`) → transpiration/biomass. Still irreducible: `L12`/`LHarvest`
   are rounded `SumCalendarDays` conversions, and the exponential ageing curve amplifies a ~5 %
   `tRel` offset into ~8 % Kc near stage end (~3 % biomass on `OttawaConst`).

### Key structural facts

- The canopy engine already forks on `ModeCycle` (`DetermineCCiGDD` vs `DetermineCCi`); GDD
  canopy triggers on `SumGDDadjCC`.
- Sown crops: `VirtualTimeCC = DayNri - DelayedDays - Day1` (raw days). `SumGDDadjCC =
  Simulation_SumGDD` for sown; the adjusted/clamped scale only applies to regrowth/perennial.
- `TimeToCCini` returns 0 for both `plant_seed` and `plant_transplant`, so transplanted crops
  also have `DaysToCCini = 0` and raw-day `VirtualTimeCC`.
- `SimulParam_Tmin/Tmax` are **not** the daily climate: `MaxAvailableGDD` leaves them at the
  record's *last* day (default 12/28). The `(None)` temperature path uses them as a constant.

---

## Upstream bugs found (for the main developer — not to be fixed on this branch)

1. **`preparefertilitysalinity.f90`, both `...ForTnxReference` routines** — fertility used the
   right source but the wrong direction, salinity the right direction but the wrong source.
   Root cause: no reference-climatology days→GDD function existed. **Fixed** — see §9.
2. **The maize `RedCCX 5→32` day-clock rounding artifact** — see §6.
3. **`tempprocessing.f90:1573` (`AdjustCalendarDays`)** — `CGC = (GDDL12/D12)*GDDCGC` divides by
   the **full** span sowing→full canopy, germination included, while the geometry it feeds
   applies CGC only over germination→full canopy. Consistent divisor is `(D12-D0)`. Valid only
   if GDD/day is the same during emergence as during canopy development. Ottawa maize 2015
   emerged slowly (20 GDD in 6 days vs ~8.4 GDD/day later) → CGC **9.7 % low** → the
   `L12SFmax` branch fires spuriously. Reproduced offline: with the consistent divisor 2015
   does not fire. Present in pristine v7.3; this is what triggers (2).
   The `32` itself is a search artifact — each `+1` on `RedCCX` buys ~0.05 day and the loop
   needed ~1.6 days, so it ground through 27 increments to shave one rounded day.
   *Const-T is the clincher for "rounding, not weather":* at 12/28 the clocks are exactly
   proportional and cannot disagree about physics, yet the day clock fires (28 > 27) and the GDD
   clock does not (322 ≤ 325). The exact margin is 3 GDD = 0.25 day of **surplus**; independent
   `roundc` on both sides turns it into a 1-day **deficit**.
4. **`CropStressParametersSoilSalinity`** — in GDD mode `CCsaltDistortion` has **no effect** on
   the salinity canopy-decline denominator. `L12Double`/`L12SSmax` are only assigned in the
   *calendar* branch, so they keep their init value `L12` and `L12SS` collapses to exactly
   `L12`; the GDD branch's own `GDDL12SSmax` is computed and thrown away. Calendar mode applies
   the distortion correctly. Now on a live path thanks to the salinity testcase.
6. **`DaysToFullCanopySF` read stale in GDD mode** — found and **fixed on this branch**,
   so it is not left for the developer. Full write-up in **§12**. Mentioned here only because
   it originated as a regression from `1cf7caf` and because its symptom (a project changing
   depending on which project ran before it) is worth recognising if it recurs.

7. **`DetermineCCiGDD`'s germination `CCiPrev` repair is unreachable** (`simul.f90` ~3567). It tests
   `abs(SumGDDadjCC - GDDaysToGermination) < epsilon` *inside* the `else` of the entry gate
   `SumGDDadjCC <= GDDaysToGermination`, which has already excluded equality. So the GDD canopy
   engine never seeds its own `CCiPrev` at germination, while the calendar twin (`DetermineCCi`
   ~4911, `VirtualTimeCC == DaysToGermination`) always does. Found while converting §14 item 3;
   consequence written up in §16. Pre-existing in v7.3, left in place on this branch.

8. **The reference-climate walks wrap one day short, and not the way the record walks do.**
   `TCropReference.SIM` and the `TminCropReferenceRun` array hold the **same** 365 days, both rotated
   to start on the crop's day 1 (`DailyTnxReferenceFileCoveringCropPeriod`). But they are consumed
   with three different wrap rules:

   | walk | rule | days used |
   |---|---|---|
   | `SeasonalSumOfKcPot`, `ReferenceClimate = .true.` (`global.f90` ~5853) | close + reopen at EOF | **365** |
   | `SumCalendarDaysReferenceTnx` (`global.f90` ~8878) | `if (i == size(...)) i = 1` | **364** — element 365 never read |
   | `GrowingDegreeDays` reference branch (§9, `tempprocessing.f90` ~965) | same | **364** |
   | the actual-record walks (`SumCalendarDays` ~1199, ~998) | `if (i == 366) i = 1` | **365** |

   So a cycle longer than a reference year makes the day count and the Kc sum drift apart by one day
   per wrap.

   **The suite DOES wrap — an earlier claim here that it does not was wrong.** Measured over
   `TCropReference.SIM` (365 days from 21 May): maize needs **391** days to bank 1700 GDD, veg
   **402** for 1400, tuber **371** for 2000; only alfalfa (349 for 1920) stays inside the year. The
   wrong claim came from dividing the target by a *growing-season* GDD rate; the reference year
   includes winter, so these walks run past 365 and into a second spring. Anything reasoning about
   "how long is the reference walk" must use the whole year's profile, not a summer rate.

   **FIXED ON THIS BRANCH 2026-07-31 (developer's call), both halves together.** `i == size` became
   `i > size` in `SumCalendarDaysReferenceTnx` (`global.f90`) *and* in the `GrowingDegreeDays`
   reference branch (`tempprocessing.f90`), so the walk now reads day 365 and wraps to day 1 after
   it. They are inverses and §9 mirrored the wrap deliberately, so fixing one alone would break the
   round-trip — that is why both move in the same commit.

   **Output change: none — and unlike the mulch case this zero diff is NOT vacuous.** Three of the
   four crops wrap, so the changed line executes. It is inert because the *count* is unaffected:
   swapping which single day is read near the end of a ~400-day walk does not change how many days
   are needed to reach the target (veg: 402 either way; the skipped day 365 carries 4.46 GDD out of
   1400). The fix still matters — it removes a silent one-day-per-year loss that would bite a
   longer cycle or a steeper reference year — but it is confirmed exercised, not merely assumed.

   Same family, same routine: `do while (RemainingGDDays > 0.1)` in `SumCalendarDaysReferenceTnx`
   has **no iteration cap**, so a crop whose `Tbase` sits above the entire reference climatology
   (every `DayGDD` = 0) hangs rather than returning a sentinel. Also unreachable in the suite, also
   pre-existing.

10. **`SumCalendarDays` and `SumCalendarDaysReferenceTnx` count the final partial day by different
    rules**, so the two disagree by one day even when they walk identical temperatures.
    `SumCalendarDays` counts every day it consumes. `SumCalendarDaysReferenceTnx` counts the last
    one only when `roundc((DayGDD - Remaining)/Remaining) >= 1` — i.e. it *drops* the day when only
    a small slice of it was needed, and `roundc` is banker's rounding, so the tie goes to dropping.
    Measured at constant 12 GDD/day: `GDDaysToFullCanopy` agrees (both 27) while
    `GDDaysToHarvest = 1210` gives 101 from the record walk and 100 from the reference walk (§19).

    Harmless where the two are used independently; it matters wherever a *span* is built from one
    of each, or where a const-T project is expected to be an oracle. It is why
    `OttawaMaizeSaltConst` moved in §19 after being predicted identical. Report upstream: the two
    should share a rounding convention. Do not "fix" one in isolation — see bug (8) for why the
    reference pair moves together.

5. **The regrowth time-scale fork asks one question on two clocks and gets two answers**
   (`run.f90` ~6973 calendar vs ~6995 GDD). "Am I past senescence?" is tested as
   `(DayNri - DelayedDays - Day1) <= DaysToSenescence` on one side and
   `SumGDDfromDay1 <= GDDaysToSenescence` on the other. For the Ottawa perennial they disagree
   for part of the run: the calendar clock stays in the compressed *slow down* branch while the
   GDD clock has moved to *switch time scale*. Consequences: `VirtualTimeCC` asymptotes below
   `DaysToHarvest` (so any `> DaysToHarvest - 1` gate is unreachable) while `SumGDDadjCC` becomes
   raw and un-clamped — measured at **2048.05 against a clamp of 2048**. Found by the §11 probe;
   it is what blocks Forage from the group-A conversion. Pre-existing in v7.3.

---

## Still to do

- ~~Regenerate `OUTP_REF` after §12~~ — **done**, folded into `c91d332` itself rather than a
  separate commit. `OUTP_REF` is therefore current as of §12, and §11's byte-identical result is
  measured against it.

  **Caveat worth remembering:** §12 moved the perennials **+0.09 %**, and
  `compare_outputs.sh` tolerates **≤ 0.1 %**. Had the references not been regenerated, that
  change would have sat just under the threshold and a later +0.05 % would still have "passed"
  while being 0.14 % from pristine. Regenerate references whenever a change is *expected* to
  move output, rather than leaning on the tolerance.
- **Crop end / `Crop_DayN`** (`run.f90` ~8081, `DayN = Day1 + DaysToHarvest - 1`). Two
  independent jobs. **Group A is DONE** — landed and byte-identical, see §11. What remains of the
  per-day family is only the deliberate exclusions: `DetermineCCi` (calendar-only) and the
  irrigation season-offset sites, which need an end *date* and are a semantics question (below).
  **Group B** is the **run-length bookkeeping**: `Simulation_ToDayNr`
  (`run.f90` 8084, `global.f90` 4932/4948), the climate-record extension `AdjustClimRecordTo`,
  `NextSimFromDayNr` for KeepSWC chaining, `TemperatureFileCoveringCropPeriod`, the CO2 window
  (`run.f90` 4846), and the crop-file load path (`tempprocessing.f90` 2223–2279,
  `initialsettings.f90` 426–433). **The design decision this waited on is now made** (developer,
  2026-07-30: the simulation period may extend beyond the crop cycle). So the direction below is
  no longer "to consider" — it is **the plan**:

  The codebase already models "crop ended before the planned run end" for the premature-end case —
  `DayNrPrematureEnd` drives `Crop_LastDayNr < DayN` (`global.f90` 4964–4966) and `NoMoreCrop` is
  an online end-of-crop signal. Let the **normal** crop end use that same mechanism: plan the run
  period from the climate record / user period, let the crop close on its own thermal gate. Every
  remaining group-B read then becomes a conservative over-estimate, which is safe for all of them.
  Note the useful fact recorded under the forage item: the perennial search window is anchored to a
  **calendar date**, so a bounded run horizon is derivable *without* knowing the outcome — which is
  what makes "set `ToDayNr` generously, let the crop close itself" principled rather than arbitrary.
- **Irrigation season offsets — a semantics question, not a conversion.** Left on `DayN`
  deliberately by §11 because they need an end *date* or an offset from it, not a boolean:
  `IrriOutSeason` (`run.f90` 6229–6230, `DNr = DayNri - DayN` indexes the `IrriAfterSeason`
  events), the `.IRR` EOF fallback "apply until end of season" (`run.f90` 4509, 6322), the
  irrigation-info writer (`run.f90` 7935–7943), the in/out-season branch that feeds
  `IrriOutSeason` (`run.f90` 6306/6313), and the countdown `dayi >= DayN - IrriInfoLastDay + 1`
  (`simul.f90` 5672). "Irrigate N days before the end" is inherently look-ahead. Raise with the
  developer together with the forage item.
- **Forage end-of-season — OUT OF SCOPE, permanently. CLOSED, not merely parked.**
  *Developer decision, 2026-07-29, **reaffirmed 2026-08-03 (decision 3)**: perennials will always
  take their end date from the PRM's `Crop_LastDayNr`. Only annuals must stop needing `Crop_DayN`.*

  **And the "missing" season generation is not missing — it lives in the GUI, by design.** The audit
  below established that the engine parses the whole perennial block and never evaluates it; the
  2026-08-03 answer is that this is correct and intended. The GUI evaluates the rule against the
  climate and writes the resulting date into the PRM; the standalone consumes that date. So the
  three latent traps listed further down are **not** work items — they are notes on code that should
  arguably be *deleted* from the engine rather than implemented. Raise that as a cleanup proposal,
  not as a gap.

  How a perennial's end date is actually produced, confirmed end to end:

  1. The `.CRO` carries the **rule**. `LoadCrop` parses the whole perennial block into
     `perennialperiod` (`global.f90` 5486–5563) — `GenerateEnd`, `EndCriterion`, threshold,
     window, successive days, occurrence.
  2. The **GUI** evaluates it against the climate and derives a date.
  3. The date is written to the **project file** (PRM/PRO), *not* the crop file, as
     *Last day of cropping period* → `project_input.f90` 259 → `tempprocessing.f90` 2122
     (`Crop_LastDayNr`) → 2238 (`SetCrop_DayN`, forage only).

  **The engine never evaluates the rule.** Every getter has zero consumers —
  `GenerateEnd`/`GenerateOnset`, `EndCriterion`/`OnsetCriterion`, `End{Threshold,Period,LastDay,
  LengthSearchPeriod,StartSearchDayNr,StopSearchDayNr}Value`, `ExtraYears`,
  `GeneratedDayNrOnset`/`End`, and also `GetOnset_AirTCriterion` / `GetEndSeason_AirTCriterion`.
  **There is no season-generation code in this engine at all**, for perennials or annuals.
  A user-supplied file with end criterion `62`, threshold `0.0 °C` and **`0` successive days**
  confirms it: that cannot express a real rule, and nobody would notice.

  If it were ever implemented, three latent traps — all inert today *only* because nothing reads
  the block, and all live the moment something does:

  - **Not GDD-only.** `EndCriterion` may be `AirTCriterion_TMeanPeriod` (code `62`) as well as
    `GDDPeriod` (`63`). An online gate needs both arms; "stop when the GDD budget is reached"
    covers only `63`.
  - **Silent criterion fallback.** The enum has four values (`global.f90` 109–116: `TminPeriod`,
    `TmeanPeriod`, `GDDPeriod`, `CumulGDD`) but the reader maps only two per direction (onset
    `12`/`13`, end `62`/`63`). Anything else hits `case default` → `GenerateEnd = .false.`, i.e.
    silently reinterpreted as "fixed on a specific day". No warning.
  - **Stale `EndCriterion`.** Assigned only when `GenerateEnd` is true, so otherwise it retains
    the *previous crop file's* value — same family as the §12 `DaysToFullCanopySF` bug.

  Also note `SaveCrop` (`global.f90` 3716–4215) **never writes the perennial block**, while
  `LoadCrop` reads it with no `iostat` and no version guard. So `SaveCrop` output for a forage
  crop cannot be re-loaded. Harmless today — the only caller (`defaultcropsoil.f90` 288) writes a
  non-forage `DEFAULT.CRO` — but it is a real format asymmetry. **Report upstream.**

  One genuinely useful fact if group B is ever revisited: the search window is anchored to a
  **calendar date** (`EndLastDay`/`EndLastMonth`/`ExtraYears`) with `EndLengthSearchPeriod` days
  searched back from it. A bounded run horizon is therefore derivable *without* knowing the
  outcome — which is what would make "set `ToDayNr` generously, let the crop close itself"
  principled rather than arbitrary.
- ~~**`ScorAT1`/`ScorAT2` restart init**~~ — **DELETE, don't convert** (developer decision 4,
  2026-08-03: starting a run inside the growing period is no longer maintained). Converted in §18;
  that conversion is now superseded by removal. See the §18 banner for the full removal list and the
  `Tadj`/`GDDTadj` overlap with forage regrowth.

- **`RatDGDD` is computed by two different formulas — runtime vs calibration.** Found 2026-08-03
  while confirming decision 1; not a blocker, but an unexamined inconsistency of exactly the kind
  §9/§17/§19 each closed.

  | where | how |
  |---|---|
  | `InitializeSimulationRunPart2` (`run.f90` 5173), `GetPotValSF` (6608), `AdvanceOneTimeStep` (7113), `DetermineCCiGDD` (`simul.f90` 3530) | `RatDGDDReference()` — **mean rate** over the decline window, dormant days excluded |
  | `StressBiomassRelationshipForTnxReference` (`preparefertilitysalinity.f90` 418) | `(L123-L12SF)/(GDDL123-GDDL12SF)` — **ratio of spans** |
  | `CCxSaltStressRelationshipForTnxReference` (`preparefertilitysalinity.f90` 635) | `(L123-L12SS)/(GDDL123-GDDL12SS)` — **ratio of spans** |

  Both are look-ahead-free since §9, so nothing is blocked. But they are not the same quantity: a
  ratio of endpoints versus a mean rate that skips zero-GDD days. They coincide only where every day
  in the window carries GDD *and* the two spans are exact inverses — which upstream bug (10) says
  they are not. Net effect: the fertility/salinity relationship is **built** with one days-per-GDD
  conversion and **applied** with another. Expect this to be small for annuals (mid-season window, no
  dormant days) and possibly not small for the perennial, where the dormant-day exclusion was worth
  ~2.5×. **Measure before deciding** — do not assume it is negligible, and do not assume it matters.

- **Three copies of the canopy-decline arithmetic.** `RatDGDD*CDecline` appears in
  `CCiNoWaterStressSF` (`global.f90` 1601/1647/1656) and is **inlined again twice** in
  `DetermineCCiGDD` (`simul.f90` 3559 and 3745) rather than routed through it. Same formula, three
  places. Any units change — the per-GDD `.CRO` discussion under BLOCKED below — has to touch all
  three, and they can drift apart silently. Worth proposing they become one function.

**BLOCKED — salinity `CDecline`.** Earlier notes called this a free one-line swap to
`(GDDL123 - GDDL12SS)`. **That is wrong.** `simul.f90` ~4289 merges the fertility and salinity
`CDecline` with `max()` into the single `Simulation%EffectStress%CDecline`, and *that merged
value* is multiplied by `RatDGDD` in the GDD branch of `CCiNoWaterStressSF`
(`global.f90` 1570/1616/1625). Making only the salinity term per-GDD converts it **twice**
(~12× wrong), and after the `max()` the two cannot be told apart to exempt one. So it is blocked
behind the same thing as the fertility decline: the decline **magnitude** must move into the
`.CRO` as a per-GDD value for *both* stresses together — an upstream format change (new line +
version bump). `ShapeCDecline` cannot simply be re-fitted per GDD: with `pUL=0`/`pLL=1`,
`CDecline(p,S) = (e^(pS)-1)/(e^S-1)` is pinned at 1 for 100 % stress for *every* shape, so a
re-fit matches at one stress level only.

Only once **all** reads are gone can `AdjustCalendarDays` / `SumCalendarDays` be deleted.
The `DayNrFlowering` anchor pattern is the template for the other `DaysToXXX` stages.

**Temporary validation idea (not yet wired):** convert each GDD threshold back to days with
`SumCalendarDays` and assert it equals the stored `DaysTo*`; a silent run proves the
conversion is self-consistent so residual diffs are pure banking. Belongs in `simul.f90`
(which already `use`s `SumCalendarDays`), not `CalculateETpot` (`ac_global` can't see it).
Remove once trusted — it *is* the look-ahead.

Open caveat: the `DayNrFlowering` anchor assumes sown/transplanted (`VirtualTimeCC` = raw
days). A regrowth GDD grain/tuber crop (exotic) would need a `DaysToCCini == 0` guard.

---

## Test suite

`testcase/LIST/ListProjects.txt` runs **15** projects × 3 runs each (21 May → 31 Oct of
2014/2015/2016; the salinity, mulch and delay projects share the same calendar).

**Two projects exist solely to light paths nothing else reaches. Do not drop them.**

- **`OttawaMaizeMulch.PRM`** (§14) — the only project with mulches or partial wetting
  (`OttawaMulch.MAN` 50 %, `IrriGenFw.IRR` 50 % wetted). Everything else has `Mulch = 0`, no OFF
  file and 100 % wetted irrigation, which made all five in/off-season gates of
  `AdjustEpotMulchWettedSurface` unreachable.
- **`OttawaMaizeDelay.PRM`** (§15) — the only project with `DelayedDays > 0`
  (`DryTopSoil.SW0` starts at 14.00 vol% against a 16.2 vol% germination threshold, so sown maize
  waits for rain). Without it `ResetCropAndSimulationPeriod` never executes at all.

Both were added *after* a change to the code they cover had already "passed" the suite. That is the
pattern to expect: a clean run over the other projects says nothing about a gate no project reaches.

Beyond the 8 below: `OttawaMaizeCal.PRM` (`MaizeCalwpy.CRO`) is the **calendar bit-identity
oracle** — the whole suite was GDD-mode until 2026-07-23, so every `ModeCycle` else-branch was
dead in tests. Its `OUTP_REF` is generated from a **pristine v7.3 build** (`main`), so it is a
true "== upstream" oracle rather than a current-build regression guard. The four
`OttawaMaizeSalt*` projects (§8) cover salinity and irrigation; `OttawaMaizeSaltCal` is their
calendar oracle and is likewise referenced against pristine.

| Project | Crop | MAN | Temperature | Purpose |
| --- | --- | --- | --- | --- |
| `Ottawa.PRM` | `AlfOttawaGDD.CRO` | `Ottawa.MAN` | `Ottawa.Tnx` | perennial alfalfa/Forage, regrowth; years 1/2/3 + KeepSWC; `GDDaysToFlowering = 0` (zero-target) |
| `OttawaMaize.PRM` | `MaizeGDDwpy.CRO` | `Ottawa2.MAN` | `Ottawa.Tnx` | sown Grain, `DeterminancyLinked = 1` |
| `OttawaTuber.PRM` | `tuberwpy.CRO` | `Ottawa2.MAN` | `Ottawa.Tnx` | transplanted Tuber, GDDFlor 550, `DeterminancyLinked = 0` |
| `OttawaVeg.PRM` | `veg.CRO` | `Ottawa2.MAN` | `Ottawa.Tnx` | transplanted Vegetative, GDDFlor 0; 2016 is the insufficient-GDD / off-season-Kc case |
| `OttawaConst.PRM` | `AlfOttawaGDD.CRO` | `Ottawa.MAN` | **`(None)`** | perennial constant-T oracle via `(None)` = SimulParam 12/28 |
| `OttawaMaizeConst.PRM` | `MaizeGDDwpy.CRO` | `Ottawa2.MAN` | `OttawaConst.Tnx` | constant-T oracle |
| `OttawaTuberConst.PRM` | `tuberwpy.CRO` | `Ottawa2.MAN` | `OttawaConst.Tnx` | constant-T oracle |
| `OttawaVegConst.PRM` | `veg.CRO` | `Ottawa2.MAN` | `OttawaConst.Tnx` | constant-T oracle |

- Annual projects use `YearSeason = 1` + `SW0 = (None)` (independent seasons); only the
  perennials use years 1/2/3 + `KeepSWC`.
- **MAN split:** perennials use `Ottawa.MAN` (cuttings ON + cut list); annuals use
  `Ottawa2.MAN` (cuttings OFF, fertility 50→21, weed shape 100→-0.01).
- WP-decline block needs `WPy < 100`, so grain/tuber use `*wpy` copies (`MaizeGDDwpy.CRO`,
  `tuberwpy.CRO`, WPy 90).
- `OttawaConst.Tnx` clones `Ottawa.Tnx`'s header/length with every row `12.0 28.0`. Method-3
  GDD/day at 12/28: maize 12, tuber 17, veg 10, alfalfa 15.

### Workflow

```sh
module load foss                      # build tools behind lmod
cd src && make                        # NOT `make bin`
cd ../testcase && ./aquacrop && ./compare_outputs.sh   # OUTP vs OUTP_REF, 0.1% rel tol
```

To regenerate a clean reference: build clean (no debug), run, copy `OUTP/*` to `OUTP_REF/`.
`testcase/{test.txt, OUTP_TMP/}` are untracked local debug/scratch (gitignored).
`testcase/SIMUL/{EToData,RainData,TempData,TCrop}.SIM` are **written by the program** each run
despite being tracked — their churn is expected and should not be committed.

---

## Archive — parked stage-clock rewrite (kept to avoid re-deriving)

> The material below is a later **stage-clock rewrite** of `DeterminePotentialBiomass` /
> `DetermineBiomassAndYield` that generalised the committed flowering work (§1) onto a single
> `StageNow` clock. It was **parked** on 2026-07-16 (`simul.f90` reverted to the 0-diff commit
> `d042ad1`; the rewrite saved as `stage-clock-wip-2026-07-16.patch` at the repo root —
> `git apply` it onto `d042ad1`'s `simul.f90` to restore). We pivoted to the incremental,
> stay-bit-identical approach above (CalculateETpot first). The proven facts have been promoted
> into "Reference facts"; the narrative is retained here.

**Parked-patch 0-diff result:** `OttawaMaizeConst`/`OttawaTuberConst` SAME at season &
harvest (daily `Brelative ±1` cosmetic transient only); `OttawaVegConst`/`Ottawa*` fully
SAME; variable-T runs DIFF as expected (day-vs-GDD).

**The stage-clock fork.** Both routines opened with one `ModeCycle` fork setting
`StageNow / StageFlor / StageLenFlor / StageSenescence / StageYieldForm / StageStep`, plus
`StageAfterFlor = StageNow - StageFlor` and `HasFlowered = StageNow >= StageFlor`. GDD branch:
`SumGDDadjCC - GDDayi` + `GDDays*`, `StageStep = GDDayi`. Calendar branch:
`dayi - Day1 - DelayedDays` + day params, `StageStep = 1._dp`, `StageYieldForm =
roundc(HI/dHIdt)` (byte-identical). Everything downstream (`fSwitch`, yield gate, pollination
window, `tmax1`, `tmax2`, section-2.7 blend, `FractionPeriod` `TimePerc`) compared positions on
that clock and never re-tested `ModeCycle`; `tmax1`/`tmax2` became `real(dp)` (`== 0` →
`<= 0._dp`); `DaysYieldFormation`/`DayiAfterFlowering`/`DayCor` removed. `FloweringDayNr`
survived only to feed the still-day-based `HarvestIndexDay`.

**Parked two-convention `+1` detail.** WP block opens **on** the onset day
(`>= DaysToFlowering`); yield block opens the **day after** (`dayi > FloweringDayNr`). Yield
block gates on `HasFlowered .and. dayi > FloweringDayNr`, not `StageAfterFlor > 0` (onset-day
overshoot would open it a day early).

**Parked audit — `AdjustCalendarCrop` (`tempprocessing.f90` ~1645, GDD case)** overwrites
`DaysToGermination/FullCanopy/Flowering/LengthFlowering/Senescence/Harvest/MaxRooting/HIo/`
`Length/CGC/CDC/dHIdt` — all look-ahead products. `HarvestIndexDay` builds HI at a per-day
rate (needs `dHIdGDD`); `FractionPeriod` needs `TimePerc = 100*(SumGDD-GDDFlor)/GDDLengthFlor`;
`tmax1`/`tmax2` double as day denominators so converting them changes the stress arithmetic.
`GetWeedRC` already forks internally on `ModeCycle`.

**Measured variable-T deviation (earlier):** maize Ottawa mid-window HI trajectory differs
3–5 % of HIo (max 4.6/3.7/3.0 % for 2014/15/16), converging at endpoints. `LHImax` swings
79/73/67 days across years for identical crop params — the look-ahead re-deriving the calendar
from each year's weather, which is exactly what we're removing.
