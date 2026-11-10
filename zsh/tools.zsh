# Integrações com ferramentas instaladas (cada uma só carrega se existir).

(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
(( $+commands[direnv] )) && eval "$(direnv hook zsh)"

# fzf: versões novas têm `fzf --zsh`; as antigas instalam os scripts em /usr/share.
if (( $+commands[fzf] )); then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  else
    for _f in /usr/share/doc/fzf/examples/key-bindings.zsh /usr/share/fzf/key-bindings.zsh \
              /usr/share/doc/fzf/examples/completion.zsh /usr/share/fzf/completion.zsh; do
      [[ -r $_f ]] && source "$_f"
    done
    unset _f
  fi
  if (( $+commands[fd] || $+commands[fdfind] )); then
    export FZF_DEFAULT_COMMAND="${commands[fd]:-${commands[fdfind]}} --type f --hidden --exclude .git"
    export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
  fi
  export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border'
fi

# delta como pager do git, sem mexer no ~/.gitconfig
if (( $+commands[delta] )); then
  export GIT_PAGER='delta'
  export DELTA_FEATURES='+side-by-side'
fi

# kubectl: completion carregada só no primeiro uso (é lenta).
# Com o plugin kubectl do oh-my-zsh, ele já cuida disso com cache.
if (( $+commands[kubectl] )) && [[ ! -r $DEVKIT_DATA/plugins/omz/kubectl.plugin.zsh ]]; then
  kubectl() {
    unfunction kubectl
    source <(command kubectl completion zsh)
    command kubectl "$@"
  }
fi

# nvm: o node padrão entra no PATH na hora; o script do nvm (lento, ~300ms)
# só carrega quando você usar o comando `nvm`.
export NVM_DIR=${NVM_DIR:-$HOME/.nvm}
if [[ -s $NVM_DIR/nvm.sh ]]; then
  _devkit_nvm_default=""
  [[ -r $NVM_DIR/alias/default ]] && _devkit_nvm_default=$(<"$NVM_DIR/alias/default")
  _devkit_nvm_bins=("$NVM_DIR"/versions/node/v${_devkit_nvm_default#v}*(/nOn[1]N))
  (( ${#_devkit_nvm_bins} )) || _devkit_nvm_bins=("$NVM_DIR"/versions/node/*(/nOn[1]N))
  (( ${#_devkit_nvm_bins} )) && path=("${_devkit_nvm_bins[1]}/bin" $path)
  unset _devkit_nvm_default _devkit_nvm_bins
  nvm() { unfunction nvm; source "$NVM_DIR/nvm.sh"; nvm "$@" }
fi

[[ -r $HOME/.cargo/env ]] && source "$HOME/.cargo/env"

# Homebrew / Linuxbrew
for _b in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
  [[ -x $_b ]] && { eval "$("$_b" shellenv)"; break; }
done
unset _b

# asdf (0.16+ é um binário em Go e só precisa dos shims; versões antigas usam asdf.sh)
export ASDF_DATA_DIR=${ASDF_DATA_DIR:-$HOME/.asdf}
if [[ -d $ASDF_DATA_DIR/shims ]]; then
  path=("$ASDF_DATA_DIR/shims" $path)
  [[ -r $ASDF_DATA_DIR/asdf.sh ]] && source "$ASDF_DATA_DIR/asdf.sh"
fi

# Completions no estilo bash (aws, terraform, az)
if (( $+commands[aws_completer] || $+commands[terraform] || $+commands[az] )); then
  autoload -Uz bashcompinit && bashcompinit
  (( $+commands[aws_completer] )) && complete -C aws_completer aws
  (( $+commands[terraform] )) && complete -o nospace -C "${commands[terraform]}" terraform
  for _f in /etc/bash_completion.d/azure-cli /opt/az/az.completion "$HOME/lib/azure-cli/az.completion"; do
    [[ -r $_f ]] && { source "$_f"; break; }
  done
  unset _f
fi

# helm: completion só no primeiro uso, como o kubectl
if (( $+commands[helm] )); then
  helm() { unfunction helm; source <(command helm completion zsh); command helm "$@" }
fi

# WSL: integração com o Windows
if [[ -r /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
  export DEVKIT_WSL=1
  alias open='explorer.exe'
  alias explorer='explorer.exe'
  alias clip='clip.exe'
  alias pbcopy='clip.exe'
  alias pbpaste='powershell.exe -NoProfile -Command Get-Clipboard | tr -d "\r"'
  (( $+commands[code] )) || alias code='code.exe'
elif (( $+commands[xclip] )); then
  alias pbcopy='xclip -selection clipboard'
  alias pbpaste='xclip -selection clipboard -o'
elif (( $+commands[wl-copy] )); then
  alias pbcopy='wl-copy'
  alias pbpaste='wl-paste'
fi
