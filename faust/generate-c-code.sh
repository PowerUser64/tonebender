#!/bin/bash

# generate code to tmp file
faust ./tonebender.dsp -o ./tonebender.gen.c.tmp -lang c

# combine to actual file, prepending faust header
cat <(echo '#include "faust.h"') ./tonebender.gen.c.tmp > ./tonebender.gen.c

# cleanup
rm ./tonebender.gen.c.tmp
