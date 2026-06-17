# Changelog

## 1.0

Initial release. Forked from [PieTabSwitcher-KWin](https://github.com/Riflio/PieTabSwitcher-KWin), substantially rewritten:

### Plasma 6 & Qt 6 port
- Removed Qt 5 Plasma module imports (PlasmaCore, KSvg, PlasmaComponents3)
- Updated to Kirigami (Theme, Units, Icons)
- All code now uses Qt 6 syntax and KWin API

### Layout & rendering
- Multi-ring distribution algorithm (`computeRingPieces()`) — distributes windows evenly across rings, max 8 per ring, excess spills to outer rings
- Dynamic sizing: base radii scale down ~3%/window for high counts, clamped to [0.55, 1.0] of full size
- Screen-fit clamp: pie shrinks further if it would overflow active screen (95% margin)
- Off-screen prevention: center positioned on cursor, then clamped to screen bounds so pie never renders partially off-display
- Single-window mode caps slice at 180° (full 360° is degenerate, chord→0)
- Hit-testing uses stable uniform layout (home sectors), not animated positions — prevents hover jitter when selected piece scales
- Canvas-based annular sector clipping via OpacityMask with offset-aware angle calculations

### Window thumbnails & icons
- Live KWin.WindowThumbnail for each window with automatic rotation compensation
- Real-time caption lookup from KWin::Window (ClientModel never emits dataChanged, so direct KWin.Workspace.windows polling required)
- Icon scaling taper on narrow slices (≥45° = full size, tapering to 0.45× at 0°)
- Separate large-icon fallback for minimized windows (no live thumbnail available)
- Icon glow using Glow effect (silhouette-based, avoids rotation artifacts of directional DropShadow)

### Interaction
- Scroll wheel navigation (`pie.cycle()`)
- Middle-click to close windows (undocumented `model.close()` API)
- No hover-driven 50/50 expansion — static equal slices with scale/dim highlight instead
- Center pointer (needle) shows selected window angle, updates via RotationAnimation with shortest-path direction
- Window caption display in center with background disc, wrapping up to 3 lines

### Visual & theming
- Theme-integrated colors: background disc, accent ring, needle, and caption all use Kirigami.Theme colors
- Configurable per-instance scaling: `selectedScale` (1.06), `nonSelectedOpacity` (0.6), `minimizedOpacity` (0.7), `bgAlpha` (0.72), `captionFontScale` (1.5)
- Accent ring (3px stroke) drawn outside masked content so it's not clipped by OpacityMask
- Fade animation (150ms InOutQuad) on show/hide with visibility only unmapped once fully transparent
- All animation durations switched to `Kirigami.Units.shortDuration` / `longDuration` for system-wide reduced-motion compliance

### Selection & state
- Explicit `windowId` property in Piece.qml (was undeclared delegate context dependency)
- Per-piece properties: `caption`, `minimized`, `isSelected`
- Piece z-ordering: selected piece renders on top so accent ring isn't covered by neighbors
- Opacity and scale Behaviors with smooth NumberAnimation on selection change
- Center item updates only after Repeater creates delegates (50ms timer workaround for itemAt(current)==null race)

### Packaging & metadata
- Install script with custom destination support and uninstall
- Renamed plugin Id from `circular` to `circularalttab` to avoid KDE Store collisions
- Updated metadata.json: author to Safwan Usaid Lubdhak, added Icon and Website fields, License to GPL-3.0-only
- Plugin name changed to "Circular Alt+Tab"
- Assets reorganized: images moved to `assets/` folder

### Documentation
- README rewritten: added Installation (GitHub Release + script), Compatibility table (Plasma 6.6.5 on Wayland/X11), Features, Usage table, Tuning section, Development guide
- Added CONTRIBUTING.md with guidelines
- Known Limitations section disclosing undocumented APIs (`KWin.Workspace.cursorPos`, `KWin.Workspace.windows`, `model.activate()`, `model.close()`)
- Architecture notes explaining ring distribution, hit-testing strategy, icon sizing, theme integration

### Pre-release fixes

- Fixed hit-test/render mismatch for single-window case (hit zone was full 360° ring, rendered piece was 180°)
