#!/usr/bin/env zsh
# brewfile-selector.sh — Interactive multi-select TUI for Brewfile packages
# Usage: zsh brewfile-selector.sh [brewfile] [output-file]
#
# Reads a Brewfile, presents a checkbox-based selector, and writes
# selected entries to the output file. Exit 0 = confirmed, 1 = cancelled.

set -euo pipefail

# Disable inherited tracing — xtrace/verbose from parent shells corrupts TUI
setopt NO_XTRACE NO_VERBOSE 2>/dev/null

# ── Arguments ────────────────────────────────────────────────────────────────

BREWFILE="${1:-$HOME/Brewfile}"
OUTPUT_FILE="${2:-$HOME/.dotfiles/.brewfile-filtered}"

if [[ ! -f "$BREWFILE" ]]; then
  printf 'Error: Brewfile not found: %s\n' "$BREWFILE" >&2
  exit 1
fi

# ── Colors ───────────────────────────────────────────────────────────────────

C_RESET=$'\033[0m'
C_CYAN=$'\033[1;36m'
C_GREEN=$'\033[1;32m'
C_DIM=$'\033[2m'
C_BOLD=$'\033[1m'
C_REVERSE=$'\033[7m'
C_YELLOW=$'\033[1;33m'

# ── Parse Brewfile ───────────────────────────────────────────────────────────

typeset -a entry_lines       # Raw Brewfile line for each entry
typeset -a entry_types       # tap/brew/cask/vscode/mas
typeset -a entry_names       # Package name
typeset -a entry_descs       # Description comment (or empty)
typeset -a entry_sections    # Section header for this entry
typeset -a entry_subcats     # Sub-category label (or empty)
typeset -a entry_selected    # 1 = selected, 0 = not

# Display items: mix of headers and entries
typeset -a display_type      # "header" or "entry"
typeset -a display_label     # Header text or entry index (1-based into entry_*)
typeset -a display_section   # For headers: the section text

entry_count=0
display_count=0

# Read all lines into an array for lookahead parsing
typeset -a raw_lines
local line_count=0
while IFS= read -r line; do
  line_count=$((line_count + 1))
  raw_lines[$line_count]="$line"
done < "$BREWFILE"

# Parse with lookahead
local current_section=""
local current_subcat=""
local current_desc=""
local i=1

while [[ $i -le $line_count ]]; do
  local line="${raw_lines[$i]}"

  # Section separator: # ============...
  # Expect pattern: separator / title / separator
  if [[ "$line" =~ '^# ={3,}' ]]; then
    # Look ahead for title line
    if [[ $((i + 1)) -le $line_count && "${raw_lines[$((i+1))]}" =~ '^# ' && ! "${raw_lines[$((i+1))]}" =~ '^# ={3,}' ]]; then
      current_section="${raw_lines[$((i+1))]#\# }"
      current_subcat=""
      current_desc=""
      display_count=$((display_count + 1))
      display_type[$display_count]="header"
      display_label[$display_count]="$current_section"
      # Skip title and closing separator
      i=$((i + 2))
      [[ $i -le $line_count && "${raw_lines[$i]}" =~ '^# ={3,}' ]] && i=$((i + 1))
      continue
    fi
    i=$((i + 1))
    continue
  fi

  # Entry line: tap/brew/cask/vscode/mas
  if [[ "$line" =~ '^(tap|brew|cask|vscode|mas) ' ]]; then
    entry_count=$((entry_count + 1))
    entry_lines[$entry_count]="$line"
    entry_selected[$entry_count]=1

    local etype="${line%% *}"
    entry_types[$entry_count]="$etype"

    local ename=""
    if [[ "$etype" == "mas" ]]; then
      ename="${line#mas \"}"
      ename="${ename%%\"*}"
    else
      ename="${line#* \"}"
      ename="${ename%%\"*}"
    fi
    entry_names[$entry_count]="$ename"
    entry_descs[$entry_count]="${current_desc:-}"
    current_desc=""
    entry_sections[$entry_count]="$current_section"
    entry_subcats[$entry_count]="$current_subcat"

    display_count=$((display_count + 1))
    display_type[$display_count]="entry"
    display_label[$display_count]="$entry_count"
    i=$((i + 1))
    continue
  fi

  # Comment line — use lookahead to distinguish sub-category from description.
  # A sub-category comment is followed by another comment (the description of
  # the first entry in that sub-group). A description comment is followed
  # directly by an entry line.
  if [[ "$line" =~ '^# ' ]]; then
    local comment_text="${line#\# }"
    # Peek at next non-blank line
    local next_idx=$((i + 1))
    while [[ $next_idx -le $line_count && -z "${raw_lines[$next_idx]}" ]]; do
      next_idx=$((next_idx + 1))
    done

    if [[ $next_idx -le $line_count && "${raw_lines[$next_idx]}" =~ '^# ' && ! "${raw_lines[$next_idx]}" =~ '^# ={3,}' ]]; then
      # Next meaningful line is also a comment — this is a sub-category label
      current_subcat="$comment_text"
      current_desc=""
      display_count=$((display_count + 1))
      display_type[$display_count]="subheader"
      display_label[$display_count]="$current_subcat"
    else
      # Next line is an entry (or end of file) — this is a description
      current_desc="$comment_text"
    fi
    i=$((i + 1))
    continue
  fi

  # Blank line — reset description
  if [[ -z "$line" ]]; then
    current_desc=""
  fi

  i=$((i + 1))
