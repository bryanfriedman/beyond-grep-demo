# Beyond grep — demos

The talk's pitch: code change at scale needs more than grep. Recipes are precise but require knowing what to change. Search is fast but text-only. Moderne builds both on the same LST substrate, so they compose — search hands off to recipe without re-parsing, and agents pick up the same tools the same way.

The kind of change we're walking through is the routine reality of any long-lived Spring codebase: *the framework moves on, your code stays where it was written.* Field `@Autowired` was idiomatic five years ago; Spring now recommends constructor injection (testability, immutability, fail-fast wiring). `RestTemplate` was the HTTP client for a decade; Spring put it in maintenance mode and points new code at `RestClient` (Spring 6.1+, synchronous, fluent builder). The audit-and-migrate work is the same recurring problem at portfolio scale.

Two demos, same handoff pattern (search narrows, recipe acts), different surfaces:

| # | Demo | What it shows | Surface | Where it runs |
|---|------|---------------|---------|---------------|
| 1 | Trigrep CLI across the working set | Two climbs, two recipe destinations via `--last-search`: search recipe (Item inventory) and transformation recipe (javax → jakarta migration) | `mod search` → `mod run --last-search` | `working-set/` via [demo.txt](demo.txt) |
| 2 | Agent with Moderne MCP on a single repo | Trigrep first-cut, then user follow-up triggers a recipe — two examples mirroring Demo 1's two recipe destinations | Claude Code | `./demo agent with petclinic` and `./demo agent with media` |

A separate platform-only opener (a recipe run from the Moderne UI) is performed live and is not scaffolded here. It establishes "recipes work" — the rest of the talk is *how the platform engineer gets to a recipe* (Demo 1) and *how an agent picks one up* (Demo 2).

## The shared pattern

Both demos demonstrate the same escalation: **Trigrep narrows fast, a recipe gives the precise answer.** And both demos show the same two recipe destinations — search recipes (precise inventory) and transformation recipes (migration).

- **Demo 1** runs both destinations in the CLI: Section 1's Item climb hands off to a search recipe (`FindTypes`); Section 2's javax climb hands off to a transformation recipe (migration of `javax.*` imports to `jakarta.*`).
- **Demo 2** shows the agent picking tools by question: petclinic uses Trigrep alone (`trigrep_search` and `trigrep_structural_search`) for fast exploratory questions where a recipe would be overkill; media does the full inventory-plus-transformation flow, escalating from Trigrep through `find_*` to the migration recipe.

Search and recipes aren't separate tools you bolt together. They're projections of the same LST that hand off to each other, regardless of who's driving — human in the CLI or agent through MCP.

---

## Prerequisites

```bash
./demo init
```

Clones the working set, provisions both Demo 2 single-repo lanes, builds LSTs, and indexes them. See [../README.md](../README.md) for flags.

---

## Demo 1 — Trigrep CLI across the working set

> **Scenario:** "I'm a platform engineer at a Spring shop. Leadership says modernize. Two specific items on my plate: I need an inventory of where `Item`-like domain types live across services (which services own which), and the Jakarta EE rename — `javax.*` imports need to become `jakarta.*` so we can move to Spring 6 / Boot 3. I want to climb from 'find a string' to 'find a code shape' without changing tools, then narrow to a precise recipe pass — sometimes for inventory, sometimes for transformation."

**What the demo proves:** Trigrep supports breadth of search types (literal, regex, `type:symbol`, structural patterns), AND it hands off to *two* recipe destinations via `--last-search` — search recipes (precise inventory) and transformation recipes (migration). All on the same LST, no reparsing, no tool switch.

```bash
./demo cli
```

The sequencer renders each block as a fake shell prompt + the command on the next line, narration cues showing as `# comments` above. Press Enter to advance — at each step you can edit the command inline before running it (bash 4+ `read -e -i`). Empty input skips a block; Ctrl-C exits cleanly.

### Section 1 — Item climb, search-recipe handoff (~2-3 min)

Climb broad → narrow via different search shapes, ending in `FindTypes` for an FQN-precise inventory. The narrowing here has a subtle ordering: `type:symbol Item` still includes `*Item*` substring matches (e.g., `ItemRepository`), so a word-boundary regex `\bItem\b` is actually the narrowest text-based step. The recipe is FQN-precise.

Starting progression:

