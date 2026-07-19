# Contributing to flick

Thanks for looking under the hood. flick is small on purpose; keeping it that
way is most of the review criteria.

## Issue first

- **Features and behavior changes:** open an issue before writing code. The
  product has a deliberately narrow shape (guest-first, one engine, thin
  clients) and plenty of reasonable features don't fit it — an issue costs
  minutes, an unmergeable PR costs an evening.
- **Small fixes** (typos, obvious bugs, doc corrections): skip the issue,
  send the PR directly.

## Contracts first

[`docs/CONTRACTS.md`](docs/CONTRACTS.md) is the binding document for the
timeline format, HTTP API, server config, and design tokens. The rule is
mechanical:

1. If your change alters anything specified there, change **CONTRACTS.md in
   the same PR, first commit**.
2. Code follows the document, never the other way around.

Two consequences worth internalizing:

- The reading-engine logic (ORP rule, timing weights) lives **only** in
  `flick-core`. Clients play timelines; they never reimplement engine logic.
- Client playback scheduling is requestAnimationFrame-accumulator based,
  never setTimeout chains.

## Where the code lives

flick is split into focused repos; contribute in the one you're changing, and
keep [`docs/CONTRACTS.md`](docs/CONTRACTS.md) (here, in the umbrella) as the
shared source of truth:

- [**flick-backend**](https://github.com/one-more-refactor/flick-backend) — the engine (`flick-core`) and API server (`flick-server`).
- [**flick-web**](https://github.com/one-more-refactor/flick-web) — the Svelte web client.
- [**flick-landing**](https://github.com/one-more-refactor/flick-landing) — the marketing site.
- [**flick-admin**](https://github.com/one-more-refactor/flick-admin) — the server admin panel, built on [corepanel](https://github.com/one-more-refactor/corepanel).

## Verify

Must pass clean before a PR, in the repo you touched:

```sh
# flick-backend
cargo test --workspace && cargo clippy --all-targets -- -D warnings

# flick-web  (use bun, not npm/node)
bun run check && bun run build
```

## Code style

- Comments explain **constraints, not narration** — why the code must be this
  way, not what the next line does. If a comment restates the code, delete
  it.
- Match the surrounding style; don't reformat code you aren't changing.
- UI work must match `docs/mockup.html` and the design tokens in
  CONTRACTS.md: one accent slot, monospace, square corners, no glow, no
  shadows.

## License — no CLA

flick is AGPL-3.0 and there is **no Contributor License Agreement**.
Contributions are accepted inbound=outbound: by submitting a PR you license
it under the project's AGPL-3.0 terms, and you keep your copyright. Because
copyright stays distributed across all contributors, nobody — including the
maintainer — can ever relicense the project under a closed license. That
guarantee is the point.
