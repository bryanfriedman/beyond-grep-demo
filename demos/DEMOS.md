# Beyond grep — demos

Two demos, both built on the same LST substrate:

| # | Demo | Surface | Where it runs |
|---|---|---|---|
| 1 | Trigrep CLI across the working set, ending with a `--last-search` recipe handoff | `mod search` → `mod run --last-search` | `working-set/` via [sequences/demo1.txt](sequences/demo1.txt) |
| 2 | Agent with Trigrep MCP on a single repo, two example prompts | Claude Code | `./demo start with <repo>` |

A separate platform-only opener (a recipe run from the Moderne UI) is performed live and is not scaffolded here.

## Prerequisites

```bash
./demo init
```

Clones the working set, provisions both Demo 2 single-repo lanes, builds LSTs, and indexes them. See [../README.md](../README.md) for flags.

---

## Demo 1 — Trigrep CLI across the portfolio

> **Scenario:** "I'm a platform engineer. Leadership decided we're modernizing our HTTP-client layer across the Spring services we own. Before I commit to anything, I need a real picture of what's in there. How many services still use `RestTemplate`? Where are the call sites? What other shapes — `WebClient`, `RestClient`, OkHttp, Feign — do we already have? I want to climb from 'find a string' to 'find a method shape' without changing tools, then narrow to a precise recipe pass on just the repos that matter."

**What the demo proves:** one search surface, several projections. Open with grep-shaped queries the audience already knows (literals, regex). Climb the ladder: symbol search, semantic filters (`visibility:public throws:IOException`, `returns:ResponseEntity` — try saying those in grep), `struct:` for code shapes that span multiple tokens. Each rung answers something the rung below can't. Close by handing the matched repo set straight to a recipe via `--last-search` — fast Trigrep narrows the haystack, the recipe works the narrowed haystack.

> Closing line: *"Same LST, different projections. Trigrep is the fast one — and it hands directly to the precise one."*

```bash
./demo seq demo1
```

The sequencer renders each block as a fake shell prompt + the command on the next line, narration cues showing as `# comments` above. Press Enter to advance — at each step you can edit the command inline before running it (bash 4+ `read -e -i`). Empty input skips a block; Ctrl-C exits cleanly.

To iterate, edit [sequences/demo1.txt](sequences/demo1.txt). The first block is `cd working-set`; everything after runs from that working directory. Pull additional candidate queries from [QUERIES.md](QUERIES.md).

---

## Demo 2 — Agent with Trigrep MCP

A single-repo agent demo where Claude Code drives the work through Trigrep MCP tools. Two example prompts, picked to show different depths of agent + recipe composition — and each one is paired with the repo it fits best. Both lanes are Gradle (Maven silently breaks MCP type resolution via the `modmaven-metadata` bug) and ship with `.mcp.json` pointing at the Moderne MCP server.

| Example | Repo | Prompt depth | Why this pairing |
|---|---|---|---|
| A | `petclinic` (`spring-projects/spring-petclinic`) | Shallow inventory | Real, recognizable codebase. Audience nods at "yeah, petclinic." Shows the agent driving Trigrep across code we didn't write. |
| B | `media` (`streamlist/media-aggregator`, from [`media-aggregator-app/`](../media-aggregator-app/)) | Full flow with recipe | Curated for predictability across rehearsals. Designed with multiple `RestTemplate` call patterns so the recipe diff reads visually. Optional trap mode for the "agent fixes what the recipe didn't" beat. |

After `./demo start with <repo> --yolo`, give the terminal ~15–30 s before pasting the prompt — MCP tools register progressively as the LST builds. `/mcp` shows status; wait until the Moderne server reports all 18 tools (or autocomplete `mcp__moderne__find_types`). Petclinic's first build is slower (~60–90 s) because of SB 4 AOT-generated stubs; cached after.

### Example A — petclinic, Trigrep-driven inventory (shallow)

