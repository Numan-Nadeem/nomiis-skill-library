#!/usr/bin/env bash
set -u

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"

show_header() {
    clear 2>/dev/null || true
    printf '\n========================================\n'
    printf "       Nomi's AI Skills Library\n"
    printf '========================================\n\n'
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$1" >&2
        exit 1
    fi
}

sync_repository() {
    printf '[1/1] Pulling your skills repository...\n'
    git -C "$REPO_ROOT" pull --rebase || {
        printf 'Git pull failed.\n' >&2
        return 1
    }
}

get_skill_files() {
    [[ -d "$SKILLS_DIR" ]] || return 0
    local skill_file
    # Categorized layout: skills/<category>/<skill-name>/SKILL.md
    for skill_file in "$SKILLS_DIR"/*/*/SKILL.md; do
        [[ -f "$skill_file" ]] && printf '%s\n' "$skill_file"
    done
    # Flat layout: skills/<skill-name>/SKILL.md
    for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
        [[ -f "$skill_file" ]] && printf '%s\n' "$skill_file"
    done
}

skill_name() {
    basename "$(dirname "$1")"
}

skill_type() {
    # skills/<category>/<skill-name> -> category; skills/<skill-name> -> uncategorized
    local relative="${1#"$SKILLS_DIR"/}"
    if [[ "$relative" == */* ]]; then
        printf '%s' "${relative%%/*}"
    else
        printf 'uncategorized'
    fi
}

show_available_skills() {
    local index=1
    local skill_file
    local skill_dir
    local relative_path
    local -a skill_files=()

    while IFS= read -r skill_file; do
        [[ -n "$skill_file" ]] && skill_files+=("$skill_file")
    done < <(get_skill_files)

    if (( ${#skill_files[@]} == 0 )); then
        printf 'No SKILL.md files were found.\n'
        return 0
    fi

    printf '\nAvailable Skills\n----------------\n'
    for skill_file in "${skill_files[@]}"; do
        skill_dir="$(dirname "$skill_file")"
        relative_path="${skill_dir#"$REPO_ROOT"/}"
        printf '[%d] %s\n' "$index" "$(skill_name "$skill_file")"
        printf '    Type:   %s\n' "$(skill_type "$skill_dir")"
        printf '    Source: %s\n' "$relative_path"
        ((index++))
    done
    printf '\n'
}

install_skill() {
    local skill_file="$1"
    local skill_dir
    skill_dir="$(dirname "$skill_file")"

    printf 'Installing: %s\n' "$(skill_name "$skill_file")"
    printf 'Source: %s\n' "$skill_dir"

    if npx skills add "$skill_dir" -g -y; then
        printf 'SUCCESS: %s\n' "$(skill_name "$skill_file")"
        return 0
    fi

    printf 'FAILED: %s\n' "$(skill_name "$skill_file")" >&2
    return 1
}

install_all_skills() {
    local skill_file
    local success=0
    local failed=0

    while IFS= read -r skill_file; do
        [[ -z "$skill_file" ]] && continue
        if install_skill "$skill_file"; then
            ((success++))
        else
            ((failed++))
        fi
    done < <(get_skill_files)

    printf '\nInstallation Summary\n'
    printf 'Successful: %d\n' "$success"
    printf 'Failed:     %d\n' "$failed"
}

install_with_skills_selector() {
    printf 'Launching the npx skills selector...\n'
    printf 'Select the skills you want to install globally.\n'

    if npx skills add "$REPO_ROOT" -g; then
        printf 'Selected skills installed successfully.\n'
    else
        printf 'The skills selector installation failed.\n' >&2
        return 1
    fi
}

install_selected_skills() {
    local selection
    local value
    local number
    local index=1
    local skill_file
    local -a skill_files=()

    while IFS= read -r skill_file; do
        [[ -n "$skill_file" ]] && skill_files+=("$skill_file")
    done < <(get_skill_files)

    show_available_skills
    (( ${#skill_files[@]} == 0 )) && return 0

    read -r -p 'Enter skill numbers separated by commas: ' selection
    IFS=',' read -ra values <<< "$selection"
    for value in "${values[@]}"; do
        value="${value//[[:space:]]/}"
        if [[ "$value" =~ ^[0-9]+$ ]]; then
            number=$((value - 1))
            if (( number >= 0 && number < ${#skill_files[@]} )); then
                install_skill "${skill_files[$number]}"
                continue
            fi
        fi
        printf 'Invalid skill number: %s\n' "$value" >&2
    done
}

add_external_skill() {
    local url
    local category
    local temp_root
    local skill_file
    local skill_name

    read -r -p 'External skill repository URL: ' url
    read -r -p 'Category to place the skill(s) under (e.g. design): ' category

    if [[ -z "$url" || -z "$category" ]]; then
        printf 'Repository URL and category are required.\n' >&2
        return 1
    fi

    if [[ ! "$category" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
        printf 'Category name may contain only letters, numbers, dots, underscores, and hyphens.\n' >&2
        return 1
    fi

    temp_root="$(mktemp -d)"
    if ! git clone --depth 1 "$url" "$temp_root/repo"; then
        printf 'Failed to clone the repository.\n' >&2
        rm -rf "$temp_root"
        return 1
    fi

    mkdir -p "$SKILLS_DIR/$category"

    # Sort by path depth (shallowest first) then deduplicate by skill
    # directory name. This collapses multi-platform repos (e.g. impeccable)
    # that ship the same SKILL.md for every agent harness into a single
    # entry each.
    while IFS= read -r skill_file; do
        [[ -z "$skill_file" ]] && continue
        skill_name="$(basename "$(dirname "$skill_file")")"
        if [[ -e "$SKILLS_DIR/$category/$skill_name" ]]; then
            printf 'Skipped (already exists): %s/%s\n' "$category" "$skill_name"
            continue
        fi
        cp -r "$(dirname "$skill_file")" "$SKILLS_DIR/$category/$skill_name"
        # Carry the upstream license/notice files into the vendored copy.
        find "$temp_root/repo" -maxdepth 1 -type f \( -iname 'LICENSE*' -o -iname 'NOTICE*' \) \
            -exec cp {} "$SKILLS_DIR/$category/$skill_name/" \;
        printf 'Vendored: %s/%s\n' "$category" "$skill_name"
    done < <(find "$temp_root/repo" -type f -name 'SKILL.md' -not -path '*/.git/*' -print \
        | awk -F'/' '{print NF"\t"$0}' \
        | sort -n \
        | awk -F'\t' '{print $2}' \
        | awk -F'/' '!seen[$(NF-1)]++')

    rm -rf "$temp_root"
    printf '\nReview the vendored skills, then commit the changes.\n'
}

run_menu() {
    local choice
    while true; do
        show_header
        printf 'Repository: %s\n\n' "$REPO_ROOT"
        printf '1. Install skills with the npx skills selector\n'
        printf '2. Install / update ALL skills automatically\n'
        printf '3. Select skills from the library\n'
        printf '4. Update already installed skills\n'
        printf '5. Show available skills\n'
        printf '6. Show installed skills\n'
        printf '7. Show Git repository status\n'
        printf '8. Vendor an external skill from a Git repository\n'
        printf '9. Exit\n\n'
        read -r -p 'Choose an option: ' choice

        case "$choice" in
            1) install_with_skills_selector; read -r -p 'Press Enter to continue' ;;
            2) install_all_skills; read -r -p 'Press Enter to continue' ;;
            3) install_selected_skills; read -r -p 'Press Enter to continue' ;;
            4) npx skills update -g -y; read -r -p 'Press Enter to continue' ;;
            5) show_available_skills; read -r -p 'Press Enter to continue' ;;
            6) npx skills list -g; read -r -p 'Press Enter to continue' ;;
            7) git -C "$REPO_ROOT" status; read -r -p 'Press Enter to continue' ;;
            8) add_external_skill; read -r -p 'Press Enter to continue' ;;
            9) printf 'Goodbye.\n'; return 0 ;;
            *) printf 'Invalid option.\n'; sleep 1 ;;
        esac
    done
}

require_command git
require_command npx
sync_repository || exit 1
run_menu
