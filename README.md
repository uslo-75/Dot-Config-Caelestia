# Dot-Config-Caelestia

Overlay portable de la configuration Caelestia/Hyprland de `uslo-75` pour Arch Linux.

Il installe les personnalisations utiles sans recopier la configuration matérielle des écrans : raccourcis AZERTY, vue d'ensemble des espaces de travail, studio de fonds d'écran et historique du presse-papiers intégrés au shell, thèmes dynamiques mémorisés par fond, icône Proton Mail dans la barre, services de maintenance et images de profil.

## Studio de fonds d'écran (`Super+Alt+W`)

- Images et vidéos lues nativement par Caelestia (branche `main`, paquet `caelestia-shell-git`), avec ses transitions shader : une transition fixe ou « Aléatoire » (16 effets doux tirés à chaque changement). Le sélecteur (`Ctrl+T`) montre chaque effet en miniature et l'anime au survol.
- Carrousel 3D à élan (une flèche maintenue fait défiler en continu), mini-clip sur la carte sélectionnée ou survolée et aperçu en direct sur le bureau (fond, transition et couleurs) pendant la navigation.
- Filtres Tous / Images / Animés / Favoris (`Tab`), favoris (`Ctrl+D`), carte au hasard (`Ctrl+R`), lecture/pause (`Ctrl+P`), diaporama (5 min à 1 h), qualité vidéo.
- Couleurs mémorisées par fond (`Ctrl+M`) : mode et variante, avec les pastilles réelles de chaque variante pour ce fond, appliqués en une seule passe (`caelestia-wallpaper-apply`).
- `caelestia-wallpaper-cache` prépare en arrière-plan des copies à la hauteur de l'écran (4K → 1080p, 3 à 4× moins de CPU), des planches d'aperçu (6 s de vidéo dans une seule texture compressée, animée par un shader) et les métadonnées (`~/.cache/caelestia/wallpaper-video/index.json`).
- **Un fond par écran ou par espace de travail** : le menu des cibles (`Ctrl+E`) vise « Tous les écrans », un écran, ou l'espace de travail affiché (son fond passe avant celui de l'écran tant qu'il est à l'écran ; commande `caelestia shell wallstudio setForWorkspace 3 /chemin`). Un écran visé seul garde son propre fond, les autres affichent le fond commun ; les couleurs du thème restent celles du fond commun. « Reprendre le fond commun » retire le fond propre, et appliquer à tous les écrans les retire tous. Le même choix existe dans les réglages du shell (page « Wallpaper & style », une vignette par écran détecté ; chaque fenêtre a sa propre cible) et en commande : `caelestia shell wallstudio setFor DP-1 /chemin/du/fond` (chemin vide : fond commun), `caelestia shell wallstudio screens` pour la liste. Le diaporama et `caelestia shell wallpaper set` ne changent que le fond commun.
- La vidéo se met en pause, lecteur déchargé, quand une fenêtre en vrai plein écran ou le mode jeu couvre l'écran (pas pour une fenêtre seulement agrandie, qui laisse voir le fond).
- Hyprland 0.57 laisse invisible une couche de fond créée pendant qu'une fenêtre est en plein écran sur son écran (shell redémarré pendant une vidéo ou un jeu) : le fond de cet écran est re-créé dès que le plein écran se termine (`modules/background/Background.qml`).
- Fluidité : créer ou détruire un lecteur vidéo bloque l'interface (~80 ms avec le décodeur NVIDIA). Les mini-clips n'en utilisent donc aucun, les aperçus du bureau passent par une image fixe superposée au fond en cours, et le lecteur du fond ne change qu'une fois le studio refermé. Les animations du shell suivent la fréquence de chaque écran (`QSG_USE_SIMPLE_ANIMATION_DRIVER` dans `shell.qml`, à retirer pour revenir à l'horloge de Qt).

## Fonds et couleurs dans les réglages du shell

Les pages « Wallpaper & style » des réglages (Nexus) reprennent le studio :