done

if [[ $entry_count -eq 0 ]]; then
  printf 'Error: No entries found in %s\n' "$BREWFILE" >&2
  exit 1
fi

# ── Terminal Setup ───────────────────────────────────────────────────────────

cursor=1            # Current display position (1-based)
scroll_offset=0     # First visible display line (0-based)
confirmed=0
cancelled=0

_term_lines() {
  tput lines 2>/dev/null || echo 24
}

_cleanup() {
  # Restore terminal
  stty sane 2>/dev/null
  printf '\033[?25h'    # Show cursor
  printf '\033[?1049l'  # Restore main screen buffer
}

trap _cleanup EXIT INT TERM

# Switch to alternate screen buffer
printf '\033[?1049h'
# Hide cursor
printf '\033[?25l'

# Handle terminal resize
trap 'true' WINCH

# ── Rendering ────────────────────────────────────────────────────────────────

_count_selected() {
  local count=0
  for i in {1..$entry_count}; do
    [[ "${entry_selected[$i]}" == "1" ]] && count=$((count + 1))
  done
  echo $count
}

_render() {
  local term_h=$(_term_lines)
  local header_lines=3   # Title + blank + column header
  local footer_lines=3   # Blank + status + controls
  local viewport_h=$((term_h - header_lines - footer_lines))
  [[ $viewport_h -lt 5 ]] && viewport_h=5

  # Adjust scroll to keep cursor visible
  if [[ $((cursor - 1)) -lt $scroll_offset ]]; then
    scroll_offset=$((cursor - 1))
  elif [[ $((cursor - 1)) -ge $((scroll_offset + viewport_h)) ]]; then
    scroll_offset=$((cursor - viewport_h))
  fi

  # Move to top-left
  printf '\033[H'

  # Header
  printf "${C_CYAN}${C_BOLD}  Brewfile Package Selector${C_RESET}\n"
  printf "${C_DIM}  Navigate: ↑/↓/j/k  Toggle: Space  All: a  None: n  Confirm: Enter  Quit: q${C_RESET}\n"
  printf "\n"

  # Render visible lines
  local rendered=0
  for i in {1..$display_count}; do
    local idx=$((i - 1))

    # Skip lines before scroll offset
    [[ $idx -lt $scroll_offset ]] && continue

    # Stop if viewport full
    [[ $rendered -ge $viewport_h ]] && break

    local dtype="${display_type[$i]}"
    local dlabel="${display_label[$i]}"

    if [[ "$dtype" == "header" ]]; then
      # Section header
      if [[ $i -eq $cursor ]]; then
        printf "${C_REVERSE}${C_CYAN}  ── %s ──${C_RESET}\033[K\n" "$dlabel"
      else
        printf "${C_CYAN}  ── %s ──${C_RESET}\033[K\n" "$dlabel"
      fi
    elif [[ "$dtype" == "subheader" ]]; then
      # Sub-category
      if [[ $i -eq $cursor ]]; then
        printf "${C_REVERSE}${C_YELLOW}    %s${C_RESET}\033[K\n" "$dlabel"
      else
        printf "${C_YELLOW}    %s${C_RESET}\033[K\n" "$dlabel"
      fi
    else
      # Entry
      local eidx="$dlabel"
      local sel="${entry_selected[$eidx]}"
      local ename="${entry_names[$eidx]}"
      local edesc="${entry_descs[$eidx]}"
      local etype="${entry_types[$eidx]}"

      local checkbox
      if [[ "$sel" == "1" ]]; then
        checkbox="${C_GREEN}[x]${C_RESET}"
      else
        checkbox="${C_DIM}[ ]${C_RESET}"
      fi

      local type_tag="${C_DIM}(${etype})${C_RESET}"
      local desc_str=""
      [[ -n "$edesc" ]] && desc_str=" ${C_DIM}— ${edesc}${C_RESET}"

      if [[ $i -eq $cursor ]]; then
        printf "  ${C_REVERSE} %b %s %b%b ${C_RESET}\033[K\n" "$checkbox" "$ename" "$type_tag" "$desc_str"
      else
        printf "  %b %s %b%b\033[K\n" "$checkbox" "$ename" "$type_tag" "$desc_str"
      fi
    fi

    rendered=$((rendered + 1))
  done

  # Clear remaining viewport lines
  while [[ $rendered -lt $viewport_h ]]; do
    printf '\033[K\n'
    rendered=$((rendered + 1))
  done

  # Footer
  local sel_count=$(_count_selected)
  printf "\n"
  printf "  ${C_BOLD}Selected: %d/%d${C_RESET}\033[K\n" "$sel_count" "$entry_count"

  # Scroll indicator
  local max_scroll=$((display_count - viewport_h))
  [[ $max_scroll -lt 0 ]] && max_scroll=0
  if [[ $max_scroll -gt 0 ]]; then
    local pct=$((scroll_offset * 100 / max_scroll))
    printf "  ${C_DIM}[scroll: %d%%]${C_RESET}\033[K\n" "$pct"
  else
    printf "\033[K\n"
  fi
}

