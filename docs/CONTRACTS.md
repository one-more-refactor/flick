# flick — Contracts

The binding document for all flick components. The web client, server, and future
native clients (Swift/Kotlin/TUI) build against THIS, not against each other's code.
Change this file first, code second.

## Product shape

- One Rust backend, many clients (web now; iOS/Android/TUI later).
- flick holds **two things under one umbrella: documents and books** — stuff you
  must get through faster, and stuff you love reading. Same engine, same library.
- Server parses reading material into **reading timelines**; clients play them.
- Clients other than web are local-first; web is the thin always-online client.
- **No account required.** Visitors read instantly as guests (server-backed
  anonymous session); an account only adds cross-device sync + streaks history.
  Never pressure toward signup.
- Accounts: email-first flow (password or email code), Google/GitHub OAuth, and
  generic OIDC SSO (Authentik first).

### Editions & plans (v0.4)

flick ships in two **editions**, selected by env `FLICK_EDITION`
(`selfhost` — the default — or `hosted`):

- **selfhost**: everything free forever, nothing enforced, no strings. Where
  the hosted UI shows Pro, the self-hosted UI shows **CONTRIBUTE** — a link to
  the GitHub repo. Forking encouraged. Developers are a primary audience.
- **hosted** (flick.cr3do.net and future cloud): the plans below apply.

**Binding principles:** what's free stays free — features never move from free
to Pro. **No lifetime tier, ever** (a lifetime price on an everyday habit
product with ongoing storage costs is dishonest pyramid economics). Pro is
framed as supporting an indie open-source project, not as a paywall.

| hosted edition | FREE (€0) | PRO (€4/month · €36/year) |
|---|---|---|
| Reader, engine, all themes, stats, streaks, guest mode, sync, search, shelf | ✓ | ✓ |
| All import formats (paste / PDF / EPUB / TXT / clippings / URL) | ✓ | ✓ |
| Storage | **uncapped** | uncapped |
| Uploads per week | **15** | unlimited |
| Cloud imports (Dropbox / OneDrive / Kindle), when they land | — | ✓ |
| Extension auto-capture library, when it lands | — | ✓ |

- The weekly upload counter covers user-sourced ingestion (paste, file, URL,
  extension HTML). Catalog adds and the intro book never count. Week =
  ISO-8601 week, UTC. Exceeding → `403 {"error": …, "code": "upload_limit"}`.
  Existing content is never deleted or locked.
- `users.plan`: `"free"` (default) or `"pro"`. No API can set it (manual/admin
  only until billing exists). Pro is shown as **SOON** in the hosted UI.
- The user JSON gains `"uploads": {"used": n, "limit": 15 | null}` (`null` =
  unlimited: selfhost edition or pro plan).
- `GET /api/meta` (public, no auth): `{"edition": "selfhost" | "hosted",
  "version": "<crate version>"}` — clients switch Pro/Contribute on this.

## Reading timeline format

Produced by `flick-core`, served by the API, played by every client.

