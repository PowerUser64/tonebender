#!/bin/bash
# Verify that the c test and the zig test are equivalent

echodo() {
   echo "$@"
   "$@"
}

script_dir="$(dirname "$(realpath "$0")")"
cd "$script_dir"

cd ./c-test/; ./buildrun.sh || exit
cd -
cd ./zig-test/; anyzig 0.14.1 build || exit
cd -

cout="$(mktemp)"
./c-test/a.out &> "$cout"

zigout="$(mktemp)"
./zig-test/zig-out/bin/faust_test &> "$zigout"

echodo delta "$cout" "$zigout"

cat "$cout" <(echo "------------") "$zigout"

rm "$cout" "$zigout"
