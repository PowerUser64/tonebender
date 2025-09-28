build: generate-faust
   anyzig 0.14.1 build

debug $TESTS='.': build
   ./bin/dbg-clapval.sh "$TESTS"

validate: build
   ./bin/validate.sh

bwlog:
   ./bin/bitwig-log-follow.sh

generate-faust $DSP="tonebender":
   ./faust/generate-c-code.sh "$DSP"