# ── Input Loop ───────────────────────────────────────────────────────────────

_find_entry_index() {
  # Given a display position, return the entry index (or 0 if header)
  local pos=$1
  if [[ "${display_type[$pos]}" == "entry" ]]; then
    echo "${display_label[$pos]}"
  else
    echo 0
  fi
}

_move_cursor() {
  local dir=$1  # 1 = down, -1 = up
  local new_pos=$((cursor + dir))

  # Wrap or clamp
  if [[ $new_pos -lt 1 ]]; then
    new_pos=$display_count
  elif [[ $new_pos -gt $display_count ]]; then
    new_pos=1
  fi

  cursor=$new_pos
}

# Disable canonical mode (character-at-a-time input) and echo,
# but keep output processing (OPOST) so \n → \r\n works correctly.
# stty raw disables OPOST which breaks TUI rendering.
stty -icanon -echo 2>/dev/null

_render

while true; do
  # Read a single byte
  local key
  key=$(dd bs=1 count=1 2>/dev/null)

  case "$key" in
    q|Q)
      cancelled=1
      break
      ;;
    "")
      # Enter key (carriage return)
      confirmed=1
      break
      ;;
    " ")
      # Space — toggle current entry
      local eidx=$(_find_entry_index $cursor)
      if [[ $eidx -ne 0 ]]; then
        if [[ "${entry_selected[$eidx]}" == "1" ]]; then
          entry_selected[$eidx]=0
        else
          entry_selected[$eidx]=1
        fi
      fi
      ;;
    a|A)
      # Select all
      for i in {1..$entry_count}; do
        entry_selected[$i]=1
      done
      ;;
    n|N)
      # Select none
      for i in {1..$entry_count}; do
        entry_selected[$i]=0
      done
      ;;
    j)
      _move_cursor 1
      ;;
    k)
      _move_cursor -1
      ;;
    $'\033')
      # Escape sequence — read next two bytes for arrow keys
      local seq1 seq2
      seq1=$(dd bs=1 count=1 2>/dev/null)
      seq2=$(dd bs=1 count=1 2>/dev/null)
      case "${seq1}${seq2}" in
        '[A') _move_cursor -1 ;;  # Up arrow
        '[B') _move_cursor 1 ;;   # Down arrow
        *) ;;
      esac
      ;;
    *)
      # Ignore other keys
      ;;
  esac

  _render
