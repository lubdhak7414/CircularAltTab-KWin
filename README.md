# PieTabSwitcher-KWin

Windows switch in the form of circle sectors for KWin (KDE Plasma6)

![Preview](readme/preview1.png)


# Tuning

Edit `contents/ui/Pie.qml` to change visual defaults:

| Property | Default | What it does |
|----------|---------|--------------|
| `selectedScale` | 1.06 | Scale of the hovered piece (1.0 = no zoom) |
| `nonSelectedOpacity` | 0.6 | Opacity of pieces that are not hovered |
| `minimizedOpacity` | 0.7 | Opacity of minimized windows |
| `bgAlpha` | 0.72 | Background disc transparency (0 = invisible, 1 = opaque) |
| `captionFontScale` | 1.5 | Caption font size multiplier relative to system default |

To override in `main.qml` instead, set them on the `Pie` instance:
```qml
Pie {
    selectedScale: 1.1
    bgAlpha: 0.9
    // ...
}
```


# For dev

Sources and run:
```
cd ~/.local/share/kwin/tabbox/pie/
plasmashell --replace
```
or `kwin_x11 --replace` or `kwin_wayland --replace` but they will kill all apps in user session. plasmashell just reloads plasma, not full DE session.
