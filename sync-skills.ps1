$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

$ExternalDir = Join-Path $RepoRoot "external"
$PersonalDir = Join-Path $RepoRoot "personal"

function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "       Nomi's AI Skills Library" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-Dependencies {
    Write-Host "[Checking dependencies]" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git is not installed or not available in PATH."
    }

    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
        throw "npx is not installed or not available in PATH. Install Node.js first."
    }

    Write-Host "Git: OK" -ForegroundColor Green
    Write-Host "npx: OK" -ForegroundColor Green
    Write-Host ""
}

function Sync-GitRepository {
    Write-Host "[1/2] Pulling your skills repository..." -ForegroundColor Yellow
    git pull --rebase
    if ($LASTEXITCODE -ne 0) {
        throw "Git pull failed."
    }

    Write-Host "[2/2] Initializing/updating submodules..." -ForegroundColor Yellow
    git submodule sync --recursive
    if ($LASTEXITCODE -ne 0) {
        throw "Git submodule sync failed."
    }

    $submodulePaths = @(git config --file .gitmodules --get-regexp '^submodule\..*\.path$' |
        ForEach-Object {
            ($_ -split '\s+', 2)[1]
        })

    foreach ($submodulePath in $submodulePaths) {
        $submoduleChanges = @(git -C $submodulePath status --porcelain)
        if ($submoduleChanges.Count -gt 0) {
            throw "A submodule has local changes: $submodulePath. Commit or stash them before updating external skills."
        }
    }

    git submodule update --init --remote --recursive
    if ($LASTEXITCODE -ne 0) {
        throw "Git submodule update failed."
    }

    Write-Host ""
    Write-Host "Submodule status:" -ForegroundColor Cyan
    git submodule status --recursive
    Write-Host ""
}

function Get-SkillDirectories {
    $skills = @()

    if (Test-Path $ExternalDir) {
        Get-ChildItem -Path $ExternalDir -Directory | ForEach-Object {
            $repository = $_

            Get-ChildItem -Path $repository.FullName -Filter "SKILL.md" -File -Recurse -ErrorAction SilentlyContinue |
                ForEach-Object {
                    $skillDirectory = $_.Directory.FullName
                    $relativePath = $skillDirectory.Substring($RepoRoot.Length).TrimStart('\')

                    $skills += [PSCustomObject]@{
                        Name = $_.Directory.Name
                        Type = "External"
                        Source = $relativePath
                        Path = $skillDirectory
                    }
                }
        }
    }

    if (Test-Path $PersonalDir) {
        Get-ChildItem -Path $PersonalDir -Directory | ForEach-Object {
            $topLevel = $_
            $directSkillFile = Join-Path $topLevel.FullName "SKILL.md"

            if (Test-Path $directSkillFile) {
                # Flat layout: personal/<skill-name>/SKILL.md
                $relativePath = $topLevel.FullName.Substring($RepoRoot.Length).TrimStart('\')

                $skills += [PSCustomObject]@{
                    Name   = $topLevel.Name
                    Type   = "Personal"
                    Source = $relativePath
                    Path   = $topLevel.FullName
                }
            } else {
                # Categorized layout: personal/<category>/<skill-name>/SKILL.md
                Get-ChildItem -Path $topLevel.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                    $skillDirectory = $_.FullName
                    $skillFile = Join-Path $skillDirectory "SKILL.md"

                    if (Test-Path $skillFile) {
                        $relativePath = $skillDirectory.Substring($RepoRoot.Length).TrimStart('\')

                        $skills += [PSCustomObject]@{
                            Name   = $_.Name
                            Type   = "Personal / $($topLevel.Name)"
                            Source = $relativePath
                            Path   = $skillDirectory
                        }
                    }
                }
            }
        }
    }

    return $skills
}

function Show-AvailableSkills {
    $skills = @(Get-SkillDirectories)

    if ($skills.Count -eq 0) {
        Write-Host "No SKILL.md files were found." -ForegroundColor Red
        return @()
    }

    Write-Host ""
    Write-Host "Available Skills" -ForegroundColor Cyan
    Write-Host "----------------" -ForegroundColor Cyan

    for ($index = 0; $index -lt $skills.Count; $index++) {
        $skill = $skills[$index]
        Write-Host "[$($index + 1)] $($skill.Name)" -ForegroundColor White
        Write-Host "    Type:   $($skill.Type)" -ForegroundColor DarkGray
        Write-Host "    Source: $($skill.Source)" -ForegroundColor DarkGray
    }

    Write-Host ""
    return $skills
}

function Install-Skill {
    param (
        [Parameter(Mandatory = $true)]
        $Skill
    )

    Write-Host "Installing: $($Skill.Name)" -ForegroundColor Cyan
    Write-Host "Source: $($Skill.Path)" -ForegroundColor DarkGray

    npx skills add "$($Skill.Path)" -g -y
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $($Skill.Name)" -ForegroundColor Red
        return $false
    }

    Write-Host "SUCCESS: $($Skill.Name)" -ForegroundColor Green
    return $true
}

function Install-AllSkills {
    $skills = @(Get-SkillDirectories)

    if ($skills.Count -eq 0) {
        Write-Host "No skills found." -ForegroundColor Red
        return
    }

    $success = 0
    $failed = 0

    foreach ($skill in $skills) {
        if (Install-Skill -Skill $skill) {
            $success++
        }
        else {
            $failed++
        }
    }

    Write-Host ""
    Write-Host "Installation Summary" -ForegroundColor Cyan
    Write-Host "Successful: $success" -ForegroundColor Green
    Write-Host "Failed:     $failed" -ForegroundColor Red
}

function Install-WithSkillsSelector {
    Write-Host "Launching the npx skills selector..." -ForegroundColor Cyan
    Write-Host "Select the skills you want to install globally." -ForegroundColor DarkGray

    npx skills add $RepoRoot -g --full-depth
    if ($LASTEXITCODE -ne 0) {
        Write-Host "The skills selector installation failed." -ForegroundColor Red
        return
    }

    Write-Host "Selected skills installed successfully." -ForegroundColor Green
}

function Install-SelectedSkills {
    $skills = @(Show-AvailableSkills)
    if ($skills.Count -eq 0) {
        return
    }

    $selection = Read-Host "Enter skill numbers separated by commas"
    if ([string]::IsNullOrWhiteSpace($selection)) {
        Write-Host "No skills selected." -ForegroundColor Yellow
        return
    }

    $selectedSkills = @()
    foreach ($value in ($selection -split ',')) {
        $number = 0
        $value = $value.Trim()

        if (-not [int]::TryParse($value, [ref]$number) -or $number -lt 1 -or $number -gt $skills.Count) {
            Write-Host "Invalid skill number: $value" -ForegroundColor Red
            continue
        }

        $selectedSkills += $skills[$number - 1]
    }

    foreach ($skill in $selectedSkills) {
        Install-Skill -Skill $skill
    }
}

function Update-InstalledSkills {
    npx skills update -g -y
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Skill update failed." -ForegroundColor Red
        return
    }

    Write-Host "Installed skills updated successfully." -ForegroundColor Green
}

