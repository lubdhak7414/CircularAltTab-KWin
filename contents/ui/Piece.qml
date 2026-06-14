import QtQuick
import Qt5Compat.GraphicalEffects

import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

Item {
  id: piece
  property double rOut: 150 //-- Внешний радиус
  property double rIn: 40 //-- Внутренний радиус
  property double angle: 150 //-- Центральный угол, в градусах
  property double offset: 5 //-- Отступ
  property double rotation: 0 //-- Поповрот
  property alias icon: icon
  property string caption: "" //-- Заголовок окна (для указателя в центре, F2)
  property bool minimized: false //-- Окно свёрнуто — живого превью нет (F8)
  property bool isSelected: false //-- F2: подсветка выбранного куска

  readonly property double angle2: angle*Math.PI/360.0 //-- Угол в радианы и сразу делим на 2, т.к. используется часто
  readonly property double chord1: 2.0*rOut*Math.sin(angle2) //-- Длина хорды центрального угла (в градусах)
  readonly property double chord2: 2.0*rIn*Math.sin(angle2)

  width: chord1 + 2*offset //-- Canvas должен вмещать дугу целиком (arc выходит за chord на offset)
  height: rOut + 6 //-- запас под масштабирование 1.06

  transform: Rotation {
    origin {
      x: width/2
      y: height
    }
    angle: piece.rotation
  }

  //-- Основной слой: маскируем содержимое (превью + иконки) формой куска.
  Item {
    id: maskedContent
    anchors.fill: parent

    layer.enabled: true
    layer.samples: 8
    layer.effect: OpacityMask {
      maskSource: mask
    }

    Canvas {
      id: mask
      anchors.fill: parent
      onPaint: {
        let ctx = getContext("2d");
        ctx.fillStyle =Qt.rgba(0, 0, 0, 1);
        ctx.clearRect(0, 0, width, height);

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
      visible: !piece.minimized //-- F8: для свёрнутых окон показываем иконку вместо превью
      anchors.top: parent.top
      anchors.topMargin: -20
      anchors.horizontalCenter: parent.horizontalCenter
      readonly property double h: rOut-rIn+40
      readonly property double w: parent.width
      //-- P0: защита от деления на ноль, пока превью ещё не получило размер
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

    //-- F8: крупная иконка приложения для свёрнутых окон (когда превью нет)
    Kirigami.Icon {
      id: fallbackIcon
      visible: piece.minimized
      source: icon.source
      width: Math.min(piece.width*0.45, Kirigami.Units.iconSizes.large)
      height: width
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: (rOut-rIn)/2.0
      smooth: true
      transform: Rotation {
        origin.x: fallbackIcon.width/2
        origin.y: fallbackIcon.height/2
        angle: -piece.rotation
      }
    }

    Kirigami.Icon {
      id: icon
      width: Kirigami.Units.iconSizes.large //-- логотип окна крупнее
      height: Kirigami.Units.iconSizes.large
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      //-- по центру кольца (радиус ~ (rIn+rOut)/2), а не у самого центра пирога —
      //-- иначе крупные иконки толпятся в середине и налезают на подпись.
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
  }

  //-- F2: акцентное кольцо вокруг выбранного куска.
  //-- Рисуется ВНЕ maskedContent, поэтому OpacityMask его не обрезает.
  //-- Canvas шириной chord1+2*offset — дуга вмещается целиком, смещение не нужно.
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
