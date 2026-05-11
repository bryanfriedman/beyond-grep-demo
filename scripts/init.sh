#!/usr/bin/env bash
#
# Initializes the Beyond grep demo environment.
#
# Clones the working set into working-set/ for Demo 1, and provisions
# two single-repo Demo 2 candidates (streamlist/media-aggregator from
# media-aggregator-app/ and spring-projects/spring-petclinic cloned from GitHub) into
# both no-trigrep/ and with-trigrep/. Both are Gradle-based to dodge the
# modmaven-metadata bug that breaks MCP type resolution on Maven repos.
# Builds LSTs so `mod search` and `mod mcp` have something to query against.
#
# Usage: ./init.sh [--skip-build] [--skip-index] [--clean] [--reset]
#   --skip-build          Clone only; don't run `mod build`
#   --skip-index          Skip `mod postbuild search index` (useful if you want
#                         to run it live during the demo as a setup reveal)
#   --clean               Remove cloned repos and .moderne artifacts, then exit
#   --reset               Clean and re-initialize (equivalent to --clean + init)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEMO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPOS_CSV="$DEMO_ROOT/repos.csv"
WORKING_SET_DIR="$DEMO_ROOT/working-set"
NO_DIR="$DEMO_ROOT/no-trigrep"
WITH_DIR="$DEMO_ROOT/with-trigrep"

# Demo 2 single-repos. Two options exposed to start-agent.sh — pick at session
# launch via `./start-agent.sh <lane> <key>` where <key> is one of:
#   media     → streamlist/media-aggregator (curated synthetic, from media-aggregator-app/) —
#               HTTP-client modernization (RestTemplate → RestClient).
#   petclinic → spring-projects/spring-petclinic (real-world, from GitHub) —
#               Spring Boot 4 best practices, e.g. @Autowired field → constructor
#               injection.
# Both are Gradle. Maven would silently break MCP type resolution via the
# modmaven-metadata bug in `mod mcp`.
MEDIA_PATH="streamlist/media-aggregator"
MEDIA_SOURCE="local:$DEMO_ROOT/media-aggregator-app"
MEDIA_BRANCH="main"

PETCLINIC_PATH="spring-projects/spring-petclinic"
PETCLINIC_SOURCE="git:https://github.com/spring-projects/spring-petclinic.git"
PETCLINIC_BRANCH="main"

SKIP_BUILD=false
SKIP_INDEX=false
CLEAN=false
RESET=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=true; shift ;;
    --skip-index) SKIP_INDEX=true; shift ;;
    --clean)      CLEAN=true; shift ;;
    --reset)      CLEAN=true; RESET=true; shift ;;
    -h|--help)
      sed -n '3,17p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ "$CLEAN" = true ]; then
  echo "==> Cleaning demo directories..."
  chmod -R u+w "$WORKING_SET_DIR" "$NO_DIR" "$WITH_DIR" "$DEMO_ROOT/.moderne" 2>/dev/null || true
  rm -rf "$WORKING_SET_DIR" "$NO_DIR" "$WITH_DIR" "$DEMO_ROOT/.moderne"
  echo "==> Clean complete."
  [ "$RESET" = false ] && exit 0
fi

if [ ! -f "$REPOS_CSV" ]; then
  echo "Error: repos.csv not found at $REPOS_CSV" >&2
  exit 1
fi

# ─── working-set (Demos 1 & 2) ────────────────────────────────────────────────

echo "==> Syncing working set into working-set/..."
mkdir -p "$WORKING_SET_DIR"
mod git sync csv "$WORKING_SET_DIR" "$REPOS_CSV" --with-sources --yes || true

# ─── single-repo provisioning (Demo 2) ────────────────────────────────────────
#
# provision_repo <lane-dir> <repo-path> <source-spec> <branch>
#   <source-spec> is one of:
#     local:/abs/path     → cp -R the local source tree
#     git:<url>           → git clone --branch <branch> --single-branch
provision_repo() {
  local lane="$1"
  local path="$2"
  local source="$3"
  local branch="$4"
  local target="$lane/$path"

  echo "==> Provisioning $path into $(basename "$lane")/..."
  mkdir -p "$lane/$(dirname "$path")"
  if [ -d "$target" ]; then
    echo "    (already exists; skipping)"
    return
  fi
  case "$source" in
    local:*)
      local src="${source#local:}"
      cp -R "$src" "$target"
      # Strip caches and source-of-truth-only directories that shouldn't
      # appear inside the provisioned lane copy.
      rm -rf "$target/.moderne" "$target/build" "$target/extras"
      ;;
    git:*)
      local url="${source#git:}"
      git clone --branch "$branch" --single-branch "$url" "$target"
      ;;
    *)
      echo "    ERROR: unrecognized source spec: $source" >&2
      return 1
      ;;
  esac
}

