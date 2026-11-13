pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common
import qs.modules.launcher.services
import qs.modules.launcher.studio

// Couleurs du shell : thème (dynamique d'après le fond d'écran, ou l'un des thèmes fournis par
// `caelestia scheme`), mode et variante du thème dynamique mémorisés pour le fond commun, et
// transparence. Les couleurs sont les mêmes sur tous les écrans.
PageBase {
    id: root

    readonly property bool dynamic: Colours.scheme === "dynamic"
    readonly property string wall: Wallpapers.actualCurrent
    readonly property var theme: {
        WallStudio.themes; // dépendance
        return WallStudio.themeFor(wall);
    }
    // Thèmes de `caelestia scheme list`, le dynamique en tête.
    readonly property var schemes: {
        const list = [...Schemes.list];
        const rank = s => s.name === "dynamic" ? 0 : 1;
        return list.sort((a, b) => rank(a) - rank(b) || `${a.name} ${a.flavour}`.localeCompare(`${b.name} ${b.flavour}`));
    }
    readonly property var swatchNames: [["primary", "Primaire"], ["secondary", "Secondaire"], ["tertiary", "Tertiaire"], ["primaryContainer", "Conteneur"], ["surfaceContainerHigh", "Surface"], ["error", "Erreur"]]

    // Écrans dont le fond n'est pas celui qui donne les couleurs.
    readonly property var otherScreens: {
        WallStudio.screenWalls; // dépendance
        return WallStudio.screenNames.filter(s => WallStudio.wallFor(s) !== wall);
    }

    function schemeTitle(name: string): string {
        return name === "dynamic" ? "Dynamique" : name.charAt(0).toUpperCase() + name.slice(1);
    }

    // Deuxième ligne d'une tuile : la déclinaison, quand le thème en a plusieurs.
    function schemeDetail(name: string, flavour: string): string {
        if (name === "dynamic")
            return flavour === "hard" ? "selon le fond, contrasté" : "selon le fond d'écran";
        return schemes.filter(s => s.name === name).length > 1 ? flavour : "";
    }

    title: Tr.tr("Colours")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Palette en cours
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.medium
            spacing: Tokens.spacing.small

            Repeater {
                model: root.swatchNames

                ColumnLayout {
                    id: swatch

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: Tokens.rounding.large
                        color: Colours.palette[`m3${swatch.modelData[0]}`]
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: swatch.modelData[1]
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Thème
        SectionHeader {
            first: true
            text: "Thème"
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: Tokens.spacing.small
            columnSpacing: Tokens.spacing.small

            Repeater {
                model: root.schemes

                StyledRect {
                    id: tile

                    required property var modelData
                    readonly property bool selected: Colours.scheme === modelData.name && Colours.flavour === modelData.flavour
                    readonly property var colours: modelData.colours

                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: selected ? Tokens.rounding.medium : Tokens.rounding.large
                    color: selected ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer

                    StateLayer {
                        radius: tile.radius
                        color: tile.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        onClicked: Quickshell.execDetached(["caelestia", "scheme", "set", "-n", tile.modelData.name, "-f", tile.modelData.flavour])
                    }

                    Row {
                        id: dots

                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: -6

                        Repeater {
                            model: ["primary", "secondary", "tertiary", "surface"]

                            Rectangle {
                                required property string modelData
                                required property int index

                                implicitWidth: 22
                                implicitHeight: 22
                                radius: 11
                                z: 4 - index
                                border.width: 2
                                border.color: tile.color
                                color: tile.colours?.[modelData] ? `#${tile.colours[modelData]}` : Colours.palette.m3surfaceContainerHighest
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.left: dots.right
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.spacing.medium
                        anchors.rightMargin: Tokens.padding.small
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: root.schemeTitle(tile.modelData.name)
                            color: tile.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            font: Tokens.font.label.large
                            elide: Text.ElideRight
                        }

                        StyledText {
                            readonly property string detail: root.schemeDetail(tile.modelData.name, tile.modelData.flavour)

                            Layout.fillWidth: true
                            visible: detail !== ""
                            text: detail
                            color: tile.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }
                    }

                    Behavior on radius {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }
            }
        }

        // Thème dynamique : mode et variante mémorisés pour le fond commun
        SectionHeader {
            visible: root.dynamic
            text: `Couleurs tirées de « ${WallStudio.displayName(root.wall)} »`
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.small
            visible: root.dynamic
            text: WallStudio.hasOwnWalls ? "Les couleurs sont les mêmes sur tous les écrans : elles viennent du fond commun, pas du fond propre à un écran. Le mode et la variante choisis ici sont mémorisés pour ce fond." : "Le mode et la variante choisis ici sont mémorisés pour ce fond et reviennent chaque fois qu'il est appliqué."
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        // Tirer les couleurs du fond d'un autre écran : il devient le fond commun, chaque écran
        // garde ce qu'il affiche.
        Repeater {
            model: root.dynamic ? root.otherScreens : []

            RowButton {
                required property string modelData
                required property int index

                Layout.bottomMargin: index === root.otherScreens.length - 1 ? Tokens.spacing.medium : 0
                first: index === 0
                last: index === root.otherScreens.length - 1
                icon: "colorize"
                text: `Prendre les couleurs du fond de ${modelData}`
                subtext: `« ${WallStudio.displayName(WallStudio.wallFor(modelData))} » · chaque écran garde son fond`
                onClicked: WallStudio.themeFromScreen(modelData)
            }
        }

        ThemePicker {
            Layout.fillWidth: true
            visible: root.dynamic
            embedded: true
            shown: root.dynamic
            path: root.wall
            theme: root.theme
            onPicked: (mode, variant) => WallStudio.setTheme(root.wall, mode, variant)
        }

        // Réglages
        SectionHeader {
            text: "Réglages"
        }

        // Le thème dynamique a son propre choix de mode, mémorisé par fond, juste au-dessus.
        ToggleRow {
            first: true
            visible: !root.dynamic
            text: Tr.tr("Dark theme")
            checked: !Colours.light
            onToggled: Colours.setMode(checked ? "dark" : "light")
        }

        ToggleRow {
            first: root.dynamic
            text: "Mode et variante automatiques"
            subtext: "Caelestia choisit sombre ou clair et la variante d'après le fond d'écran"
            checked: GlobalConfig.services.smartScheme
            onToggled: GlobalConfig.services.smartScheme = checked
        }

        ToggleRow {
            text: Tr.tr("Transparency")
            subtext: "Panneaux du shell translucides, avec flou"
            checked: Colours.transparency.enabled
            onToggled: GlobalConfig.appearance.transparency.enabled = checked
        }

        SliderRow {
            icon: "opacity"
            label: "Opacité du fond des panneaux"
            valueLabel: `${Math.round(value * 100)} %`
            value: GlobalConfig.appearance.transparency.base
            enabled: Colours.transparency.enabled
            onMoved: v => GlobalConfig.appearance.transparency.base = Math.round(v * 100) / 100
        }

        SliderRow {
            last: true
            icon: "layers"
            label: "Opacité des éléments"
            valueLabel: `${Math.round(value * 100)} %`
            value: GlobalConfig.appearance.transparency.layers
            enabled: Colours.transparency.enabled
            onMoved: v => GlobalConfig.appearance.transparency.layers = Math.round(v * 100) / 100
        }
    }
}
