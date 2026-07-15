# GDD-native phenology refactor

Working notes / design rationale. Status as of 2026-07-15.

## Goal

In GDD mode, drive phenology from accumulated GDD directly and stop consuming the
calendar-day values produced by the planting-time look-ahead conversion
(`AdjustCalendarDays` / `SumCalendarDays` / `GrowingDegreeDays`), so that the full
temperature record need not be known in advance. End goal: delete that conversion.

## Decision (2026-07-15): go GDD-native, accept the diff

Bit-identity against the legacy code was the original correctness oracle. It has been
**deliberately dropped for GDD mode**, because it is not achievable:

* `SumCalendarDays` counts inclusively, so legacy's flowering day is the day *after*
  `SumGDD` crosses the target. Legacy's `dayi > FloweringDayNr` therefore needs `SumGDD`
  as of `dayi-2`; no test on today's `SumGDD` (nor `SumGDD - GDDayi`, i.e. yesterday's)
  can express that. The `+1` anchor **is** the bridge between GDD space and the calendar
  days legacy baked in — it is not incidental complexity.
* More fundamentally, legacy interpolates **linearly in days** within a stage, whereas
  GDD-native interpolates **linearly in GDD**. These coincide only when daily GDD is
  constant. That divergence is the point of the refactor, not a defect.

### Measured size of the expected deviation

Maize / Ottawa / GDD method 3 / Tbase 8 / `GDDaysToFlowering` 276 / `GDDaysToHIo` 858:
the mid-window HI trajectory differs by **3-5 % of HIo** (max 4.6 / 3.7 / 3.0 % for
2014 / 2015 / 2016), converging at the endpoints. Not last-digit, but not chaos.

Also telling: `LHImax` swings 79 / 73 / 67 days across 2014-2016 for *identical* crop
parameters - the look-ahead silently re-deriving the calendar from each year's weather.

### New oracle: the constant-temperature projects

With constant Tmin/Tmax, daily GDD is constant, day-space and GDD-space are linearly
related, and `SumCalendarDays(X)` collapses to `ceil(X / GDD_day)`. GDD-native must then
still match legacy to within the <= 1-day inclusive-count rounding. **If the const-T
projects drift, it is a wiring bug, not physics.** The variable-temperature runs are
judged on magnitude (expect the ~3-5 % band) and plausibility, not on being zero.

## Key structural facts

* The canopy engine already forks on `ModeCycle`: `DetermineCCiGDD` (GDD) vs
  `DetermineCCi` (days, dead in GDD mode). GDD canopy already triggers on `SumGDDadjCC`.
* For **sown** crops `VirtualTimeCC = DayNri - DelayedDays - Day1` (raw days, steps by 1);
  the slow-down/adjusted scale applies only to regrowth/perennial.
  `SumGDDadjCC = Simulation_SumGDD`.
* `TimeToCCini` returns 0 for `plant_seed` *and* `plant_transplant` (`global.f90` ~1800),
  so transplanted crops also have `DaysToCCini = 0` and raw-day `VirtualTimeCC`.

## Technique: look-ahead -> event + counter

Per-run state `Simulation%DayNrFlowering` (`global.f90` Get/Set; reset to `undef_int` at
`run.f90` ~5019 next to the SumGDD reset). Set when `SumGDDadjCC >= GDDaysToFlowering`,
then derive days-after-flowering from it instead of `DaysToFlowering`.

**Gotcha:** `SumCalendarDays` counts inclusively, so the legacy calendar onset is the day
*after* GDD reaches the target. The anchor must be `crossingDay + 1`, and
`FloweringStarted` must be gated on `DayNri >= DayNrFlowering` (otherwise a spurious
negative `DayiAfterFlowering` on the crossing day). Without this, Brelative differed by 1
(68 vs 67).

### Zero-target trap

The `+1` rule only holds for `GDDaysToFlowering > 0`. `SumCalendarDays` opens with
`NrCdays = 0; if (ValGDDays > 0) then ...`, so a target of 0 converts to 0 days, not 1.
Ottawa alfalfa is GDD mode + Forage + `GDDaysToFlowering = 0`, so `DayNrFlowering` is set
on crop day 1 with a bogus `+1` (and `VirtualTimeCC` is not raw days for regrowth anyway).
This is harmless today **only** because every `FloweringDayNr` consumer is grain/tuber
gated. Anything that later routes veg/forage through `FloweringDayNr` must handle
`target <= 0` first.

Related: `FloweringDayNr` freezes `DelayedDays` at flowering time whereas legacy re-reads
it live - fine for grain (germination settles long before flowering), but not for a
day-1 anchor.

## Done so far

