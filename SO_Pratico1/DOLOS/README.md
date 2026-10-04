*[Read in English](README-en.md)*

# DOLOS — DOckered Linux OS

Uma imagem Docker baseada no Debian stable para a disciplina de Sistemas
Operativos. O código é editado no CLion, na máquina anfitriã (host); o DOLOS
fornece o ambiente Linux (compilador, cmake, gdb, valgrind, ...) onde esse
código é de facto compilado, executado e depurado.

Funciona em Linux, Windows (Docker Desktop), macOS Intel, macOS Apple
Silicon, e Windows em ARM (através do suporte arm64/emulado do Docker
Desktop) — a imagem base e todos os pacotes instalados são multi-arquitetura.
É uma imagem apenas de consola (sem X11/Wayland), mantida o mais pequena
possível.

## Conteúdo

```
DOLOS/
├── README.md             # este guia, em português
├── README-en.md          # este guia, em inglês
├── Dockerfile
├── docker-compose.yml
├── dolos.sh              # lançador tudo-em-um + menu interativo
├── dolos.ps1             # lançador tudo-em-um + menu interativo
├── scripts/
│   ├── entrypoint.sh
│   ├── dolos-lang     # mudar o idioma do SO
│   └── dolos-kbd      # mudar o layout de teclado
└── workspace/          # criada no primeiro arranque, partilhada com o contentor
```

Dois scripts, um por plataforma — use o que corresponde ao seu sistema
operativo, não execute o outro:

| Script       | Executar em                          | Precisa de                                          |
|--------------|---------------------------------------|-------------------------------------------------------|
| `dolos.sh`   | **apenas macOS, Linux, WSL2**         | bash (já presente — nada a instalar)                   |
| `dolos.ps1`  | **apenas Windows**                    | PowerShell (incluído em qualquer instalação Windows)   |

O `dolos.ps1` é PowerShell do Windows e **não** funciona em macOS/Linux (não
há `pwsh` por defeito nesses sistemas). O `dolos.sh` é bash e **não** funciona
nativamente na PowerShell do Windows nem na Command Prompt — em WSL2 funciona
sem problemas, uma vez que o WSL é Linux. Nenhum dos dois scripts precisa de
nada instalado além do próprio Docker, que é necessário de qualquer forma.

## O que vem incluído

Debian stable-slim, mais `build-essential`, `git`, `rsync`, `htop`, `procps`
(`ps`, `top`, `kill`, ...), `less`, e `cmake` / `gdb` / `valgrind` (incluindo
a ferramenta Memcheck, incluída por defeito) instalados a partir do
repositório `trixie-backports` em vez dos pacotes do Debian stable, já que o
backports disponibiliza versões visivelmente mais recentes destes três —
o backports é adicionado só para estes pacotes e fixado para que nada mais
na imagem venha de lá.

`vim`/`nano`, `wget`/`curl`, `sed`, `coreutils`, `diffutils`, `file`,
`gettext-base`, `sudo`, `openssh-server`, e ferramentas de idioma/teclado
apenas de consola (sem pacotes X11/Wayland — este é um ambiente de
desenvolvimento sem interface gráfica). Uma única conta de utilizador:
`aluno` / palavra-passe `aluno`, com acesso sudo (com pedido de palavra-passe
— a própria palavra-passe do `aluno`).

## 1. O modo fácil — menu interativo

O DOLOS vem com dois scripts, `dolos.sh` (macOS/Linux/WSL2) e `dolos.ps1`
(Windows) — escolha o do seu sistema operativo, nada a instalar além do
próprio Docker. Ao executar sem argumentos obtém um menu numerado que se
adapta consoante o DOLOS esteja ou não em execução — a opção 2 mostra
"Start DOLOS" quando está parado, ou "Stop DOLOS" quando está em execução:

```
1) Install / build the DOLOS image
2) Start DOLOS  (mostra "Stop DOLOS" em vez disso, se já estiver em execução)
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
chmod +x dolos.sh   # uma única vez
./dolos.sh
```

```powershell
# Windows, PowerShell (já incluído — nada a instalar)
powershell -ExecutionPolicy Bypass -File .\dolos.ps1
```

