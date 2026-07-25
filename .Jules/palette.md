# Palette's Journal 🎨

A record of critical UX and accessibility learnings from working on flick.

## 2026-07-23 - [Keyboard Shortcut Expectation Mismatch in Mockup UI]
**Learning:** Mockup screens and UI demonstrations often include static hints (such as "↑↓ select · enter read") that imply full functionality. However, when these shortcuts are left unimplemented, it creates an expectation-reality mismatch for both developers and accessibility tools, rendering the UI inaccessible to keyboard and screen reader users despite looking interactive.
**Action:** Always map keyboard hints to actual event handlers and ensure all lists marked with navigation hints support standard focus states, arrow keys, and keyboard triggers.
