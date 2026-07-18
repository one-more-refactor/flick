# flick — Pre-Launch Legal Review

**Scope:** flick as a **public, hosted SaaS** at **myflick.app**, operated by an
individual in Germany. Open source under **AGPL-3.0**, also self-hostable.
Reviewed against **GDPR**, German **TDDDG/ePrivacy** and **§ 5 DDG (Impressum)**,
**AGPL-3.0 § 13**, and third-party license compatibility.

**This document is an internal engineering/compliance findings report, not legal
advice.** The operator must have the drafted policies (`PRIVACY.md`, `TERMS.md`)
and the Impressum reviewed by a qualified lawyer in Germany before relying on
them. Findings cite the file/feature they come from so they can be actioned and
re-checked.

**Basis of review:** commit state of the repo at
`/home/philip/dev/projects/flick` and the marketing landing at
`/home/philip/dev/projects/flick-landing` as read on 2026-07-18.

---

## MUST-DO before public launch (blockers)

These genuinely block a lawful public launch. Each is concrete and actionable.

1. **Build account deletion (GDPR Art. 17 — right to erasure).**
   There is **no** account-deletion endpoint. `POST /api/auth/logout`
   (`server/src/auth.rs:522`) only clears the session cookie; the route table
   (`server/src/lib.rs:117-174`) has GET+PATCH on `/auth/me` and per-book
   `DELETE`, but nothing that deletes the *user*. A public service **must** let
   data subjects erase their account and all associated data.
   *Good news — low effort:* the schema already declares
   `ON DELETE CASCADE` from `sessions`, `books`, `identities`, `reading_days`,
   `sessions_log`, and `friends` to `users(id)` (`server/src/db.rs:21-195`), so a
   single `DELETE FROM users WHERE id = ?` cascades almost everything. You must
   additionally: delete the `login_codes` row (keyed by email, not cascaded),
   revoke/clear any share tokens, and null out `referred_by`/referral state that
   points at the deleted user. Add `DELETE /api/auth/me` + a confirm flow in the
   account menu (`web/src/App.svelte`).

2. **Build data export (GDPR Art. 15 access / Art. 20 portability).**
   No export endpoint exists. Users must be able to obtain their personal data
   in a portable, machine-readable form (their profile, books/uploaded text,
   reading days, sessions, friends, referral state). Add a
   `GET /api/auth/me/export` returning a JSON bundle (and offer it in the
   account menu). Medium effort — all the read helpers already exist in
   `server/src/db.rs`.

3. **Remove GSAP from the AGPL-distributed web app (license conflict).**
   `web/package.json` declares `"gsap": "^3.15.0"` and it is imported in
   `web/src/lib/landing/motion.ts` (`import { gsap } from 'gsap'` +
   `gsap/ScrollTrigger`), so GSAP is **bundled into `web/dist`**, which the
   AGPL-3.0 `flick-server` serves and which self-hosters build and redistribute.
   GSAP core ships under GreenSock's proprietary *"Standard 'no charge'
   license"* (confirmed: `web/node_modules/gsap/package.json` →
   `"license": "Standard 'no charge' license: https://gsap.com/standard-license."`),
   which is **not OSI-approved and not GPL/AGPL-compatible**. Distributing it as
   part of an AGPL work both (a) violates AGPL § 7's rule against adding further
   restrictions and (b) likely exceeds GreenSock's license terms. See the
   dedicated **GSAP / AGPL verdict** section for the fix. This blocks lawful
   AGPL distribution to self-hosters. (Lazy-loading it into a separate chunk
   does **not** cure this — it is still a declared dependency shipped in `dist`.)