# Provision both repos into both lanes.
for lane in "$NO_DIR" "$WITH_DIR"; do
  provision_repo "$lane" "$MEDIA_PATH"   "$MEDIA_SOURCE"   "$MEDIA_BRANCH"
  provision_repo "$lane" "$PETCLINIC_PATH" "$PETCLINIC_SOURCE" "$PETCLINIC_BRANCH"
done

# ─── per-repo lane setup (configs, symlinks, CLAUDE.md) ───────────────────────
#
# setup_lane_repo <lane-dir> <repo-path> <claude-md-content>
#   For with-trigrep: drops .mcp.json (Moderne stdio) + CLAUDE.md.
#   For no-trigrep:   drops empty-mcp.json.
#   Both: symlinks start-agent.sh and session-tokens.sh.
setup_lane_repo() {
  local lane="$1"
  local path="$2"
  local claude_md="$3"
  local target="$lane/$path"

  if [[ "$lane" == "$WITH_DIR" ]]; then
    # No project-scope .mcp.json — the with-trigrep lane inherits the
    # user-scope `moderne` MCP server registered by `mod config agent-tools
    # install`. Provisioning a project-scope copy creates duplicate-endpoint
    # warnings against an already-authenticated user-scope server.
    if [ -n "$claude_md" ]; then
      printf '%s\n' "$claude_md" > "$target/CLAUDE.md"
    fi
  else
    # The no-trigrep lane explicitly blocks MCP inheritance via
    # --strict-mcp-config + this empty config (see start-agent.sh).
    cat > "$target/empty-mcp.json" <<'EOF'
{
  "mcpServers": {}
}
EOF
  fi
  ln -sf "$SCRIPT_DIR/start-agent.sh"    "$target/start-agent.sh"
  ln -sf "$SCRIPT_DIR/session-tokens.sh" "$target/session-tokens.sh"
}

# Neither repo gets a repo-scoped CLAUDE.md — the agent relies on the
# Moderne MCP tool descriptions plus the user prompt. The setup_lane_repo
# claude_md parameter is preserved (passes empty here) in case repo-scoped
# guidance is reintroduced later.
MEDIA_CLAUDE_MD=''
PETCLINIC_CLAUDE_MD=''

for lane in "$NO_DIR" "$WITH_DIR"; do
  setup_lane_repo "$lane" "$MEDIA_PATH"   "$MEDIA_CLAUDE_MD"
  setup_lane_repo "$lane" "$PETCLINIC_PATH" "$PETCLINIC_CLAUDE_MD"
done

# ─── builds and indexes ───────────────────────────────────────────────────────

if [ "$SKIP_BUILD" = false ]; then
  echo "==> Building LSTs for working set (this may take a while)..."
  mod build "$WORKING_SET_DIR" || echo "    (working-set build had failures; continuing)"

  echo "==> Building LSTs for Demo 2 with-trigrep lane..."
  mod build "$WITH_DIR" || echo "    (with-trigrep build had failures; Trigrep will be limited)"
else
  echo "==> Skipping LST builds (--skip-build)"
fi

if [ "$SKIP_INDEX" = false ] && [ "$SKIP_BUILD" = false ]; then
  echo "==> Building trigram search indexes for working set..."
  mod postbuild search index "$WORKING_SET_DIR" || echo "    (working-set index build failed)"
  echo "==> Building trigram search indexes for Demo 2 with-trigrep lane..."
  mod postbuild search index "$WITH_DIR" || echo "    (with-trigrep index build failed)"
elif [ "$SKIP_INDEX" = true ]; then
  echo "==> Skipping trigram index build (--skip-index)"
  echo "    Run \`mod postbuild search index <path>\` before \`mod search\`."
fi

echo ""
echo "==> Init complete."
echo "    Demo 1 (working-set CLI):    ./demo cli"
echo "    Demo 2 (single-repo agent):"
echo "      media:      ./demo agent with media       /   ./demo agent no media"
echo "      petclinic:  ./demo agent with petclinic   /   ./demo agent no petclinic"
