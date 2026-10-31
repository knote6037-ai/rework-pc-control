import QtQuick

Rectangle {
    id: card
    radius: 27
    color: "transparent"
    border.color: "#806f5792"
    Rectangle {
        anchors.fill: parent; radius: card.radius
        gradient: Gradient {
            GradientStop { position: 0; color: "#cd30243f" }
            GradientStop { position: .5; color: "#b5201b2c" }
            GradientStop { position: 1; color: "#a51c1727" }
        }
        border.color: "#806f5792"; border.width: 1
    }
    clip: true
    property real now: Date.now()
    Timer { interval: 1000; repeat: true; running: card.visible; onTriggered: card.now = Date.now() }
    function resetLabel(ms) {
        if (!ms) return "Сброс не указан"
        var left = ms - now
        if (left <= 0) return "Ожидаем сброс от Codex"
        var minutes = Math.ceil(left / 60000)
        var text = minutes >= 1440 ? Math.floor(minutes / 1440) + " д " + Math.floor(minutes % 1440 / 60) + " ч" : minutes >= 60 ? Math.floor(minutes / 60) + " ч " + minutes % 60 + " мин" : minutes + " мин"
        return "Сброс через " + text
    }
    Text { x: 19; y: 15; text: "✦  ASTRA LIMITS"; color: "#f0e8ff"; font.family: "Segoe UI"; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.1 }
    Text { x: 20; y: 35; text: "Осталось в Codex" + (astra.plan ? " · " + astra.plan : ""); color: "#a99bbd"; font.pixelSize: 9 }
    Rectangle {
        anchors.right: parent.right; anchors.rightMargin: 16; y: 14; width: 29; height: 29; radius: 9
        color: hover.hovered ? "#584474" : "#382b4a"
        Text { anchors.centerIn: parent; text: astra.busy ? "···" : "↻"; color: "#c4a1ff"; font.pixelSize: 19 }
        Accessible.role: Accessible.Button; Accessible.name: "Обновить Astra Limits"
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; enabled: !astra.busy; onTapped: astra.refresh() }
    }
    Flickable {
        x: 19; y: 58; width: parent.width - 38; height: parent.height - y - 32
        contentHeight: quotas.height; clip: true; boundsBehavior: Flickable.StopAtBounds
        Column {
            id: quotas; width: parent.width; spacing: 9
            Repeater {
                model: astra.rows
                Item {
                    required property var modelData
                    width: quotas.width; height: 45
                    Text { text: (modelData.bucket ? modelData.bucket + " · " : "") + modelData.label; color: "#d0c1e7"; font.pixelSize: 10; width: parent.width - 90; elide: Text.ElideRight }
                    Text { anchors.right: parent.right; y: -4; text: modelData.remaining < 0 ? "—" : Number(modelData.remaining).toLocaleString(Qt.locale("ru_RU"), 'f', modelData.remaining % 1 ? 1 : 0) + "%"; color: astra.stale ? "#8d819f" : "#d1afff"; font.pixelSize: 19; font.weight: Font.DemiBold; Accessible.role: Accessible.StaticText; Accessible.name: modelData.label + ": осталось " + text }
                    Rectangle { y: 22; width: parent.width; height: 3; radius: 2; color: "#42334f"; Rectangle { width: parent.width * Math.max(0, modelData.remaining) / 100; height: 3; radius: 2; color: astra.stale ? "#796888" : "#ac7ae7"; Behavior on width { NumberAnimation { duration: 550; easing.type: Easing.OutCubic } } } }
                    Text { y: 30; text: card.resetLabel(modelData.resetMs); color: "#a294b4"; font.pixelSize: 8 }
                }
            }
            Text { visible: astra.rows.length === 0; text: astra.busy ? "Читаем лимиты аккаунта…" : "Лимиты пока недоступны"; color: "#c2b0d8"; font.pixelSize: 11 }
        }
    }
    Text { x: 19; y: parent.height - 22; width: parent.width - 38; text: (astra.stale && astra.rows.length ? "Старые данные · " : "") + astra.status; color: astra.stale ? "#bfa0da" : "#9e8dad"; font.pixelSize: 8; elide: Text.ElideRight }
}
