# Self-hosting flick

flick deploys as **one binary, one static directory, one SQLite file**. No
Docker required, no external database, no message queue. This guide covers
building, configuring, running under systemd, reverse proxying, SSO, mail,
backups, and upgrades.

## Prerequisites

- **Rust** (stable) — `rustup` recommended. SQLite is bundled via `rusqlite`
  (`features = ["bundled"]`), so no system SQLite dev packages are needed.
- **Bun** — builds the web client. Only needed at build time; the server
  serves the resulting static files itself.
- Optionally: the `sqlite3` CLI on the host, for backups.

## Build

```sh
git clone https://github.com/one-more-refactor/flick && cd flick
cargo build --release -p flick-server
cd web && bun install && bun run build && cd ..
```

Artifacts:

- `target/release/flick-server` — the server binary (release profile uses LTO
  and symbol stripping).
- `web/dist/` — the built web client, served statically by the server.

## Run

```sh
./target/release/flick-server
```

From the repo root that is a complete deployment: the server finds `web/dist`
automatically, creates the data directory and `flick.db` on first start, and
listens on `0.0.0.0:8484`. To install elsewhere, copy the binary and the
`web/dist` directory and point `FLICK_WEB_DIST` at it.

## Configuration (environment variables)

All configuration is via `FLICK_*` environment variables. Everything is
optional; the defaults give a working local instance.

| Var | Meaning | Default |
|---|---|---|
| `FLICK_EDITION` | `selfhost` or `hosted`. Selfhost = everything free, no enforcement; Pro surfaces become CONTRIBUTE links. You want the default. | `selfhost` |
| `FLICK_ADDR` | Listen address | `0.0.0.0:8484` |
| `FLICK_DATA_DIR` | Data directory (SQLite database + storage) | `./data` |
| `FLICK_PUBLIC_URL` | External base URL. Used for OAuth/OIDC redirect URIs; an `https://` value turns on the `Secure` cookie attribute. | `http://localhost:8484` |
| `FLICK_WEB_DIST` | Directory of the built web client | first of `./web/dist`, `../web/dist` containing `index.html` |
| `FLICK_OIDC_ISSUER` | OIDC issuer URL — setting issuer + client id + secret enables the generic SSO button | — |
| `FLICK_OIDC_CLIENT_ID` / `FLICK_OIDC_CLIENT_SECRET` | OIDC client credentials | — |
| `FLICK_OIDC_NAME` | Label on the SSO login button | `SSO` |
| `FLICK_OAUTH_GOOGLE_CLIENT_ID` / `FLICK_OAUTH_GOOGLE_CLIENT_SECRET` | Google sign-in (OIDC) | — |
| `FLICK_OAUTH_GITHUB_CLIENT_ID` / `FLICK_OAUTH_GITHUB_CLIENT_SECRET` | GitHub sign-in (OAuth2) | — |
| `FLICK_SMTP_URL` | `smtp[s]://user:pass@host:port` for sending login codes. Unset ⇒ codes are written to the server log at `info` level (dev mode). | — |
| `FLICK_SMTP_FROM` | From address for outbound mail | `flick <no-reply@localhost>` |
| `FLICK_DROPBOX_APP_KEY` | Enables the Dropbox Chooser import | — |
| `FLICK_GOOGLE_PICKER_API_KEY` | Enables the Google Picker import (together with the Google client id) | — |

Notes:

- Credential pairs (OIDC, Google, GitHub) only take effect when **both** id
  and secret are set.
- Blank values are treated as unset.
- Uploads are capped at 25 MB per request.
- Unknown non-`/api` GET paths serve `index.html` from `FLICK_WEB_DIST` (SPA
  fallback), so client-side routes like `/read/:id` deep-link correctly.

## systemd

Create a user and an install layout:

```sh
sudo useradd --system --home /var/lib/flick --create-home flick
sudo install -D -m 755 target/release/flick-server /usr/local/bin/flick-server
sudo cp -r web/dist /var/lib/flick/web-dist
sudo chown -R flick:flick /var/lib/flick
```

`/etc/flick/flick.env` (mode 640, root:flick — it holds secrets):

```sh
FLICK_ADDR=127.0.0.1:8484
FLICK_DATA_DIR=/var/lib/flick/data
FLICK_WEB_DIST=/var/lib/flick/web-dist
FLICK_PUBLIC_URL=https://flick.example.com
# FLICK_SMTP_URL=smtps://user:pass@mail.example.com:465
```

`/etc/systemd/system/flick.service`:

```ini
[Unit]
Description=flick speed reader
After=network-online.target
Wants=network-online.target

[Service]
User=flick
Group=flick
EnvironmentFile=/etc/flick/flick.env
ExecStart=/usr/local/bin/flick-server
Restart=on-failure

# Hardening: the server only ever writes inside its data dir.
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/flick/data
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
```

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now flick
journalctl -u flick -f
```

The server handles Ctrl-C (SIGINT) gracefully; under systemd, `systemctl
stop` terminates it via plain SIGTERM, which is safe — SQLite in WAL mode
recovers cleanly on next start.

## Reverse proxy / TLS

flick serves plain HTTP; put any TLS-terminating reverse proxy in front
(Caddy, nginx, Traefik — anything that forwards to `127.0.0.1:8484`). Two
things to know:

- **Cookies:** set `FLICK_PUBLIC_URL` to the `https://` URL. That flips the
  session cookie's `Secure` attribute on and is also what OAuth/OIDC redirect
  URIs are built from.
