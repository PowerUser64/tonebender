#!/bin/bash

script_dir="$(dirname "$(realpath "$0")")"
repo_dir="$(git -C "$script_dir" rev-parse --show-toplevel)"

cd "$repo_dir"

clap-validator validate "$@" -i com.bnw.tonebender ./zig-out/lib/tonebender.clap