- **Page principale** : aperçu du fond de l'écran visé, une vignette par écran, et une section « Fonds animés et transitions » (lecture/pause, qualité des vidéos, transition, diaporama).
- **Wallpapers** (`modules/nexus/pages/extras/WallpapersPage.qml`, à la place de la page d'origine qui ne montrait que les images du dossier) : galerie de tous les fonds, images et animés, sous-dossiers compris, avec les filtres et favoris du studio, une recherche, le fond actuel repéré, et un mini-clip au survol des fonds animés (sans lecteur vidéo). Un clic applique à l'écran visé.
- **Colours** (`ColoursPage.qml`, la page d'origine est encore vide) : palette en cours, choix du thème (dynamique d'après le fond, ou l'un des thèmes de `caelestia scheme`), mode et variante du thème dynamique avec les vraies pastilles de chaque variante pour le fond, transparence et opacités.
- Les couleurs sont les mêmes sur tous les écrans (une seule palette pour le shell, les applis et le terminal). « Prendre les couleurs du fond de <écran> » tire le thème du fond d'un écran : ce fond devient le fond commun, chaque écran garde ce qu'il affiche.

## Verrouillage à l'ouverture de session

Avec la connexion automatique, l'écran de verrouillage de Caelestia peut servir d'écran de connexion : option « Verrouiller au démarrage » de la page « Extras » des réglages (`lock.atStartup`, désactivée par défaut). Le shell verrouille dès son premier démarrage dans une session Hyprland, et pas quand il redémarre ensuite (témoin dans `$XDG_RUNTIME_DIR`). Ce n'est pas une barrière de sécurité : la session est déjà ouverte, le bureau reste visible un instant, et rien ne verrouille si le shell ne démarre pas. `caelestia shell startupLock status` dit ce qui a été décidé.

## Minuteur (`Super+Alt+T`)

- Dans le launcher : `>timer 10`, `>timer 25min`, `>timer 1h30 pâtes`, `>timer 1:30` ; sans durée, les durées prédéfinies et le pomodoro. Avec un minuteur en cours : pause, reprise, arrêt.
- Témoin dans la barre (anneau qui se vide, minutes restantes) avec, au survol, les commandes : pause, +1 min, +5 min, arrêt.
- Pomodoro : travail, pause, grande pause après quelques séries (durées réglables). Notification et son à la fin de chaque phase.
- Le minuteur survit à un redémarrage du shell. Commandes : `caelestia shell timer start 10m`, `pomodoro`, `toggle`, `add 5`, `stop`, `status`.

## Mises à jour

- Vérification périodique des paquets des dépôts (`checkupdates`, de `pacman-contrib`), de l'AUR (`yay` ou `paru`) et de Flatpak. Rien n'est installé par le shell : « Tout mettre à jour » ouvre un terminal avec la commande habituelle (`yay -Syu` par défaut).
- Témoin dans la barre avec le nombre de paquets ; au survol, le résumé et les premiers paquets.
- Page « Updates » des réglages (vide en amont) : liste complète par source, vérification, réglages.
- Quand le paquet du shell a été mis à jour, la copie modifiée (`~/.config/quickshell/caelestia`) le masque : la page le signale et propose de la reconstruire avec `install.sh`.
- Commandes : `caelestia shell updates check`, `status`, `list`, `upgrade`, `open`.

## Outils de capture

Dans le launcher (actions « Texte d'une zone », « Lire un QR code », « Créer un QR code », « Pipette », « GIF d'une zone »), par raccourci, ou avec `caelestia shell capture ocr|qr|qrMake|colour|gif`. Le travail est fait par `~/.local/bin/caelestia-capture`, utilisable seul (`--region "x,y LxH"`, `--stdout`).

- **Texte d'une zone** (`Super+Maj+T`) : reconnaissance de caractères avec `tesseract`, texte copié. Langues : toutes celles installées (`tesseract-data-fra`, `tesseract-data-eng`…), ou celles choisies dans les réglages.
- **QR code** : lecture d'une zone (`zbar`) ou création depuis le texte copié (`qrencode`, image copiée et enregistrée).
- **Pipette** (`Super+Maj+C`) : `hyprpicker`, couleur copiée, annoncée et gardée dans un historique.
- **GIF d'une zone** (`Super+Maj+G`) : enregistrement (`wf-recorder`) puis conversion (`ffmpeg`) ; le même raccourci, ou le témoin rouge de la barre, l'arrête. Fichier dans `Images/Captures`, copié pour être collé.
- Un outil absent est signalé par une notification qui dit quoi installer.

## Widgets de bureau

- Horloge, météo, système (processeur, carte graphique, mémoire, disque), lecteur, calendrier et minuteur, posés sur le fond d'écran, dans la fenêtre du fond (aucune surface de plus).
- Désactivés par défaut. Dans la page « Extras » des réglages : interrupteur général, taille, opacité, et pour chaque widget « masqué », « tous les écrans » ou un écran.
- « Déplacer les widgets » : chacun se glisse à la souris sur le bureau, sa croix le masque (`caelestia shell widgets edit`).

## Vue d'ensemble des espaces de travail (`Super+Tab`)

- Grille de tous les espaces de travail (2 × 5 par défaut) avec les fenêtres en miniature, mises à jour en direct et placées comme sur l'écran ; les espaces spéciaux occupés sont listés dessous.
- Clic sur une fenêtre pour y aller, clic dans le vide pour aller à l'espace, glisser une miniature vers une autre case pour déplacer la fenêtre (même vers un autre écran), clic molette pour la fermer.
- Au clavier : taper pour chercher une fenêtre (titre, classe ou nom de l'appli), `Tab` pour passer de fenêtre en fenêtre, flèches pour choisir un espace, `Entrée` pour y aller, `Échap` pour fermer.
- Module autonome (`modules/extras/overview/`), ouvert sur l'écran actif, y compris par-dessus une fenêtre en plein écran. Commande : `caelestia shell overview toggle`.

## Modes ajoutés au launcher

Ils se tapent après le préfixe d'action (`>`), apparaissent dans la liste des actions et vivent dans `modules/launcher/modes/`.

- **Emoji et symboles** (`Super+;`, `>emoji` ou `>e`) : grille des emoji et des glyphes Nerd Font fournis par `caelestia emoji`, recherche par mots-clés (en anglais), derniers utilisés en tête. `Entrée` colle dans la fenêtre active, `Maj+Entrée` copie seulement.
- **Fichiers** (`>files` ou `>f`) : recherche par nom dans le dossier personnel avec `ripgrep` (repli sur `find`). `Entrée` ouvre, `Maj+Entrée` ouvre le dossier, `Ctrl+Entrée` copie le chemin.
- **Web** (`>web`, ou directement `>g`, `>yt`, `>gh`, `>w`, `>aw`, `>aur`) : ouvre la recherche dans le navigateur par défaut.

## Réglages des ajouts (`~/.config/caelestia/extras.json`)

Modifiables dans les réglages du shell, page « Extras » (`modules/nexus/pages/extras/`), ou directement dans le fichier : il est créé avec les valeurs par défaut au premier lancement, complété quand une version ajoute une section, et relu à chaud.

- `overview` : `rows` et `columns` (taille de la grille), `livePreviews` (miniatures en continu, sinon une capture par seconde), `showSpecial` (espaces spéciaux), `dim` (assombrissement du bureau, de 0 à 1).
- `files` : `roots` (dossiers parcourus, `~` par défaut), `hidden` (fichiers cachés), `maxResults`.
- `lock` : `atStartup` (verrouiller à l'ouverture de session).
- `timer` : `presets` (durées proposées, en minutes), `sound`, `alwaysShow` (témoin toujours dans la barre), `pomodoro` (`work`, `shortBreak`, `longBreak`, `cycles`).
- `updates` : `enabled`, `interval` (minutes), `aur`, `flatpak`, `showInBar`, `notify`, `command`.
- `capture` : `ocrLanguages`, `gifFps`, `gifWidth`, `gifMaxSeconds`, `directory`.
- `widgets` : `enabled`, `scale`, `opacity`, `items` (un objet par widget : `type`, `enabled`, `screen`, `x`, `y` de 0 à 1).
- `web` : `engines`, la liste des moteurs (`key` tapée après `>`, `name`, `icon`, `url` où `%s` est la recherche). La page « Extras » permet d'en ajouter, d'en retirer et de changer leur adresse.

Les fonds propres à chaque écran sont un état, pas un réglage : ils sont gardés avec les favoris du studio dans `~/.local/state/caelestia/wallstudio.json` (`screens`).

## Notifications

L'icône d'une appli envoyée comme fichier (chemin ou adresse `file://`, ce que fait Claude) s'affiche dans la bulle, le panneau latéral et l'écran de verrouillage ; une icône inconnue du thème donne l'icône générique au lieu du damier rose et noir « icône introuvable ».

## Presse-papiers (`Super+V`)

Historique `cliphist` dans le launcher : groupé par jour avec l'heure et l'appli d'origine, aperçu texte/code, images, liens et couleurs, recherche, épingles (`Ctrl+P`), suppression (`Suppr`), pause de l'historique (`Ctrl+S`). `Entrée` colle directement dans l'appli active (`Ctrl+Maj+V` dans les terminaux), `Maj+Entrée` copie seulement. Les contenus marqués sensibles par les gestionnaires de mots de passe ne sont pas enregistrés.

## Installation rapide

Prérequis : Arch Linux, une session Caelestia fonctionnelle et un compte utilisateur normal disposant de `sudo`.

```bash
git clone https://github.com/uslo-75/Dot-Config-Caelestia.git
cd Dot-Config-Caelestia
./install.sh --dry-run
./install.sh
```

Par défaut, l'installeur :

- installe les dépendances manquantes avec `pacman` et `yay` ;
- sauvegarde chaque élément remplacé sous `~/.local/state/caelestia-portable/backups/` ;
- applique l'overlay Caelestia/Hyprland et les correctifs QML ;
- conserve les réglages et états existants de Caelestia (favoris, couleurs par fond, épingles) et migre une ancienne installation Waypaper/mpvpaper/Clipse (sauvegardée) ;
- installe les dix images de profil dans `~/Images/Profils` ;
- conserve la photo existante ou utilise `Sylvie.png` si `~/.face` est absent ;
- télécharge et vérifie l'archive `wallpapers-v1` depuis GitHub Releases ;
- active les services systemd utilisateur.
- détecte GRUB/rEFInd, NVIDIA et configure l'autologin SDDM vers Hyprland.

Options utiles :

```text
--dry-run        Afficher les opérations sans rien modifier
--no-packages    Ne pas installer les paquets manquants
--no-wallpapers  Ne pas télécharger les 1,7 Go de fonds d'écran
--no-system      Ne modifier ni bootloader, ni NVIDIA, ni SDDM
--no-bootloader  Ne pas installer le thème GRUB/rEFInd
--no-nvidia      Ne pas installer/vérifier le pilote NVIDIA
--no-autologin   Ne pas configurer la connexion automatique
--skip-reload    Ne pas recharger Hyprland/Caelestia à la fin
```

Pour automatiser l'installation avec un autre Codex, voir [CODEX_SETUP.md](CODEX_SETUP.md). Pour revenir en arrière :

```bash
./restore.sh
```

Validation locale complète :

```bash
./scripts/validate.sh
```

## Raccourcis personnalisés

| Raccourci | Action |
| --- | --- |
| `Super` + rangée AZERTY | Aller aux workspaces 1 à 10 |
| `Super+Alt` + rangée AZERTY | Déplacer la fenêtre vers le workspace |
| `Super+T` | Kitty |
| `Super+W` | Zen Browser |
| `Super+V` / `Super+Alt+V` | Ouvrir/fermer l'historique du presse-papiers |
| `Ctrl+Maj+Alt+V` | Coller le dernier élément copié |
| `Super+Alt+W` / `X` / `C` | Ouvrir/fermer le studio de fonds d'écran |
| `Super+Tab` | Ouvrir/fermer la vue d'ensemble des espaces de travail |
| `Super+;` | Ouvrir/fermer le sélecteur d'emoji et de symboles |
| `Super+Alt+T` | Minuteur (dans le launcher) |
| `Super+Maj+T` | Copier le texte d'une zone de l'écran |
| `Super+Maj+G` | Enregistrer une zone en GIF (et l'arrêter) |
| `Super+Maj+C` | Pipette |

## Compatibilité et sécurité

Les correctifs QML (`patches/caelestia-shell-main.patch` + fichiers ajoutés dans `overlay/`) sont basés sur Caelestia Shell `main` (commit `f80a980`, paquets `caelestia-shell-git` et `caelestia-cli-git`) et Quickshell 0.3.2. Ils sont testés avant application ; une version incompatible provoque un arrêt sans écraser les fichiers QML.

Le dépôt exclut volontairement les configurations `monitor`, caches, logs, historiques du presse-papiers, fichiers d'état contenant des chemins absolus et sauvegardes locales. Les règles d'écran de chaque machine vivent dans `~/.config/caelestia/hypr-monitors.lua`, chargé par `hypr-user.lua` s'il existe : lors d'une réinstallation, l'installeur y déplace les `hl.monitor` présents dans l'ancien `hypr-user.lua` avant de le remplacer.

## Boot, NVIDIA et connexion automatique

La machine source utilise en réalité **rEFInd** avec `refind-gruvbox-theme`, et non GRUB. Le dépôt contient donc le thème rEFInd exact ainsi qu'une adaptation Gruvbox pour GRUB. L'installeur détecte le bootloader présent, sauvegarde sa configuration et ne remplace jamais le bootloader lui-même.

Sur une machine NVIDIA, l'installation choisit le module `nvidia-open` approprié au noyau Arch pour une carte Turing ou plus récente, installe les outils Vulkan/VA-API et ajoute uniquement les paramètres Wayland valides. Après redémarrage :

```bash
~/.local/bin/caelestia-nvidia-report --strict
```

L'autologin écrit uniquement `User=<utilisateur>` et `Session=hyprland` dans SDDM. Aucun mot de passe n'est lu ou stocké. Le mot de passe du compte reste actif pour le verrouillage Caelestia, `sudo` et les connexions distantes. Cette option réduit la sécurité physique : toute personne qui démarre le PC accède directement à la session.

Les licences et attributions des composants tiers sont détaillées dans [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
