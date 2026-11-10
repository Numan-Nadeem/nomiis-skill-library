# Nomi's AI Skills Library

A categorized library of AI agent skills, installable with a single command through the [`skills`](https://github.com/vercel-labs/skills) CLI, with optional interactive managers for personal syncing across Windows, macOS, and Linux.

## Installation

Anyone can install skills from this repository without cloning it:

```bash
npx skills add Numan-Nadeem/nomiis-skill-library
```

This opens the interactive `skills` CLI selector, which lists every skill grouped by the category folders below `skills/`. Useful variations:

```bash
# Install everything, no prompts
npx skills add Numan-Nadeem/nomiis-skill-library --all

# Install one skill globally (available in all projects)
npx skills add Numan-Nadeem/nomiis-skill-library --skill strip-image-metadata -g

# Pin to a specific revision
npx skills add Numan-Nadeem/nomiis-skill-library@<tag-or-commit>
```

The CLI detects installed agents (Claude Code, Codex, ZCode, and others) and installs each selected skill into the agent's skills directory, such as `.agents/skills/<name>` or `~/.zcode/skills/<name>`.

## What This Repository Does

Besides direct `npx skills add` installation, the repository provides equivalent interactive managers for Windows, macOS, and Linux:

- `sync-skills.ps1` for Windows PowerShell or PowerShell 7.
- `sync-skills.sh` for macOS, Linux, WSL, and other Bash environments.

Both managers provide an interactive workflow to:

- Pull the latest changes for this repository.
- Discover local `SKILL.md` files.
- Install all skills or selected skills globally.
- Update and list globally installed skills.
- Vendor new external skills from Git repositories.
- Display the repository status.

Both managers resolve repository paths relative to their own location, so they work after cloning to any directory. The managers do not depend on this repository's name or on a particular user's home directory.

## Requirements

Install and expose these commands in `PATH`:

- Git
- Node.js, which provides `npx`
- The `skills` CLI, available through `npx skills`

Use PowerShell on Windows. Use Bash on macOS, Linux, or WSL. PowerShell 7 is also supported on macOS and Linux.

Verify the first two requirements with:

```powershell
git --version
npx --version
```

The manager scripts use network access for Git synchronization and for the `npx skills` commands. `update-vendored.sh` additionally clones the upstream repositories listed in `vendored-sources.txt`.

## Quick Start

For personal management of the library, clone and run a manager:

```bash
git clone <repository-url>
cd nomiis-skill-library
```

On Windows, run from PowerShell:

```powershell
.\sync-skills.ps1
```

On macOS, Linux, or WSL, run:

```bash
bash ./sync-skills.sh
```

On a Bash system, you may make the script directly executable once:

```bash
chmod +x sync-skills.sh
./sync-skills.sh
```

If PowerShell blocks local scripts, review the current execution policy:

```powershell
Get-ExecutionPolicy -List
```

Use the least-permissive policy appropriate for your machine. Do not bypass security controls blindly.

## Startup Synchronization

Every time a manager starts, it runs:

```text
git pull --rebase
```

The main repository is rebased onto the remote branch. Because this changes repository state, commit or stash important local changes before running a manager. A pull can also fail when the branch has conflicts, no upstream branch, or no network access.

## Interactive Menu

After synchronization, the script displays these options:

### 1. Install skills with the `npx skills` selector

Runs the CLI selector across the complete repository:

```text
npx skills add <repository-root> -g
```

Choose the skills you want in the interactive selector. Because every skill lives under the standard `skills/` container directory, no extra flags are required. This is the recommended installation path when you want the official `npx skills` selection experience.

### 2. Install / update all skills automatically

Scans the `skills` directory for skills and runs:

```powershell
npx skills add <skill-path> -g -y
```

Each discovered skill is installed independently. The summary reports successful and failed installations.

### 3. Select skills from the library

Displays a numbered list of discovered skills. Enter comma-separated numbers, for example:

```text
1,3
```

Invalid values are reported and skipped. Valid selections are installed globally.

### 4. Update already installed skills

Runs:

```powershell
npx skills update -g -y
```

This updates skills managed by the global `skills` installation.

### 5. Show available skills

Lists every skill discovered in the repository, including its name, category, and relative source path.

### 6. Show installed skills

Runs:

```powershell
npx skills list -g
```

Use this after the first installation to confirm that skills were registered where expected.

### 7. Show Git repository status

Runs `git status` from the repository root.

### 8. Vendor an external skill from a Git repository

Prompts for a Git repository URL and a category, then clones the repository, locates every distinct `SKILL.md`, and copies each skill folder into `skills/<category>/<skill-name>/` together with the upstream `LICENSE`/`NOTICE` files.

The category name may contain letters, numbers, dots, underscores, and hyphens. Existing destination folders are skipped, so remove a folder first to re-vendor it. Review the new skill contents before committing the changes.

After vendoring, choose option 5 to confirm the skill is discoverable, then choose option 1 or 2 to install it.

### 9. Exit

Closes the script.

## Skill Discovery Rules

Both managers recognize a skill when they find a file named exactly `SKILL.md` inside the `skills` directory. Two layouts are supported:

**Categorized** — the skill is grouped under a category folder:

```text
skills/<category>/<skill-name>/SKILL.md
```

**Flat** — the skill sits directly inside a named folder:

```text
skills/<skill-name>/SKILL.md
```

Both layouts are discovered and installed by both managers, and both are also visible to `npx skills add Numan-Nadeem/nomiis-skill-library`. Categorized skills display their category in the type column, for example `image-tools`.

The displayed skill name is the name of the directory containing `SKILL.md`. If two discovered directories have the same name, the menu can contain duplicate-looking entries, so use the displayed source path to distinguish them.

## Recommended Repository Layout

```text
nomiis-skill-library/
|
+-- skills/                        <- standard container scanned by npx skills
|   +-- animation/                 <- category folder
|   |   +-- animate/
|   |   |   +-- SKILL.md
|   |   |   +-- LICENSE
|   |   +-- ...
|   +-- design/
|   |   +-- design-taste-frontend/
|   |   |   +-- SKILL.md
|   |   |   +-- assets/
|   |   |   +-- references/
|   |   |   +-- LICENSE
|   |   +-- impeccable/
|   |   |   +-- SKILL.md
|   |   |   +-- LICENSE
|   |   |   +-- NOTICE.md
|   |   +-- ...
|   +-- image-tools/
|   |   +-- strip-image-metadata/
|   |       +-- SKILL.md
|   |       +-- scripts/
|   |           +-- strip_png_metadata.js
|   |           +-- strip_jpeg_metadata.js
|   +-- mobile/
|   +-- security/
|   +-- seo/
|
+-- .github/
|   +-- dependabot/
|   +-- workflows/
|       +-- update-vendored.yml
+-- sync-skills.ps1
+-- sync-skills.sh
+-- update-vendored.sh
+-- vendored-sources.txt
+-- README.md
```

To add a personal skill, create a directory under `skills` (optionally inside a category sub-folder), add a `SKILL.md` file, and run the manager again. Skills with bundled assets such as scripts should place them alongside `SKILL.md` in the skill directory. To add an external skill, use menu option 8 or edit `vendored-sources.txt` and run `./update-vendored.sh`.

## Vendored Skills and Updates

Skills from external authors are vendored — committed directly into this repository — so that `npx skills add` can install them. Git submodules would not work here because the `skills` CLI downloads a repository archive, which never includes submodule contents.

Each vendored skill keeps a copy of its upstream `LICENSE` (and `NOTICE` where applicable) inside its folder:

| Skills | Upstream | License |
| --- | --- | --- |
| `animation/*`, `mobile/*`, `design/{apple-design, ask-sonner, break-ui, emil-design-eng, pick-ui-library, prototype}` | [emilkowalski/skills](https://github.com/emilkowalski/skills) | MIT |
| `design/design-taste-frontend` | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | MIT |
| `design/impeccable` | [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | Apache-2.0 |
| `security/security-audit` | [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill) | MIT |
| `seo/seo-audit` | [seo-skills/seo-audit-skill](https://github.com/seo-skills/seo-audit-skill) | MIT |
| `image-tools/strip-image-metadata` | personal | — |

Upstream updates are refreshed by `vendored-sources.txt` + `update-vendored.sh`:

```bash
./update-vendored.sh          # re-vendor every listed skill from its upstream tip
git diff -- skills            # review the changes
```

A scheduled GitHub Actions workflow (`.github/workflows/update-vendored.yml`) runs the same script weekly and opens a pull request with any upstream changes. To track a new upstream skill automatically, add a line to `vendored-sources.txt`:

```text
<category>/<skill-name>|<upstream-repository>|<skill-folder-inside-repo>
```

## Troubleshooting

### `git` or `npx` is not recognized

Install Git or Node.js, restart the terminal, and confirm the commands are available in `PATH`.

### Git pull fails

Check the repository status, commit or stash local changes, confirm the branch has an upstream, and verify network access:

```powershell
git status
git remote -v
git branch -vv
```

### `npx skills add` finds no skills

Confirm that each skill contains a file named exactly `SKILL.md` under `skills/<category>/<skill-name>/`. The file name is case-sensitive in some environments. Skills outside the `skills/` directory are only found with `--full-depth`.

### A vendored update is skipped

`update-vendored.sh` reports when a destination folder or an upstream path no longer exists. Upstream repositories occasionally rename or move skill folders; update the affected line in `vendored-sources.txt` to match the new location.

### Installation fails

Run the failing `npx skills add` command manually using the source path shown by the script. Also check the `skills` CLI version and whether the target global skill location is writable.

### PowerShell refuses to run the script

Check the execution policy and whether the file was downloaded from an untrusted source. Prefer changing policy only for the appropriate scope rather than using a broad bypass.

### Bash is not available

Install Bash through your operating system, use WSL on Windows, or use the PowerShell manager instead. The repository does not require Bash on Windows when `sync-skills.ps1` is used.

## Safety and Maintenance Notes

- Review vendored skill changes (`git diff -- skills`) before installing them globally.
- Keep vendored skills in sync with `vendored-sources.txt`; the manifest is the source of truth for automated updates.
- Respect upstream licenses when vendoring new skills; keep `LICENSE`/`NOTICE` files inside each skill folder.
- Do not commit credentials, tokens, generated global skill directories, or machine-specific paths.
- The manager scripts use `-y`, so installation and update commands do not pause for confirmation.
- The exact behavior of `npx skills` can vary by CLI version. Confirm the result with menu option 5 after installation.
- The manager scripts intentionally install globally with `-g`; remove that flag only if you have verified the desired local installation workflow for your agents.

## Validation

Check PowerShell syntax without running synchronization or installing anything:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path (Get-Location) 'sync-skills.ps1'),
    [ref]$tokens,
    [ref]$errors
) | Out-Null

if ($errors.Count -eq 0) {
    'PowerShell syntax: OK'
} else {
    $errors | ForEach-Object {
        "Line $($_.Extent.StartLineNumber): $($_.Message)"
    }
}
```

On macOS, Linux, or WSL, check Bash syntax without running synchronization or installing anything:

```bash
bash -n sync-skills.sh
bash -n update-vendored.sh
```
