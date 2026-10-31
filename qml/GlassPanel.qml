import QtQuick

Item {
    id: panel
    property var sceneSource
    property Item sceneItem
    property real cornerRadius: 30
    property real glow: 0
    property point origin: Qt.point(0, 0)
    property real hoverAmount: hover.hovered ? 1 : 0
    default property alias content: contentItem.data

    function updateOrigin() {
        if (sceneItem) origin = panel.mapToItem(sceneItem, 0, 0)
    }
    onXChanged: updateOrigin()
    onYChanged: updateOrigin()
    onWidthChanged: updateOrigin()
    onHeightChanged: updateOrigin()
    Component.onCompleted: updateOrigin()
    Connections {
        target: panel.sceneItem
        function onWidthChanged() { panel.updateOrigin() }
        function onHeightChanged() { panel.updateOrigin() }
    }
    Behavior on hoverAmount { NumberAnimation { duration: 550; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 14
        anchors.bottomMargin: -14
        radius: panel.cornerRadius
        color: "#35000000"
    }
    ShaderEffect {
        anchors.fill: parent
        property var source: panel.sceneSource
        property vector2d panelSize: Qt.vector2d(width, height)
        property vector2d sceneSize: Qt.vector2d(panel.sceneItem ? panel.sceneItem.width : width, panel.sceneItem ? panel.sceneItem.height : height)
        property vector2d scenePosition: Qt.vector2d(panel.origin.x, panel.origin.y)
        property real cornerRadius: panel.cornerRadius
        property real hoverAmount: panel.hoverAmount + panel.glow
        property vector2d hoverPosition: Qt.vector2d(hover.point.position.x, hover.point.position.y)
        fragmentShader: "qrc:/shaders/glass.frag.qsb"
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 0.5
        radius: panel.cornerRadius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(.92, .95, 1, .18 + panel.hoverAmount * .08)
    }
    Rectangle {
        x: panel.cornerRadius
        y: 0
        width: Math.max(0, parent.width - panel.cornerRadius * 2)
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#00f3f5ff" }
            GradientStop { position: .35; color: "#8af3f5ff" }
            GradientStop { position: 1; color: "#00f3f5ff" }
        }
    }
    HoverHandler { id: hover }
    Item { id: contentItem; anchors.fill: parent }
}
