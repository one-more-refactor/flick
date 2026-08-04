## 2026-07-27 - Encoding and Character Corruption in HTML Mockups
**Learning:** HTML mockup files lacking a declared `<meta charset="utf-8">` and proper DOCTYPE template default to legacy encodings (like ISO-8859-1) on local filesystems or standard dev servers. This corrupts accessibility symbols and special characters (e.g., UI indicators like `·` and `▶`), creating a broken screen reader and visual experience.
**Action:** Always wrap mockup files in a standard DOCTYPE, html structure, and explicitly define `<meta charset="utf-8">` inside the `<head>` of the document as the very first element.

## 2026-07-28 - Raycast-Style Keycap Hints for Monospace Interfaces
**Learning:** Monospace terminal/minimalist web mockups can feel text-heavy and make keyboard-navigable shortcuts obscure. Semantic `<kbd>` tags with high-contrast, square-corner, 1px/2px offset borders establish a strong visual metaphor of hardware keycaps, making accessibility controls instantly recognizable to power users without relying on distracting icons or colors.
**Action:** Use a no-radius, high-contrast, double-layered bottom border `<kbd>` keycap pattern to elevate discoverability of keyboard commands in monospace design systems.

## 2026-08-04 - Dynamic Interaction Handling in Static Mockup Prototyping
**Learning:** Adding dynamic, functional flows to static HTML mockup pages requires safe event rebinding and secure DOM parsing. When dynamically appending items (like newly uploaded books) to active element list systems (which are parsed initially to construct selection models), event listeners must be re-bound cleanly, element properties must be modified using safe APIs like `textContent`, and keyboard inputs should be guarded by checking focused states to avoid hijacking browser interactions.
**Action:** Ensure dynamic additions to list elements in mockup pages cleanly update counter elements, dynamically re-bind interaction listeners, and guard global hotkey listeners using focused state checks.
