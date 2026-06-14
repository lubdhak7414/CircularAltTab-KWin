---
name: kwin-tabbox-switcher-api
description: "Verified KWin Plasma 6 TabBox window-switcher QML API — model roles, switcher/Workspace properties, methods"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 00993be5-96bd-4cca-807e-8f78df15e8fc
---

KWin window switchers (TabBox visualizations) are QML KPackages. Root type `KWin.TabBoxSwitcher` (`import org.kde.kwin as KWin`, no version in Plasma 6). Verified against KWin master `src/tabbox/clientmodel.{h,cpp}` and `switcheritem.h`, and the bundled `thumbnail_grid` switcher.

**Model roles** (rows of `tabBox.model`, available to delegates by name): `caption` (string, window title), `desktopName` (string), `icon` (icon source), `windowId` (ulonglong → feed to `KWin.WindowThumbnail.wId`), `minimized` (bool), `closeable` (bool). There is **no** `internalId` role and **no** role flagging the active/most-recently-used window — only the keyboard/selected `currentIndex` is exposed.

**Model methods** (callable from QML): `activate(int index)` — selects that window **and closes the switcher**; `close(int index)` — closes that window; `longestCaption()` — QString, for sizing.

**`KWin.TabBoxSwitcher` properties/signals**: `model`, `currentIndex` (read/write int — writing it moves the highlight), `visible` (r/w), `allDesktops`, `screenGeometry`, `noModifierGrab`, `compositing`, `automaticallyHide`; signals `currentIndexChanged`, `modelChanged`, `visibleChanged`, `aboutToShow()`, `aboutToHide()`. **No `count` property** — use `model.count` or a Repeater's `.count`.

**`KWin.Workspace`**: `cursorPos` (QPoint, global cursor position), `activeWindow`. **`KWin.WindowThumbnail`**: `wId` (ulonglong).

**Plasma 5→6 differences**: `import org.kde.kwin as KWin` (was `2.0`); root `KWin.TabBoxSwitcher` (was `KWin.Switcher`); `KWin.WindowThumbnail` (was `ThumbnailItem`); `KWin.Workspace.cursorPos` (was global `workspace`); `KSvg.FrameSvgItem` from `org.kde.ksvg`. Model roles are unchanged across 5→6.

Docs: https://develop.kde.org/docs/plasma/windowswitcher/ . Source: https://github.com/KDE/kwin/ (`src/tabbox/`).
