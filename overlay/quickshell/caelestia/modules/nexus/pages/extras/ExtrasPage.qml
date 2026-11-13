pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services
import qs.modules.nexus.common

// Réglages des ajouts au shell : les valeurs sont celles de ~/.config/caelestia/extras.json
// (service Extras), modifiables ici ou directement dans le fichier.
PageBase {
    id: root

    title: "Extras"

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Vue d'ensemble
        SectionHeader {
            first: true
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
    }
}
