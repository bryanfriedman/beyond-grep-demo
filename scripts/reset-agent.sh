#!/usr/bin/env bash
#
# Reset the Demo 2 agent lanes between rehearsals.
#
# Usage: ./reset-agent.sh [media|petclinic|all]
#   default: all
#
# What it does, per lane:
#   1. `git checkout -- .` to undo any source edits the agent made
#      (resets tracked files only — leaves .mcp.json, CLAUDE.md,
#      symlinks, etc. alone since they're untracked).
#   2. `git clean` of common agent-side artifacts (target/, build/).
#   3. Wipe `.moderne/mcp/` and `.moderne/build/` so the next session
#      starts with a fresh LST build.
#   4. Pre-build the LST for the with-trigrep lane so the agent doesn't
#      have to wait at session start.
#
# Why not just `./init.sh --reset`: that also re-syncs the working set
# (Demos 1 & 2), which doesn't need touching. This is the
# lighter, faster reset for the agent demo only.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEMO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="${1:-all}"

MEDIA_PATH="streamlist/media-aggregator"
PETCLINIC_PATH="spring-projects/spring-petclinic"

reset_one() {
  local lane="$1"   # no-trigrep or with-trigrep
  local path="$2"
  local target="$DEMO_ROOT/$lane/$path"

  if [ ! -d "$target" ]; then
    echo "  $lane/$path — not provisioned, skipping"
    return
  fi

  echo "  $lane/$path"
  cd "$target"
  git checkout -q -- . 2>/dev/null || true
  rm -rf target build .moderne/mcp .moderne/build 2>/dev/null
  cd "$DEMO_ROOT"
}

prebuild_with_trigrep() {
  local path="$1"
  local target="$DEMO_ROOT/with-trigrep/$path"
  [ -d "$target" ] || return
  echo "  pre-building LST for with-trigrep/$path …"
  mod build "$target" 2>&1 | tail -3
}

case "$TARGET" in
  media)
    echo "==> Resetting media lane"
    reset_one "no-trigrep"   "$MEDIA_PATH"
    reset_one "with-trigrep" "$MEDIA_PATH"
    prebuild_with_trigrep    "$MEDIA_PATH"
    ;;
  petclinic)
    echo "==> Resetting petclinic lane"
    reset_one "no-trigrep"   "$PETCLINIC_PATH"
    reset_one "with-trigrep" "$PETCLINIC_PATH"
    prebuild_with_trigrep    "$PETCLINIC_PATH"
    ;;
  all)
    echo "==> Resetting all agent lanes"
    reset_one "no-trigrep"   "$MEDIA_PATH"
    reset_one "with-trigrep" "$MEDIA_PATH"
    reset_one "no-trigrep"   "$PETCLINIC_PATH"
    reset_one "with-trigrep" "$PETCLINIC_PATH"
    prebuild_with_trigrep    "$MEDIA_PATH"
    prebuild_with_trigrep    "$PETCLINIC_PATH"
    ;;
  *)
    echo "Usage: $0 [media|petclinic|all]" >&2
    exit 1
    ;;
esac

echo ""
echo "==> Reset complete. Ready for next rehearsal."
