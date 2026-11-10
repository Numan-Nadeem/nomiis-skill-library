$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

$SkillsDir = Join-Path $RepoRoot "skills"

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
    Write-Host "[1/1] Pulling your skills repository..." -ForegroundColor Yellow
    git pull --rebase
    if ($LASTEXITCODE -ne 0) {
        throw "Git pull failed."
    }
}

function Get-SkillDirectories {
    $skills = @()

    if (Test-Path $SkillsDir) {
        Get-ChildItem -Path $SkillsDir -Directory | ForEach-Object {
            $topLevel = $_
            $directSkillFile = Join-Path $topLevel.FullName "SKILL.md"

            if (Test-Path $directSkillFile) {
                # Flat layout: skills/<skill-name>/SKILL.md
                $relativePath = $topLevel.FullName.Substring($RepoRoot.Length).TrimStart('\')

                $skills += [PSCustomObject]@{
                    Name   = $topLevel.Name
                    Type   = "uncategorized"
                    Source = $relativePath
                    Path   = $topLevel.FullName
                }
            } else {
                # Categorized layout: skills/<category>/<skill-name>/SKILL.md
                Get-ChildItem -Path $topLevel.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                    $skillDirectory = $_.FullName
                    $skillFile = Join-Path $skillDirectory "SKILL.md"

                    if (Test-Path $skillFile) {
                        $relativePath = $skillDirectory.Substring($RepoRoot.Length).TrimStart('\')

                        $skills += [PSCustomObject]@{
                            Name   = $_.Name
                            Type   = $topLevel.Name
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

    npx skills add $RepoRoot -g
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
    $category = Read-Host "Category to place the skill(s) under (e.g. design)"

    if ([string]::IsNullOrWhiteSpace($url) -or [string]::IsNullOrWhiteSpace($category)) {
        Write-Host "Repository URL and category are required." -ForegroundColor Red
        return
    }

    if ($category -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        Write-Host "Category name may contain only letters, numbers, dots, underscores, and hyphens." -ForegroundColor Red
        return
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("skills-vendor-" + [System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    $cloneDir = Join-Path $tempRoot "repo"

    git clone --depth 1 $url $cloneDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to clone the repository." -ForegroundColor Red
        Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
        return
    }

    # Carry the upstream license/notice files into every vendored copy.
    $licenseFiles = @(Get-ChildItem -Path $cloneDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^(LICENSE|LICENCE|NOTICE)' })

    # Sort by path depth (shallowest first) then deduplicate by skill name.
    # This collapses multi-platform repos (e.g. impeccable) that ship the
    # same SKILL.md for every agent harness into a single entry each.
    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    $skillFiles = Get-ChildItem -Path $cloneDir -Filter "SKILL.md" -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/]\.git([\\/]|$)' } |
        Sort-Object { ($_.FullName -split [regex]::Escape([System.IO.Path]::DirectorySeparatorChar)).Count }

    foreach ($file in $skillFiles) {
        if (-not $seen.Add($file.Directory.Name)) {
            continue
        }

        $skillName = $file.Directory.Name
        $destination = Join-Path (Join-Path $SkillsDir $category) $skillName

        if (Test-Path $destination) {
            Write-Host "Skipped (already exists): $category/$skillName" -ForegroundColor Yellow
            continue
        }

        Copy-Item -Path $file.Directory.FullName -Destination $destination -Recurse
        foreach ($licenseFile in $licenseFiles) {
            Copy-Item -Path $licenseFile.FullName -Destination $destination
        }

        Write-Host "Vendored: $category/$skillName" -ForegroundColor Green
    }

    Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
    Write-Host ""
    Write-Host "Review the vendored skills, then commit the changes." -ForegroundColor Yellow
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
    Write-Host "8. Vendor an external skill from a Git repository"
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
