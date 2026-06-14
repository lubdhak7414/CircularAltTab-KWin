# PieTabSwitcher-KWin — Improvement Plan

Improvements derived from `COMMENTS.md` plus a code/UX/robustness sweep and a verified
KWin Plasma 6 API check. File/line references point at the current tree
(`contents/ui/{main,Pie,Piece}.qml`).

---

## Decisions needed before implementation

These materially change the work; confirm them first.

- **D1 — What is "the main window" (Feature 1)?** The KWin TabBox model exposes **no
  "active window" role** (see Appendix). Two readings:
  - **(A) the currently *selected* window** — the slice grows as you hover/Tab. ✅ Recommended; clean (`pie.current`).
  - (B) the window you're switching *away from* — a fixed big slice. ⚠️ Only inferable as `index === 0`, and only in "stacking order" mode; not robust.
- **D2 — What goes in the center circle (Feature 2)?** `pointer` / `caption label` / `both`.
  With Feature 1 the selected slice is already huge, so a caption ("what is selected")
  may add more than a pointer ("where it is"). Recommended: **both** (pointer + caption), plus an accent ring on the slice.
- **D3 — Fade behavior (Feature 3).** Confirm the interpretation: fade in on show, fade
  out to transparent on hide, un-map only once fully transparent (no abrupt opaque pop).
- **D4 — App grouping (Feature 4).** Confirm the default grouping key is `model.icon`
  (windows sharing an app icon group into one slice), and that drilling into a group **dims
  the outer pie + reveals a sub-pie** (vs. expanding the group in place).

---

## Feature 1 — Selected window = 50% of the pie  *(COMMENTS.md #1)*

> "the main window take up 50% of the pie chart, and all the other windows share the remaining 50% in equal sizes."

**Scope:** single-file change in `Pie.qml`, delegate bindings (~lines 129–142), ~10–15 line diff.

