# dolos.ps1 - all-in-one launcher for Windows hosts (incl. Windows on ARM).
# No dependencies beyond PowerShell (built into every Windows install) and
# Docker Desktop (already required for DOLOS).
#
# With no arguments: shows an interactive menu - install/build, start, stop,
# restart, shell, change language, change keyboard, status, reset.
#
# With arguments: forwards them straight to `docker compose`, after setting
# DOLOS_HOST_OS so docker-compose.yml picks the right default keyboard
# layout (PT on Windows). For advanced use / CI.
#
# Usage:
#   .\dolos.ps1                  # interactive menu
#   .\dolos.ps1 build            # same as: docker compose build
#   .\dolos.ps1 up -d
#   .\dolos.ps1 stop
#   .\dolos.ps1 restart
#   .\dolos.ps1 down
#
# If running inside WSL2, prefer dolos.sh from a WSL bash prompt instead -
# it will correctly detect "linux" as the host from WSL's point of view.
#
# If PowerShell refuses to run this script ("running scripts is disabled"),
# run once from an elevated prompt:
#   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

Set-Location -Path $PSScriptRoot

$ContainerName = "dolos"
$env:DOLOS_HOST_OS = "windows"
$KbdDefault = "PT"

# --- advanced / passthrough mode: `.\dolos.ps1 <docker compose args...>` ---
if ($args.Count -gt 0) {
    Write-Host "DOLOS: detected host OS -> windows (default keyboard: $KbdDefault)"
    docker compose @args
    exit $LASTEXITCODE
}

# --- interactive menu -------------------------------------------------------

function Pause-DOLOS {
    Read-Host "Press Enter to continue" | Out-Null
}

function Test-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "======================================================================"
        Write-Host "Docker was not found on your PATH."
        Write-Host "Install Docker Desktop first: https://www.docker.com/products/docker-desktop/"
        Write-Host "======================================================================"
        Pause-DOLOS
        return $false
    }
    docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "======================================================================"
        Write-Host "Docker is installed but doesn't seem to be running."
        Write-Host "Start Docker Desktop and try again."
        Write-Host "======================================================================"
        Pause-DOLOS
        return $false
    }
    return $true
}

function Test-ContainerRunning {
    $names = docker ps --filter "name=^$ContainerName`$" --format '{{.Names}}' 2>$null
    return ($names -contains $ContainerName)
}

function Require-Running {
    if (-not (Test-ContainerRunning)) {
        Write-Host "DOLOS isn't running. Start it first (option 2)."
        Pause-DOLOS
        return $false
    }
    return $true
}

function Action-Build {
    Write-Host "Building the DOLOS image. This can take a few minutes the first time."
    docker compose build
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "docker compose build failed. This can happen due to a known Docker"
        Write-Host "Desktop bug where BuildKit's credential resolution breaks internally"
        Write-Host "even though plain 'docker pull'/'docker build' still work fine."
        Write-Host "Falling back to a non-BuildKit build..."
        Write-Host ""
        $env:DOCKER_BUILDKIT = "0"
        docker build -t dolos:latest .
        $fallbackExit = $LASTEXITCODE
        Remove-Item Env:\DOCKER_BUILDKIT -ErrorAction SilentlyContinue
        if ($fallbackExit -ne 0) {
            Write-Host ""
            Write-Host "Fallback build also failed - see the README's Troubleshooting"
            Write-Host "section for how to fix Docker Desktop's credential helper."
        } else {
            Write-Host ""
            Write-Host "Fallback build succeeded. 'docker compose up' will reuse this"
            Write-Host "local image without trying to build it again."
        }
    }
    Pause-DOLOS
}

function Action-Start {
    docker compose up -d
    Write-Host ""
    Write-Host "DOLOS started. Default keyboard layout: $KbdDefault (host: windows)."
    Pause-DOLOS
}

function Action-Stop {
    docker compose stop
    Pause-DOLOS
}

function Action-Restart {
    docker compose restart
    Pause-DOLOS
}

function Action-Shell {
    if (-not (Require-Running)) { return }
    docker exec -it -u aluno $ContainerName bash
}