4. **Publish the required legal pages, and confirm the source repo is public.**
   - **Impressum (§ 5 DDG):** a public commercial website operated from Germany
     **must** carry an Impressum with the operator's real name and a physical
     postal address (a PO box / c/o packstation is not sufficient) and a direct
     contact (email; a contact form/phone). There is currently **no** Impressum,
     privacy policy, or terms anywhere in the codebase (grep for
     `impressum|privacy|terms|datenschutz` finds only marketing copy). This is a
     hard German-law requirement independent of GDPR and is aggressively
     enforced via *Abmahnung* (cease-and-desist). Ship an Impressum page.
   - **Privacy policy + Terms:** none exist. Drafts are provided
     (`PRIVACY.md`, `TERMS.md`) — have them reviewed and publish them, linked
     from the footer and the auth/registration screen.
   - **AGPL § 13 source offer — verify the repo is PUBLIC.** The UI already
     shows a source link: the top-bar GitHub button and CONTRIBUTE page link to
     `https://github.com/one-more-refactor/flick` (`web/src/lib/consts.ts:2`,
     `web/src/App.svelte:522`, `web/src/lib/Premium.svelte`). AGPL § 13 requires
     that all users interacting with the running instance over the network be
     offered the **Corresponding Source of the exact version running**. If that
     GitHub repo is **private at launch**, the link 404s and serving the app
     publicly is an AGPL violation. **Confirm the repo is public** before go-live
     and keep it in sync with what's deployed (ideally link/tag the deployed
     version, not just `master`).

5. **Bound IP-address retention (data minimization, Art. 5(1)(c)/(e)).**
   `users.signup_ip` stores a **raw client IP** and is written **only for
   referred signups** (`server/src/db.rs:1136-1148`, called from
   `auth.rs:271`/`460` via `set_referred_by`; normal signups store no IP). It is
   kept **indefinitely** with no TTL and is used solely for same-IP referral
   anti-abuse (`server/src/referral.rs:54-72`). Indefinite retention of an IP
   for fraud-dedup is hard to justify. Fix: store a **salted hash** of the IP
   instead of the raw value (dedup only needs equality), and/or auto-purge it
   after a bounded window (e.g. 30-90 days, or once the referral qualifies/is
   rejected). Also define a **short retention for server access logs and the
   reverse-proxy (Caddy/Cloudflare) logs**, which capture IPs + request paths;
   the rate-limiter logs IPs too (`ratelimit.rs:258`).

---

## SHOULD-DO (important, not strictly blocking)

- **Data-processing agreements (DPAs) with each processor.** Put GDPR Art. 28
  DPAs in place with: the **SMTP/email provider** (login codes carry email
  addresses — `server/src/mail.rs`), the **hosting provider**, and **Cloudflare**
  if it fronts the service. Name them in the privacy policy.

- **International-transfer basis (Art. 44 ff.).** Cloudflare (US) and the
  Google/GitHub sign-in paths involve US transfers. Rely on the **EU-US Data
  Privacy Framework** certification of those vendors and/or **SCCs**, and
  document it. Disclose in the privacy policy.

- **Retention honesty for reading history.** The "90-day free history" is a
  **read-time filter**, not deletion: `stats::list_sessions` passes a
  `min_started_at` floor for free users (`server/src/stats.rs:251-252`), but
  `sessions_log` and `reading_days` rows are **never deleted** — they persist
  indefinitely (until account deletion). Either actually delete beyond the
  retention window or state clearly in the policy that history is retained for
  the life of the account (the draft states the latter). Do not describe it to
  users as if old data is gone when it is not.

- **Notice-and-takedown / DMCA policy for user uploads + share links.** Users
  upload arbitrary documents (`POST /api/books`, `POST /api/import/url|html`)
  and can publish **public share links** (`/s/:token`,
  `GET /api/shared/:token` — public, no auth, `server/src/books.rs`,
  `lib.rs:142-144`). The hosted service is a host of user content and needs
  (a) a ToS clause putting responsibility for uploaded/shared content on the
  user, and (b) a takedown contact + process. Drafted in `TERMS.md`.

- **Minimum age / minors.** For a public EU service the German age of digital
  consent is **16** (Germany did not lower Art. 8 GDPR below 16). State a 16+
  minimum in the ToS/registration, or implement verifiable parental consent
  below 16. The self-host "family/kids accounts" concept (per project memory)
  **must not** be exposed as a public feature on myflick.app without a
  parental-consent flow — keep kid accounts self-host-only. (No child-specific
  onboarding was found in the current `web/src`, which is good.)

