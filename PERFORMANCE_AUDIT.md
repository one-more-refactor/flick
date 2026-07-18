# Performance Audit

Audit date: 2026-07-18

## Scope

Reviewed the Rust reading engine, Axum API, SQLite persistence, ingestion and catalog paths, Svelte client boot flow, reader scheduling, library operations, static asset delivery, service worker, and production bundle output. Measurements used local builds and integration tests only.

## Executive summary

The application is compact and generally efficient: the web production output is approximately 304 KB on disk, Rust parsing is performed once at ingestion, reader scheduling uses the required requestAnimationFrame accumulator, and database access is moved off Tokio worker threads.

Three material performance areas were confirmed:

| ID | Priority | Finding | Location | Status |
|---|---|---|---|---|
| P-01 | High | Large JSON timelines were transferred without HTTP compression | `server/src/lib.rs`, `server/src/books.rs` | Fixed and verified |
| P-02 | High | One SQLite connection serializes all reads and writes | `server/src/db.rs:271-289` | Confirmed, architectural follow-up |
| P-03 | Medium | Bulk library actions make sequential round trips | `web/src/lib/Library.svelte:78-110` | Confirmed, API follow-up |

## Baseline build

```text
HTML                        2.12 KB, 0.91 KB gzip
CSS                        67.85 KB, 12.73 KB gzip
Main JavaScript           184.80 KB, 64.14 KB gzip
Motion chunk                1.17 KB, 0.53 KB gzip
Total dist                    304 KB on disk
```

## Findings

### P-01: Large JSON timelines were transferred without HTTP compression

**Priority:** High

Timeline responses are stored and returned as JSON blobs. Real books produce highly repetitive, multi-megabyte payloads, but the Axum stack had no compression layer and did not honor `Accept-Encoding`. This increased transfer time, data usage, and time before reader startup.

#### Fix

Enabled Tower HTTP Brotli and gzip response compression globally. Compression negotiation now applies to large API JSON and static text responses while the middleware's size/content heuristics avoid compressing tiny or unsuitable bodies.

```diff
-tower-http = { version = "0.6", features = ["fs", "trace"] }
+tower-http = { version = "0.6", features = ["compression-br", "compression-gzip", "fs", "trace"] }
```

```diff
 router
+    .layer(CompressionLayer::new())
     .layer(...)
```

#### Verification

The integration suite now creates a realistic repetitive timeline, requests it with `Accept-Encoding: gzip`, and asserts `Content-Encoding: gzip`. The normal uncompressed JSON parsing path remains covered.

Verified.

### P-02: One SQLite connection serializes all reads and writes

**Priority:** High

`Db` stores one `rusqlite::Connection` behind a mutex. Every operation enters `spawn_blocking` and then waits for that same mutex. A large timeline fetch, catalog warm-up, account export, or import transaction can therefore delay unrelated stats, authentication, and book-list reads.

This is safe and simple, and WAL is already compatible with multiple readers, but it limits throughput and increases tail latency under concurrent use.

#### Recommendation

Introduce a small bounded connection pool with separate read connections and a serialized write path. Preserve transaction boundaries and SQLite busy timeouts. Before changing architecture, add lock-wait and query-duration tracing and benchmark mixed workloads:

- timeline reads plus stats requests;
- imports plus authentication requests;
- catalog cold start plus guest creation.

This was not changed during the audit because connection pooling affects every persistence call and warrants dedicated load tests.

### P-03: Bulk library actions make sequential round trips

**Priority:** Medium

Bulk trash and bulk tag operations await one API request at a time. Selecting 50 books creates 50 serialized network round trips and repeated database closures, then reloads the entire library.

#### Recommendation

Add authenticated bulk endpoints accepting bounded ID arrays and execute each operation in one transaction. Return per-ID outcomes so partial failures remain visible. Client-side `Promise.all` alone would reduce wall time but increase contention on the single database connection, so a server-side batch is the preferred root fix.

## Additional observations

### Client boot request fan-out

App startup requests metadata and active events while authentication is resolved. After adoption it fetches stats and referral status. The public requests are independent and already start without blocking the session request, but the initial UI remains in the boot state until `/auth/me` resolves. A lightweight skeleton would improve perceived latency on slow networks without changing request count.

### Authentication response query cost

The user JSON computes current weekly uploads and hosted Pro/event status. This is correct live data, but hosted `/auth/me` can require multiple serialized database calls. Consider returning stable identity/settings first and refreshing usage/referral chips separately if production traces show boot latency.

### Search response bounds

Full-text search has no explicit result limit. Common terms in a large library can return every matching book summary. Add pagination or a conservative limit before libraries routinely exceed hundreds of items.

### Immutable timeline caching

Timelines do not change after ingestion, but authenticated timeline URLs use user-scoped access and generic API no-cache behavior. Conditional requests with user-specific ETags could avoid retransfers without making private data publicly cacheable. Service-worker caching of authenticated content was intentionally not recommended because it changes local privacy and logout semantics.

### Reader runtime

The main reader correctly uses a requestAnimationFrame accumulator and advances reactive state only when accumulated duration crosses a word boundary. Expensive work is bounded to displayed-word changes rather than every frame. Reduced motion suppresses autoplay. No confirmed reader-loop regression was found.

### Core tokenizer

Tokenization allocates intermediate character vectors and strings for Unicode-safe ORP, splitting, and weighting. This occurs at ingestion rather than playback. Optimization should be driven by a criterion/flamegraph benchmark on representative English, German compound-heavy, PDF, and EPUB inputs; speculative rewrites risk correctness in the source-of-truth engine.

### Catalog cold start

The first uncached catalog request or first seeded user can compute bundled timelines while holding the database connection. Subsequent requests use the catalog cache. Prewarming at controlled server startup could remove the first-user latency if production measurements show it is visible.

## Ruled-out items

- The reader uses requestAnimationFrame accumulation rather than timeout chains.
- Book and timeline requests on reader navigation already run concurrently through `Promise.all`.
- Static hashed assets receive immutable caching headers.
- Service-worker static caching is cache-first and does not accidentally cache private API data.
- URL fetches have time, redirect, and body-size bounds.
- Upload size is capped at 25 MB.
- Svelte keyed lists avoid wholesale DOM replacement for stable book IDs.
- The app bundle has no large third-party runtime beyond Svelte.

## Recommendations

1. Add mixed-workload latency benchmarks before introducing a SQLite pool.
2. Implement transaction-backed bulk trash and tag endpoints.
3. Add pagination or limits to full-text search.
4. Add private conditional caching for immutable timelines.
5. Add server timing metrics for database wait, query execution, ingestion parsing, and response serialization.
6. Establish bundle budgets around the current 64.14 KB gzip main JavaScript and 12.73 KB gzip CSS.

## Verification

```text
cargo test
cargo clippy --workspace
cd web && bun run check
cd web && bun run build
```

The targeted compression regression and the full project verification pass.