> **Scenario:** "Before I commit to anything in this real-world Spring sample, I want the agent to give me the lay of the land. What's the dependency-injection style? Where is field-level `@Autowired` still being used? Just the inventory pass — same kind of thing Demo 1 did across the portfolio, narrowed to one repo and driven by an agent that picks the search tools itself."

```bash
./demo start with petclinic --yolo
```

Suggested prompt:

```
Give me an inventory of dependency-injection usage in this repo. Where
is field-level @Autowired still in use? Where is constructor injection
already in place? What's the spread? Use the search tools available to
you and summarize.
```

What you're watching for: the agent reaches for Moderne MCP tools (`find_annotations`, `trigrep_search`, `find_types`) instead of grep + read-each-file. The payoff is the same kind of inventory Demo 1 did across the portfolio — but the agent picked the tools itself, on a real codebase, in seconds.

### Example B — media, inventory + recipe (full flow)

> **Scenario:** "Now I want the agent to do the migration end-to-end on a service I own. Inventory the `RestTemplate` surface, find the OpenRewrite recipe that handles the mechanical conversion, run it, fix anything the recipe didn't cover, and report what changed."

```bash
./demo reset media           # before each rehearsal
./demo start with media --yolo
```

Suggested prompt (start with this; refine over time):

```
Inventory the RestTemplate usage in this repo and apply the most
appropriate migration recipe to the mechanical cases. Stop when the
mechanical cases are handled — leave anything ambiguous untouched and
document what was deferred.
```

What you're watching for: agent calls `find_types` / `trigrep_search` for inventory → `search_recipes` to discover the recipe → `learn_recipe` to read it → `run_recipe` to apply it → manual edits only where the recipe leaves something unfinished. That whole chain happens inside one MCP server.

> Closing line: *"Same LST, third projection. Trigrep is now a tool the agent picks up like any other — and the recipe layer is right alongside it."*

### Optional: side-by-side with `no-trigrep` (token delta)

A natural follow-on to either example: run the same prompt against the `no-trigrep/` lane (zero MCP servers via `empty-mcp.json`) and put the two sessions side by side. The agent falls back to grep + read-each-file, and the token delta is the number to quote live.

```bash
./demo start no media --yolo        # or `no petclinic`
./demo tokens <session-id>          # run for both sessions, after capturing the IDs
```

### Optional: trap mode for the `media` repo

`media-aggregator-app/` ships clean by default — the recipe produces compilable output. If you want a beat where the agent has to fix something the recipe leaves broken, enable trap mode:

```bash
./demo trap enable          # cps a setErrorHandler-using HttpClientConfig
./demo trap status
./demo trap disable         # back to clean
```

With the trap on, the recipe leaves `template.setErrorHandler(...)` in `HttpClientConfig` — but `RestClient` has no `setErrorHandler` method. The agent has to recognize the compile break and convert to `RestClient.builder().defaultStatusHandler(...)` (or document the deferral). Trap mode is fragile across rehearsals (the recipe leaves uncompilable code, which can poison subsequent MCP LST rebuilds), so use `./demo reset media` between runs.

---

## Troubleshooting

- **`mod search` returns "No search index"**: LSTs built but trigram indexes weren't. Run `mod postbuild search index <path>`. If you ran `./demo init --skip-index`, that's intentional — run the postbuild live.
- **`mod search` returns nothing (no error)**: LSTs weren't built. Re-run `./demo init` or `mod build <repo>`.
- **`--last-search` errors**: run a `mod search` first in the same working directory; `--last-search` reads from CLI state in `~/.moderne/`.
- **Agent in `with-trigrep/` doesn't use MCP**: confirm `.mcp.json` exists and `mod` is on PATH. Re-launch `claude` — MCP servers register at startup.
- **MCP tools show only `build_status`**: give it 15–30 s. Tools register progressively as the MCP server builds the LST internally. Use `/mcp` to check status.
- **Build failure on a working-set clone**: `./demo init --skip-build`, then build the others by hand. The working set is permissive — drop a repo if it costs more than it earns.
