#!/usr/bin/env zsh
# brewfile-filter.sh — Filter Brewfile lines by @mode inline tags
#
# Usage: brewfile-filter.sh <mode> [brewfile]
#   mode     — personal, host, or guest
#   brewfile — path to Brewfile (default: ~/Brewfile)
#
# Lines without @tags are included in all modes.
# Lines with @tags are included only if the current mode matches one of the tags.
# Blank lines and comment-only lines are preserved.
#
# Example Brewfile lines:
#   brew "git"                  # no tag → included in all modes
#   brew "lume"                 # @host @guest
#   cask "cursor"               # @personal @guest

set -euo pipefail

mode="${1:?Usage: brewfile-filter.sh <mode> [brewfile]}"
brewfile="${2:-$HOME/Brewfile}"

if [[ ! -f "$brewfile" ]]; then
  echo "Error: Brewfile not found: $brewfile" >&2
  exit 1
fi

while IFS= read -r line || [[ -n "$line" ]]; do
  # Preserve blank lines
  if [[ -z "$line" ]]; then
    echo ""
    continue
  fi

  # Preserve comment-only lines (lines that start with optional whitespace + #)
  if [[ "$line" =~ ^[[:space:]]*# ]]; then
    echo "$line"
    continue
  fi

  # Check if the line has any @mode tags
  if [[ "$line" =~ @(personal|host|guest) ]]; then
    # Line has tags — include only if current mode matches
    if [[ "$line" =~ @${mode}([[:space:]]|$) ]]; then
      echo "$line"
    fi
  else
    # No tags — include in all modes
    echo "$line"
  fi
done < "$brewfile"
