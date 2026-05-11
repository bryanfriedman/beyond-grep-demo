# Beyond grep — demo

Demo materials for the _Beyond grep: how semantic code search makes large-scale change safer_ talk. Two demos, both built on the same LST substrate. A third beat — a recipe run on the Moderne Platform UI — happens live in the browser before Demo 1 and is not scaffolded here.

| # | Demo | Surface |
|---|---|---|
| 1 | Trigrep CLI across the working set, ending with a `--last-search` recipe handoff | `mod search` → `mod run --last-search` |
| 2 | Agent with Trigrep MCP on a single repo (two example prompts) | Claude Code |

Demos run live; the side-by-side `no-trigrep/` lane and `./demo tokens` are there as a backup / cost-comparison option, not the default flow.

## Prerequisites

- [Moderne CLI](https://docs.moderne.io/moderne-cli/getting-started/cli-intro) (`mod`) installed and authenticated
- Moderne MCP server registered at user scope: `mod config agent-tools install` (one-time; the `with-trigrep` lane inherits this)
- Git
- JDK 17+ on PATH (the CLI provisions per-repo JDKs internally for older repos)
- Maven and Gradle for LST builds
- Bash 4+ (Homebrew bash). macOS default `/bin/bash` is 3.2 and is not enough — `run-sequence.sh` uses `read -e -i`, which is bash 4+.
- Python 3 for token counting
- Claude Code installed for Demo 2

## Setup

```bash
./demo init
```

This will:
1. Clone the working set ([repos.csv](repos.csv)) into `working-set/`
2. Provision **two** Demo 2 single-repos into both `no-trigrep/` and `with-trigrep/`:
   - `streamlist/media-aggregator` (curated, copied from `media-aggregator-app/`)
   - `spring-projects/spring-petclinic` (cloned from GitHub)
3. Drop an `empty-mcp.json` into each `no-trigrep/` repo (zero MCP servers — blocks user-scope inheritance)
4. Build LSTs and trigram search indexes so `mod search` works

The `with-trigrep/` lane has no project-scope MCP config — it inherits the user-scope `moderne` MCP registered by `mod config agent-tools install`.

Flags:
- `--skip-build` — clone only, skip `mod build`
- `--skip-index` — skip the trigram index build (run live during the demo if you want)
- `--clean` — remove cloned dirs and `.moderne/` artifacts
- `--reset` — clean + re-init

## Directory layout

```
.
├── README.md                       # this file
├── repos.csv                       # working set (Demo 1)
├── demo                            # master entry point; dispatches to scripts/
├── demos/
│   ├── DEMOS.md                    # per-demo walkthrough
│   ├── QUERIES.md                  # curated Trigrep query catalog
│   └── demo.txt                    # Demo 1 CLI sequence (edit freely)
├── media-aggregator-app/           # curated source for the Demo 2 `media` repo
│   └── extras/                     # opt-in HttpClientConfig.with-trap.java + README
├── scripts/                        # subcommand scripts (also runnable directly)
│   ├── init.sh                     # ./demo init
│   ├── start-agent.sh              # ./demo agent
│   ├── reset-agent.sh              # ./demo reset
│   ├── trap-mode.sh                # ./demo trap status|enable|disable
│   ├── run-sequence.sh             # ./demo cli
│   └── session-tokens.sh           # ./demo tokens <session-id>
├── working-set/                    # generated — synced via mod git sync
├── no-trigrep/                     # generated — agent lane, no MCP
│   ├── streamlist/media-aggregator
│   └── spring-projects/spring-petclinic
└── with-trigrep/                   # generated — agent lane, Trigrep MCP
    ├── streamlist/media-aggregator
    └── spring-projects/spring-petclinic
```

## Running the demos

See [demos/DEMOS.md](demos/DEMOS.md) for the per-demo walkthrough. For the curated query bench, see [demos/QUERIES.md](demos/QUERIES.md).

### Quick reference

```bash
./demo init                              # one-time setup

./demo cli                               # Demo 1 — working-set Trigrep CLI + --last-search bridge

./demo reset media                       # before each Demo 2 rehearsal
./demo agent                             # Demo 2 — defaults to `with media --yolo` style flow
./demo agent with petclinic --yolo       # Demo 2 — petclinic repo
./demo agent no media --yolo             # Optional cost comparison (no MCP)

./demo trap status                       # is the trap enabled in the media lane?
./demo trap enable                       # opt into the "agent fixes recipe gap" beat
./demo trap disable                      # back to clean

./demo tokens <session-id>               # token report after a Demo 2 session
```

The lane symlinks for `./start-agent.sh` inside each `no-trigrep/` and `with-trigrep/` repo dir continue to work — they point at `scripts/start-agent.sh` directly. From inside a lane, `./start-agent.sh --yolo` launches the agent with that lane's MCP config.