```json
{
  "version": 1,
  "words": [["reading", 2, 1.06], ["fast,", 1, 1.38]],
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

### Weight model v2 (engine v2, flick-core ≥ 0.5 — research-grounded)

Every token's raw weight is the product of four factors (each grounded in
eye-movement research: word-length and word-frequency effects on fixation
durations, clause/sentence wrap-up effects, and the extra cost of digits):

1. **Length** `L = 1 + 0.055 × max(0, n − 6)` where `n` = alphanumeric core
   length in chars (graded, no cliff; capped by long-word splitting below).
2. **Frequency** `F` from embedded Zipf tables (top-20k per language,
   OpenSubtitles-derived FrequencyWords data, CC-BY-SA-4.0 — see NOTICE;
   document
   language auto-detected en/de by function-word sampling):
   `zipf ≥ 6 → 0.85 · 5–6 → 0.92 · 4–5 → 1.00 · 3.5–4 → 1.12 ·
   known < 3.5 → 1.22`. Unknown words: `1.28`; unknown but capitalized
   (proper nouns) `1.12`; unknown with core ≤ 3 chars `1.0`.
3. **Kind** `K`: contains a digit `×1.5` (numerals draw 2.5–7× more
   fixations than words); all-caps core of ≥2 chars (acronyms) `×1.18`
   (all-caps reads 10–20% slower, Tinker); internal hyphen `×1.08`.
4. **Wrap-up** `P` (not stacked; first match wins): paragraph-final `×2.8`;
   sentence-final `.!?…` incl. before closing quotes/brackets `×1.9`, or
   `×2.3` when the sentence ran longer than 7 words (wrap-up scales with
   sentence length — Tiffin-Richards & Schröder 2018, Spritz patent);
   clause-final `,;:` or `—` `×1.5`.
5. **Spillover** `S`: the word after a rare one (`F ≥ 1.22`) gets `×1.06`
   (Rayner & Duffy 1986); resets at sentence boundaries.

Then, per document: clamp raw weights to `[0.45, 3.4]`; when the timeline has
≥ 20 entries, divide every weight by the document mean (**wpm honesty**: the
mean weight is exactly 1.0, so N words at `wpm` take `N/wpm` minutes and
"min left" estimates are exact — the wpm dial is true throughput, not a
vibe); clamp again to `[0.4, 3.6]` and round to 2 decimals.

**Long-word splitting** (Spritz-style, essential for German compounds):
alphanumeric cores > 14 chars are displayed as chunks of ≤ 10 chars, all but
the last suffixed `-`, split preferably after a vowel near the chunk cap.
Each chunk is its own timeline entry with its own ORP and weight; trailing
punctuation (and the wrap-up factor) belongs to the last chunk; leading
punctuation to the first. `paragraphs()` applies the identical split, so the
flattened-text ↔ timeline 1:1 mapping still holds.

The timeline JSON format is unchanged (`version: 1`);
`flick_core::ENGINE_VERSION = 2`. Existing stored timelines keep playing —
the engine runs at ingestion time only.

## HTTP API

Base path `/api`. JSON unless noted. Auth via `flick_session` HttpOnly cookie
(SameSite=Lax, Secure behind TLS). Errors: `{"error": "human readable message"}`
with appropriate 4xx/5xx status.

### Auth — email-first flow (v0.3)

The client never shows a login-vs-register choice. One screen: email field +
provider buttons. `lookup` decides what happens next.

| Method & path | Body | Response |
|---|---|---|
| `POST /api/auth/guest` | — | `201 {user}` + session cookie (anonymous user, `guest: true`) |
| `POST /api/auth/lookup` | `{email}` | `200 {exists: bool, methods: ["password", "code", ...providers linked]}` |
| `POST /api/auth/register` | `{email, password, name?}` | `201 {user}` + session cookie |
| `POST /api/auth/login` | `{email, password}` | `200 {user}` + session cookie |
| `POST /api/auth/code/request` | `{email}` | `204` — emails a 6-digit login code (existing accounts only; silent `204` regardless) |
| `POST /api/auth/code/verify` | `{email, code}` | `200 {user}` + session (10-min expiry, 5 attempts, single-use) |
| `POST /api/auth/logout` | — | `204`, clears cookie |
| `GET /api/auth/me` | — | `200 {user}` or `401` |
| `GET /api/auth/providers` | — | `200 {"providers": [{id: "google"|"github"|"oidc", name}]}` (only configured ones) |
| `GET /api/auth/oauth/:provider/login` | — | `302` to provider (`404` unknown/unconfigured) |
| `GET /api/auth/oauth/:provider/callback` | — | sets session, `302 /` |

```json
user = {
  "id": "...", "email": "..." | null, "name": "...",
  "username": "phil" | null,
  "guest": false,
  "onboarded": false,
  "settings": {"wpm": 350, "theme": "auto", "accent": "red", "lang": "auto"}
}
```

Client flow: email entered → `lookup` → not found ⇒ registration panel (password
+ optional name) then onboarding (skippable); found ⇒ password field + the
account's other methods (email code always; linked SSO buttons). SMS codes are
future work (needs phone numbers + an SMS provider) — the `methods` array is
already shaped for it.

**Guests.** `POST /api/auth/guest` is called lazily the first time an
unauthenticated visitor adds/opens a book. A guest is a real user row
(`guest: true`, `email: null`) — books, positions, stats and settings all work.
When a guest registers or logs in **with the guest session cookie still
present**, the guest's books and stats merge into the target account (guest row
is deleted; on id collision existing account data wins). Since v0.4.1 guests
are seeded with the full starter library at creation (see Starter library);
the lazy seed-on-first-add path remains only as a backstop for pre-v0.4.1
guest rows that are still empty.

**Providers.** Local passwords: argon2id. `identities` table links
`(provider, sub) → user`: `oidc` (generic, Authentik first) and `google` use
OIDC; `github` uses plain OAuth2 (`GET /user` + `/user/emails`, primary
verified email). Email collision with an existing account links to it (verified
emails only). Old `oidc_sub` column migrates into `identities`.
`GET /api/auth/oidc/login|callback` remain as aliases for
`/api/auth/oauth/oidc/*`.

Legacy `POST /api/auth/register|login` semantics are unchanged (used by the new
flow's panels).

### Profile & onboarding

| Method & path | Body | Response |
|---|---|---|
| `PATCH /api/auth/me` | any subset of `{username, name, onboarded, settings: {wpm?, theme?, accent?, lang?}}` | `200 {user}` |

- `username`: 2–24 chars, `[a-zA-Z0-9_-]`, stored as given, unique not required (it's a display handle, email stays the identifier). `400` with a helpful message on invalid.
- `settings.wpm`: int 100–1200. `settings.theme`: `"auto" | "light" | "dark"`.
- `settings.accent`: `"red" | "ember" | "acid" | "cyan" | "violet" | "mono"` (curated pairs, see Design tokens). Default `"red"`.
- `settings.lang`: `"auto" | "en" | "de"`. Default `"auto"` (client resolves via `navigator.language`).
- `onboarded`: client sets `true` when the intro flow completes **or is skipped**. New users start `false`; clients route un-onboarded users into the intro flow after auth (local register AND first SSO login). The flow always shows a small `SKIP_` (top corner, quiet) — skipping sets `onboarded: true` with defaults.
- Settings are server-side so they follow the account across devices; clients cache in localStorage (for guests localStorage is the primary store until they upgrade).

### Starter library (v0.4.1)

Every newly created user — register, first SSO login, **and guest creation** —
is seeded with a default library: the built-in `WELCOME TO FLICK` intro book
(`source: "intro"`) plus **every catalog work** (`source: "catalog"`, normal
`catalog_slug`). No library ever starts empty. The intro's text lives in the
server binary and teaches: what the pivot letter is, the controls/shortcuts,
and how to ramp WPM. All seeded books are deletable like any book (catalog
works can be re-added via `/api/catalog/:slug/add`); none of them ever count
toward upload limits. Seeded `created_at` values are staggered (intro newest,
then manifest order) so the default list order is stable.

The guest→account merge never duplicates seeds: at most one intro survives
(target's wins), and for each catalog slug present on both sides the copy with
the **greater reading position** survives.

### Catalog (free content, no auth)

Public-domain works shipped with the server (`server/assets/catalog/`,
manifest `catalog.json`). Timelines are parsed once per work (lazy, cached
server-side), then copied cheaply into a user's library.

| Method & path | Body | Response |
|---|---|---|
| `GET /api/catalog` | — | `200 [{slug, title, author, lang, kind, description, word_count}]` (public, no auth) |
| `POST /api/catalog/:slug/add` | — | `201 {book}` (auth required; guests call `/api/auth/guest` first). `409` if already in library. |

Catalog books get `source: "catalog"`. Adding is idempotent per user
(`409` carries the existing book id in the error message body:
`{"error": "...", "book_id": "..."}`). Since libraries are pre-seeded with the
whole catalog (v0.4.1), clients treat a `409` as success and open the existing
copy via its `book_id`.

### Stats & streak

Server-side per-day reading log; the client reports consumed words alongside
position saves.

| Method & path | Body | Response |
|---|---|---|
| `PUT /api/books/:id/position` | `{position, read?: int, day?: "YYYY-MM-DD"}` | `204` |
| `GET /api/stats` | — | `200 {today: {day, words}, total_words, goal, streak: {current, best}, days: [{day, words}]}` |

- `read`: words consumed since the client's last report (client-computed).
  Server clamps to 0–500 per report and adds to the user's row for `day`.
- `day`: the client's LOCAL date (streaks are a human-day concept). Server
  rejects days more than 2 days away from server date (clock abuse guard).
  Missing `day` → server date.
- `goal` is the daily words threshold for a streak day, server constant `300`.
- `streak.current`: consecutive days ending today or yesterday with
  `words >= goal`. `streak.best`: all-time max. `days`: last 42 entries.

**Sessions (running-app-style detail).** The client posts a session summary on
reader exit/pause-end (≥10s and ≥20 words, else discard):

| Method & path | Body | Response |
|---|---|---|
| `POST /api/sessions` | `{book_id, started_at, duration_ms, words, avg_wpm}` | `201` |
| `GET /api/sessions?limit=50` | — | `200 [{id, book_id, book_title, started_at, duration_ms, words, avg_wpm}]` newest first |

Server sanity-clamps (`duration_ms` ≤ 6h, `avg_wpm` ≤ 1500, `words` consistent
with duration×wpm ±50%). Stats view derives records (longest session, fastest
sustained wpm, biggest day) from sessions + days.
- Streak celebration is CLIENT-driven: the client knows today's words from
  `GET /api/stats` at reader-open plus its own live count; when the goal is
  crossed it plays the full-screen animation (see Web client v0.3), then
  re-fetches stats. The API never pushes.

### Books & imports

| Method & path | Body | Response |
|---|---|---|
| `GET /api/books?q=` | — | `200 [{book}]` — `q` full-text searches title + content (SQLite FTS5), omitted = whole library |
| `POST /api/books` | JSON `{title?, text}` **or** multipart `file` (optional `title` field) | `201 {book}` |
| `POST /api/import/url` | `{url, title?}` | `201 {book}` |
| `POST /api/import/html` | `{url, html, title?}` | `201 {book}` — extension path: page HTML captured in-browser (paywalled/logged-in pages included), server runs the same readability extraction |
| `GET /api/books/:id` | — | `200 {book}` |
| `GET /api/books/:id/timeline` | — | `200` timeline JSON (format above) |
| `GET /api/books/:id/text` | — | `200 {"paragraphs": [["word", ...], ...]}` — words flattened across paragraphs match timeline indices EXACTLY (same tokenizer), so clients map text↔timeline 1:1 |
| `PUT /api/books/:id/position` | `{position, read?, day?}` | `204` (also bumps `last_read_at`) |
| `DELETE /api/books/:id` | — | `204` |
| `GET /api/integrations` | — | `200 {dropbox: {app_key} \| null, google_picker: {client_id, api_key} \| null}` (public) |

```json
book = {
  "id", "title", "source", "word_count", "position", "created_at",
  "last_read_at": 0 | null,
  "author": "..." | null,          // catalog + extracted metadata
  "url": "https://..." | null,      // web imports
  "favicon": "https://..." | null,  // Pocket-style origin icon (URL only, client renders w/ fallback)
  "excerpt": "first ~30 words…" | null,
  "category": "article" | "news" | "docs" | "book" | "story" | "essay" | null
}
```

- `source`: `"paste" | "pdf" | "epub" | "txt" | "clippings" | "url" | "html" | "catalog" | "intro"`.
- Original text is stored server-side (enables `/text`, FTS search, future
  re-parsing). `category` is a server heuristic (catalog kind; URL imports:
  domain + og:type mapping; uploads: `"docs"` for pdf/txt, `"book"` for epub).
  `favicon` = `https://<origin>/favicon.ico` unless the page declares one.
- `last_read_at`: unix seconds, null until first position save. The library's
  CONTINUE row uses the max.
- Multipart upload sniffing (extension is a hint, bytes decide): `%PDF` →
  pdf-extract; zip with EPUB mimetype → rbook (EPUB 2+3); UTF-8 text
  containing `==========` My-Clippings record separators → Kindle clippings
  parser (each highlight becomes a paragraph, prefixed by its book title when
  the file spans multiple books); other UTF-8 text → txt/md as-is. Anything
  else → `400`. All parsers panic-guarded (`catch_unwind`) like pdf-extract.
- `POST /api/import/url`: server fetches the page (20s timeout, 25 MB cap,
  redirects followed max 5) and extracts either the raw file (pdf/epub/txt by
  content sniff — this is the path the Dropbox Chooser and Google Picker use
  via their direct-download links) or the readable article text
  (`dom_smoothie`, Mozilla-readability port) for HTML. **SSRF guard**: https
  and http only, DNS-resolved IPs must be public unicast (reject loopback,
  RFC1918, link-local, ULA…), re-checked per redirect hop.
- Kindle note (researched 2026-07): there is no Kindle API; Amazon removed
  "Download & Transfer" in 2025 and full-book export means DRM stripping —
  never build that. Clippings upload is the honest path now; a per-user
  email-import address (Readwise pattern) is the planned v0.4 upgrade.
- OneDrive: deferred — picker v8 requires MSAL + (since 2025) tenant admin
  consent; revisit on demand. Dropbox Chooser + Google Picker are client-side
  script embeds gated on `GET /api/integrations` (dark until keys configured).
- Paste with no `title`: server uses first ~40 chars of text.
- All book routes are scoped to the session user; foreign ids → `404`.
- Upload limit: 25 MB.

## Rate limits

Per-client limits on the abuse-prone endpoints. In-memory fixed-window
counters, per server process (each replica counts independently); one bucket
per (endpoint, client) pair, so hitting one endpoint's limit never blocks the
others. Everything not listed is unlimited.

| Endpoint | Limit |
|---|---|
| `POST /api/auth/login` | 10 / 5 min |
| `POST /api/auth/register` | 10 / 5 min |
| `POST /api/auth/code/verify` | 10 / 5 min |
| `POST /api/auth/code/request` | 5 / 5 min |
| `POST /api/auth/lookup` | 30 / 5 min |
| `POST /api/auth/guest` | 20 / hour |
| `POST /api/import/url` | 30 / hour |

- Exceeding a limit → `429` with the standard `{"error": "..."}` body and a
  `Retry-After` header (whole seconds until the window resets).
- **Client key = client IP.** The FIRST `X-Forwarded-For` entry is trusted
  ONLY when the direct peer is a private/loopback address (loopback, RFC1918,
  100.64/10 CGNAT/tailnet, `::1`, `fc00::/7`) — i.e. the reverse proxy
  (Caddy) in front; from any public peer the header is ignored and the peer
  address itself is the key.
- Fixed window means a worst-case 2× burst across a window boundary — fine
  for abuse resistance; this is not traffic shaping.

## Server config (env)

| Var | Meaning | Default |
|---|---|---|
| `FLICK_EDITION` | `selfhost` or `hosted` (see Editions & plans) | `selfhost` |
| `FLICK_ADDR` | listen address | `0.0.0.0:8484` |
| `FLICK_DATA_DIR` | SQLite + storage dir | `./data` |
| `FLICK_PUBLIC_URL` | external base URL (OIDC redirects) | `http://localhost:8484` |
| `FLICK_WEB_DIST` | built web client dir to serve statically | first of `./web/dist`, `../web/dist` containing `index.html` (so it works from repo root and from `server/`) |
| `FLICK_OIDC_ISSUER` | OIDC issuer URL (enables generic SSO when set) | — |
| `FLICK_OIDC_CLIENT_ID` / `FLICK_OIDC_CLIENT_SECRET` | OIDC client creds | — |
| `FLICK_OIDC_NAME` | SSO button label | `SSO` |
| `FLICK_OAUTH_GOOGLE_CLIENT_ID` / `..._SECRET` | Google sign-in (OIDC) | — |
| `FLICK_OAUTH_GITHUB_CLIENT_ID` / `..._SECRET` | GitHub sign-in (OAuth2) | — |
| `FLICK_SMTP_URL` | `smtp[s]://user:pass@host:port` for login codes | — (unset ⇒ codes are logged at `info`, dev mode) |
| `FLICK_SMTP_FROM` | From address for mail | `flick <no-reply@localhost>` |
| `FLICK_DROPBOX_APP_KEY` | enables Dropbox Chooser | — |
| `FLICK_GOOGLE_PICKER_API_KEY` | enables Google Picker (with google client id) | — |

SPA fallback: unknown non-`/api` GET paths serve `index.html` from `FLICK_WEB_DIST`.

## Design tokens (web/src/app.css is the shipped implementation)

Two orthogonal axes, both stamped on `<html>` (an inline `<head>` script stamps
them from localStorage before first paint — no theme flash):

- `data-mode = light | dark` — the "flicker". Stored as `settings.theme`
  (`auto` follows `prefers-color-scheme` and is resolved by the client).
- `data-theme = paper | signal | sage | tide | dusk | noir` — six curated,
  hand-tuned themes (never a free color wheel). Stored as `settings.accent`
  under the legacy slugs; the mapping lives ONLY in `web/src/lib/theme.svelte.ts`:
  `paper↔red · signal↔ember · sage↔acid · tide↔cyan · dusk↔violet · noir↔mono`.

Neutrals — warm for paper/sage/dusk, cool for signal/tide/noir:

| Token | warm light | warm dark | cool light | cool dark |
|---|---|---|---|---|
| bg | `#F5F2EA` | `#0C0A08` | `#F2F2EF` | `#070707` |
| panel | `#FFFFFF` | `#141110` | `#FFFFFF` | `#101010` |
| ink | `#1A1512` | `#F2EDE5` | `#0C0C0B` | `#F3F3F1` |
| dim | `#8C8378` | `#807769` | `#8B8B87` | `#797977` |
| line | `#E7E1D6` | `#241F18` | `#E3E3DE` | `#1E1E1E` |

- Monospace everywhere (`ui-monospace, "JetBrains Mono", "Cascadia Mono", "SF Mono", Menlo, Consolas, monospace`).
- **One accent slot** (`--accent`): pivot letter, counters, progress, selection
  marker. No other colors, ever. AA on both grounds:

  | theme | light accent | dark accent |
  |---|---|---|
  | `paper` (default) | `#D8342B` | `#F53B30` |
  | `signal` | `#E5231B` | `#FF3B30` |
  | `sage` | `#3E8A00` | `#7ADB2E` |
  | `tide` | `#0071B8` | `#2DC7FF` |
  | `dusk` | `#7A3DD4` | `#A87BFF` |
  | `noir` | = ink | = ink |

  `noir` = accent equals ink; the pivot letter then renders inverse-video
  (ink block, bg letter) so it stays visible. `signal` is the Nothing-flavour
  theme: it alone turns on the dot-matrix grid texture (`--tex: 1`). Accent is
  used at full value or not at all — no tints, no alphas.
- **NO glow effects. None.** No `text-shadow`, no colored `box-shadow`, no CRT
  scanlines, no blur halos — anywhere, either theme. Texture allowance: a flat
  dot-matrix grid (`radial-gradient` 1px dots at 5% ink, 18px cell) on
  hero/celebration surfaces only. Elevation = surface ladder (bg → panel →
  inverse-video), never shadows.
- Motion tokens: `--t-micro: 100ms linear`, `--t-std: 200ms ease-in-out`,
  `--t-screen: 350ms ease-in-out`, `--t-seq: 500ms linear`. Nothing over 600ms
  per beat; easing only linear/ease-in-out (no bounce/spring/overshoot).
  Enters = fade + 4–8px translate; never scale. 30ms stagger on grouped items.
  `prefers-reduced-motion` ⇒ skip to settled end states.
- Square corners, 1px hairline borders, uppercase letter-spaced labels.
  Keycap primitive for shortcut hints: `kbd` with hairline border,
  2px bottom border, 10px tracked type.
- Numbers: `tabular-nums` everywhere. Hero-scale numbers (streak day, big
  stats) render as 5×7 dot-matrix digits (inline SVG circles from per-digit
  bitmasks, ≥24px, display-only — body numbers stay JetBrains Mono).
- Library = flipper-style: index numbers, all-caps titles, dotted leaders, accent progress %, inverse-video selection.
- Reader = clean instrument: guide rails + accent notches, big centered ORP word, accent pivot.
- Both themes; `prefers-color-scheme` + `data-theme` override, token-level (see mockup CSS).
- Wordmark: `FLICK_` with blinking accent cursor.
- Loading = terminal status row (three 6px squares filling `steps(3)` + label
  with animated trailing dots), never a spinner.

## Reader playback (client behavior)

- Scheduler MUST be vsync-locked (requestAnimationFrame accumulator on web; CADisplayLink/Choreographer native), never bare setTimeout chains — target smooth 150–800+ WPM on 60/90/120 Hz screens.
- Word advance: accumulate frame delta; when elapsed ≥ current word's `weight * 60000/wpm`, advance (carry remainder).
- Frame deltas are clamped to 250 ms and a hidden tab pauses playback — jank
  or a background tab must never fast-forward through unseen words (v0.5).
- Controls: play/pause (Space), back/forward one sentence (←/→), WPM slider (150–800, step 25). Initial WPM comes from `user.settings.wpm` (localStorage is only a cache).
- Touch (phone): tap center third = play/pause, left third = back one sentence, right third = forward one sentence. No hover-dependent UI anywhere.
- Respect `prefers-reduced-motion`: never autoplay.

## Web client v0.2 additions

- **Onboarding flow** (full-screen staged panel, shown while `user.onboarded == false`):
  1. `USERNAME_` — pick a handle (prefilled from name/email local part), validated per PATCH rules.
  2. `SPEED` — a live word-stream demo the user speeds up/down until comfortable; the chosen value becomes `settings.wpm`. Demo timeline is PRE-COMPUTED data embedded in the client (generated by flick-core), never engine logic reimplemented client-side.
  3. `THEME` — auto / light / dark with instant preview; sets `settings.theme` (`data-theme` on root; `auto` removes the override).
  Finish → single `PATCH /api/auth/me` with `{username, settings, onboarded: true}` → library.
- **Auth page** carries a small looping RSVP demo (same pre-computed-timeline rule) so the first thing a visitor sees is the product working.
- **Library (Mediathek)** rows get a second dim line: source tag (`[PDF]`/`[TXT]`/`[INTRO]`), word count, estimated remaining time at the user's WPM, added date. Panel header keeps red counters (books · words). Selected row stays inverse-video with red `▶`. The whole view keeps the flipper-zero character — chunky, indexed, keyboard-first (with touch equivalents).
- **Phone-native**: responsive single-column layout; 44px+ touch targets; `viewport-fit=cover` + safe-area insets (reader controls sit above the home indicator); reader is full-viewport on phones with fixed bottom controls.
- **PWA**: `manifest.webmanifest` (name flick, display standalone, theme/background per scheme, maskable icons), service worker with cache-first app shell and NO caching of `/api/*`. App must remain fully functional when the SW is unsupported.
- **Theme setting**: `settings.theme` applies `data-theme` on the root element; `auto` follows `prefers-color-scheme`.

## Web client v0.4 additions

- **Real URLs, working back button.** The client maps views onto paths via the
  History API: `/` (landing when logged out, library when authed), `/read/:id`,
  `/stats`, `/auth`. Navigation pushes state; browser back/forward (popstate)
  drives the state machine; deep links resolve on load (`/read/:id` with no
  session → landing). The server's SPA fallback already serves index.html for
  all non-`/api` paths.
- **WPM ramp ("car motor").** On every play start (first play AND resume), the
  effective wpm ramps from 60% of the target to 100% over the first ~3 seconds
  of active playback (linear, floor 100 wpm). The slider always shows/sets the
  target. Seeking does not reset the ramp; pausing and resuming does. This is
  playback pacing (client behavior), not engine logic — the timeline is
  untouched.
- **Landing quick-read.** The landing accepts a file drop / picker directly:
  guest session is minted lazily, the file imports, and the reader opens —
  upload-to-reading in one gesture. Same for pasted text via the add panel.
- **Edition awareness.** Client fetches `GET /api/meta`; `selfhost` replaces
  every Pro surface with CONTRIBUTE → the GitHub repo. `hosted` shows the
  plans strip and, when the weekly upload limit is hit, a friendly limit note
  (never a lock on existing content).
- Defaults doctrine: every control's initial position is a decision — wpm
  seeds from account settings (or 350), theme/mode follow system, language
  follows browser. No control may default to a degenerate value.

## Web client v0.4.1 additions

- **Top bar (full).** Right side, in order: `GITHUB ↗` external link (always);
  `GO PREMIUM` (hosted edition only — selfhost never shows a Pro surface;
  scrolls to the landing plans strip); the light/dark **flip cube**; then auth
  controls — signed out: quiet `LOG IN` link + primary `CREATE ACCOUNT`
  button; guest: `CREATE ACCOUNT`; signed in: `LOG OUT`. On narrow viewports
  the premium and login links yield first; `CREATE ACCOUNT` stays.
- **Flip cube.** The light/dark toggle is a 3D cube (flat faces, 1px borders,
  no shadows) that rotates 90° forward on every flick to reveal the other
  side's face (`LIGHT`/`DARK`). Face shown always matches the resolved mode
  (an effect re-syncs if the system theme flips it externally).
  `prefers-reduced-motion`: no rotation transition.
- **Hover language (uiverse-inspired, flat).** `CREATE ACCOUNT`: accent block
  slides in behind the label, text inverts — no gradients, no shadows.
  Top-bar links get bracket hovers (`[ ]` fade in, accent). Delete `×`
  buttons: half-turn + inverse-video accent square on hover.
- **Armed delete row.** Clicking `×` arms the whole row: blinking accent
  outline (steps, cursor-style), accent-tinted background, struck-through
  title, inline `delete? y/n`. `n`, or deleting/canceling, disarms.
- **Pre-seeded library.** Because every library starts with the intro + full
  catalog, the landing catalog picks treat `409 already in library` as
  success and open the existing copy (`ApiError.bookId`).
- **Trash-bin soft delete (v0.4.3).** `DELETE /api/books/:id` moves a live
  book to the trash (`books.deleted_at`); trashed books vanish from every
  live surface (list, get, timeline, text, position, search, catalog-slug
  idempotency, stats `books_finished`, upload counting — so trashing refunds
  the week's upload slot). `GET /api/books/trash` →
  `{items: [{id, title, author, word_count, deleted_at, expires_at}],
  retention_days: 30}` (newest first). `POST /api/books/:id/restore` and
  `DELETE /api/books/:id/purge` (both 204/404; only trashed books qualify).
  Auto-purge sweeps rows older than 30 days whenever the user's trash is
  touched. Session summaries keep the real title while a book sits in the
  trash; only purging degrades it to `DELETED`.
- **Tags (v0.4.3).** `books.tags` (JSON array of strings) serialized on
  every book. Auto-tagged at creation with the book's `category` when it has
  one (catalog seeds included); `PUT /api/books/:id/tags {tags: [...]}` →
  `200 {book}` replaces them (≤12 tags, each 1–24 chars, trimmed, deduped
  case-insensitively, order preserved; violations are 400s). The web library
  shows a tag filter bar (union of live tags) once there is more than one
  distinct tag, plus per-row inline tag editing.
- **Guided add wizard (v0.4.3, web).** The `+ add` control is a real primary
  button opening a full-screen guided flow: step 1 pick a source (paste /
  file / web link / cloud storage / built-in catalog), step 2 the source's
  input (+ optional title and tags), then import → straight into the reader.
  Esc/×/back at every step; the landing quick-drop stays untouched. "Cloud
  storage" accepts public Dropbox / Google Drive / OneDrive share links —
  the client rewrites them to direct-download URLs and feeds
  `POST /api/import/url` (no OAuth, no keys; private files need the user to
  create a share link first).
- **Stats totals (v0.4.2).** `GET /api/stats` additionally returns
  `"totals": {time_ms, sessions, avg_wpm, books_finished, active_days,
  best_day: {day, words} | null}` aggregated server-side (`avg_wpm` is
  duration-weighted from the session log; `books_finished` counts books with
  `position >= word_count > 0`).
- **Playful pass (v0.4.2, web).** Delete is a trash-can glyph (lid opens on
  hover, inverse-video accent); the library home drops row numbers and leads
  with the last 3 read books as cards (progress bar + resume) above a
  compact ALL list; the six-theme picker moves from the footer to a top-bar
  popover (swatch button → panel); the streak overlay is a real celebration
  (count-up, flat square confetti, accent flash — still skippable, <4s);
  buttons share the slide-fill hover + press-down active language and meet
  44px touch targets on phone. Still: no gradients, no shadows, no glows.
- **Friction pass.** Library list order puts the reading front and center:
  continue card (most recent unfinished), then in-progress books by
  `last_read_at` desc, then unread (server order), finished last. Guests see
  a quiet persistence hint ("reading lives only in this browser") linking to
  the auth page — never a modal or a gate. The auth page carries a one-line
  pitch (library/position/streak on every device); guests additionally get
  the merge reassurance ("your current reading comes with you").

## Web client v0.3

**Homepage (guest-first).** Unauthenticated `/` is a homepage, not a login
wall. ≤5 bands, 96px rhythm, homepage max-width ~880px:
1. Header: `FLICK_` wordmark + quiet `LOG IN` ghost button (top-right).
2. Hero (dot-grid surface): eyebrow tagline, ONE oversized display line
   (the umbrella: read your documents and books faster), then the live RSVP
   demo as protagonist — idle shows a static ORP word, plays on tap (never
   autoplay), WPM slider attached so visitors feel 250→500. Keycap hints.
3. TRY band: paste textarea + drop zone + `BROWSE CATALOG` — the real product.
   First add lazily creates the guest session, then jumps straight into the
   reader. A quiet status row (never a modal/gate) offers
   `SAVE YOUR LIBRARY ACROSS DEVICES → CREATE ACCOUNT`.
4. HOW band (inverse-video): `[01] ONE WORD AT A TIME · [02] THE PIVOT LETTER
   · [03] YOUR PACE` 3-up with mini ORP diagram, 30ms stagger. Below it a FREE
   row: what's free (everything — unlimited reading, 100 books, 25 MB
   uploads) stated plainly; "Pro later = power integrations only, what's free
   stays free."
5. Footer: theme toggle, language picker (`EN / DE` text codes, no flags),
   FAQ link-outs (RSVP science, WPM guidance — short content sections under
   the fold).

**Auth flow (email-first).** Single screen: email field + configured provider
buttons (from `/api/auth/providers`). Continue → `lookup`:
- unknown email → registration panel (password, optional name) → onboarding.
- known email → the account's methods: password field (if set), `EMAIL ME A
  CODE` (always), linked SSO buttons. Code entry = 6 single-char cells.
- Guests keep their session cookie through this flow so the server merges
  their library into the account.

**Onboarding** gains a quiet `SKIP_` (top corner) on every step; step 3 (LOOK)
adds the accent swatch row (6 squares) next to theme choice. Language is
auto-detected; picker lives in footer/settings.

**Streak celebration** — full-screen "glyph sequence", machine choreography,
monochrome + accent, dot-grid surface, skippable from frame 0 (tap/Esc/Space),
auto-dismiss ≤4s, reduced-motion ⇒ settled state immediately:
- 0–300ms overlay fade-in · 300–700ms hairline rails draw in (`scaleX`),
  `DAY_` label fades up 8px · 700–850ms the day numeral fills dot-by-dot
  (5×7 dot-matrix, `steps()` fill, accent) · 850–1600ms stat rows stagger in
  (60ms; words today, avg wpm, dotted leaders) + 2px accent bar sweeps toward
  the next milestone · then settle; `CONTINUE_` appears only after settle
  (mis-tap guard).
- Escalation: days 2–6 = inline stats tick only (no overlay); day 1, 7, 30,
  100, 365 = overlay. A shown milestone never re-fires (localStorage +
  server stats both checked).

**Reader:** obvious exit — a persistent bordered `← LIBRARY` button top-left
(desktop and phone; not a bare glyph), plus Esc. Tap zones unchanged.
**Missed a word? (context + full text view):**
- On pause, a context strip appears under the word stage: the current sentence
  (reconstructed client-side from the timeline) with the current word marked;
  tap any word in it to jump there.
- `TEXT_` button (and `T` key) opens the **full read view**: the whole book as
  normal readable text (`GET /api/books/:id/text`), auto-scrolled to the
  current position, current word marked in accent. Tap/click any word →
  reader jumps to that timeline index and closes the view. This doubles as a
  normal-reading mode for skimming back.
**Stats view (running-app style):** session feed newest-first (per session:
book, date, duration, words, avg wpm — dotted-leader rows), 42-day bar graph,
records block (longest session, best day, fastest sustained wpm, streak best),
dot-matrix hero numbers.
**Library:** `CONTINUE READING` row pinned under the header (most recent
`last_read_at`: title + progress + `▶ RESUME`), then the list; stats strip
gains `DAY STREAK` cell; catalog entry point row at the bottom:
`+ ADD FROM CATALOG` opening the catalog browser (grouped by kind, word
counts, one-tap add).
**Import UI:** the add flow shows source buttons: `PASTE / FILE (PDF EPUB TXT
MD) / URL / DROPBOX / GOOGLE DRIVE / KINDLE CLIPPINGS` — Dropbox/Google only
when `/api/integrations` says configured; Kindle clippings = file upload with
a hint where to find `My Clippings.txt`.
**i18n:** all UI strings via a tiny dictionary module (`en`, `de`), zero deps,
`settings.lang` (`auto` → `navigator.language`). Book content is never
translated. German copy must be real German, not machine-word-order.
**Stats view:** reachable from the library stats strip. Guests see it too
(their data lives server-side on the guest row).

## Browser extension (v0.3, `extension/`)

MV3 WebExtension (Chrome/Edge/Brave; Firefox-compatible where free), the
"Pocket for speed reading" client. Zero build deps — plain TS compiled by Bun,
no bundler frameworks.

- **Capture**: toolbar button + context-menu (`Read with flick` on page or
  selection). Selection → `POST /api/import/html` with the selection wrapped
  in the page's title/url; full page → outerHTML. Capturing in-browser means
  logged-in/paywalled pages the USER can see import correctly (their own
  access, their own library — never bypassing anything server-side).
- **Metadata**: page title, url, favicon (from `link[rel~=icon]`, fallback
  `/favicon.ico`) travel with the import; server categorizes + makes it
  searchable. This is the automatic save-categorize-iconify-search loop.
- **After save**: open `<FLICK_PUBLIC_URL>/read/<book_id>` in a new tab
  (the web app deep-links straight into the reader; unknown id → library).
- **Auth**: cookie-based against the flick origin (`host_permissions` for the
  configured server URL; `fetch` with `credentials: "include"`). Options page:
  server URL (default `https://flickread.app`, editable for self-hosters —
  this is the only extension setting). Not signed in → the popup shows
  `OPEN FLICK TO SIGN IN` (guest sessions work too).
- **Popup**: last 5 saves (favicon + title + word count), search field
  (`GET /api/books?q=`), `OPEN LIBRARY`. Same design tokens (embedded CSS).
- Web app addition: `/read/:id` route (SPA state deep link) — opens the reader
  for that book after session check; guests included.

Inline overlay reading on third-party pages (SwiftRead-style) is deliberately
NOT in v0.3 — the app reader is one tab away; an overlay means injecting the
player into arbitrary pages and comes later, if ever.
