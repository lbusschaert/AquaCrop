# GDD-native phenology refactor

Working notes / design rationale. Status as of **2026-07-17**.

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

### 2. CalculateETpot → GDD-native (2026-07-17, current uncommitted work)

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

1. **`fSwitch` (unlinked)** → biomass.
2. **`HItimesAT` (sections 2.5–2.7)** → HI/yield: the GDD `StageAfterFlor` carries banked
   overshoot and its window gate stays open ~1 day longer, landing `HItimesAT ≈ 0.984`,
   dragging HI ~1.5 % low while biomass is exact.
3. **Kc ageing** (this session, `CalculateETpot`) → transpiration/biomass, as above.

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

## Still to do

- `DeterminePotentialBiomass` / `DetermineBiomassAndYield`: `DaysYieldFormation` / `dHIdt` and
  the `HarvestIndexDay` day-rate (needs `dHIdGDD = HI / GDDaysToHIo` + a GDD variant).
- `LengthFlowering`, `DaysToSenescence` reads that still feed `tmax1`/`tmax2` as day spans
  (converting them changes the stress-weighting arithmetic, not just the trigger).
- The `RatDGDD` CDC rescale (hardest; do last).
- `DaysToGermination` / `Senescence` / `Harvest` reads in `run.f90`.

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

`testcase/LIST/ListProjects.txt` runs 8 projects × 3 runs each (21 May → 31 Oct of
2014/2015/2016).

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
