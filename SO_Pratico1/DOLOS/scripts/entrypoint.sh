#!/usr/bin/env bash
# DOLOS entrypoint.
# - Applies the default keyboard layout (PT, or PT-mac if the host is
#   macOS) based on the DOLOS_HOST_OS env var, unless the layout was
#   manually changed with dolos-kbd (see /etc/dolos/keyboard.manual).
# - Starts sshd in the background if DOLOS_SSH=1 (default: on), so CLion's
#   "SSH / Remote Host" toolchain works out of the box too.
# - Then execs whatever CMD was given (default: `sleep infinity`, which just
#   keeps the container alive for `docker exec` based workflows, e.g. CLion's
#   native Docker toolchain).

set -e

if [ ! -f /etc/dolos/keyboard.manual ]; then
    case "${DOLOS_HOST_OS:-linux}" in
        mac|macos|darwin|osx)
            DOLOS_KBD_AUTO=1 /usr/local/bin/dolos-kbd pt-mac || true
            ;;
        *)
            DOLOS_KBD_AUTO=1 /usr/local/bin/dolos-kbd pt || true
            ;;
    esac
fi

if [ "${DOLOS_SSH:-1}" = "1" ]; then
    service ssh start >/dev/null 2>&1 || /usr/sbin/sshd
fi

exec "$@"
