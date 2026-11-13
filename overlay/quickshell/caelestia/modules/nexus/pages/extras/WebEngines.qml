pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

// Moteurs du mode « web » du launcher : > suivi de la clé, puis la recherche (« >yt lofi »).
PageBase {
    id: root

    property string newKey
    property string newName
    property string newUrl
    readonly property bool canAdd: /^[a-z0-9]{1,12}$/.test(newKey) && newName.trim() !== "" && /^https?:\/\/.*%s/.test(newUrl) && !Extras.web.engines.some(e => e.key === newKey)

    function engines(): var {
        return Extras.web.engines.map(e => Object.assign({}, e));
    }

    function setUrl(index: int, url: string): void {
        const list = engines();
        if (!list[index] || list[index].url === url || !/^https?:\/\/.*%s/.test(url))
            return;
        list[index].url = url;
        Extras.web.engines = list;
    }

    function remove(index: int): void {
        const list = engines();
        list.splice(index, 1);
        Extras.web.engines = list;
    }

    function add(): void {
        if (!canAdd)
            return;
        Extras.web.engines = [...engines(), {
                key: newKey,
                name: newName.trim(),
                icon: "search",
                url: newUrl.trim()
            }];
        keyRow.clear();
        nameRow.clear();
        urlRow.clear();
        newKey = newName = newUrl = "";
    }

    title: "Moteurs de recherche"
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.medium
            text: "Dans le launcher, tape > suivi de la clé puis ta recherche, par exemple « >yt lofi ». Dans l'adresse, %s est remplacé par la recherche."
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: Extras.web.engines

            ColumnLayout {
                id: engine

                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.bottomMargin: Tokens.spacing.small
                spacing: Tokens.spacing.extraSmall / 2

                TextFieldRow {
                    first: true
                    label: engine.modelData.name
                    subtext: `>${engine.modelData.key}`
                    errorText: "L'adresse doit commencer par http(s):// et contenir %s"
                    value: engine.modelData.url
                    validate: /^https?:\/\/.*%s/
                    onEditingFinished: value => root.setUrl(engine.index, value.trim())
                }

                RowButton {
                    last: true
                    icon: "delete"
                    text: `Retirer ${engine.modelData.name}`
                    onClicked: root.remove(engine.index)
                }
            }
        }

        SectionHeader {
            text: "Ajouter un moteur"
        }

        TextFieldRow {
            id: keyRow

            first: true
            label: "Clé"
            subtext: "Le mot tapé après > (lettres minuscules et chiffres)"
            errorText: "Lettres minuscules et chiffres, 12 au plus"
            placeholderText: "ddg"
            maximumLength: 12
            smallField: true
            validate: /^[a-z0-9]{1,12}$/
            onValueEdited: value => root.newKey = value
        }

        TextFieldRow {
            id: nameRow

            label: "Nom"
            placeholderText: "DuckDuckGo"
            onValueEdited: value => root.newName = value
        }

        TextFieldRow {
            id: urlRow

            label: "Adresse"
            subtext: "%s est remplacé par la recherche"
            errorText: "L'adresse doit commencer par http(s):// et contenir %s"
            placeholderText: "https://duckduckgo.com/?q=%s"
            validate: /^https?:\/\/.*%s/
            onValueEdited: value => root.newUrl = value
        }

        RowButton {
            last: true
            icon: "add"
            text: "Ajouter ce moteur"
            subtext: Extras.web.engines.some(e => e.key === root.newKey) ? "Cette clé est déjà utilisée" : ""
            disabled: !root.canAdd
            onClicked: root.add()
        }
    }
}
