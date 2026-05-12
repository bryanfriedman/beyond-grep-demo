#!/usr/bin/env bash
#
# Unified launcher for the Demo 2 single-repo agent demo.
#
# From the demo root:
#   ./start-agent.sh [no|with] [media|petclinic|eureka] [--ask] [extra claude args...]
#
# From a lane's repo dir (via symlink):
#   ./start-agent.sh [--ask] [extra claude args...]
#
# Defaults: lane = with (inherits user-scope Moderne MCP), repo-key = media,
# permissions = skip (yolo-by-default). Pass --ask to opt into Claude's normal
# permission prompts.

set -euo pipefail

INVOKED_FROM="$(cd "$(dirname "$0")" && pwd)"

# Repo key → repo path mapping.
REPO_PATH_media="streamlist/media-aggregator"
REPO_PATH_petclinic="spring-projects/spring-petclinic"
REPO_PATH_eureka="Netflix/eureka"

case "$INVOKED_FROM" in
  */no-trigrep/*)
    LANE="no"
    REPO_DIR="$INVOKED_FROM"
    ;;
  */with-trigrep/*)
    LANE="with"
    REPO_DIR="$INVOKED_FROM"
    ;;
  *)
    # Invoked from demo root or scripts/. Find the demo root: it's the dir
    # containing repos.csv (either INVOKED_FROM or its parent).
    if [ -f "$INVOKED_FROM/repos.csv" ]; then
      DEMO_ROOT="$INVOKED_FROM"
    elif [ -f "$INVOKED_FROM/../repos.csv" ]; then
      DEMO_ROOT="$(cd "$INVOKED_FROM/.." && pwd)"
    else
      echo "Cannot locate demo root from $INVOKED_FROM" >&2
      exit 1
    fi

    # Optional lane, defaults to with.
    case "${1:-}" in
      no|with) LANE="$1"; shift ;;
      *)       LANE="with" ;;
    esac

    # Optional repo key, defaults to media.
    REPO_KEY="media"
    case "${1:-}" in
      media|petclinic|eureka) REPO_KEY="$1"; shift ;;
    esac

    # Resolve repo path from the key.
    var="REPO_PATH_${REPO_KEY}"
    REPO_PATH="${!var:-}"
    if [ -z "$REPO_PATH" ]; then
      echo "Unknown repo key: $REPO_KEY (expected media|petclinic|eureka)" >&2
      exit 1
    fi

    case "$LANE" in
      no)   REPO_DIR="$DEMO_ROOT/no-trigrep/$REPO_PATH" ;;
      with) REPO_DIR="$DEMO_ROOT/with-trigrep/$REPO_PATH" ;;
      *)
        echo "Usage: $0 [no|with] [media|petclinic|eureka] [--ask] [extra claude args...]" >&2
        exit 1
        ;;
    esac
    ;;
esac

if [ ! -d "$REPO_DIR" ]; then
  echo "Lane repo dir not found: $REPO_DIR" >&2
  if [[ "$REPO_DIR" == *"/Netflix/eureka" ]]; then
    echo "The eureka lane is opt-in. Provision with: ./demo init --with-eureka" >&2
  else
    echo "Did you run ./init.sh?" >&2
  fi
  exit 1
fi

# Permissions: yolo-by-default. Pass --ask to opt into Claude's normal permission prompts.
SKIP_PERMS=true
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --ask) SKIP_PERMS=false ;;
    *)     ARGS+=("$arg") ;;
  esac
done
if [ "$SKIP_PERMS" = true ]; then
  ARGS=("--dangerously-skip-permissions" "${ARGS[@]}")
fi

cd "$REPO_DIR"
clear

case "$LANE" in
  # no: explicit empty config blocks user-scope MCP inheritance
  no)   exec claude --strict-mcp-config --mcp-config empty-mcp.json "${ARGS[@]}" ;;
  # with: inherit user-scope `moderne` MCP (registered via `mod config agent-tools install`)
  with) exec claude "${ARGS[@]}" ;;
esac
