#!/bin/bash

# Compare OUTP and OUTP_REF directories with a relative numeric tolerance.
# Usage: ./compare_outputs.sh [--rtol R]
#   --rtol R   allowed relative difference per numeric value (default 0.001 = 0.1%)
# A file is reported as exact, within-tolerance (relative diff <= R), or
# a real difference. Only real differences make the script fail.

OUTP_DIR="./OUTP"
OUTP_REF_DIR="./OUTP_ORIG"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMP="$SCRIPT_DIR/compare_numeric.py"

RTOL=0.001
while [ $# -gt 0 ]; do
    case "$1" in
        --rtol) RTOL="$2"; shift 2 ;;
        *) echo "unknown arg: $1"; exit 2 ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Comparing OUTP and OUTP_REF (relative tolerance: $RTOL)..."
echo "============================================"

if [ ! -d "$OUTP_DIR" ]; then
    echo -e "${RED}Error: $OUTP_DIR does not exist${NC}"; exit 1
fi
if [ ! -d "$OUTP_REF_DIR" ]; then
    echo -e "${RED}Error: $OUTP_REF_DIR does not exist${NC}"; exit 1
fi

real_diffs=0        # files with real differences
close_files=0       # files within last-digit tolerance
exact_files=0       # byte-identical (after header)
diff_files=()

for ref_file in "$OUTP_REF_DIR"/*; do
    ref_filename=$(basename "$ref_file")
    outp_file="$OUTP_DIR/$ref_filename"

    if [ ! -f "$outp_file" ]; then
        echo -e "${YELLOW}Missing in OUTP: $ref_filename${NC}"
        real_diffs=1
        diff_files+=("$ref_filename")
        continue
    fi

    out=$(python3 "$CMP" "$ref_file" "$outp_file" --rtol "$RTOL" 2>&1)
    rc=$?
    case $rc in
        0) echo -e "${GREEN}=  $ref_filename${NC}"; exact_files=$((exact_files+1)) ;;
        1) echo -e "${YELLOW}~  $ref_filename  (within relative tolerance)${NC}"
           echo "$out" | sed 's/^/    /'
           close_files=$((close_files+1)) ;;
        *) echo -e "${RED}x  $ref_filename  (REAL DIFFERENCES)${NC}"
           echo "$out" | sed 's/^/    /'
           real_diffs=$((real_diffs+1))
           diff_files+=("$ref_filename") ;;
    esac
done

# Check for extra files in OUTP
echo ""
echo "Checking for extra files in OUTP..."
for outp_file in "$OUTP_DIR"/*; do
    outp_filename=$(basename "$outp_file")
    if [ ! -f "$OUTP_REF_DIR/$outp_filename" ]; then
        echo -e "${YELLOW}Extra in OUTP: $outp_filename${NC}"
    fi
done

echo ""
echo "============================================"
echo "exact: $exact_files   within-tolerance: $close_files   real-diff: $real_diffs"
if [ "$real_diffs" -eq 0 ]; then
    if [ "$close_files" -eq 0 ]; then
        echo -e "${GREEN}All files match exactly!${NC}"
    else
        echo -e "${GREEN}All files match within relative tolerance.${NC}"
    fi
    exit 0
fi

echo -e "${RED}Real differences found.${NC}"
echo ""
if [ ${#diff_files[@]} -gt 0 ]; then
    echo "Files with real differences:"
    for i in "${!diff_files[@]}"; do
        echo "  $((i+1)). ${diff_files[$i]}"
    done
    echo ""
    # Only prompt for vimdiff on an interactive terminal
    if [ -t 0 ]; then
        read -p "Open vimdiff for any of these files? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for filename in "${diff_files[@]}"; do
                read -p "Open vimdiff for $filename? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    vimdiff "$OUTP_REF_DIR/$filename" "$OUTP_DIR/$filename"
                fi
            done
        fi
    fi
fi
exit 1
