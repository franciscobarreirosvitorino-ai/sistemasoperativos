#!/usr/bin/env bash
# dolos.sh - all-in-one launcher for macOS / Linux (and WSL2) hosts.
# No dependencies beyond bash and Docker (both already required for DOLOS).
#
# With no arguments: shows an interactive menu - install/build, start, stop,
# restart, shell, change language, change keyboard, status, reset.
#
# With arguments: forwards them straight to `docker compose`, after
# exporting DOLOS_HOST_OS so docker-compose.yml picks the right default
# keyboard layout (PT-mac on macOS, PT elsewhere). For advanced use / CI.
#
# Usage:
#   ./dolos.sh                  # interactive menu
#   ./dolos.sh build            # same as: docker compose build
#   ./dolos.sh up -d
#   ./dolos.sh stop
#   ./dolos.sh restart
#   ./dolos.sh down

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR" || exit 1

CONTAINER_NAME="dolos"

case "$(uname -s)" in
    Darwin) DOLOS_HOST_OS="mac" ;;
    *)      DOLOS_HOST_OS="linux" ;;
esac
export DOLOS_HOST_OS

KBD_DEFAULT="pt"
[ "$DOLOS_HOST_OS" = "mac" ] && KBD_DEFAULT="pt-mac"
# Uppercased for display only. Avoids bash 4+ ${VAR^^} syntax, since macOS
# still ships bash 3.2 by default.
KBD_DEFAULT_UPPER="$(echo "$KBD_DEFAULT" | tr '[:lower:]' '[:upper:]')"

# --- advanced / passthrough mode: `./dolos.sh <docker compose args...>` ----
if [ "$#" -gt 0 ]; then
    echo "DOLOS: detected host OS -> ${DOLOS_HOST_OS} (default keyboard: ${KBD_DEFAULT_UPPER})" >&2
    exec docker compose "$@"
fi

# --- interactive menu -------------------------------------------------------

pause() {
    read -r -p "Press Enter to continue..." _
}

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "======================================================================"
        echo "Docker was not found on your PATH."
        echo "Install Docker Desktop first: https://www.docker.com/products/docker-desktop/"
        echo "======================================================================"
        pause
        return 1
    fi
    if ! docker info >/dev/null 2>&1; then
        echo "======================================================================"
        echo "Docker is installed but doesn't seem to be running."
        echo "Start Docker Desktop (or the Docker daemon) and try again."
        echo "======================================================================"
        pause
        return 1
    fi
    return 0
}

container_running() {
    docker ps --filter "name=^${CONTAINER_NAME}\$" --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}\$"
}

require_running() {
    if ! container_running; then
        echo "DOLOS isn't running. Start it first (option 2)."
        pause
        return 1
    fi
    return 0
}

action_build() {
    echo "Building the DOLOS image. This can take a few minutes the first time."
    if docker compose build; then
        pause
        return
    fi

    echo
    echo "docker compose build failed. This can happen due to a known Docker"
    echo "Desktop bug where BuildKit's credential resolution breaks internally"
    echo "even though plain 'docker pull'/'docker build' still work fine."
    echo "Falling back to a non-BuildKit build..."
    echo
    if DOCKER_BUILDKIT=0 docker build -t dolos:latest .; then
        echo
        echo "Fallback build succeeded. 'docker compose up' will reuse this"
        echo "local image without trying to build it again."
    else
        echo
        echo "Fallback build also failed - see the README's Troubleshooting"
        echo "section for how to fix Docker Desktop's credential helper."
    fi
    pause
}

action_start() {
    docker compose up -d
    echo
    echo "DOLOS started. Default keyboard layout: ${KBD_DEFAULT_UPPER} (detected host: ${DOLOS_HOST_OS})."
    pause
}

action_stop() {
    docker compose stop
    pause
}

action_restart() {
    docker compose restart
    pause
}

action_shell() {
    require_running || return
    docker exec -it -u aluno "$CONTAINER_NAME" bash
}

