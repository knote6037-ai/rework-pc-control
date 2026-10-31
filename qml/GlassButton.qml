import QtQuick

Rectangle {
    id: button
    property alias text: label.text
    property bool primary: false
    property bool checked: false
    property bool quiet: false
    property bool light: false
    property int fontSize: 13
    property real hoverLevel: hover.hovered ? 1 : 0
    property real shine: -1
    signal clicked()
    implicitHeight: 46
    implicitWidth: 110
    radius: primary ? 16 : 12
    scale: tap.pressed ? .975 : 1 + hoverLevel * .014
    clip: true
    opacity: enabled ? 1 : .42
    color: primary ? (light ? "#f2f2f2" : "#121315") : checked ? (light ? "#f1f1f1" : "#161719") : light ? (hover.hovered ? "#20ffffff" : "#07ffffff") : (hover.hovered ? "#e9e9e9" : "#f0f0f0")
    border.width: 1
    border.color: primary ? (light ? "#ffffff" : "#222326") : checked ? (light ? "#ffffff" : "#1a1b1d") : light ? "#34ffffff" : "#18181818"
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: if (button.enabled) button.clicked()
    Behavior on scale { SpringAnimation { spring: 7; damping: .6; mass: .8 } }
    Behavior on color { ColorAnimation { duration: 240 } }
    Behavior on hoverLevel { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    NumberAnimation on shine { from: -1; to: 2; duration: 1500; loops: Animation.Infinite; running: hover.hovered && button.primary && button.enabled }
    Rectangle { visible: button.activeFocus; anchors.fill: parent; anchors.margins: 2; radius: button.radius - 2; color: "transparent"; border.color: button.light ? "#eeeeee" : "#777777"; border.width: 1 }
    Rectangle { x: 14; y: 1; width: Math.max(0, parent.width - 28); height: 1; color: button.primary ? "#25ffffff" : "transparent" }
    Rectangle { visible: button.primary && button.hoverLevel > .01; x: button.shine * button.width; y: -height * .25; width: button.width * .28; height: button.height * 2; rotation: -20; opacity: button.hoverLevel; gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "#00ffffff" } GradientStop { position: .5; color: "#25ffffff" } GradientStop { position: 1; color: "#00ffffff" } } }
    Text { id: label; anchors.centerIn: parent; color: button.primary ? (button.light ? "#151618" : "#ffffff") : checked ? (button.light ? "#17181a" : "#ffffff") : button.light ? "#d6d7d8" : "#393b3d"; font.family: "Segoe UI Variable Display"; font.pixelSize: button.fontSize; font.weight: button.primary ? Font.DemiBold : Font.Normal; elide: Text.ElideRight; width: Math.max(0, button.width - 24); horizontalAlignment: Text.AlignHCenter }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: { button.forceActiveFocus(); button.clicked() } }
    Keys.onSpacePressed: if (enabled) clicked()
    Keys.onReturnPressed: if (enabled) clicked()
}
