import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

Rectangle {
  id: pie
  color: "transparent"

  property alias model: pieces.model
  property int current: -1
  property var ringPieces: []

  // user-tunable visual preferences
  property double selectedScale: 1.06
  property double nonSelectedOpacity: 0.6
  property double minimizedOpacity: 0.7
  property double bgAlpha: 0.72
  property double captionFontScale: 1.5

  // max slices per ring before spilling to the next ring (≈ 360/maxPerRing° min arc)
  readonly property int maxPerRing: 8

  // base sizes (DPI-aware); the actual sizes taper as window count grows
  readonly property double baseRingHeight: Kirigami.Units.gridUnit*12
  readonly property double baseInRadius: Kirigami.Units.gridUnit*2
  readonly property double baseRingSpacing: Kirigami.Units.gridUnit*0.5
  // 1.0 up to 4 windows, then shrinks ~3%/window, clamped to [0.55, 1.0]
  readonly property double sizeFactor: Math.min(1.0, Math.max(0.55, 1.0-(pieces.count-4)*0.03))
  // extra shrink so the circle fits the active screen; set by main.qml before showing
  property double screenFit: 1.0
  property double ringHeight: baseRingHeight*sizeFactor*screenFit
  property double inRadius: baseInRadius*sizeFactor*screenFit
  property double ringSpacing: baseRingSpacing*sizeFactor*screenFit
  readonly property int ringsCount: _private.ringPieces.length
  property alias bg: bg

  // angle and caption of the selected piece - drives the center pointer/label
  readonly property double currentAngle: (current>=0 && current<pieces.count && pieces.itemAt(current))
      ? pieces.itemAt(current).rotation : NaN
  readonly property string currentCaption: (current>=0 && current<pieces.count && pieces.itemAt(current))
      ? pieces.itemAt(current).caption : ""

  signal clicked(var mouse);
  signal closeRequested(int idx);

  // base size + padding for 1.06x scale (wider piece = chord1 + 2*offset)
  implicitHeight: inRadius*2+(ringHeight+ringSpacing)*ringsCount*2 + 0.14*((ringHeight+ringSpacing)*ringsCount+inRadius)
  implicitWidth: implicitHeight

  QtObject {
    id: _private
    property var pieceToRing: []
    property var ringPieces: []
    property var idxsInRing: []

    function updateData() {
      let pr =[0], rp =[0], ir =[0];
      for (let i=0, summ =0, j =0, ring =0; i<pieces.count; ++i, ++j) {
        if ( ring<pie.ringPieces.length && i>=summ+pie.ringPieces[ring] ) { summ +=pie.ringPieces[ring]; ring++; rp[ring] =0; j =0; }
        pr[i] =ring;
        ir[i] =j;
        rp[ring]++;
      }
      _private.pieceToRing =pr;
      _private.ringPieces =rp;
      _private.idxsInRing =ir;
    }
  }

  onRingPiecesChanged: {
    _private.updateData();
  }

  // Hit-test uses STABLE uniform layout (home sectors), not animated geometry.
  // Otherwise hovering "jumps": the hovered piece scales and moves from under
  // the cursor, landing on a neighbor and thrashing the selection.
  function getPieIdx(x, y) {
    const tx =x-width/2;
    const ty =y-height/2;
    const d =tx*tx+ty*ty;
    let mouseAngle =(Math.atan2(tx, -ty)*180.0/Math.PI+360)%360;
    for (let i=0; i<pieces.count; ++i) {
      const ring =_private.pieceToRing[i];
      const n =_private.ringPieces[ring];
      const j =_private.idxsInRing[i];
      const rIn =inRadius+(ringHeight+ringSpacing)*ring;
      const rOut =rIn+ringHeight;
      if ( d<rIn*rIn || d>rOut*rOut ) { continue; }
      const central =Math.min(180.0, 360.0/n);
      const startAngle =j*central-central/2.0;
      const endAngle =j*central+central/2.0;
      if ( startAngle<0 || endAngle>360 ) {
        if ( (mouseAngle>=(startAngle+360)%360 || mouseAngle<(endAngle%360)) ) { return i; }
      } else {
        if ( mouseAngle>=startAngle && mouseAngle<endAngle ) { return i; }
      }
    }
    return -1;
  }

  function updateData() {
    let rp = computeRingPieces();
    if ( JSON.stringify(rp) !== JSON.stringify(pie.ringPieces) ) {
      pie.ringPieces = rp;
    } else {
      _private.updateData();
    }
  }

  // returns a per-ring capacity array summing EXACTLY to pieces.count
  function computeRingPieces() {
    let n = pieces.count;
    if ( n <= 0 ) { return []; }
    let rings = Math.ceil(n / maxPerRing);
    let base  = Math.floor(n / rings);
    let rem   = n % rings;
    let arr = [];
    for ( let r = 0; r < rings; r++ ) {
      arr.push(base + (r >= rings - rem ? 1 : 0));
    }
    return arr;
  }

  // cycle selection by step (+1 / -1), wrapping; shared by wheel + arrow keys
  function cycle(step) {
    if ( pieces.count<=0 ) { return; }
    if ( pie.current<0 ) { pie.current =(step>0)? 0 : pieces.count-1; }
    else { pie.current =(pie.current+step+pieces.count)%pieces.count; }
  }

  Kirigami.PlaceholderMessage {
    anchors.centerIn: parent
    width: parent.width*0.5
    // render above the opaque bg disc (a later sibling), otherwise it's hidden
    z: 100
    visible: pieces.count===0
    text: "No active windows."
  }

  MouseArea {
    id: mouseHandler
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true

    Rectangle {
      id: bg
      anchors.fill: parent
      // bg covers only the pie content, not the scale padding
      anchors.margins: 0.07*((ringHeight+ringSpacing)*ringsCount+inRadius)
      radius: width/2
      color: "transparent"
    }

    onClicked: (mouse)=>{
      if ( mouse.button===Qt.MiddleButton ) { pie.closeRequested(pie.current); }
      else { pie.clicked(mouse); }
    }

    onWheel: (wheel)=>{
      pie.cycle(wheel.angleDelta.y>0 ? -1 : 1);
    }

    onPositionChanged: (mouse) => {
      mouse.accepted =false;
      if ( !containsMouse ) { return; }
      pie.current =getPieIdx(mouse.x, mouse.y);
    }

    onContainsMouseChanged: {
      if ( !containsMouse ) { pie.current =-1; }
    }

    Repeater {
      id: pieces

      onModelChanged: {
        pie.updateData();
      }

      onCountChanged: {
        pie.updateData();
      }

      Component.onCompleted: {
        pie.updateData();
      }

      delegate: Piece {
        id: pieceDelegate

        // guard against NaN (360/undefined) which permanently latches Behavior animations
        readonly property int ringIdx: _private.pieceToRing[index] || 0
        readonly property int piecesInRing: _private.ringPieces[ringIdx] || 1
        readonly property int idxInRing: _private.idxsInRing[index] || 0
        // cap at 180°: a lone window's 360° slice is degenerate (chord→0), and the
        // chord (= preview width) is widest at 180°, so this gives the biggest preview.
        // Only bites when piecesInRing==1; for 2+ windows 360/n is already ≤180.
        readonly property double centralAngle: Math.min(180.0, 360.0/piecesInRing)

        // lookup live KWin::Window for real-time caption (ClientModel never emits dataChanged)
        readonly property var kwinWindow: {
            var windows = KWin.Workspace.windows;
            for (var i = 0; i < windows.length; i++) {
                if (String(windows[i].internalId) === String(model.windowId)) {
                    return windows[i];
                }
            }
            return null;
        }
        caption: kwinWindow ? kwinWindow.caption : model.caption
        minimized: model.minimized
        isSelected: pie.current === index
        // selected piece renders on top so accent ring isn't covered by neighbors
        z: isSelected ? 1 : 0
        opacity: (pie.current>=0 && pie.current!==index)? pie.nonSelectedOpacity : (model.minimized? pie.minimizedOpacity : 1.0)
        // scale from center to avoid clipping outside the window
        transformOrigin: Item.Center
        scale: (pie.current===index)? pie.selectedScale : 1.0
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration; } }
        Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; } }

        rIn: pie.inRadius+((pie.ringHeight+pie.ringSpacing)*ringIdx)
        rOut: rIn+pie.ringHeight
        offset: 0.8*piecesInRing
        angle: centralAngle
        x: pie.width/2-width/2
        y: pie.height/2-height
        rotation: idxInRing*centralAngle

        windowId: model.windowId
        icon.source: model.icon

        Behavior on angle {
          NumberAnimation { duration: Kirigami.Units.shortDuration; }
        }

        Behavior on rotation {
          NumberAnimation { duration: Kirigami.Units.shortDuration; }
        }
      }
    }
  }
}
