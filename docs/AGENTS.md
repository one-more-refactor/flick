# The agent surface

What a flick server publishes so that automated clients can find it, describe
it and use it without being told. Everything here is served by `flick-server`
from documents embedded in the binary, rendered against `FLICK_PUBLIC_URL` —
a self-hosted instance advertises itself correctly with no extra configuration
and no files to copy.

The implementation is `server/src/discovery.rs` (documents, `Link` headers,
markdown negotiation) and `server/src/mcp.rs` (the MCP endpoint), with the
source documents under `server/assets/agents/`.

## What is published

| Path | Type | What it is |
|---|---|---|
| `/.well-known/api-catalog` | `application/linkset+json` | RFC 9727 catalog: the API and its description, docs, status and auth links |
| `/openapi.json` | `application/json` | OpenAPI 3.1 description of the public API (`service-desc`) |
| `/docs/api` | `text/markdown` | Prose API documentation (`service-doc`) |
| `/auth.md` | `text/markdown` | How an agent gets a credential, with an `agent_auth` block |
| `/.well-known/mcp/server-card.json` | `application/json` | SEP-1649 card pointing at `/mcp` |
| `/mcp` | JSON-RPC | Model Context Protocol, streamable HTTP |
| `/.well-known/agent-skills/index.json` | `application/json` | Agent Skills Discovery v0.2.0 index, with sha256 digests |
| `/.well-known/agent-skills/{name}/SKILL.md` | `text/markdown` | The skills themselves |
| `/llms.txt` | `text/plain` | Plain-language summary of the product |
| `/robots.txt` | `text/plain` | Allows everything; declares Content-Signals |

Every HTML response carries a `Link` header (RFC 8288) pointing at the
catalog, the OpenAPI description, the docs, the MCP card, `llms.txt`, the
skills index and the licence — so an agent that fetches nothing but the
homepage still finds all of it.

Anything else under `/.well-known/` answers a JSON `404`. That matters: the
SPA fallback would otherwise return `200` and an HTML shell for every probe,
which reads to a scanner as "this document exists and is malformed" rather
than "not published".

## Markdown for agents

`GET /` and `GET /science` return `text/markdown` instead of HTML when the
request sends `Accept: text/markdown`, with an `x-markdown-tokens` estimate
and `Vary: Accept`. The default `Accept` a browser or curl sends (`*/*`,
`text/html,…`) does **not** trigger this — only an explicit `text/markdown`
does, because a wildcard means "anything", not "markdown please".

The markdown twins live in `server/assets/agents/index.md` and `science.md`.
They duplicate content that also exists in the Svelte views; when either page
changes materially, change the twin too.

## The MCP server

`POST /mcp`, protocol revision `2025-06-18`, answered as a single JSON body —
no SSE stream, because every tool returns in one shot and there is no session
state to keep. `GET /mcp` is a `405`.

| Tool | Session? | What it does |
|---|---|---|
| `preview_timeline` | no | Text → paced timeline: pivot letters, per-word weights, reading time |
| `list_catalog` | no | The built-in public-domain works |
| `server_info` | no | Edition, version, where the docs are |
| `search_library` | yes | Full-text search of the caller's own books |
| `get_book_text` | yes | A book's text, paginated, indices aligned to the timeline |
| `save_text` | yes | Add a passage to the library |
| `import_url` | yes | Fetch and add a web article, under the SSRF guard |
| `reading_stats` | yes | Words today, totals, goal, streak |

Every tool is a thin front for logic that already exists elsewhere in the
server — the same engine, the same catalog, the same importer, the same
per-user scoping. Nothing is reimplemented for agents, so an agent and the web
client cannot drift apart.

**Security posture.** Auth is the ordinary `flick_session` cookie. `/mcp` is
deliberately **not** in the CORS allow-list, and the cookie is `SameSite=Lax`,
so a hostile page cannot drive a signed-in user's library from their browser.
`import_url` charges the same rate-limit bucket as `POST /api/import/url`, so
MCP is another door onto the outbound fetcher, not a second allowance; `/mcp`
as a whole has its own coarse per-client ceiling.

## WebMCP

The web client calls `navigator.modelContext.provideContext()` when the
browser supports it (`web/src/lib/webmcp.ts`), exposing the actions the HTTP
API cannot perform from outside: opening a book in *this* reader and changing
the speed of the running stream, plus the read-only tools an agent needs to
decide what to open. Feature-detected — a no-op everywhere the API is absent.

## Content signals

`robots.txt` declares `Content-Signal: ai-train=yes, search=yes, ai-input=yes`.
That is a deliberate position, not a default: the project is AGPL-3.0, the site
is documentation and marketing for it, and being findable and quotable is the
point. If that ever changes, `web/public/robots.txt` is the one place to
change it.

## Not published, on purpose

**OAuth authorization-server metadata** (`/.well-known/oauth-authorization-server`)
and **protected-resource metadata** (`/.well-known/oauth-protected-resource`).

flick is an OAuth/OIDC *client*, never an authorization server: a federated
login is exchanged for a first-party session cookie, and the identity
provider's tokens are not accepted as flick API credentials. There is no
bearer flow for user-facing calls, no refresh token and no introspection
endpoint. Publishing that metadata would send agents down a path that cannot
work, so `/auth.md` documents the real mechanism instead and says why the
metadata is absent.

Scanners that check for these two documents will keep reporting them missing.
That is the correct outcome. It would only change if flick grew real
token-based API auth, at which point the metadata should be published because
it would be true.

## Pending: DNS-AID

Not done — it needs DNS records on the `myflick.app` zone, which is a
Cloudflare change rather than a code change.

[DNS for AI Discovery](https://datatracker.ietf.org/doc/draft-mozleywilliams-dnsop-dnsaid/)
publishes agent entry points as ServiceMode SVCB records under
`_agents.<domain>`, so a resolver can find an agent surface without an HTTP
round trip. It is an early IETF draft with no adoption call yet, so this is a
cheap flag to plant rather than something load-bearing.

Two records, on the `myflick.app` zone:

```
_index._agents.myflick.app.  3600  IN  SVCB  1 myflick.app. (
                                      alpn="h2,http/1.1"
                                      port=443
                                      dohpath="/.well-known/api-catalog" )

_mcp._agents.myflick.app.    3600  IN  SVCB  1 myflick.app. (
                                      alpn="h2,http/1.1"
                                      port=443
                                      dohpath="/mcp" )
```

In the Cloudflare dashboard these are added under **DNS → Records → Add
record → SVCB**, with:

- Name: `_index._agents` (and `_mcp._agents`)
- Priority: `1` (ServiceMode — priority 0 would be AliasMode, which is wrong here)
- Target: `myflick.app`
- Value: `alpn="h2,http/1.1" port=443`

The draft's `endpoint` parameter has no dashboard field yet; the `dohpath`
key above is the closest registered stand-in and is what the path is carried
in until the draft settles. Re-check the draft before treating these as final.

Sign the zone with DNSSEC (Cloudflare: **DNS → Settings → DNSSEC → Enable**)
so validating resolvers get authenticated answers — without it the records are
publishable but not trustworthy, which is most of the point.

## Pending: the origin split

The agent surface is served by `flick-server`. As long as `myflick.app` is
served by anything else, none of it appears on the apex — only on whichever
host reaches the server. See the deployment notes before assuming a scan of
the apex reflects this code.
