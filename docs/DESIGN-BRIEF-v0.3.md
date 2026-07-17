# flick v0.3 — Design Brief

Distilled from: Nothing design guidelines v3.0, Linear/Raycast/Resend/Claude design
teardowns, uiverse.io research, game-feel-juice playbook. Binding baseline:
`docs/CONTRACTS.md` tokens + `web/src/app.css`. Red family stays default; monospace,
square corners, hairlines are non-negotiable.

## 0. Corrections to the current CSS (do first)

- **Delete `--pivot-glow` entirely** (both dark blocks in app.css) — owner mandate.
  The pivot letter is pure `var(--accent)` at full value, nothing else.
- **Retire the CRT `--scanline` overlay too.** Replace the dark-theme texture
  signature with a dot-matrix grid on *hero/celebration surfaces only*:
  `background-image: radial-gradient(circle, rgba(255,255,255,0.05) 1px, transparent 1px); background-size: 18px 18px;`
  (light theme: `rgba(0,0,0,0.05)`).
- **Never tint or fade the accent** ("at full value or not at all"). No rgba() of accent.

## 1. Source principles

- **Nothing (primary):** greyscale-first, one signal accent, 8px spacing base
  (`4/8/16/24/32/48/64/96`), radius 0, dot-matrix numerals for display numbers,
  motion tokens `100ms linear` (micro) / `200ms ease-in-out` (standard) /
  `350ms ease-in-out` (screen) / `500ms linear` (sequences), **nothing over
  600ms per beat**, easing only `linear` + `ease-in-out` (no bounce/spring/
  overshoot — celebrations feel like precision machinery, not Duolingo).
  Enter = opacity 0 + 4–8px translate (never scale/zoom), exit = 80% of enter,
  30ms stagger on grouped items. Micro-label typography: 9–11px, +30–40%
  tracking, uppercase.
- **Linear:** surface-ladder elevation instead of shadows (bg → panel →
  inverse-video; never a shadow), hairline-only borders, product UI is the
  protagonist of every marketing section, 96px section rhythm, eyebrow labels.
- **Raycast:** the marketing page IS the product at scale. Keycap glyphs for
  shortcut hints (`SPACE`, `←`, `→`) as a signature element. One bright CTA per fold.
- **Resend:** true-black confidence, ONE oversized typographic hero moment per
  page, 128px hero band padding.
- **Claude:** surface-mode alternation as page pacing — alternate plain-bg bands
  with panel bands and one inverse-video (ink-bg) band. 32px card padding, never cramped.
- **game-feel-juice:** reward shape = anticipation 150–400ms → impact ≤150ms →
  follow-through 300–900ms → settle. Escalating-rarity ladder. Celebration ≤4s
  and skippable from t=0. Count-up numbers ease-out with `tabular-nums`,
  40–80ms staggers. `prefers-reduced-motion` skips to settled end-state.

## 2. Homepage (see CONTRACTS "Web client v0.3")

≤5 bands, 96px rhythm, homepage max-width ~880px. Hero: 128px pad, dot-grid
surface, eyebrow `— READ AT 600 WPM —` style tagline, one display line
(28–40px uppercase, the only oversized type), live RSVP demo as protagonist
(idle = static ORP word, plays on tap, WPM slider attached), keycap hints.
TRY band = real paste/drop panel. HOW band = inverse-video 3-up
`[01]/[02]/[03]` with 30ms stagger. Numbers band = dot-matrix stats. Footer.

## 3. Motion tokens

```css
--t-micro: 100ms linear;      /* hover, press: translateY(1px), no scale */
--t-std: 200ms ease-in-out;   /* view fades, panel enters */
--t-screen: 350ms ease-in-out;/* full-screen transitions */
--t-seq: 500ms linear;        /* choreographed sequences (streak) */
```

**Streak overlay choreography** (skippable from frame 0, ≤4s total,
reduced-motion ⇒ settled state):
0–300ms overlay+dot-grid fade-in → 300–700ms hairline rails draw in
(`transform: scaleX` 0→1) + `DAY_` label fades up 8px → 700–850ms day numeral
fills dot-by-dot (5×7 SVG dot-matrix, `steps()` fill, accent; multi-digit
count-up ease-out ~300ms, digits staggered 40–60ms) → 850–1600ms stat rows
stagger in 60ms each (dotted leaders) + 2px accent bar sweeps toward next
milestone (linear 500ms) → settle ≥1s, `CONTINUE_` only appears now.
Escalation: days 2–6 inline stat tick only; overlay at day 1, 7, 30, 100, 365.
Never re-fire a seen milestone.

**Micro:** button press `translateY(1px)` 100ms linear; pause = rail notches
blink once; slider thumb NO transition (instrument-direct); list rows 30ms
stagger on first paint only.

## 4. Accent slot (see CONTRACTS token table)

`--red` → `--accent` (keep `--red` as alias). 6 curated pairs via
`data-accent` on root. `mono` = accent equals ink; reader pivot renders
inverse-video (ink block, bg letter). Picker = 6 swatch buttons in the
theme-grid pattern, instant preview.

## 5. Component techniques (plain CSS, zero deps)

- **Terminal status loader** (replaces all spinners): three 6px square dots
  dim→accent filled sequentially `steps(3)` + label with trailing dots via
  `::after` width-clip `steps(4)`. Label style: `PARSING...`
- **Keycaps:** `kbd { border: 1px solid var(--line); border-bottom-width: 2px;
  padding: 1px 6px; font-size: 10px; letter-spacing: .1em; }` — no radius.
- **Hover fill-wipe buttons:** `background: linear-gradient(var(--accent),
  var(--accent)) no-repeat left / 0% 100%;` → transition background-size to
  `100% 100%` in 150ms linear.
- **Blinking-caret type-on** for the hero headline (`width` + `steps(n)`,
  600ms cap, reduced-motion shows final state).
- **Dotted-leader stat rows** as a general primitive (library, streak, stats).
- NO WebGL/3D/mouse-trails/glassmorphism/gradients-as-decoration.

## 6. Numbers

`font-variant-numeric: tabular-nums` on every numeral. Hero-scale numbers
(streak day, stats heroes) = 5×7 dot-matrix digits as inline SVG circles from
per-digit bitmask arrays (~30 lines of Svelte), min rendered size 24px,
display-only. Counters count up ease-out 250–400ms on first paint, 40ms stagger.

## 7. Identity check

Every new surface: *would this look at home on the back of a Nothing Phone
rendered by a receipt printer?* Greyscale + one full-value accent, square,
monospace, ≤600ms linear/ease-in-out motion, information over decoration.
Language picker = text codes (`EN / DE`), never flag emoji.
