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
    pacman -Q hyprland >/dev/null 2>&1 || missing+=(hyprland)
    for package in caelestia-shell caelestia-cli; do
        pacman -Q "$package" >/dev/null 2>&1 || pacman -Q "$package-git" >/dev/null 2>&1 || missing+=("$package-git")
    done
    # Le studio s'appuie sur la lecture vidéo native de Caelestia (module Caelestia.Multimedia,
    # branche main après la 2.5.0) : caelestia-shell-git tant qu'aucune version stable ne l'inclut.
    if [[ ! -d /usr/lib/qt6/qml/Caelestia/Multimedia ]]; then
        missing+=("caelestia-shell-git (vidéos natives)")
    fi
    if ! pacman -Q quickshell >/dev/null 2>&1 && ! pacman -Q quickshell-git >/dev/null 2>&1; then
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

deploy_if_missing() {
    local source="$1" destination="$2" mode="${3:-0644}"
    if [[ -e "$destination" || -L "$destination" ]]; then
        log "réglage existant conservé: $destination"
        return 0
    fi
    deploy "$source" "$destination" "$mode"
}

# Les règles hl.monitor sont propres à la machine et restent hors du dépôt : avant de
# remplacer hypr-user.lua, elles sont déplacées dans hypr-monitors.lua, que hypr-user.lua charge.
migrate_hypr_monitors() {
    local user_file="$HOME/.config/caelestia/hypr-user.lua"
    local monitors_file="$HOME/.config/caelestia/hypr-monitors.lua"
    local rules count
    [[ -f "$user_file" ]] || return 0
    rules="$(python3 - "$user_file" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
blocks = []
position = 0
while (start := text.find("hl.monitor(", position)) != -1:
    line_start = text.rfind("\n", 0, start) + 1
    position = start + 1
    if "--" in text[line_start:start]:
        continue
    depth, index, quote = 0, start + len("hl.monitor"), None
    while index < len(text):
        char = text[index]
        if quote:
            if char == "\\":
                index += 1
            elif char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                break
        index += 1
    else:
        sys.exit(f"hl.monitor non refermé dans {sys.argv[1]}")
    blocks.append(text[start:index + 1])
    position = index + 1
print("\n\n".join(blocks))
PY
)"
    [[ -n "$rules" ]] || return 0
    count="$(rg -c '^hl\.monitor\(' <<<"$rules")"
    backup_path "$monitors_file"
    if (( DRY_RUN )); then
        log "déplacerait $count règle(s) hl.monitor de $user_file vers $monitors_file"
        return 0
    fi
    if [[ ! -e "$monitors_file" ]]; then
        printf '%s\n' "-- Monitor layout of this machine (not in the repo), loaded by hypr-user.lua." > "$monitors_file"
    fi
    printf '\n%s\n' "$rules" >> "$monitors_file"
    log "$count règle(s) d'écran conservée(s) dans $monitors_file"
}