action_change_language() {
    require_running || return
    echo "Choose a language:"
    echo "  1) English (en)"
    echo "  2) Portugues de Portugal (pt)"
    echo "  3) Enter a custom locale (e.g. es_ES.UTF-8, fr_FR.UTF-8)"
    echo "  0) Cancel"
    read -r -p "> " choice
    case "$choice" in
        1) lang="en" ;;
        2) lang="pt" ;;
        3)
            read -r -p "Locale (e.g. es_ES.UTF-8): " lang
            if [ -z "$lang" ]; then
                echo "Cancelled."
                pause
                return
            fi
            ;;
        0) return ;;
        *) echo "Invalid choice."; pause; return ;;
    esac
    docker exec -it -u aluno "$CONTAINER_NAME" sudo dolos-lang "$lang"
    echo
    echo "Open a new shell in the container for the change to take effect."
    pause
}

action_change_keyboard() {
    require_running || return
    echo "Choose a keyboard layout:"
    echo "  1) Portuguese (PT)"
    echo "  2) Portuguese, Mac variant (PT-mac)"
    echo "  3) US"
    echo "  4) US, Mac variant (US-mac)"
    echo "  5) Enter a custom layout (e.g. de, fr:oss, es:mac)"
    echo "  0) Cancel"
    read -r -p "> " choice
    case "$choice" in
        1) layout="pt" ;;
        2) layout="pt-mac" ;;
        3) layout="us" ;;
        4) layout="us-mac" ;;
        5)
            read -r -p "Layout (e.g. de, or fr:oss for LAYOUT:VARIANT): " layout
            if [ -z "$layout" ]; then
                echo "Cancelled."
                pause
                return
            fi
            ;;
        0) return ;;
        *) echo "Invalid choice."; pause; return ;;
    esac
    docker exec -it -u aluno "$CONTAINER_NAME" sudo dolos-kbd "$layout"
    pause
}

action_status() {
    echo "Detected host OS: ${DOLOS_HOST_OS}  (default keyboard would be: ${KBD_DEFAULT_UPPER})"
    echo
    docker compose ps
    if container_running; then
        echo
        echo "${CONTAINER_NAME} is running. Current settings inside the container:"
        docker exec -it "$CONTAINER_NAME" dolos-lang --show
        docker exec -it "$CONTAINER_NAME" dolos-kbd --show
    else
        echo
        echo "${CONTAINER_NAME} is not running."
    fi
    pause
}

action_reset() {
    echo "This stops and removes the DOLOS container (settings inside it are"
    echo "lost; your ./workspace folder on the host is NOT touched)."
    read -r -p "Type 'yes' to confirm: " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Cancelled."
        pause
        return
    fi
    docker compose down

    read -r -p "Also remove the built image, forcing a full rebuild next time? [y/N] " also_image
    if [ "$also_image" = "y" ] || [ "$also_image" = "Y" ]; then
        docker rmi dolos:latest
    fi

    echo
    echo "Reset done. Use 'Start' to bring DOLOS back up (it will rebuild if needed)."
    pause
}

print_menu() {
    running="$1"
    echo
    echo "============================================"
    echo " DOLOS - DOckered Linux OS"
    echo " Host OS detected: ${DOLOS_HOST_OS}"
    if [ "$running" = "1" ]; then
        echo " Status: RUNNING"
    else
        echo " Status: stopped"
    fi
    echo "============================================"
    echo "  1) Install / build the DOLOS image"
    if [ "$running" = "1" ]; then
        echo "  2) Stop DOLOS"
    else
        echo "  2) Start DOLOS"
    fi
    echo "  3) Restart DOLOS"
    echo "  4) Open a shell inside DOLOS"
    echo "  5) Change language (English / Portugues / custom)"
    echo "  6) Change keyboard layout (PT / PT-mac / US / US-mac / custom)"
    echo "  7) Show status"
    echo "  8) Reset (remove the container)"
    echo "  0) Quit"
    echo "============================================"
}

check_docker || true

while true; do
    if container_running; then
        running=1
    else
        running=0
    fi
    print_menu "$running"
    read -r -p "Choose an option: " choice || { echo; echo "Bye!"; exit 0; }
    case "$choice" in
        1) action_build ;;
        2) if [ "$running" = "1" ]; then action_stop; else action_start; fi ;;
        3) action_restart ;;
        4) action_shell ;;
        5) action_change_language ;;
        6) action_change_keyboard ;;
        7) action_status ;;
        8) action_reset ;;
        0) echo "Bye!"; exit 0 ;;
        *) echo "Invalid choice." ;;
    esac
done
