#!/usr/bin/env bash
# Z18 and Z19: run the suite against differently-compiled binaries.
#
#   Z18  a build that traps non-finite arithmetic. Any case that dies under
#        -ffpe-trap is doing arithmetic the production build silently absorbs.
#   Z19  an unoptimised build compared against references frozen at -O2. A
#        result that moves is an optimisation-sensitive calculation.
#
# The production binary is saved first and restored at the end, whatever
# happens, so src/aquacrop is what it was before.
#
# Both builds are made from source, so the script needs the code, not just a
# binary. By default it builds the src/ next to the cases; --src points it at
# another working folder, which is what you want when the suite is a separate
# checkout (see section 2 of the README).
#
#   ./tests/runner/check_builds.sh                          both
#   ./tests/runner/check_builds.sh fpe                      Z18 only
#   ./tests/runner/check_builds.sh o0                       Z19 only
#   ./tests/runner/check_builds.sh fpe --src ../AquaCrop    build that folder's code
set -uo pipefail
cd "$(dirname "$0")/../.."
ROOT=$PWD
SAVE=$(mktemp -d)
WHICH=both
CODE=$ROOT
while [ $# -gt 0 ]; do
    case $1 in
        fpe|o0|both) WHICH=$1; shift ;;
        --src) CODE=$2; shift 2 ;;
        *) echo "usage: check_builds.sh [fpe|o0|both] [--src <folder with src/>]"; exit 1 ;;
    esac
done
cd "$CODE" || exit 1
CODE=$PWD                        # absolute, so the runner can be started elsewhere
cd "$ROOT"

restore() {
    echo
    echo "--- restoring the production binary ---"
    make -C "$CODE/src" fortranclean >/dev/null 2>&1
    if [ -f "$SAVE/aquacrop" ]; then
        cp "$SAVE/aquacrop" "$CODE/src/aquacrop" \
            && echo "    $CODE/src/aquacrop restored"
    fi
    rm -rf "$SAVE"
}
trap restore EXIT

[ -f "$CODE/src/aquacrop" ] || {
    echo "$CODE/src/aquacrop not built; run make -C $CODE/src first"; exit 1; }
cp "$CODE/src/aquacrop" "$SAVE/aquacrop"
echo "code     $CODE/src"
echo "cases    $ROOT/tests/cases"
echo "saved the production binary ($(sha256sum "$CODE/src/aquacrop" | cut -c1-16))"

build () {                       # build <label> <make args...>
    local label=$1; shift
    echo
    echo "=== building: $label ==="
    make -C "$CODE/src" fortranclean >/dev/null 2>&1
    if ! make -C "$CODE/src" "$@" bin 2>&1 | tail -3; then
        echo "    BUILD FAILED"; return 1
    fi
    cp "$CODE/src/aquacrop" "$SAVE/aquacrop.$label"
    echo "    ok ($(sha256sum "$CODE/src/aquacrop" | cut -c1-16))"
}

if [ "$WHICH" = both ] || [ "$WHICH" = fpe ]; then
    if build fpe DEBUG=1 CPPFLAGS="-ffpe-trap=invalid,zero,overflow -ffpe-summary=all"; then
        echo
        echo "=== Z18: running the suite under -ffpe-trap ==="
        echo "    a failure here is arithmetic the production build absorbs silently"
        python3 tests/runner/run_tests.py -j 36 -q --exe "$SAVE/aquacrop.fpe"
    fi
fi

if [ "$WHICH" = both ] || [ "$WHICH" = o0 ]; then
    if build o0 DEBUG=1; then
        echo
        echo "=== Z19: unoptimised build against references frozen at -O2 ==="
        echo "    within-tolerance is expected; a real difference is optimisation-sensitive"
        python3 tests/runner/run_tests.py -j 36 -q --exe "$SAVE/aquacrop.o0" --rtol 1e-3
    fi
fi
