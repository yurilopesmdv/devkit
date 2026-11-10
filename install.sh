#!/usr/bin/env bash
# devkit — prepara um Linux novo (ou WSL) para desenvolvimento em um comando.
#
#   ./install.sh               instala tudo (pede sudo para os pacotes)
#   ./install.sh --dry-run     mostra o que faria, sem mudar nada
#   ./install.sh --help        todas as opções
set -euo pipefail

DEVKIT_HOME=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
. "$DEVKIT_HOME/lib/common.sh"
# shellcheck source=lib/releases.sh
. "$DEVKIT_HOME/lib/releases.sh"

CORE_TOOLS=(git curl zsh unzip tar)
CLI_TOOLS=(fzf rg fd bat jq tree htop tmux direnv eza zoxide btop delta lazygit yq)
RELEASE_FALLBACK=(eza zoxide delta lazygit yq)
PLUGINS=(
  zsh-users/zsh-autosuggestions
  zsh-users/zsh-syntax-highlighting
  zsh-users/zsh-completions
)

WITH_PACKAGES=1 WITH_RELEASES=1 WITH_SHELL=1 WITH_CHSH=1

usage() {
  cat <<'EOF'
Uso: ./install.sh [opções]

  --dry-run         mostra os comandos sem executar
  --no-packages     não instala pacotes da distro (só configura o zsh)
  --no-releases     não baixa binários do GitHub para o que a distro não tem
  --no-shell        não mexe no ~/.zshrc
  --no-chsh         não troca o shell padrão para zsh
  -h, --help        esta ajuda

Distros: Debian/Ubuntu (apt), Fedora/RHEL (dnf), Arch (pacman), openSUSE (zypper),
macOS (brew) e WSL. Seu ~/.zshrc atual vira backup e as linhas dele ficam
comentadas em ~/.config/devkit/local.zsh para você reaproveitar.
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=1 ;;
    --no-packages) WITH_PACKAGES=0 ;;
    --no-releases) WITH_RELEASES=0 ;;
    --no-shell) WITH_SHELL=0 ;;
    --no-chsh) WITH_CHSH=0 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; fail "opção desconhecida: $1" ;;
  esac
  shift
done