- Broad — every textual `Item` (the Item classes + `ItemRepository`, `itemId`, comments, strings) — `mod search . Item`
- Symbol — narrower, but still catches `*Item*` substrings — `mod search . type:symbol Item`
- Word-boundary regex — narrowest text-based, only "Item" as a standalone word — `mod search . '/\bItem\b/'`
- Hand to FindTypes — `mod run . --last-search --recipe=org.openrewrite.java.search.FindTypes -PfullyQualifiedTypeName=com.ewolff.microservice.catalog.Item`

What `FindTypes` adds on top of the regex: FQN-precise. The output is a clean list scoped to one specific `Item` type (here ewolff's catalog `Item`, dropping piggymetrics' account `Item`) — a search recipe as report destination, not a stepping stone.

### Interlude — Struct + LST-filter showcase (~75-90s)

Queries not tied to either climb, demonstrating two flavors of LST-aware searching that grep can't reach:

**Struct (code-shape matching with holes that capture varying content):**

- `mod search . 'struct:throw new :[exception:id](:[args:e])'` — every `throw new ...(...)` statement across the working set. Matches the *shape* (not the type); `:[exception:id]` captures different exception types; `:[args:e]` captures varying message shapes (empty, message-only, message + cause). One pattern, many concrete call shapes.
- `mod search . 'struct:@:[ann:id](":[value]")'` — every annotation with parameters (`@RequestMapping("/path")`, `@PreAuthorize("...")`, `@Cacheable(...)`, `@Qualifier("name")`, etc.). `:[ann:id]` captures the annotation name; `:[value]` captures whatever's inside the parens. Pattern stays constant; both captures vary across matches.

