# flick — Contracts

The binding document for all flick components. The web client, server, and future
native clients (Swift/Kotlin/TUI) build against THIS, not against each other's code.
Change this file first, code second.

## Product shape

- One Rust backend, many clients (web now; iOS/Android/TUI later).
- Server parses books (paste + PDF for v0.1) into **reading timelines**; clients play them.
- Clients other than web are local-first; web is the thin always-online client.
- Accounts: local email+password AND optional generic OIDC SSO (Authentik first).

## Reading timeline format

Produced by `flick-core`, served by the API, played by every client.

```json
{
  "version": 1,
  "words": [["reading", 3, 1.0], ["fast,", 1, 1.6]],
  "word_count": 2
}
```

- `words[i] = [text, orp_index, weight]` — array-of-arrays to keep payloads small.
- `orp_index`: 0-based index of the pivot (red) letter within `text`.
- `weight`: relative duration multiplier. Client computes per-word display time as
  `weight * (60000 / wpm)` ms. WPM changes never require a server round-trip.

### ORP rule (letters counted on the alphanumeric core of the word)

| core length | orp_index |
|---|---|
| ≤1 | 0 |
| 2–5 | 1 |
| 6–9 | 2 |
| 10–13 | 3 |
| ≥14 | 4 |

`orp_index` is relative to the full `text` (including leading punctuation, e.g. `"(word"` → pivot on `o` = index 2).

### Weight rules (multiplicative, applied in this order)

- base `1.0`
- core length > 8 → `×1.3`
- ends with `, ; :` → `×1.6`
- ends with `. ! ?` (or closing quote/bracket after one) → `×2.1`
- last word before a paragraph break → `×2.6` **instead of** the sentence multiplier (not stacked)

Round weight to 2 decimals.

## HTTP API

Base path `/api`. JSON unless noted. Auth via `flick_session` HttpOnly cookie
(SameSite=Lax, Secure behind TLS). Errors: `{"error": "human readable message"}`
with appropriate 4xx/5xx status.

### Auth

| Method & path | Body | Response |
|---|---|---|
| `POST /api/auth/register` | `{email, password, name}` | `201 {user}` + session cookie |
| `POST /api/auth/login` | `{email, password}` | `200 {user}` + session cookie |
| `POST /api/auth/logout` | — | `204`, clears cookie |
| `GET /api/auth/me` | — | `200 {user}` or `401` |
| `GET /api/auth/providers` | — | `200 {"oidc": {"enabled": bool, "name": "Authentik"}}` |
| `GET /api/auth/oidc/login` | — | `302` to IdP (or `404` if not configured) |
| `GET /api/auth/oidc/callback` | — | sets session, `302 /` |

`user = {"id": "...", "email": "...", "name": "..."}`. Passwords: argon2id.
OIDC users are matched/created by `sub` claim; email collision with a local
account links the accounts (same user row gains `oidc_sub`).

### Books

| Method & path | Body | Response |
|---|---|---|
| `GET /api/books` | — | `200 [{id, title, source, word_count, position, created_at}]` |
| `POST /api/books` | JSON `{title?, text}` **or** multipart `file` (PDF, field name `file`, optional `title` field) | `201 {book}` |
| `GET /api/books/:id` | — | `200 {book}` |
| `GET /api/books/:id/timeline` | — | `200` timeline JSON (format above) |
| `PUT /api/books/:id/position` | `{position: int}` | `204` |
| `DELETE /api/books/:id` | — | `204` |

- `source`: `"paste"` or `"pdf"`.
- `position`: 0-based word index of reading progress; clients send it on pause/exit and periodically (~ every 5s while playing).
- Paste with no `title`: server uses first ~40 chars of text.
- All book routes are scoped to the session user; foreign ids → `404`.
- Upload limit: 25 MB. Non-PDF uploads → `400`.

## Server config (env)

| Var | Meaning | Default |
|---|---|---|
| `FLICK_ADDR` | listen address | `0.0.0.0:8484` |
| `FLICK_DATA_DIR` | SQLite + storage dir | `./data` |
| `FLICK_PUBLIC_URL` | external base URL (OIDC redirects) | `http://localhost:8484` |
| `FLICK_WEB_DIST` | built web client dir to serve statically | `../web/dist` |
| `FLICK_OIDC_ISSUER` | OIDC issuer URL (enables SSO when set) | — |
| `FLICK_OIDC_CLIENT_ID` / `FLICK_OIDC_CLIENT_SECRET` | OIDC client creds | — |
| `FLICK_OIDC_NAME` | SSO button label | `SSO` |

SPA fallback: unknown non-`/api` GET paths serve `index.html` from `FLICK_WEB_DIST`.

## Design tokens (see docs/mockup.html for the living reference)

| Token | Light | Dark |
|---|---|---|
| bg | `#FAFAF7` | `#0B0A0A` |
| ink | `#141110` | `#F2EFEC` |
| red (only accent) | `#E02D2D` | `#F53B30` |
| dim (warm grey) | `#8A8380` | `#7D7672` |
| line | `#E4E0DC` | `#242020` |
| panel | `#FFFFFE` | `#121010` |

- Monospace everywhere (`ui-monospace, "JetBrains Mono", "Cascadia Mono", "SF Mono", Menlo, Consolas, monospace`).
- Red is the ONLY accent: pivot letter, counters, progress, selection marker. No other colors.
- Square corners, 1px hairline borders, uppercase letter-spaced labels.
- Library = flipper-style: index numbers, all-caps titles, dotted leaders, red progress %, inverse-video selection.
- Reader = clean instrument: guide rails + red notches, big centered ORP word, red pivot.
- Both themes; `prefers-color-scheme` + `data-theme` override, token-level (see mockup CSS).
- Wordmark: `FLICK_` with blinking red cursor.

## Reader playback (client behavior)

- Scheduler MUST be vsync-locked (requestAnimationFrame accumulator on web; CADisplayLink/Choreographer native), never bare setTimeout chains — target smooth 150–800+ WPM on 60/90/120 Hz screens.
- Word advance: accumulate frame delta; when elapsed ≥ current word's `weight * 60000/wpm`, advance (carry remainder).
- Controls: play/pause (Space), back/forward one sentence (←/→), WPM slider (150–800, step 25).
- Respect `prefers-reduced-motion`: never autoplay.
