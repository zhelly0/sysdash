import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    readonly property real fs: cfg.fontScale / 100
    readonly property bool anim: cfg.animations

    // ---- palette -------------------------------------------------------
    // By default everything derives from the active Plasma colour scheme, so
    // the widget follows light/dark and accent-colour changes automatically.
    readonly property color cText: Kirigami.Theme.textColor
    readonly property color cDim: Qt.rgba(cText.r, cText.g, cText.b, 0.62)
    readonly property color cPanel: Qt.rgba(cText.r, cText.g, cText.b, cfg.tileOpacity / 100)
    readonly property color cTrack: Qt.rgba(cText.r, cText.g, cText.b, 0.14)
    readonly property color cBorder: Qt.rgba(cText.r, cText.g, cText.b, 0.12)
    readonly property bool themed: cfg.useThemeColors
    readonly property color cCpu: themed ? Kirigami.Theme.highlightColor : cfg.cpuColor
    readonly property color cGpu: themed ? Kirigami.Theme.positiveTextColor : cfg.gpuColor
    readonly property color cMem: themed ? Kirigami.Theme.visitedLinkColor : cfg.memColor
    readonly property color cDisk: themed ? Kirigami.Theme.neutralTextColor : cfg.diskColor
    readonly property color cNet: themed ? Kirigami.Theme.linkColor : cfg.netColor
    // Secondary series (disk writes, uploads) share one colour across sections.
    readonly property color cOut: themed ? Kirigami.Theme.visitedLinkColor : cfg.outColor

    // ---- data ----------------------------------------------------------
    property var stats: ({})
    readonly property var cpu: stats.cpu || ({ cores: [], load: [0, 0, 0] })
    readonly property var gpu: stats.gpu || ({})
    readonly property var mem: stats.mem || ({ dimmTemps: [] })
    readonly property var disks: stats.disks || []
    readonly property var net: stats.net || ({})
    readonly property var rootDisk: disks.find(d => d.mount === "/") || ({})

    readonly property int histLen: Math.max(2, Math.round(cfg.historySeconds * 1000 / cfg.updateInterval))
    property var cpuHist: []
    property var gpuHist: []
    property var memHist: []
    property var readHist: []
    property var writeHist: []
    property var downHist: []
    property var upHist: []

    readonly property string codeDir: Qt.resolvedUrl("../code/").toString().replace(/^file:\/\//, "")
    readonly property string script: codeDir + "stats.py"

    // Width of the bottom taskbar (0 = unknown), polled when matching is enabled.
    property int taskbarWidth: 0
    readonly property int forcedWidth: cfg.matchTaskbarWidth && taskbarWidth > 0 ? taskbarWidth : cfg.fixedWidth

    function push(arr, v) {
        const a = arr.slice(-(histLen - 1));
        a.push(v || 0);
        return a;
    }

    function tempColor(t) {
        if (t === undefined || t === null || isNaN(t)) return cDim;
        const ok = Kirigami.Theme.positiveTextColor, warn = Kirigami.Theme.neutralTextColor;
        if (t < cfg.tempWarm) return ok;
        if (t < cfg.tempHot) return Kirigami.ColorUtils.linearInterpolation(ok, warn, 0.5);
        if (t < cfg.tempCritical) return warn;
        return Kirigami.Theme.negativeTextColor;
    }

    function gib(b) { return ((b || 0) / 1073741824).toFixed(1); }

    function rate(b) {
        b = b || 0;
        if (b >= 1048576) return (b / 1048576).toFixed(b >= 104857600 ? 0 : 1) + " MB/s";
        if (b >= 1024) return (b / 1024).toFixed(0) + " KB/s";
        return b.toFixed(0) + " B/s";
    }

    function uptime(s) {
        s = Math.floor(s || 0);
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (d ? d + "d " : "") + h + "h " + m + "m";
    }

    function diskLabel(d) {
        return d.mount === "/" ? "/" : (d.mount || "").split("/").pop();
    }

    function px(n) { return Math.round(n * fs); }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            if (data["exit code"] !== 0) return;
            try {
                root.stats = JSON.parse(data.stdout);
            } catch (e) {
                return;
            }
            const s = root.stats;
            root.cpuHist = root.push(root.cpuHist, s.cpu.usage);
            root.gpuHist = root.push(root.gpuHist, s.gpu ? s.gpu.usage : 0);
            root.memHist = root.push(root.memHist, 100 * s.mem.used / s.mem.total);
            root.readHist = root.push(root.readHist, root.rootDisk.read);
            root.writeHist = root.push(root.writeHist, root.rootDisk.write);
            root.downHist = root.push(root.downHist, s.net.down);
            root.upHist = root.push(root.upHist, s.net.up);
        }
    }

    Timer {
        interval: root.cfg.updateInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: exec.connectSource("python3 '" + root.script + "'")
    }

    P5Support.DataSource {
        id: panelExec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            root.taskbarWidth = parseInt(data.stdout) || 0;
        }
    }

    Timer {
        interval: 5000
        running: root.cfg.matchTaskbarWidth
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const screen = Plasmoid.containment ? Math.max(Plasmoid.containment.screen, 0) : 0;
            panelExec.connectSource("python3 '" + root.codeDir + "panel.py' " + screen);
        }
    }

    // The full view draws its own background (see fullRepresentation).
    Plasmoid.backgroundHints: Plasmoid.formFactor === PlasmaCore.Types.Planar
        ? PlasmaCore.Types.NoBackground : PlasmaCore.Types.DefaultBackground
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation

    // ---- building blocks ------------------------------------------------
    // Every section is: Header → hero/Metric rows → Spark filling the rest.

    component Caption: Text {
        color: root.cDim
        font.pixelSize: root.px(11)
        font.letterSpacing: 1.2
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
    }

    component Value: Text {
        color: root.cText
        font.pixelSize: root.px(12)
        font.features: { "tnum": 1 }
    }

    component Pill: Rectangle {
        property real temp: NaN
        property string label: ""
        readonly property color tc: root.tempColor(temp)
        implicitWidth: pillText.implicitWidth + 14
        implicitHeight: root.px(20)
        radius: height / 2
        color: Qt.rgba(tc.r, tc.g, tc.b, 0.14)
        border.color: Qt.rgba(tc.r, tc.g, tc.b, 0.35)
        Text {
            id: pillText
            anchors.centerIn: parent
            text: parent.label + " " + (isNaN(parent.temp) ? "–" : Math.round(parent.temp) + "°")
            color: parent.tc
            font.pixelSize: root.px(11)
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    // Section title on the left, labelled temperature pills on the right.
    component Header: RowLayout {
        property string title
        property color accent
        property var temps: []      // [{ label, temp }]
        Layout.fillWidth: true
        Layout.preferredHeight: root.px(20)
        spacing: 4
        Caption { text: parent.title; color: parent.accent }
        Item { Layout.fillWidth: true }
        Repeater {
            model: root.cfg.showTemps ? parent.temps : []
            Pill { label: modelData.label; temp: modelData.temp ?? NaN }
        }
    }

    component Bar: Rectangle {
        property real value: 0      // 0..1
        property real value2: 0     // optional secondary segment (e.g. cache)
        property color accent: root.cCpu
        implicitHeight: 6
        radius: 3
        color: root.cTrack
        Rectangle {
            x: parent.width * Math.min(parent.value, 1)
            width: parent.width * Math.min(parent.value2, Math.max(1 - parent.value, 0))
            height: parent.height
            radius: 3
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.25)
        }
        Rectangle {
            width: parent.width * Math.min(Math.max(parent.value, 0), 1)
            height: parent.height
            radius: 3
            color: parent.accent
            Behavior on width { enabled: root.anim; NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
    }

    // "label  sub ........ value" with an optional bar underneath.
    component Metric: ColumnLayout {
        property string label
        property string sub
        property string value
        property color valueColor: root.cText
        property bool showBar: true
        property real frac: 0
        property real frac2: 0
        property color accent
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Value { text: parent.parent.label; color: root.cDim }
            Value { text: parent.parent.sub; color: root.cDim; opacity: 0.7; font.pixelSize: root.px(11); visible: text !== "" }
            Item { Layout.fillWidth: true }
            Value { text: parent.parent.value; color: parent.parent.valueColor }
        }
        Bar {
            Layout.fillWidth: true
            visible: parent.showBar
            value: parent.frac
            value2: parent.frac2
            accent: parent.accent
        }
    }

    component Ring: Item {
        property real value: 0      // 0..100
        property color accent: root.cCpu
        implicitWidth: root.px(88)
        implicitHeight: root.px(88)
        Behavior on value { enabled: root.anim; NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        onValueChanged: canvas.requestPaint()
        onAccentChanged: canvas.requestPaint()
        Canvas {
            id: canvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const r = width / 2 - 6, cx = width / 2, cy = height / 2;
                const a0 = Math.PI * 0.75, span = Math.PI * 1.5;
                ctx.lineWidth = 7;
                ctx.lineCap = "round";
                ctx.strokeStyle = root.cTrack;
                ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + span); ctx.stroke();
                const v = Math.max(0, Math.min(parent.value, 100)) / 100;
                if (v > 0.005) {
                    ctx.strokeStyle = parent.accent;
                    ctx.beginPath(); ctx.arc(cx, cy, r, a0, a0 + span * v); ctx.stroke();
                }
            }
        }
        Text {
            anchors.centerIn: parent
            text: Math.round(parent.value) + "%"
            color: root.cText
            font.pixelSize: root.px(22)
            font.weight: Font.Light
            font.features: { "tnum": 1 }
        }
    }

    // Ring on the left, up to three detail lines on the right.
    component Hero: RowLayout {
        property real value
        property color accent
        property bool details: true
        property string line1
        property string line2
        property string line3
        Layout.fillWidth: true
        spacing: 12
        Ring { value: parent.value; accent: parent.accent }
        ColumnLayout {
            Layout.fillWidth: true
            visible: parent.details
            spacing: 3
            Value { text: parent.parent.line1; font.pixelSize: root.px(13); font.weight: Font.DemiBold }
            Value { text: parent.parent.line2; color: root.cDim }
            Value { text: parent.parent.line3; color: root.cDim }
        }
    }

    component Spark: Canvas {
        property var series: []          // [[values], ...]
        property var colors: []
        property real maxValue: 100      // 0 = auto-scale
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 24
        visible: root.cfg.showGraphs
        onSeriesChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            let max = maxValue;
            if (!max) {
                max = 1;
                for (const s of series) for (const v of s) max = Math.max(max, v);
                max *= 1.15;
            }
            const step = width / (root.histLen - 1);
            const fill = root.cfg.graphFillOpacity / 100;
            series.forEach((s, i) => {
                if (s.length < 2) return;
                const c = colors[i];
                const x0 = width - (s.length - 1) * step;
                ctx.beginPath();
                s.forEach((v, j) => {
                    const x = x0 + j * step, y = height - 1 - (v / max) * (height - 3);
                    j ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
                });
                ctx.lineWidth = root.cfg.graphLineWidth / 10;
                ctx.strokeStyle = c;
                ctx.stroke();
                if (fill <= 0) return;
                ctx.lineTo(width, height);
                ctx.lineTo(x0, height);
                ctx.closePath();
                const g = ctx.createLinearGradient(0, 0, 0, height);
                g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, fill));
                g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0));
                ctx.fillStyle = g;
                ctx.fill();
            });
        }
    }

    component Section: Rectangle {
        default property alias content: inner.data
        Layout.fillHeight: true
        Layout.fillWidth: root.forcedWidth > 0
        radius: root.cfg.tileRadius
        color: root.cPanel
        ColumnLayout {
            id: inner
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            // With graphs hidden, content stays top-aligned instead of stretching.
            height: root.cfg.showGraphs ? parent.height - 24 : implicitHeight
            spacing: 8
        }
    }

    // ---- panel (compact) view -----------------------------------------
    compactRepresentation: RowLayout {
        spacing: 6
        Text { text: "CPU " + Math.round(root.cpu.usage || 0) + "%"; color: root.cCpu; font.pixelSize: 12 }
        Text { text: Math.round(root.cpu.temp || 0) + "°"; color: root.tempColor(root.cpu.temp); font.pixelSize: 12 }
        Text { text: "GPU " + Math.round(root.gpu.usage || 0) + "%"; color: root.cGpu; font.pixelSize: 12 }
        Text { text: Math.round(root.gpu.temp || 0) + "°"; color: root.tempColor(root.gpu.temp); font.pixelSize: 12 }
        MouseArea {
            Layout.fillHeight: true
            Layout.fillWidth: true
            onClicked: root.expanded = !root.expanded
        }
    }

    // ---- desktop (full) view: horizontal strip --------------------------
    fullRepresentation: Item {
        id: full
        // 0 = taskbar SVG, 1 = Plasma widget SVG, 2 = custom rectangle, 3 = none
        readonly property int bgStyle: root.cfg.backgroundStyle
        readonly property bool svgBg: bgStyle <= 1
        readonly property real customPad: Math.max(8, root.cfg.cornerRadius / 2)
        readonly property real padL: svgBg ? frame.margins.left + 4 : bgStyle === 2 ? customPad : 0
        readonly property real padR: svgBg ? frame.margins.right + 4 : bgStyle === 2 ? customPad : 0
        readonly property real padT: svgBg ? frame.margins.top + 4 : bgStyle === 2 ? customPad : 0
        readonly property real padB: svgBg ? frame.margins.bottom + 4 : bgStyle === 2 ? customPad : 0

        readonly property real autoWidth: body.implicitWidth + padL + padR
        Layout.minimumWidth: root.forcedWidth > 0 ? root.forcedWidth : autoWidth
        Layout.preferredWidth: Layout.minimumWidth
        Layout.minimumHeight: root.px(200) + padT + padB
        Layout.preferredHeight: Layout.minimumHeight

        KSvg.FrameSvgItem {
            id: frame
            anchors.fill: parent
            visible: full.svgBg
            imagePath: full.bgStyle === 1 ? "widgets/background" : "widgets/panel-background"
        }

        Rectangle {
            anchors.fill: parent
            visible: full.bgStyle === 2
            radius: root.cfg.cornerRadius
            color: Qt.rgba(root.cfg.customBgColor.r, root.cfg.customBgColor.g, root.cfg.customBgColor.b, root.cfg.customBgOpacity / 100)
            border.width: root.cfg.customBorder ? 1 : 0
            border.color: root.cBorder
        }

        RowLayout {
            id: body
            anchors.fill: parent
            anchors.leftMargin: full.padL
            anchors.rightMargin: full.padR
            anchors.topMargin: full.padT
            anchors.bottomMargin: full.padB
            spacing: root.cfg.sectionSpacing

            // CPU
            Section {
                visible: root.cfg.showCpu
                Layout.preferredWidth: 300
                Header {
                    title: "CPU"
                    accent: root.cCpu
                    // Tctl = AMD's package/control temperature, Tccd = the core chiplet.
                    // The integrated Radeon graphics lives on the CPU too, so it's shown here.
                    temps: [
                        { label: "Pkg", temp: root.cpu.temp },
                        { label: "Cores", temp: root.cpu.ccd },
                        { label: "iGPU", temp: root.cfg.showIgpuTemp && root.stats.igpu ? root.stats.igpu.temp : null }
                    ].filter(t => t.temp !== undefined && t.temp !== null)
                }
                Hero {
                    value: root.cpu.usage || 0
                    accent: root.cCpu
                    details: root.cfg.showCpuDetails
                    line1: root.cpu.name || ""
                    line2: ((root.cpu.freq || 0) / 1000).toFixed(2) + " GHz"
                    line3: "load " + root.cpu.load.map(l => l.toFixed(2)).join(" ")
                }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 18
                    visible: root.cfg.showCoreBars
                    Row {
                        id: coreRow
                        anchors.fill: parent
                        spacing: 3
                        readonly property int n: Math.max(root.cpu.cores.length, 1)
                        Repeater {
                            model: root.cpu.cores
                            Rectangle {
                                width: (coreRow.width - coreRow.spacing * (coreRow.n - 1)) / coreRow.n
                                height: coreRow.height
                                radius: 2
                                color: root.cTrack
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(2, parent.height * modelData / 100)
                                    radius: 2
                                    color: root.cCpu
                                    opacity: 0.45 + 0.55 * modelData / 100
                                    Behavior on height { enabled: root.anim; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }
                }
                Spark { series: [root.cpuHist]; colors: [root.cCpu] }
            }

            // GPU
            Section {
                visible: root.cfg.showGpu
                Layout.preferredWidth: 300
                Header {
                    title: "GPU"
                    accent: root.cGpu
                    temps: [{ label: "Die", temp: root.gpu.temp }]
                }
                Hero {
                    value: root.gpu.usage || 0
                    accent: root.cGpu
                    details: root.cfg.showGpuDetails
                    line1: root.gpu.name || "No NVIDIA data"
                    line2: (root.gpu.clock || 0) + " MHz · fan " + (root.gpu.fan ?? 0) + "%"
                    line3: Math.round(root.gpu.power || 0) + " / " + Math.round(root.gpu.powerLimit || 0) + " W"
                }
                Metric {
                    visible: root.cfg.showVram
                    label: "VRAM"
                    value: root.gib(root.gpu.vramUsed) + " / " + root.gib(root.gpu.vramTotal) + " GiB"
                    frac: root.gpu.vramTotal ? root.gpu.vramUsed / root.gpu.vramTotal : 0
                    accent: root.cGpu
                }
                Spark { series: [root.gpuHist]; colors: [root.cGpu] }
            }

            // Memory
            Section {
                visible: root.cfg.showMemory
                Layout.preferredWidth: 260
                Header {
                    title: "Memory"
                    accent: root.cMem
                    temps: root.cfg.showDimmTemps ? root.mem.dimmTemps.map((t, i) => ({ label: "DIMM" + (i + 1), temp: t })) : []
                }
                Metric {
                    label: "RAM"
                    value: root.gib(root.mem.used) + " / " + root.gib(root.mem.total) + " GiB"
                    frac: root.mem.total ? root.mem.used / root.mem.total : 0
                    frac2: root.cfg.showCache && root.mem.total ? root.mem.cache / root.mem.total : 0
                    accent: root.cMem
                }
                Metric {
                    visible: root.cfg.showSwap && root.mem.swapTotal > 0
                    label: "Swap"
                    value: root.gib(root.mem.swapUsed) + " / " + root.gib(root.mem.swapTotal) + " GiB"
                    frac: root.mem.swapTotal ? root.mem.swapUsed / root.mem.swapTotal : 0
                    accent: root.cMem
                }
                Spark { series: [root.memHist]; colors: [root.cMem] }
            }

            // Storage
            Section {
                id: storage
                visible: root.cfg.showStorage
                Layout.preferredWidth: 300
                readonly property var shown: root.cfg.showAllDisks ? root.disks : root.disks.filter(d => d.mount === "/")
                Header {
                    title: "Storage"
                    accent: root.cDisk
                    temps: storage.shown.map(d => ({ label: root.diskLabel(d), temp: d.temp }))
                }
                Repeater {
                    model: storage.shown
                    Metric {
                        label: modelData.name
                        sub: root.diskLabel(modelData)
                        value: modelData.total ? Math.round(modelData.used / 1e9) + " / " + Math.round(modelData.total / 1e9) + " GB" : "not mounted"
                        frac: modelData.total ? modelData.used / modelData.total : 0
                        accent: root.cDisk
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.cfg.showDiskIo
                    Value { text: "I/O"; color: root.cDim }
                    Value { text: "/"; color: root.cDim; opacity: 0.7; font.pixelSize: root.px(11) }
                    Item { Layout.fillWidth: true }
                    Value { text: "R " + root.rate(root.rootDisk.read); color: root.cDisk }
                    Value { text: "W " + root.rate(root.rootDisk.write); color: root.cOut; leftPadding: 8 }
                }
                Spark {
                    visible: root.cfg.showGraphs && root.cfg.showDiskIo
                    maxValue: 0
                    series: [root.readHist, root.writeHist]
                    colors: [root.cDisk, root.cOut]
                }
            }

            // Network
            Section {
                visible: root.cfg.showNetwork
                Layout.preferredWidth: 240
                Header {
                    title: "Network"
                    accent: root.cNet
                    Caption {
                        visible: root.cfg.showUptime
                        text: "up " + root.uptime(root.stats.uptime)
                        font.letterSpacing: 0.3
                    }
                }
                Metric {
                    label: "Download"
                    value: root.rate(root.net.down)
                    valueColor: root.cNet
                    showBar: false
                }
                Metric {
                    label: "Upload"
                    value: root.rate(root.net.up)
                    valueColor: root.cOut
                    showBar: false
                }
                Spark { maxValue: 0; series: [root.downHist, root.upHist]; colors: [root.cNet, root.cOut] }
            }
        }
    }
}
