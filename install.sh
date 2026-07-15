#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
INSTALL_PACKAGES=1
INSTALL_WALLPAPERS=1
INSTALL_SYSTEM=1
INSTALL_SERVICES=1
RELOAD_SESSION=1
SYSTEM_ARGS=()
TARGET_USER="$(id -un)"
RELEASE_REPO="${CAELESTIA_RELEASE_REPO:-uslo-75/Dot-Config-Caelestia}"
RELEASE_TAG="${CAELESTIA_RELEASE_TAG:-wallpapers-v1}"
WALLPAPER_ASSET="caelestia-wallpapers-v1.tar.zst"

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

  --dry-run         Afficher les opérations sans rien modifier
  --no-packages     Ne pas installer les dépendances manquantes
  --no-wallpapers   Ne pas télécharger l'archive de fonds d'écran
  --no-system       Ne modifier ni bootloader, ni NVIDIA, ni SDDM
  --no-bootloader   Transmis à l'installation système
  --no-nvidia       Transmis à l'installation système
  --no-autologin    Transmis à l'installation système
  --bootloader MODE auto, grub, refind ou both
  --user NAME       Utilisateur cible de l'autologin
  --no-services     Installer les unités sans les activer
  --skip-reload     Ne pas recharger Hyprland/Caelestia
EOF
}

while (($#)); do
    case "$1" in
        --dry-run) DRY_RUN=1; SYSTEM_ARGS+=(--dry-run) ;;
        --no-packages) INSTALL_PACKAGES=0; SYSTEM_ARGS+=(--no-packages) ;;
        --no-wallpapers) INSTALL_WALLPAPERS=0 ;;
        --no-system) INSTALL_SYSTEM=0 ;;
        --no-bootloader|--no-nvidia|--no-autologin) SYSTEM_ARGS+=("$1") ;;
        --bootloader) shift; SYSTEM_ARGS+=(--bootloader "${1:?mode manquant}") ;;
        --user) shift; TARGET_USER="${1:?utilisateur manquant}" ;;
        --no-services) INSTALL_SERVICES=0 ;;
        --skip-reload) RELOAD_SESSION=0 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Option inconnue: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done
SYSTEM_ARGS+=(--user "$TARGET_USER")

if (( EUID == 0 )); then
    printf 'Exécuter install.sh avec un utilisateur normal ; le script appellera sudo uniquement pour le volet système.\n' >&2
    exit 1
fi
if [[ ! -f /etc/arch-release ]]; then
    printf 'Cette installation est conçue pour Arch Linux.\n' >&2
    exit 1
fi

