pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Réglages des ajouts au shell : les valeurs sont celles de ~/.config/caelestia/extras.json
// (service Extras), modifiables ici ou directement dans le fichier.
PageBase {
    id: root

    readonly property var widgetNames: ({
            clock: "Horloge",
            weather: "Météo",
            system: "Système",
            media: "Lecteur",
            calendar: "Calendrier",
            timer: "Minuteur"
        })
    readonly property var widgetIcons: ({
            clock: "schedule",
            weather: "partly_cloudy_day",
            system: "monitoring",
            media: "music_note",
            calendar: "calendar_month",
            timer: "timer"
        })

    // Choix d'affichage d'un widget : masqué, tous les écrans, ou un écran.
    function widgetChoice(item: var): string {
        if (!item.enabled)
            return "@hidden";
        return WallStudio.screenNames.includes(item.screen) ? item.screen : "";
    }

    title: "Extras"

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Ouverture de session
        SectionHeader {
            first: true
            text: "Ouverture de session"
        }

        ToggleRow {
            first: true
            last: true
            text: "Verrouiller au démarrage"
            subtext: "Avec une connexion automatique, l'écran de verrouillage sert d'écran de connexion"
            checked: Extras.lock.atStartup
            onToggled: Extras.lock.atStartup = checked
        }

        // Vue d'ensemble
        SectionHeader {
            text: "Vue d'ensemble des espaces de travail (Super+Tab)"
        }

        StepperRow {
            first: true
            label: "Lignes"
            value: Extras.overview.rows
            from: 1
            to: 4
            stepSize: 1
            onMoved: v => Extras.overview.rows = v
        }

        StepperRow {
            label: "Colonnes"
            subtext: `${Extras.overview.rows * Extras.overview.columns} espaces de travail par page`
            value: Extras.overview.columns
            from: 2
            to: 10
            stepSize: 1
            onMoved: v => Extras.overview.columns = v
        }

        ToggleRow {
            text: "Miniatures en direct"
            subtext: "Sinon elles sont rafraîchies une fois par seconde"
            checked: Extras.overview.livePreviews
            onToggled: Extras.overview.livePreviews = checked
        }

        ToggleRow {
            text: "Espaces spéciaux"
            subtext: "Affiche sous la grille les espaces spéciaux occupés"
            checked: Extras.overview.showSpecial
            onToggled: Extras.overview.showSpecial = checked
        }

        SliderRow {
            last: true
            icon: "contrast"
            label: "Assombrissement du bureau"
            valueLabel: `${Math.round(value * 100)} %`
            value: Extras.overview.dim
            onMoved: v => Extras.overview.dim = Math.round(v * 20) / 20
        }

        // Recherche de fichiers
        SectionHeader {
            text: "Recherche de fichiers du launcher (>f)"
        }

        TextFieldRow {
            first: true
            label: "Dossiers parcourus"
            subtext: "Séparés par des virgules ; ~ désigne le dossier personnel"
            value: Extras.files.roots.join(", ")
            placeholderText: "~"
            onEditingFinished: value => {
                const roots = value.split(",").map(r => r.trim()).filter(r => r !== "");
                Extras.files.roots = roots.length > 0 ? roots : ["~"];
            }
        }

        ToggleRow {
            text: "Fichiers cachés"
            subtext: "Inclut les fichiers et dossiers dont le nom commence par un point"
            checked: Extras.files.hidden
            onToggled: Extras.files.hidden = checked
        }

        StepperRow {
            last: true
            label: "Résultats affichés au maximum"
            value: Extras.files.maxResults
            from: 10
            to: 200
            stepSize: 10
            onMoved: v => Extras.files.maxResults = v
        }

        // Recherche web
        SectionHeader {
            text: "Recherche web du launcher (>web)"
        }

        NavRow {
            first: true
            last: true
            icon: "travel_explore"
            text: "Moteurs de recherche"
            subtext: Extras.web.engines.map(e => `>${e.key}`).join("   ")
            onClicked: root.nState.openSubPage(1)
        }

        // Minuteur
        SectionHeader {
            text: "Minuteur (>timer dans le launcher, témoin dans la barre)"
        }

        TextFieldRow {
            first: true
            label: "Durées proposées"
            subtext: "En minutes, séparées par des virgules"
            value: Extras.timer.presets.join(", ")
            placeholderText: "5, 10, 15, 25, 45"
            onEditingFinished: value => {
                const presets = value.split(",").map(v => parseFloat(v.trim().replace(",", "."))).filter(v => v > 0);
                Extras.timer.presets = presets.length > 0 ? presets : [5, 10, 15, 25, 45];
            }
        }

        ToggleRow {
            text: "Son à la fin"
            checked: Extras.timer.sound
            onToggled: Extras.timer.sound = checked
        }

        ToggleRow {
            text: "Témoin toujours visible dans la barre"
            subtext: "Sinon seulement quand un minuteur tourne"
            checked: Extras.timer.alwaysShow
            onToggled: Extras.timer.alwaysShow = checked
        }

        StepperRow {
            label: "Pomodoro : minutes de travail"
            value: Extras.timer.pomodoro.work
            from: 5
            to: 90
            stepSize: 5
            onMoved: v => Extras.timer.pomodoro.work = v
        }

        StepperRow {
            label: "Pomodoro : minutes de pause"
            value: Extras.timer.pomodoro.shortBreak
            from: 1
            to: 30
            stepSize: 1
            onMoved: v => Extras.timer.pomodoro.shortBreak = v
        }

        StepperRow {
            label: "Pomodoro : minutes de grande pause"
            value: Extras.timer.pomodoro.longBreak
            from: 5
            to: 60
            stepSize: 5
            onMoved: v => Extras.timer.pomodoro.longBreak = v
        }

        StepperRow {
            last: true
            label: "Pomodoro : séries avant la grande pause"
            value: Extras.timer.pomodoro.cycles
            from: 2
            to: 8
            stepSize: 1
            onMoved: v => Extras.timer.pomodoro.cycles = v
        }

        // Outils de capture
        SectionHeader {
            text: "Outils de capture (texte, QR code, pipette, GIF)"
        }

        TextFieldRow {
            first: true
            label: "Langues de la reconnaissance de texte"
            subtext: "Par exemple fra+eng ; vide : toutes celles installées pour tesseract"
            value: Extras.capture.ocrLanguages
            placeholderText: "fra+eng"
            smallField: true
            onEditingFinished: value => Extras.capture.ocrLanguages = value.trim()
        }

        StepperRow {
            label: "GIF : images par seconde"
            value: Extras.capture.gifFps
            from: 5
            to: 30
            stepSize: 5
            onMoved: v => Extras.capture.gifFps = v
        }

        StepperRow {
            label: "GIF : largeur maximale"
            subtext: "En pixels ; une zone plus large est réduite"
            value: Extras.capture.gifWidth
            from: 240
            to: 1920
            stepSize: 120
            onMoved: v => Extras.capture.gifWidth = v
        }

        StepperRow {
            label: "GIF : durée maximale"
            subtext: "En secondes ; l'enregistrement s'arrête seul"
            value: Extras.capture.gifMaxSeconds
            from: 5
            to: 300
            stepSize: 5
            onMoved: v => Extras.capture.gifMaxSeconds = v
        }

        TextFieldRow {
            last: true
            label: "Dossier des GIF et des QR codes"
            subtext: "Vide : le dossier Captures de tes images"
            value: Extras.capture.directory
            placeholderText: "~/Images/Captures"
            onEditingFinished: value => Extras.capture.directory = value.trim()
        }

        // Widgets de bureau
        SectionHeader {
            text: "Widgets de bureau"
        }

        ToggleRow {
            first: true
            text: "Afficher les widgets"
            subtext: "Posés sur le fond d'écran, sous les fenêtres"
            checked: Extras.widgets.enabled
            onToggled: Extras.widgets.enabled = checked
        }

        RowButton {
            icon: "open_with"
            text: Extras.editingWidgets ? "Terminer le déplacement" : "Déplacer les widgets à la souris"
            subtext: Extras.editingWidgets ? "Glisse chaque widget sur le bureau, sa croix le masque" : "Chaque widget devient déplaçable sur le bureau"
            disabled: !Extras.widgets.enabled
            onClicked: Extras.editingWidgets = !Extras.editingWidgets
        }

        SliderRow {
            icon: "format_size"
            label: "Taille"
            valueLabel: `${Math.round(Extras.widgets.scale * 100)} %`
            value: (Extras.widgets.scale - 0.5) / 1.5
            onMoved: v => Extras.widgets.scale = Math.round((0.5 + v * 1.5) * 20) / 20
        }

        SliderRow {
            icon: "opacity"
            label: "Opacité du fond"
            valueLabel: `${Math.round(value * 100)} %`
            value: Extras.widgets.opacity
            onMoved: v => Extras.widgets.opacity = Math.round(v * 20) / 20
        }

        // Un widget par ligne : masqué, sur tous les écrans, ou sur un seul.
        Variants {
            id: widgetChoices

            model: [
                {
                    value: "@hidden",
                    text: "Masqué",
                    icon: "visibility_off"
                },
                {
                    value: "",
                    text: "Tous les écrans",
                    icon: "select_all"
                },
                ...WallStudio.screenNames.map(s => ({
                            value: s,
                            text: s,
                            icon: "desktop_windows"
                        }))
            ]

            MenuItem {
                required property var modelData

                text: modelData.text
                icon: modelData.icon
                value: modelData.value
            }
        }

        Repeater {
            model: Extras.widgets.items

            SelectRow {
                id: widgetRow

                required property var modelData
                required property int index

                last: index === Extras.widgets.items.length - 1
                menuOnTop: true
                label: root.widgetNames[modelData.type] ?? modelData.type
                menuItems: widgetChoices.instances
                active: widgetChoices.instances.find(i => i.value === root.widgetChoice(widgetRow.modelData)) ?? null
                onSelected: item => Extras.setWidget(widgetRow.index, item.value === "@hidden" ? {
                    enabled: false
                } : {
                    enabled: true,
                    screen: item.value
                })
            }
        }
    }
}