**Layout math** (`rotation` is the slice's angular *center*, deg, 0°=top, clockwise — verified):
- Selected piece: `angle = 180`, `rotation = 0` (centered at top).
- Each other piece: `angle = 180/(n-1)`, tiled clockwise across the bottom half:
  - `rank = (idxInRing - idxCurrentInRing + n) % n`   (1..n-1, clockwise from selected)
  - `rotation = 90 + (rank - 0.5) * otherAngle`
- Tiles a full 360° with **no gaps/overlaps** (verified for n=4).

**Proposed bindings (replace the `angle`/`rotation` block in the delegate):**
```qml
readonly property int rankFromCurrent: (idxCurrentInRing < 0)
    ? -1 : (idxInRing - idxCurrentInRing + piecesInRing) % piecesInRing
readonly property double otherAngle: (piecesInRing > 1) ? 180.0 / (piecesInRing - 1) : 360.0

angle: (!currentInThisRing || piecesInRing < 3)
    ? centralAngle
    : (pie.current === index ? 180.0 : otherAngle)

rotation: (!currentInThisRing || piecesInRing < 3)
    ? (idxInRing * centralAngle)
    : (pie.current === index ? 0.0 : 90.0 + (rankFromCurrent - 0.5) * otherAngle)
```

**Edge cases (decided):** gate the split behind `piecesInRing >= 3` → n=1 and n=2 fall
back to the equal split (also avoids the `180/(n-1)` and existing `zoom/(n-1)`
divide-by-zero). `current == -1` → equal split (neutral). Multi-ring → applies per-ring,
only to the ring containing the selection (default config is single-ring anyway).

**Free wins:** `getPieIdx` reads live `rotation`/`angle`/`rIn`/`rOut` and already handles
the 360°/0° wraparound → **no hit-test changes.** Existing 100 ms `Behavior on angle/rotation`
animates it for free. `zoom`, `b`, `b2` become dead → remove.

**Risk to watch:** a 180°-wide slice is wide and short, so the selected thumbnail gets
scaled up and cropped (`Piece.qml:72`). Acceptable for a focus slice, but the main visual
unknown — eyeball it live.

---

## Feature 2 — Make the selection stand out  *(COMMENTS.md #2)*

> "ditch the datetime in the inner circle and try a pointer instead."

**Pointer** — replace `centerItem` (`main.qml:39–60`) with a triangle/needle `Canvas` in
the inner circle, rotated to the selected slice:
- Add an accessor to `Pie.qml`: `function currentAngle() { return (current>=0 && current<pices.count) ? pices.itemAt(current).rotation : NaN }`
- Bind the needle's `rotation` to `pie.currentAngle()`.
- Animate with **`RotationAnimation { direction: RotationAnimation.Shortest }`** — *not*
  `NumberAnimation`, which spins the long way when wrapping last→first item.
- `current == -1`: hide the needle but hold its last angle (no snap-to-top flicker).
  Empty model → `NaN` → hidden.

**Stronger emphasis (both EASY, recommended alongside the pointer):**
1. **Caption in the center** — show `model.caption` of the selected window (currently
   unused anywhere in the repo). Pointer = where, caption = what.
2. **Accent ring on the selected slice** — second `ctx.stroke()` on the existing arc path
   in `Piece.qml` (lines 57–60) using `Kirigami.Theme.highlightColor`, gated on `pie.current === index`.

More involved (defer): desaturate/dim non-selected slices (needs an extra layer effect
since the `OpacityMask` already occupies `layer.effect`), drop-shadow/scale on selected.

---

## Feature 3 — Smooth fade in/out on show/hide  *(NEW)*

> "appear smoothly, disappear smoothly to transparent, then at last moment just shown full opaque."

**Today:** `wnd.visible` is bound directly to `tabBox.visible` (`main.qml:21`), so the
window pops in/out abruptly at full opacity — no fade.

**Goal:** fade opacity 0→1 on show, 1→0 on hide, and **un-map the window only once it is
fully transparent** (the "last moment"), so there's never an opaque pop.

**Approach** — decouple `visible` from `tabBox.visible` and drive `opacity`:
```qml
Window {
    id: wnd
    visible: false          // managed manually now
    opacity: 0.0
    color: "transparent"
    // ...flags, size...

    Connections {
        target: tabBox
        function onVisibleChanged() {
            if (tabBox.visible) {
                wnd.x = KWin.Workspace.cursorPos.x - wnd.width / 2;
                wnd.y = KWin.Workspace.cursorPos.y - wnd.height / 2;
                pie.updateData();
                wnd.visible = true;     // map first
                wnd.opacity = 1.0;      // then fade in
            } else {
                wnd.opacity = 0.0;      // fade out; unmap on finish (below)
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 150               // → Kirigami.Units.longDuration once theming lands
            easing.type: Easing.InOutQuad
            onFinished: if (wnd.opacity === 0.0) wnd.visible = false;  // unmap only when transparent
        }
    }
}
```

**Notes / risks:**
- KWin exposes `aboutToShow()` / `aboutToHide()` signals on `TabBoxSwitcher` — viable
  alternative hooks if `onVisibleChanged` timing misbehaves.
- Window-level `opacity` needs compositing (always true for this switcher, which relies on
  `WindowThumbnail`). If window opacity composites oddly under the `BypassWindowManagerHint`
  flag, fall back to animating the **root content item's** `opacity` instead and keep
  `visible` bound as today.
- Verify KWin doesn't tear the switcher down the instant `tabBox.visible` goes false; the
  150 ms delayed un-map assumes the item persists (it normally does across invocations).
- Keep the duration short (~120–150 ms) so Alt+Tab still feels instant.

---

## Additional QoL features

Curated for implementability against the confirmed model roles (`caption`, `desktopName`,
`icon`, `windowId`, `minimized`, `closeable`), slots (`activate(int)`, `close(int)`), and the
writable `currentIndex`. Ideas needing data the API does **not** expose were dropped:
per-window app *class* isn't a role (Feature 4 works around this), custom number-key shortcuts
fight KWin's keyboard grab during TabBox, and there is no "cancel-without-activating" slot.

### Feature 4 — Group an app's windows into one slice, with a drill-down sub-pie  *(your example)*
When an app has N windows, show **one** slice for it; hovering that slice dims the outer pie
to low opacity and reveals a second pie containing just that app's windows (activate or close
any; move the cursor back out to return to the top level).
- **Grouping key:** the model has no app/class role, but `model.icon` *is* the app icon and
  windows of one app share it → group by `icon` equality. (Robustness enhancement to *verify*:
  cross-reference the `KWin.Workspace` window list for `resourceClass`/`desktopFileName` and
  match to rows by id — only worth it if icon-keying proves too coarse, e.g. apps that set
  per-window icons.)
- **Implementation:** add a QML "display model" layer that derives groups from `tabBox.model`
  (the `pices` Repeater currently binds straight to it). Top level shows one entry per group
  (with a member-count badge); drilling in swaps the pie's source list to that group's members.
  Reuse Feature 3's fade for the dim/reveal, and Feature 5/6 for activate/close inside a group.
- **Effort: L** — the largest item; it changes the data flow and adds a navigation state.
  Best tackled after Features 1–3 land.