function Show-InstalledSkills {
    npx skills list -g
}

function Show-RepositoryStatus {
    git status
}

function Add-ExternalSkill {
    $url = Read-Host "External skill repository URL"
    $name = Read-Host "External skill folder name"

    if ([string]::IsNullOrWhiteSpace($url) -or [string]::IsNullOrWhiteSpace($name)) {
        Write-Host "Repository URL and folder name are required." -ForegroundColor Red
        return
    }

    if ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        Write-Host "Folder name may contain only letters, numbers, dots, underscores, and hyphens." -ForegroundColor Red
        return
    }

    $relativePath = Join-Path "external" $name
    $fullPath = Join-Path $RepoRoot $relativePath

    if (Test-Path $fullPath) {
        Write-Host "The folder already exists: $relativePath" -ForegroundColor Red
        return
    }

    git submodule add $url $relativePath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to add the external skill submodule." -ForegroundColor Red
        return
    }

    Write-Host "External skill added: $relativePath" -ForegroundColor Green
    Write-Host "Review and commit the .gitmodules and submodule changes." -ForegroundColor Yellow
}

try {
    Show-Header
    Test-Dependencies
    Sync-GitRepository
}
catch {
    Write-Host "Synchronization failed: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

while ($true) {
    Show-Header
    Write-Host "Repository: $RepoRoot" -ForegroundColor Gray
    Write-Host ""
    Write-Host "1. Install skills with the npx skills selector"
    Write-Host "2. Install / update ALL skills automatically"
    Write-Host "3. Select skills from the library"
    Write-Host "4. Update already installed skills"
    Write-Host "5. Show available skills"
    Write-Host "6. Show installed skills"
    Write-Host "7. Show Git repository status"
    Write-Host "8. Add an external skill submodule"
    Write-Host "9. Exit"
    Write-Host ""

    switch (Read-Host "Choose an option") {
        "1" { Install-WithSkillsSelector; Read-Host "Press Enter to continue" }
        "2" { Install-AllSkills; Read-Host "Press Enter to continue" }
        "3" { Install-SelectedSkills; Read-Host "Press Enter to continue" }
        "4" { Update-InstalledSkills; Read-Host "Press Enter to continue" }
        "5" { Show-AvailableSkills; Read-Host "Press Enter to continue" }
        "6" { Show-InstalledSkills; Read-Host "Press Enter to continue" }
        "7" { Show-RepositoryStatus; Read-Host "Press Enter to continue" }
        "8" { Add-ExternalSkill; Read-Host "Press Enter to continue" }
        "9" { Write-Host "Goodbye." -ForegroundColor Cyan; exit 0 }
        default { Write-Host "Invalid option." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}
