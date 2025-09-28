#!/bin/bash

dsp=("${@:-mydsp.dsp}")

# generate code to tmp file
faust "${dsp[@]}" -o ./mydsp.gen.c.tmp -lang c

# combine to actual file, prepending faust header
cat <(echo '#include "faust.h"') ./mydsp.gen.c.tmp > ./mydsp.gen.c

# cleanup
rm ./mydsp.gen.c.tmp
