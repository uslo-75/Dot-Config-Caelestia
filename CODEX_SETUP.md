# Instructions pour un autre Codex

Objectif : reproduire cet environnement sur un PC Arch disposant déjà de Caelestia, sans modifier sa configuration d'écran.

## Procédure obligatoire

1. Vérifier que l'utilisateur est dans une session normale, pas dans un shell root, et que `caelestia-shell`, `caelestia-cli`, `hyprland` et Quickshell sont installés.
2. Cloner ce dépôt dans un dossier de travail propre. Pour un dépôt privé, authentifier d'abord `gh` avec `gh auth login`.
3. Exécuter `./install.sh --dry-run` et lire entièrement le résumé. Ne jamais ajouter manuellement `monitors.conf`, `workspaces.conf` ou `~/.config/caelestia/monitors`.
4. Exécuter `./scripts/validate.sh`, puis `./install.sh`. Autoriser `sudo pacman` et `yay` uniquement pour les paquets explicitement listés dans `manifest/packages-*.txt`.
5. Si le patch QML est refusé, ne pas utiliser `patch --force` et ne pas remplacer tout Caelestia. Comparer la version installée avec `patches/caelestia-shell-2.1.0.patch`, porter les mêmes comportements sur la nouvelle version, puis relancer les validations.
6. Vérifier les commandes de la section suivante avant de déclarer l'installation terminée.
7. Ne jamais demander, journaliser ou écrire le mot de passe du compte. SDDM n'en a pas besoin pour l'autologin.

## Vérifications attendues

```bash
systemctl --user is-enabled \
  caelestia-cache-maintain.timer \
  caelestia-wallpaper-thumbs-watch.service \
  mpvpaper-guard.service \
  clipse-maintain.timer \
  clipse-theme-watch.service

~/.local/bin/cg-open --status
test -d ~/Images/wallpapers
test -d ~/Images/Profils
hyprctl binds | rg 'SUPER.*(V|T|W)'
~/.local/bin/caelestia-nvidia-report --strict
sudo rg -n 'User=uslo|Session=hyprland' /etc/sddm.conf.d/99-caelestia-autologin.conf
```

Valider ensuite manuellement :

- `Super+V` ouvre Clipse GUI et le referme au second appui ;
- `Super+Alt+V` conserve le presse-papiers Caelestia ;
- `Super+Alt+X` ouvre Waypaper ;
- une image et une vidéo peuvent être sélectionnées sans écran noir ;
- la miniature vidéo et le thème dynamique suivent le fond choisi ;
- les workspaces AZERTY fonctionnent ;
- la disposition, la fréquence et l'échelle des écrans n'ont pas changé.
- le prochain redémarrage ouvre directement la session Hyprland de `uslo` et le verrou Caelestia demande toujours le mot de passe ;
- le thème Gruvbox apparaît dans GRUB ou rEFInd selon le bootloader réellement détecté.

## Restauration

En cas d'échec, exécuter `./restore.sh`. Sans argument, il choisit la sauvegarde la plus récente. Il est aussi possible de fournir explicitement le dossier affiché par l'installeur :

```bash
./restore.sh ~/.local/state/caelestia-portable/backups/AAAAmmjj-HHMMSS
```

Ne jamais recopier les caches, l'historique Clipse ou les anciens fichiers `*.bak*` depuis la machine source.