1. **WP-decline block** in `DeterminePotentialBiomass`.
2. **HI build-up block** in `DetermineBiomassAndYield`, grain/tuber only. Added shared
   locals `FloweringDayNr` (= anchor in GDD, = `Day1 + DelayedDays + DaysToFlowering` in
   calendar mode) and `HasFlowered`; routed the `HarvestIndexDay` call, WP reproductive,
   main yield gate, pollination window, `tmax1`, `DayCor` x2, `tmax2` window and both
   `FractionFlowering` uses through them. Before flowering, `HarvestIndexDay` is passed
   `DaysToFlowerLoc = (dayi - Day1 - DelayedDays) + 1` to force `t <= 0` (HI = 0),
   matching legacy.
3. **veg/forage yield gate**: dropped the `+ DaysToFlowering` term outright. Provably
   identical, not merely empirically: for Vegetative/Forage `DaysToFlowering` is forced to
   0 at crop-file load (`global.f90` ~5151) and `AdjustCalendarDays` only assigns `DFlor`
   in its `case (subkind_Grain, subkind_Tuber)` branch (`tempprocessing.f90` ~1540) - it
   is a hardcoded 0, never a look-ahead product. Deliberately *not* routed through
   `FloweringDayNr` (see zero-target trap).
4. **Fertility-stress + determinancy gate**: now
   `subkind_grain .and. DeterminancyLinked .and. HasFlowered .and. dayi > FloweringDayNr + tmax1`.
   The single `HasFlowered` term does both jobs: calendar mode keeps legacy exactly
   (`HasFlowered` is always true there, so the pre-flowering quirk survives), while GDD
   mode drops the quirk because the flowering day is unknowable until it happens.

   *The quirk:* `tmax1` is reset to `undef_int` (-9) each call and only assigned inside the
   `dayi > FloweringDayNr` block, so the legacy gate read `dayi > FloweringDayNr - 9` and
   fired on the 9 days up to **and including** the flowering day, ratcheting
   `StressSFadjNEW` up to `PreviousStressLevel` - clearly not the intent of a check named
   "potential vegetation period is exceeded".

## Audit of `DetermineBiomassAndYield` (2026-07-15)

`DaysToFlowering` is now fully converted there (only the calendar-mode `else` branches
remain, which is intentional). **But the routine is still not GDD-native.**
`AdjustCalendarCrop` (`tempprocessing.f90` ~1645, GDD case) overwrites
`DaysToGermination`, `DaysToFullCanopy`, `DaysToFlowering`, `LengthFlowering`,
`DaysToSenescence`, `DaysToHarvest`, `DaysToMaxRooting`, `DaysToHIo`, `Length`, `CGC`,
`CDC` **and `dHIdt`** - all are look-ahead products. Three are still read GDD-live:

| Value | Where | Affects |
| --- | --- | --- |
| `dHIdt` (= HI/LHImax, LHImax = `SumCalendarDays(GDDHImax)`) | `HarvestIndexDay` arg ~685; `DaysYieldFormation` ~705 (and the same in `DeterminePotentialBiomass`); `tmax2` ~944/947 | HI, biomass, yield |
| `LengthFlowering` (= `SumCalendarDays(GDDLengthFlor)`) | pollination window ~886; `tmax1` determinancy-**linked** ~919; `FractionFlowering`/`FractionPeriod` ~1098/1108/1123 | yield |
| `DaysToSenescence` (= `SumCalendarDays(GDDL123)`) | `tmax1` determinancy-**unlinked** ~921 | yield |

Notes:

* `HarvestIndexDay` builds HI at a per-**day** rate; GDD-native needs
  `dHIdGDD = HI / GDDaysToHIo` and a GDD variant of the function.
* `FractionPeriod` needs `TimePerc` as a GDD fraction:
  `100 * (SumGDD - GDDFlor) / GDDLengthFlor`.
* **`tmax1`/`tmax2` are also used as day denominators** (`ScorAT1 += Dcor/tmax1`, then
  `HItimesAT1 = (tmax1/DayCor) * ScorAT1`). Converting them to GDD spans changes the
  stress-weighting arithmetic, not just the trigger. Think before touching.
* `GetWeedRC` (~759) is already fine: it takes both day and GDD values plus `ModeCycle`
  and forks internally.
* Section 3 (fertility stress) has no day dependence of its own beyond `tmax1`.
* The reads at `simul.f90` ~530/543/653/682 are the calendar-mode `else` branches of the
  forks - intentional, not blockers.

## Still to do

