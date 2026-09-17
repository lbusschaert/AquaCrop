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
#   ./tests/runner/check_builds.sh          both
#   ./tests/runner/check_builds.sh fpe      Z18 only
#   ./tests/runner/check_builds.sh o0       Z19 only
set -uo pipefail
cd "$(dirname "$0")/../.."
ROOT=$PWD
SAVE=$(mktemp -d)
WHICH=${1:-both}

restore() {
    echo
    echo "--- restoring the production binary ---"
    make -C src fortranclean >/dev/null 2>&1
    if [ -f "$SAVE/aquacrop" ]; then
        cp "$SAVE/aquacrop" src/aquacrop && echo "    src/aquacrop restored"
    fi
    rm -rf "$SAVE"
}
trap restore EXIT

[ -f src/aquacrop ] || { echo "src/aquacrop not built; run make -C src first"; exit 1; }
cp src/aquacrop "$SAVE/aquacrop"
echo "saved the production binary ($(sha256sum src/aquacrop | cut -c1-16))"

build () {                       # build <label> <make args...>
    local label=$1; shift
    echo
    echo "=== building: $label ==="
    make -C src fortranclean >/dev/null 2>&1
    if ! make -C src "$@" bin 2>&1 | tail -3; then
        echo "    BUILD FAILED"; return 1
    fi
    cp src/aquacrop "$SAVE/aquacrop.$label"
    echo "    ok ($(sha256sum src/aquacrop | cut -c1-16))"
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
