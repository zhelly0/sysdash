import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-theme"
        source: "configAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Sections")
        icon: "view-list-details"
        source: "configSections.qml"
    }
    ConfigCategory {
        name: i18n("Colors")
        icon: "preferences-desktop-color"
        source: "configColors.qml"
    }
}
