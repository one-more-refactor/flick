# Privacy Policy — flick (myflick.app)

> **DRAFT — not legal advice.** This draft describes what the flick codebase
> actually does as of this review. The operator must have it reviewed by a
> qualified lawyer in their jurisdiction (Germany) before relying on or
> publishing it. Placeholders in `[BRACKETS]` must be completed with real
> details. Some statements (e.g. account deletion, data export, bounded IP
> retention) describe features that **must be built before launch** — do not
> publish claims the software does not yet honor.

_Last updated: [DATE]_

## 1. Who is responsible (controller)

The controller for the hosted flick service at **myflick.app** is:

- **[FULL LEGAL NAME]**
- **[POSTAL ADDRESS — street, postal code, city, Germany]**
- Email: **[CONTACT EMAIL]**

(The same details appear in our Impressum.) We are a small independent
operator. We have not appointed a Data Protection Officer because we are not
required to; you can reach us for any privacy matter at the email above.

## 2. What flick is, and our privacy approach

flick is a speed-reading app. You can read as a **guest** without an account; an
account adds cross-device sync, stats and streaks. We deliberately keep data
collection minimal:

- **No advertising, no third-party analytics, no tracking cookies, no tracking
  pixels.** We do not sell or share your data for marketing.
- The app loads **no external fonts, CDNs or trackers** — the interface is
  self-contained.
- flick is **open source (AGPL-3.0) and self-hostable**. If you prefer, you can
  run your own instance so your data never touches our servers. The source is at
  https://github.com/one-more-refactor/flick.

## 3. What data we process, why, and on what legal basis

### 3.1 Account and profile
- **Email address** — to create and identify your account, to log you in, and to
  send login codes. *Basis: performance of a contract, Art. 6(1)(b) GDPR.*
- **Password** — stored only as a strong one-way hash (argon2id); we never store
  or see your plaintext password. *Basis: Art. 6(1)(b); security Art. 32.*
- **Display name and (optional) username** — shown in the app and to friends you
  connect with. *Basis: Art. 6(1)(b).*
- **Optional profile picture (avatar)** — if you choose to upload one; stored
  inline with your account. *Basis: your consent, Art. 6(1)(a) — you can remove
  it at any time.*
- **Preferences** — reading speed, theme, language, onboarding state. *Basis:
  Art. 6(1)(b).*

### 3.2 Sign-in with Google / GitHub / SSO (optional)
If you choose to sign in with Google, GitHub, or a single-sign-on provider, we
receive a **provider account identifier and your (verified) email** from that
provider to create or match your account. We link accounts only on a
**verified** email. *Basis: Art. 6(1)(b).* Those providers process your data
under their own privacy policies; using them is your choice.

### 3.3 Your reading content
- **Documents and books you add** (by paste, file upload, URL import, browser
  extension, or catalog) — including their **text**, computed reading timeline,
  title, author, source URL, and tags. We store this to provide the reader,
  full-text search, and cross-device sync. *Basis: Art. 6(1)(b).*
- **Reading position, per-day word counts, and reading sessions** (start time,
  duration, words, average speed) — to power progress sync, stats, streaks and
  your yearly "wrapped". *Basis: Art. 6(1)(b) and our legitimate interest in
  providing habit/stats features, Art. 6(1)(f).*
- You are responsible for the content you upload. Please don't upload other
  people's personal data or confidential material you're not entitled to share.

### 3.4 Friends and sharing (optional)
- If you connect with a **friend** via a personal link, we store that
  connection. Friends see **only aggregate numbers** — words read, streaks, and
  time. **Friends never see your document titles or content.**
- If you create a **share link** for a book, anyone with that link can read (or,
  if you allow it, import) that specific book until you revoke the link.
- *Basis: Art. 6(1)(a)/(b) — you initiate these features.*

### 3.5 Login codes
When you request an email login code, we store a short-lived hash of the code
(valid ~10 minutes, single use) and send the code to your email via our email
provider. *Basis: Art. 6(1)(b).*

### 3.6 Referral program
If you join via someone's referral link, we record who referred you and — **for
referred sign-ups only** — [a bounded record of your IP address / a salted hash
of your IP] to prevent people rewarding themselves with fake invites. We use it
solely for anti-abuse. *Basis: our legitimate interest in preventing fraud,
Art. 6(1)(f).* We keep this for no longer than needed for that purpose
[state the retention window, e.g. up to 90 days].

