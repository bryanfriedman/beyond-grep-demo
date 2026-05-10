#!/usr/bin/env bash
#
# Initializes the Beyond grep demo environment.
#
# Clones the multi-repo set into multi-repo/ for Demo 1, and provisions
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
MULTI_DIR="$DEMO_ROOT/multi-repo"
NO_DIR="$DEMO_ROOT/no-trigrep"
WITH_DIR="$DEMO_ROOT/with-trigrep"

# Demo 2 single-repos. Two options exposed to start.sh — pick at session
# launch via `./start.sh <lane> <key>` where <key> is one of:
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
  chmod -R u+w "$MULTI_DIR" "$NO_DIR" "$WITH_DIR" "$DEMO_ROOT/.moderne" 2>/dev/null || true
  rm -rf "$MULTI_DIR" "$NO_DIR" "$WITH_DIR" "$DEMO_ROOT/.moderne"
  echo "==> Clean complete."
  [ "$RESET" = false ] && exit 0
fi

if [ ! -f "$REPOS_CSV" ]; then
  echo "Error: repos.csv not found at $REPOS_CSV" >&2
  exit 1
fi

# ─── multi-repo (Demos 1 & 2) ─────────────────────────────────────────────────

echo "==> Syncing multi-repo set into multi-repo/..."
mkdir -p "$MULTI_DIR"
mod git sync csv "$MULTI_DIR" "$REPOS_CSV" --with-sources --yes || true

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
#   Both: symlinks start.sh and session-tokens.sh.
setup_lane_repo() {
  local lane="$1"
  local path="$2"
  local claude_md="$3"
  local target="$lane/$path"

  if [[ "$lane" == "$WITH_DIR" ]]; then
    cat > "$target/.mcp.json" <<'EOF'
{
  "mcpServers": {
    "moderne": {
      "type": "stdio",
      "command": "bash",
      "args": [
        "-c",
        "if [ -x \"$HOME/.moderne/cli/bin/mod\" ]; then exec \"$HOME/.moderne/cli/bin/mod\" mcp; else exec mod mcp; fi"
      ]
    }
  }
}
EOF
    # Only drop CLAUDE.md when caller passed non-empty content — a repo can
    # opt out of repo-scoped guidance and rely on MCP tool descriptions alone.
    if [ -n "$claude_md" ]; then
      printf '%s\n' "$claude_md" > "$target/CLAUDE.md"
    fi
  else
    cat > "$target/empty-mcp.json" <<'EOF'
{
  "mcpServers": {}
}
EOF
  fi
  ln -sf "$SCRIPT_DIR/start.sh"          "$target/start.sh"
  ln -sf "$SCRIPT_DIR/session-tokens.sh" "$target/session-tokens.sh"
}

MEDIA_CLAUDE_MD='# Agent guidance for this repo

This repo has the Moderne MCP server configured. The codebase is a small
Spring Boot 3.5 service that aggregates streaming-media metadata across
multiple upstream providers using `RestTemplate`. Spring deprecated
`RestTemplate` for new development; the migration target is `RestClient`
(Spring 6.1+, synchronous), which this codebase already supports.

Inventory the RestTemplate usage, run the migration recipe where it covers
the case, fix anything the recipe leaves broken, and document anything you
deferred.

## How to work in this repo

**Search:** Use the Moderne MCP tools — they are backed by Trigrep, a
trigram index built over pre-built LSTs. They return structured, typed
results from the LST in milliseconds, so you can skip the
read-to-confirm-type loop.
- `find_types` for type references (imports, fields, parameters, casts, generics)
- `find_methods` for method invocations by AspectJ pattern
- `find_annotations` for annotation usages
- `trigrep_search` / `trigrep_structural_search` for free-text and Comby patterns
- `symbols_overview` to understand a file before reading it

Reach for grep only when Trigrep cannot express the query (free-text prose
in comments, non-Java files, etc.).

**Transform:** When making transformations, look for available OpenRewrite
recipes via MCP **before** writing manual edits. Recipes are deterministic
and preserve formatting; prefer them whenever they cover the case at hand.
Workflow:
1. `search_recipes` to find candidates — try queries like "RestTemplate",
   "RestClient", "Spring Boot", etc.
2. `learn_recipe` on a likely match to read its full description and options.
3. `run_recipe` to apply it. Recipes operate on the LST and produce diffs
   you can review.

Fall back to manual edits (`Edit`, `change_type`, `change_method_name`,
`pattern_replace` with a Refaster template) only for cases recipes do not
cover.

**Scope:** This is an inventory + partial migration, not a full sweep.
Cover the clear call sites, document anything ambiguous, summarize what
was changed and what was left.'

# spring-petclinic: no repo-scoped CLAUDE.md. The agent gets its guidance
# from the Moderne MCP tool descriptions (which themselves prefer Trigrep
# over grep and describe the search_recipes → learn_recipe → run_recipe
# workflow) plus the user prompt. Tests whether the MCP surface alone is
# enough.
PETCLINIC_CLAUDE_MD=''

for lane in "$NO_DIR" "$WITH_DIR"; do
  setup_lane_repo "$lane" "$MEDIA_PATH"   "$MEDIA_CLAUDE_MD"
  setup_lane_repo "$lane" "$PETCLINIC_PATH" "$PETCLINIC_CLAUDE_MD"
done

# ─── builds and indexes ───────────────────────────────────────────────────────

if [ "$SKIP_BUILD" = false ]; then
  echo "==> Building LSTs for multi-repo set (this may take a while)..."
  for repo in "$MULTI_DIR"/*/*; do
    [ -d "$repo" ] || continue
    echo "    building $repo"
    mod build "$repo" || echo "    (build failed for $repo; continuing)"
  done

  echo "==> Building LSTs for Demo 2 with-trigrep lane..."
  for path in "$MEDIA_PATH" "$PETCLINIC_PATH"; do
    echo "    building $WITH_DIR/$path"
    mod build "$WITH_DIR/$path" || echo "    (build failed for $path; Trigrep will be limited)"
  done
else
  echo "==> Skipping LST builds (--skip-build)"
fi

if [ "$SKIP_INDEX" = false ] && [ "$SKIP_BUILD" = false ]; then
  echo "==> Building trigram search indexes for multi-repo set..."
  mod postbuild search index "$MULTI_DIR" || echo "    (multi-repo index build failed)"
  echo "==> Building trigram search indexes for Demo 2 with-trigrep lane..."
  for path in "$MEDIA_PATH" "$PETCLINIC_PATH"; do
    mod postbuild search index "$WITH_DIR/$path" || echo "    (index build failed for $path)"
  done
elif [ "$SKIP_INDEX" = true ]; then
  echo "==> Skipping trigram index build (--skip-index)"
  echo "    Run \`mod postbuild search index <path>\` before \`mod search\`."
fi

echo ""
echo "==> Init complete."
echo "    Demo 1 (multi-repo CLI):     ./demo seq demo1"
echo "    Demo 2 (single-repo agent):"
echo "      media:      ./demo start with media --yolo       /   ./demo start no media --yolo"
echo "      petclinic:  ./demo start with petclinic --yolo   /   ./demo start no petclinic --yolo"
