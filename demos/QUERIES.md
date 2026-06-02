# Query catalog

A curated list of Trigrep queries to draw from when iterating on Demo 1. The sequence at [demo.txt](demo.txt) is the playlist; this file is the bench.

`mod search` needs a path argument first. From `working-set/`, use `.`.

## Tier 1 — Familiar syntax

```bash
mod search . RestTemplate
mod search . @RestController
mod search . @Autowired
mod search . '/Rest(Template|Client|Operations)/'   # alternation across the HTTP-client family
mod search . '/\bRestController\b/'                  # word-anchored — skips RestControllerAdvice, MyRestController
mod search . '/(get|post|put|delete)For\w+/'
mod search . '/@(Get|Post|Put|Delete|Patch)Mapping/'
mod search . sym:RestTemplate
mod search . sym:WebClient
mod search . sym:RestClient
mod search . sym:Owner
mod search . 'sym:/Client$/'
mod search . sym:RestTemplate or sym:WebClient   # disjunction (case-insensitive — `OR` also works)
mod search . @RestController -test               # NOT via `-` prefix
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

Typed holes (per the docs) sharpen what the hole is allowed to match: `:[name:e]` balanced expression, `:[name:id]` identifier, `:[name:g]` generics including angle brackets, `:[name:block]` balanced braces, `:[name:stmt]` to next semicolon. Plain `:[name]` is non-greedy and usually works for argument lists, but `:[args:e]` is safer when args contain nested parens/strings.

```bash
mod search . 'struct:restTemplate.exchange(:[args])'
mod search . 'struct:restTemplate.getForEntity(:[args])'
mod search . 'struct:restTemplate.getForObject(:[args])'
mod search . 'struct:restTemplate.postForEntity(:[args])'
mod search . 'struct:new RestTemplate()'
mod search . 'struct:new RestTemplate(:[args])'
mod search . 'struct:@RequestMapping(:[args])'
mod search . 'struct:@GetMapping(:[args])'
mod search . 'struct:@Autowired :[type:id] :[field:id]'   # field-injection candidates
mod search . 'struct:ResponseEntity<:[type:g]>'           # typed REST responses
mod search . 'struct:@Value(":[expr]") :[type:id] :[field:id]'  # property-injected fields
```

## Tier 4 — Bridge to a recipe (`--last-search`)

```bash
mod search . @RestController
mod run . --last-search --recipe=org.openrewrite.java.search.FindAnnotations \
  -PannotationPattern='@org.springframework.web.bind.annotation.RestController'

mod search . sym:RestTemplate
mod run . --last-search --recipe=org.openrewrite.java.search.FindTypes \
  -PfullyQualifiedTypeName=org.springframework.web.client.RestTemplate
```

## Demo 2 bench — eureka single-repo (agent's Trigrep moves)

For the optional `Netflix/eureka` cost-comparison lane (`./demo init
--with-eureka`). These are the queries the *agent* composes through MCP when
answering "if I modify `InstanceInfo`, what's affected?" — useful to rehearse by
hand so you know what good looks like before watching the agent. Run from
`with-trigrep/Netflix/eureka` with `.` as the path.

```bash
mod search . sym:InstanceInfo                 # central service-registration metadata class
mod search . sym:EurekaClient                 # core client interface
mod search . extends:AbstractInstanceRegistry  # registry implementations (direct extenders)
mod search . visibility:public returns:InstanceInfo   # methods that hand back an InstanceInfo
mod search . throws:IOException               # exception surface across the registry
```

Grep contrast for the talk: `grep -rn "InstanceInfo" .` returns hundreds of hits
— imports, comments, tests, string constants — so a grep-only agent has to read
each file to confirm which are real type references. `sym:InstanceInfo` resolves
to the symbol directly, and `find_types InstanceInfo` (the agent's escalation)
gives FQN-precise reference scope. That skipped read loop is the ~16×-fewer-token
delta recorded in [../CLAUDE.md](../CLAUDE.md).

> Don't reach for a `visibility:public type:method` "public API surface" query
> here — `type:method` is a silent no-op in CLI 4.2.x. Lean on `returns:` /
> `throws:` / `visibility:` as shown above.

## CLI 4.x query rules worth memorizing

- **Filters must be separate shell args** — never quote the whole query into one string. The CLI treats a single-arg query as a literal phrase (it re-emits it quoted in the `Searching for:` line) and almost always returns 0 matches.
  ```
  ✓  mod search . returns:ResponseEntity
  ✗  mod search . 'returns:ResponseEntity'
  ✓  mod search . visibility:public throws:IOException
  ✗  mod search . 'visibility:public throws:IOException'
  ```
- For order-sensitive filters (`type:`, `case:`, `count:`, `patternType:`), the filter must come **before** the term it modifies. `type:symbol Person` filters; `Person type:symbol` is silently equivalent to bare `Person`.
- `type:` accepts only `file` / `path` / `symbol`. `type:method` and `type:annotation` are silent no-ops — use `returns:` / `throws:` for methods and `'"@AnnotationName"'` for annotations.
- `type:symbol Person` is the narrow lens (the `Person` symbol itself); `sym:Person` is a substring match on FQN, so it picks up `PersonRepository` and every method inside `class Person`. Bare `Person` is broader still — also matches imports, comments, string literals.
- Boolean operators: implicit AND between space-separated terms, `or` / `OR` (case-insensitive) for disjunction, leading `-` for NOT. Standalone capitalized `AND` / `NOT` not separately verified in 4.2.x — use the implicit/`-` forms.
- Inner double-quotes around a literal only matter when it would otherwise be misparsed: contains a colon (`'"version:1"'` keeps `version:` from being read as a filter), spans multiple words (`'"hello world"'` vs two ANDed terms), or shadows an operator (`'"or"'` for the literal word, `'"-test"'` to keep the leading dash). For bare alphanumeric tokens, `RestTemplate` and `'"RestTemplate"'` parse identically.
- Path/language filters parse but don't render usefully in CLI 4.2.x. `path:` / `file:` narrow correctly but render file-match mode (first-5-lines preview, no content highlights — even when combined with a content term, which then acts as a file-existence filter rather than a per-line match). `lang:` narrows the candidate set correctly but always renders 0 matches. Pick one of {path/lang filter, content term} per query in this version — combining either loses line highlights (path/file) or zeros the result entirely (lang).
- Recipe options use bare `-PoptionName=value`, not `-Poption.optionName=`.

## A note on `sym:`

`sym:RestTemplate` is substring-on-FQN, so it catches the whole `*RestTemplate*` family — `RestTemplateBuilder`, `OAuth2RestTemplate`, `TestRestTemplate`. That breadth is great for an audit but wider than a strict-name match. To narrow:

- Suffix-anchored regex: `'sym:/RestTemplate$/'` drops the `*Builder` / `*Controller` / `*Config` variants but keeps the prefix family.
- Use `FindTypes` for FQN-precise — that's exactly what the `--last-search` bridge dramatizes.

Fully-anchored `'sym:/^RestTemplate$/'` returns zero in CLI 4.2.x — parser quirk. Don't rely on it.
