#!/usr/bin/env bash
#
# Toggle the optional `media`-lane "trap" demo variant on/off.
#
# Default (clean): both lanes' HttpClientConfig declares two plain
#   `RestTemplate` beans. The migration recipe converts them cleanly
#   and the post-recipe code compiles. Repeatable across rehearsals.
#
# Trap (opt-in): the second bean attaches a custom `ResponseErrorHandler`
#   via `setErrorHandler(...)`. The recipe converts the bean's type to
#   `RestClient` but leaves the `setErrorHandler` call (RestClient has
#   no such method), so the post-recipe code won't compile until the
#   agent fixes it. Adds a "agent fills what the recipe missed" beat to
#   the demo, at the cost of fragility (re-rehearsing requires reset).
#
# Usage:
#   ./trap-mode.sh status     # report current state of both lanes
#   ./trap-mode.sh enable     # reset lanes clean, then swap in trap variant
#   ./trap-mode.sh disable    # reset lanes back to clean (default)

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEMO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MEDIA_PATH="streamlist/media-aggregator"
HCC_REL="src/main/java/com/streamlist/media/config/HttpClientConfig.java"
TRAP_FILE="$DEMO_ROOT/media-aggregator-app/extras/HttpClientConfig.with-trap.java"

is_trap_enabled() {
  local target="$1"
  [ -f "$target" ] && grep -q "setErrorHandler" "$target"
}

cmd_status() {
  for lane in no-trigrep with-trigrep; do
    local target="$DEMO_ROOT/$lane/$MEDIA_PATH/$HCC_REL"
    if [ ! -f "$target" ]; then
      printf "  %-13s  not provisioned\n" "$lane"
    elif is_trap_enabled "$target"; then
      printf "  %-13s  TRAP enabled\n" "$lane"
    else
      printf "  %-13s  clean (no trap)\n" "$lane"
    fi
  done
}

cmd_enable() {
  if [ ! -f "$TRAP_FILE" ]; then
    echo "Error: trap variant not found at $TRAP_FILE" >&2
    exit 1
  fi

  echo "==> Resetting media lanes to clean state first ..."
  bash "$SCRIPT_DIR/reset-agent.sh" media >/dev/null 2>&1 || true

  echo "==> Swapping in trap variant ..."
  for lane in no-trigrep with-trigrep; do
    local target="$DEMO_ROOT/$lane/$MEDIA_PATH/$HCC_REL"
    if [ -d "$DEMO_ROOT/$lane/$MEDIA_PATH" ]; then
      cp "$TRAP_FILE" "$target"
      printf "    %s  ✓\n" "$lane/$MEDIA_PATH/$HCC_REL"
    fi
  done

  echo "==> Rebuilding LST + index for with-trigrep lane ..."
  mod build "$DEMO_ROOT/with-trigrep/$MEDIA_PATH" 2>&1 | grep -E "MOD SUCCEEDED|FAILED|Built" | head -3
  mod postbuild search index "$DEMO_ROOT/with-trigrep/$MEDIA_PATH" 2>&1 | grep -E "MOD SUCCEEDED|indexed" | head -2

  cat <<'EOF'

==> Trap mode ENABLED for the media lane.

The migration recipe will leave `template.setErrorHandler(...)` intact
in HttpClientConfig.java; the agent will need to fix it manually after
running the recipe (e.g. with RestClient.builder().defaultStatusHandler()).

⚠  Trap mode is single-take. After the agent runs the recipe, the lane
   source won't compile until the fix lands. Any subsequent MCP LST
   rebuild will fall back to PlainText and break the agent's tools.

Run `./demo trap disable` (or `./demo reset media`) between takes.
EOF
}

cmd_disable() {
  echo "==> Restoring clean state via reset-agent.sh ..."
  bash "$SCRIPT_DIR/reset-agent.sh" media

  echo ""
  echo "==> Trap mode DISABLED. Lanes back to default (recipe output compiles clean)."
}

case "${1:-status}" in
  status)  echo "==> Trap status (media lane)"; cmd_status ;;
  enable)  cmd_enable ;;
  disable) cmd_disable ;;
  *)
    echo "Usage: $0 status|enable|disable" >&2
    exit 1
    ;;
esac