* `DeterminePotentialBiomass` (`DaysYieldFormation`/`dHIdt`).
* `CalculateETpot`/Kc - day-native, no GDD path at all.
* The `RatDGDD` CDC rescale (hardest; do last).
* `DaysToGermination`/`Senescence`/`Harvest` reads in `run.f90`.

Only once **all** reads are gone can the `AdjustCalendarDays`/`SumCalendarDays`
conversion be deleted. Flowering is just the first stage; the same anchor pattern applies
to the other `DaysToXXX` stages.

Open caveat: the `DayNrFlowering` anchor formula assumes sown/transplanted
(`VirtualTimeCC` = raw days). A regrowth GDD grain/tuber crop (exotic) would need a
`DaysToCCini == 0` guard.

## Test suite

`testcase/LIST/ListProjects.txt` runs 7 projects x 3 runs each (21 May -> 31 Oct of
2014/2015/2016; DayNrs 41414/41577, 41779/41942, 42145/42308).

| Project | Crop | MAN | Tnx | Purpose |
| --- | --- | --- | --- | --- |
| `Ottawa.PRM` | `AlfOttawaGDD.CRO` | `Ottawa.MAN` | `Ottawa.Tnx` | perennial alfalfa/Forage, regrowth; years 1/2/3 + KeepSWC; `GDDaysToFlowering = 0` (zero-target) |
| `OttawaMaize.PRM` | `MaizeGDDwpy.CRO` | `Ottawa2.MAN` | `Ottawa.Tnx` | sown Grain, `DeterminancyLinked = 1` |
| `OttawaTuber.PRM` | `tuberwpy.CRO` | `Ottawa2.MAN` | `Ottawa.Tnx` | transplanted Tuber, GDDFlor 550, `DeterminancyLinked = 0` - only crop hitting the determinancy-unlinked else-branches (~710 fSwitch, ~921 tmax1) |
| `OttawaVeg.PRM` | `veg.CRO` | `Ottawa2.MAN` | `Ottawa.Tnx` | transplanted Vegetative, GDDFlor 0 - only non-forage crop covering the zero-target gate |
| `OttawaMaizeConst.PRM` | `MaizeGDDwpy.CRO` | `Ottawa2.MAN` | `OttawaConst.Tnx` | constant-T oracle |
| `OttawaTuberConst.PRM` | `tuberwpy.CRO` | `Ottawa2.MAN` | `OttawaConst.Tnx` | constant-T oracle |
| `OttawaVegConst.PRM` | `veg.CRO` | `Ottawa2.MAN` | `OttawaConst.Tnx` | constant-T oracle |

* The 3 annual projects use `YearSeason = 1` + `SW0 = (None)` per run (independent
  seasons); only the perennial alfalfa uses years 1/2/3 + `KeepSWC`.
* **MAN split:** only the perennial uses `Ottawa.MAN` (multiple cuttings ON + explicit cut
  list). The annuals use `Ottawa2.MAN` (cuttings OFF - cuts on annuals made no sense and
  showed up in their `harvests.OUT`). `Ottawa2.MAN` also drops fertility stress 50 -> 21
  (still > 0, so the maize soil-fertility/determinancy block stays reachable) and weed
  shape 100.00 -> -0.01.
* The WP-decline block needs `WPy < 100`, so grain/tuber use `*wpy` copies:
  `MaizeGDDwpy.CRO` and `tuberwpy.CRO` (line 62, WPy 100 -> 90). `tuber.CRO` and
  `MaizeGDD.CRO` are kept but unreferenced.
* `tuber.CRO`/`veg.CRO` are v7.2 files - the loader handles them via the
  `VersionNr*10 <= 72` skip of the PrematureEnd line.
* `OttawaConst.Tnx` is a clone of `Ottawa.Tnx` (same 8-line header, same 1096 days
  2014-2016) with every row `12.0  28.0`. Tmin 12 / Tmax 28 chosen so every cycle finishes
  inside the 163-day season and no cold/heat pollination stress fires. Method-3 GDD/day:
  maize 12 (cycle 1210 done day 101), tuber 17 (day 76), veg 10 (day 140), alfalfa 15
  (day 128).

### Workflow

```sh
module load foss          # build tools are behind lmod
cd src && make bin
cd ../testcase && ./aquacrop && ./compare_outputs.sh   # diffs OUTP vs OUTP_REF, skipping line 1
```

To regenerate a clean reference: stash only the source (`git stash push -- src/simul.f90`
etc.; untracked PRM/CRO survive), build, run, then copy `OUTP/*` to `OUTP_REF/`.

Note that `testcase/SIMUL/{EToData,RainData,TempData,TCrop}.SIM` are **written by the
program** on every run despite being tracked; their churn is expected and should not be
committed.
