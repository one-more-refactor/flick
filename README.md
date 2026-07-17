# flick_

Speed reading, everywhere. One Rust backend, many thin clients.

Words flash one at a time, anchored on their optimal recognition point — the red
letter your eye locks onto so it never has to move. Comfortable up to 800 WPM.

## Status

v0.3 shipped: guest-first reading (no account needed), email-first auth +
Google/GitHub + email codes, stats/streaks/sessions, free public-domain
catalog, PDF/EPUB/txt/URL/Kindle-clippings import, full-text library search,
six themes × light/dark flicker, i18n (en/de), phone-native reader, PWA.

## Architecture

| Piece | Stack | Role |
|---|---|---|
| `core/` | Rust (`flick-core`) | The shared engine: tokenize → ORP pivots → timing weights → timeline. One implementation, every platform. |
| `server/` | Rust (axum, SQLite) | Accounts (local + OIDC SSO), book parsing (paste/PDF), library, position sync. Serves the web client. |
| `web/` | Bun + Svelte 5 + Vite | The reader. Plays timelines vsync-locked. |
| later | Swift / Kotlin / Rust TUI | Native local-first clients, same backend, same engine (via UniFFI/WASM). |

The binding contract between all pieces lives in [`docs/CONTRACTS.md`](docs/CONTRACTS.md).
The design reference is [`docs/mockup.html`](docs/mockup.html).

## Dev

```sh
# server (terminal 1)
cargo run -p flick-server            # http://localhost:8484

# web (terminal 2)
cd web && bun install && bun dev     # http://localhost:5173, proxies /api → :8484
```

## Deploy (single binary + static dir)

```sh
cargo build --release -p flick-server
cd web && bun install && bun run build
FLICK_WEB_DIST=web/dist ./target/release/flick-server
```

SSO: set `FLICK_OIDC_ISSUER`, `FLICK_OIDC_CLIENT_ID`, `FLICK_OIDC_CLIENT_SECRET`
(and `FLICK_PUBLIC_URL`) to enable the SSO login button. Works with Authentik or
any OIDC provider.
