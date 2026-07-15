#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

printf '[1/7] Bash\n'
bash -n install.sh restore.sh scripts/*.sh bin/*

printf '[2/7] Python\n'
python3 - <<'PY'
import ast
from pathlib import Path

for name in ("bin/clipse-gui-fixed", "bin/clipse-theme-sync"):
    ast.parse(Path(name).read_text(encoding="utf-8"), filename=name)
PY

printf '[3/7] JSON\n'
for file in dotfiles/caelestia/*.json dotfiles/clipse/*.json; do
    jq empty "$file"
done

printf '[4/7] systemd\n'
if ! systemd_output="$(systemd-analyze verify dotfiles/systemd/user/*.service dotfiles/systemd/user/*.timer 2>&1)"; then
    relevant="$(printf '%s\n' "$systemd_output" | rg -v '^Failed to (turn off SO_PASSRIGHTS|enable SO_PASSCRED)' || true)"
    if [[ -n "$relevant" ]]; then
        printf '%s\n' "$relevant" >&2
        exit 1
    fi
    printf 'Avertissement: vérification systemd limitée par le bac à sable.\n'
fi

printf '[5/7] Patch QML\n'
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
rsync -rlt /etc/xdg/quickshell/caelestia/ "$tmp/"
patch --dry-run --forward --batch -p1 -d "$tmp" < patches/caelestia-shell-2.1.0.patch >/dev/null

printf '[6/7] Portabilité et confidentialité\n'
source_home='/home/'"uslo"
if rg -n -F "$source_home" . -g '!.git/**' -g '!dist/**'; then
    printf 'Chemin personnel détecté.\n' >&2
    exit 1
fi
if find . -path './.git' -prune -o -path './dist' -prune -o -type f \
    \( -name '*.bak*' -o -name '*.log' -o -name 'clipboard_history.json' -o -name 'monitors.conf' -o -name 'workspaces.conf' -o -name 'waypaper-current' \) \
    -print -quit | rg -q .; then
    printf 'Fichier d’état interdit détecté.\n' >&2
    exit 1
fi

printf '[7/7] Asset Release (si construit)\n'
asset=dist/caelestia-wallpapers-v1.tar.zst
if [[ -f "$asset" ]]; then
    (cd dist && sha256sum -c ../release/caelestia-wallpapers-v1.tar.zst.sha256)
    zstd --test "$asset"
fi

git diff --check
printf 'Toutes les validations ont réussi.\n'
