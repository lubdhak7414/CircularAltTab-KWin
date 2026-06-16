import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

KWin.TabBoxSwitcher {
  id: tabBox

  Window {
    id: wnd
    width: pie.implicitWidth
    height: pie.implicitHeight
    visible: false // managed manually for smooth fade
    flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
    color: "transparent"

    Pie {
      id: pie
      model: tabBox.model
      bg.color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                        Kirigami.Theme.backgroundColor.g,
                        Kirigami.Theme.backgroundColor.b,
                        pie.bgAlpha)
      opacity: 0.0

      Behavior on opacity {
        NumberAnimation {
          duration: Kirigami.Units.longDuration
          easing.type: Easing.InOutQuad
          // unmap only once fully transparent
          onFinished: if ( pie.opacity===0.0 ) { wnd.visible =false; }
        }
      }

      onClicked: {
        // ignore clicks on the center hole / gaps (no piece under cursor)
        // model.activate() is undocumented KWin API - no stability guarantee.
        // For click activation only; keyboard flow uses currentIndex + Alt-release.
        if ( tabBox.model && pie.current>=0 ) { tabBox.model.activate(pie.current); }
      }

      onCloseRequested: (idx)=>{
        // model.close() is undocumented KWin API - no stability guarantee.
        // No documented alternative exists for closing windows from a TabBox switcher.
        if ( tabBox.model && idx>=0 ) { tabBox.model.close(idx); }
      }

      onCurrentChanged: {
        // no hovered piece - hold keyboard selection
        if ( current<0 ) { current =tabBox.currentIndex; }
        // hover writes currentIndex so Alt-release activates the hovered piece
        else if ( tabBox.currentIndex!==current ) { tabBox.currentIndex =current; }
      }

      Item {
        id: centerItem
        anchors.centerIn: parent
        width: pie.inRadius*2
        height: pie.inRadius*2
        z: 10

        readonly property double targetAngle: pie.currentAngle
        readonly property bool hasTarget: !isNaN(targetAngle)
        // hold last angle when cursor leaves (no snap-to-top flicker)
        property double lastAngle: 0
        onTargetAngleChanged: if ( hasTarget ) { lastAngle =targetAngle; }

        Canvas {
          id: needle
          anchors.fill: parent
          visible: centerItem.hasTarget
          rotation: centerItem.lastAngle
          onPaint: {
            let ctx =getContext("2d");
            ctx.reset();
            const cx =width/2.0;
            const tip =8.0;
            const baseY =height*0.30;
            const bw =width*0.08;
            ctx.beginPath();
            ctx.moveTo(cx, tip);
            ctx.lineTo(cx-bw, baseY);
            ctx.lineTo(cx+bw, baseY);
            ctx.closePath();
            ctx.fillStyle =Kirigami.Theme.highlightColor;
            ctx.fill();
          }
          Behavior on rotation {
            RotationAnimation {
              duration: Kirigami.Units.longDuration
              direction: RotationAnimation.Shortest
            }
          }
          onVisibleChanged: requestPaint()
          Component.onCompleted: requestPaint()
        }

        Rectangle {
          id: captionBg
          anchors.centerIn: captionLabel
          width: Math.min(captionLabel.implicitWidth, captionLabel.width) + Kirigami.Units.largeSpacing * 2
          height: captionLabel.implicitHeight + Kirigami.Units.smallSpacing
          radius: Kirigami.Units.cornerRadius
          color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                         Kirigami.Theme.backgroundColor.g,
                         Kirigami.Theme.backgroundColor.b,
                         0.75)
          visible: captionLabel.text !== ""
        }

        Text {
          id: captionLabel
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          // below needle tip when pointing down (tip at ~inRadius*1.92)
          anchors.topMargin: pie.inRadius*1.85
          // wider than center hole so long titles aren't clipped early
          width: pie.inRadius*6
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          maximumLineCount: 3
          elide: Text.ElideRight
          font.family: Kirigami.Theme.defaultFont.family
          font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize*pie.captionFontScale)
          color: Kirigami.Theme.textColor
          text: pie.currentCaption
        }
      }
    }
  }

  onVisibleChanged: {
    if ( visible ) {
      // reset current BEFORE updateData so bindings re-evaluate after delegates are created
      pie.current =-1;
      pie.screenFit =1.0;
      pie.updateData();
      let g =tabBox.screenGeometry;
      // shrink further if the natural size (many windows -> many rings) would
      // overflow the screen - sizeFactor alone floors at 0.55 and doesn't know
      // about screen size
      if ( g && g.width>0 && g.height>0 ) {
        const margin =0.95;
        const fit =Math.min(1.0, g.width*margin/pie.implicitWidth, g.height*margin/pie.implicitHeight);
        if ( fit<1.0 ) { pie.screenFit =fit; }
      }
      // center on cursor, then clamp to the screen so the pie never opens off-screen
      let cx =KWin.Workspace.cursorPos.x-pie.implicitWidth/2;
      let cy =KWin.Workspace.cursorPos.y-pie.implicitHeight/2;
      if ( g && g.width>0 && g.height>0 ) {
        wnd.x =Math.max(g.x, Math.min(cx, g.x+g.width-pie.implicitWidth));
        wnd.y =Math.max(g.y, Math.min(cy, g.y+g.height-pie.implicitHeight));
      } else {
        wnd.x =cx;
        wnd.y =cy;
      }
      wnd.visible =true;
      pie.opacity =1.0;
      // restore current after Repeater created delegates, otherwise itemAt(current)==null
      showSelectTimer.restart();
    } else {
      pie.opacity =0.0;
    }
  }

  Timer {
    id: showSelectTimer
    interval: 50
    onTriggered: pie.current = tabBox.currentIndex
  }

  onCurrentIndexChanged: {
    pie.current =tabBox.currentIndex;
  }
}