function Action-ChangeLanguage {
    if (-not (Require-Running)) { return }
    Write-Host "Choose a language:"
    Write-Host "  1) English (en)"
    Write-Host "  2) Portugues de Portugal (pt)"
    Write-Host "  3) Enter a custom locale (e.g. es_ES.UTF-8, fr_FR.UTF-8)"
    Write-Host "  0) Cancel"
    $choice = Read-Host ">"
    switch ($choice) {
        "1" { $lang = "en" }
        "2" { $lang = "pt" }
        "3" {
            $lang = Read-Host "Locale (e.g. es_ES.UTF-8)"
            if ([string]::IsNullOrWhiteSpace($lang)) { Write-Host "Cancelled."; Pause-DOLOS; return }
        }
        "0" { return }
        default { Write-Host "Invalid choice."; Pause-DOLOS; return }
    }
    docker exec -it -u aluno $ContainerName sudo dolos-lang $lang
    Write-Host ""
    Write-Host "Open a new shell in the container for the change to take effect."
    Pause-DOLOS
}

function Action-ChangeKeyboard {
    if (-not (Require-Running)) { return }
    Write-Host "Choose a keyboard layout:"
    Write-Host "  1) Portuguese (PT)"
    Write-Host "  2) Portuguese, Mac variant (PT-mac)"
    Write-Host "  3) US"
    Write-Host "  4) US, Mac variant (US-mac)"
    Write-Host "  5) Enter a custom layout (e.g. de, fr:oss, es:mac)"
    Write-Host "  0) Cancel"
    $choice = Read-Host ">"
    switch ($choice) {
        "1" { $layout = "pt" }
        "2" { $layout = "pt-mac" }
        "3" { $layout = "us" }
        "4" { $layout = "us-mac" }
        "5" {
            $layout = Read-Host "Layout (e.g. de, or fr:oss for LAYOUT:VARIANT)"
            if ([string]::IsNullOrWhiteSpace($layout)) { Write-Host "Cancelled."; Pause-DOLOS; return }
        }
        "0" { return }
        default { Write-Host "Invalid choice."; Pause-DOLOS; return }
    }
    docker exec -it -u aluno $ContainerName sudo dolos-kbd $layout
    Pause-DOLOS
}

function Action-Status {
    Write-Host "Detected host OS: windows  (default keyboard would be: $KbdDefault)"
    Write-Host ""
    docker compose ps
    if (Test-ContainerRunning) {
        Write-Host ""
        Write-Host "$ContainerName is running. Current settings inside the container:"
        docker exec -it $ContainerName dolos-lang --show
        docker exec -it $ContainerName dolos-kbd --show
    } else {
        Write-Host ""
        Write-Host "$ContainerName is not running."
    }
    Pause-DOLOS
}

function Action-Reset {
    Write-Host "This stops and removes the DOLOS container (settings inside it are"
    Write-Host "lost; your .\workspace folder on the host is NOT touched)."
    $confirm = Read-Host "Type 'yes' to confirm"
    if ($confirm -ne "yes") {
        Write-Host "Cancelled."
        Pause-DOLOS
        return
    }
    docker compose down

    $alsoImage = Read-Host "Also remove the built image, forcing a full rebuild next time? [y/N]"
    if ($alsoImage -eq "y" -or $alsoImage -eq "Y") {
        docker rmi dolos:latest
    }

    Write-Host ""
    Write-Host "Reset done. Use 'Start' to bring DOLOS back up (it will rebuild if needed)."
    Pause-DOLOS
}

function Show-Menu {
    param([bool]$Running)
    Write-Host ""
    Write-Host "============================================"
    Write-Host " DOLOS - DOckered Linux OS"
    Write-Host " Host OS detected: windows"
    if ($Running) {
        Write-Host " Status: RUNNING"
    } else {
        Write-Host " Status: stopped"
    }
    Write-Host "============================================"
    Write-Host "  1) Install / build the DOLOS image"
    if ($Running) {
        Write-Host "  2) Stop DOLOS"
    } else {
        Write-Host "  2) Start DOLOS"
    }
    Write-Host "  3) Restart DOLOS"
    Write-Host "  4) Open a shell inside DOLOS"
    Write-Host "  5) Change language (English / Portugues / custom)"
    Write-Host "  6) Change keyboard layout (PT / PT-mac / US / US-mac / custom)"
    Write-Host "  7) Show status"
    Write-Host "  8) Reset (remove the container)"
    Write-Host "  0) Quit"
    Write-Host "============================================"
}

Test-Docker | Out-Null

while ($true) {
    $running = Test-ContainerRunning
    Show-Menu -Running $running
    $choice = Read-Host "Choose an option"
    switch ($choice) {
        "1" { Action-Build }
        "2" { if ($running) { Action-Stop } else { Action-Start } }
        "3" { Action-Restart }
        "4" { Action-Shell }
        "5" { Action-ChangeLanguage }
        "6" { Action-ChangeKeyboard }
        "7" { Action-Status }
        "8" { Action-Reset }
        "0" { Write-Host "Bye!"; exit 0 }
        default { Write-Host "Invalid choice." }
    }
}
