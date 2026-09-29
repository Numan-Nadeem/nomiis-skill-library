#!/usr/bin/env bash
set -u

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
EXTERNAL_DIR="$REPO_ROOT/external"
PERSONAL_DIR="$REPO_ROOT/personal"

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
    printf '[1/2] Pulling your skills repository...\n'
    git -C "$REPO_ROOT" pull --rebase || {
        printf 'Git pull failed.\n' >&2
        return 1
    }

    printf '[2/2] Initializing/updating submodules...\n'
    git -C "$REPO_ROOT" submodule sync --recursive || return 1
    if ! git -C "$REPO_ROOT" submodule foreach --recursive 'test -z "$(git status --porcelain)"'; then
        printf 'A submodule has local changes. Commit or stash them before updating external skills.\n' >&2
        return 1
    fi

    git -C "$REPO_ROOT" submodule update --init --remote --recursive || return 1

    printf '\nSubmodule status:\n'
    git -C "$REPO_ROOT" submodule status --recursive
    printf '\n'
}

get_skill_files() {
    if [[ -d "$EXTERNAL_DIR" ]]; then
        find "$EXTERNAL_DIR" -type f -name 'SKILL.md' -print
    fi

    if [[ -d "$PERSONAL_DIR" ]]; then
        local skill_file
        for skill_file in "$PERSONAL_DIR"/*/SKILL.md; do
            [[ -f "$skill_file" ]] && printf '%s\n' "$skill_file"
        done
    fi
}

skill_name() {
    basename "$(dirname "$1")"
}

skill_type() {
    if [[ "$1" == "$EXTERNAL_DIR"/* ]]; then
        printf 'External'
    else
        printf 'Personal'
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

    if npx skills add "$REPO_ROOT" -g --full-depth; then
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
    local name
    local destination

    read -r -p 'External skill repository URL: ' url
    read -r -p 'External skill folder name: ' name

    if [[ -z "$url" || -z "$name" ]]; then
        printf 'Repository URL and folder name are required.\n' >&2
        return 1
    fi

    if [[ ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
        printf 'Folder name may contain only letters, numbers, dots, underscores, and hyphens.\n' >&2
        return 1
    fi

    destination="external/$name"
    if [[ -e "$REPO_ROOT/$destination" ]]; then
        printf 'The folder already exists: %s\n' "$destination" >&2
        return 1
    fi

    if ! git -C "$REPO_ROOT" submodule add "$url" "$destination"; then
        printf 'Failed to add the external skill submodule.\n' >&2
        return 1
    fi

    printf 'External skill added: %s\n' "$destination"
    printf 'Review and commit the .gitmodules and submodule changes.\n'
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
        printf '8. Add an external skill submodule\n'
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
