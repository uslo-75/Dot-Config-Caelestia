#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="${1:-$HOME/Images/wallpapers}"
DIST="$REPO_ROOT/dist"
ASSET=caelestia-wallpapers-v1.tar.zst

[[ -d "$SOURCE" ]] || { printf 'Dossier introuvable: %s\n' "$SOURCE" >&2; exit 1; }
command -v zstd >/dev/null || { printf 'Installer zstd.\n' >&2; exit 1; }

mkdir -p "$DIST"
parent="$(dirname -- "$SOURCE")"
name="$(basename -- "$SOURCE")"

printf 'Création de %s à partir de %s...\n' "$DIST/$ASSET" "$SOURCE"
tar -C "$parent" --exclude="$name/.gitignore" --use-compress-program='zstd -T0 -1' -cf "$DIST/$ASSET" "$name"

size="$(stat -c %s "$DIST/$ASSET")"
limit=$((2 * 1024 * 1024 * 1024))
if (( size >= limit )); then
    printf 'Asset trop volumineux pour une GitHub Release: %s octets\n' "$size" >&2
    exit 1
fi

(cd "$DIST" && sha256sum "$ASSET")
printf 'Taille: %s octets (< 2 Gio)\n' "$size"
