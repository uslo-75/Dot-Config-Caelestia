#!/usr/bin/env bash
set -Eeuo pipefail

STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia-portable"
backup="${1:-}"
if [[ -z "$backup" ]]; then
    backup="$(find "$STATE_ROOT/backups" -mindepth 1 -maxdepth 1 -type d -printf '%p\n' 2>/dev/null | sort | tail -1)"
fi
if [[ -z "$backup" || ! -d "$backup" ]]; then
    printf 'Sauvegarde utilisateur introuvable.\n' >&2
    exit 1
fi

units=(
    caelestia-cache-maintain.timer
    caelestia-wallpaper-thumbs-watch.service
    mpvpaper-guard.service
    clipse-maintain.timer
    clipse-theme-watch.service
)
systemctl --user disable --now "${units[@]}" >/dev/null 2>&1 || true

validate_path() {
    case "$1" in
        "$HOME"/*) ;;
        *) printf 'Chemin hors HOME refusé: %s\n' "$1" >&2; exit 1 ;;
    esac
}

while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    validate_path "$path"
    source="$backup/root$path"
    rm -rf -- "$path"
    install -d -m 0755 "$(dirname -- "$path")"
    cp -a -- "$source" "$path"
    printf 'restauré: %s\n' "$path"
done < "$backup/original.list"

while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    validate_path "$path"
    rm -rf -- "$path"
    printf 'supprimé (absent avant installation): %s\n' "$path"
done < "$backup/missing.list"

systemctl --user daemon-reload >/dev/null 2>&1 || true
if [[ -s "$backup/services-enabled.list" ]]; then
    mapfile -t enabled < "$backup/services-enabled.list"
    systemctl --user enable --now "${enabled[@]}" >/dev/null 2>&1 || true
fi
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload >/dev/null 2>&1 || true
fi

printf 'Restauration utilisateur terminée depuis %s.\n' "$backup"
printf 'Pour restaurer aussi le système: ./scripts/restore-system.sh\n'
