# =============================================================================
# DOLOS — DOckered Linux OS
# A Debian-stable-based development/teaching image for an Operating Systems
# course. Meant to be driven from the host via CLion's Docker or SSH/Remote
# Host toolchain, so the container just needs to stay alive and offer a full
# build/debug toolchain inside. Console-only (no X11/Wayland) and kept as
# small as practical — this is a CLI dev environment, not a desktop.
#
# Build for the platform you're on; Debian's base image is multi-arch
# (amd64, arm64/v8), so this works unmodified on:
#   - Linux x86_64
#   - Windows x86_64 (Docker Desktop + WSL2)
#   - macOS Intel
#   - macOS Apple Silicon (M1/M2/M3/...)
#   - Windows on ARM (Docker Desktop, experimental but works via the arm64
#     image / QEMU emulation if a native arm64 engine isn't available)
# =============================================================================

FROM debian:stable-slim

LABEL maintainer="OS classes"
LABEL description="DOLOS - DOckered Linux OS - teaching image for Operating Systems course"

ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=${DEBIAN_FRONTEND} \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# -----------------------------------------------------------------------------
# 1. Base packages — deliberately minimal, console-only (no X11/Wayland),
#    but with the everyday Unix utilities a student/instructor will reach
#    for constantly:
#    - build-essential: full C/C++ build toolchain (cmake, gdb, and valgrind
#      itself all come from trixie-backports in section 2, not this apt call)
#    - git, rsync, wget, curl: fetch/sync code (CLion also rsyncs sources in)
#    - htop, procps (ps/top/kill/...), less, vi/vim/nano, sed, coreutils,
#      diffutils, file, gettext-base: general Unix/OS-course utilities
#    - sudo: aluno needs to escalate for apt / system experiments
#    - locales, console-setup, keyboard-configuration, kbd: language +
#      (virtual-console-only) keyboard layout switching — no X11 keyboard
#      utilities are installed since there's no GUI in this image
#    - openssh-server: for CLion's SSH / Remote Host toolchain
#    - ca-certificates: needed for apt/curl HTTPS
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        rsync \
        htop \
        procps \
        less \
        vim \
        nano \
        wget \
        curl \
        sed \
        coreutils \
        diffutils \
        file \
        gettext-base \
        sudo \
        locales \
        console-setup \
        keyboard-configuration \
        kbd \
        openssh-server \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 2. CMake, GDB, Valgrind — installed from trixie-backports rather than
#    trixie stable, since the backported packages track much more current
#    upstream releases than the versions in the stable suite:
#      - cmake: 4.x in backports vs. Debian stable's older 3.x
#      - gdb: a current GDB release vs. Debian stable's older packaged one
#      - valgrind: includes Memcheck (its default tool, always bundled in
#        the same package — there's no separate "memcheck" package to
#        install) plus Helgrind, Cachegrind, Massif, etc.
#    Using apt (instead of downloading/building from source) keeps the
#    Dockerfile simple and the build fast. The backports suite is added
#    just for these three packages and pinned via `-t trixie-backports` so
#    nothing else in the image is accidentally pulled from it.
# -----------------------------------------------------------------------------
RUN set -eux; \
    echo "deb http://deb.debian.org/debian trixie-backports main" \
        > /etc/apt/sources.list.d/trixie-backports.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends -t trixie-backports \
        cmake gdb valgrind; \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 3. Locales — generate English (US) and Portuguese (Portugal) locales so
#    the language can be switched at runtime without rebuilding the image.
# -----------------------------------------------------------------------------
RUN sed -i \
        -e 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' \
        -e 's/^# *pt_PT.UTF-8 UTF-8/pt_PT.UTF-8 UTF-8/' \
        /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

# -----------------------------------------------------------------------------
# 4. SSH server config — started by entrypoint.sh at container startup
#    (DOLOS_SSH=1 by default) so CLion's SSH / Remote Host toolchain works,
#    alongside the Docker toolchain which doesn't need this at all.
# -----------------------------------------------------------------------------
RUN mkdir -p /var/run/sshd \
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# -----------------------------------------------------------------------------
# 5. User setup — single account "aluno" (Portuguese for "student"),
#    password "aluno", member of sudo group.
# -----------------------------------------------------------------------------
RUN useradd -m -s /bin/bash -G sudo aluno \
    && echo "aluno:aluno" | chpasswd \
    && echo "aluno ALL=(ALL:ALL) ALL" > /etc/sudoers.d/aluno \
    && chmod 0440 /etc/sudoers.d/aluno

# -----------------------------------------------------------------------------
# 6. DOLOS helper scripts (language / keyboard switching)
# -----------------------------------------------------------------------------
COPY scripts/dolos-lang /usr/local/bin/dolos-lang
COPY scripts/dolos-kbd /usr/local/bin/dolos-kbd
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/dolos-lang /usr/local/bin/dolos-kbd /usr/local/bin/entrypoint.sh

# Default keyboard baked into the image: PT layout, English language.
# At container startup, entrypoint.sh re-applies the default based on the
# detected host OS (PT-mac on macOS hosts, PT otherwise) unless a user has
# manually changed it with dolos-kbd — see entrypoint.sh / scripts/dolos-kbd.
RUN DOLOS_KBD_AUTO=1 /usr/local/bin/dolos-kbd pt || true

WORKDIR /home/aluno
EXPOSE 22

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