### Feature 5 — Releasing the modifier activates the *hovered* slice  *(correctness + QoL)*
Today hover sets `pie.current` but never writes `tabBox.currentIndex`, so releasing Alt
activates the **keyboard**-selected window, ignoring where the mouse is. Write
`tabBox.currentIndex = pie.current` on hover (it's read/write) so Alt-release and click agree.
**Effort: S.** Coordinate with the P0 `onCurrentChanged` refactor — the write-back loop is
benign (it re-sets `current` to the same value).

### Feature 6 — Close a window from the switcher
Middle-click a slice (or a small ✕ on the hovered slice) → `tabBox.model.close(index)`
(confirmed slot; the `closeable` role tells you whether to offer it). Tidy up windows without
leaving the switcher. **Effort: S–M.**

### Feature 7 — Scroll wheel cycles the selection
`MouseArea.onWheel` steps `tabBox.currentIndex` by ±1 (wrapping). Mouse input already works
here (hover + click), so the wheel path is available too. Pairs naturally with Feature 5.
**Effort: S.**

### Feature 8 — Sensible rendering for minimized windows
Minimized windows have no live thumbnail (renders blank). Use the `minimized` role to show the
app icon large instead, and dim the slice slightly so its state reads at a glance.
**Effort: S–M.**

### Feature 9 — *Optional:* one ring per virtual desktop
Repurpose the existing (currently dormant) multi-ring layout so each virtual desktop gets its
own ring, labeled via `desktopName`. Turns the unused `ringPieces` machinery into a real
feature for multi-desktop users. Keep it **opt-in** (config flag) so the default stays a single
pie. **Effort: M.**

---

## Broader improvements (sweep)

**P0 — correctness / robustness**
- **`ringPieces: {[]}` is a latent bug** (`Pie.qml:12,26`): `{[]}` evaluates to `undefined`,
  not an empty array — survives only because `updateData()` overwrites it before first
  paint. Change to `property var ringPieces: []`. *(S)*
- **Empty model** renders an empty donut with no message — add `Kirigami.PlaceholderMessage`
  ("No open windows"), like the built-in switchers, gated on `pices.count === 0`. *(M)*
- **Single window** → `b = zoom/(piecesInRing-1)` divides by zero (`Pie.qml:130`); Feature 1's
  `>=3` gate fixes this if implemented, otherwise guard explicitly. *(S)*
- **Thumbnail divide-by-zero**: `k = max(h/thumb.implicitHeight, …)` is NaN when a thumbnail
  isn't mapped yet/minimized (`Piece.qml:72`) — fall back to icon-only. *(M)*
- **`onCurrentChanged` self-assignment** (`main.qml:34–37`) re-triggers itself; fragile.
  Move "snap back to keyboard index" into `Pie`'s `onContainsMouseChanged`. *(S)*

**P1 — UX**
- **No window title shown anywhere** — `model.caption` available and unused (covered by
  Feature 2's caption option). *(S–M)*

**P2 — theming / config** *(all S)*
- Hardcoded bg `"#4b4b4b"` (`main.qml:28`) → `Kirigami.Theme.backgroundColor` for light/dark.
- Route the two `duration: 100` and the new fade through `Kirigami.Units.longDuration`;
  icon/margin constants through `Kirigami.Units` for HiDPI.

**P3 — cleanup** *(S)*
- Dead `newCurrentIdx` (`Pie.qml:60`) and unused `return [pr, rp]` (`Pie.qml:43`).

**P4 — workflow (highest leverage, do first)**
- Deployed copy at `~/.local/share/kwin/tabbox/pie/` is a **plain copy, not a symlink** —
  every edit here silently tests *stale* code until copied. Run once:
  `ln -sfn "$PWD" ~/.local/share/kwin/tabbox/pie`.
- Switcher QML is reloaded by **KWin** (`kwin_wayland`/`kwin_x11 --replace`), not reliably
  by `plasmashell --replace`.

---

## Suggested sequencing

1. **P4 symlink** + **P0 fixes** (cheap; ensures you test real edits and don't crash).
2. **Feature 1** (50/50) — pending **D1**.
3. **Feature 2** (pointer + caption + accent ring) — pending **D2**.
4. **Feature 3** (fade in/out) — pending **D3**.
5. **Quick QoL wins:** Feature 5 (hover → `currentIndex`) and Feature 7 (scroll-wheel cycle).
6. **Feature 6** (close from switcher) and **Feature 8** (minimized rendering).
7. **Feature 4** (app grouping + drill-down) — pending **D4**; the largest item.
8. **Feature 9** (per-desktop rings, optional) + **P2 / P3** polish.

---

## Appendix — verified KWin Plasma 6 API facts

Confirmed from KWin `master` source (`src/tabbox/`) and the bundled `thumbnail_grid` switcher.

**TabBox model roles available to delegates** (only these six):
`caption` (title), `desktopName`, `icon`, `windowId` (→ `WindowThumbnail.wId`), `minimized`,
`closeable`. There is **no `internalId` role and no "is-active"/MRU role**.

**Detecting the active window:** not exposed to QML rows. Best handles are `index === 0`
(only under "stacking order" mode) or `KWin.Workspace.activeWindow` (but rows can't be
matched back to it). Pragmatic option: snapshot `tabBox.currentIndex` at show time.

**`KWin.TabBoxSwitcher`:** `model`, `currentIndex` (r/w), `visible`, `allDesktops`,
`screenGeometry`, `noModifierGrab`, `compositing`; signals incl. `currentIndexChanged`,
`aboutToShow()`, `aboutToHide()`. No `count` property → use `pices.count` / `model.count`.

**Model methods:** `activate(int)` (select **and** close — already used in `main.qml`),
`close(int)`, `longestCaption()`.

**`KWin.Workspace`:** `cursorPos` (used), `activeWindow`. **`KWin.WindowThumbnail`:** `wId`.

**Geometry convention (verified in both Pie.qml & Piece.qml):** a `Piece`'s `rotation` is
its angular **center**, degrees, **0° = top (12 o'clock), increasing clockwise**; the slice
rotates about its bottom-center, which is the pie center. The `Canvas` mask in `Piece.qml`
uses radians in standard canvas orientation (hence the `Math.PI*1.5` / `-Math.PI/2` offsets).
