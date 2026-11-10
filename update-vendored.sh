#!/usr/bin/env bash
# Refreshes every vendored skill listed in vendored-sources.txt from its
# upstream repository tip. Review the resulting git diff before committing.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$REPO_ROOT/vendored-sources.txt"
TEMP_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

clone_once() {
    local url="$1"
    local clone_dir="$TEMP_ROOT/$(printf '%s' "$url" | tr '/:' '__')"
    if [[ ! -d "$clone_dir" ]]; then
        git clone --quiet --depth 1 "$url" "$clone_dir"
    fi
    printf '%s' "$clone_dir"
}

updated=0
skipped=0

while IFS='|' read -r destination url source_path; do
    # Skip blank lines and comments.
    [[ -z "$destination" || "$destination" == \#* ]] && continue

    if [[ ! -f "$REPO_ROOT/skills/$destination/SKILL.md" ]]; then
        printf 'Missing destination, skipped: skills/%s\n' "$destination" >&2
        skipped=$((skipped + 1))
        continue
    fi

    clone_dir="$(clone_once "$url")"

    if [[ ! -d "$clone_dir/$source_path" ]]; then
        printf 'Upstream path gone, skipped: %s (%s)\n' "$destination" "$url" >&2
        skipped=$((skipped + 1))
        continue
    fi

    rm -rf "$REPO_ROOT/skills/$destination"
    cp -r "$clone_dir/$source_path" "$REPO_ROOT/skills/$destination"

    # Refresh the upstream license/notice files.
    find "$clone_dir" -maxdepth 1 -type f \( -iname 'LICENSE*' -o -iname 'NOTICE*' \) \
        -exec cp {} "$REPO_ROOT/skills/$destination/" \;

    printf 'Updated: skills/%s\n' "$destination"
    updated=$((updated + 1))
done < "$MANIFEST"

printf '\nUpdated: %d, Skipped: %d\n' "$updated" "$skipped"
if git -C "$REPO_ROOT" diff --quiet -- skills; then
    printf 'No upstream changes detected.\n'
else
    printf 'Changes detected. Review with: git diff -- skills\n'
fi
