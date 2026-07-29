# GDD-native phenology refactor

Working notes / design rationale. Status as of **2026-07-29**.

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
   Neither behaviour is clearly the intended one — **still an open question for the developer**,
   just no longer a blocker.
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

**Design decision (2026-07-23): keep the banked `+1`-day convention for now; global unbank
is a later option.** The banked `- GDDayi` is deliberate — it makes the `>` gates (harvest,
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

`AdjustCalendarCrop` — which fills the calendar `DaysTo*` from the GDD thresholds — is only
called **when the season can bank enough GDD**: `run.f90` ~8058
`if (GDDAvailable >= GetCrop_GDDaysToHarvest()) call AdjustCalendarCrop(...)`. In a cool year
that fails, so `DaysToHarvest` keeps its `-9` "cannot reach harvest" sentinel while
`GDDaysToHarvest` keeps the intrinsic value. `GDDAvailable` comes from `MaxAvailableGDD`
scanning the whole record — i.e. detecting "can't complete" is *inherently* a look-ahead
question, unanswerable online. Distinct from `NoMoreCrop` (only trips at `CCiActual <= 0`,
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

- **Regenerate `OUTP_REF` for `Ottawa` and `OttawaConst`** after §12 lands — separate commit,
  as with `43b7966`. Nothing else in the suite moved.
- **Crop end / `Crop_DayN`** (`run.f90` ~8081, `DayN = Day1 + DaysToHarvest - 1`). Two
  independent jobs. **Group A is DONE** — landed and byte-identical, see §11. What remains of the
  per-day family is only the deliberate exclusions: `DetermineCCi` (calendar-only) and the
  irrigation season-offset sites, which need an end *date* and are a semantics question (below).
  **Group B** is the **run-length bookkeeping**: `Simulation_ToDayNr`
  (`run.f90` 8084, `global.f90` 4932/4948), the climate-record extension `AdjustClimRecordTo`,
  `NextSimFromDayNr` for KeepSWC chaining, `TemperatureFileCoveringCropPeriod`, the CO2 window
  (`run.f90` 4846), and the crop-file load path (`tempprocessing.f90` 2223–2279,
  `initialsettings.f90` 426–433). The difficulty is unchanged and is **not** the gate — it is
  that the **run length stops being known before the run starts**. Needs a design decision.
  *Direction to consider:* the codebase already models "crop ended before the planned run end"
  for the premature-end case — `DayNrPrematureEnd` drives `Crop_LastDayNr < DayN`
  (`global.f90` 4964–4966) and `NoMoreCrop` is an online end-of-crop signal. Letting the
  **normal** crop end use that same mechanism (plan the run period from the climate record /
  user period, let the crop close on its own thermal gate) turns every remaining group-B read
  into a conservative over-estimate, which is safe for all of them.
- **Irrigation season offsets — a semantics question, not a conversion.** Left on `DayN`
  deliberately by §11 because they need an end *date* or an offset from it, not a boolean:
  `IrriOutSeason` (`run.f90` 6229–6230, `DNr = DayNri - DayN` indexes the `IrriAfterSeason`
  events), the `.IRR` EOF fallback "apply until end of season" (`run.f90` 4509, 6322), the
  irrigation-info writer (`run.f90` 7935–7943), the in/out-season branch that feeds
  `IrriOutSeason` (`run.f90` 6306/6313), and the countdown `dayi >= DayN - IrriInfoLastDay + 1`
  (`simul.f90` 5672). "Irrigate N days before the end" is inherently look-ahead. Raise with the
  developer together with the forage item.
- **Forage end-of-season — OUT OF SCOPE, but documented so it is not re-derived.**
  *Developer decision, 2026-07-29: perennials keep taking their end date from the PRM. Only
  annuals must stop needing `Crop_DayN`.* Recorded here because the audit is done and the
  conclusion is non-obvious.

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
- **`ScorAT1`/`ScorAT2` restart init** (`run.f90` ~5357): reads `DaysToFlowering`,
  `LengthFlowering`, `DaysToSenescence`, `dHIdt` unconditionally. Only bites when a run *starts*
  after flowering, so it is inert in the suite — convertible but invisible.

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

`testcase/LIST/ListProjects.txt` runs **13** projects × 3 runs each (21 May → 31 Oct of
2014/2015/2016; the salinity projects share the same calendar).

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