A flag `-ExecutionPolicy Bypass` permite executar este script mesmo que a
política de execução do Windows o bloqueasse por defeito ("running scripts
is disabled on this system") — aplica-se apenas a esta execução, não altera
as definições do PowerShell a nível do sistema.

Este é o caminho recomendado para os alunos — primeiro execute "Install /
build", depois "Start", e use o menu para tudo o resto no dia a dia.

### Usar a interface gráfica do Docker Desktop (opcional)

Se tiver o Docker Desktop instalado, também pode ver e gerir o DOLOS a
partir da sua interface gráfica, em vez de (ou juntamente com) o script de
menu:

- **Separador Containers**: depois de construir/iniciar uma vez através do
  menu, o DOLOS aparece aqui como um contentor chamado `dolos`. A partir
  daqui pode iniciar ▶, parar ⏹, reiniciar, ou remover com um clique — as
  mesmas ações das opções 2/3/8 do menu.
- **Separador Terminal** (dentro da vista de detalhe do contentor `dolos`):
  dá-lhe uma shell dentro do contentor sem escrever nenhum comando
  `docker exec`. Note que abre como `root` por defeito, não como `aluno` —
  para o ambiente exato do `aluno` que o CLion e o menu usam, prefira a
  opção 4 do menu (ou `docker exec -it -u aluno dolos bash`).
- **Separador Logs**: mostra o output do `entrypoint.sh` (arranque do sshd,
  configuração de idioma/teclado, etc.) — útil se algo parecer bloqueado.
- **Separador Images**: depois de "Install / build" (opção 1 do menu), a
  imagem construída aparece aqui como `dolos:latest`.
- **Separador Files**: permite navegar diretamente no sistema de ficheiros
  do contentor, útil para espreitar `/etc/dolos/keyboard.manual` ou
  `/etc/default/keyboard` sem abrir uma shell.

Nada disto é obrigatório — o script de menu e as toolchains do CLion cobrem
tudo por si só — mas é uma forma conveniente de ver o estado ou obter logs
sem sair da interface gráfica. Não é necessária nenhuma conta Docker Hub nem
sessão iniciada para nada disto, uma vez que o DOLOS só usa imagens
públicas/locais.

## 2. Usar o DOLOS a partir do CLion

O DOLOS está preparado para funcionar com qualquer uma das toolchains
remotas do CLion — escolha a que preferir para a disciplina/configuração.
Ambas comunicam com o mesmo contentor `dolos` em execução, pelo que é
possível alternar entre elas sem alterar a imagem.

### Opção A — Docker Toolchain (sem SSH, comunica diretamente com o motor Docker)

1. `Settings/Preferences → Build, Execution, Deployment → Toolchains`
2. Clicar em `+` → **Docker**
3. Imagem: escolher `dolos:latest` (ou apontar para o `Dockerfile`/
   `docker-compose.yml` para o CLion construir a imagem). Contentor:
   reutilizar o contentor `dolos` existente, se já tiver sido iniciado com
   `docker compose up -d`.
4. O CLion deteta automaticamente o CMake, o Make e o GDB dentro do
   contentor — confirme que o caminho do CMake resolve corretamente
   (`/usr/bin/cmake`) e que o GDB é encontrado.
5. Em `Settings → Build, Execution, Deployment → CMake`, selecione um
   perfil que use esta toolchain.

O CLion sincroniza automaticamente o código do projeto para dentro do
contentor quando se usa a Docker Toolchain (não é necessário depender do
bind mount `workspace` para isso), mas essa pasta continua a ser útil para
partilhar dados extra, datasets ou scripts entre o anfitrião e o contentor.

### Opção B — SSH / Remote Host Toolchain

O sshd é executado dentro do DOLOS por defeito e está exposto no anfitrião
em `localhost:2222` (ver `docker-compose.yml` / a flag `-p 2222:22` acima).

1. `Settings/Preferences → Build, Execution, Deployment → Toolchains`
2. Clicar em `+` → **SSH**
3. Host: `localhost`, Porta: `2222`, Utilizador: `aluno`, Palavra-passe:
   `aluno` (ou adicionar uma chave SSH a
   `/home/aluno/.ssh/authorized_keys` dentro do contentor para autenticação
   por chave).
4. O CLion faz deploy/sincronização do projeto via SSH/SFTP e deteta
   automaticamente o CMake, o Make/Ninja e o GDB, tal como na Docker
   Toolchain.
5. Em `Settings → Build, Execution, Deployment → CMake`, selecione um
   perfil que use esta toolchain.

Se estiver a correr vários contentores para vários alunos, atribua uma porta
diferente do anfitrião a cada um (por exemplo `2223:22`, `2224:22`, ...) em
`docker-compose.yml`.

### Valgrind (qualquer uma das opções)

O CLion não tem uma integração de primeira qualidade com o Valgrind para
toolchains remotas, tão fiável como tem para toolchains locais, pelo que o
caminho mais simples é usar um terminal: `Alt+F12` no CLion, ou
`docker exec -it -u aluno dolos bash` / `ssh -p 2222 aluno@localhost`, e
depois correr `valgrind ./o_seu_binario` diretamente — é também assim que a
disciplina normalmente espera que o Valgrind seja usado.

O `sudo` pede a palavra-passe do `aluno` (`aluno`) — não é passwordless,
pelo que estes comandos devem ser corridos como `aluno` com um terminal
interativo (`-it`) para que o sudo consiga pedir a palavra-passe.

## 3. Mudar o idioma

Mais fácil: opção 5 do menu em `dolos.sh` / `dolos.ps1` — apresenta Inglês,
Português, ou "introduzir um locale personalizado" (por exemplo
`es_ES.UTF-8`, `fr_FR.UTF-8`, `de_DE.UTF-8`). Locales personalizados são
gerados na hora, caso ainda não existam na imagem.

Diretamente:

```bash
docker exec -it -u aluno dolos sudo dolos-lang en             # Inglês (por defeito)
docker exec -it -u aluno dolos sudo dolos-lang pt             # Português de Portugal
docker exec -it -u aluno dolos sudo dolos-lang es_ES.UTF-8     # qualquer outro locale
docker exec -it dolos dolos-lang --show                        # ver a configuração atual (não precisa de sudo)
```

Ou a partir de uma shell dentro do contentor: `sudo dolos-lang pt` (introduza
a palavra-passe do `aluno` quando pedida). Abra uma nova shell depois para a
alteração ter efeito.

## 4. Mudar o layout de teclado

Por defeito, em cada arranque: **PT** (ou **PT-mac** se lançado via
`dolos.sh` num anfitrião macOS — ver o Anexo). Forma mais fácil de o mudar:
opção 6 do menu em `dolos.sh` / `dolos.ps1` — apresenta PT, PT-mac, US,
US-mac, ou "introduzir um layout personalizado" (qualquer código de layout
XKB, por exemplo `de`, ou no formato `LAYOUT:VARIANTE` como `fr:oss`).

Diretamente:

```bash
docker exec -it -u aluno dolos sudo dolos-kbd pt        # Português (por defeito)
docker exec -it -u aluno dolos sudo dolos-kbd pt-mac    # Português, variante Mac
docker exec -it -u aluno dolos sudo dolos-kbd us        # US
docker exec -it -u aluno dolos sudo dolos-kbd us-mac    # US, variante Mac
docker exec -it -u aluno dolos sudo dolos-kbd de        # qualquer outro código de layout XKB
docker exec -it -u aluno dolos sudo dolos-kbd fr:oss    # formato LAYOUT:VARIANTE
docker exec -it dolos dolos-kbd --show                  # ver a configuração atual (não precisa de sudo)
```

Depois de o mudar manualmente, o DOLOS lembra-se da escolha (através do
ficheiro `/etc/dolos/keyboard.manual`) e não a substitui pelo valor
predefinido detetado pelo anfitrião em arranques seguintes. Para voltar à
deteção automática, apague esse marcador:
`docker exec -it -u aluno dolos sudo rm /etc/dolos/keyboard.manual`.

Nota: o DOLOS é apenas de consola (sem X11/Wayland, por decisão de design,
para manter a imagem pequena), pelo que o layout de teclado aqui só importa
para uma sessão de consola virtual dentro do contentor. Se estiver a usar o
terminal integrado do CLion ou o `docker exec`, o layout de teclado que
realmente se aplica ao que escreve é o do **sistema operativo anfitrião** —
o `dolos-kbd` é fornecido por completude e para exercícios de aula que
trabalhem diretamente numa consola dentro do DOLOS.

## Notas de plataforma

- **macOS (Intel/Apple Silicon) e Linux**: funciona diretamente com o
  Docker Desktop / Docker Engine, sem alterações necessárias.
- **Windows**: instale o Docker Desktop e deixe-o usar o backend por
  defeito. O WSL2 **não é um requisito obrigatório** — a instalação por
  defeito do Docker Desktop (por utilizador, sem privilégios de
  administrador) só oferece o backend WSL2, mas uma instalação para todos
  os utilizadores em Windows Pro/Enterprise/Education pode usar o backend
  Hyper-V, sem envolver o WSL. De qualquer forma, o DOLOS em si não se
  importa com o backend que o Docker usa — é invisível para o contentor. O
  Windows em ARM só suporta o backend WSL2.
- **Windows em ARM**: o Docker Desktop suporta arm64 nativamente nas
  versões recentes; se o seu motor não conseguir obter diretamente uma
  imagem Debian arm64, ative a emulação QEMU (o Docker Desktop faz isto
  automaticamente quando necessário) — a imagem continua a construir e a
  funcionar, apenas um pouco mais lenta sob emulação.

## Resolução de problemas

**`error getting credentials - err: exec: "docker-credential-desktop": executable file not found in $PATH`**,
**`error listing credentials - err: exit status 1, out: ``` `**, ou
semelhante, mencionando `docker-credential-...`, ao executar "Install /
build" ou `docker compose build` — isto não é um problema do DOLOS, é um bug
conhecido do Docker Desktop em que a resolução de credenciais do BuildKit
(usada pelo `docker build` e pelo `docker compose build`) avaria
internamente, mesmo quando obter imagens normalmente continua a funcionar.
Confirme o padrão com:
```bash
docker pull debian:stable-slim              # isto costuma continuar a funcionar
DOCKER_BUILDKIT=0 docker build -t dolos:latest .   # e isto também (BuildKit desativado)
docker compose build                        # mas isto falha com um erro de credenciais
```
Se for este o caso, **a opção "Install / build" do menu já trata disto
automaticamente** — se o `docker compose build` falhar, o script recorre a
um `docker build -t dolos:latest .` sem BuildKit, e o `docker compose up`
passa depois a reutilizar essa imagem local em vez de tentar (e falhar)
construí-la de novo. Portanto, se o fallback automático também reportar
sucesso, está desbloqueado e pode continuar a usar o menu normalmente — a
causa é um bug no cofre de credenciais do BuildKit/buildx do Docker Desktop,
não algo errado nos ficheiros do DOLOS.

Se preferir corrigir o Docker Desktop em vez de depender do fallback:
`docker logout` vale a pena experimentar rapidamente (baixo risco), embora
não corrija este bug de forma fiável. A correção mais completa é Docker
Desktop → Troubleshoot → "Clean / Purge data", que repõe o estado interno —
mas isto também remove os contentores e imagens existentes, portanto só o
faça se não se importar de os perder.

Separadamente, no Windows/Linux, o mesmo erro também pode significar que o
binário do credential helper está simplesmente em falta no `PATH` (em vez
de estar a avariar) — no Windows, confirme que
`C:\Program Files\Docker\Docker\resources\bin` está no `PATH` (uma
reparação da instalação corrige isto, se estiver em falta); no Linux,
confirme que a pasta onde o Docker Desktop instalou os credential helpers
está no `PATH`.

**"Docker is installed but doesn't seem to be running"** (mostrado pelo
menu) — inicie o Docker Desktop (ou o daemon do Docker no Linux) e tente
novamente. Os scripts do menu verificam `docker info` antes de fazer
qualquer outra coisa.

**Permissão negada ao comunicar com o daemon do Docker (Linux, sem Docker
Desktop)** — o seu utilizador ainda não está no grupo `docker`. Execute
`sudo usermod -aG docker $USER`, depois termine sessão e volte a entrar (ou
reinicie a máquina).

## Anexo: O modo direto — docker compose / docker simples

Tudo o que se segue é para referência / uso avançado — os alunos devem
normalmente usar apenas o menu (secção 1). Se preferir correr comandos
manualmente (ou a partir de um script), os mesmos scripts `dolos.sh` /
`dolos.ps1` também reencaminham argumentos diretamente para o
`docker compose` quando lhes passa algum — apenas definem primeiro
`DOLOS_HOST_OS`, para que o layout de teclado por defeito saia correto
(**PT-mac** em macOS, **PT** em todos os outros casos):

```bash
./dolos.sh build          # macOS/Linux — equivalente a: docker compose build
./dolos.sh up -d          # arrancar (em background) — cria ./workspace no anfitrião
./dolos.sh stop           # parar, mantendo o contentor
./dolos.sh start          # arrancar novamente
./dolos.sh restart        # reiniciar
./dolos.sh down           # parar e remover o contentor (a imagem mantém-se)
```

```powershell
powershell -ExecutionPolicy Bypass -File .\dolos.ps1 up -d
powershell -ExecutionPolicy Bypass -File .\dolos.ps1 stop
```

Se correr `docker compose ...` diretamente, sem usar um dos scripts,
`DOLOS_HOST_OS` assume o valor por defeito `linux` (ou seja, PT simples, sem
a variante mac) — o que está correto para anfitriões Linux/Windows, mas em
macOS convém defini-lo manualmente primeiro:
`DOLOS_HOST_OS=mac docker compose up -d`.

Sem usar compose:

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

(defina `-e DOLOS_HOST_OS=mac` se o anfitrião for macOS)

As flags `--cap-add SYS_PTRACE` e a desativação do seccomp são necessárias
para que o `gdb` e o `valgrind` consigam anexar-se a processos dentro do
contentor. O primeiro build demora alguns minutos (instalação de pacotes,
mais cmake/gdb/valgrind via trixie-backports); reconstrua sempre que
alterar o Dockerfile.

Abrir uma shell dentro do contentor em execução:

```bash
docker exec -it -u aluno dolos bash
```
