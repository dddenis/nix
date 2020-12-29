#!/usr/bin/env sh

. "$(dirname "$0")"/.nnn-plugin-helper

symlink2file() {
  orig="$PWD/$(basename "$1").orig"
  if [ -s "$orig" ]; then
    echo "ERROR: $orig exists"
    exit 2
  fi

  mv "$1" "$orig"
  cp "$orig" "$1"
  chmod 755 "$1"
}

echo nnn "$nnn"

if [ -s "$selection" ]; then
  selected=$(tr '\0' '\n' < "$selection")

  for file in $selected; do
    symlink2file "$file"
  done
elif [ -n "$1" ]; then
  symlink2file "$1"
fi
