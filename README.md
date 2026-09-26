# Nomi's AI Skills Library

A Git-based library and cross-platform manager for reusable AI agent skills. The repository keeps external skills as Git submodules and can install selected skills globally with the `skills` command-line tool.

## What This Repository Does

The repository provides equivalent interactive managers for Windows, macOS, and Linux:

- `sync-skills.ps1` for Windows PowerShell or PowerShell 7.
- `sync-skills.sh` for macOS, Linux, WSL, and other Bash environments.

Both managers provide an interactive workflow to:

- Pull the latest changes for this repository.
- Initialize and update the exact submodule commits recorded here.
- Discover local `SKILL.md` files.
- Install all skills or selected skills globally.
- Update and list globally installed skills.
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

The script uses network access for Git synchronization and for the `npx skills` commands.

## Quick Start

Clone the repository with its submodule:

```bash
git clone --recurse-submodules <repository-url>
cd nomiis-skill-library
```

If the repository was cloned without `--recurse-submodules`, the managers initialize it automatically on startup. You can also initialize it manually:

```bash
git submodule update --init --recursive
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

Every time a manager starts, it runs these commands in order:

```text
git pull --rebase
git submodule sync --recursive
git submodule foreach --recursive 'test -z "$(git status --porcelain)"'
git submodule update --init --remote --recursive
```

This means:

1. The main repository is rebased onto the remote branch.
2. Submodule URLs are synchronized with `.gitmodules`.
3. Submodules are initialized and updated to the latest commit on each submodule's configured remote branch.

External repositories update automatically on every manager start. The clean-submodule check prevents an update when a submodule contains local changes. The parent repository may then show a modified submodule gitlink; review and commit that gitlink if you want to record the newly selected external revision in your clone.

Because `git pull --rebase` and remote submodule updates change repository state, commit or stash important local changes before running a manager. A pull can also fail when the branch has conflicts, no upstream branch, or no network access.

## Interactive Menu

After synchronization, the script displays these options:

### 1. Install / update all skills

Scans the `external` and `personal` directories for skills and runs:

```powershell
npx skills add <skill-path> -g -y
```

Each discovered skill is installed independently. The summary reports successful and failed installations.

### 2. Select skills to install / update

Displays a numbered list of discovered skills. Enter comma-separated numbers, for example:

```text
1,3
```

Invalid values are reported and skipped. Valid selections are installed globally.

### 3. Update already installed skills

Runs:

```powershell
npx skills update -g -y
```

This updates skills managed by the global `skills` installation.

### 4. Show available skills

Lists every skill discovered in the repository, including its name, type, and relative source path.

### 5. Show installed skills

Runs:

```powershell
npx skills list -g
```

Use this after the first installation to confirm that skills were registered where expected.

### 6. Show Git repository status

Runs `git status` from the repository root.

### 7. Exit

Closes the script.

## Skill Discovery Rules

Both managers recognize a skill when they find a file named exactly `SKILL.md`.

External skills are searched recursively below each direct child directory of `external`:

```text
external/<repository>/**/SKILL.md
```

Personal skills are searched one level below `personal`:

```text
personal/<skill-name>/SKILL.md
```

A personal directory is optional. The current repository may contain only external skills.

The displayed skill name is the name of the directory containing `SKILL.md`. If two discovered directories have the same name, the menu can contain duplicate-looking entries, so use the displayed source path to distinguish them.

## Recommended Repository Layout

```text
nomiis-skill-library/
|
+-- external/
|   +-- cloudflare-security-audit/
|       +-- skills/
|           +-- security-audit/
|               +-- SKILL.md
|
+-- personal/
|   +-- typescript/
|       +-- SKILL.md
|   +-- nextjs/
|       +-- SKILL.md
|   +-- etsy/
|       +-- SKILL.md
|
+-- .github/
|   +-- dependabot/
|       +-- dependabot.yml
+-- .gitmodules
+-- sync-skills.ps1
+-- sync-skills.sh
+-- README.md
```

To add a personal skill, create a directory under `personal`, add a `SKILL.md` file, and run the script again. External skills should normally remain managed by their Git submodule.

## External Skill Updates

The Cloudflare security audit skill is configured as a submodule in `.gitmodules` and is refreshed from its upstream remote automatically:

```ini
[submodule "external/cloudflare-security-audit"]
    path = external/cloudflare-security-audit
    url = https://github.com/cloudflare/security-audit-skill.git
```

Dependabot can still propose updates to the submodule pointer in the main repository. The managers also fetch the current upstream submodule revision locally, so users receive external skill updates without waiting for a parent-repository change. Review the changed skill contents and commit the updated gitlink when maintaining a controlled repository state.

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

### Submodule content is missing

Run the following from the repository root:

```powershell
git submodule sync --recursive
git submodule update --init --remote --recursive
```

### A submodule update is blocked

The manager stops when an external repository has uncommitted or untracked changes. Enter the submodule directory, commit or stash the changes, and run the manager again. This prevents automatic updates from overwriting local work.

### No skills are listed

Confirm that each skill contains a file named exactly `SKILL.md` in one of the supported locations. The file name is case-sensitive in some environments.

### Installation fails

Run the failing `npx skills add` command manually using the source path shown by the script. Also check the `skills` CLI version and whether the target global skill location is writable.

### PowerShell refuses to run the script

Check the execution policy and whether the file was downloaded from an untrusted source. Prefer changing policy only for the appropriate scope rather than using a broad bypass.

### Bash is not available

Install Bash through your operating system, use WSL on Windows, or use the PowerShell manager instead. The repository does not require Bash on Windows when `sync-skills.ps1` is used.

## Safety and Maintenance Notes

- Review external skill changes before installing them globally.
- Keep the main repository and submodule commits under version control.
- Do not commit credentials, tokens, generated global skill directories, or machine-specific paths.
- The script uses `-y`, so installation and update commands do not pause for confirmation.
- The exact behavior of `npx skills` can vary by CLI version. Confirm the result with menu option 5 after installation.
- The script intentionally installs globally with `-g`; remove that flag only if you have verified the desired local installation workflow for your agents.

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
```
