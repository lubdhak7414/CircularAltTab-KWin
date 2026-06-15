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
      bg.color: Kirigami.Theme.backgroundColor
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
        tabBox.model.activate(pie.current);
      }

      onCloseRequested: (idx)=>{
        if ( idx>=0 ) { tabBox.model.close(idx); }
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

        Text {
          id: captionLabel
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          // below needle base when pointing down (base at ~inRadius*1.4)
          anchors.topMargin: pie.inRadius*1.6
          // wider than center hole so long titles aren't clipped early
          width: pie.inRadius*6
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          maximumLineCount: 3
          elide: Text.ElideRight
          font.family: Kirigami.Theme.defaultFont.family
          font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize*1.5)
          color: Kirigami.Theme.textColor
          style: Text.Outline
          styleColor: Kirigami.Theme.backgroundColor
          text: pie.currentCaption
        }
      }
    }
  }

  onVisibleChanged: {
    if ( visible ) {
      // reset current BEFORE updateData so bindings re-evaluate after delegates are created
      pie.current =-1;
      pie.updateData();
      wnd.x =KWin.Workspace.cursorPos.x-pie.implicitWidth/2;
      wnd.y =KWin.Workspace.cursorPos.y-pie.implicitHeight/2;
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
