#!/usr/bin/env bash
# Funções compartilhadas pelo install.sh, uninstall.sh e bin/devkit.

DEVKIT_DATA=${DEVKIT_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/devkit}
DEVKIT_CONFIG=${DEVKIT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/devkit}
DEVKIT_BIN=${DEVKIT_BIN:-$HOME/.local/bin}
DRY_RUN=${DRY_RUN:-0}

if [[ -t 1 ]]; then
  C_RESET=$'\e[0m' C_BLUE=$'\e[34m' C_GREEN=$'\e[32m' C_YELLOW=$'\e[33m' C_RED=$'\e[31m' C_DIM=$'\e[2m'
else
  C_RESET='' C_BLUE='' C_GREEN='' C_YELLOW='' C_RED='' C_DIM=''
fi

step() { printf '\n%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()   { printf '  %s✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
fail() { printf '  %s✘%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

# Executa (ou só mostra, em --dry-run).
run() {
  if [[ $DRY_RUN == 1 ]]; then
    printf '  %s$ %s%s\n' "$C_DIM" "$*" "$C_RESET"
    return 0
  fi
  "$@"
}

# sudo só quando não for root (containers rodam como root, sem sudo).
as_root() {
  if [[ $(id -u) -eq 0 ]]; then run "$@"
  elif has sudo; then run sudo "$@"
  else fail "precisa de root para: $*  (instale o sudo ou rode como root)"
  fi
}

# Define OS_ID, OS_LIKE, PKG (apt|dnf|pacman|zypper|brew) e IS_WSL.
detect_os() {
  OS_ID=unknown OS_LIKE='' PKG='' IS_WSL=0
  if [[ $(uname -s) == Darwin ]]; then
    OS_ID=macos PKG=brew
  elif [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID=${ID:-unknown} OS_LIKE=${ID_LIKE:-}
  fi
  if [[ -z $PKG ]]; then
    case " $OS_ID $OS_LIKE " in
      *' debian '*|*' ubuntu '*) PKG=apt ;;
      *' fedora '*|*' rhel '*|*' centos '*) PKG=dnf ;;
      *' arch '*) PKG=pacman ;;
      *' suse '*|*' opensuse '*) PKG=zypper ;;
    esac
  fi
  grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=1
  return 0
}

detect_arch() {
  case $(uname -m) in
    x86_64|amd64) ARCH=x86_64 ;;
    aarch64|arm64) ARCH=aarch64 ;;
    *) ARCH=$(uname -m) ;;
  esac
}

# Nome do pacote de cada ferramenta por gerenciador ("-" = não existe lá).
pkg_name() {
  local tool=$1
  case "$PKG:$tool" in
    apt:fd) echo fd-find ;;
    apt:delta) echo git-delta ;;
    apt:rg|dnf:rg|pacman:rg|zypper:rg|brew:rg) echo ripgrep ;;
    apt:lazygit) echo - ;;
    apt:yq) echo - ;;  # o "yq" do apt é outro projeto (python)
    dnf:fd) echo fd-find ;;
    dnf:delta|pacman:delta|zypper:delta) echo git-delta ;;
    dnf:yq) echo - ;;
    dnf:lazygit) echo - ;;
    pacman:yq) echo go-yq ;;
    zypper:fd) echo fd ;;
    *) echo "$tool" ;;
  esac
}

pkg_refresh() {
  case $PKG in
    apt) as_root apt-get update -qq ;;
    dnf) as_root dnf -q makecache ;;
    pacman) as_root pacman -Sy --noconfirm ;;
    zypper) as_root zypper -q refresh ;;
    brew) run brew update ;;
  esac
}

pkg_available() {
  local name=$1
  case $PKG in
    apt) [[ -n $(apt-cache policy "$name" 2>/dev/null | awk '/Candidate:/ && $2 != "(none)"') ]] ;;
    dnf) dnf -q list --available "$name" >/dev/null 2>&1 || rpm -q "$name" >/dev/null 2>&1 ;;
    pacman) pacman -Si "$name" >/dev/null 2>&1 ;;
    zypper) zypper -q info "$name" 2>/dev/null | grep -q '^Name' ;;
    brew) brew info "$name" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

pkg_install() {
  [[ $# -eq 0 ]] && return 0
  case $PKG in
    apt) as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "$@" ;;
    dnf) as_root dnf install -y -q "$@" ;;
    pacman) as_root pacman -S --noconfirm --needed "$@" ;;
    zypper) as_root zypper -q install -y "$@" ;;
    brew) run brew install "$@" ;;
  esac
}
