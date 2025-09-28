default := 'build'

build: generate-faust
   anyzig 0.14.1 build

debug $TESTS='.': build
   ./bin/dbg-clapval.sh "$TESTS"

validate: build
   ./bin/validate.sh

bwlog:
   ./bin/bitwig-log-follow.sh

generate-faust: init-faust-symlink
   ./faust/generate-c-code.sh

init-faust-symlink dsp='':
   ./bin/init-faust-symlink.sh '{{dsp}}'
