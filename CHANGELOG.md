# Changelog

## 1.1

- Add `install.sh --uninstall`
- Add Compatibility and Known Limitations sections to README
- Guard window activate/close against a null TabBox model
- Fix circle overflowing the screen at high window counts (`screenFit`, scales the ring layout to fit `screenGeometry`)
- Verify Wayland and X11 compatibility, document rendering-cost profiling results
- Misc README/metadata cleanup

## 1.0

- Initial release: pie/circular multi-ring TabBox switcher for KDE Plasma 6
