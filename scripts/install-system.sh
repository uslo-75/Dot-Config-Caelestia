#!/usr/bin/env bash
set -Eeuo pipefail

ORIGINAL_ARGS=("$@")
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0
INSTALL_BOOT=1
INSTALL_NVIDIA=1
INSTALL_AUTOLOGIN=1
INSTALL_PACKAGES=1
TARGET_USER="${SUDO_USER:-${USER:-uslo}}"
BOOT_MODE=auto

usage() {
    cat <<'EOF'
Usage: scripts/install-system.sh [options]

  --dry-run            Afficher sans modifier
  --user NAME          Utilisateur de l'autologin (défaut: utilisateur courant)
  --bootloader MODE    auto, grub, refind ou both
  --no-bootloader      Ne pas installer de thème de boot
  --no-nvidia          Ne pas vérifier/installer NVIDIA
  --no-autologin       Ne pas configurer SDDM
  --no-packages        Vérifier sans installer de paquets système
EOF
}

while (($#)); do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --user) shift; TARGET_USER="${1:?nom utilisateur manquant}" ;;
        --bootloader) shift; BOOT_MODE="${1:?mode manquant}" ;;
        --no-bootloader) INSTALL_BOOT=0 ;;
        --no-nvidia) INSTALL_NVIDIA=0 ;;
        --no-autologin) INSTALL_AUTOLOGIN=0 ;;
        --no-packages) INSTALL_PACKAGES=0 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Option inconnue: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

case "$BOOT_MODE" in auto|grub|refind|both) ;; *) printf 'Bootloader invalide: %s\n' "$BOOT_MODE" >&2; exit 2 ;; esac

if (( ! DRY_RUN && EUID != 0 )); then
    exec sudo -- "$0" "${ORIGINAL_ARGS[@]}"
fi

log() { printf '[system] %s\n' "$*"; }
run() {
    if (( DRY_RUN )); then
        printf '[dry-run system]'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

if ! getent passwd "$TARGET_USER" >/dev/null; then
    printf 'Utilisateur introuvable: %s\n' "$TARGET_USER" >&2
    exit 1
fi

target_uid="$(getent passwd "$TARGET_USER" | cut -d: -f3)"
if (( target_uid < 1000 )); then
    printf 'Refus de configurer un compte système (UID %s).\n' "$target_uid" >&2
    exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S-%N)"
BACKUP_DIR="/var/lib/caelestia-portable/backups/$timestamp"

