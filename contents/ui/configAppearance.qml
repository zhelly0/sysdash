import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls

KCM.SimpleKCM {
    property alias cfg_updateInterval: intervalCtl.value
    property alias cfg_historySeconds: historyCtl.value
    property alias cfg_animations: animationsCtl.checked
    property alias cfg_fixedWidth: widthCtl.value
    property alias cfg_matchTaskbarWidth: matchCtl.checked
    property alias cfg_sectionSpacing: spacingCtl.value
    property alias cfg_fontScale: fontScaleCtl.value
    property alias cfg_backgroundStyle: bgStyleCtl.currentIndex
    property alias cfg_customBgColor: bgColorCtl.color
    property alias cfg_customBgOpacity: bgOpacityCtl.value
    property alias cfg_cornerRadius: radiusCtl.value
    property alias cfg_customBorder: borderCtl.checked
    property alias cfg_tileOpacity: tileOpacityCtl.value
    property alias cfg_tileRadius: tileRadiusCtl.value

    component SliderRow: RowLayout {
        property alias from: slider.from
        property alias to: slider.to
        property alias stepSize: slider.stepSize
        property alias value: slider.value
        property string suffix: ""
        property var format: v => v + suffix
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
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Updates") }

        SliderRow {
            id: intervalCtl
            Kirigami.FormData.label: i18n("Refresh every:")
            from: 250; to: 5000; stepSize: 250
            format: v => v < 1000 ? v + " ms" : (v / 1000).toFixed(v % 1000 ? 2 : 0) + " s"
        }
        SliderRow {
            id: historyCtl
            Kirigami.FormData.label: i18n("Graph history:")
            from: 30; to: 600; stepSize: 30
            format: v => v < 60 ? v + " s" : (v / 60).toFixed(v % 60 ? 1 : 0) + " min"
        }
        QQC2.CheckBox { id: animationsCtl; text: i18n("Animate gauges and bars") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Layout") }

        QQC2.CheckBox {
            id: matchCtl
            Kirigami.FormData.label: i18n("Width:")
            text: i18n("Match the bottom taskbar's width")
        }
        RowLayout {
            enabled: !matchCtl.checked
            QQC2.SpinBox {
                id: widthCtl
                from: 0; to: 5120; stepSize: 8
                editable: true
                textFromValue: v => v === 0 ? i18n("Auto") : v + " px"
                valueFromText: t => parseInt(t) || 0
            }
            QQC2.Label {
                text: i18n("0 = fit content")
                opacity: 0.7
                font: Kirigami.Theme.smallFont
            }
        }
        SliderRow { id: spacingCtl; Kirigami.FormData.label: i18n("Section spacing:"); from: 0; to: 32; stepSize: 1; suffix: " px" }
        SliderRow { id: fontScaleCtl; Kirigami.FormData.label: i18n("Text size:"); from: 80; to: 150; stepSize: 5; suffix: " %" }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Background") }

        QQC2.ComboBox {
            id: bgStyleCtl
            Kirigami.FormData.label: i18n("Style:")
            model: [i18n("Match taskbar"), i18n("Plasma widget"), i18n("Custom"), i18n("None")]
        }
        KQuickControls.ColorButton {
            id: bgColorCtl
            Kirigami.FormData.label: i18n("Color:")
            enabled: bgStyleCtl.currentIndex === 2
        }
        SliderRow {
            id: bgOpacityCtl
            Kirigami.FormData.label: i18n("Opacity:")
            enabled: bgStyleCtl.currentIndex === 2
            from: 0; to: 100; stepSize: 5; suffix: " %"
        }
        SliderRow {
            id: radiusCtl
            Kirigami.FormData.label: i18n("Corner radius:")
            enabled: bgStyleCtl.currentIndex === 2
            from: 0; to: 32; stepSize: 1; suffix: " px"
        }
        QQC2.CheckBox { id: borderCtl; text: i18n("Thin border"); enabled: bgStyleCtl.currentIndex === 2 }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Section tiles") }

        SliderRow { id: tileOpacityCtl; Kirigami.FormData.label: i18n("Tile tint:"); from: 0; to: 20; stepSize: 1; suffix: " %" }
        SliderRow { id: tileRadiusCtl; Kirigami.FormData.label: i18n("Tile corner radius:"); from: 0; to: 24; stepSize: 1; suffix: " px" }
    }
}
