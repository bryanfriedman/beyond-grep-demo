#!/usr/bin/env bash
#
# Unified launcher for the Demo 2 single-repo agent demo.
#
# From the demo root:
#   ./start.sh no|with [media|petclinic] [--yolo] [extra claude args...]
#
# From a lane's repo dir (via symlink):
#   ./start.sh [--yolo] [extra claude args...]
#
# The repo-key (media|petclinic) defaults to `media`.

set -euo pipefail

INVOKED_FROM="$(cd "$(dirname "$0")" && pwd)"

# Repo key → repo path mapping.
REPO_PATH_media="streamlist/media-aggregator"
REPO_PATH_petclinic="spring-projects/spring-petclinic"

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

    LANE="${1:-}"
    shift || true

    # Optional repo key, defaults to media.
    REPO_KEY="media"
    case "${1:-}" in
      media|petclinic) REPO_KEY="$1"; shift ;;
    esac

    # Resolve repo path from the key.
    var="REPO_PATH_${REPO_KEY}"
    REPO_PATH="${!var:-}"
    if [ -z "$REPO_PATH" ]; then
      echo "Unknown repo key: $REPO_KEY (expected media|petclinic)" >&2
      exit 1
    fi

    case "$LANE" in
      no)   REPO_DIR="$DEMO_ROOT/no-trigrep/$REPO_PATH" ;;
      with) REPO_DIR="$DEMO_ROOT/with-trigrep/$REPO_PATH" ;;
      *)
        echo "Usage: $0 no|with [media|petclinic] [--yolo] [extra claude args...]" >&2
        exit 1
        ;;
    esac
    ;;
esac

if [ ! -d "$REPO_DIR" ]; then
  echo "Lane repo dir not found: $REPO_DIR" >&2
  echo "Did you run ./init.sh?" >&2
  exit 1
fi

# Translate --yolo / --skip-perms shortcut.
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --yolo|--skip-perms) ARGS+=("--dangerously-skip-permissions") ;;
    *)                   ARGS+=("$arg") ;;
  esac
done

cd "$REPO_DIR"

case "$LANE" in
  no)   exec claude --strict-mcp-config --mcp-config empty-mcp.json "${ARGS[@]}" ;;
  with) exec claude --strict-mcp-config --mcp-config .mcp.json      "${ARGS[@]}" ;;
esac
