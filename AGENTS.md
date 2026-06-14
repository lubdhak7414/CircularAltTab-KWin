# AGENTS.md

## What this is

KWin TabBox window switcher for KDE Plasma 6 — a QML KPackage (`KPackageStructure: KWin/WindowSwitcher`, plugin Id `pie`). Interpreted at runtime by KWin, **not compiled**. No Makefile, CMake, test suite, or lint config exists.

## Files

Three QML files under `contents/ui/`:

- `main.qml` — KWin integration (`KWin.TabBoxSwitcher` root), hosts the frameless `Window`, center overlay (needle + caption), fade in/out logic
- `Pie.qml` — layout engine: ring distribution, hit-testing (`getPieIdx`), MouseArea, Repeater for pieces, implicit size calculation
- `Piece.qml` — one annular sector: Canvas mask + OpacityMask, window thumbnail, icon, accent ring

`metadata.json` — KPackage metadata (name "Pie", id "pie")

## Deploy and reload

The package must live at `~/.local/share/kwin/tabbox/pie/`. **Ensure it is a symlink to the repo:**

```sh
ln -sfn "$PWD" ~/.local/share/kwin/tabbox/pie
```

After editing, reload KWin to pick up changes. The switcher is rendered by **KWin**, not Plasma:

```sh
kwin_wayland --replace &   # Wayland
kwin_x11 --replace &       # X11
```

`plasmashell --replace` reloads Plasma shell but **not** reliably the KWin switcher QML. A lighter alternative: switch the Task Switcher visualization away from "Pie" and back in System Settings.

Select it: System Settings → Window Management → Task Switcher → Visualization → **"Pie"**.

## Key conventions

- **Inline comments are in Russian.** Match the surrounding language when editing.
- **Two angle systems coexist — do not mix them:**
  - Layout/positioning: degrees, 0° = top (12 o'clock), clockwise (`atan2(tx, -ty)`)
  - Canvas painting (`Piece.qml`): radians, standard canvas orientation (`Math.PI*1.5` / `-Math.PI/2` offsets)
- **Model roles from KWin TabBox model** (not defined in this repo): `caption`, `icon`, `windowId`, `minimized`, `closeable`, `desktopName`. Methods: `activate(int)`, `close(int)`.
- **Qt 6 / Plasma 6 imports**: versionless (`import QtQuick`), `org.kde.kwin`, `org.kde.ksvg`, `org.kde.kirigami`, `Qt5Compat.GraphicalEffects` (for `OpacityMask`)

## Gotchas

- **Implicit size is geometry-driven.** `Pie.implicitHeight` = `inRadius*2 + (ringHeight+ringSpacing)*ringsCount*2 + scale padding`. Changing piece dimensions or ring count requires updating this formula, or the window clips pieces.
- **Scale transform origin matters.** Pieces scale from `Item.Center` (not `Item.Bottom`) to avoid clipping outside the window. Rotation still uses bottom-center origin via an explicit `Rotation` transform in the `transform` array.
- **Accent ring is drawn inward.** The accent ring Canvas offsets arcs inward by `lineWidth/2` so the stroke stays inside the piece boundary — no extra padding needed on inactive pieces.
- **Piece width = chord, not 2*rOut.** Width is `chord1` (chord of central angle at rOut). The mask arc extends `offset` beyond chord at the midpoint, but adjacent pieces on the same ring cover this overlap.
- **`bg` margins exclude scale padding.** The background circle uses `anchors.margins` matching the scale padding so it only covers the actual pie content area.
- **Deployed copy can drift.** If not symlinked, edits to the repo have no effect until manually copied. Always verify the symlink exists.
- **No 50/50 slice expansion.** The "selected window = 50% of pie" idea was tried and reverted — reflowing slices on hover makes selection jump uncontrollably. Keep slices at `angle = 360/n`, emphasize selection via opacity/scale/pointer only. See `memories/pie-no-hover-5050-expansion.md`.
- **Behavior + NaN = permanent latch.** If a property has `Behavior { NumberAnimation }` and its binding transiently evaluates to `NaN`, the animation interpolates toward NaN and **latches forever**. Guard all binding inputs (e.g. `arr[i] || 0`, `360/piecesInRing` → guard `piecesInRing`). See `memories/qml-behavior-nan-latch.md`.
- **No `count` on TabBoxSwitcher.** Use `model.count` or a Repeater's `.count` — the switcher itself has no `count` property.
- **Verifying QML outside KWin:** `QT_QPA_PLATFORM=offscreen qml6 file.qml` — but stub `org.kde.kwin` types (they only work in a live compositor). Use `QT_LOGING_RULES="js=true"` for console output and call `Qt.quit()` to flush buffered output.

## Reference

- KWin TabBox API: https://github.com/KDE/kwin/ (`src/tabbox/`)
- Plasma KWin API docs: https://develop.kde.org/docs/plasma/kwin/api/
- Detailed improvement plan: `PLAN.md`
