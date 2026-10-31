import QtQuick

// Надпись с бегущим металлическим бликом.
// Реализовано без шейдеров: три «окна» разной ширины и яркости скользят
// по одному и тому же тексту, поэтому блик получается мягким.
Item {
    id: root
    property string text: ""
    property string fontFamily: "Segoe UI"
    property int pixelSize: 7
    property real letterSpacing: 1.6
    property color baseColor: "#6c7075"
    property color shineColor: "#ffffff"
    property real period: 2600          // мс на один проход блика
    property bool animated: true
    property real phase: 0

    implicitWidth: base.implicitWidth
    implicitHeight: base.implicitHeight

    NumberAnimation on phase {
        from: 0; to: 1
        duration: root.period
        loops: Animation.Infinite
        running: root.animated && root.visible
    }

    Text {
        id: base
        text: root.text
        font.family: root.fontFamily
        font.pixelSize: root.pixelSize
        font.letterSpacing: root.letterSpacing
        color: root.baseColor
    }

    ShineBand { bandWidth: root.implicitWidth * .60; strength: .22 }
    ShineBand { bandWidth: root.implicitWidth * .34; strength: .50 }
    ShineBand { bandWidth: root.implicitWidth * .15; strength: 1.0 }

    component ShineBand: Item {
        id: band
        property real bandWidth: 0
        property real strength: 1
        width: bandWidth
        height: root.implicitHeight
        clip: true
        opacity: strength
        // Полоса стартует за левым краем и уходит за правый: стык цикла не виден.
        x: -bandWidth + (root.implicitWidth + bandWidth) * root.phase
        Text {
            x: -band.x
            text: root.text
            font.family: root.fontFamily
            font.pixelSize: root.pixelSize
            font.letterSpacing: root.letterSpacing
            color: root.shineColor
        }
    }
}
