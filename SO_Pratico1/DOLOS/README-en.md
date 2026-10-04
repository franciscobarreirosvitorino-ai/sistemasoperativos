*[Ler em português](README.md)*

# DOLOS — DOckered Linux OS

A Debian-stable based Docker image for the Operating Systems course. You edit
code in CLion on your host machine; DOLOS provides the Linux environment
(compiler, cmake, gdb, valgrind, ...) that actually builds, runs, and debugs
it.

Works on Linux, Windows (Docker Desktop), macOS Intel, macOS Apple
Silicon, and Windows on ARM (via Docker Desktop's arm64/emulated support) —
the base image and every package installed are multi-arch. It's a console-
only image (no X11/Wayland) kept as small as practical.

## Contents

```
DOLOS/
├── README.md             # this guide, in Portuguese
├── README-en.md          # this guide, in English
├── Dockerfile
├── docker-compose.yml
├── dolos.sh              # all-in-one launcher + interactive menu
├── dolos.ps1             # all-in-one launcher + interactive menu
├── scripts/
│   ├── entrypoint.sh
│   ├── dolos-lang     # switch OS language
│   └── dolos-kbd      # switch keyboard layout
└── workspace/          # created on first run, shared with the container
```

Two scripts, one per platform — pick the one that matches your OS, don't run
the other one:

| Script       | Run on                              | Needs                                              |
|--------------|--------------------------------------|-----------------------------------------------------|
| `dolos.sh`   | **macOS, Linux, WSL2 only**          | bash (already present — nothing to install)         |
| `dolos.ps1`  | **Windows only**                     | PowerShell (built into every Windows install)       |

`dolos.ps1` is Windows PowerShell and will **not** run on macOS/Linux (no
`pwsh` there by default). `dolos.sh` is bash and will **not** run natively in
Windows PowerShell or Command Prompt — under WSL2 it works fine, since WSL is
Linux. Neither script needs anything installed beyond Docker itself, which
you need either way.

## What's inside

Debian stable-slim, plus `build-essential`, `git`, `rsync`, `htop`, `procps`
(`ps`, `top`, `kill`, ...), `less`, and `cmake` / `gdb` / `valgrind`
(including its default Memcheck tool) all installed from the
`trixie-backports` suite rather than Debian stable's own packages, since
backports tracks noticeably newer upstream releases of all three —
backports is added just for these and pinned so nothing else in the image
comes from it.
`vim`/`nano`, `wget`/`curl`, `sed`, `coreutils`, `diffutils`, `file`,
`gettext-base`, `sudo`, `openssh-server`, and console-only locale/keyboard
tooling (no X11/Wayland packages — this is a headless dev environment).

Single user account: `aluno` / password `aluno`, with sudo access (password
required — `aluno`'s own password).

## 1. The easy way — interactive menu

DOLOS ships with two scripts, `dolos.sh` (macOS/Linux/WSL2) and `dolos.ps1`
(Windows) — pick the one for your OS, nothing to install beyond Docker
itself. Run it with no arguments and you get a numbered menu that adapts to
whether DOLOS is currently running — option 2 shows "Start DOLOS" when it's
stopped, or "Stop DOLOS" when it's running:

```
1) Install / build the DOLOS image
2) Start DOLOS  (shows "Stop DOLOS" instead if it's already running)
3) Restart DOLOS
4) Open a shell inside DOLOS
5) Change language (English / Portugues)
6) Change keyboard layout (PT / PT-mac / US / US-mac)
7) Show status
8) Reset (remove the container)
0) Quit
```

```bash
# macOS / Linux / WSL2
chmod +x dolos.sh   # one-time
./dolos.sh
```

```powershell
# Windows, PowerShell (built in — nothing to install)
powershell -ExecutionPolicy Bypass -File .\dolos.ps1
```

The `-ExecutionPolicy Bypass` flag lets this one script run even if Windows'
default execution policy would otherwise block it ("running scripts is
disabled on this system") — it only applies to this single invocation, not
to your system-wide PowerShell settings.

This is the recommended path for students — first run "Install / build",
then "Start", and use the menu for everything else day to day.

### Using Docker Desktop's GUI (optional)

If you have Docker Desktop installed, you can also see and manage DOLOS from
its graphical interface instead of (or alongside) the menu script:

- **Containers tab**: after building/starting once via the menu, DOLOS shows
  up here as a container named `dolos`. From here you can start ▶, stop ⏹,
  restart, or delete it with a click — the same actions as menu options 2/3/8.
- **Terminal tab** (inside the `dolos` container's detail view): gives you a
  shell inside the container without typing any `docker exec` command. Note
  it opens as `root` by default, not as `aluno` — for the exact `aluno`
  environment CLion and the menu use, prefer menu option 4 (or
  `docker exec -it -u aluno dolos bash`) instead.
- **Logs tab**: shows `entrypoint.sh`'s output (sshd starting, keyboard/
  language setup, etc.) — useful if something looks stuck.
- **Images tab**: after "Install / build" (menu option 1), the built image
  appears here as `dolos:latest`.
- **Files tab**: lets you browse the container's filesystem directly, handy
  for peeking at `/etc/dolos/keyboard.manual` or `/etc/default/keyboard`
  without opening a shell.

None of this is required — the menu script and CLion toolchains cover
everything on their own — but it's a convenient way to glance at status or
grab logs without leaving the GUI. No Docker Hub account or sign-in is
needed for any of this, since DOLOS only uses local/public images.

## 2. Using DOLOS from CLion

DOLOS is set up to work with either of CLion's remote toolchains — pick
whichever your course/setup prefers. Both talk to the same running `dolos`
container, so you can even switch between them without changing the image.

### Option A — Docker Toolchain (no SSH, talks to the engine directly)

1. `Settings/Preferences → Build, Execution, Deployment → Toolchains`
2. Click `+` → **Docker**
3. Image: pick `dolos:latest` (or point it at the `Dockerfile`/`docker-compose.yml`
   so CLion builds it for you). Container: reuse the existing `dolos` container
   if you started it via `docker compose up -d`.
4. CLion auto-detects CMake, Make, GDB inside the container — verify the
   CMake path resolves (`/usr/bin/cmake`) and that GDB is found.
5. In `Settings → Build, Execution, Deployment → CMake`, select a profile
   using this toolchain.

CLion syncs your project source into the container automatically for the
Docker toolchain (no need to rely on the `workspace` bind mount for that),
but the mount is still handy for sharing extra data files, datasets, or
scripts between host and container.

### Option B — SSH / Remote Host Toolchain

sshd runs inside DOLOS by default and is published on the host at
`localhost:2222` (see `docker-compose.yml` / the `-p 2222:22` flag above).

1. `Settings/Preferences → Build, Execution, Deployment → Toolchains`
2. Click `+` → **SSH**
3. Host: `localhost`, Port: `2222`, User: `aluno`, Password: `aluno` (or add
   an SSH key to `/home/aluno/.ssh/authorized_keys` in the container for
   key-based login).
4. CLion will deploy/sync your project over SSH/SFTP and auto-detect CMake,
   Make/Ninja, and GDB the same way as the Docker toolchain.
5. In `Settings → Build, Execution, Deployment → CMake`, select a profile
   using this toolchain.

If you run multiple students/containers, give each one a different host port
(e.g. `2223:22`, `2224:22`, ...) in `docker-compose.yml`.

### Valgrind (either option)

CLion doesn't have first-class Valgrind integration for remote toolchains as
reliably as it does for local ones, so the simplest path is a terminal:
`Alt+F12` in CLion, or `docker exec -it -u aluno dolos bash` /
`ssh -p 2222 aluno@localhost`, then run `valgrind ./your_binary` directly —
this is also how the course typically expects Valgrind to be used.

`sudo` requires `aluno`'s password (`aluno`) — it's not passwordless, so run
these as `aluno` with an interactive terminal (`-it`) so sudo can prompt.

## 3. Changing language

Easiest: menu option 5 in `dolos.sh` / `dolos.ps1` — presents English,
Portugues, or "enter a custom locale" (e.g. `es_ES.UTF-8`, `fr_FR.UTF-8`,
`de_DE.UTF-8`). Custom locales are generated on the fly if not already
present in the image.

Directly:

```bash
docker exec -it -u aluno dolos sudo dolos-lang en             # English (default)
docker exec -it -u aluno dolos sudo dolos-lang pt             # Portugues de Portugal
docker exec -it -u aluno dolos sudo dolos-lang es_ES.UTF-8     # any other locale
docker exec -it dolos dolos-lang --show                        # check current setting (no sudo needed)
```

Or from inside a shell in the container: `sudo dolos-lang pt` (enter the
`aluno` password when prompted). Open a new shell afterwards for the change
to apply.

## 4. Changing keyboard layout

Default on every start: **PT** (or **PT-mac** if launched via `dolos.sh` on a
macOS host — see the Annex). Easiest way to change it: menu option 6 in
`dolos.sh` / `dolos.ps1` — presents PT, PT-mac, US, US-mac, or "enter a
custom layout" (any XKB layout code, e.g. `de`, or `LAYOUT:VARIANT` like
`fr:oss`).

Directly:

```bash
docker exec -it -u aluno dolos sudo dolos-kbd pt        # Portuguese (default)
docker exec -it -u aluno dolos sudo dolos-kbd pt-mac    # Portuguese, Mac layout
docker exec -it -u aluno dolos sudo dolos-kbd us        # US
docker exec -it -u aluno dolos sudo dolos-kbd us-mac    # US, Mac layout
docker exec -it -u aluno dolos sudo dolos-kbd de        # any other XKB layout code
docker exec -it -u aluno dolos sudo dolos-kbd fr:oss    # LAYOUT:VARIANT form
docker exec -it dolos dolos-kbd --show                  # check current setting (no sudo needed)
```

Once you set it manually, DOLOS remembers your choice (via
`/etc/dolos/keyboard.manual`) and won't overwrite it with the host-detected
default on later restarts. To go back to auto-detection, delete that marker:
`docker exec -it -u aluno dolos sudo rm /etc/dolos/keyboard.manual`.

Note: DOLOS is console-only (no X11/Wayland by design, to keep the image
small), so keyboard layout here only matters for a virtual console session
inside the container. If you're using CLion's integrated terminal or
`docker exec`, the keyboard layout that actually applies to what you type is
your **host OS's** layout — `dolos-kbd` is provided for completeness and for
any in-class exercises that work directly at a console inside DOLOS.

## Platform notes

- **macOS (Intel/Apple Silicon) and Linux**: works directly with Docker
  Desktop / Docker Engine, no changes needed.
- **Windows**: install Docker Desktop and let it use its default backend.
  WSL2 is **not a hard requirement** — Docker Desktop's default (per-user,
  no-admin) install only offers the WSL2 backend, but an all-users install on
  Windows Pro/Enterprise/Education can instead use the Hyper-V backend, no
  WSL involved. Either way DOLOS itself doesn't care which backend Docker
  uses — it's invisible to the container. Windows on ARM only supports the
  WSL2 backend.
- **Windows on ARM**: Docker Desktop supports arm64 natively on recent
  builds; if your engine can't pull an arm64 Debian image directly, enable
  QEMU emulation (Docker Desktop does this automatically when needed) — the
  image will still build and run, just slightly slower under emulation.

## Troubleshooting

**`error getting credentials - err: exec: "docker-credential-desktop": executable file not found in $PATH`**,
**`error listing credentials - err: exit status 1, out: ``` `**, or similar,
mentioning `docker-credential-...`, when running "Install / build" or
`docker compose build` — this is not a DOLOS problem, it's a known Docker
Desktop bug where BuildKit's credential resolution (used by `docker build`
and `docker compose build`) breaks internally, even though plain image pulls
still work fine. Confirm the pattern with:
```bash
docker pull debian:stable-slim              # this usually still works
DOCKER_BUILDKIT=0 docker build -t dolos:latest .   # and this too (BuildKit disabled)
docker compose build                        # but this fails with a credentials error
```
If that's what you're seeing, **the menu's "Install / build" option already
handles this automatically** — if `docker compose build` fails, it falls
back to a non-BuildKit `docker build -t dolos:latest .`, and `docker compose
up` will then reuse that local image instead of trying (and failing) to
build it again. So if the automatic fallback also reports success, you're
unblocked and can just carry on using the menu normally — the "why" is a bug
in Docker Desktop's BuildKit/buildx credential vault, not something wrong
with the DOLOS files.

If you'd rather fix Docker Desktop itself instead of relying on the
fallback: `docker logout` is worth a quick, low-risk try, though it does not
reliably fix this particular bug. The more thorough fix is Docker Desktop →
Troubleshoot → "Clean / Purge data", which resets its internal state — but
this also removes your existing containers and images, so only do it if
you're fine losing those.

Separately, on Windows/Linux, the same error can also mean the credential
helper binary is simply missing from `PATH` (rather than crashing) — on
Windows check `C:\Program Files\Docker\Docker\resources\bin` is on `PATH`
(a repair install fixes this if missing); on Linux, check wherever Docker
Desktop installed its credential helpers is on `PATH`.

**"Docker is installed but doesn't seem to be running"** (from the menu) —
start Docker Desktop (or the Docker daemon on Linux) and try again. The menu
scripts check `docker info` before doing anything else.

**Permission denied talking to the Docker daemon (Linux, no Docker
Desktop)** — your user isn't in the `docker` group yet. Run
`sudo usermod -aG docker $USER`, then log out and back in (or reboot).

## Annex: The direct way — docker compose / plain docker

Everything below is for reference / advanced use — students should normally
just use the menu (section 1). If you'd rather run things by hand (or from a
script), the same `dolos.sh` / `dolos.ps1` scripts also forward arguments
straight to `docker compose` when you pass any — they just set
`DOLOS_HOST_OS` first so the default keyboard layout comes out right
(**PT-mac** on macOS, **PT** everywhere else):

```bash
./dolos.sh build          # macOS/Linux — same as: docker compose build
./dolos.sh up -d          # start (detached) — creates ./workspace on host
./dolos.sh stop           # stop, keep the container
./dolos.sh start          # start it again
./dolos.sh restart        # restart
./dolos.sh down           # stop and remove the container (image stays)
```

```powershell
powershell -ExecutionPolicy Bypass -File .\dolos.ps1 up -d
powershell -ExecutionPolicy Bypass -File .\dolos.ps1 stop
```

If you run `docker compose ...` directly instead of a wrapper, `DOLOS_HOST_OS`
defaults to `linux` (i.e. plain PT, no mac variant) — fine for Linux/Windows
hosts, but on macOS you'd want to export it yourself first:
`DOLOS_HOST_OS=mac docker compose up -d`.

Without compose at all:

```bash
docker build -t dolos:latest .
docker run -d --name dolos --hostname dolos \
  -p 2222:22 \
  -e DOLOS_HOST_OS=linux \
  -v "$(pwd)/workspace:/home/aluno/workspace" \
  --cap-add SYS_PTRACE --security-opt seccomp=unconfined \
  dolos:latest
docker stop dolos
docker start dolos
docker restart dolos
docker rm -f dolos
```

(set `-e DOLOS_HOST_OS=mac` if the host is macOS)

`--cap-add SYS_PTRACE` and the seccomp override are needed for `gdb` and
`valgrind` to attach to processes inside the container. The first build
takes a few minutes (installing packages, plus cmake/gdb/valgrind from
trixie-backports); rebuild whenever you change the Dockerfile.

Open a shell inside the running container:

```bash
docker exec -it -u aluno dolos bash
```