install_dotfiles() {
    local source name
    log "installation des réglages utilisateur"
    migrate_hypr_monitors
    for source in "$REPO_ROOT"/dotfiles/caelestia/*; do
        name="$(basename -- "$source")"
        case "$name" in
            cli.json|shell.json)
                deploy_if_missing "$source" "$HOME/.config/caelestia/$name"
                ;;
            *)
                deploy "$source" "$HOME/.config/caelestia/$name"
                ;;
        esac
    done
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
    local patch_file="$REPO_ROOT/patches/caelestia-shell-main.patch"
    local overlay_dir="$REPO_ROOT/overlay/quickshell/caelestia"
    local marker="$STATE_ROOT/qml-patch.sha256"
    local shell_version patch_hash
    [[ -d "$baseline" ]] || { printf 'Base QML Caelestia introuvable: %s\n' "$baseline" >&2; exit 1; }
    # La version du paquet fait partie de l'empreinte : après une mise à jour de
    # caelestia-shell, la copie locale est reconstruite au lieu de masquer la nouvelle version.
    shell_version="$(pacman -Q caelestia-shell-git 2>/dev/null || pacman -Q caelestia-shell 2>/dev/null || true)"
    patch_hash="$({ sha256sum "$patch_file"; find "$overlay_dir" -type f -print0 | sort -z | xargs -0 sha256sum; printf '%s\n' "$shell_version"; } | sha256sum | awk '{print $1}')"

    # Pour le shell (page « Updates » des réglages) : version du paquet d'où vient la copie
    # modifiée, et dépôt d'où la reconstruire quand le paquet a changé.
    record_qml_origin() {
        (( DRY_RUN )) && return 0
        install -d -m 0700 "$STATE_ROOT"
        printf '%s\n' "$shell_version" > "$STATE_ROOT/qml-shell-version"
        printf '%s\n' "$REPO_ROOT" > "$STATE_ROOT/repo-path"
    }

    if [[ -f "$marker" && "$(cat "$marker" 2>/dev/null)" == "$patch_hash" && -f "$qml_dir/services/WallStudio.qml" ]]; then
        log "overlay QML déjà appliqué"
        record_qml_origin
        return 0
    fi

    # Le patch est toujours testé sur une copie propre du paquet installé.
    local tmp_qml
    tmp_qml="$(mktemp -d)"
    rsync -rlt "$baseline/" "$tmp_qml/"
    if ! patch --forward --batch --fuzz=0 -p1 -d "$tmp_qml" < "$patch_file" >/tmp/caelestia-qml-patch.log 2>&1; then
        rm -rf -- "$tmp_qml"
        printf 'Patch QML incompatible avec %s ; aucun fichier QML n’a été modifié. Détails: /tmp/caelestia-qml-patch.log\n' "${shell_version:-caelestia-shell}" >&2
        exit 1
    fi
    rsync -rlt "$overlay_dir/" "$tmp_qml/"

    backup_path "$qml_dir"
    if (( DRY_RUN )); then
        log "reconstruirait $qml_dir depuis $baseline (${shell_version:-version inconnue}) + patch + overlay"
    else
        install -d -m 0755 "$qml_dir"
        rsync -rlt --delete "$tmp_qml/" "$qml_dir/"
        install -d -m 0700 "$STATE_ROOT"
        printf '%s\n' "$patch_hash" > "$marker"
        record_qml_origin
    fi
    rm -rf -- "$tmp_qml"
}

# Ancienne installation (Waypaper + mpvpaper + Clipse) : services arrêtés, scripts retirés
# (sauvegardés), réglages migrés vers le studio et le presse-papiers intégrés au shell.
migrate_legacy() {
    local legacy_units=(
        caelestia-wallpaper-thumbs-watch.service mpvpaper-guard.service
        clipse-listen-safe.service clipse-maintain.timer clipse-maintain.service
        clipse-history-snapshot.timer clipse-history-snapshot.service clipse-theme-watch.service
    )
    local legacy_bins=(
        mpvpaper-guard caelestia-wallpaper-set waypaper-open caelestia-wallpaper-video caelestia-theme-menu
        caelestia-wallpaper-thumbs-watch caelestia-wallpaper-menu caelestia-wallpaper-thumbs waypaper-restore-safe
        caelestia-waypaper-apply waypaper-style-polish cg-open clipse-gui-fixed clipse-history-snapshot
        clipse-listen-safe clipse-maintain clipse-privacy-audit clipse-store-safe clipse-theme-sync clipse-theme-watch
    )
    local unit name path
    for unit in "${legacy_units[@]}"; do
        path="$HOME/.config/systemd/user/$unit"
        [[ -e "$path" ]] || continue
        log "retrait de l'ancien service $unit"
        run systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
        backup_path "$path"
        run rm -f -- "$path"
    done
    for name in "${legacy_bins[@]}"; do
        path="$HOME/.local/bin/$name"
        [[ -e "$path" ]] || continue
        backup_path "$path"
        run rm -f -- "$path"
    done
    run pkill -x mpvpaper >/dev/null 2>&1 || true
    run pkill -f 'clipse-gui' >/dev/null 2>&1 || true

    (( DRY_RUN )) && { log "migrerait les réglages de thème et de fond"; return 0; }

    local cfg="$HOME/.config/caelestia"
    local state="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
    # Réglage forcé par Super+Alt+C (ancien menu) -> thème mémorisé pour ce fond dans le studio.
    if [[ -s "$cfg/theme-override-wallpaper" && ! -e "$state/wallstudio.json" ]]; then
        backup_path "$state/wallstudio.json"
        python3 - "$cfg" "$state/wallstudio.json" <<'PY'
import json, sys
from pathlib import Path
cfg, out = Path(sys.argv[1]), Path(sys.argv[2])
read = lambda n, d: (cfg / n).read_text().strip() if (cfg / n).exists() else d
wall = read("theme-override-wallpaper", "")
mode, variant = read("theme-mode", "auto"), read("theme-variant", "auto")
themes = {wall: {"mode": mode, "variant": variant}} if wall and (mode != "auto" or variant != "auto") else {}
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps({"favourites": [], "themes": themes, "transition": "random"}, indent=2))
PY
    fi
    # Le fond actif de Waypaper devient celui de Caelestia (les vidéos sont maintenant acceptées).
    if [[ -s "$cfg/waypaper-current" ]]; then
        local current
        current="$(head -n1 "$cfg/waypaper-current")"
        if [[ -f "$current" && "$(cat "$state/wallpaper/path.txt" 2>/dev/null)" != "$current" ]]; then
            "$HOME/.local/bin/caelestia-wallpaper-apply" "$current" >/dev/null 2>&1 || true
        fi
    fi
    for name in waypaper-current theme-override-wallpaper theme-mode theme-variant; do
        [[ -e "$cfg/$name" ]] || continue
        backup_path "$cfg/$name"
        rm -f -- "$cfg/$name"
    done
    # « Auto » = mode et variante choisis d'après le fond (comme l'ancien script).
    if [[ -f "$cfg/shell.json" ]] && ! jq -e '.services.smartScheme == true' "$cfg/shell.json" >/dev/null 2>&1; then
        backup_path "$cfg/shell.json"
        local tmp
        tmp="$(mktemp)"
        jq '.services.smartScheme = true' "$cfg/shell.json" > "$tmp" && install -m 0600 "$tmp" "$cfg/shell.json"
        rm -f -- "$tmp"
    fi
    rm -rf -- "$HOME/.cache/caelestia/wallpaper-thumbs" "$HOME/.cache/caelestia/wallpaper-transition-frames"
}

enable_services() {
    local units=(
        caelestia-cache-maintain.timer
        caelestia-clipboard.service
        protonmail-tray.service
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
migrate_legacy
install_qml_overlay
enable_services
download_wallpapers

if (( INSTALL_SYSTEM )); then
    "$REPO_ROOT/scripts/install-system.sh" "${SYSTEM_ARGS[@]}"
fi

if (( ! DRY_RUN )); then
    "$HOME/.local/bin/caelestia-wallpaper-cache" build --async || true
fi
reload_session

if (( DRY_RUN )); then
    log "dry-run terminé : aucune modification effectuée"
else
    log "installation terminée"
    log "sauvegarde utilisateur: $BACKUP_DIR"
    log "diagnostic NVIDIA: $HOME/.local/bin/caelestia-nvidia-report"
fi
