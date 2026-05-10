# Query catalog

A curated list of Trigrep queries to draw from when iterating on Demo 1. The sequence at [sequences/demo1.txt](sequences/demo1.txt) is the playlist; this file is the bench.

`mod search` needs a path argument first. From `multi-repo/`, use `.`.

## Tier 1 — Familiar syntax

```bash
mod search . '"RestTemplate"'
mod search . '"@RestController"'
mod search . '/RestTemplate\w*/'
mod search . '/(get|post|put|delete)For\w+/'
mod search . sym:RestTemplate
mod search . sym:WebClient
mod search . sym:RestClient
mod search . sym:Owner
mod search . 'sym:/Client$/'
```

## Tier 2 — Semantic filters

```bash
mod search . returns:ResponseEntity
mod search . visibility:public returns:ResponseEntity
mod search . throws:IOException
mod search . visibility:public throws:IOException
mod search . returns:Mono
mod search . returns:Flux
mod search . implements:Repository
mod search . extends:RestTemplate
```

## Tier 3 — Structural search (`struct:` / Comby)

`:[hole]` matches balanced delimiters (parens, braces, strings). Templates are whitespace-sensitive between literal tokens — if a query returns zero matches, try collapsing spaces around braces.

```bash
mod search . 'struct:restTemplate.exchange(:[args])'
mod search . 'struct:restTemplate.getForEntity(:[args])'
mod search . 'struct:restTemplate.getForObject(:[args])'
mod search . 'struct:restTemplate.postForEntity(:[args])'
mod search . 'struct:new RestTemplate()'
mod search . 'struct:new RestTemplate(:[args])'
mod search . 'struct:@RequestMapping(:[args])'
mod search . 'struct:@GetMapping(:[args])'
```

## Tier 4 — Bridge to a recipe (`--last-search`)

```bash
mod search . '"@RestController"'
mod run . --last-search --recipe=org.openrewrite.java.search.FindAnnotations \
  -PannotationPattern='@org.springframework.web.bind.annotation.RestController'

mod search . sym:RestTemplate
mod run . --last-search --recipe=org.openrewrite.java.search.FindTypes \
  -PfullyQualifiedTypeName=org.springframework.web.client.RestTemplate
```

## CLI 4.x query rules worth memorizing

- **Filters must be separate shell args** — never quote the whole query into one string.
  ```
  ✓  mod search . returns:ResponseEntity
  ✗  mod search . 'returns:ResponseEntity'
  ```
- **For `type:symbol` with a bareword, the filter must come first** — and even then it's flaky. Prefer `sym:Foo`.
- `type:method` is a silent no-op. Use `returns:` / `throws:` directly.
- `AND` / `OR` / `NOT` and `file:` / `path:` / `lang:` are not parsed.
- Quote Sourcegraph literals: `'"RestTemplate"'`. Without quotes, they're parsed as field expressions.
- Recipe options use bare `-PoptionName=value`, not `-Poption.optionName=`.

## A note on `sym:`

`sym:RestTemplate` is substring-on-FQN, so it catches the whole `*RestTemplate*` family — `RestTemplateBuilder`, `OAuth2RestTemplate`, `TestRestTemplate`. That breadth is great for an audit but wider than a strict-name match. To narrow:

- Suffix-anchored regex: `'sym:/RestTemplate$/'` drops the `*Builder` / `*Controller` / `*Config` variants but keeps the prefix family.
- Use `FindTypes` for FQN-precise — that's exactly what the `--last-search` bridge dramatizes.

Fully-anchored `'sym:/^RestTemplate$/'` returns zero in CLI 4.2.x — parser quirk. Don't rely on it.