install_packages() {
  step "Pacotes ($PKG em $OS_ID)"
  [[ -n $PKG ]] || { warn "distro não reconhecida ($OS_ID); pulando pacotes"; return; }
  pkg_refresh

  local tool name wanted=() missing=()
  # imagens mínimas (containers) vêm sem certificados: sem eles, nada de HTTPS
  if [[ ! -s /etc/ssl/certs/ca-certificates.crt && ! -s /etc/pki/tls/certs/ca-bundle.crt && $PKG != brew ]]; then
    wanted+=(ca-certificates)
  fi
  for tool in "${CORE_TOOLS[@]}" "${CLI_TOOLS[@]}"; do
    has "$tool" && continue
    [[ $tool == fd ]] && has fdfind && continue
    [[ $tool == bat ]] && has batcat && continue
    name=$(pkg_name "$tool")
    if [[ $name != - ]] && { [[ $DRY_RUN == 1 && $PKG != apt ]] || pkg_available "$name"; }; then
      wanted+=("$name")
    else
      missing+=("$tool")
    fi
  done

  if [[ ${#wanted[@]} -gt 0 ]]; then
    pkg_install "${wanted[@]}"
    ok "instalados: ${wanted[*]}"
  else
    ok "nada a instalar pela distro"
  fi
  MISSING_TOOLS=("${missing[@]}")
}

install_releases() {
  step "Binários do GitHub (o que a distro não tem)"
  local tool any=0
  for tool in "${MISSING_TOOLS[@]}"; do
    [[ " ${RELEASE_FALLBACK[*]} " == *" $tool "* ]] || { warn "$tool: indisponível nesta distro"; continue; }
    any=1
    release_install "$tool" || true
  done
  [[ $any == 1 ]] || ok "nada a baixar"
}

install_plugins() {
  step "Plugins do zsh"
  run mkdir -p "$DEVKIT_DATA/plugins"
  local repo dir
  for repo in "${PLUGINS[@]}"; do
    dir="$DEVKIT_DATA/plugins/${repo#*/}"
    if [[ -d $dir/.git ]]; then
      run git -C "$dir" pull -q --ff-only && ok "${repo#*/} atualizado"
    else
      run git clone -q --depth 1 "https://github.com/$repo.git" "$dir" && ok "${repo#*/}"
    fi
  done
}

configure_shell() {
  step "Configuração do zsh"
  local zshrc=$HOME/.zshrc local_file=$DEVKIT_CONFIG/local.zsh
  run mkdir -p "$DEVKIT_CONFIG"

  if [[ -f $zshrc ]] && ! grep -q 'gerado pelo devkit' "$zshrc"; then
    local backup
    backup="$zshrc.devkit-backup-$(date +%Y%m%d-%H%M%S)"
    run cp "$zshrc" "$backup"
    ok "backup do .zshrc: $backup"
    if [[ ! -f $local_file ]]; then
      if [[ $DRY_RUN == 1 ]]; then
        printf '  %s$ copiar linhas do .zshrc antigo, comentadas, para %s%s\n' "$C_DIM" "$local_file" "$C_RESET"
      else
        {
          echo "# Suas personalizações (carregado por último pelo devkit)."
          echo "# Abaixo, o seu .zshrc antigo comentado: descomente o que ainda quiser."
          echo "# O devkit já cuida de: oh-my-zsh, tema, plugins, nvm, cargo, fzf e PATH local."
          echo
          sed 's/^/# /' "$zshrc"
        } >"$local_file"
      fi
      ok "linhas antigas guardadas em $local_file"
    fi
  fi

  if [[ $DRY_RUN == 1 ]]; then
    printf '  %s$ escrever %s%s\n' "$C_DIM" "$zshrc" "$C_RESET"
  else
    cat >"$zshrc" <<EOF
# gerado pelo devkit — personalize em $local_file
export DEVKIT_HOME="$DEVKIT_HOME"
source "\$DEVKIT_HOME/zsh/devkit.zsh"
EOF
  fi
  ok "~/.zshrc aponta para $DEVKIT_HOME"

  run mkdir -p "$DEVKIT_BIN"
  run ln -sf "$DEVKIT_HOME/bin/devkit" "$DEVKIT_BIN/devkit"
  ok "comando devkit em $DEVKIT_BIN"
}

change_shell() {
  local zsh_path
  zsh_path=$(command -v zsh || true)
  [[ -n $zsh_path ]] || { warn "zsh não encontrado; shell padrão não alterado"; return; }
  [[ ${SHELL:-} == "$zsh_path" ]] && return
  step "Shell padrão"
  if run chsh -s "$zsh_path" "$(id -un)"; then ok "shell padrão: $zsh_path"
  else warn "não consegui trocar; rode: chsh -s $zsh_path"
  fi
}

main() {
  detect_os
  printf '%sdevkit%s · %s%s · %s\n' "$C_GREEN" "$C_RESET" "$OS_ID" "$([[ $IS_WSL == 1 ]] && echo ' (WSL)')" "$DEVKIT_HOME"
  [[ $DRY_RUN == 1 ]] && warn "modo --dry-run: nada será alterado"

  MISSING_TOOLS=()
  [[ $WITH_PACKAGES == 1 ]] && install_packages
  [[ $WITH_RELEASES == 1 && ${#MISSING_TOOLS[@]} -gt 0 ]] && install_releases
  if [[ $WITH_SHELL == 1 ]]; then
    has git || [[ $DRY_RUN == 1 ]] || fail "git é necessário para os plugins"
    install_plugins
    configure_shell
  fi
  [[ $WITH_CHSH == 1 ]] && change_shell

  step "Pronto"
  echo "  Abra um terminal novo (ou rode: exec zsh) e confira com: devkit doctor"
}

main
