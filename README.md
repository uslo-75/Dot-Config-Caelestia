# Dot-Config-Caelestia

Overlay portable de la configuration Caelestia/Hyprland de `uslo-75` pour Arch Linux.

Il installe les personnalisations utiles sans recopier la configuration matérielle des écrans : raccourcis AZERTY, intégration Clipse pour `Super+V`, gestion des fonds d'écran statiques et animés avec Waypaper/mpvpaper, thèmes dynamiques, services de maintenance et images de profil.

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
| `Super+V` | Ouvrir/fermer Clipse GUI |
| `Super+Alt+V` | Presse-papiers Caelestia d'origine |
| `Super+Alt+W` | Menu de fonds d'écran |
| `Super+Alt+X` | Interface Waypaper |
| `Super+Alt+C` | Mode/variante du thème courant |

## Compatibilité et sécurité

Les correctifs QML sont basés sur Caelestia Shell 2.1.0 (révision `90a1b466`) et Quickshell 0.3.0. Ils sont testés avant application ; une version incompatible provoque un arrêt sans écraser les fichiers QML.

Le dépôt exclut volontairement les configurations `monitor`, caches, logs, historiques du presse-papiers, fichiers d'état contenant des chemins absolus et sauvegardes locales.

## Boot, NVIDIA et connexion automatique

La machine source utilise en réalité **rEFInd** avec `refind-gruvbox-theme`, et non GRUB. Le dépôt contient donc le thème rEFInd exact ainsi qu'une adaptation Gruvbox pour GRUB. L'installeur détecte le bootloader présent, sauvegarde sa configuration et ne remplace jamais le bootloader lui-même.

Sur une machine NVIDIA, l'installation choisit le module `nvidia-open` approprié au noyau Arch pour une carte Turing ou plus récente, installe les outils Vulkan/VA-API et ajoute uniquement les paramètres Wayland valides. Après redémarrage :

```bash
~/.local/bin/caelestia-nvidia-report --strict
```

L'autologin écrit uniquement `User=<utilisateur>` et `Session=hyprland` dans SDDM. Aucun mot de passe n'est lu ou stocké. Le mot de passe du compte reste actif pour le verrouillage Caelestia, `sudo` et les connexions distantes. Cette option réduit la sécurité physique : toute personne qui démarre le PC accède directement à la session.

Les licences et attributions des composants tiers sont détaillées dans [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
