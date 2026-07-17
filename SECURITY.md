# Security policy

## Supported versions

The latest release (and the current `main` branch). There are no backport
branches; fixes ship as a new release.

## Reporting a vulnerability

Please report vulnerabilities **privately via GitHub security advisories**
(the "Report a vulnerability" button under the repository's Security tab). Do
not open a public issue for anything exploitable.

You can expect an acknowledgment within a few days. This is an indie project
— there is **no bug bounty** — but reporters get credit in the advisory and
release notes (or anonymity, if preferred).

## Scope notes

Areas worth attention, roughly in order of interest:

- **Auth**: session cookies (`flick_session`, HttpOnly, SameSite=Lax, Secure
  behind TLS), the email-first login flow, email login codes, OAuth/OIDC
  callback handling, guest-session minting.
- **Uploads & parsers**: PDF, EPUB, TXT, and Kindle-clippings parsing of
  attacker-supplied files (25 MB limit), plus HTML extraction for imports.
- **URL import / SSRF**: `POST /api/import/url` fetches user-supplied URLs.
  The guard resolves DNS, rejects non-global addresses (loopback, RFC1918,
  CGNAT, link-local, ULA, v4-mapped v6), and pins the connection to the
  vetted IP to prevent rebinding. Bypasses of this guard are squarely in
  scope.
- **Rate limiting**: the `X-Forwarded-For` trust rule (only honored from
  private/loopback peers) and anything that lets a client dodge the auth
  endpoint limits.
- **Access control**: all book/stats routes are scoped to the session user;
  any cross-user read or write is a serious bug.

Out of scope: denial of service via volume alone, reports about missing
security headers on a bare (unproxied) HTTP deployment, and anything
requiring a compromised host.
