# Optional demo variants

## `HttpClientConfig.with-trap.java` — recipe-leaves-broken-code variant

The default `media-aggregator-app/src/main/java/com/streamlist/media/config/HttpClientConfig.java`
declares two plain `RestTemplate` beans. After the migration recipe runs,
the post-recipe code compiles cleanly. That's the **default**, and it's
what you want for repeatable rehearsals.

This file is the optional **trap variant**. The second bean attaches a
custom `ResponseErrorHandler`:

```java
template.setErrorHandler(new ProviderErrorHandler());
```

`RestClient` has no `setErrorHandler` method, so after the migration recipe
runs, that line won't compile. The narrative beat is "agent ran the recipe,
recipe got 95% right, and the agent identifies + fixes the remaining bit
(replacing it with `RestClient.builder().defaultStatusHandler(...)`)."

## How to enable the trap for a rehearsal / take

From the demo root, use `trap-mode.sh`:

```bash
./demo trap status         # report current state of both lanes
./demo trap enable         # reset to clean, swap in trap, rebuild LST + index
./demo trap disable        # restore clean state (= ./demo reset media)
```

Then launch as usual: `./demo start with media --yolo`.

## Why this isn't the default

After running the recipe in trap mode, the source has a real compile error.
If the `mod mcp` server tries to rebuild the LST mid-session (or on the
next session before you reset), `compileJava` fails, `GradleBuildStep2`
falls back to `ResourceBuild`, and every `.java` file gets re-tagged as
`PlainText`. Type-aware MCP tools then return 0 / nothing. So:

- **Trap mode is fine for a single take.** Recipe runs once, agent fixes
  it, demo ends, reset, done.
- **Trap mode is fragile across sessions.** If anything triggers an LST
  rebuild between the recipe step and the fix step, the lane is poisoned
  until the source compiles again.

The default (clean) version sidesteps this entirely, at the cost of one
narrative beat ("agent fills what the recipe missed").
