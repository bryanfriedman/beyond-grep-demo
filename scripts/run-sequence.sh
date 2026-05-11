#!/usr/bin/env bash
#
# Press-Enter-paced runner for a demo query sequence.
#
# Usage: ./run-sequence.sh <sequence-file>
#
# Sequence-file format:
#   - Lines starting with `#` (single hash) are narration cues — rendered as
#     dim `# comments` above the prompt before each command.
#   - Lines starting with `##` (two or more hashes) are PRIVATE notes —
#     skipped entirely, never rendered. Use these for presenter notes that
#     should not appear on the projector.
#   - `## CLEAR` is a directive (still a private note, doesn't render): before
#     the next block runs, pause for Enter and then clear the screen. Useful
#     between demo sections — keeps the previous section's output visible until
#     the presenter is ready to advance.
#   - Other lines are commands. Each block (cue + cmd) is separated by a blank line.
#   - Commands are evaluated in the sequencer's shell, so `cd`, pipes, redirects,
#     and shell-quoted args all work. The prompt's cwd updates after each `cd`.
#   - Use a literal `cd <dir>` block at the top to set the working directory.
#
# Per block, the sequencer:
#   1. Prints the cue lines as `# comments` at the prompt
#   2. Drops you onto an editable prompt with the command pre-filled
#   3. Reads the line: Enter runs whatever's in the buffer
#        (default: the pre-filled command; edit freely before pressing Enter)
#        Empty line (Ctrl-U + Enter) skips the block
#        Ctrl-C quits the sequence
#   4. Runs the result with `eval`. Output prints below, like real shell output.
#   5. Loops; the next prompt appears beneath the output.

set -u

# Bash 4+ is required for `read -e -i` (pre-filled editable input).
if [ -z "${BASH_VERSION:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  echo "This script needs bash 4+ for inline command editing." >&2
  echo "Install via: brew install bash" >&2
  echo "(Your default /bin/bash is 3.2; Homebrew puts bash 5 on PATH.)" >&2
  exit 1
fi

SEQ="${1:-}"
if [ -z "$SEQ" ] || [ ! -f "$SEQ" ]; then
  echo "Usage: $0 <sequence-file>" >&2
  exit 1
fi

DIM=$'\033[2m'
BOLD=$'\033[1m'
GREEN=$'\033[32m'
BLUE=$'\033[34m'
RESET=$'\033[0m'

# Clean exit on Ctrl-C.
trap 'printf "\n%s# stopped%s\n" "$DIM" "$RESET"; exit 0' INT

# Parse the sequence file into parallel arrays: cues + cmds + clears (one entry per block).
CUES=()
CMDS=()
CLEARS=()
cue=""
cmd=""
next_clears=0
flush_block() {
  if [ -n "$cmd" ]; then
    CUES+=("$cue")
    CMDS+=("$cmd")
    CLEARS+=("$next_clears")
    next_clears=0
  fi
  cue=""; cmd=""
}
while IFS= read -r line || [ -n "$line" ]; do
  if [ -z "$line" ]; then
    flush_block
    continue
  fi
  if [[ "$line" == "##"* ]]; then
    # Private presenter note — never rendered, except for directives.
    if [[ "$line" == "## CLEAR"* ]]; then
      next_clears=1
    fi
    continue
  elif [[ "$line" == "#"* ]]; then
    stripped="${line#\#}"
    stripped="${stripped# }"
    if [ -z "$cue" ]; then cue="$stripped"; else cue+=$'\n'"$stripped"; fi
  else
    if [ -z "$cmd" ]; then cmd="$line"; else cmd+=$'\n'"$line"; fi
  fi
done < "$SEQ"
flush_block

TOTAL=${#CMDS[@]}
if [ "$TOTAL" -eq 0 ]; then
  echo "No command blocks found in $SEQ" >&2
  exit 1
fi

# Build a fake shell prompt that tracks the current cwd.
# Format: tilde-shortened path in blue + bold "$" + space.
build_prompt() {
  local cwd="$PWD"
  if [[ "$cwd" == "$HOME" ]]; then
    cwd="~"
  elif [[ "$cwd" == "$HOME"/* ]]; then
    cwd="~${cwd#$HOME}"
  fi
  printf "${BOLD}${BLUE}%s${RESET} ${BOLD}\$${RESET} " "$cwd"
}

clear

for ((i=0; i<TOTAL; i++)); do
  if [ "${CLEARS[$i]:-0}" = "1" ]; then
    printf "%s# press Enter for next section…%s" "$DIM" "$RESET"
    read -r _
    clear
  fi
  cue="${CUES[$i]}"
  cmd="${CMDS[$i]}"

  # Cue lines render as plain dim `# comments` (no fake prompt) — they read
  # as presenter commentary above the actual prompt.
  if [ -n "$cue" ]; then
    while IFS= read -r line; do
      printf "${DIM}# %s${RESET}\n" "$line"
    done <<< "$cue"
  fi

  # Editable prompt with the command pre-filled. Enter runs as-is or edited.
  # Empty input (Ctrl-U + Enter, or backspace-all) skips the block.
  read -e -r -i "$cmd" -p "$(build_prompt)" line

  if [ -z "$line" ]; then
    printf "%s# skipped%s\n\n" "$DIM" "$RESET"
    continue
  fi

  # Run the command. eval keeps state (cd, exports, etc.) across blocks.
  eval "$line" || true

  # Blank line between command output and the next prompt.
  printf "\n"
done

# Final empty prompt, like exiting back to the shell.
build_prompt
printf "\n"
