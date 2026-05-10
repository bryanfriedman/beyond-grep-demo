# streamlist/media-aggregator

Backend service that aggregates streaming-media metadata across multiple
upstream providers. Given a title or media ID, it fans out to TMDB-, IMDB-,
and Trakt-style providers, merges the results, and returns a single
`MediaInfo` response. Also exposes a `POST /api/corrections` endpoint for
client-reported metadata fixes and a ratings lookup with retry semantics.

## Endpoints

- `GET /api/media/{id}` — full metadata for a single title.
- `GET /api/media/search?q=<query>` — multi-provider search.
- `GET /api/media/{id}/ratings` — aggregated ratings (uses retry).
- `POST /api/corrections` — submit a metadata correction.

## Stack

- Spring Boot 3.5.x
- Java 21
- HTTP via `RestTemplate` (today). Modernization to `RestClient` is the
  open work item.

## Build

```bash
./gradlew build
```
