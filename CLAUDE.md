# Trigrep demo project

Maintainer context for the **Beyond grep** demo set — the Trigrep demos.

## Goal

Demo materials for the talk *Beyond grep: how semantic code search makes
large-scale change safer*. The through-line: **code change at scale needs more
than grep.** Recipes are precise but require knowing what to change; text search
is fast but text-only. Moderne builds both on the same LST substrate, so they
compose — search narrows, a recipe acts, no re-parsing, and an agent picks up
the same tools the same way.

Two demos, same handoff pattern, different surfaces:

1. **Demo 1 — Trigrep CLI across a working set.** Human/portfolio workflow.
   Two climbs (Item inventory, javax → jakarta migration), each ending in a
   `--last-search` recipe handoff — one a search recipe, one a transformation.
2. **Demo 2 — agent with Trigrep MCP on a single repo.** Agent workflow.
   The agent picks tools by question: Trigrep alone for fast exploration
   (petclinic), or the full inventory-then-recipe flow (media). An optional
   eureka lane drives the no-trigrep vs with-trigrep cost comparison.

## Trigrep basics

Trigrep is Moderne's indexed code search. It runs against pre-built trigram
indexes derived from LSTs (not raw source), so it's fast and it understands code
structure. Access it via `mod search` on the CLI or through MCP for agents
(`trigrep_search`, `trigrep_structural_search`, plus the `find_*` LST tools).

Supported semantic filters: `extends:`, `implements:`, `visibility:`,
`throws:`, `returns:`, and `type:symbol`. Query syntax is intentionally similar to 
Sourcegraph/Zoekt (literal, regex, symbol search), with the semantic filters as
the LST-powered additions those tools can't do.

## Two use cases — keep these separate

**Multi-repo CLI** (`mod search` across a working set): human/portfolio
workflow. Search across many repos; `--last-search` narrows the subsequent
recipe run to only the repos that matched. Value = portfolio-scale search +
bridge from fast search to precise recipe execution.

**Single-repo MCP** (agent uses Trigrep instead of grep): agent workflow. The
agent calls Trigrep through MCP while working in one repo. Value = it eliminates
the read loop. The token savings isn't in the search call — it's in the file
reads the agent never has to make.

These are different workflows with different value props. Don't conflate them in
the narrative.

## Constraints

- All repos must be publicly accessible (Moderne public instance uses open
  source repos).
- The single repo for the MCP demo must be **Gradle-based**. Maven repos hit a
  `modmaven-metadata` bug in `mod mcp` that silently breaks type resolution —
  the agent's `find_*` tools fall back to PlainText and stop resolving types.
  All three Demo 2 lanes (media, petclinic, eureka) are Gradle for this reason.
- The Trigrep UI on the platform may or may not be available. Don't depend on it.

## Repo selections

**Working set** (Demo 1, [repos.csv](repos.csv)): 4 diverse Spring microservice
repos — `spring-petclinic/spring-petclinic-microservices`, `sqshq/piggymetrics`,
`macrozheng/mall`, `ewolff/microservice`. Chosen so the two climbs both have a
visible payoff: `ewolff/microservice` owns the catalog `Item` type (Section 1),
and javax imports live in 3 of the 4 repos — petclinic-microservices already
migrated to jakarta and gets silently skipped, which is the `--last-search`
"only the repos that matched" beat (Section 2).

> The `sym:Vet` symbol-disambiguation contrast (~180 matches vs ~16k grep lines)
> needs a petclinic repo in the working set. It lives in QUERIES.md as an
> optional tier — add `spring-projects/spring-petclinic` to repos.csv to run it
> live.

**Single repos** (Demo 2): `streamlist/media-aggregator` (curated, from
[`media-aggregator-app/`](media-aggregator-app/)) and
`spring-projects/spring-petclinic`, both provisioned by default into the
`no-trigrep/` and `with-trigrep/` lanes. `Netflix/eureka` is the opt-in third
lane (`./demo init --with-eureka`) for the cost comparison — see below.

## Measured cost comparison (eureka, reference baseline)

The no-trigrep vs with-trigrep delta was measured on `Netflix/eureka` (Gradle,
~409 Java files) with the prompt *"If I modify the InstanceInfo class, what other
classes and services would be affected?"*:

| Metric            | Without Trigrep | With Trigrep |
|-------------------|-----------------|--------------|
| Total tokens      | ~4.4M (4,388,922) | ~271K (270,959) |
| Tool calls        | 84              | 7            |
| Subagents spawned | 1               | 0            |
| **Reduction**     |                 | **~16× fewer tokens, ~12× fewer tool calls** |

These are a recorded reference point, not a guarantee — re-measure live with
`./demo tokens <session-id>`. The delta is far more dramatic on eureka than on
media/petclinic, where grep + read-each-file finishes without much pain; that's
why eureka is the recommended lane when the cost story is the point.