# AquaCrop test suite

A set of 832 small AquaCrop simulations with their expected output. Run them
after you change the code, and they tell you what your change did to the
results.

The suite lives on the branch `test/testsuite`, in the folder `tests/`. It
does not change the model: nothing in `src/` is touched and the src should be 
identical to the version in the main.

---

## In short

```bash
git fetch origin                        # origin = KUL-RSDA/AquaCrop (see section 2)
git merge origin/test/testsuite         # 1. bring the suite into your branch
(cd src && make)                        # 2. build AquaCrop (your code)
python3 tests/runner/run_tests.py -j 8  # 3. run every case in parallel (here 8 processes)
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
whole suite should take about a minute and takes about 185M of storage.

---

## 2. Bring the suite into your branch

You are working on your own branch (a fix, a new feature, a refactor). The
suite is the branch `test/testsuite` of the group repository,
[KUL-RSDA/AquaCrop](https://github.com/KUL-RSDA/AquaCrop). Merge it into your
branch:

```bash
git fetch origin
git merge origin/test/testsuite
```

This assumes `origin` is KUL-RSDA/AquaCrop, as in a normal clone. Check with
`git remote -v`. If `origin` is your own fork, add the group repository once
and use its name instead of `origin` in the commands on this page:

```bash
git remote add kul git@github.com:KUL-RSDA/AquaCrop.git
git fetch kul
git merge kul/test/testsuite
```

This only adds the `tests/` folder and a few lines in `.gitignore`, so your
runs are not stored in git. It does not touch `src/`.

**If git refuses** with *"untracked working tree files would be overwritten
by merge"*, you have an old copy of `tests/` lying around from an earlier
checkout. Those files are not part of your branch. Move them out of the way
(or delete them if you do not need them) and merge again:

```bash
mv tests tests_old
git merge origin/test/testsuite
```

To pick up later improvements to the suite, merge again the same way.

---

## 3. Run it

From the top of the repository:

```bash
python3 tests/runner/run_tests.py -j 8           # all cases, 8 at a time
python3 tests/runner/run_tests.py -j 8 G U       # only groups G and U
python3 tests/runner/run_tests.py Q15 F14        # only these cases
python3 tests/runner/run_tests.py -j 8 -q        # only print what goes wrong
python3 tests/runner/run_tests.py -j 8 --keep    # keep the output of passing cases too
```

Each case runs in its own folder under `tests/work/`, so running many at once
is safe. The folder of a failing case is always kept, so you can look at its
output. Use `--keep` if you want to plot the results afterwards (section 5):
passing cases are useful to compare against.

At the end you get a summary like

```
pass 829   within-tol 0   known-defect 0   FAIL 3   ERROR 0
```

and a report is written to `tests/work/results.json`.

### What the results mean

| mark | result | meaning |
|---|---|---|
| `=` | **pass** | the output is the same as the stored reference |
| `~` | **within tolerance** | numbers differ, but by less than the case's tolerance (normally 0.1 %) |
| `x` | **fail** | the output differs, or a check below was broken |
| `!` | **error** | AquaCrop stopped with an error |

The first line of every output file (the date and time of the run) is always
ignored.

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

4. **If the changes are what you intended**, the testsuite ref will need to be
   updated to keep it in line with the main. 

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
reference unless you give `--force`. It records the build it used in
`tests/REFERENCE.txt`. Then:

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

The easiest way is to copy a case that is close to what you want:

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
- `rtol`: the relative tolerance (0.001 is 0.1 %).

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

`check_builds.sh` rebuilds `src/aquacrop` with other compiler options and
puts your original build back when it is done.
