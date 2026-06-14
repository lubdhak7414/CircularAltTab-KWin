import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kwin as KWin

/**
* @brief Круговой переключатель окон (KWin TabBox, Plasma 6)
* @ref https://github.com/KDE/kwin/
* @ref https://develop.kde.org/docs/plasma/kwin/api/
*/
KWin.TabBoxSwitcher {
  id: tabBox

  Window {
    id: wnd
    width: pie.implicitWidth
    height: pie.implicitHeight
    visible: false //-- F3: видимостью управляем вручную ради плавного fade
    flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
    color: "transparent"

    Pie {
      id: pie
      model: tabBox.model
      bg.color: Kirigami.Theme.backgroundColor
      opacity: 0.0 //-- F3: плавно появляемся/исчезаем

      Behavior on opacity {
        NumberAnimation {
          duration: Kirigami.Units.longDuration
          easing.type: Easing.InOutQuad
          //-- скрываем окно только когда полностью прозрачно ("в последний момент")
          onFinished: if ( pie.opacity===0.0 ) { wnd.visible =false; }
        }
      }

      onClicked: {
        tabBox.model.activate(pie.current);
      }

      onCloseRequested: (idx)=>{ //-- F6: средняя кнопка мыши закрывает окно
        if ( idx>=0 ) { tabBox.model.close(idx); }
      }

      onCurrentChanged: {
        //-- Нет выбранного - курсор увели, держим выбор, сделанный с клавиатуры
        if ( current<0 ) { current =tabBox.currentIndex; }
        //-- F5: наведение мышью делает кусок активируемым по отпусканию модификатора
        else if ( tabBox.currentIndex!==current ) { tabBox.currentIndex =current; }
      }

      //-- F2: указатель на выбранный кусок + заголовок окна вместо часов
      Item {
        id: centerItem
        anchors.centerIn: parent
        width: pie.inRadius*2
        height: pie.inRadius*2
        z: 10

        readonly property double targetAngle: pie.currentAngle
        readonly property bool hasTarget: !isNaN(targetAngle)
        property double lastAngle: 0 //-- держим последний угол, пока выбор отсутствует
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
          anchors.top: parent.verticalCenter
          anchors.topMargin: 4
          width: pie.inRadius*6 //-- заметно шире центрального отверстия, чтобы имя не обрезалось так рано
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          maximumLineCount: 3
          elide: Text.ElideRight
          //-- ~на 2/3 крупнее прежнего (был smallFont)
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

  //-- F3: реакция на показ/скрытие переключателя
  onVisibleChanged: {
    if ( visible ) {
      //-- Сбрасываем current ПЕРЕД updateData, чтобы привязки (currentAngle,
      //-- currentCaption) гарантированно переоцениться после создания делегатов.
      pie.current =-1;
      pie.updateData();
      wnd.x =KWin.Workspace.cursorPos.x-pie.implicitWidth/2;
      wnd.y =KWin.Workspace.cursorPos.y-pie.implicitHeight/2;
      wnd.visible =true;
      pie.opacity =1.0;
      //-- Восстанавливаем current после того, как Repeater создал делегаты,
      //-- иначе pices.itemAt(current)==null → заголовок/указатель пустые.
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
