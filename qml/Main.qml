import QtQuick
import QtQuick.Window

Window {
    id: root
    objectName: "mainWindow"
    width: 1280; height: 880
    minimumWidth: 980; minimumHeight: 740
    visible: true; color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: "Rework PC Control" + (control.demo ? " · Демо" : "")
    // Рабочая доска имеет фиксированный размер и масштабируется целиком:
    // при развороте на весь экран панели становятся больше, но сохраняют
    // пропорции и не вытягиваются.
    readonly property real boardWidth: 1280
    readonly property real boardHeight: 833
    property bool compact: false
    property bool counting: control.mode === "closed" || (control.mode === "pending" && control.previousMode === "closed")
    property bool ending: control.mode === "shuttingDown"
    property bool richMotion: true
    property real phase: 0
    property real entrance: 0
    property real pageWidth: Math.min(width - 96, 1240)
    readonly property color ink: "#141517"
    readonly property color paper: "#f5f5f3"
    onClosing: function(close) { close.accepted = false; control.hideWindow() }
    NumberAnimation on phase { from: 0; to: Math.PI * 2; duration: 36000; loops: Animation.Infinite; running: root.richMotion; paused: !root.visible || root.visibility === Window.Minimized }
    NumberAnimation on entrance { from: 0; to: 1; duration: 1050; easing.type: Easing.OutCubic; running: true }
    function twoDigits(value) { return value < 10 ? "0" + value : "" + value }
    function countdownText() { return twoDigits(Math.floor(control.remainingSeconds / 60)) + ":" + twoDigits(control.remainingSeconds % 60) }
    function toggleMaximized() { if (root.visibility === Window.Maximized) root.showNormal(); else root.showMaximized() }
    function act() { if (!root.ending) control.prepare(control.minutes) }

    Rectangle { anchors.fill: parent; color: "#101113"; radius: root.visibility === Window.Maximized ? 0 : 15; border.color: "#525458"; border.width: 1 }

    Item {
        id: windowBar
        enabled: control.mode !== "pending" && !confirmationShade.visible
        x: 17; y: 9; width: parent.width - 34; height: 33; z: 20
        DragHandler { target: null; acceptedButtons: Qt.LeftButton; onActiveChanged: if (active) root.startSystemMove() }
        TapHandler { onDoubleTapped: root.toggleMaximized() }
        Text { anchors.verticalCenter: parent.verticalCenter; x: 10; text: "R E W O R K   /   P C   C O N T R O L"; font.family: "Segoe UI"; font.pixelSize: 8; color: "#75777a" }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 5
            Repeater {
                model: ["−", "□", "×"]
                Rectangle {
                    required property string modelData; required property int index
                    width: 34; height: 29; radius: 8; color: windowHover.hovered ? "#22ffffff" : "transparent"
                    Accessible.role: Accessible.Button
                    Accessible.name: index === 0 ? "Свернуть" : index === 1 ? "Развернуть" : "Скрыть в трей"
                    Text { anchors.centerIn: parent; text: modelData; color: "#c5c6c8"; font.family: "Segoe UI"; font.pixelSize: index === 2 ? 20 : 16 }
                    HoverHandler { id: windowHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: { if (index === 0) root.showMinimized(); else if (index === 1) root.toggleMaximized(); else control.hideWindow() } }
                }
            }
        }
    }

    Item {
        id: stage
        x: 1; y: 47; width: root.width - 2; height: root.height - y - 1
        clip: true
        enabled: control.mode !== "pending" && !confirmationShade.visible

        ShaderEffect { anchors.fill: parent; property vector2d resolution: Qt.vector2d(width, height); property real phase: root.phase; fragmentShader: "qrc:/shaders/atmosphere.frag.qsb" }
        Repeater {
            model: 24
            Rectangle {
                required property int index
                readonly property real progress: (root.phase / (Math.PI * 2) + index * .0618034) % 1
                x: stage.width * ((index * .381966) % 1) + Math.sin(root.phase * 2 + index) * 24
                y: stage.height * (1 - progress)
                width: index % 5 === 0 ? 3 : 1.4
                height: width; radius: width / 2
                color: "#e9edf2"
                opacity: Math.sin(progress * Math.PI) * (index % 5 === 0 ? .48 : .19)
            }
        }
        Rectangle { x: stage.width * (.59 + Math.sin(root.phase) * .04); y: 45 + Math.cos(root.phase) * 32; width: stage.width * .37; height: width; radius: width / 2; color: "transparent"; border.width: 1; border.color: "#16ffffff" }
        Rectangle { x: stage.width * (.025 + Math.cos(root.phase) * .025); y: 175 + Math.sin(root.phase * 2) * 22; width: stage.width * .40; height: width; radius: width / 2; color: "transparent"; border.width: 1; border.color: "#12ffffff" }

        Item {
            id: board
            width: root.boardWidth
            height: root.boardHeight
            // Масштаб считается от левого верхнего угла, иначе доска «уезжает»
            // при увеличении и обрезается по краям.
            transformOrigin: Item.TopLeft
            scale: Math.min(stage.width / width, stage.height / height)
            x: (stage.width - width * scale) / 2
            y: (stage.height - height * scale) / 2

        Item {
            id: content; width: 1184; height: board.height; x: (board.width - width) / 2
            y: (1 - root.entrance) * 18; opacity: root.entrance

            Row {
                y: 14; spacing: 12
                Rectangle { width: 35; height: 35; radius: 11; color: "#eeeeee"; Text { anchors.centerIn: parent; text: "R"; color: "#111214"; font.family: "Segoe UI Variable Display"; font.pixelSize: 22; font.weight: Font.DemiBold } }
                Text { y: 1; text: "rework"; color: "#f5f5f4"; font.family: "Segoe UI Variable Display"; font.pixelSize: 27; font.weight: Font.DemiBold; font.letterSpacing: -1.2 }
                Rectangle { y: 10; width: 1; height: 17; color: "#4c4d50" }
                Text { y: 12; text: "BLACK / WHITE"; color: "#8b8d90"; font.family: "Segoe UI"; font.pixelSize: 8; font.letterSpacing: 1.8 }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 20; color: "#4c4d50" }
                ShimmerText { anchors.verticalCenter: parent.verticalCenter; text: "BENTLEY EDITION  /  ROTATING DISPLAY"; pixelSize: 10; letterSpacing: 1.7; baseColor: "#65696e"; period: 2200 }
            }
            Row {
                anchors.right: parent.right; y: 18; spacing: 13
                Rectangle { visible: control.demo; width: 151; height: 27; radius: 14; color: "#1c1e21"; border.color: "#3f4145"; Text { anchors.centerIn: parent; text: "Демо · без выключения"; color: "#bfc1c4"; font.family: "Segoe UI"; font.pixelSize: 10 } }
                Row { height: 27; spacing: 7; Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 4; height: 4; radius: 2; color: "#e5e5e5" } Text { anchors.verticalCenter: parent.verticalCenter; text: "На вашем компьютере"; color: "#85878a"; font.family: "Segoe UI"; font.pixelSize: 10 } }
            }
            Text { y: root.compact ? 68 : 76; text: "ВРЕМЯ. ПОД ВАШИМ КОНТРОЛЕМ."; color: "#7d8084"; font.family: "Segoe UI"; font.pixelSize: 8; font.letterSpacing: 2.3 }
            Text { y: root.compact ? 87 : 96; text: "Точность в каждой детали."; color: "#f2f2f1"; font.family: "Segoe UI Variable Display"; font.pixelSize: root.compact ? 30 : 37; font.weight: Font.Light; font.letterSpacing: -1.2 }
            Text { anchors.right: parent.right; y: root.compact ? 103 : 112; text: "01  /  YOUR SPACE"; color: "#707276"; font.family: "Segoe UI"; font.pixelSize: 8; font.letterSpacing: 1.7 }

            Item {
                id: cards
                y: root.compact ? 137 : 154
                width: parent.width
                height: content.height - y - 18
                property int gap: 25
                property real selectorHeight: 42

                // ---------- ЛЕВАЯ ПАНЕЛЬ: три грани, как в Bentley ----------
                Item {
                    id: leftColumn
                    width: (cards.width - cards.gap) * .545
                    height: parent.height

                    RotatingPanel {
                        id: panel
                        width: parent.width
                        height: parent.height - cards.selectorHeight
                        objectName: "bentleyPanel"

                        // Грань 1 — часы
                        Item {
                            id: clockFace
                            anchors.fill: parent
                            visible: panel.currentIndex === 0
                            Text { x: 26; y: 22; text: "МЕСТНОЕ ВРЕМЯ"; color: "#aeb0b3"; font.family: "Segoe UI"; font.pixelSize: 8; font.letterSpacing: 1.8 }
                            Row { anchors.right: parent.right; anchors.rightMargin: 26; y: 22; spacing: 6; Rectangle { y: 3; width: 4; height: 4; radius: 2; color: "#e9e9e9" } Text { text: "LIVE"; color: "#d3d4d5"; font.family: "Segoe UI"; font.pixelSize: 8; font.letterSpacing: 1.4 } }
                            ClockFace {
                                id: dial
                                width: Math.min(clockFace.width - 56, clockFace.height - (root.compact ? 121 : 139), 444)
                                height: width
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: root.compact ? 40 : 42
                                animated: root.richMotion && root.visible && root.visibility !== Window.Minimized && panel.currentIndex === 0
                            }
                            Text { id: digital; anchors.horizontalCenter: parent.horizontalCenter; y: dial.y + dial.height + (root.compact ? 0 : 7); text: control.timeString; color: "#f2f2f2"; font.family: "Segoe UI Light"; font.pixelSize: root.compact ? 28 : 34; font.weight: Font.Light; font.letterSpacing: -1.3 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; y: digital.y + digital.height + 1; text: control.dateString; color: "#8a8d91"; font.family: "Segoe UI"; font.pixelSize: 10 }
                            Text { x: 27; y: parent.height - 24; text: "DIAMOND SKELETON"; color: "#64676b"; font.family: "Segoe UI"; font.pixelSize: 7; font.letterSpacing: 1.8 }
                            Text { anchors.right: parent.right; anchors.rightMargin: 27; y: parent.height - 24; text: "REWORK  /  EDITION 03"; color: "#64676b"; font.family: "Segoe UI"; font.pixelSize: 7; font.letterSpacing: .8 }
                        }

                        // Грань 2 — датчики
                        TemperatureFace { anchors.fill: parent; visible: panel.currentIndex === 1 }

                        // Грань 3 — ассистенты
                        AssistantFace { anchors.fill: parent; visible: panel.currentIndex === 2 }
                    }

                    // Переключатель граней
                    Row {
                        y: parent.height - cards.selectorHeight + 6
                        spacing: 6
                        Repeater {
                            model: ["ВРЕМЯ", "ДАТЧИКИ", "АССИСТЕНТЫ"]
                            Rectangle {
                                required property string modelData; required property int index
                                height: 30; width: selectorLabel.implicitWidth + 26; radius: 10
                                color: panel.currentIndex === index ? "#f0f0ee" : "#1b1d21"
                                border.width: 1; border.color: panel.currentIndex === index ? "#ffffff" : "#3a3d42"
                                Accessible.role: Accessible.Button
                                Accessible.name: "Показать грань " + modelData
                                Behavior on color { ColorAnimation { duration: 220 } }
                                Text { id: selectorLabel; anchors.centerIn: parent; text: modelData; font.family: "Segoe UI"; font.pixelSize: 9; font.letterSpacing: 1.1; color: panel.currentIndex === index ? "#15171a" : "#8b9096" }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: panel.goTo(index) }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 6
                            text: "↻  нажмите на панель, чтобы перевернуть"
                            color: "#6d7378"; font.family: "Segoe UI"; font.pixelSize: 9
                        }
                    }
                }

                // ---------- ПРАВАЯ ПАНЕЛЬ: управление ----------
                Rectangle {
                    id: controlPanel; x: leftColumn.width + cards.gap; width: cards.width - x; height: parent.height
                    radius: 27; color: "transparent"; border.color: "transparent"
                    // Only the material is translucent; text and controls stay crisp.
                    Rectangle {
                        anchors.top: parent.top; width: parent.width; height: astraPanel.y - 12
                        radius: 27
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#d6fafafa" }
                            GradientStop { position: .55; color: "#bff0f0f3" }
                            GradientStop { position: 1; color: "#b3e8e8ee" }
                        }
                        border.width: 1; border.color: "#99ffffff"
                    }
                    Rectangle { x: 28 + (parent.width - width - 56) * (.5 + .5 * Math.cos(root.phase * 2)); y: 1; width: parent.width * .30; height: 3; radius: 2; gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "#00b6bcc4" } GradientStop { position: .5; color: "#b0a3abb6" } GradientStop { position: 1; color: "#00b6bcc4" } } }
                    property int inset: root.compact ? 25 : 31
                    property real usableWidth: width - inset * 2
                    Text { x: controlPanel.inset; y: 18; text: "РЕЖИМ ПРОСТРАНСТВА"; color: "#6e7073"; font.family: "Segoe UI"; font.pixelSize: 8; font.letterSpacing: 1.8 }
                    Rectangle { anchors.right: parent.right; anchors.rightMargin: controlPanel.inset; y: 20; width: 5; height: 5; radius: 3; color: "#1e2023" }
                    Text { id: modeLabel; x: controlPanel.inset; y: 39; text: root.ending ? "Выключение…" : root.counting ? "Закрыто" : "Открыто"; color: root.ink; font.family: "Segoe UI Variable Display"; font.pixelSize: 30; font.weight: Font.Light; font.letterSpacing: -1.4 }
                    Text { x: controlPanel.inset; y: modeLabel.y + modeLabel.height + 2; width: controlPanel.usableWidth; text: root.ending ? "Запрос на выключение передан Windows." : root.counting ? "Таймер идёт. Завершите всё важное." : "Компьютер готов. Пространство открыто."; color: "#77797c"; font.family: "Segoe UI"; font.pixelSize: 11 }
                    Rectangle {
                        id: modeSwitch; x: controlPanel.inset; y: 98; width: controlPanel.usableWidth; height: 38; radius: 12; color: "#e7e7e5"
                        Rectangle { x: root.counting || root.ending ? parent.width / 2 + 2 : 3; y: 3; width: parent.width / 2 - 5; height: parent.height - 6; radius: 11; color: "#ffffff"; border.color: "#e1e1df"; Behavior on x { SpringAnimation { spring: 5; damping: .76; mass: 1 } } }
                        Repeater {
                            model: ["Открыто", "Закрыто"]
                            Item {
                                required property int index; required property string modelData
                                x: index * modeSwitch.width / 2; width: modeSwitch.width / 2; height: modeSwitch.height
                                Accessible.role: Accessible.Button; Accessible.name: modelData
                                Accessible.onPressAction: { if (index === 0) control.cancel(); else if (!root.counting) root.act() }
                                Text { anchors.centerIn: parent; text: (index === 0 ? "•  " : "⏻  ") + modelData; color: ((index === 0) !== root.counting) ? "#15171a" : "#8b8d90"; font.family: "Segoe UI"; font.pixelSize: 12 }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; enabled: !root.ending; onTapped: { if (index === 0) control.cancel(); else if (!root.counting) root.act() } }
                            }
                        }
                    }
                    Item {
                        id: duration; x: controlPanel.inset; y: 149; width: controlPanel.usableWidth; height: 66
                        Text { text: "Выключить через"; color: "#3d3f42"; font.family: "Segoe UI"; font.pixelSize: 11 }
                        Text { anchors.right: parent.right; text: root.counting ? "Для нового отсчёта" : "После подтверждения"; color: "#62656c"; font.family: "Segoe UI"; font.pixelSize: 9 }
                        Row {
                            y: 25; width: parent.width; spacing: 5
                            Repeater { model: [5, 10, 20, 30]; GlassButton { required property int modelData; width: (duration.width - 75 - 20) / 4; height: 36; text: modelData + " мин"; fontSize: 10; checked: control.minutes === modelData; enabled: !root.ending; onClicked: control.setDuration(modelData) } }
                            Rectangle {
                                width: 75; height: 36; radius: 12; color: "#eaeae8"; border.color: customTime.activeFocus ? "#999b9d" : "#dcdcda"
                                TextInput {
                                    id: customTime; objectName: "customMinutes"; x: 5; y: (parent.height - height) / 2; width: 34
                                    text: control.minutes.toString(); color: "#1f2124"; font.family: "Segoe UI"; font.pixelSize: 11
                                    horizontalAlignment: TextInput.AlignRight; selectByMouse: true; validator: IntValidator { bottom: 1; top: 180 }
                                    enabled: !root.ending; Accessible.name: "Своё время в минутах"
                                    onEditingFinished: { var n = Number(text); if (Number.isInteger(n) && n >= 1 && n <= 180) control.setDuration(n); text = control.minutes.toString() }
                                    Keys.onReturnPressed: { focus = false; powerAction.forceActiveFocus() }
                                    Connections { target: control; function onStateChanged() { if (!customTime.activeFocus) customTime.text = control.minutes.toString() } }
                                }
                                Text { x: 45; anchors.verticalCenter: parent.verticalCenter; text: "мин"; color: "#8e9093"; font.family: "Segoe UI"; font.pixelSize: 9 }
                            }
                        }
                    }
                    Item {
                        id: countdown; x: controlPanel.inset; y: 215; width: controlPanel.usableWidth; height: 49; visible: root.counting
                        Text { text: "ДО ВЫКЛЮЧЕНИЯ"; color: "#939598"; font.family: "Segoe UI"; font.pixelSize: 7; font.letterSpacing: 1.7 }
                        Text { anchors.right: parent.right; text: control.deadlineMs > 0 ? "в " + Qt.formatDateTime(new Date(control.deadlineMs), "HH:mm") : ""; color: "#999b9d"; font.family: "Segoe UI"; font.pixelSize: 9 }
                        Text { y: 11; text: root.countdownText(); color: "#181a1d"; font.family: "Segoe UI Light"; font.pixelSize: 30; font.weight: Font.Light; font.letterSpacing: -1.5; Accessible.role: Accessible.StaticText; Accessible.name: "Осталось до выключения " + text }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; radius: 1; color: "#dcdcda"; Rectangle { width: parent.width * Math.max(0, Math.min(1, control.progress)); height: parent.height; radius: 1; color: "#242629"; Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.Linear } } } }
                    }
                    Item {
                        id: actions; x: controlPanel.inset; y: root.counting ? countdown.y + countdown.height + 8 : 215; width: controlPanel.usableWidth; height: root.counting ? 98 : 83
                        Behavior on y { NumberAnimation { duration: 480; easing.type: Easing.OutCubic } }
                        GlassButton { id: powerAction; width: parent.width; height: 39; text: root.ending ? "Выключение компьютера…" : root.counting ? "Применить и начать заново  ↗" : "⏻   Выключить  ↗"; primary: true; enabled: !root.ending; onClicked: { customTime.focus = false; root.act() } }
                        GlassButton { y: 45; width: parent.width; height: 31; text: "Отменить выключение"; fontSize: 11; visible: root.counting; onClicked: control.cancel() }
                        Text { visible: !root.counting; y: 47; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.ending ? "Сохраните открытые файлы в Windows." : "Первое нажатие — вопрос. Второе — таймер."; color: "#62656c"; font.family: "Segoe UI"; font.pixelSize: 9 }
                    }
                    Row { x: controlPanel.inset; y: root.counting ? 364 : 278; spacing: 10; Text { text: "☼"; color: "#6a6d70"; font.pixelSize: 22 } Column { y: 3; spacing: 2; Text { text: "Подсветка комнаты"; color: "#696c6f"; font.family: "Segoe UI"; font.pixelSize: 10 } Text { text: "Отображение режима"; color: "#a4a6a8"; font.family: "Segoe UI"; font.pixelSize: 8 } } }
                    Text { anchors.right: parent.right; anchors.rightMargin: controlPanel.inset; y: root.counting ? 371 : 285; text: root.counting ? "Закрыто" : "Открыто"; color: "#74777a"; font.family: "Segoe UI"; font.pixelSize: 9 }
                    AstraPanel { id: astraPanel; x: 0; y: root.counting ? 405 : 320; width: parent.width; height: parent.height - y }
                }
            }

            Item {
                y: content.height - 14; width: parent.width; height: 14
                Text { anchors.right: parent.right; y: -4; text: "LIVE HARDWARE MONITORING"; color: "#777a7e"; font.family: "Segoe UI"; font.pixelSize: 7; font.letterSpacing: 1.3 }
            }
        }
        }
    }

    Rectangle {
        id: notice; visible: control.message.length > 0 && control.mode !== "pending"
        anchors.horizontalCenter: parent.horizontalCenter; y: root.height - height - 14; z: 5
        width: Math.min(root.width - 100, messageText.implicitWidth + 42); height: messageText.height + 24
        radius: 14; color: "#f0222427"; border.color: "#676a6e"
        Text { id: messageText; x: 20; y: 12; width: Math.min(implicitWidth, root.width - 142); wrapMode: Text.WordWrap; text: control.message; color: "#e9e9e9"; font.family: "Segoe UI"; font.pixelSize: 11 }
    }
    Rectangle {
        id: confirmationShade; anchors.fill: parent; color: "#bb070809"; opacity: control.mode === "pending" ? 1 : 0; visible: opacity > .001; z: 30
        onVisibleChanged: if (!visible && control.mode !== "pending") Qt.callLater(function() { if (control.mode !== "pending") powerAction.forceActiveFocus() })
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: control.dismiss() }
        Rectangle {
            id: confirmSheet; enabled: control.mode === "pending"; focus: control.mode === "pending"
            Accessible.role: Accessible.Dialog; Accessible.name: root.counting ? "Начать отсчёт заново?" : "Точно закрыть?"
            width: Math.min(470, root.width - 80); height: root.counting ? 348 : 324; anchors.centerIn: parent; radius: 28; color: "#f6f6f4"; border.color: "#ffffff"
            scale: control.mode === "pending" ? 1 : .94; Behavior on scale { SpringAnimation { spring: 4; damping: .74; mass: 1 } }
            MouseArea { anchors.fill: parent; onClicked: function(mouse) { mouse.accepted = true } }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 25; width: 44; height: 44; radius: 16; color: "#e7e7e5"; Text { anchors.centerIn: parent; text: "?"; color: "#41464c"; font.family: "Segoe UI Light"; font.pixelSize: 25 } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 85; text: root.counting ? "Начать отсчёт заново?" : "Точно закрыть?"; color: root.ink; font.family: "Segoe UI Variable Display"; font.pixelSize: 25; font.weight: Font.Light }
            Text { x: 40; y: 126; width: parent.width - 80; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: "Компьютер выключится через " + control.minutes + " мин.\n" + (root.counting ? "Текущий таймер будет заменён новым." : "Сохраните всё важное перед выключением."); color: "#85898e"; font.family: "Segoe UI"; font.pixelSize: 12; lineHeight: 1.45 }
            Text { visible: root.counting; anchors.horizontalCenter: parent.horizontalCenter; y: 180; text: "Текущий отсчёт: " + root.countdownText(); color: "#666c72"; font.family: "Segoe UI"; font.pixelSize: 11 }
            GlassButton { id: confirmAction; x: 30; y: root.counting ? 215 : 192; width: parent.width - 60; height: 48; text: "Да, закрыть и запустить таймер"; primary: true; KeyNavigation.tab: dismissAction; KeyNavigation.backtab: dismissAction; onClicked: if (control.mode === "pending") control.confirm() }
            GlassButton { id: dismissAction; x: 30; y: root.counting ? 272 : 249; width: parent.width - 60; height: 35; text: root.counting ? "Оставить текущий таймер" : "Продолжить работу"; fontSize: 11; KeyNavigation.tab: confirmAction; KeyNavigation.backtab: confirmAction; onClicked: if (control.mode === "pending") control.dismiss() }
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 26; text: "Подтверждение действует 30 секунд"; color: "#a0a3a7"; font.family: "Segoe UI"; font.pixelSize: 9 }
        }
    }
    Shortcut { sequence: "Escape"; enabled: control.mode === "pending"; onActivated: control.dismiss() }
    Shortcut { sequence: "Right"; enabled: control.mode !== "pending"; onActivated: panel.next() }
    Shortcut { sequence: "Left"; enabled: control.mode !== "pending"; onActivated: panel.previous() }
    Shortcut { sequence: "1"; enabled: control.mode !== "pending"; onActivated: panel.goTo(0) }
    Shortcut { sequence: "2"; enabled: control.mode !== "pending"; onActivated: panel.goTo(1) }
    Shortcut { sequence: "3"; enabled: control.mode !== "pending"; onActivated: panel.goTo(2) }
    Connections { target: control; property string lastMode: "open"; function onStateChanged() { if (control.mode === "pending" && lastMode !== "pending") Qt.callLater(function() { if (control.mode === "pending") confirmAction.forceActiveFocus() }); lastMode = control.mode } }
}