### 3.7 Session cookie and local storage
- **`flick_session`** — a strictly-necessary, `HttpOnly`, `SameSite=Lax`,
  `Secure` cookie that keeps you logged in (30-day lifetime). This is essential
  for the service to work and is **not** used for tracking. *Basis: Art. 6(1)(f)
  / TDDDG § 25(2) — no consent required for strictly-necessary storage.*
- **Local storage in your browser** — holds only functional settings (theme,
  language, speed) and, for guests, your local library cache. It stays on your
  device.

Because we use only a strictly-necessary cookie and functional local storage —
and no trackers or analytics — **we do not show a cookie consent banner**.

### 3.8 Server and security logs
Our servers and hosting/reverse-proxy layer keep short-term technical logs that
can include your **IP address**, request time and path, for operating the
service, security, and abuse prevention (e.g. rate limiting). *Basis:
Art. 6(1)(f).* We keep these logs for [X days] and then delete/anonymize them.

## 4. Who we share data with (processors and providers)

We do not sell your data. We use a small number of service providers who process
data on our behalf under data-processing agreements:

- **Hosting/infrastructure provider** — [NAME], where the service and database
  run. [Location].
- **Email provider (SMTP)** — [NAME], to deliver login codes and account emails.
- **Content delivery / security (if used)** — [Cloudflare, Inc.], which may
  process your IP and request metadata to route and protect traffic.
- **Sign-in providers you choose** — Google LLC and/or GitHub (Microsoft) if you
  use social sign-in.

Some of these providers are located in or transfer data to the **United States**.
Where that happens, transfers are covered by the **EU-US Data Privacy Framework**
and/or the European Commission's **Standard Contractual Clauses**. [Confirm and
name the mechanism per provider.]

## 5. How long we keep your data

- **Account and content:** for as long as your account exists. When you **delete
  your account**, we delete your profile, uploaded documents, reading stats,
  sessions, friendships and referral records. [This deletion feature is required
  before launch — do not publish this section until it works.]
- **Trash:** deleted books sit in the trash and are permanently purged after
  **30 days**.
- **Login codes:** expire after ~10 minutes and are deleted on use.
- **Sessions (auth):** expire after 30 days.
- **Referral IP record:** [bounded window — see 3.6].
- **Technical logs:** [X days].
- **Guest data:** guest reading data lives on the server tied to an anonymous
  guest session; [describe cleanup of abandoned guest accounts]. If you create
  an account while a guest, your guest library is merged into your account.

## 6. Your rights

Under the GDPR you have the right to: **access** your data (Art. 15), **correct**
it (Art. 16), **erase** it (Art. 17), **restrict** or **object** to processing
(Art. 18/21), and **data portability** (Art. 20), plus the right to **withdraw
consent** at any time (Art. 7) where processing is based on consent.

In the app you can update your profile and settings, remove your avatar, manage
friends and share links, empty your trash, **export your data**, and **delete
your account**. [Export and account-deletion must be built before these claims
are published.] You can also contact us at **[CONTACT EMAIL]** to exercise any
right; we respond within one month.

You have the right to lodge a **complaint with a supervisory authority**. In
Germany this is the data protection authority of your (or our) federal state —
for us, **[COMPETENT LANDESDATENSCHUTZBEHÖRDE]**.

## 7. Children

flick is not directed at children. You must be at least **16 years old** to use
the hosted service, or have verifiable consent from a parent/guardian as
required by German law. We do not knowingly collect data from children under 16;
if you believe a child has provided us data, contact us and we will delete it.

## 8. Security

We protect your data with, among other measures: argon2id password hashing, TLS
in transit, `HttpOnly`/`Secure` session cookies, rate limiting on
authentication and import endpoints, server-side validation and SSRF protection
on URL imports, and verified-email checks for federated sign-in. No system is
perfectly secure, but we take reasonable and appropriate technical and
organizational measures (Art. 32 GDPR).

## 9. Automated decision-making

We do **not** carry out automated decision-making or profiling that produces
legal or similarly significant effects on you.

## 10. Changes to this policy

We may update this policy as the service evolves. We will post the updated
version here and update the "Last updated" date; material changes will be
communicated appropriately.

## 11. Contact

Questions about your privacy? Email **[CONTACT EMAIL]** or write to the postal
address in Section 1.