log() { printf '[caelestia] %s\n' "$*"; }
run() {
    if (( DRY_RUN )); then
        printf '[dry-run]'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

require_caelestia() {
    local missing=() package
    for package in caelestia-shell caelestia-cli hyprland; do
        pacman -Q "$package" >/dev/null 2>&1 || missing+=("$package")
    done
    if ! pacman -Qq | rg -qx 'quickshell(-git)?'; then
        missing+=("quickshell ou quickshell-git")
    fi
    if ((${#missing[@]})); then
        printf 'Installation Caelestia incomplète. Manque: %s\n' "${missing[*]}" >&2
        exit 1
    fi
}

read_manifest() {
    rg -v '^\s*(#|$)' "$1"
}

ensure_yay() {
    command -v yay >/dev/null 2>&1 && return 0
    if (( DRY_RUN )); then
        log "installerait yay depuis l'AUR"
        return 0
    fi
    sudo pacman -S --needed --noconfirm base-devel git
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf -- "${tmp:-}"' RETURN
    git clone https://aur.archlinux.org/yay.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --needed --noconfirm)
    rm -rf -- "$tmp"
    trap - RETURN
}

install_dependencies() {
    local repo_missing=() aur_missing=() package
    while IFS= read -r package; do
        pacman -Q "$package" >/dev/null 2>&1 || repo_missing+=("$package")
    done < <(read_manifest "$REPO_ROOT/manifest/packages-repo.txt")
    while IFS= read -r package; do
        pacman -Q "$package" >/dev/null 2>&1 || aur_missing+=("$package")
    done < <(read_manifest "$REPO_ROOT/manifest/packages-aur.txt")

    if (( ! INSTALL_PACKAGES )); then
        ((${#repo_missing[@]} + ${#aur_missing[@]} == 0)) || log "dépendances absentes laissées intactes: ${repo_missing[*]} ${aur_missing[*]}"
        return 0
    fi
    ((${#repo_missing[@]} == 0)) || run sudo pacman -S --needed --noconfirm "${repo_missing[@]}"
    if ((${#aur_missing[@]})); then
        ensure_yay
        run yay -S --needed --noconfirm "${aur_missing[@]}"
    fi
}

timestamp="$(date +%Y%m%d-%H%M%S-%N)"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia-portable"
BACKUP_DIR="$STATE_ROOT/backups/$timestamp"

init_backup() {
    (( DRY_RUN )) && return 0
    install -d -m 0700 "$BACKUP_DIR/root"
    : > "$BACKUP_DIR/original.list"
    : > "$BACKUP_DIR/missing.list"
    : > "$BACKUP_DIR/services-enabled.list"
}

backup_path() {
    local path="$1"
    (( DRY_RUN )) && { log "sauvegarderait $path"; return 0; }
    if grep -Fxq -- "$path" "$BACKUP_DIR/original.list" "$BACKUP_DIR/missing.list" 2>/dev/null; then
        return 0
    fi
    if [[ -e "$path" || -L "$path" ]]; then
        install -d -m 0700 "$BACKUP_DIR/root$(dirname -- "$path")"
        cp -a -- "$path" "$BACKUP_DIR/root$path"
        printf '%s\n' "$path" >> "$BACKUP_DIR/original.list"
    else
        printf '%s\n' "$path" >> "$BACKUP_DIR/missing.list"
    fi
}

deploy() {
    local source="$1" destination="$2" mode="${3:-0644}"
    backup_path "$destination"
    if (( DRY_RUN )); then
        log "installerait $source -> $destination"
        return 0
    fi
    install -d -m 0755 "$(dirname -- "$destination")"
    if rg -q '__HOME__' "$source"; then
        local tmp
        tmp="$(mktemp)"
        python3 - "$source" "$tmp" "$HOME" <<'PY'
import sys
from pathlib import Path

source, destination, home = map(Path, sys.argv[1:])
destination.write_text(source.read_text(encoding="utf-8").replace("__HOME__", str(home)), encoding="utf-8")
PY
        install -m "$mode" "$tmp" "$destination"
        rm -f -- "$tmp"
    else
        install -m "$mode" "$source" "$destination"
    fi
}

install_dotfiles() {
    local source name
    log "installation des réglages utilisateur"
    for source in "$REPO_ROOT"/dotfiles/caelestia/*; do
        name="$(basename -- "$source")"
        deploy "$source" "$HOME/.config/caelestia/$name"
    done
    for source in "$REPO_ROOT"/dotfiles/waypaper/*; do
        name="$(basename -- "$source")"
        deploy "$source" "$HOME/.config/waypaper/$name"
    done
    deploy "$REPO_ROOT/dotfiles/clipse/config.json" "$HOME/.config/clipse/config.json"
    deploy "$REPO_ROOT/dotfiles/clipse-gui/settings.ini" "$HOME/.config/clipse-gui/settings.ini"

    for source in "$REPO_ROOT"/bin/*; do
        [[ -f "$source" ]] || continue
        name="$(basename -- "$source")"
        deploy "$source" "$HOME/.local/bin/$name" 0755
    done
    for source in "$REPO_ROOT"/dotfiles/systemd/user/*; do
        name="$(basename -- "$source")"
        deploy "$source" "$HOME/.config/systemd/user/$name"
    done

    for source in "$REPO_ROOT"/assets/profiles/*; do
        name="$(basename -- "$source")"
        deploy "$source" "$HOME/Images/Profils/$name"
    done
    if [[ ! -e "$HOME/.face" ]]; then
        deploy "$REPO_ROOT/assets/profiles/Sylvie.png" "$HOME/.face"
    else
        log "photo active conservée: $HOME/.face"
    fi
}

install_qml_overlay() {
    local qml_dir="$HOME/.config/quickshell/caelestia"
    local baseline=/etc/xdg/quickshell/caelestia
    local patch_file="$REPO_ROOT/patches/caelestia-shell-2.1.0.patch"
    local marker="$STATE_ROOT/qml-patch.sha256"
    local patch_hash
    patch_hash="$({ sha256sum "$patch_file" "$REPO_ROOT/overlay/quickshell/caelestia/services/LauncherState.qml"; } | sha256sum | awk '{print $1}')"

    if [[ -f "$marker" && "$(cat "$marker" 2>/dev/null)" == "$patch_hash" ]] && rg -q 'waypaperCurrentNamePath' "$qml_dir/services/Wallpapers.qml" 2>/dev/null; then
        log "overlay QML déjà appliqué"
        deploy "$REPO_ROOT/overlay/quickshell/caelestia/services/LauncherState.qml" "$qml_dir/services/LauncherState.qml"
        return 0
    fi

    backup_path "$qml_dir"
    local patch_target="$qml_dir"
    if [[ ! -d "$qml_dir" ]]; then
        [[ -d "$baseline" ]] || { printf 'Base QML Caelestia introuvable: %s\n' "$baseline" >&2; exit 1; }
        if (( DRY_RUN )); then
            log "copierait la base QML $baseline vers $qml_dir"
            patch_target="$baseline"
        else
            install -d -m 0755 "$qml_dir"
            rsync -rlt "$baseline/" "$qml_dir/"
        fi
    fi

    if rg -q 'waypaperCurrentNamePath' "$patch_target/services/Wallpapers.qml" 2>/dev/null; then
        log "comportement QML présent ; patch textuel non rejoué"
    else
        if ! patch --dry-run --forward --batch -p1 -d "$patch_target" < "$patch_file" >/tmp/caelestia-qml-patch.log 2>&1; then
            printf 'Patch QML incompatible ; aucun fichier QML n’a été modifié. Détails: /tmp/caelestia-qml-patch.log\n' >&2
            exit 1
        fi
        run patch --forward --batch -p1 -d "$qml_dir" -i "$patch_file"
    fi
    deploy "$REPO_ROOT/overlay/quickshell/caelestia/services/LauncherState.qml" "$qml_dir/services/LauncherState.qml"
    if (( ! DRY_RUN )); then
        install -d -m 0700 "$STATE_ROOT"
        printf '%s\n' "$patch_hash" > "$marker"
    fi
}

enable_services() {
    local units=(
        caelestia-cache-maintain.timer
        caelestia-wallpaper-thumbs-watch.service
        mpvpaper-guard.service
        clipse-maintain.timer
        clipse-theme-watch.service
    ) unit
    (( INSTALL_SERVICES )) || { log "activation systemd utilisateur ignorée"; return 0; }
    if (( ! DRY_RUN )); then
        for unit in "${units[@]}"; do
            systemctl --user is-enabled "$unit" >/dev/null 2>&1 && printf '%s\n' "$unit" >> "$BACKUP_DIR/services-enabled.list" || true
        done
    fi
    run systemctl --user daemon-reload
    run systemctl --user enable --now "${units[@]}"
}

download_wallpapers() {
    (( INSTALL_WALLPAPERS )) || { log "fonds d’écran ignorés"; return 0; }
    local checksum="$REPO_ROOT/release/$WALLPAPER_ASSET.sha256"
    [[ -f "$checksum" ]] || { printf 'Somme de contrôle absente: %s\n' "$checksum" >&2; exit 1; }
    if (( DRY_RUN )); then
        log "téléchargerait $WALLPAPER_ASSET depuis la Release $RELEASE_TAG"
        return 0
    fi

    local tmp archive
    tmp="$(mktemp -d)"
    archive="$tmp/$WALLPAPER_ASSET"
    trap 'rm -rf -- "${tmp:-}"' RETURN
    if [[ -n "${CAELESTIA_WALLPAPER_ARCHIVE:-}" ]]; then
        ln -s -- "$(realpath -- "$CAELESTIA_WALLPAPER_ARCHIVE")" "$archive"
    elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        gh release download "$RELEASE_TAG" --repo "$RELEASE_REPO" --pattern "$WALLPAPER_ASSET" --dir "$tmp"
    else
        curl --fail --location --retry 3 --output "$archive" \
            "https://github.com/$RELEASE_REPO/releases/download/$RELEASE_TAG/$WALLPAPER_ASSET"
    fi
    (cd "$tmp" && sha256sum -c "$checksum")
    if tar --zstd -tf "$archive" | awk '
        $0 !~ /^wallpapers\// || $0 ~ /(^|\/)\.\.($|\/)/ { bad=1 }
        END { exit bad }
    '; then
        install -d -m 0755 "$HOME/Images"
        tar --zstd --skip-old-files -xf "$archive" -C "$HOME/Images"
    else
        printf 'Archive refusée: chemins inattendus.\n' >&2
        exit 1
    fi
    rm -rf -- "$tmp"
    trap - RETURN
}

reload_session() {
    (( RELOAD_SESSION )) || return 0
    if (( DRY_RUN )); then
        log "rechargerait Hyprland et Caelestia dans une session active"
        return 0
    fi
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null
        if command -v qs >/dev/null 2>&1; then
            qs -c caelestia kill >/dev/null 2>&1 || true
            sleep 0.2
        fi
        caelestia shell -d >/tmp/caelestia-portable-shell.log 2>&1 || true
    else
        log "hors session Hyprland : rechargement différé au prochain login"
    fi
}

require_caelestia
install_dependencies
init_backup
install_dotfiles
install_qml_overlay
enable_services
download_wallpapers

if (( INSTALL_SYSTEM )); then
    "$REPO_ROOT/scripts/install-system.sh" "${SYSTEM_ARGS[@]}"
fi

if (( ! DRY_RUN )); then
    "$HOME/.local/bin/waypaper-style-polish" || true
fi
reload_session

if (( DRY_RUN )); then
    log "dry-run terminé : aucune modification effectuée"
else
    log "installation terminée"
    log "sauvegarde utilisateur: $BACKUP_DIR"
    log "diagnostic NVIDIA: $HOME/.local/bin/caelestia-nvidia-report"
fi
