---
name: pie-no-hover-5050-expansion
description: PieTabSwitcher decision — hover-driven 50/50 slice expansion was tried and reverted; use equal fixed slices
metadata: 
  node_type: memory
  type: project
  originSessionId: 00993be5-96bd-4cca-807e-8f78df15e8fc
---

The "selected window takes ~50% of the pie" idea (from COMMENTS.md #1) was implemented then **reverted** (2026-06-15) for the mouse/hover flow. Equal, fixed-size slices are used instead; the active window is emphasized without moving anything: dimmed non-selected slices + a small radial `scale` pop (1.06) on the selected + the centre pointer + caption.

**Why:** ballooning the hovered slice to 180° necessarily reflows every other slice away from its home angle. Whatever you point at then moves, and the slice you *see* stops matching its clickable wedge → selection "jumps to another window" and feels uncontrollable. It is an inherent conflict between hover-selection and dynamic re-layout (no hit-testing scheme fixes it: stable wedges break point-at-what-you-see; dynamic wedges get sticky/thrash).

**How to apply:** keep `Piece` slices at `angle = 360/n` and `rotation = idxInRing*centralAngle` (constant per item) in `contents/ui/Pie.qml`. Emphasize selection via opacity / scale / the pointer, never via angular size or position. If a "big active window" feel is wanted later, do it without moving the other slices (e.g. a large preview in the centre hole) or gate the 50/50 to keyboard-only navigation. See [[qml-behavior-nan-latch]], [[kwin-tabbox-switcher-api]].