done

# ── Output ───────────────────────────────────────────────────────────────────

_cleanup
trap - EXIT INT TERM

if [[ $cancelled -eq 1 ]]; then
  printf 'Selection cancelled.\n'
  exit 1
fi

# Build the filtered Brewfile
# First, collect which taps are needed by selected brew entries
typeset -A needed_taps

for i in {1..$entry_count}; do
  [[ "${entry_selected[$i]}" != "1" ]] && continue

  local etype="${entry_types[$i]}"
  local ename="${entry_names[$i]}"

  if [[ "$etype" == "brew" ]]; then
    # If the name contains a slash (e.g., "steipete/tap/bird"), auto-include its tap
    if [[ "$ename" == */* ]]; then
      # Extract tap: "steipete/tap/bird" -> "steipete/tap"
      local tap_name="${ename%/*}"
      needed_taps[$tap_name]=1
    fi
  fi

  if [[ "$etype" == "cask" ]]; then
    # homebrew/cask is implicit, no action needed
    :
  fi
done

# Also include explicitly selected taps
for i in {1..$entry_count}; do
  if [[ "${entry_types[$i]}" == "tap" && "${entry_selected[$i]}" == "1" ]]; then
    needed_taps[${entry_names[$i]}]=1
  fi
done

# Always include homebrew/bundle tap if any entries are selected
local any_selected=0
for i in {1..$entry_count}; do
  [[ "${entry_selected[$i]}" == "1" ]] && { any_selected=1; break; }
done
[[ $any_selected -eq 1 ]] && needed_taps["homebrew/bundle"]=1

# Write the filtered file, preserving structure
{
  local in_section=""
  local section_has_entries=0
  local pending_section_lines=()
  local pending_subcat_lines=()
  local wrote_taps=0

  # First: write the taps section
  if [[ ${#needed_taps} -gt 0 ]]; then
    printf '# ============================================\n'
    printf '# Taps\n'
    printf '# ============================================\n'
    printf '\n'
    # Write needed taps in original order
    for i in {1..$entry_count}; do
      if [[ "${entry_types[$i]}" == "tap" ]]; then
        if [[ -n "${needed_taps[${entry_names[$i]}]+x}" ]]; then
          printf '%s\n' "${entry_lines[$i]}"
        fi
      fi
    done
    printf '\n'
    wrote_taps=1
  fi

  # Then write non-tap entries grouped by section
  local prev_section=""
  local prev_subcat=""

  for i in {1..$entry_count}; do
    [[ "${entry_types[$i]}" == "tap" ]] && continue
    [[ "${entry_selected[$i]}" != "1" ]] && continue

    local esec="${entry_sections[$i]}"
    local esub="${entry_subcats[$i]}"

    # New section
    if [[ "$esec" != "$prev_section" ]]; then
      [[ -n "$prev_section" ]] && printf '\n'
      printf '# ============================================\n'
      printf '# %s\n' "$esec"
      printf '# ============================================\n'
      printf '\n'
      prev_section="$esec"
      prev_subcat=""
    fi

    # New sub-category
    if [[ -n "$esub" && "$esub" != "$prev_subcat" ]]; then
      printf '# %s\n' "$esub"
      prev_subcat="$esub"
    fi

    # Write description if present
    [[ -n "${entry_descs[$i]}" ]] && printf '# %s\n' "${entry_descs[$i]}"

    # Write entry
    printf '%s\n' "${entry_lines[$i]}"
  done
} > "$OUTPUT_FILE"

local final_count=$(_count_selected)
printf "${C_GREEN}Wrote %d selected entries to %s${C_RESET}\n" "$final_count" "$OUTPUT_FILE"
exit 0