- **Rate limiting:** the per-client key is the client IP. The first
  `X-Forwarded-For` entry is trusted **only** when the direct peer is a
  private/loopback address (loopback, RFC1918, CGNAT/tailnet 100.64/10,
  `fc00::/7`) — i.e. your proxy. Make sure the proxy sets `X-Forwarded-For`;
  most do by default.

Minimal Caddyfile:

```
flick.example.com {
    reverse_proxy 127.0.0.1:8484
}
```

## SSO / social login

All providers redirect back to paths under `FLICK_PUBLIC_URL`, so set that
first. Each provider appears as a login button once its credentials are set.

**Generic OIDC** (Authentik, Keycloak, etc.):

```sh
FLICK_OIDC_ISSUER=https://auth.example.com/application/o/flick/
FLICK_OIDC_CLIENT_ID=...
FLICK_OIDC_CLIENT_SECRET=...
FLICK_OIDC_NAME=Authentik        # button label, optional
```

Register the redirect URI at your IdP:
`<FLICK_PUBLIC_URL>/api/auth/oidc/callback`

**Google** (create an OAuth client in Google Cloud Console):

```sh
FLICK_OAUTH_GOOGLE_CLIENT_ID=...
FLICK_OAUTH_GOOGLE_CLIENT_SECRET=...
```

Redirect URI: `<FLICK_PUBLIC_URL>/api/auth/oauth/google/callback`

**GitHub** (create an OAuth App in GitHub developer settings):

```sh
FLICK_OAUTH_GITHUB_CLIENT_ID=...
FLICK_OAUTH_GITHUB_CLIENT_SECRET=...
```

Redirect URI: `<FLICK_PUBLIC_URL>/api/auth/oauth/github/callback`

Provider identities link to an existing account on a **verified**-email
match, so a user who registered with a password can later sign in with
Google/GitHub/OIDC using the same address — provided the provider attests the
email as verified.

## Mail (login codes)

Email-code login needs an SMTP relay:

```sh
FLICK_SMTP_URL=smtps://user:password@mail.example.com:465
FLICK_SMTP_FROM="flick <no-reply@example.com>"
```

`smtps://` is implicit TLS; `smtp://` is plain/STARTTLS-capable per your
relay. TLS uses rustls (no OpenSSL dependency). **If `FLICK_SMTP_URL` is
unset, login codes are not mailed — they are logged at `info` level
instead.** That is fine for a personal instance where you can read
`journalctl`, and it is how development works, but set up SMTP before giving
accounts to other people.

## Data & backups

Everything lives in `FLICK_DATA_DIR`: a single SQLite database at
`<data_dir>/flick.db` (WAL mode, so you will also see `flick.db-wal` and
`flick.db-shm` alongside it).

Do **not** back up by copying `flick.db` while the server runs — a copy can
tear between the main file and the WAL. Use `VACUUM INTO`, which produces a
consistent, compacted snapshot and is safe against a live WAL database:

```sh
sqlite3 /var/lib/flick/data/flick.db \
  "VACUUM INTO '/var/backups/flick/flick-$(date +%F).db'"
```

Systemd timer for nightly backups — `/etc/systemd/system/flick-backup.service`:

```ini
[Unit]
Description=flick SQLite snapshot

[Service]
Type=oneshot
User=flick
ExecStart=/bin/sh -c "sqlite3 /var/lib/flick/data/flick.db \"VACUUM INTO '/var/backups/flick/flick-$$(date +%%F).db'\""
```

`/etc/systemd/system/flick-backup.timer`:

```ini
[Unit]
Description=Nightly flick backup

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

```sh
sudo mkdir -p /var/backups/flick && sudo chown flick:flick /var/backups/flick
sudo systemctl enable --now flick-backup.timer
```

(If you prefer cron: `0 3 * * * sqlite3 /var/lib/flick/data/flick.db "VACUUM INTO '/var/backups/flick/flick-$(date +\%F).db'"`.)

Restoring = stop the server, replace `flick.db` with a snapshot (delete any
stale `-wal`/`-shm` files), start the server.

## Upgrades

1. Take a backup (above).
2. `git pull`, then rebuild both artifacts:
   ```sh
   cargo build --release -p flick-server
   cd web && bun install && bun run build && cd ..
   ```
3. Replace the installed binary and `web-dist` directory, restart the
   service.

Schema migrations run automatically on startup: the server checks SQLite's
`PRAGMA user_version` and applies any newer migration steps in order. There
is no separate migrate command and nothing to run by hand. Downgrading a
binary against a newer database is not supported — that's what the backup is
for.
