import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
  id: pie
  color: "transparent"

  property alias model: pices.model
  property double ringHeight: Kirigami.Units.gridUnit*12
  property double inRadius: Kirigami.Units.gridUnit*2
  property int current: -1 //-- Индекс активного куска
  property var ringPieces: [] //-- Сколько итемов показывать в каждом кольце. В последнем кольце будут все, кто не влез.
  property double ringSpacing: Kirigami.Units.gridUnit*0.5 //-- Расстояние между кольцами
  readonly property int ringsCount: _private.ringPieces.length //-- Сколько фактически колец
  property alias bg: bg

  //-- F2: угол (град.) и заголовок текущего выбранного куска — для указателя/подписи в центре.
  //-- Привязка реактивна: следит и за current, и за rotation выбранного куска (анимация).
  readonly property double currentAngle: (current>=0 && current<pices.count && pices.itemAt(current))
      ? pices.itemAt(current).rotation : NaN
  readonly property string currentCaption: (current>=0 && current<pices.count && pices.itemAt(current))
      ? pices.itemAt(current).caption : ""

  signal mousePositionChanged(var mouse);
  signal clicked(var mouse);
  signal closeRequested(int idx); //-- F6: запрос закрытия окна по индексу

  implicitHeight: inRadius*2+(ringHeight+ringSpacing)*ringsCount*2 + 0.14*((ringHeight+ringSpacing)*ringsCount+inRadius) //-- запас под scale 1.06 (piece шире на 2*offset)
  implicitWidth: implicitHeight

  QtObject {
    id: _private
    property var pieceToRing: [] //-- Какой кусок какому кольцу принадлежит
    property var ringPieces: [] //-- Сколько фактически итемов в каждом кольце
    property var idxsInRing: [] //-- Индекс относительно кольца

    /**
    * @brief Обновляем @see pieceToRing, @see ringPieces, @see idxsInRing
    */
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

  /**
  * @brief Определяем кусок по координатам.
  * @note Хит-тест по СТАБИЛЬНОЙ равномерной раскладке (домашние секторы),
  *       а НЕ по текущей (анимируемой) геометрии. Иначе наведение «дёргается»:
  *       выбранный кусок раздувается и уезжает из-под курсора, под курсором
  *       оказывается соседний кусок — и выбор начинает прыгать.
  */
  function getPieIdx(x, y) {
    const tx =x-width/2;
    const ty =y-height/2;
    const d =tx*tx+ty*ty;
    let mouseAngle =(Math.atan2(tx, -ty)*180.0/Math.PI+360)%360; //-- Угол курсора в градусах относительно центра
    for (let i=0; i<pices.count; ++i) {
      const ring =_private.pieceToRing[i];
      const n =_private.ringPieces[ring];
      const j =_private.idxsInRing[i];
      const rIn =inRadius+(ringHeight+ringSpacing)*ring;
      const rOut =rIn+ringHeight;
      if ( d<rIn*rIn || d>rOut*rOut ) { continue; }
      const central =360.0/n; //-- ширина домашнего сектора (равномерная раскладка)
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

  /**
  * @brief
  */
  function updateData() {
    _private.updateData();
  }

  //-- P0: пустой список окон
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
      anchors.margins: 0.07*((ringHeight+ringSpacing)*ringsCount+inRadius) //-- bg только по реальному пирогу, без запаса под scale
      radius: width/2
      color: "transparent"
    }

    onClicked: (mouse)=>{
      if ( mouse.button===Qt.MiddleButton ) { pie.closeRequested(pie.current); } //-- F6
      else { pie.clicked(mouse); }
    }

    onWheel: (wheel)=>{ //-- F7: колесо мыши перебирает окна
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

        //-- || 0/1 — защита от NaN, пока _private не заполнен updateData()
        //-- (иначе 360/undefined=NaN «залипает» в Behavior-анимации навсегда).
        readonly property int ringIdx: _private.pieceToRing[index] || 0
        readonly property int piecesInRing: _private.ringPieces[ringIdx] || 1
        readonly property int idxInRing: _private.idxsInRing[index] || 0
        //-- РАВНЫЕ доли: куски НЕ переразмещаются при наведении, поэтому курсор всегда
        //-- попадает ровно в то окно, на которое наведён (раньше раздувание до 50%
        //-- сдвигало остальные куски и выбор «прыгал»).
        readonly property double centralAngle: 360.0/piecesInRing

        caption: model.caption
        minimized: model.minimized
        isSelected: pie.current === index
        z: isSelected ? 1 : 0 //-- выбранный кусок поверх соседей, чтобы акцентное кольцо не перекрывалось
        //-- Выделение без переразмещения: невыбранные приглушаем, выбранный —
        //-- полная яркость + лёгкий радиальный «pop» (scale от центра пирога).
        opacity: (pie.current>=0 && pie.current!==index)? 0.6 : (model.minimized? 0.7 : 1.0)
        transformOrigin: Item.Center //-- масштабируем от центра, чтобы кусок не выходил за окно
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
