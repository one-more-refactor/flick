# Security Audit

Audit date: 2026-07-18Branch: `security-audit/2026-07-18`Audited revision: `0e6abab` plus the fixes documented below

## Scope

This is a white-box, source-only audit of the local flick repository. The application is a speed-reading service, not an e-commerce store, so there is no catalog checkout, coupon, stock, payment, or card-data flow to test.

Reviewed components and trust boundaries:

- Rust/Axum HTTP API, routing, extractors, error mapping, static serving, request limits, and tracing.
- Authentication: guest sessions, registration, password login, email codes, logout, account lookup, OAuth/OIDC, session cookies, account export, and erasure.
- Authorization: books, text and timelines, trash/restore/purge, tags, reading positions, sessions/stats, sharing, referrals, friends, wrapped statistics, catalog imports, and admin events.
- Ingestion: paste, TXT, PDF, EPUB, Kindle clippings, client-supplied HTML, URL fetching, redirects, DNS resolution, response limits, and parsing.
- Web client: Svelte interpolation, API calls, service worker behavior, local storage, redirect handling, third-party integrations, and potential unsafe HTML sinks.
- Persistence: SQLite schema, foreign keys, queries, transactions, deletion behavior, retained personal data, and logging.
- Configuration, deployment documentation, CI workflows, dependencies, current files, and Git history for secret patterns.

Dynamic verification used the Axum integration tests and local builds only. No non-local host was scanned or tested.

## Executive summary

**2 confirmed findings: 0 Critical / 0 High / 0 Medium / 2 Low.**

The core security posture is strong. Passwords use Argon2id, login timing uses a dummy hash for unknown accounts, login codes are hashed and attempt-limited, sessions use high-entropy server-side tokens in HttpOnly SameSite cookies, OAuth/OIDC uses state and PKCE, database queries are parameterized, ownership checks consistently scope records to the session user, and URL imports vet every resolved address and redirect while pinning the connection.

Two low-severity hardening gaps were confirmed and fixed: profile avatars accepted active SVG data, and friend-link redemption had neither dedicated throttling nor the same token strength as other bearer links. The suspected IPv4-compatible IPv6 SSRF bypass was specifically tested and ruled out because Rust's `Ipv6Addr::to_ipv4()` recognizes both compatible and mapped forms.

## Findings

| ID | Severity | Scope | Finding | Location | Status |
|---|---|---|---|---|---|
| F-01 | Low | Web/XSS hardening | Avatar validation accepted active SVG data URLs | `server/src/auth.rs:626` | Fixed and verified |
| F-02 | Low | Abuse prevention/access consent | Friend-link redemption lacked dedicated throttling and used 64-bit codes | `server/src/social.rs:30`, `server/src/ratelimit.rs:49` | Fixed and verified |

## Finding details

### F-01: Avatar validation accepted active SVG data URLs

**Severity:** Low**Scope:** Web layer / stored-content hardening**Location:** `server/src/auth.rs:626-635`, `server/src/auth.rs:665-672`**Confidence:** Confirmed

#### Impact

The profile endpoint accepted any string beginning with `data:image/` and containing `;base64,`, including `data:image/svg+xml`. The current Svelte client renders avatars through an `<img>` source, which prevents the demonstrated SVG event handler from executing in current browsers. The stored active document nevertheless created an unnecessary future XSS hazard if reused through an object, embed, direct navigation, download, or inline rendering context.

#### Reproduction

A regression test submitted this authenticated profile update:

```json
{
  "avatar": "data:image/svg+xml;base64,PHN2ZyBvbmxvYWQ9YWxlcnQoMSk+PC9zdmc+"
}
```

Before the fix, `PATCH /api/auth/me` returned `200 OK` and stored the value. The failing test output showed `left: 200`, `right: 400`.

#### Fix

```diff
-fn valid_avatar(data: &str) -> bool {
-    data.len() <= MAX_AVATAR_LEN
-        && data.starts_with("data:image/")
-        && data.contains(";base64,")
-}
+fn valid_avatar(data: &str) -> bool {
+    data.len() <= MAX_AVATAR_LEN
+        && [
+            "data:image/png;base64,",
+            "data:image/jpeg;base64,",
+            "data:image/webp;base64,",
+        ]
+        .iter()
+        .any(|prefix| data.starts_with(prefix))
+}
```

The API contract now explicitly permits only PNG, JPEG, and WebP data URLs and rejects SVG and unsupported image types.

#### Verification

