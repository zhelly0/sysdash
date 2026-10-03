import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_showCpu: showCpu.checked
    property alias cfg_showGpu: showGpu.checked
    property alias cfg_showMemory: showMemory.checked
    property alias cfg_showStorage: showStorage.checked
    property alias cfg_showNetwork: showNetwork.checked
    property alias cfg_showGraphs: showGraphs.checked
    property alias cfg_showTemps: showTemps.checked
    property alias cfg_showCoreBars: showCoreBars.checked
    property alias cfg_showCpuDetails: showCpuDetails.checked
    property alias cfg_showIgpuTemp: showIgpuTemp.checked
    property alias cfg_showGpuDetails: showGpuDetails.checked
    property alias cfg_showVram: showVram.checked
    property alias cfg_showDimmTemps: showDimmTemps.checked
    property alias cfg_showCache: showCache.checked
    property alias cfg_showSwap: showSwap.checked
    property alias cfg_showAllDisks: showAllDisks.checked
    property alias cfg_showDiskIo: showDiskIo.checked
    property alias cfg_showUptime: showUptime.checked

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Sections") }
        QQC2.CheckBox { id: showCpu; Kirigami.FormData.label: i18n("Show:"); text: i18n("CPU") }
        QQC2.CheckBox { id: showGpu; text: i18n("GPU") }
        QQC2.CheckBox { id: showMemory; text: i18n("Memory") }
        QQC2.CheckBox { id: showStorage; text: i18n("Storage") }
        QQC2.CheckBox { id: showNetwork; text: i18n("Network") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Everywhere") }
        QQC2.CheckBox { id: showGraphs; Kirigami.FormData.label: i18n("Show:"); text: i18n("History graphs") }
        QQC2.CheckBox { id: showTemps; text: i18n("Temperature pills") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("CPU") }
        QQC2.CheckBox { id: showCpuDetails; Kirigami.FormData.label: i18n("Show:"); text: i18n("Model, clock and load") }
        QQC2.CheckBox { id: showCoreBars; text: i18n("Per-thread usage bars") }
        QQC2.CheckBox { id: showIgpuTemp; text: i18n("Integrated graphics temperature") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("GPU") }
        QQC2.CheckBox { id: showGpuDetails; Kirigami.FormData.label: i18n("Show:"); text: i18n("Model, clock, fan and power") }
        QQC2.CheckBox { id: showVram; text: i18n("VRAM usage") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Memory") }
        QQC2.CheckBox { id: showDimmTemps; Kirigami.FormData.label: i18n("Show:"); text: i18n("RAM stick temperatures") }
        QQC2.CheckBox { id: showCache; text: i18n("Cache as a lighter bar segment") }
        QQC2.CheckBox { id: showSwap; text: i18n("Swap") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Storage & network") }
        QQC2.CheckBox { id: showAllDisks; Kirigami.FormData.label: i18n("Show:"); text: i18n("All drives (off = system drive only)") }
        QQC2.CheckBox { id: showDiskIo; text: i18n("System drive read/write") }
        QQC2.CheckBox { id: showUptime; text: i18n("Uptime") }
    }
}