- **Pro billing is not built — gate the promises.** `users.plan` exists but no
  API sets it and there is **no payment integration** (CONTRACTS.md "Editions &
  plans"; Pro shown as *SOON*). The ToS must present Pro as a future paid
  feature. **When billing launches**, selling to EU consumers triggers: **VAT /
  OSS** obligations (place-of-supply is the consumer's country), a **payment
  processor with SCA** (Stripe/Paddle etc.; a Merchant-of-Record like Paddle
  offloads VAT), the **consumer right of withdrawal** (14-day, with the standard
  waiver for immediately-supplied digital content), and pre-contractual price
  transparency (§ 312j BGB / "Button-Lösung"). Flagged in `TERMS.md`.

- **Referral program terms.** The 1-month/1-month reward, the "300 words on 3
  distinct days" qualification, the same-IP self-invite rejection, "only while a
  referral event is active", and no-cash-value/right-to-revoke need written
  terms (`server/src/referral.rs`). Drafted in `TERMS.md`.

- **Email as an identifier / rectification.** `PATCH /api/auth/me`
  (`auth.rs:583`) can change name/username/avatar/settings but **not email**;
  there is no self-serve email change (Art. 16 rectification). Consider adding
  it, or handle email changes on request.

- **Guest sessions still store personal data server-side.** A "guest" is a real
  `users` row with books, reading days and sessions on the server
  (`auth::guest`, `db::merge_guest_into`). The privacy policy must cover guest
  data, and erasure/expiry of abandoned guest rows should be defined (there is
  currently no cleanup of stale guest accounts — consider a TTL sweep).

---

## NICE-TO-HAVE (polish / good practice)

- **Catalog / Project Gutenberg hygiene.** `server/assets/catalog/` ships
  Gutenberg public-domain works (O. Henry, Poe, Bierce, Aesop, Conan Doyle,
  Kafka *Die Verwandlung*, Stevenson, Thoreau, Marcus Aurelius; `catalog.json`).
  The underlying works are public domain, so the reading content is fine.
  Project Gutenberg's terms ask that if you **strip** the PG license header you
  must also **remove the "Project Gutenberg" trademark/name**; if you keep the
  header you must keep their license text. Verify each `.txt` is either
  stripped-and-de-trademarked or carries the PG boilerplate. `NOTICE` already
  attributes them to Project Gutenberg / public domain — good.

- **CC-BY-SA-4.0 attribution for frequency tables — verified present.** The
  embedded Zipf tables (`core/assets/freq_en.txt`, `freq_de.txt`) are correctly
  attributed to Hermit Dave's FrequencyWords (CC-BY-SA-4.0, OpenSubtitles) in
  `NOTICE`. This is a **binary/data** inclusion; because the tables are
  CC-BY-SA, the attribution + license notice must continue to travel with any
  distribution (it does, via `NOTICE`). Fine.

- **Remote favicons are not a live leak (today).** The API models a `favicon`
  URL on books, but the current web client hard-codes `favicon: null`
  (`web/src/App.svelte:304`) and never renders a remote `<img>` for it. If you
  later render third-party favicons in the library, note that this would make
  the reader's browser hit third-party origins (IP + which articles they saved)
  — self-proxy or inline them instead.

- **Consider a versioned "deployed commit" link** next to the GitHub button so
  AGPL § 13's "exact version" expectation is met precisely.

- **Security posture is good — keep it.** argon2id password hashing
  (`auth.rs:45-51`), TLS-gated `Secure` + `HttpOnly` + `SameSite=Lax` session
  cookie (`auth.rs:87-99`, `config.rs:146`), no email enumeration
  (dummy-hash timing + silent `204` on code request), constant-time code/token
  comparison, per-endpoint rate limiting, SSRF-guarded URL import
  (CONTRACTS.md; `books.rs`), and OAuth/OIDC identity linking gated on
  **verified email** (`oidc.rs:306,450-461`) — this prevents account takeover
  via unverified-email collision. Document the security measures in the privacy
  policy (Art. 32).

---

## GDPR data inventory

Personal data actually collected/stored, per the schema in `server/src/db.rs`
and the handlers. "Lawful basis" is the suggested basis; confirm with counsel.

| Data | Where | Purpose | Suggested lawful basis | Retention (as built) |
|---|---|---|---|---|
| Internal user id (random) | `users.id` | Pseudonymous account key | Art. 6(1)(b) contract | Until account deletion |
| **Email** (nullable; null for guests) | `users.email`, `identities.email`, `login_codes.email` | Login, account identity, login codes | 6(1)(b) contract | Until deletion; `login_codes` auto-expires (10 min) & deleted on use |
| Display **name** (defaults to email local-part) | `users.name` | Shown in UI / to friends | 6(1)(b) contract | Until deletion |
| **Password hash** (argon2id) | `users.password_hash` | Authentication | 6(1)(b) contract + 6(1)(f)/Art.32 security | Until deletion |
| **Username** (optional handle) | `users.username` | Display handle, friends scoreboard | 6(1)(b) contract | Until deletion |
| **Avatar** (data-URL image ≤150 KB) | `users.avatar` | Optional profile picture | 6(1)(a) consent / 6(1)(b) | Until cleared/deletion |
| Settings (wpm, theme, accent, lang), onboarded, guest flag, created_at | `users.*` | Provide the service, cross-device sync | 6(1)(b) contract | Until deletion |
| **signup_ip (raw IP)** — *referred signups only* | `users.signup_ip` | Referral same-IP anti-abuse | 6(1)(f) legitimate interest (fraud) | **Indefinite — FIX (must bound)** |
| Referral state (`ref_code`, `referred_by`, `ref_credited`, `pro_until`, `plan`) | `users.*` | Referral program, Pro credit | 6(1)(b)/(f) | Until deletion |
| **OAuth/OIDC identity** (`provider`, `sub`, `email`) | `identities` | Federated sign-in (Google/GitHub/OIDC) | 6(1)(b) contract | Until deletion |
| **Session token** (auth cookie value) | `sessions` | Keep users logged in (strictly necessary) | 6(1)(b) + 6(1)(f) | 30-day TTL; expired rows swept on write |
| Login codes (sha256 hash, attempts) | `login_codes` | Passwordless email login | 6(1)(b) contract | 10-min TTL, deleted on use |
| **Uploaded documents/books** (title, full text, timeline, author, url, excerpt, category, tags, position, share token/mode) | `books` | The reading service itself | 6(1)(b) contract | Until deletion; trash 30-day auto-purge (`TRASH_RETENTION_DAYS`) |
| **Reading days** (per-day word counts) | `reading_days` | Streaks, stats, referral qualification | 6(1)(b)/(f) | **Indefinite** (until deletion) — not 90 days |
| **Reading sessions** (book, start, duration, words, avg wpm) | `sessions_log` | Stats, "wrapped", records | 6(1)(b)/(f) | **Indefinite** (until deletion); free plan only *displays* last 90 days |
| **Friendships** (user pairs) | `friends` | Social scoreboard (aggregates only) | 6(1)(a)/(b) — link possession = consent | Until unfriend/deletion |
| Client IP in logs | app trace logs + reverse proxy | Ops, rate limiting, abuse | 6(1)(f) | **Define a short retention — FIX** |

**Aggregate-only friend sharing — verified.** The social scoreboard
(`server/src/social.rs`, `score_row`) exposes only name/username + word counts,
streaks and time. It **never** exposes book titles or content — matching the
"binding privacy rule" in CONTRACTS.md. Good, and worth stating in the policy so
users understand what a friend can see.

**Special-category / user content caveat.** Uploaded documents (`books.text`)
can contain anything the user chooses, including others' personal data or
special-category data. The controller is a host/processor of that content;
minimize by (a) not using it for anything but serving it back, (b) making
erasure work (Must-Do #1), and (c) putting responsibility on the uploader in the
ToS.

## Data-subject rights: status

| Right (GDPR) | Supported today? | Gap |
|---|---|---|
| Access (Art. 15) | ✗ | No export/access endpoint — **build** |
| Rectification (Art. 16) | Partial | `PATCH /auth/me` covers name/username/avatar/settings; **no email change** |
| Erasure (Art. 17) | ✗ | No account deletion — **build** (cascades already exist) |
| Restriction (Art. 18) | ✗ | Handle procedurally / on request |
| Portability (Art. 20) | ✗ | Same as access — provide JSON export |
| Object (Art. 21) | n/a-ish | No profiling/marketing; provide a contact |
| Withdraw consent (Art. 7) | Partial | Delete avatar / unfriend / logout exist; erasure closes the gap |

**Bottom line: account deletion and data export do NOT exist today and must be
built before public launch.**

---

## ePrivacy / cookies verdict

**No consent banner is required — a plain privacy notice is enough**, *provided*
you keep the current no-tracker posture.

- The **only cookie** is `flick_session` — `HttpOnly; SameSite=Lax; Secure`
  (behind TLS), a **strictly-necessary** authentication cookie, exempt from
  consent under ePrivacy Art. 5(3) / **TDDDG § 25(2) Nr. 2**.
- **localStorage** holds only theme/mode/language/wpm prefs, guest library
  cache, and "seen this milestone" flags — **functional**, set by the app the
  user is using, no cross-site tracking. Exempt.
- **No analytics, no third-party trackers, no web-fonts, no CDN at runtime.**
  Verified: `web/src/app.css` uses a **system monospace** stack (no `@font-face`,
  no `fonts.googleapis`); a grep of `web/src` finds **zero** external URLs;
  `web/index.html` references only local icons + the manifest. URL imports are
  fetched **server-side** (SSRF-guarded), so the reader's IP is not leaked to
  content sites.
- **Keep it that way.** Two things would break the "no banner needed" position
  and require prior consent if switched on:
  1. **Analytics** (intentionally parked — good; if ever added, it needs a
     consent gate unless it's genuinely anonymous/consent-exempt).
  2. **Dropbox Chooser / Google Picker** — these are **third-party scripts**
     loaded into the user's browser, gated dark unless
     `FLICK_DROPBOX_APP_KEY` / Google keys are set (`integrations.rs`,
     CONTRACTS.md). If enabled on the hosted service they load Dropbox/Google
     code and should be consent-gated (or left off).

The **marketing landing** (`flick-landing`, Astro) bundles GSAP/Vanta/three/
anime/Lenis **locally** (all dynamic-imported from `node_modules` into `dist`);
a grep of the built `dist` finds no analytics/font/CDN runtime requests (only
`gsap.com` and `jcgt.org` strings inside bundled JS banners/citations, not
network calls). So the landing does not leak visitor IPs to third parties
either. Good.

---

## AGPL-3.0 § 13 (network use)

- **Requirement:** anyone interacting with the hosted flick over a network must
  be offered the **Corresponding Source of the exact modified version running**,
  at no charge, via a prominent, working link.
- **Status:** the UI satisfies the "prominent link" part — the top-bar GitHub
  button and the Premium/Contribute pages link to
  `https://github.com/one-more-refactor/flick` (`web/src/lib/consts.ts:2`).
- **The one blocker:** that repository **must be public** at launch, and its
  contents must correspond to what's deployed. If it is private (or lags the
  deployed build significantly), you are serving an AGPL app publicly while
  withholding the source — an AGPL violation. Verify public status; prefer
  linking the **deployed tag/commit**. See Must-Do #4.
- **Inbound=outbound / no CLA** (README) keeps the project relicense-proof —
  fine, but it also means **you cannot quietly drop AGPL obligations** for the
  hosted build; the GSAP conflict (below) must be fixed, not waived.

---

## GSAP / AGPL license verdict

**Verdict: real, probable license conflict — must fix before distributing the
AGPL app (i.e. before self-hosters get this build / before launch).**

- **The conflict is in the distributed app, not just the landing.**
  `web/package.json` → `"gsap": "^3.15.0"`, imported in
  `web/src/lib/landing/motion.ts`. It is compiled into `web/dist`, which
  `flick-server` (AGPL-3.0) serves and self-hosters redistribute.
- GSAP core is licensed under GreenSock's **"Standard 'no charge' license"**
  (confirmed in `web/node_modules/gsap/package.json`), a **proprietary** license
  that is **not OSI-approved and not GPL/AGPL-compatible**. It imposes use
  restrictions (and historically gated some plugins) that conflict with the
  AGPL's guarantee of unrestricted freedom to run/modify/redistribute.
- Combining GPL/AGPL code with a component under additional restrictions
  violates **AGPL § 7** (you may not impose further restrictions), and shipping
  GSAP inside a redistributed FOSS project likely exceeds GreenSock's terms too.
  Lazy-loading/code-splitting does **not** fix it — the bytes still ship in the
  distributed `dist`.

**Recommended fix (in order of preference):**

1. **Remove GSAP from `web/` and reimplement the scroll reveals with a
   GPL-compatible approach.** The effects in `motion.ts` are scroll-triggered
   fade/translate reveals + a progress bar + smooth scroll. These are readily
   done with the **Web Animations API** / CSS transitions +
   **IntersectionObserver**, and **Lenis is already a dependency and is MIT**
   for the smooth-scroll part. This drops the only non-free dependency from the
   app with no feature loss. **Preferred.**
2. **Isolate GSAP to the non-distributed hosted landing only.** The separate
   `flick-landing` repo is marketing, has **no AGPL license file**, and is not
   part of the AGPL app or shipped to self-hosters — GSAP there (a website you
   operate) is within GreenSock's no-charge terms. Move any GSAP-dependent
   flourish out of `web/` and into the landing, and delete `gsap` from
   `web/package.json`.
3. **Obtain a commercial GreenSock license** — this lets *you* use GSAP, but
   does **not** grant your self-hosters/redistributors the right, so it does
   **not** resolve the AGPL-distribution conflict. Weakest option; avoid.

**Other web/landing dependencies are clean:** `lenis`, `three`, `vanta`,
`animejs`, and `svelte` are all **MIT** (verified in their `package.json`s).
Only **GSAP** is the problem.

---

## Third-party licenses summary

| Component | License | Distributed in AGPL app? | Status |
|---|---|---|---|
| **GSAP** (`web/` + landing) | GreenSock "no-charge" (proprietary) | **Yes (web/dist)** | **CONFLICT — fix (Must-Do #3)** |
| Lenis | MIT | Yes | OK |
| Svelte | MIT | Yes | OK |
| three.js / Vanta / anime.js | MIT | Landing only (not AGPL) | OK |
| FrequencyWords Zipf tables | CC-BY-SA-4.0 | Yes (embedded) | OK — attributed in `NOTICE` |
| Gutenberg catalog texts | Public domain | Yes (embedded) | OK — verify PG trademark/header hygiene |
| Rust crates (argon2, axum, rusqlite, lettre, reqwest, openidconnect, etc.) | MIT/Apache-2.0 (typical) | Yes | Run `cargo license`/`cargo-deny` to confirm no GPL-incompatible transitive dep |
| Fonts | System fonts only (no bundled webfont) | n/a | OK |

*Recommend adding `cargo-deny` (license + advisory check) and a JS
license check to CI so a future dependency can't silently reintroduce a
conflict.*

---

## Quick reference: what to build vs. what to write

**Build (code):** account-deletion endpoint + UI; data-export endpoint + UI;
remove GSAP from `web/`; bound `signup_ip` (hash or TTL) + log retention.
**Write/publish (legal):** Impressum; privacy policy (draft: `PRIVACY.md`);
terms incl. referral + future-Pro + takedown (draft: `TERMS.md`); footer links.
**Verify (ops):** GitHub repo is public and matches the deploy; DPAs with
SMTP/host/Cloudflare; EU-US transfer basis documented.
