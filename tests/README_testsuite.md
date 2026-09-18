# AquaCrop test suite

A set of 851 small AquaCrop simulations with their expected output. Run them
after you change the code, and they tell you what your change did to the
results.

The suite is its own branch, `test/testsuite`, and everything it needs is in
the folder `tests/`. It never changes the model: nothing in `src/` is touched,
so the suite can be merged into any branch, or kept separate and pointed at
any build (section 2).

**Which code the stored output belongs to.** The expected output is not
absolute truth: it is what one build of AquaCrop produced, and
`tests/REFERENCE.txt` says which one. At the moment that is the branch
`fix/7.4_fixes_testsuite`, not the `src/` of this branch, which is the 7.3
release. So running the suite against another branch shows the cases that the
fixes changed; section 4 explains how to read such differences.

---

## In short

You need the suite (`tests/`) and a build of AquaCrop (`src/aquacrop`). There
are two ways to have both, and section 2 describes them:

```bash
# A. merge the suite into the branch you are working on
git fetch origin                        # origin = KUL-RSDA/AquaCrop (see section 2)
git merge origin/test/testsuite         # 1. bring the suite into your branch
(cd src && make)                        # 2. build AquaCrop (your code)
python3 tests/runner/run_tests.py -j 8  # 3. run every case, 8 at a time

# B. keep the suite separate and point it at your build
python3 tests/runner/run_tests.py -j 8 --exe ../AquaCrop/src/aquacrop
```

The brackets around `cd src && make` bring you back to the top folder
afterwards, where step 3 has to run.

If every case passes, your change did not alter any result. If some fail, the
rest of this page explains how to find out whether that was intended.

---

## 1. What you need

- **Python 3** with **PyYAML** (`pip install pyyaml`). This is all the runner
  needs and is available on the default HPC python (or base env).
- For the results notebook: **pandas**, **numpy** and **matplotlib**, and
  optionally **ipywidgets** for the drop-down menus. The simplest way to get
  them is a Python virtual environment, made once. It needs **Python 3.9 or
  newer**: check with `python3 --version`. If a conda environment is active
  (your prompt starts with `(base)`), `python3` is conda's Python, which may be
  older; run `conda deactivate` first, or start from `/usr/bin/python3`.

  On the VSC clusters, put it in your data folder. `$VSC_DATA` is already set
  to it (`/data/leuven/xxx/vscxxxxx`), so the commands work for everyone as
  they are:

  ```bash
  python3 -m venv $VSC_DATA/venvs/aquacrop-tests
  source $VSC_DATA/venvs/aquacrop-tests/bin/activate
  pip install -r tests/requirements.txt
  python -m ipykernel install --user --name aquacrop-tests --display-name "AquaCrop tests"
  ```

  The last line registers the environment as a Jupyter kernel called
  *AquaCrop tests*. On another machine, use any folder instead of
  `$VSC_DATA/venvs`.

  **Using it in VS Code.** Open `tests/compare_suite.ipynb`, click
  *Select Kernel* at the top right, then *Jupyter Kernel...*, and pick
  *AquaCrop tests*. If it is not in the list yet, reload the window once
  (Ctrl+Shift+P, *Developer: Reload Window*). Alternatively, choose
  *Python Environments...*, then *Enter interpreter path...*, and type the
  full path, for example
  `/data/leuven/xxx/vscxxxxx/venvs/aquacrop-tests/bin/python`
  (VS Code does not expand `$VSC_DATA` there; `echo $VSC_DATA` shows yours).
- A build of AquaCrop at `src/aquacrop` (`make`).

The runs are small, but there are many. Use several cores: with 36 cores the
whole suite takes about a minute. The stored output is about 70M; a run with
`--keep` adds a few hundred M under `tests/work/`, which git ignores.

---

## 2. Get the suite and your build together

The runner needs two things: the folder `tests/`, which it is run from, and a
built `aquacrop`. Pick whichever way suits your work.

