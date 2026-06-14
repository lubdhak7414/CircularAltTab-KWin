---
name: qml-behavior-nan-latch
description: "QML gotcha — a Behavior/NumberAnimation latches NaN permanently if its property's binding ever transiently evaluates to NaN"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 00993be5-96bd-4cca-807e-8f78df15e8fc
---

In Qt6 QML, if a numeric property has BOTH a `Behavior { NumberAnimation }` AND a binding that can transiently evaluate to `NaN`/`undefined` (e.g. `360/piecesInRing` before backing data is populated), the animation interpolates *toward* NaN and **latches there permanently** — interpolating from NaN stays NaN, so the property never recovers even after the binding later yields a valid number. Tell-tale symptom: the property reads `NaN` forever while every one of its binding inputs reads as a valid number.

Fix: guard the binding inputs so they can never produce NaN (e.g. `_private.ringPieces[ringIdx] || 1`, `arr[i] || 0`). In PieTabSwitcher this hit the `Piece` delegate's `angle`/`rotation` (both have `Behavior on …`) in `contents/ui/Pie.qml`; guarding `ringIdx`/`piecesInRing`/`idxInRing` fixed it while keeping the smooth animations.

Verifying this project's QML outside KWin: `QT_QPA_PLATFORM=offscreen qml6 file.qml`, but **stub the `org.kde.kwin` types** (`WindowThumbnail`, `TabBoxSwitcher`) — they only instantiate inside a live compositor. This environment suppresses Qt logging by default, so force `console.warn` visibility with `QT_LOGGING_RULES="js=true"` and call `Qt.quit()` at the end so buffered output flushes (otherwise `timeout`-killing the process loses it). See also [[kwin-tabbox-switcher-api]].
