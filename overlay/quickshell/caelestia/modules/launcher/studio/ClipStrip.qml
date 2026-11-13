pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.services

// Mini-clip sans lecteur vidéo : une planche d'images (grille préparée par
// caelestia-wallpaper-cache, en texture compressée) dont un shader affiche deux cases
// voisines en fondu.
// Créer ou détruire un lecteur vidéo bloque l'interface ~80 ms à chaque fois ; ici il n'y a
// qu'une image chargée en arrière-plan et une texture.
Item {
    id: root

    property string source // chemin de la planche
    property int columns: 10
    property int frames: 1
    property real fps: 15
    property bool playing: true
    readonly property bool ready: sheet.status === Image.Ready && frames > 0

    // Image courante ; la partie décimale est le fondu vers la suivante.
    property real position
    readonly property int count: Math.max(1, frames)
    readonly property int rows: Math.ceil(count / columns)
    readonly property int frameA: Math.floor(position) % count
    readonly property int frameB: (frameA + 1) % count

    opacity: ready ? 1 : 0

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    // Cadencé par un Timer plutôt que par une animation : avec l'horloge d'animation au rythme
    // des écrans (voir shell.qml), une animation sans fin ferait redessiner toutes les fenêtres
    // du shell tant que le studio est ouvert.
    Timer {
        property real started

        interval: 16
        repeat: true
        running: root.playing && root.ready && root.count > 1
        onRunningChanged: {
            if (running)
                started = Date.now() - root.position / root.fps * 1000;
        }
        onTriggered: root.position = ((Date.now() - started) / 1000 * root.fps) % root.count
    }

    Image {
        id: sheet

        visible: false
        source: WallStudio.fileUrl(root.source)
        asynchronous: true
        cache: false // À libérer dès que la carte n'est plus sélectionnée.
    }

    ShaderEffect {
        readonly property Item source: sheet
        readonly property vector2d grid: Qt.vector2d(root.columns, root.rows)
        readonly property vector2d cellA: Qt.vector2d(root.frameA % root.columns, Math.floor(root.frameA / root.columns))
        readonly property vector2d cellB: Qt.vector2d(root.frameB % root.columns, Math.floor(root.frameB / root.columns))
        readonly property vector2d texel: Qt.vector2d(1 / Math.max(1, sheet.implicitWidth), 1 / Math.max(1, sheet.implicitHeight))
        readonly property real blend: root.position - Math.floor(root.position)

        anchors.fill: parent
        visible: root.ready
        fragmentShader: Qt.resolvedUrl(`${Quickshell.shellDir}/assets/shaders/strip.frag.qsb`)
    }
}
