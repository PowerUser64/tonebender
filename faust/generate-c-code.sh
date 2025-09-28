#!/bin/bash

set -euo pipefail

# NOTE: this always runs from the script's location
script_dir="$(dirname "$(realpath "$0")")"
cd "$script_dir"

dsp=()
set -- "${@:-mydsp}"
for f; do
   dsp+=("${f%.dsp}.dsp")
done

# generate code to tmp file
faust "${dsp[@]}" -o ./mydsp.gen.c.tmp -lang c

# combine to actual file, prepending faust header
cat <(echo '#include "faust.h"') ./mydsp.gen.c.tmp > ./mydsp.gen.c

# cleanup
rm ./mydsp.gen.c.tmp
