import QtQuick

Item {
    id: face
    readonly property real cardHeight: Math.min(108, (height - 156) / 3)
    Text { x: 25; y: 22; text: "ВАШИ АССИСТЕНТЫ"; color: "#b5bac0"; font.family: "Segoe UI"; font.pixelSize: 8; font.letterSpacing: 1.8 }
    Text { anchors.right: parent.right; anchors.rightMargin: 25; y: 22; text: "03"; color: "#757c86"; font.family: "Segoe UI"; font.pixelSize: 9 }
    Text { x: 25; y: 46; text: "Один щелчок — и вы на месте."; color: "#737e8b"; font.family: "Segoe UI"; font.pixelSize: 10 }
    Column {
        x: 22; y: 77; width: parent.width - 44; spacing: 12
        AppTile { width: parent.width; height: face.cardHeight; appName: "Codex"; monogram: "X"; appId: "chatgpt"; available: launcher.chatGptAvailable; caption: "OpenAI" }
        AppTile { width: parent.width; height: face.cardHeight; appName: "Claude"; monogram: "C"; appId: "claude"; available: launcher.claudeAvailable; caption: "Anthropic" }
        AppTile { width: parent.width; height: face.cardHeight; appName: "DeepSeek Harness"; monogram: "D"; appId: "deepseek"; available: launcher.deepSeekAvailable; caption: "Рабочее пространство" }
    }
    Text { x: 25; y: parent.height - 40; width: parent.width - 50; text: launcher.message.length > 0 ? launcher.message : "ЛОКАЛЬНЫЕ ПРИЛОЖЕНИЯ / БЫСТРЫЙ ЗАПУСК"; color: "#85909c"; font.family: "Segoe UI"; font.pixelSize: 9; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
    component AppTile: Rectangle {
        id: tile
        property string appName: ""
        property string monogram: ""
        property string caption: ""
        property string appId: ""
        property bool available: false
        radius: 19; color: hover.hovered ? "#383e46" : "#20252c"; border.color: hover.hovered ? "#c1c9d2" : "#515a65"
        scale: tap.pressed ? .985 : 1
        activeFocusOnTab: true
        Accessible.role: Accessible.Button; Accessible.name: "Открыть " + appName
        Accessible.onPressAction: launcher.launch(tile.appId)
        Behavior on color { ColorAnimation { duration: 240 } }
        Behavior on scale { SpringAnimation { spring: 7; damping: .7 } }
        Rectangle { x: 20; anchors.verticalCenter: parent.verticalCenter; width: 41; height: 41; radius: 13; color: "#eceff3"; Text { anchors.centerIn: parent; text: tile.monogram; color: "#1c2229"; font.family: "Segoe UI Variable Display"; font.pixelSize: 22; font.weight: Font.DemiBold } }
        Column { x: 76; anchors.verticalCenter: parent.verticalCenter; spacing: 5; Text { text: tile.appName; color: "#f1f3f5"; font.family: "Segoe UI Variable Display"; font.pixelSize: tile.height < 94 ? 17 : 20; font.weight: Font.Light } Text { text: tile.available ? tile.caption + "  /  Установлено" : "Не найдено на компьютере"; color: "#909ba8"; font.family: "Segoe UI"; font.pixelSize: 9 } }
        Text { anchors.right: parent.right; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter; text: "↗"; color: "#d6dce3"; font.family: "Segoe UI"; font.pixelSize: 22 }
        Rectangle { visible: tile.activeFocus; anchors.fill: parent; anchors.margins: 3; radius: 16; color: "transparent"; border.color: "#e3e9ef" }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: tap; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: { tile.forceActiveFocus(); launcher.launch(tile.appId) } }
        Keys.onReturnPressed: launcher.launch(tile.appId)
        Keys.onSpacePressed: launcher.launch(tile.appId)
    }
}
