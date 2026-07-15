#!/usr/bin/env bash
set -Eeuo pipefail

if (( EUID != 0 )); then
    exec sudo -- "$0" "$@"
fi

state_root=/var/lib/caelestia-portable/backups
backup="${1:-}"
if [[ -z "$backup" ]]; then
    backup="$(find "$state_root" -mindepth 1 -maxdepth 1 -type d -printf '%p\n' 2>/dev/null | sort | tail -1)"
fi
if [[ -z "$backup" || ! -d "$backup" ]]; then
    printf 'Sauvegarde système introuvable.\n' >&2
    exit 1
fi

restore_path() {
    local path="$1" source="$backup/root$1"
    case "$path" in /etc/*|/boot/*|/efi/*) ;; *) printf 'Chemin système refusé: %s\n' "$path" >&2; exit 1 ;; esac
    rm -rf -- "$path"
    install -d -m 0755 "$(dirname -- "$path")"
    cp -a -- "$source" "$path"
    printf 'restauré: %s\n' "$path"
}

while IFS= read -r path; do
    [[ -n "$path" ]] && restore_path "$path"
done < "$backup/original.list"

while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    case "$path" in /etc/*|/boot/*|/efi/*) rm -rf -- "$path" ;; *) printf 'Chemin système refusé: %s\n' "$path" >&2; exit 1 ;; esac
    printf 'supprimé (absent avant installation): %s\n' "$path"
done < "$backup/missing.list"

if command -v grub-mkconfig >/dev/null 2>&1 && [[ -d /boot/grub ]]; then
    grub-mkconfig -o /boot/grub/grub.cfg
fi
if command -v mkinitcpio >/dev/null 2>&1; then
    mkinitcpio -P
fi
systemctl daemon-reload
printf 'Restauration système terminée depuis %s. Redémarrer la machine.\n' "$backup"
