# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A KWin **window switcher** (TabBox visualization) for KDE Plasma 6, written entirely in QML. Instead of the usual Alt-Tab list, it draws the open windows as sectors of concentric rings (a "pie"/donut) centered on the mouse cursor. It is a KPackage (`KPackageStructure: KWin/WindowSwitcher`, plugin `Id: pie`), not a compiled application.

## No build / test / lint system

This is interpreted QML loaded by KWin at runtime — there is no Makefile, CMake, package.json, test suite, or lint config, and you should not look for one. "Running" it means deploying the package and asking KWin to re-read it.

## Develop / run loop

The package must live at `~/.local/share/kwin/tabbox/pie/` for KWin to find it. **This repo is the source; edits here have no effect until they are copied there.** (The currently deployed copy is a plain copy, not a symlink, so it can drift out of sync with the repo.) A one-time symlink avoids the copy step:

```sh
ln -sfn "$PWD" ~/.local/share/kwin/tabbox/pie
```

Select it: System Settings → Window Management → Task Switcher → Visualization → **"Pie"** (the name comes from `metadata.json`).

Reload after editing. Per the README, `plasmashell --replace` reloads Plasma without killing the session. Note that the switcher is rendered by **KWin**, so forcing KWin to re-read the QML means `kwin_wayland --replace` or `kwin_x11 --replace` — but the README warns those restart apps in the user session (replacing the Wayland compositor restarts the whole session), which is why it prefers the gentler `plasmashell --replace`.

## Architecture

Three QML files under `contents/ui/`, layered from KWin integration down to a single rendered slice:

- **`main.qml` — KWin integration.** Root is a `KWin.TabBoxSwitcher`, which exposes `model` (the window list) and `currentIndex` (keyboard selection). It hosts a frameless, transparent, `BypassWindowManagerHint` `Window` that is re-centered on `KWin.Workspace.cursorPos` every time it becomes visible. Selection is synced two ways: `tabBox.currentIndex → pie.current` (keyboard), and a mouse click activates the hovered piece via `tabBox.model.activate(pie.current)`. Also holds the center clock overlay.

- **`Pie.qml` — layout + hit-testing engine.** Distributes windows across concentric rings according to the `ringPieces` array; any overflow falls into the last ring. `_private.updateData()` rebuilds three parallel arrays indexed by item: `pieceToRing`, `ringPieces` (actual per-ring counts), and `idxsInRing`. `getPieIdx(x,y)` converts a cursor position to polar coordinates to find the piece under it. A hover-enabled `MouseArea` drives `pie.current` (and resets it to `-1` when the cursor leaves). A `Repeater` (`pices`) instantiates one `Piece` per window and computes each piece's radii (`rIn`/`rOut`), central `angle`, and `rotation`. The hover "zoom" effect lives here: the focused piece's `angle` grows by `zoom` while its ring-mates shrink and rotate to make room, animated via `Behavior on angle`/`rotation`.

- **`Piece.qml` — one window slice (annular sector).** A `Canvas` paints the donut-segment shape and is applied as an `OpacityMask` layer effect to clip the slice's contents to that curved shape. Inside the slice: a live `KWin.WindowThumbnail` (`wId: windowId`) and a `Kirigami.Icon` (`model.icon`), both counter-rotated by `-rotation` so they stay upright while the slice itself is rotated into angular position about its bottom-center (the pie's center).

## Conventions & gotchas

- **Inline comments are in Russian.** Match the surrounding language when editing nearby.
- **Two angle conventions coexist — don't mix them.** Layout/positioning uses **degrees, 0° at the top (12 o'clock), increasing clockwise** (note `getPieIdx`'s `atan2(tx, -ty)`). The `Canvas` mask in `Piece.qml` uses **radians in standard canvas orientation**, which is why its arcs carry `Math.PI*1.5` / `-Math.PI/2` offsets.
- **Model roles come from KWin's TabBox model**, not from this code: `model.icon` and `windowId` on each delegate, plus `currentIndex` and `activate()` on `tabBox.model`.
- **Qt 6 / Plasma 6 imports**: versionless (`import QtQuick`), with `org.kde.kwin`, `org.kde.ksvg`, `org.kde.kirigami`, and `org.kde.plasma.*`. `OpacityMask` specifically comes from `Qt5Compat.GraphicalEffects`.
- Overall size is geometry-driven: `implicitHeight = inRadius*2 + (ringHeight + ringSpacing) * ringsCount * 2`, and a piece's width is the chord of its central angle.

## Reference

KWin TabBox / model API: the upstream sources (https://github.com/KDE/kwin/) and the Plasma KWin API docs (https://develop.kde.org/docs/plasma/kwin/api/), both linked from `main.qml`.
