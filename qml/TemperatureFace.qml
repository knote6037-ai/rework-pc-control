import QtQuick

Item {
    id: face
    Text { x: 25; y: 22; text: "ТЕМПЕРАТУРА / LIVE SENSORS"; color: "#b5bac0"; font.family: "Segoe UI"; font.pixelSize: 8; font.letterSpacing: 1.7 }
    Text { anchors.right: parent.right; anchors.rightMargin: 25; y: 22; text: "02"; color: "#757c86"; font.family: "Segoe UI"; font.pixelSize: 9 }
    Sensor {
        id: cpu; x: 22; y: 57; width: parent.width - 44; height: (parent.height - 105) / 2
        label: "ПРОЦЕССОР"; deviceName: telemetry.cpuName; temperature: telemetry.cpuTemperature; load: telemetry.cpuLoad
        status: telemetry.cpuStatus; samples: telemetry.cpuHistory; isCpu: true
    }
    Sensor {
        x: 22; y: cpu.y + cpu.height + 12; width: cpu.width; height: cpu.height
        label: "ВИДЕОКАРТА"; deviceName: telemetry.gpuName; temperature: telemetry.gpuTemperature; load: telemetry.gpuLoad
        status: telemetry.gpuStatus; samples: telemetry.gpuHistory
    }
    Text { x: 25; y: parent.height - 21; text: telemetry.updatedAt.length > 0 ? "ОБНОВЛЕНО В " + telemetry.updatedAt : "ЧТЕНИЕ ДАТЧИКОВ"; color: "#6f7782"; font.family: "Segoe UI"; font.pixelSize: 7; font.letterSpacing: 1 }
    Text { anchors.right: parent.right; anchors.rightMargin: 25; y: parent.height - 21; text: "BENTLEY EDITION"; color: "#6f7782"; font.family: "Segoe UI"; font.pixelSize: 7; font.letterSpacing: 1 }

    component Sensor: Rectangle {
        id: sensor
        property string label: ""
        property string deviceName: ""
        property string status: ""
        property real temperature: -1
        property real load: -1
        property var samples: []
        property bool isCpu: false
        readonly property bool dense: height < 180
        radius: 19; color: "#f0f1f1"; border.color: "#f9fafb"
        Text { x: 20; y: 14; text: sensor.label; color: "#878c92"; font.family: "Segoe UI"; font.pixelSize: 7; font.letterSpacing: 1.8 }
        Text { x: 20; y: 30; width: parent.width - 40; text: sensor.deviceName; color: "#32383f"; font.family: "Segoe UI"; font.pixelSize: 10; elide: Text.ElideRight }
        Row {
            x: 18; y: sensor.dense ? 45 : 53; spacing: 5
            Text { text: sensor.temperature >= 0 ? Math.round(sensor.temperature).toString() : "—"; color: "#161a1f"; font.family: "Segoe UI Light"; font.pixelSize: sensor.dense ? 44 : 54; font.weight: Font.Light; font.letterSpacing: -2; Accessible.role: Accessible.StaticText; Accessible.name: sensor.label + " " + text + " градусов" }
            Text { y: 9; text: "°C"; color: "#9ba1a7"; font.family: "Segoe UI Light"; font.pixelSize: 21 }
        }
        Column {
            anchors.right: parent.right; anchors.rightMargin: 22; y: sensor.dense ? 52 : 65; spacing: 3
            Text { anchors.right: parent.right; text: "НАГРУЗКА"; color: "#9da3a9"; font.family: "Segoe UI"; font.pixelSize: 6; font.letterSpacing: 1.1 }
            Text { anchors.right: parent.right; text: sensor.load >= 0 ? Math.round(sensor.load) + "%" : "—"; color: "#575f68"; font.family: "Segoe UI Light"; font.pixelSize: 23 }
        }
        Canvas {
            x: 20; y: sensor.height - 55; width: parent.width - 40; height: sensor.dense ? 20 : 27
            visible: sensor.temperature >= 0
            property var values: sensor.samples
            onValuesChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                var c = getContext("2d"); c.reset(); c.strokeStyle = "#d9dde0"; c.lineWidth = 1
                c.beginPath(); c.moveTo(0, height - .5); c.lineTo(width, height - .5); c.stroke()
                var data = values || []; if (data.length < 2) return
                c.beginPath(); var first = true
                for (var i = 0; i < data.length; ++i) { var n = Number(data[i]); if (n < 0 || !isFinite(n)) { first = true; continue }; var px = width * i / Math.max(1, data.length - 1); var py = height - Math.max(0, Math.min(110, n)) / 110 * height; if (first) { c.moveTo(px, py); first = false } else c.lineTo(px, py) }
                c.lineWidth = 1.6; c.strokeStyle = "#454f59"; c.lineJoin = "round"; c.stroke()
            }
        }
        Text { x: 20; y: sensor.height - (sensor.temperature < 0 && sensor.isCpu ? 49 : 23); width: parent.width - 40; text: sensor.status; color: "#9299a0"; font.family: "Segoe UI"; font.pixelSize: 8; elide: Text.ElideRight }
        GlassButton { visible: sensor.isCpu && sensor.temperature < 0; x: 18; y: parent.height - 34; width: Math.min(parent.width - 36, 212); height: 25; text: "Подключить датчик CPU"; fontSize: 9; onClicked: telemetry.connectCpuSensors() }
    }
}
