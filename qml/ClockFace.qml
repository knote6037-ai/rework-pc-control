import QtQuick

Item {
    id: dial
    property bool animated: true
    property real stamp: Date.now()
    property date moment: new Date(stamp)
    property real secondAngle: (moment.getSeconds() + moment.getMilliseconds() / 1000) * 6
    property real minuteAngle: (moment.getMinutes() + secondAngle / 360) * 6
    property real hourAngle: ((moment.getHours() % 12) + minuteAngle / 360) * 30
    // Keep shader time small enough for sub-frame precision on GPU floats.
    readonly property real lightTime: (stamp % 600000) / 1000
    property real hoverX: hover.hovered ? (hover.point.position.x / Math.max(width, 1) - .5) : 0
    property real hoverY: hover.hovered ? (hover.point.position.y / Math.max(height, 1) - .5) : 0
    implicitWidth: 420
    implicitHeight: 420
    Accessible.role: Accessible.Clock
    Accessible.name: "Местное время " + Qt.formatDateTime(moment, "HH:mm")
    Behavior on hoverX { SpringAnimation { spring: 4; damping: .82; mass: 1.1 } }
    Behavior on hoverY { SpringAnimation { spring: 4; damping: .82; mass: 1.1 } }

    FrameAnimation {
        running: dial.animated && dial.visible
        onTriggered: dial.stamp = Date.now()
    }
    Timer {
        interval: 1000
        running: !dial.animated && dial.visible
        repeat: true
        onTriggered: dial.stamp = Date.now()
    }

    // Image, hands and glints share one transform, so the pinion stays aligned.
    Item {
        id: watch
        width: Math.min(dial.width, dial.height)
        height: width
        anchors.centerIn: parent
        transform: [
            Rotation { origin.x: watch.width / 2; origin.y: watch.height / 2; axis.x: 0; axis.y: 1; axis.z: 0; angle: dial.hoverX * 2.1 },
            Rotation { origin.x: watch.width / 2; origin.y: watch.height / 2; axis.x: 1; axis.y: 0; axis.z: 0; angle: -dial.hoverY * 1.7 }
        ]

        Canvas {
            width: parent.width * 1.14; height: width
            anchors.centerIn: parent
            opacity: dial.animated ? .58 + Math.sin(dial.lightTime * .7) * .16 : .58
            scale: dial.animated ? 1 + Math.sin(dial.lightTime * .5) * .025 : 1
            onWidthChanged: requestPaint()
            onPaint: {
                var c = getContext("2d"); c.reset()
                var g = c.createRadialGradient(width / 2, height / 2, width * .25, width / 2, height / 2, width * .5)
                g.addColorStop(0, "#00ffffff"); g.addColorStop(.55, "#22e4eaff"); g.addColorStop(1, "#00ffffff")
                c.fillStyle = g; c.fillRect(0, 0, width, height)
            }
        }

        Image {
            id: jewelArtwork
            anchors.fill: parent
            source: "qrc:/assets/diamond-dial.png"
            sourceSize.width: 1280
            sourceSize.height: 1280
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            asynchronous: true
            visible: false
        }
        ShaderEffect {
            anchors.fill: parent
            property var source: jewelArtwork
            property real lightTime: dial.lightTime
            property real movement: dial.animated ? 1 : 0
            fragmentShader: "qrc:/shaders/jewel.frag.qsb"
        }

        // A light travels around the setting while independent bright facets
        // scintillate. Stars are deliberately large enough to read at 400 px.
        Repeater {
            model: [
                {x:.237,y:.115,s:.88}, {x:.377,y:.136,s:.67},
                {x:.510,y:.137,s:.82}, {x:.651,y:.142,s:.72},
                {x:.792,y:.119,s:.95}, {x:.886,y:.251,s:.75},
                {x:.895,y:.361,s:.67}, {x:.897,y:.642,s:.82},
                {x:.874,y:.766,s:.83}, {x:.785,y:.867,s:.96},
                {x:.648,y:.839,s:.70}, {x:.493,y:.850,s:.95},
                {x:.349,y:.853,s:.72}, {x:.235,y:.860,s:.83},
                {x:.116,y:.775,s:.90}, {x:.092,y:.661,s:.73},
                {x:.091,y:.489,s:.85}, {x:.099,y:.331,s:.75},
                {x:.132,y:.225,s:.84}, {x:.275,y:.301,s:.50},
                {x:.488,y:.277,s:.47}, {x:.633,y:.338,s:.53},
                {x:.363,y:.547,s:.48}, {x:.675,y:.548,s:.49},
                {x:.490,y:.713,s:.47}, {x:.270,y:.702,s:.47}
            ]
            Item {
                id: facet
                required property var modelData
                required property int index
                readonly property real sweepPosition: ((dial.lightTime * .19) % 1) * 26
                readonly property real sweepDistance: Math.min(Math.abs(index - sweepPosition), 26 - Math.abs(index - sweepPosition))
                readonly property real sweep: dial.animated ? Math.exp(-sweepDistance * sweepDistance / 3.3) : 0
                readonly property real pulse: dial.animated ? Math.pow(Math.max(0, Math.sin(dial.lightTime * (1.25 + index * .009) + index * 2.731)), 6) : .13
                readonly property real proximity: hover.hovered ? Math.max(0, 1 - Math.hypot(hover.point.position.x / Math.max(dial.width, 1) - modelData.x,
                    hover.point.position.y / Math.max(dial.height, 1) - modelData.y) / .18) : 0
                readonly property real intensity: Math.min(1, .025 + sweep * .98 + pulse * .9 + proximity * .65)
                width: watch.width * .123 * modelData.s
                height: width
                x: watch.width * modelData.x - width / 2
                y: watch.height * modelData.y - height / 2
                opacity: intensity
                scale: .61 + intensity * .52
                rotation: (index % 3 === 0 ? 16 : -10) + (dial.animated ? Math.sin(dial.lightTime * .25 + index) * 7 : 0)
                visible: opacity > .004
                Canvas {
                    anchors.fill: parent
                    antialiasing: true
                    onWidthChanged: requestPaint()
                    onPaint: {
                        var c = getContext("2d"); c.reset()
                        var cx = width / 2, cy = height / 2, r = width * .49
                        var bloom = c.createRadialGradient(cx, cy, 0, cx, cy, r)
                        bloom.addColorStop(0, "#dcffffff")
                        bloom.addColorStop(.10, "#80ffffff")
                        bloom.addColorStop(.35, "#20ffffff")
                        bloom.addColorStop(1, "#00ffffff")
                        c.fillStyle = bloom; c.fillRect(0, 0, width, height)
                        // Dark optical fringe makes white rays visible on pale stones.
                        c.beginPath(); c.moveTo(cx, cy - r); c.lineTo(cx, cy + r)
                        c.moveTo(cx - r * .82, cy); c.lineTo(cx + r * .82, cy)
                        c.strokeStyle = "#55252a31"; c.lineWidth = 4.4; c.stroke()
                        c.beginPath()
                        c.moveTo(cx, cy - r); c.lineTo(cx + width * .035, cy - width * .035)
                        c.lineTo(cx + r * .82, cy); c.lineTo(cx + width * .035, cy + width * .035)
                        c.lineTo(cx, cy + r); c.lineTo(cx - width * .035, cy + width * .035)
                        c.lineTo(cx - r * .82, cy); c.lineTo(cx - width * .035, cy - width * .035)
                        c.closePath(); c.fillStyle = "#ffffff"; c.fill()
                        c.beginPath(); c.moveTo(cx - r * .35, cy - r * .35); c.lineTo(cx + r * .35, cy + r * .35)
                        c.moveTo(cx + r * .35, cy - r * .35); c.lineTo(cx - r * .35, cy + r * .35)
                        c.strokeStyle = "#c8ffffff"; c.lineWidth = 1; c.stroke()
                        c.beginPath(); c.arc(cx, cy, Math.max(1.8, width * .038), 0, Math.PI * 2)
                        c.fillStyle = "white"; c.fill()
                    }
                }
            }
        }

        // The photographed movement's centre is slightly above/left of the
        // canvas centre. All hand rotation uses the actual pinion coordinates.
        PolishedHand {
            x: watch.width * .490625
            y: watch.height * .4875
            length: watch.height * .230
            breadth: watch.width * .048
            tail: watch.height * .026
            rotation: dial.hourAngle
        }
        PolishedHand {
            x: watch.width * .490625
            y: watch.height * .4875
            length: watch.height * .307
            breadth: watch.width * .036
            tail: watch.height * .035
            rotation: dial.minuteAngle
        }
        Item {
            x: watch.width * .490625
            y: watch.height * .4875
            rotation: dial.secondAngle
            Rectangle {
                x: -width / 2
                y: -watch.height * .326
                width: Math.max(2.5, watch.width * .0062)
                height: watch.height * .390
                color: "#050608"
                border.width: .8
                border.color: "#ffffff"
                radius: width / 2
            }
            Rectangle {
                x: -width / 2
                y: watch.height * .052
                width: watch.width * .018
                height: width
                radius: width / 2
                color: "#14161a"
                border.color: "#e8ebee"
                border.width: 1.1
            }
        }

        Rectangle {
            x: watch.width * .490625 - width / 2
            y: watch.height * .4875 - height / 2
            width: watch.width * .052
            height: width
            radius: width / 2
            border.width: .7
            border.color: "#d9dee4"
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#c1c7ce" }
                GradientStop { position: .34; color: "#ffffff" }
                GradientStop { position: .53; color: "#3d4148" }
                GradientStop { position: 1; color: "#a4abb3" }
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * .41
                height: width
                radius: width / 2
                color: "#171a20"
                border.color: "#aeb7c1"
                border.width: .6
            }
        }
    }

    HoverHandler { id: hover }

    component PolishedHand: Item {
        id: hand
        property real length: 80
        property real breadth: 10
        property real tail: 12
        width: 0
        height: 0
        transformOrigin: Item.TopLeft
        Canvas {
            x: -hand.breadth / 2 - 6
            y: -hand.length - 6
            width: hand.breadth + 12
            height: hand.length + hand.tail + 12
            antialiasing: true
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var b = hand.breadth, h = hand.length + hand.tail
                function shape(dx, dy) {
                    ctx.beginPath()
                    ctx.moveTo(6 + b * .5 + dx, 6 + dy)
                    ctx.lineTo(6 + b * .92 + dx, 6 + h * .16 + dy)
                    ctx.lineTo(6 + b * .78 + dx, 6 + h * .83 + dy)
                    ctx.lineTo(6 + b * .72 + dx, 6 + h * .96 + dy)
                    ctx.quadraticCurveTo(6 + b * .5 + dx, 6 + h * 1.02 + dy, 6 + b * .28 + dx, 6 + h * .96 + dy)
                    ctx.lineTo(6 + b * .22 + dx, 6 + h * .83 + dy)
                    ctx.lineTo(6 + b * .08 + dx, 6 + h * .16 + dy)
                    ctx.closePath()
                }
                shape(1.5, 2.5)
                ctx.fillStyle = "#bc000000"; ctx.strokeStyle = "#95000000"; ctx.lineWidth = 4
                ctx.fill(); ctx.stroke()
                var metal = ctx.createLinearGradient(6, 0, 6 + b, 0)
                metal.addColorStop(0, "#454a51"); metal.addColorStop(.18, "#111419")
                metal.addColorStop(.48, "#030405"); metal.addColorStop(.8, "#111419"); metal.addColorStop(1, "#5d636b")
                shape(0, 0)
                ctx.fillStyle = metal; ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 1.8
                ctx.fill(); ctx.stroke()
                // A broad luminous inlay distinguishes the moving hand from the skeleton bridges.
                ctx.beginPath()
                ctx.moveTo(6 + b * .5, 6 + h * .13)
                ctx.lineTo(6 + b * .59, 6 + h * .25)
                ctx.lineTo(6 + b * .59, 6 + h * .78)
                ctx.lineTo(6 + b * .41, 6 + h * .78)
                ctx.lineTo(6 + b * .41, 6 + h * .25)
                ctx.closePath(); ctx.fillStyle = "#f4f8fc"; ctx.fill()
            }
        }
    }
}
