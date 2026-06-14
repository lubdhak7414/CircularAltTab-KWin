import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
  id: pie
  color: "transparent"

  property alias model: pices.model
  property double ringHeight: Kirigami.Units.gridUnit*12
  property double inRadius: Kirigami.Units.gridUnit*2
  property int current: -1
  property var ringPieces: []
  property double ringSpacing: Kirigami.Units.gridUnit*0.5
  readonly property int ringsCount: _private.ringPieces.length
  property alias bg: bg

  // selected piece angle (degrees) and caption — reactive to current + rotation animation
  readonly property double currentAngle: (current>=0 && current<pices.count && pices.itemAt(current))
      ? pices.itemAt(current).rotation : NaN
  readonly property string currentCaption: (current>=0 && current<pices.count && pices.itemAt(current))
      ? pices.itemAt(current).caption : ""

  signal mousePositionChanged(var mouse);
  signal clicked(var mouse);
  signal closeRequested(int idx);

  // extra padding for 1.06x scale on wider piece (chord1 + 2*offset)
  implicitHeight: inRadius*2+(ringHeight+ringSpacing)*ringsCount*2 + 0.14*((ringHeight+ringSpacing)*ringsCount+inRadius)
  implicitWidth: implicitHeight

  QtObject {
    id: _private
    property var pieceToRing: [] // which ring each piece belongs to
    property var ringPieces: []  // actual count of items per ring
    property var idxsInRing: []  // index within its ring

    function updateData() {
      let pr =[0], rp =[0], ir =[0];
      for (let i=0, summ =0, j =0, ring =0; i<pices.count; ++i, ++j) {
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

  // Hit-test against STABLE uniform layout, not animated geometry — otherwise
  // the hovered piece expands away from the cursor and selection jumps.
  function getPieIdx(x, y) {
    const tx =x-width/2;
    const ty =y-height/2;
    const d =tx*tx+ty*ty;
    let mouseAngle =(Math.atan2(tx, -ty)*180.0/Math.PI+360)%360;
    for (let i=0; i<pices.count; ++i) {
      const ring =_private.pieceToRing[i];
      const n =_private.ringPieces[ring];
      const j =_private.idxsInRing[i];
      const rIn =inRadius+(ringHeight+ringSpacing)*ring;
      const rOut =rIn+ringHeight;
      if ( d<rIn*rIn || d>rOut*rOut ) { continue; }
      const central =360.0/n;
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
    _private.updateData();
  }

  Kirigami.PlaceholderMessage {
    anchors.centerIn: parent
    width: parent.width*0.5
    visible: pices.count===0
    text: "No open windows"
  }

  MouseArea {
    id: mouseHandler
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true

    Rectangle {
      id: bg
      anchors.fill: parent
      // bg covers only the pie content area, not the scale padding
      anchors.margins: 0.07*((ringHeight+ringSpacing)*ringsCount+inRadius)
      radius: width/2
      color: "transparent"
    }

    onClicked: (mouse)=>{
      if ( mouse.button===Qt.MiddleButton ) { pie.closeRequested(pie.current); }
      else { pie.clicked(mouse); }
    }

    onWheel: (wheel)=>{
      if ( pices.count<=0 ) { return; }
      let step =(wheel.angleDelta.y>0)? -1 : 1;
      if ( pie.current<0 ) { pie.current =(step>0)? 0 : pices.count-1; }
      else { pie.current =(pie.current+step+pices.count)%pices.count; }
    }

    onPositionChanged: (mouse) => {
      mouse.accepted =false;
      mousePositionChanged(mouse);
      if ( !containsMouse ) { return; }
      pie.current =getPieIdx(mouse.x, mouse.y);
    }

    onContainsMouseChanged: {
      if ( !containsMouse ) { pie.current =-1; }
    }

    Repeater {
      id: pices

      onModelChanged: {
        _private.updateData();
      }

      Component.onCompleted: {
        _private.updateData();
      }

      delegate: Piece {
        id: pieceDelegate

        // guard against NaN before updateData populates _private
        // (360/undefined=NaN latches permanently in Behavior animations)
        readonly property int ringIdx: _private.pieceToRing[index] || 0
        readonly property int piecesInRing: _private.ringPieces[ringIdx] || 1
        readonly property int idxInRing: _private.idxsInRing[index] || 0
        readonly property double centralAngle: 360.0/piecesInRing

        caption: model.caption
        minimized: model.minimized
        isSelected: pie.current === index
        z: isSelected ? 1 : 0 // selected piece renders above neighbors
        opacity: (pie.current>=0 && pie.current!==index)? 0.6 : (model.minimized? 0.7 : 1.0)
        // scale from center to avoid clipping outside the window
        transformOrigin: Item.Center
        scale: (pie.current===index)? 1.06 : 1.0
        Behavior on opacity { NumberAnimation { duration: 100; } }
        Behavior on scale { NumberAnimation { duration: 100; } }

        rIn: pie.inRadius+((pie.ringHeight+pie.ringSpacing)*ringIdx)
        rOut: rIn+pie.ringHeight
        offset: 0.8*piecesInRing
        angle: centralAngle
        x: pie.width/2-width/2
        y: pie.height/2-height
        rotation: idxInRing*centralAngle

        icon.source: model.icon

        Behavior on angle {
          NumberAnimation { duration: 100; }
        }

        Behavior on rotation {
          NumberAnimation { duration: 100; }
        }
      }
    }
  }
}