The suite is the branch `test/testsuite` of the group repository,
[KUL-RSDA/AquaCrop](https://github.com/KUL-RSDA/AquaCrop). The commands below
assume `origin` is that repository, as in a normal clone. Check with
`git remote -v`. If `origin` is your own fork, add the group repository once
and use its name instead of `origin` everywhere on this page:

```bash
git remote add kul git@github.com:KUL-RSDA/AquaCrop.git
git fetch kul
```

### A. Merge the suite into your branch

Simplest, and the suite then travels with your branch:

```bash
git fetch origin
git merge origin/test/testsuite
(cd src && make)
python3 tests/runner/run_tests.py -j 8
```

The merge only adds the `tests/` folder and a few lines in `.gitignore`, so
your runs are not stored in git. It does not touch `src/`. To pick up later
improvements to the suite, merge again the same way.

**If git refuses** with *"untracked working tree files would be overwritten
by merge"*, you have an old copy of `tests/` lying around from an earlier
checkout. Those files are not part of your branch. Move them out of the way
(or delete them if you do not need them) and merge again:

```bash
mv tests tests_old
git merge origin/test/testsuite
```

### B. Keep the suite separate, and pass `--exe`

Use this when you would rather not have `tests/` in your branch at all, or
when you want to run the same suite against several builds. Check the suite
out next to your work — a git worktree does that from the same clone, without
a second download:

```bash
git fetch origin
git worktree add ../AquaCrop_suite origin/test/testsuite   # once
```

Then build your code as usual, and run the suite from its own folder, telling
it which binary to use:

```bash
(cd src && make)                        # in your own working folder
cd ../AquaCrop_suite
python3 tests/runner/run_tests.py -j 8 --exe ../AquaCrop/src/aquacrop
```

`--exe` takes a relative or an absolute path and is accepted by `run_tests.py`
and `freeze.py` alike. Without it, both use `src/aquacrop` of the folder they
are run from, which on this branch is the release build.

Comparing two builds is then just two runs:

```bash
python3 tests/runner/run_tests.py -j 8 --exe ../AquaCrop/src/aquacrop
python3 tests/runner/run_tests.py -j 8 --exe ../AquaCrop_other/src/aquacrop
```

To update the suite later: `git -C ../AquaCrop_suite pull`. To get rid of it:
`git worktree remove ../AquaCrop_suite`.

---

## 3. Run it

From the top of the repository:

```bash
python3 tests/runner/run_tests.py -j 8           # all cases, 8 at a time
python3 tests/runner/run_tests.py -j 8 G U       # only groups G and U
python3 tests/runner/run_tests.py Q15 F14        # only these cases
python3 tests/runner/run_tests.py -j 8 -q        # only print what goes wrong
python3 tests/runner/run_tests.py -j 8 --keep    # keep the output of passing cases too
python3 tests/runner/run_tests.py -j 8 \
        --exe ../AquaCrop/src/aquacrop           # use a build from elsewhere
python3 tests/runner/run_tests.py -j 8 --rtol 0  # every difference is a failure
```

Each case runs in its own folder under `tests/work/`, so running many at once
is safe. The folder of a failing case is always kept, so you can look at its
output. Use `--keep` if you want to plot the results afterwards (section 5):
passing cases are useful to compare against.

At the end you get a summary like

```
pass 848   within-tol 0   known-defect 0   FAIL 3   ERROR 0
```

and a report is written to `tests/work/results.json`. The exit status is 0
only if every case selected passed, so the suite can be used in a script.

### What the results mean

| mark | result | meaning |
|---|---|---|
| `=` | **pass** | the output is the same as the stored reference |
| `~` | **within tolerance** | numbers differ, but by less than the case's tolerance (normally 0.1 %) |
| `x` | **fail** | the output differs, or a check below was broken |
| `!` | **error** | AquaCrop stopped with an error |

The first line of every output file (the date and time of the run) is always
ignored.

### The tolerance

Text (project names, dates, `Tot(1)`) has to match exactly. Numbers may differ
by the case's `rtol`, 0.1 % by default, before the case fails. Such a
difference is never hidden: the case is marked `~`, counted as *within-tol* in
the summary, and the message says how many values differed and by how much.

The same binary on the same machine reproduces its output exactly, so on your
own runs `~` means your change did move numbers, if only slightly. The
tolerance is there for comparisons where equality to the last digit is not a
fair test: another compiler or machine, or another build of the same code, for
example the unoptimised build of section 10, which reorders floating-point
arithmetic. A real change of behaviour moves numbers by whole percent and
fails whatever the tolerance.

To change it for a whole run, use `--rtol` (`--rtol 0` fails on any
difference); to change it for one case, edit `rtol:` in its `case.yml`.

**Nine cases are meant to fail to run.** They hand AquaCrop something wrong —
a project list with an empty line, a soil file with too many horizons, a
simulation period the climate record does not cover — and AquaCrop has to
refuse it with a message. Their `case.yml` says which message
(`expect_error:`, see section 9), and they pass when the run stops and prints
it. They have no stored output. If one of them starts running "successfully",
or stops with a different message, it fails.

Besides comparing with the reference, every case is also checked against
rules that must always hold, whatever the code does:

- the water balance closes: what comes in equals what goes out plus the change
  in storage, every day;
- the salt balance closes in the same way;
- no compartment holds more water than its porosity, or less than none;
- percentages stay between 0 and 100, and no output is `NaN` or `Inf`;
- for some cases, the compartment sizes, growing degree days and ten-day
  climate values are also recomputed in Python and compared.

So a case can fail even if the reference was never updated: if your change
breaks the water balance, you will know.

---

## 4. Some cases failed. Now what?

A failing case is not automatically a problem. It means **something changed**,
and you have to decide whether that change is the one you wanted.

1. **Look at what moved.** Open the notebook (section 5), or compare the files
   directly:

   ```bash
   diff tests/cases/Q15_*/OUTP_REF/Q15PRMseason.OUT \
        tests/work/Q15_*/OUTP/Q15PRMseason.OUT
   ```

2. **Ask whether it makes sense.** A fix to capillary rise should move the
   cases with a water table (groups G and U). If cases move that have nothing 
   to do with your change, look closer.

3. **If an error or a broken rule shows up**, your change has introduced a bug.
   Fix the code, not the test.

4. **If the changes are what you intended**, the stored output has to be
   updated so the suite stays in step with the code (see below). Do this on
   the suite branch, and say in the commit message which change moved which
   cases.

**Never update the references just to make the failures go away.** The stored
output is the only record of how the model behaved before. Once it is
overwritten, the old behaviour cannot be compared any more (or needs to be
rerun with old executable).

### Updating the references

Only after you have checked that the changes are intended:

```bash
python3 tests/runner/freeze.py Q15 G05 -j 8        # only these cases
python3 tests/runner/freeze.py --all --force -j 36 # every case
```

`freeze.py` asks before it writes and refuses to overwrite an existing
reference unless you give `--force`. It takes `--exe` like `run_tests.py`, and
records the build it used in `tests/REFERENCE.txt`. Cases that are meant to
fail to run are skipped: there is nothing to store for them. Then:

```bash
python3 tests/runner/run_tests.py -j 8     # everything should pass now
git add tests/cases tests/REFERENCE.txt
git commit -m "Update test references after <your change>"
```

Write in the commit message which change moved which cases, so the new values
can always be traced back.

If your change deliberately changes **how compartments are sized**, the
expected sizes stored in some `case.yml` files (the `predict:` blocks) and
`tests/runner/soil_oracle.py` must follow too. The geometry checks will tell
you which cases.

---

## 5. Look at the results in a notebook

`tests/compare_suite.ipynb` shows the outcome of a run:

1. **Overview**: which groups have cases that do not pass, and how they fail
   (the run stopped, a balance broke, numbers moved, or only text changed).
2. **Scatter plots**: reference against new value for a set of cases you pick,
   one panel per output variable. Points on the diagonal did not move.
3. **One case over time**: reference and new, the difference underneath, and
   the first day they differ. `plot_case(case, columns="crop")` shows canopy,
   biomass and yield; `columns="water"` shows the soil water, with the root
   zone water at saturation, field capacity and wilting point drawn along it.

Run the suite with `--keep` first, then open the notebook and run it from the
top. To look at a run that sits somewhere else, set the environment variable
`AQUACROP_WORK` to that `work` folder before starting Jupyter.

The notebook is written by `tests/runner/build_compare_notebook.py`. To change
it, edit that script and run it again.

---

## 6. Check a case in the Windows GUI

To compare a case with the AquaCrop GUI, package it for Windows:

```bash
python3 tests/runner/export_windows.py Q15
  # bundles the test case Q15
python3 tests/runner/export_windows.py F14 F23 S10 --bundle geometry
  # bundle several cases (here called geometry because that was the main check)
python3 tests/runner/export_windows.py Q15 --data 'D:\AquaCrop\DATA'
  # give the path of your GUI DATA folder
```

This writes `tests/export/Q15/` and `tests/export/Q15.zip` (with `--bundle`,
also one zip holding all the cases). Inside:

- every input file, **renamed after the case** (`Q15.SOL`, `Q15.CRO`, ...), so
  nothing overwrites a file already in the GUI's folder;
- the project `Q15.PRM`, with every path pointing at the GUI's DATA folder
  (`C:\Workdir\Programs\GUI_AC7.3\DATA` unless you give `--data`);
- `Q15.PPn`, the program parameters the case was run with;
- a `README.txt` saying where each file goes, and for soil cases the
  compartment sizes to expect.

All files have Windows line endings. On the Windows side:

1. Copy the input files into the GUI's DATA folder.
2. In the GUI, open the project folder (e.g. `Q15.PRM`), the corresponding data
   should be loaded.
3. Run the project and compare. Either visually within the GUI or export the output.

---

## 7. Overview page of all cases

`tests/matrix.html` is a web page listing every case, grouped by what it
tests, with its status (tested, blocked by a defect, not written yet, ...),
followed by the defects and observations the suite has found. Open it in any
browser.

It is built from `tests/TESTPLAN.md` and the cases on disk. After changing
either, rebuild it:

```bash
python3 tests/render_matrix.py
```

GitHub shows `.html` files as source code, not as a page. To get a link you can
open or share, ask Claude Code to publish `tests/matrix.html` as an artifact.
It gives you a `claude.ai` link, private until you share it from the page's
share menu. After rebuilding the page, ask Claude to publish it again to the
same link, so the link stays the same.

---

## 8. What is in `tests/`

| path | what it is |
|---|---|
| `cases/<ID>_<name>/` | one folder per case: `case.yml` (the inputs) and `OUTP_REF/` (the expected output) |
| `assets/` | the input files the cases use (climate, crops, soils, ...) and the scripts that generated them |
| `runner/` | the tools: `run_tests.py`, `freeze.py`, the checks and the Python re-computations (`*_oracle.py`) |
| `TESTPLAN.md` | the full plan: every case, what it covers, and the problems found so far |
| `matrix.html` | the same plan as a page to open in a browser (made by `render_matrix.py`) |
| `REFERENCE.txt` | which build produced the stored references |
| `compare_suite.ipynb` | the results notebook |
| `requirements.txt` | the Python packages the notebook needs |
| `work/`, `export/` | output of your runs and exports; not stored in git |

### Groups

The letters at the start of a case name say what the case is about.

| | | | |
|---|---|---|---|
| **A** | project and run structure | **N** | program parameters |
| **B** | crop type, planting, phenology | **O** | output and reporting |
| **C** | calendar days vs growing degree days | **P** | stress and crop failure |
| **D** | climate input | **Q** | drainage |
| **E** | rainfall and runoff settings | **R** | runoff and infiltration |
| **F** | soil profile, compartments, rooting depth | **S** | soil evaporation |
| **G** | groundwater table | **T** | transpiration and root water uptake |
| **H** | initial conditions | **U** | capillary rise |
| **I** | irrigation | **V** | salt transport |
| **J** | field management | **W** | canopy development |
| **K** | off-season | **X** | biomass, harvest index, yield |
| **L** | salinity | **Y** | stress |
| **M** | growing-season calendar | **Z** | water and salt balance, overall checks |
| **SW** | generated sweeps (one setting varied over its range) | | |

---

## 9. Adding a case

**Most cases are written by a script.** The generators in `tests/assets/`
(`gen_cases_*.py`) hold one line per case and write its `case.yml`. If your
case belongs to a group one of them produces, add your line there and run the
script, otherwise the next person who runs it will not have your case. Check
with `git status` that it only wrote what you expected.

For a one-off case, the easiest way is to copy a case that is close to what
you want:

```bash
cp -r tests/cases/Q15_drainage_against_an_adjusted_field_capacity \
      tests/cases/Q30_my_new_case
rm -r tests/cases/Q30_my_new_case/OUTP_REF
```

Edit `case.yml` in the new folder:

- `id`: the folder name;
- `stage`: the input files it needs, by name, from `tests/assets/`;
- `project`: dates and which file is used for climate, crop, soil, water
  table, and so on;
- `patch`: change single lines of an input file, as `line number: new text`;
- `daily`: which daily output blocks to write (1 to 8);
- `rtol`: the relative tolerance (0.001 is 0.1 %);
- `expect_error`: for a case with wrong input, where AquaCrop must stop. The
  case passes when AquaCrop stops (exit status not 0) and its terminal output
  contains this text. Such a case has no `OUTP_REF`, and `freeze.py` skips it.

Then store its output and check it:

```bash
python3 tests/runner/freeze.py Q30
python3 tests/runner/run_tests.py Q30
```

New input files go in the matching folder under `tests/assets/`.

**The suite never keeps a case that is known to fail.** If a new case shows a
bug in AquaCrop, write the problem down in `TESTPLAN.md` (under *Defects found
by the suite*) and remove the case. It is added back once the bug is fixed. That
way a failing run always means something new.

---

## 10. Extra checks

| command | what it checks |
|---|---|
| `tests/runner/check_builds.sh fpe` | runs the suite on a build that stops on invalid arithmetic (division by zero, `NaN`) |
| `tests/runner/check_builds.sh o0` | runs the suite on an unoptimised build, to catch results that depend on the compiler |
| `python3 tests/runner/check_equivalence.py` | a project with several runs gives the same result as those runs done separately |

`check_builds.sh` compiles the code twice with other compiler options, runs the
suite against each build, and puts your original `src/aquacrop` back when it is
done, also if it stops half way. Because it compiles, it needs the code itself,
not just a binary: `--exe` is not enough. By default it builds the `src/` next
to the cases; if the suite is a separate checkout, point it at your working
folder:

```bash
tests/runner/check_builds.sh fpe --src ../AquaCrop
```

It prints which code and which cases it is using, so you can check before it
starts. Mind that both builds use `DEBUG=1` (`-O0 -fcheck=all`), which is slow:
allow more time than for a normal run.
