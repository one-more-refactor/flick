# flick_

Speed reading, self-hosted. Words flash one at a time, anchored on their
optimal recognition point — the red letter your eye locks onto so it never has
to move (RSVP with ORP alignment). Comfortable up to 800 WPM.

flick is **guest-first**: visitors read instantly without an account. An
account only adds cross-device sync and streak history. It holds two things
under one umbrella — documents you must get through faster, and books you love
reading. Same engine, same library.

## Features

- RSVP reader with ORP pivot alignment and per-word timing weights
  (punctuation, word length, paragraph breaks) — vsync-locked playback,
  150–800 WPM
- Import: paste, PDF, EPUB, TXT, URL (SSRF-guarded fetch), Kindle
  `My Clippings.txt`
- Guest sessions, email-first auth (password or mailed code), Google/GitHub
  sign-in, generic OIDC SSO (Authentik-tested)
- Stats, streaks, reading sessions; full-text library search; position sync
- Free public-domain catalog embedded in the binary
- Six themes × light/dark, monospace flipper-style UI, i18n (en/de),
  phone-native layout, PWA
- Single binary + one SQLite file. No external services required.

## Self-host quickstart

Prerequisites: [Rust](https://rustup.rs) (stable) and [Bun](https://bun.sh).
SQLite is bundled into the binary — nothing to install.

```sh
git clone https://github.com/one-more-refactor/flick && cd flick
cargo build --release -p flick-server
cd web && bun install && bun run build && cd ..
./target/release/flick-server        # http://localhost:8484
```

That's it. The server finds `web/dist` automatically when run from the repo
root, creates `./data/flick.db` on first start, and runs its own schema
migrations. The whole deployment is one binary, one static directory, and one
SQLite file.

Common knobs (all optional, full table in
[docs/SELF-HOSTING.md](docs/SELF-HOSTING.md)):

```sh
FLICK_ADDR=0.0.0.0:8484          # listen address
FLICK_DATA_DIR=./data            # SQLite + storage
FLICK_PUBLIC_URL=https://flick.example.com   # external URL; https ⇒ Secure cookies
FLICK_WEB_DIST=web/dist          # built web client
FLICK_SMTP_URL=smtps://user:pass@mail:465    # unset ⇒ login codes go to the log
```

For systemd units, reverse proxying, SSO setup, backups, and upgrades, see
**[docs/SELF-HOSTING.md](docs/SELF-HOSTING.md)**.

## Architecture

Contracts-first: [`docs/CONTRACTS.md`](docs/CONTRACTS.md) is the binding
document — the timeline format, HTTP API, config, and design tokens are
specified there, and every component builds against the document, not against
each other's code. Changes go to CONTRACTS.md first, code second.

| Piece | Stack | Role |
|---|---|---|
| `core/` | Rust (`flick-core`) | The engine: tokenize → ORP pivots → timing weights → timeline. Pure logic, no I/O. One implementation, every platform. |
| `server/` | Rust (axum + SQLite) | Accounts (local + OAuth + OIDC), parsing/imports, library, catalog, stats, position sync. Serves the web client. |
| `web/` | Bun + Svelte 5 + Vite + TS | The reader. Plays timelines with a requestAnimationFrame accumulator. |
| later | Swift / Kotlin / TUI | Local-first native clients, same backend, same engine (UniFFI/WASM). |

The reading-timeline model in three sentences: the server parses any source
into a timeline — `[text, orp_index, weight]` per word — produced solely by
`flick-core`. Clients never reimplement engine logic; they play timelines,
computing each word's display time as `weight * (60000 / wpm)`, so changing
WPM never needs a server round-trip. That keeps the engine identical across
web, native, and whatever comes next.

## Development

```sh
# server (terminal 1)
cargo run -p flick-server            # http://localhost:8484

# web (terminal 2)
cd web && bun install && bun dev     # http://localhost:5173, proxies /api → :8484
```

Verify before submitting anything:

```sh
cargo test && cargo clippy --workspace
cd web && bun run check && bun run build
```

Use `bun` (not npm/node) for everything under `web/`. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## Editions

flick ships in two editions, selected by `FLICK_EDITION` (default:
`selfhost`).

- **selfhost** — everything free forever, nothing enforced, no strings
  attached. Where the hosted UI would show Pro, the self-hosted UI shows
  CONTRIBUTE — a link back to this repo. Forking is encouraged.
- **hosted** — the maintainer-run cloud instance, with a paid Pro plan that
  exists to fund this project.

Binding principles (from CONTRACTS.md): what's free stays free — features
never move from free to paid — and there is no lifetime tier, ever. Hosted
revenue funds the open project.

## License & contributions

AGPL-3.0 ([LICENSE](LICENSE)). **No CLA.** Contributions are accepted under
the inbound=outbound rule: you license your contribution under the same AGPL
terms as the project. Since no single party accumulates copyright over the
whole codebase, relicensing to a closed license is impossible by design —
that's a feature, not an oversight.

## Status

v0.4: guest-first reading (no account needed), email-first auth +
Google/GitHub + email codes + generic OIDC, stats/streaks/sessions, free
public-domain catalog, PDF/EPUB/txt/URL/Kindle-clippings import, full-text
library search, six themes × light/dark flicker, i18n (en/de), phone-native
reader, PWA, rate limiting, editions (selfhost/hosted), real URLs with working
back button, WPM ramp on play.

The design reference is [`docs/mockup.html`](docs/mockup.html).
