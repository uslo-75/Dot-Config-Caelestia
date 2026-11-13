pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Models
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus.common
import qs.modules.launcher.studio

// Galerie des fonds d'écran des réglages : images et fonds animés du dossier (sous-dossiers
// compris), filtres et favoris du studio, recherche, mini-clip au survol. Le fond choisi
// s'applique à l'écran visé (« Tous les écrans » ou un seul).
PageBase {
    id: root

    property string search
    // Écran visé dans cette fenêtre de réglages ("" : tous les écrans).
    readonly property string target: nState.wallTarget
    readonly property string targetWall: WallStudio.wallOf(target)
    readonly property var targets: WallStudio.targetsFor(nState.screen?.name ?? "")
    readonly property list<string> videoExtensions: ["mp4", "webm", "mkv", "mov", "avi", "m4v"]
    readonly property string featured: Quickshell.shellPath("assets/wallpaper.webp")

    readonly property var filters: [
        {
            key: "all",
            name: "Tous",
            icon: "apps"
        },
        {
            key: "images",
            name: "Images",
            icon: "image"
        },
        {
            key: "videos",
            name: "Animés",
            icon: "animated_images"
        },
        {
            key: "favourites",
            name: "Favoris",
            icon: "star"
        }
    ]

    readonly property var found: Wallpapers.query(search)
    readonly property var entries: {
        WallStudio.favourites;
        WallStudio.items;
        const f = WallStudio.filter;
        return found.filter(w => matches(w.path, f));
    }
    readonly property var counts: {
        WallStudio.favourites;
        WallStudio.items;
        const c = {
            all: 0,
            images: 0,
            videos: 0,
            favourites: 0
        };
        for (const w of found) {
            c.all++;
            if (WallStudio.isVideo(w.path))
                c.videos++;
            else
                c.images++;
            if (WallStudio.isFavourite(w.path))
                c.favourites++;
        }
        return c;
    }
    // Le fond fourni avec Caelestia, proposé avec les images tant qu'on ne cherche rien.
    readonly property bool showFeatured: search === "" && (WallStudio.filter === "all" || WallStudio.filter === "images")

    function matches(path: string, f: string): bool {
        if (f === "images")
            return !WallStudio.isVideo(path);
        if (f === "videos")
            return WallStudio.isVideo(path);
        if (f === "favourites")
            return WallStudio.isFavourite(path);
        return true;
    }

    title: root.target ? `${Tr.tr("Wallpapers")} · ${WallStudio.targetName(root.target)}` : Tr.tr("Wallpapers")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.medium

        // Recherche et actions
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            SearchBar {
                Layout.fillWidth: true
                placeholderText: "Rechercher un fond d'écran"
                font: Tokens.font.body.medium
                bg.color: Colours.tPalette.m3surfaceContainer
                onTextChanged: root.search = text
            }

            IconTextButton {
                icon: "photo_library"
                text: Tr.tr("Browse")
                isRound: true
                type: IconTextButton.Tonal
                onClicked: browseDialog.open()

                FileDialog {
                    id: browseDialog

                    title: "Choisir une image ou une vidéo"
                    filterLabel: "Images et vidéos"
                    filters: [...Images.validImageExtensions, ...root.videoExtensions]
                    onAccepted: path => WallStudio.applyTo(root.target, path, false)
                }
            }

            IconTextButton {
                icon: "shuffle"
                text: Tr.tr("Random")
                isRound: true
                type: IconTextButton.Tonal
                onClicked: WallStudio.shuffleFor(root.target, WallStudio.filter)
            }
        }

        // Filtres du studio, et écran visé quand il y en a plusieurs
        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: root.filters

                StudioChip {
                    required property var modelData

                    icon: modelData.icon
                    text: modelData.name
                    trailing: String(root.counts[modelData.key] ?? 0)
                    checked: WallStudio.filter === modelData.key
                    onClicked: WallStudio.setFilter(modelData.key)
                }
            }

            Item {
                visible: root.targets.length > 1
                implicitWidth: Tokens.spacing.large
                implicitHeight: 1
            }

            Repeater {
                model: root.targets.length > 1 ? root.targets : []

                StudioChip {
                    required property string modelData

                    icon: WallStudio.targetIcon(modelData)
                    text: WallStudio.targetName(modelData)
                    checked: root.target === modelData
                    onClicked: root.nState.wallTarget = modelData
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: root.target !== ""
            text: `Le fond choisi ne s'applique qu'${WallStudio.toTarget(root.target)} ; les couleurs du thème restent celles du fond commun.`
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            elide: Text.ElideRight
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: root.entries.length > 0 || root.showFeatured

            columns: Config.nexus.wallpapersPerRow
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.large

            Repeater {
                model: root.entries

                WallTile {
                    required property FileSystemEntry modelData

                    path: modelData.path
                    current: root.targetWall === modelData.path
                    onClicked: WallStudio.applyTo(root.target, modelData.path, false)
                }
            }

            WallTile {
                visible: root.showFeatured
                path: root.featured
                label: "Fond de Caelestia"
                current: root.targetWall === root.featured
                onClicked: WallStudio.applyTo(root.target, root.featured, false)
            }

            // Cases vides : les vignettes gardent leur largeur quand la dernière ligne est incomplète.
            Repeater {
                model: Math.max(0, Config.nexus.wallpapersPerRow - root.entries.length - (root.showFeatured ? 1 : 0))

                Item {
                    Layout.fillWidth: true
                }
            }
        }

        // Rien à afficher
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraLarge
            visible: root.entries.length === 0 && !root.showFeatured
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: WallStudio.filter === "favourites" && root.search === "" ? "star" : "hide_image"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.extraLarge
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    if (Wallpapers.list.length === 0)
                        return `Ajoute des images ou des vidéos dans ${Paths.shortenHome(Paths.wallsdir)}`;
                    if (WallStudio.filter === "favourites" && root.search === "")
                        return "Aucun favori : l'étoile d'une vignette en ajoute un";
                    return "Aucun fond trouvé";
                }
                color: Colours.palette.m3outline
                font: Tokens.font.title.small
            }
        }
    }
}
