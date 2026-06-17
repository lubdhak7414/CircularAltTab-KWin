import QtQuick
import Qt5Compat.GraphicalEffects

import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

Item {
  id: piece
  property double rOut: 150
  property double rIn: 40
  property double angle: 150
  property double offset: 5
  property double rotation: 0
  property alias icon: icon
  property string caption: ""
  property bool minimized: false
  property bool isSelected: false
  property var windowId

  // shrink icons on narrow slices (≥45° = full size, tapering to 0.45×)
  readonly property double iconScale: Math.max(0.45, 1.0-(angle<45 ? (45-angle)/90 : 0))

  // half-angle in radians (used frequently in arc calculations)
  readonly property double angle2: angle*Math.PI/360.0
  // chord length at outer radius
  readonly property double chord1: 2.0*rOut*Math.sin(angle2)

  // canvas must be wide enough for the full arc (extends 'offset' beyond chord)
  width: chord1 + 2*offset
  height: rOut + 6

  transform: Rotation {
    origin {
      x: width/2
      y: height
    }
    angle: piece.rotation
  }

  Item {
    id: maskedContent
    anchors.fill: parent

    layer.enabled: true
    layer.samples: 8
    layer.effect: OpacityMask {
      maskSource: mask
    }

    // annular sector mask - clips content (preview + icons) to donut-segment shape
    Canvas {
      id: mask
      anchors.fill: parent
      onPaint: {
        let ctx = getContext("2d");
        ctx.fillStyle =Qt.rgba(0, 0, 0, 1);
        ctx.clearRect(0, 0, width, height);

        // calculates the effective central angle accounting for the inward offset
        let calcCenterAngle =(r) => {
          let a =Math.PI/2.0-angle2;
          let adj =offset*Math.sin(a);
          let opp =offset*Math.cos(a);
          let leg =Math.sqrt(r*r-opp*opp)-adj;
          let chord = 2.0*leg*Math.sin(angle2);
          return 2.0*Math.asin(chord/(2.0*r));
        }

        let a1 =calcCenterAngle(rOut);
        let a2 =calcCenterAngle(rIn);

        ctx.beginPath();
          ctx.arc(width/2, height, rOut, Math.PI*1.5-a1/2.0, -Math.PI/2.0+a1/2.0, 0);
          ctx.arc(width/2, height, rIn, -Math.PI/2.0+a2/2.0, Math.PI*1.5-a2/2.0, 1);
          ctx.closePath();
        ctx.fill();
      }
    }

    Item {
      id: contentWrapper
      visible: !piece.minimized
      opacity: 0.75
      anchors.top: parent.top
      anchors.topMargin: -20
      anchors.horizontalCenter: parent.horizontalCenter
      readonly property double h: rOut-rIn+40
      readonly property double w: parent.width
      // guard against zero-division before thumbnail has a size
      readonly property double k: (thumb.implicitWidth>0 && thumb.implicitHeight>0)
          ? Math.max(h/thumb.implicitHeight, w/thumb.implicitWidth) : 1.0
      width: thumb.implicitWidth*k
      height: thumb.implicitHeight*k

      KWin.WindowThumbnail {
        id: thumb
        anchors.fill:parent
        wId: windowId
        transform: [
          Rotation {
            angle: -piece.rotation
            origin.x: thumb.width/2
            origin.y: thumb.height/2
          }
        ]
      }
    }
  }

  // icon + edge glow outside maskedContent - Glow traces the icon's silhouette
  // (not a disc), and since it's a uniform edge expansion the piece rotation
  // doesn't create the rotation-artifact that a directional DropShadow would.

  Glow {
    id: iconGlow
    source: icon
    visible: !piece.minimized
    anchors.fill: icon
    color: Kirigami.Theme.highlightColor
    radius: 8
    samples: 16
    spread: 0.3
    transform: Rotation {
      origin.x: icon.width / 2
      origin.y: icon.height / 2
      angle: -piece.rotation
    }
  }

  Kirigami.Icon {
    id: icon
    width: Kirigami.Units.iconSizes.large*piece.iconScale
    height: Kirigami.Units.iconSizes.large*piece.iconScale
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    // centered on the ring (midway between rIn and rOut), not at the pie center
    anchors.topMargin: (rOut-rIn)/2 - height/2
    smooth: true
    antialiasing: true
    transform: Rotation {
      origin {
        x: icon.width/2
        y: icon.height/2
      }
      angle: -piece.rotation
    }
  }

  Glow {
    id: fallbackIconGlow
    source: fallbackIcon
    visible: piece.minimized
    anchors.fill: fallbackIcon
    color: Kirigami.Theme.highlightColor
    radius: 8
    samples: 16
    spread: 0.3
    transform: Rotation {
      origin.x: fallbackIcon.width / 2
      origin.y: fallbackIcon.height / 2
      angle: -piece.rotation
    }
  }

  // large app icon for minimized windows (no live thumbnail)
  Kirigami.Icon {
    id: fallbackIcon
    visible: piece.minimized
    source: icon.source
    width: Math.min(piece.width*0.45, Kirigami.Units.iconSizes.large*piece.iconScale)
    height: width
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: (rOut-rIn)/2 - height/2
    smooth: true
    transform: Rotation {
      origin.x: fallbackIcon.width/2
      origin.y: fallbackIcon.height/2
      angle: -piece.rotation
    }
  }

  // accent ring drawn OUTSIDE maskedContent so OpacityMask doesn't clip it
  Canvas {
    id: accentRing
    anchors.fill: parent
    visible: piece.isSelected
    onPaint: {
      let ctx = getContext("2d");
      ctx.clearRect(0, 0, width, height);
      if (!piece.isSelected) return;

      let calcCenterAngle = (r) => {
        let a = Math.PI/2.0 - angle2;
        let adj = offset * Math.sin(a);
        let opp = offset * Math.cos(a);
        let leg = Math.sqrt(r*r - opp*opp) - adj;
        let chord = 2.0 * leg * Math.sin(angle2);
        return 2.0 * Math.asin(chord / (2.0 * r));
      }

      let a1 = calcCenterAngle(rOut);
      let a2 = calcCenterAngle(rIn);

      ctx.beginPath();
      ctx.arc(width/2, height, rOut, Math.PI*1.5 - a1/2.0, -Math.PI/2.0 + a1/2.0, false);
      ctx.arc(width/2, height, rIn, -Math.PI/2.0 + a2/2.0, Math.PI*1.5 - a2/2.0, true);
      ctx.closePath();
      ctx.strokeStyle = Kirigami.Theme.highlightColor;
      ctx.lineWidth = 3;
      ctx.stroke();
    }
    onVisibleChanged: if (visible) requestPaint()
    Connections {
      target: piece
      function onIsSelectedChanged() { accentRing.requestPaint(); }
    }
  }
}