**LST filters (semantic queries grep can't ask):**

- `mod search . extends:RuntimeException` — every class that directly extends `RuntimeException`. Inheritance filter; grep can't ask "extends" semantically.
- `mod search . visibility:public throws:IOException` — every public method declaring `throws IOException`. Composed filter — two LST filters working together; the grep one-liner is a paragraph.

The interlude is orthogonal to both threads — its job is to land "Trigrep does code-shape and semantic-property searches the climbs didn't have room for" before we go back to thread-driven narrowing.

### Section 2 — javax → jakarta climb, transformation-recipe handoff (~3 min)

Same climb shape as Section 1, different destination — the recipe here is a *transformation*, not a search. The diff at the end is what the audience sees, not just a structured list. And unlike the Item climb, the visible payoff of `--last-search` here is *which repos get touched*: javax imports live in 3 of 4 working-set repos (ewolff, mall, piggymetrics); petclinic-microservices already migrated to jakarta and gets silently skipped.

Starting progression:

- Broadest — every textual `javax` (Java source, `pom.xml`/`build.gradle` deps, comments) — `mod search . javax`
- Narrow to source files — drops build-file matches; only `.java` content remains — `mod search . javax file:java`
- Hand to the migration recipe — `mod run . --last-search --recipe=org.openrewrite.java.migrate.jakarta.JavaxMigrationToJakarta`

What the migration recipe adds: the actual transformation. `javax.*` import statements get rewritten to `jakarta.*`, dependency coordinates in build files get bumped, and the diff is the destination. Demo 2 will pick up the same pattern (search → transformation recipe) with the agent — at media, the migration target is the related `RestTemplate` → `RestClient` modernization.

> Closing line for Demo 1: *"Two climbs, two destinations. One ended in a search recipe for precise inventory; the other ended in a transformation. Same handoff pattern, two different recipe types — exactly the shape Demo 2 mirrors with the agent."*

> **Note on rehearsal:** the queries above are starting points. Some `mod search` filter combinations have known quirks in CLI 4.2.x (path/lang filters render badly when combined with content terms; leading `-` query terms collide with the option parser). [QUERIES.md](QUERIES.md) has the bench and the gotchas — substitute alternates if a query reads poorly live.

---

## Demo 2 — Agent with Moderne MCP

The pattern Demo 2 demonstrates: **the agent picks tools by question.** Some questions need a fast text/structural scan; others need the full inventory-then-recipe flow. Two examples show both modes:

| Example | Repo | What's shown | Why this pairing |
|---------|------|--------------|------------------|
| A — petclinic | `spring-projects/spring-petclinic` | Trigrep-only — `trigrep_search` and `trigrep_structural_search` for fast exploratory questions. No recipe. | Real, recognizable codebase. Showcases Trigrep as the agent's "fast cut" tool when a recipe would be overkill. |
| B — media | `streamlist/media-aggregator` (from [`media-aggregator-app/`](../media-aggregator-app/)) | Full agent flow — Trigrep + `find_*` for inventory, then escalation to a transformation recipe (migration to `RestClient`). | Curated for predictability — multi-pattern by design (`getForObject`, `getForEntity`, `postForEntity`, `exchange` with custom `HttpHeaders`, `delete`, plus `RestTemplate` inside `@Retryable`) so the recipe diff reads visually. |

Both lanes are Gradle (Maven silently breaks MCP type resolution via the `modmaven-metadata` bug). The `with-trigrep` lane inherits the user-scope `moderne` MCP server (registered via `mod config agent-tools install`); the `no-trigrep` lane uses an `empty-mcp.json` + `--strict-mcp-config` to block MCP inheritance.

After `./demo agent with <repo>`, give the terminal ~15–30 s — MCP tools register progressively as the LST builds. `/mcp` shows status; wait until the Moderne server reports all 18 tools (or autocomplete `mcp__moderne__find_types`). Permissions are auto-skipped by default; pass `--ask` to opt into Claude's normal prompts.

Prompts for both examples live in [prompts.txt](prompts.txt). Keep that file open during rehearsal — copy/paste the prompt for the current turn into claude's input when you're ready to send.

### Example A — petclinic: Trigrep showcase (no recipe)

```bash
./demo agent with petclinic
```

Two simple exploratory prompts, each landing a different Trigrep mode. No recipe escalation — the answer IS the search. CLAUDE.md (user-scope) primes the agent on `struct:"..."` form and the `extends:`/`implements:`/`returns:`/`throws:` LST filters, so the prompts can stay short.

**Prompt 1** — structural search via `trigrep_structural_search`:

```
What exception types does this codebase throw, and what arguments do they take?
```

What you're watching for: the agent reaches for `trigrep_structural_search` with `struct:"throw new :[type](:[args])"`. Different exception types and argument shapes show up — the holes capture the variability.

**Prompt 2** — LST filter via `trigrep_search`:

```
Find every class that directly extends BaseEntity.
```

What you're watching for: the agent reaches for `trigrep_search` with `extends:BaseEntity` (LST-aware filter, direct extenders only — *not* `find_implementations`, which would give transitive results). Returns the small set of classes that directly inherit from BaseEntity. Demonstrates Trigrep's LST-aware filters (`extends:`, `implements:`, `returns:`, `throws:`, `visibility:`) — things grep can't touch.

(The annotations/endpoints example moved to Demo 2's media flow, where the agent uses `find_*` and Trigrep together. No need to repeat the regex-search beat here.)

> Closing line for this example: *"Two questions, two Trigrep modes — structural and LST filter. Both landed without a recipe. Sometimes the search IS the answer."*

### Example B — media: Trigrep first-cut, then transformation-recipe escalation

```bash
./demo reset media           # before each rehearsal
./demo agent with media
```

**Turn 1 prompt** — fast Trigrep inventory:

```
Give me a quick inventory of RestTemplate usage in this repo. Where are
the call sites, what call shapes show up?
```

What you're watching for: agent reaches for `find_types` / `trigrep_search`, returns the inventory.

**Turn 2 prompt** — escalate to a transformation recipe:

```
Now apply the most appropriate migration recipe to convert RestTemplate
to RestClient on the mechanical cases. Stop when those are handled —
leave anything ambiguous untouched and document what was deferred.
```

What you're watching for: agent reaches for `search_recipes` → `learn_recipe` → `run_recipe` → manual edits only where the recipe leaves something unfinished. The diff in the terminal is the closing visual.

> Closing line: *"Same escalation pattern as petclinic, but now the recipe transformed the code instead of just reporting on it. Trigrep plus a recipe can land you anywhere on the search-vs-transform spectrum."*

> Final closing for the talk: *"Same LST, three surfaces. Trigrep is a tool the agent picks up like any other — and the recipe layer is right alongside it."*

---

## Optional beats

These lengthen Demo 2 — use sparingly, only if the spine has landed.

### Trap mode for `media` — "agent fixes what the recipe didn't"

`media-aggregator-app/` ships clean by default — the recipe produces compilable output. If you want a beat where the agent has to fix something the recipe leaves broken, enable trap mode:

```bash
./demo trap enable          # cps a setErrorHandler-using HttpClientConfig
./demo trap status
./demo trap disable         # back to clean
```

With the trap on, the recipe leaves `template.setErrorHandler(...)` in `HttpClientConfig` — but `RestClient` has no `setErrorHandler` method. The agent has to recognize the compile break and convert to `RestClient.builder().defaultStatusHandler(...)` (or document the deferral). Trap mode is fragile across rehearsals (the recipe leaves uncompilable code, which can poison subsequent MCP LST rebuilds), so use `./demo reset media` between runs.

### Side-by-side with `no-trigrep` — token delta

Run the same prompts against the `no-trigrep/` lane (zero MCP servers via `empty-mcp.json` + `--strict-mcp-config`) and put the two sessions side by side. The agent falls back to grep + read-each-file, and the token delta is the number to quote live.

```bash
./demo agent no media        # or `no petclinic`
./demo tokens <session-id>          # run for both sessions, after capturing the IDs
```

**Beefier option — `Netflix/eureka`.** The token delta on `media` and `petclinic` is real but not dramatic — both repos are small enough that grep + read-each-file finishes without much pain. For a more visible delta, provision the optional `eureka` lane:

```bash
./demo init --with-eureka              # one-time: clones into both lanes, builds with-trigrep LST
./demo agent with eureka
./demo agent no eureka
```

`Netflix/eureka` is a multi-module Gradle Java project (the Spring Cloud service-registry library) — recognizable in the Spring world, big enough that the grep-fallback agent reads a lot more files to assemble the same answers. Because it's Gradle, the full MCP toolset works (no Maven `modmaven-metadata` flake).

**Prompt (run identically in both lanes):**

```
If I modify the InstanceInfo class, what other classes and services would be affected?
```

`InstanceInfo` is core eureka — the canonical service-registration metadata class with heavy fan-out across the codebase. A realistic refactor-impact question a platform engineer would actually ask.

What you're watching for in **with-trigrep**: the agent should open with `trigrep_search` to scout (`InstanceInfo` plus possibly LST-flavored filters like `extends:InstanceInfo`), then legitimately escalate to `find_types` for precise type-FQN reference scope. That's the CLAUDE.md "trigrep first, `find_*` only on escalation" policy in action — `find_types` is the right tool here, not a regression. If the agent stops at direct references and doesn't explore transitive impact (call sites of methods that consume `InstanceInfo`), append *"include the transitive impact, not just direct usages"* to force the deeper pass.

What you're watching for in **no-trigrep**: grep on `InstanceInfo`, then read-each-file to disambiguate type references from incidental variable names, then trace through fields/parameters/return types. That's where the token cost piles up — and it's the number to quote live via `./demo tokens <session-id>` for each session.

**Recorded baseline (eureka, same prompt).** A prior measured run, for reference if you can't capture fresh numbers live:

| Metric            | Without Trigrep   | With Trigrep |
|-------------------|-------------------|--------------|
| Total tokens      | ~4.4M (4,388,922) | ~271K (270,959) |
| Tool calls        | 84                | 7            |
| Subagents spawned | 1                 | 0            |
| **Reduction**     |                   | **~16× fewer tokens, ~12× fewer tool calls** |

Treat these as illustrative, not guaranteed — agent behavior varies run to run. Re-measure with `./demo tokens <session-id>` and quote your live numbers; fall back to these if a session goes sideways. See [../CLAUDE.md](../CLAUDE.md) for the measurement context.

---

## Troubleshooting

- **`mod search` returns "No search index"**: LSTs built but trigram indexes weren't. Run `mod postbuild search index <path>`. If you ran `./demo init --skip-index`, that's intentional — run the postbuild live.
- **`mod search` returns nothing (no error)**: LSTs weren't built. Re-run `./demo init` or `mod build <repo>`.
- **`--last-search` errors**: run a `mod search` first in the same working directory; `--last-search` reads from CLI state in `~/.moderne/`.
- **Agent in `with-trigrep/` doesn't use MCP**: confirm user-scope `moderne` MCP is registered (run `mod config agent-tools install`) and that `mod` is on PATH. Re-launch `claude` — MCP servers register at startup.
- **MCP tools show only `build_status`**: give it 15–30 s. Tools register progressively as the MCP server builds the LST internally. Use `/mcp` to check status.
- **Build failure on a working-set clone**: `./demo init --skip-build`, then build the others by hand. The working set is permissive — drop a repo if it costs more than it earns.
