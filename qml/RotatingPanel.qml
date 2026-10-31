import QtQuick
import QtQuick.Effects

// Панель-барабан в стиле Bentley Rotating Display.
// Переворот идёт вокруг ГОРИЗОНТАЛЬНОЙ оси: грань уходит вверх/вниз.
// В момент поворота содержимое уходит в motion-blur, как раскрытие складного
// дисплея: к «ребру» размытие максимально, на месте — полностью чисто.
Item {
    id: display
    objectName: "bentleyRotatingPanel"
    property int currentIndex: 0
    property bool locked: false
    property real phase: 0
    property int destination: 0
    property int direction: 1
    property real angle: 0
    // 0 — панель стоит лицом, 1 — стоит ребром
    readonly property real edge: Math.abs(Math.sin(angle * Math.PI / 180))
    readonly property bool turning: turn.running
    default property alias faces: faceContent.data

    function goTo(index) {
        var next = ((index % 3) + 3) % 3
        if (locked || turning || next === currentIndex) return
        destination = next
        direction = ((next - currentIndex + 3) % 3) === 1 ? 1 : -1
        turn.start()
    }
    function next() { goTo(currentIndex + 1) }
    function previous() { goTo(currentIndex - 1) }

    // Мягкая тень: во время переворота панель «отрывается» от подложки.
    Rectangle {
        x: 8; y: 20; width: parent.width - 16; height: parent.height - 10
        radius: 30; color: "#5c000000"
        scale: 1 - display.edge * .05
        opacity: .9 - display.edge * .25
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    }

    // Торцевое ребро барабана: видно, когда панель встаёт боком.
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 6; height: 13
        radius: 6
        visible: display.turning
        opacity: Math.min(1, display.edge * 1.6)
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: "#171a1e" }
            GradientStop { position: .5; color: "#b9c1c9" }
            GradientStop { position: 1; color: "#171a1e" }
        }
    }

    // Ось вращения и псевдоперспектива.
    Item {
        id: pivot
        anchors.fill: parent
        scale: 1 - display.edge * .05
        transform: Rotation {
            origin.x: pivot.width / 2
            origin.y: pivot.height / 2
            axis.x: 1; axis.y: 0; axis.z: 0
            angle: display.angle
        }

        // Содержимое грани. Blur применяется отдельным эффектом ниже.
        Item {
            id: rotor
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent; radius: 27
                gradient: Gradient {
                    GradientStop { position: 0; color: "#e42a2d32" }
                    GradientStop { position: .5; color: "#ed15181d" }
                    GradientStop { position: 1; color: "#f00c0e12" }
                }
                border.color: "#7c8289"; border.width: 1
            }
            Rectangle { x: 28; y: 1; width: parent.width - 56; height: 1; color: "#5bffffff" }
            Rectangle {
                x: 31 + (parent.width - width - 62) * (.5 + .5 * Math.sin(display.phase * 2)); y: 1
                width: parent.width * .32; height: 2; radius: 1
                gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "#00ffffff" } GradientStop { position: .5; color: "#d0ffffff" } GradientStop { position: 1; color: "#00ffffff" } }
            }

            MouseArea {
                anchors.fill: parent; enabled: !display.locked && !display.turning
                cursorShape: Qt.PointingHandCursor
                onClicked: display.next()
            }

            Item { id: faceContent; anchors.fill: parent; enabled: !display.turning && !display.locked }

            // Затенение уходящей грани: чем ближе к ребру, тем темнее.
            Rectangle {
                anchors.fill: parent; radius: 27; enabled: false
                opacity: Math.min(.72, display.edge * .95)
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0; color: display.direction > 0 ? "#c8000000" : "#00000000" }
                    GradientStop { position: .55; color: "#30000000" }
                    GradientStop { position: 1; color: display.direction > 0 ? "#00000000" : "#c8000000" }
                }
            }
        }

        // Motion-blur содержимого — ТОЛЬКО на время переворота.
        // В покое источник не подключён, поэтому панель рисуется напрямую
        // и остаётся резкой: слой-текстура иначе мылит картинку.
        MultiEffect {
            anchors.fill: parent
            source: display.turning ? rotor : null
            visible: display.turning
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 44
            blur: Math.min(1, display.edge * .55)
        }
    }

    SequentialAnimation {
        id: turn
        NumberAnimation {
            target: display; property: "angle"
            from: 0; to: display.direction * 90
            duration: 640; easing.type: Easing.InCubic
        }
        ScriptAction { script: { display.currentIndex = display.destination; display.angle = -display.direction * 90 } }
        NumberAnimation {
            target: display; property: "angle"
            to: 0
            duration: 780; easing.type: Easing.OutCubic
        }
    }
}
