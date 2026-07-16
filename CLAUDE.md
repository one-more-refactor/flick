# flick — agent notes

- `docs/CONTRACTS.md` is the source of truth (timeline format, API, config, design tokens). Change it first, code second.
- `docs/mockup.html` is the living design reference — the app must look like this.
- Rust workspace: `core/` (flick-core, pure logic, no I/O) + `server/` (flick-server, axum). Web: `web/` (Bun + Svelte 5 + Vite + TS).
- Red `#E02D2D`/`#F53B30` is the ONLY accent color. Monospace only. Square corners.
- The reading engine logic (ORP, weights) lives ONLY in flick-core. Never reimplement it in a client — clients play timelines.
- Reader scheduling must be requestAnimationFrame-accumulator based, never setTimeout chains.
- Use `bun` (not npm/node) for everything in `web/`.
- Verify: `cargo test && cargo clippy --workspace` and `cd web && bun run check && bun run build`.
