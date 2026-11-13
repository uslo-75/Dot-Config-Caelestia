pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// Un espace de travail de la vue d'ensemble : fond, numéro (ou nom d'un espace spécial) et ses
// fenêtres en miniature, placées comme sur l'écran.
Item {
    id: root

    required property var view // OverviewContent
    required property var wsKey // Numéro, ou "special:nom"

    readonly property bool special: typeof wsKey === "string"
    readonly property HyprlandWorkspace workspace: Hypr.workspaces.values.find(w => special ? w.name === wsKey : w.id === wsKey) ?? null
    readonly property HyprlandMonitor monitor: workspace?.monitor ?? view.monitor
    // Zone utile de l'écran de cet espace, ramenée dans la case en gardant ses proportions.
    readonly property var area: view.usableArea(monitor)
    readonly property real fit: Math.min(width / area.w, height / area.h)
    readonly property real offsetX: (width - area.w * fit) / 2
    readonly property real offsetY: (height - area.h * fit) / 2

    readonly property var windows: view.windowsFor(wsKey)
    // Affiché en ce moment sur son écran.
    readonly property bool visibleNow: special ? monitor?.lastIpcObject?.specialWorkspace?.name === wsKey : monitor?.activeWorkspace?.id === wsKey
    readonly property bool selected: view.selectedWindow === null && view.selectedWs === wsKey
    readonly property bool dropTarget: view.dragWindow !== null && view.dropKey === wsKey && !windows.includes(view.dragWindow)
    readonly property bool otherMonitor: !special && monitor !== view.monitor

    // La case de la fenêtre tenue passe au-dessus des autres.
    z: view.dragWindow !== null && windows.includes(view.dragWindow) ? 2 : 0

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.medium
        color: root.dropTarget ? Colours.palette.m3primaryContainer : hover.containsMouse ? Colours.tPalette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainer
        border.width: root.selected || root.visibleNow ? 2 : 0
        border.color: root.selected ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

        Behavior on border.color {
            CAnim {}
        }
    }

    // Numéro en filigrane d'un espace vide.
    StyledText {
        anchors.centerIn: parent
        visible: !root.special && root.windows.length === 0
        text: String(root.wsKey)
        color: Qt.alpha(Colours.palette.m3onSurface, 0.14)
        font: Tokens.font.title.builders.large.size(Math.max(12, root.height * 0.42)).weight(Font.Bold).build()
    }

    // Clic dans le vide : aller à cet espace.
    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.view.goTo(root.wsKey)
    }

    Repeater {
        model: ScriptModel {
            values: root.windows
        }

        WindowThumb {
            view: root.view
            cell: root
        }
    }

    // Étiquette par-dessus les miniatures : numéro d'un espace occupé (et son écran si ce n'est
    // pas celui de la vue), ou icône et nom d'un espace spécial.
    StyledRect {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Tokens.padding.extraSmall
        z: 50
        visible: root.special || root.windows.length > 0 || root.otherMonitor
        implicitWidth: Math.max(implicitHeight, label.implicitWidth + Tokens.padding.small * 2)
        implicitHeight: label.implicitHeight + Tokens.padding.extraSmall
        radius: Tokens.rounding.full
        color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.9)

        Row {
            id: label

            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.special
                text: root.special ? Icons.matchIconRuleList(Hypr.trimWsName(String(root.wsKey)), GlobalConfig.bar.workspaces.specialWorkspaceIcons) : ""
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.special ? Hypr.trimWsName(String(root.wsKey)) : root.otherMonitor ? `${root.wsKey} · ${root.monitor?.name ?? ""}` : String(root.wsKey)
                font: Tokens.font.label.small
            }
        }
    }
}
