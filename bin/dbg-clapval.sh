#!/bin/bash

init=/usr/share/pwndbg/gdbinit.py # pwndbg
# init=/usr/share/gef/gef.py # gef

if [ $# = 0 ]; then
   set -- .
fi

# Loop over all arguments, treating them as test filters for clap-validator
for t; do
   gdb -q -x "$init" --args clap-validator validate --in-process -f "$t" -i com.interpunct.clap-demo ./zig-out/lib/clap-demo.clap
done