init_backup() {
    (( DRY_RUN )) && return 0
    install -d -m 0700 "$BACKUP_DIR/root"
    : > "$BACKUP_DIR/original.list"
    : > "$BACKUP_DIR/missing.list"
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

install_packages() {
    local missing=() package
    for package in "$@"; do
        pacman -Q "$package" >/dev/null 2>&1 || missing+=("$package")
    done
    ((${#missing[@]})) || return 0
    if (( INSTALL_PACKAGES )); then
        run pacman -S --needed --noconfirm "${missing[@]}"
    else
        log "paquets système manquants laissés intacts: ${missing[*]}"
    fi
}

install_autologin() {
    log "configuration SDDM autologin pour $TARGET_USER (aucun mot de passe stocké)"
    local password_state
    password_state="$(passwd -S "$TARGET_USER" 2>/dev/null | awk '{print $2}' || true)"
    if [[ "$password_state" != P ]]; then
        log "attention: le compte n’a pas l’état mot de passe P ; le verrouillage Caelestia peut ne pas fonctionner comme prévu"
    fi
    install_packages sddm
    if [[ ! -f /usr/share/wayland-sessions/hyprland.desktop ]]; then
        printf 'Session Hyprland absente: /usr/share/wayland-sessions/hyprland.desktop\n' >&2
        exit 1
    fi
    local dest=/etc/sddm.conf.d/99-caelestia-autologin.conf
    backup_path "$dest"
    backup_path /etc/systemd/system/display-manager.service
    if (( DRY_RUN )); then
        log "installerait $dest avec User=$TARGET_USER Session=hyprland"
    else
        install -d -m 0755 /etc/sddm.conf.d
        sed "s/__USER__/$TARGET_USER/g" "$REPO_ROOT/system/sddm/99-caelestia-autologin.conf.in" > "$dest"
        chmod 0644 "$dest"
    fi
    run systemctl enable sddm.service --force
}

choose_nvidia_driver_packages() {
    if pacman -Qq | rg -qx 'nvidia(-open)?(-lts|-dkms)?'; then
        return 0
    fi

    local gpu kernels custom=0 kernel
    gpu="$(lspci -nn 2>/dev/null | rg -i 'NVIDIA.*(VGA|3D)|(?:VGA|3D).*NVIDIA' || true)"
    if ! printf '%s\n' "$gpu" | rg -qi 'RTX|GTX 16|Quadro RTX|GB[0-9]|AD[0-9]|GA[0-9]|TU[0-9]'; then
        printf 'GPU NVIDIA détecté mais génération non reconnue pour nvidia-open. Installation automatique du module refusée.\n%s\n' "$gpu" >&2
        return 0
    fi

    mapfile -t kernels < <(pacman -Qq | rg '^linux($|-lts$|-zen$|-hardened$)' || true)
    ((${#kernels[@]})) || { printf 'Aucun noyau Arch pris en charge détecté.\n' >&2; return 0; }
    for kernel in "${kernels[@]}"; do
        case "$kernel" in linux|linux-lts) ;; *) custom=1 ;; esac
    done

    if (( custom )); then
        local packages=(nvidia-open-dkms) header
        for kernel in "${kernels[@]}"; do
            header="${kernel}-headers"
            pacman -Si "$header" >/dev/null 2>&1 && packages+=("$header")
        done
        install_packages "${packages[@]}"
    else
        local packages=()
        printf '%s\n' "${kernels[@]}" | rg -qx linux && packages+=(nvidia-open)
        printf '%s\n' "${kernels[@]}" | rg -qx linux-lts && packages+=(nvidia-open-lts)
        install_packages "${packages[@]}"
    fi
}

install_nvidia() {
    if ! lspci -nn 2>/dev/null | rg -qi 'NVIDIA.*(VGA|3D)|(?:VGA|3D).*NVIDIA'; then
        log "aucun GPU NVIDIA détecté, volet NVIDIA ignoré"
        return 0
    fi
    log "GPU NVIDIA détecté"
    choose_nvidia_driver_packages
    install_packages nvidia-utils nvidia-settings libva-nvidia-driver nvtop
    pacman -Si lib32-nvidia-utils >/dev/null 2>&1 && install_packages lib32-nvidia-utils

    local dest=/etc/modprobe.d/caelestia-nvidia.conf
    backup_path "$dest"
    run install -Dm0644 "$REPO_ROOT/system/modprobe.d/caelestia-nvidia.conf" "$dest"
    if command -v mkinitcpio >/dev/null 2>&1; then
        run mkinitcpio -P
    fi
}

find_refind_dir() {
    local candidate
    for candidate in /boot/EFI/refind /boot/efi/EFI/refind /efi/EFI/refind; do
        [[ -f "$candidate/refind.conf" ]] && { printf '%s\n' "$candidate"; return 0; }
    done
    return 1
}

install_refind_theme() {
    local refind_dir theme_dest conf
    refind_dir="$(find_refind_dir || true)"
    if [[ -z "$refind_dir" ]]; then
        log "rEFInd non détecté, thème rEFInd ignoré"
        return 0
    fi
    theme_dest="$refind_dir/themes/refind-gruvbox-theme"
    conf="$refind_dir/refind.conf"
    backup_path "$theme_dest"
    backup_path "$conf"
    if (( DRY_RUN )); then
        log "installerait le thème rEFInd dans $theme_dest"
        return 0
    fi
    install -d -m 0755 "$theme_dest"
    cp -a "$REPO_ROOT/boot/refind/refind-gruvbox-theme/." "$theme_dest/"
    python3 - "$conf" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
lines = [line for line in text.splitlines() if not re.match(r"^\s*include\s+themes/.+/theme\.conf\s*$", line)]
lines.extend(["", "include themes/refind-gruvbox-theme/theme.conf"])
path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
PY
}

install_grub_theme() {
    if [[ ! -f /etc/default/grub && ! -f /boot/grub/grub.cfg ]]; then
        log "GRUB non détecté, thème GRUB ignoré"
        return 0
    fi
    install_packages grub ttf-dejavu
    local theme_dest=/boot/grub/themes/caelestia-gruvbox
    local defaults=/etc/default/grub
    local grub_cfg=/boot/grub/grub.cfg
    backup_path "$theme_dest"
    backup_path "$defaults"
    backup_path "$grub_cfg"
    if (( DRY_RUN )); then
        log "installerait le thème GRUB dans $theme_dest et régénérerait $grub_cfg"
        return 0
    fi
    install -d -m 0755 "$theme_dest"
    cp -a "$REPO_ROOT/boot/grub/caelestia-gruvbox/." "$theme_dest/"
    grub-mkfont -s 16 -o "$theme_dest/DejaVuSans16.pf2" /usr/share/fonts/TTF/DejaVuSans.ttf
    grub-mkfont -s 18 -o "$theme_dest/DejaVuSans18.pf2" /usr/share/fonts/TTF/DejaVuSans.ttf
    grub-mkfont -s 16 -o "$theme_dest/DejaVuSansMono16.pf2" /usr/share/fonts/TTF/DejaVuSansMono.ttf
    grub-mkfont -s 18 -o "$theme_dest/DejaVuSansBold18.pf2" /usr/share/fonts/TTF/DejaVuSans-Bold.ttf
    grub-mkfont -s 28 -o "$theme_dest/DejaVuSansBold28.pf2" /usr/share/fonts/TTF/DejaVuSans-Bold.ttf
    python3 - "$defaults" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8") if path.exists() else ""
setting = 'GRUB_THEME="/boot/grub/themes/caelestia-gruvbox/theme.txt"'
if re.search(r"^GRUB_THEME=.*$", text, flags=re.MULTILINE):
    text = re.sub(r"^GRUB_THEME=.*$", setting, text, flags=re.MULTILINE)
else:
    text = text.rstrip() + "\n" + setting + "\n"
path.write_text(text, encoding="utf-8")
PY
    grub-mkconfig -o "$grub_cfg"
}

install_boot_theme() {
    case "$BOOT_MODE" in
        grub) install_grub_theme ;;
        refind) install_refind_theme ;;
        both) install_grub_theme; install_refind_theme ;;
        auto)
            local found=0
            if [[ -f /etc/default/grub || -f /boot/grub/grub.cfg ]]; then install_grub_theme; found=1; fi
            if find_refind_dir >/dev/null; then install_refind_theme; found=1; fi
            (( found )) || log "aucun bootloader GRUB/rEFInd reconnu ; aucune modification"
            ;;
    esac
}

init_backup
(( INSTALL_AUTOLOGIN )) && install_autologin
(( INSTALL_NVIDIA )) && install_nvidia
(( INSTALL_BOOT )) && install_boot_theme

if (( DRY_RUN )); then
    log "dry-run terminé"
else
    log "installation système terminée ; sauvegarde: $BACKUP_DIR"
    log "un redémarrage est requis pour valider SDDM et les éventuels changements NVIDIA"
fi
