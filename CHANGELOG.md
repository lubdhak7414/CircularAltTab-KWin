# Changelog

## 1.1

- Fix ambiguous `License` field in `metadata.json` (`GPL` → `GPL-3.0-only`)
- Document Alt+Shift+Tab reverse cycling in README
- Add `install.sh --uninstall`
- Add Compatibility section to README (tested Plasma/KWin/Qt versions, session type)
- Add Known Limitations section to README (undocumented API, close-dialog behavior, Wayland/multi-monitor/accessibility gaps)
- Guard `model.activate()`/`model.close()` calls against a null `tabBox.model`

## 1.0

- Initial release: pie/circular multi-ring TabBox switcher for KDE Plasma 6