`cargo test -p flick-server --test api avatar_set_and_clear` passes. The test confirms the PNG fixture is accepted, the SVG payload is rejected with `400`, a remote URL is rejected, and clearing the avatar still works. Verified ✅

### F-02: Friend-link redemption lacked dedicated throttling and used 64-bit codes

**Severity:** Low**Scope:** Authorization consent / abuse prevention**Location:** `server/src/social.rs:20-36`, `server/src/social.rs:44-71`, `server/src/ratelimit.rs:49-91`**Confidence:** Confirmed

#### Impact

Possession of a personal friend code is consent to create a mutual relationship that exposes display identity and aggregate reading statistics. Codes contained 64 random bits, but `POST /api/friends/add` was absent from the rate-limit table. An authenticated attacker could make unlimited online guesses and distinguish valid, invalid, and self-owned codes by status. Exhaustive guessing was still impractical, so this is a low-severity defense-in-depth issue rather than an immediate account compromise.

#### Reproduction

Source and route inspection confirmed the handler generated `random_token(8)` and every request reached a database lookup. A dedicated integration test with a two-request test limit demonstrated that the endpoint was not represented in `RateLimits` before the fix; there was no field or route rule capable of producing `429` for friend-code guesses.

#### Fix

```diff
-    let fresh = random_token(8);
+    let fresh = random_token(16);
```

```diff
 pub struct RateLimits {
     ...
     pub import_url: Rule,
+    pub friend_add: Rule,
 }

 impl Default for RateLimits {
     fn default() -> Self {
         RateLimits {
             ...
+            friend_add: Rule::new(30, FIVE_MIN),
         }
     }
 }

 match path {
     ...
+    "/api/friends/add" => Some(("friend_add", self.friend_add)),
 }
```

New friend codes now contain 128 random bits. Existing codes remain valid because redemption does not assume a fixed length. The endpoint is limited to 30 attempts per client IP per five minutes.

#### Verification

- `cargo test -p flick-server --test api friends_scoreboard_and_wrapped` confirms new codes are 32 hex characters and normal connect/unfriend behavior still works.
- `cargo test -p flick-server --test api friend_add_is_rate_limited` confirms two allowed attempts followed by `429 Too Many Requests` under the test rule.

Verified ✅

## Ruled-out items

### Authentication and sessions

- Password hashes use Argon2id through `argon2::Argon2::default()` with a random salt. Password material is not logged or returned.
- Unknown-user password login verifies against a precomputed dummy Argon2 hash, reducing account-existence timing differences.
- Password login, registration, lookup, guest creation, code request, and code verification have per-client limits. Email codes additionally expire after ten minutes, permit five attempts, are single-use, and are stored as SHA-256 hashes.
- Sessions use random server-side tokens, expire in the database, and are delivered with `HttpOnly`, `SameSite=Lax`, `Path=/`, and `Secure` whenever `FLICK_PUBLIC_URL` is HTTPS.
- Account lookup intentionally returns existence and available login methods as part of the specified email-first UX. It is rate-limited; this is a product privacy tradeoff, not an accidental leak.
- OAuth/OIDC uses provider-specific state cookies, constant-time state comparison, nonce verification for OIDC, PKCE, verified issuer/JWKS processing, and verified-email rules before account linking.

### Authorization and IDOR

- Book reads, source text, timelines, position changes, tags, trash, restore, purge, delete, and share creation/revocation consistently include the authenticated user ID in database queries. Integration tests confirm foreign IDs return `404`.
- Stats, reading sessions, account export, account deletion, referrals, friends, and wrapped data derive the subject from the session rather than request-controlled user IDs.
- Admin event routes require a configured bearer token. The admin API is disabled when no token is configured.
- Public share tokens are deliberate bearer capabilities. Read-only mode blocks importing; revocation invalidates preview and import.

### Injection and unsafe parsing

- SQLite values are bound with `rusqlite` parameters. Dynamic SQL only selects fixed internal column names or expressions; no request data is interpolated into SQL syntax.
- No process execution or shell command API is present, ruling out command injection in the reviewed source.
- No unsafe deserialization framework is used. JSON is typed through Serde, and upload parsers receive bounded input.
- Rust memory safety and the 25 MB request/body limits reduce parser memory-corruption and volume risk, though third-party parser defects remain dependency risk.

### XSS, CSRF, CORS, redirects, and service worker

