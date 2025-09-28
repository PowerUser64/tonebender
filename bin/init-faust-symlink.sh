#!/bin/bash

set -euo pipefail

dsp="${1:-}"

default=sine

script_dir="$(dirname "$(realpath "$0")")"
repo_dir="$(git -C "$script_dir" rev-parse --show-toplevel)"
cd "$repo_dir"

repo_dir_rel="$(realpath --relative-to=. "$repo_dir")"

linktarget=mydsp.dsp

echodo() {
   echo + "$@"
   "$@"
}

link() {
   echodo ln -rsf "$repo_dir_rel"/faust/"$dsp" "$repo_dir_rel"/faust/"$linktarget"
}

if [ -n "$dsp" ]; then
   dsp="$dsp.dsp"
   link
elif [ -f "$linktarget" ]; then
   # use default -- no input, and file doesn't already exist
   dsp="$default.dsp"
   link
else
   # skip if no input and the file is already created
   echo "skipping"
fi

