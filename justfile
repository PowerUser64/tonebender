build:
   anyzig 0.14.1 build

debug things:
   just build
   ./bin/dbg.sh {{things}}

validate:
   ./bin/validate.sh

bwlog:
   ./bin/bitwig-log-follow.sh