- The Svelte client contains no `{@html}`, `innerHTML`, or equivalent unsafe rendering sink. User content is rendered through escaped interpolation.
- State-changing application routes use non-GET methods. The app is same-origin, sets no permissive CORS headers, and relies on `SameSite=Lax` session cookies, preventing ordinary cross-site credentialed POST/PUT/PATCH/DELETE requests.
- OAuth redirects are generated by configured provider clients. No request-controlled post-login redirect parameter was found.
- The service worker bypasses `/api` and does not cache authenticated API responses.
- Generic security headers were reviewed. The repository security policy explicitly treats headers on bare HTTP deployments as out of scope and the deployment model places TLS/header policy at the reverse proxy. Their absence was not included as a finding.

### URL import and SSRF

- Only HTTP and HTTPS are accepted.
- Every DNS result must be public, the selected connection is pinned to a vetted address to prevent DNS rebinding, automatic redirects are disabled, every redirect target is re-resolved and revalidated, redirects are capped, requests time out, and response bodies are capped.
- Private IPv4, loopback, link-local, CGNAT, reserved ranges, ULA, multicast, documentation ranges, IPv4-mapped IPv6, and IPv4-compatible IPv6 were tested.
- The candidate bypass using `::127.0.0.1` and `::169.254.169.254` was **not exploitable**. Rust's `Ipv6Addr::to_ipv4()` returns the embedded IPv4 address for both compatible and mapped forms, and the existing guard delegates to the IPv4 global-address checks. Regression coverage was added.

### Business logic

- The repository contains no checkout, payment, price, quantity, coupon, inventory, or raw card-data functionality.
- Hosted upload allowance checks and insertion execute under the single SQLite connection mutex, preventing concurrent requests from racing the weekly quota in one process.
- Share imports and catalog seeds intentionally do not consume user upload allowance, matching the contract.

### Secrets and configuration

- Current tracked files and Git patches were searched for common private-key, cloud-token, GitHub-token, Stripe-key, and credentialed-URL patterns.
- Matches were variable names, test placeholders, and documented examples such as `user:password@mail.example.com`; no real secret was confirmed.
- `.env` files and local data directories are excluded by Git ignore rules.
- OAuth, SMTP, picker, and admin credentials are environment-provided rather than hardcoded.

### Error handling and logging

- API errors use a stable JSON shape and do not return Rust backtraces or database internals.
- HTTP tracing records request metadata rather than request or response bodies.
- When SMTP is intentionally unset, email addresses and login codes are logged at info level as the documented local-development delivery mechanism. Operators must configure SMTP in production; no additional secret logging was found.

### GDPR and data handling

- Stored personal data includes account email/name/username/avatar/settings, library source text and reading progress, reading days/sessions, friend links/relationships, OAuth identity subjects, and pseudonymized signup IPs used for referral abuse prevention.
- Passwords are one-way Argon2id hashes; login codes and signup IPs are one-way hashes. Session bearer tokens remain plaintext in SQLite because they must be looked up.
- `GET /api/auth/export` provides profile, content, reading records, sessions, and friend data. `DELETE /api/auth/me` deletes the account and owned data through foreign-key cascades and removes login codes by email.
- There is no application-layer encryption at rest. Protection of the SQLite database and backups depends on host/filesystem controls; this is documented as an operational consideration rather than a confirmed source vulnerability.
- Hosted free accounts expose only the last 90 days of session history, but the current implementation is a visibility window rather than physical retention deletion. A formal backup/database retention schedule remains an operational policy item.

## Dependency audit

### Rust

`cargo audit` could not be executed because `cargo-audit` is not installed, and installation is blocked by the execution environment's command policy. This is a tooling limitation, not a clean vulnerability result.

The lockfile was still inspected and the project was compiled/tested successfully. Notable resolved versions include Axum 0.8.x, Reqwest 0.12.28, RSA 0.9.10, IDNA 1.1.0, Time 0.3.53, and bundled Rusqlite 0.40.1. The GitHub workflow includes dependency auditing, so CI remains the authoritative advisory check. No dependency finding is claimed without a completed advisory database comparison.

### Web

This Bun version does not provide `bun pm audit`; `bun pm scan` requires a separately configured scanner package. Therefore no local advisory result is claimed. The lockfile resolves current package versions, the web project passes type checking and production build, and Dependabot/CI provide ongoing update coverage.

## Verification

The following completed successfully after all fixes:

```text
cargo test
cargo clippy --workspace
cd web && bun run check
cd web && bun run build
```

Targeted regression tests also passed for avatar validation, friend-code entropy and behavior, friend-add throttling, and IPv4-compatible IPv6 SSRF coverage.
