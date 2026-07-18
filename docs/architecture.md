# Architecture

How flick is put together, and how the pieces talk. The binding spec for the
formats and endpoints named here is [CONTRACTS.md](CONTRACTS.md); this document
is the map, that one is the law.

## One contract, many clients

flick is **contracts-first**. [`CONTRACTS.md`](CONTRACTS.md) defines the reading
**timeline** format, the **HTTP API**, **server config**, and the **design
tokens**. The server implements it; every client consumes it; no client
reimplements engine logic. Add a client (browser extension, mobile app) and it
plugs into the same API — the backend doesn't change.

```
one-more-refactor/
├── flick           umbrella — docs, contract, installer, compose, legal   (this repo)
├── flick-backend   Rust — flick-core (engine) + flick-server (axum API)
├── flick-web       Svelte 5 — the reference web client
└── flick-landing   Astro — the marketing site (myflick.app, hosted-only)
```

## Request lifecycle

In production one image serves everything on one origin: the web client at `/`,
the JSON API under `/api`.

```
browser ─▶ GET /                 → flick-server serves the built web client (ServeDir)
        ─▶ POST /api/auth/guest  → mint guest user + session cookie
        ─▶ GET  /api/books       → library JSON  (cookie → AuthUser extractor)
        ─▶ GET  /api/books/:id/timeline → flick-core turns text into a paced timeline
        ─▶ PUT  /api/books/:id/position → checkpoint while reading
```

- **Sessions** are signed cookies; an `AuthUser` extractor resolves the cookie
  to a user (guest or full) on every guarded route.
- **The client never computes pacing.** It requests a *timeline* — a list of
  words with per-word dwell weights and ORP pivots — and plays it with a
  `requestAnimationFrame` accumulator (frame-accurate, no `setTimeout` drift).

## The engine (`flick-core`)

Pure, deterministic, no I/O — which is why it's heavily unit-tested. The
pipeline, per word:

1. **Tokenise** text into words + trailing punctuation.
2. **ORP** — pick the optimal recognition point (the pivot letter) and split the
   word around it so the pivot renders in a fixed column.
3. **Weight** the dwell time from: base WPM, **Zipf frequency** (rarer = longer),
   **length** (graded, with long words split into chunks), and **wrap-up**
   pauses after clause/sentence punctuation.
4. Emit a **timeline**: `[{ pre, pivot, post, ms }, …]`.

Change any of this and you change `CONTRACTS.md` in the same commit.

## Data model

Everything is one **SQLite** database (WAL mode) via `rusqlite` (bundled — no
system SQLite). Schema versions advance through `PRAGMA user_version`
migrations. Core tables:

```
users ──┬─< books ──< (book text, timelines cached)
        ├─< reading_days      (streak + daily goal)
        ├─< sessions_log      (per-read stats)
        ├─< identities        (oauth/oidc links)
        └─< friends
```

Foreign keys cascade on user delete, so **account deletion removes everything**
(GDPR Art. 17). `login_codes` are keyed by email and swept separately.

## How reading syncs

The design goal: reading follows you, and you never *have* to sign up.

```
 guest visit         create account / sign in           read a book
     │                        │                              │
     ▼                        ▼                              ▼
POST /auth/guest      merge_guest_into(user)        PUT /books/:id/position
 cookie + guest        guest's books + progress       every ~5s while playing,
 user row              fold into the account          on pause, on exit
     │                        │                              │
     └──── library + position live server-side, keyed to whoever you are now ──┘
```

1. **Guest** — first visit mints a guest user + cookie. Library and position are
   server-side from the start; a refresh loses nothing.
2. **Merge on auth** — signing up or in from a guest session runs
   `merge_guest_into`, folding the guest's books and progress into the account.
3. **Checkpoint** — the reader `PUT`s position + words-read every ~5 seconds
   while playing (and on pause/exit), so any device resumes at the exact word.

## Editions

`FLICK_EDITION` selects behaviour: `selfhost` (everything free, nothing metered)
or `hosted` (Free tier + Pro on myflick.app). Same binary, same features — the
edition only governs limits and billing surface.

## Deployment

The production image (`flick-backend/deploy/Containerfile`) builds the Svelte
client from `flick-web`, the Rust server from `flick-backend`, and bakes them
into one Debian-slim runtime. On [myflick.app](https://myflick.app) it runs
rootless (Podman + systemd Quadlet) on loopback behind a Cloudflare Tunnel — no
ports exposed. Self-hosters get the same image via [Compose](../docker-compose.yml).
See [SELF-HOSTING.md](SELF-HOSTING.md).
