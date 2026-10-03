import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls

KCM.SimpleKCM {
    property alias cfg_useThemeColors: useTheme.checked
    property alias cfg_cpuColor: cpuColor.color
    property alias cfg_gpuColor: gpuColor.color
    property alias cfg_memColor: memColor.color
    property alias cfg_diskColor: diskColor.color
    property alias cfg_netColor: netColor.color
    property alias cfg_outColor: outColor.color
    property alias cfg_tempWarm: warm.value
    property alias cfg_tempHot: hot.value
    property alias cfg_tempCritical: critical.value
    property alias cfg_graphLineWidth: lineWidth.value
    property alias cfg_graphFillOpacity: fillOpacity.value

    component SliderRow: RowLayout {
        property alias from: slider.from
        property alias to: slider.to
        property alias stepSize: slider.stepSize
        property alias value: slider.value
        property var format: v => v
        QQC2.Slider {
            id: slider
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            snapMode: QQC2.Slider.SnapAlways
        }
        QQC2.Label {
            Layout.minimumWidth: Kirigami.Units.gridUnit * 4
            text: parent.format(slider.value)
            font.features: { "tnum": 1 }
        }
    }

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Section colors") }

        QQC2.CheckBox {
            id: useTheme
            Kirigami.FormData.label: i18n("Source:")
            text: i18n("Follow the Plasma color scheme")
        }
        KQuickControls.ColorButton { id: cpuColor; Kirigami.FormData.label: i18n("CPU:"); enabled: !useTheme.checked }
        KQuickControls.ColorButton { id: gpuColor; Kirigami.FormData.label: i18n("GPU:"); enabled: !useTheme.checked }
        KQuickControls.ColorButton { id: memColor; Kirigami.FormData.label: i18n("Memory:"); enabled: !useTheme.checked }
        KQuickControls.ColorButton { id: diskColor; Kirigami.FormData.label: i18n("Storage:"); enabled: !useTheme.checked }
        KQuickControls.ColorButton { id: netColor; Kirigami.FormData.label: i18n("Network:"); enabled: !useTheme.checked }
        KQuickControls.ColorButton { id: outColor; Kirigami.FormData.label: i18n("Writes / uploads:"); enabled: !useTheme.checked }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Temperature colors") }

        SliderRow {
            id: warm
            Kirigami.FormData.label: i18n("Warm from:")
            from: 30; to: 90; stepSize: 1
            format: v => v + " °C"
            onValueChanged: if (hot.value <= value) hot.value = value + 1
        }
        SliderRow {
            id: hot
            Kirigami.FormData.label: i18n("Hot from:")
            from: 31; to: 100; stepSize: 1
            format: v => v + " °C"
            onValueChanged: {
                if (warm.value >= value) warm.value = value - 1;
                if (critical.value <= value) critical.value = value + 1;
            }
        }
        SliderRow {
            id: critical
            Kirigami.FormData.label: i18n("Critical from:")
            from: 32; to: 110; stepSize: 1
            format: v => v + " °C"
            onValueChanged: if (hot.value >= value) hot.value = value - 1
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Graphs") }

        SliderRow {
            id: lineWidth
            Kirigami.FormData.label: i18n("Line width:")
            from: 5; to: 40; stepSize: 5
            format: v => (v / 10).toFixed(1) + " px"
        }
        SliderRow {
            id: fillOpacity
            Kirigami.FormData.label: i18n("Fill under line:")
            from: 0; to: 80; stepSize: 2
            format: v => v + " %"
        }
    }
}
