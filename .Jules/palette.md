## 2026-07-27 - Encoding and Character Corruption in HTML Mockups
**Learning:** HTML mockup files lacking a declared `<meta charset="utf-8">` and proper DOCTYPE template default to legacy encodings (like ISO-8859-1) on local filesystems or standard dev servers. This corrupts accessibility symbols and special characters (e.g., UI indicators like `·` and `▶`), creating a broken screen reader and visual experience.
**Action:** Always wrap mockup files in a standard DOCTYPE, html structure, and explicitly define `<meta charset="utf-8">` inside the `<head>` of the document as the very first element.

## 2026-07-28 - Raycast-Style Keycap Hints for Monospace Interfaces
**Learning:** Monospace terminal/minimalist web mockups can feel text-heavy and make keyboard-navigable shortcuts obscure. Semantic `<kbd>` tags with high-contrast, square-corner, 1px/2px offset borders establish a strong visual metaphor of hardware keycaps, making accessibility controls instantly recognizable to power users without relying on distracting icons or colors.
**Action:** Use a no-radius, high-contrast, double-layered bottom border `<kbd>` keycap pattern to elevate discoverability of keyboard commands in monospace design systems.

## 2026-08-13 - State-Aware Accessible Mockup Toggles & File Ingestion
**Learning:** For mockup interfaces (such as speedreaders), state-aware accessibility controls (such as using `aria-pressed` on Play/Pause buttons) are crucial. Furthermore, allowing user-provided text file uploads using `FileReader` in a static mockup, combined with safe DOM manipulation (`textContent` and `document.createElement`), provides an immersive experience while strictly safeguarding against XSS.
**Action:** Use `aria-pressed` for media playback buttons in mockups and dynamically create elements using safe DOM APIs instead of `innerHTML` to securely render custom file inputs.
