#!/usr/bin/env bash
set -euo pipefail

roots=("$@")
if [ "${#roots[@]}" -eq 0 ]; then
  roots=(base common dmp huichuan model net serving_base vertical wolong zilong ads_index)
fi

existing_roots=()
for root in "${roots[@]}"; do
  if [ -d "$root" ]; then
    existing_roots+=("$root")
  else
    printf 'skip missing directory: %s\n' "$root" >&2
  fi
done

if [ "${#existing_roots[@]}" -eq 0 ]; then
  printf 'no existing directories to scan\n' >&2
  exit 0
fi

tmp_file="$(mktemp "${TMPDIR:-/tmp}/wly-ctags.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT

find -H "${existing_roots[@]}" \
  \( -name .git -o -name .master -o -name .dep_create -o -name large_data -o -name third_party \) -prune \
  -o -type f \
  \( -name '*.h' -o -name '*.hh' -o -name '*.hpp' -o -name '*.hxx' \
     -o -name '*.cc' -o -name '*.cpp' -o -name '*.cxx' -o -name '*.c' \) \
  -print > "$tmp_file"

ctags \
  --languages=C++ \
  --langmap=C++:+.h.hh.hpp.hxx.cc.cpp.cxx.c \
  --c++-kinds=+p \
  --fields=+iaS \
  --extra=+q \
  -L "$tmp_file"
