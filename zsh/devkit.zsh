# devkit — ponto de entrada do zsh. Carregado pelo ~/.zshrc gerado no install.
# Personalizações suas: ~/.config/devkit/local.zsh (carregado por último).

export DEVKIT_HOME=${DEVKIT_HOME:-${${(%):-%x}:A:h:h}}
export DEVKIT_DATA=${DEVKIT_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/devkit}
export DEVKIT_CONFIG=${DEVKIT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/devkit}

# PATH: binários locais primeiro, sem duplicar.
typeset -U path
path=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/go/bin" $path)

# Histórico
HISTFILE=${HISTFILE:-$HOME/.zsh_history}
HISTSIZE=100000
SAVEHIST=100000
setopt extended_history hist_ignore_all_dups hist_ignore_space hist_reduce_blanks
setopt share_history inc_append_history

# Comportamento
setopt auto_cd auto_pushd pushd_ignore_dups interactive_comments no_beep
bindkey -e
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# Completions (zsh-completions + cache de 24h)
[[ -d $DEVKIT_DATA/plugins/zsh-completions/src ]] && fpath=("$DEVKIT_DATA/plugins/zsh-completions/src" $fpath)
autoload -Uz compinit
_devkit_zcompdump=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-$ZSH_VERSION
mkdir -p "${_devkit_zcompdump:h}"
if [[ -n $_devkit_zcompdump(#qN.mh+24) || ! -s $_devkit_zcompdump ]]; then
  compinit -i -d "$_devkit_zcompdump"
else
  compinit -C -d "$_devkit_zcompdump"
fi
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compcache"

source "$DEVKIT_HOME/zsh/aliases.zsh"
source "$DEVKIT_HOME/zsh/tools.zsh"
source "$DEVKIT_HOME/zsh/prompt.zsh"

# Plugins (syntax-highlighting precisa ser o último)
for _devkit_plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  [[ -r $DEVKIT_DATA/plugins/$_devkit_plugin/$_devkit_plugin.zsh ]] && \
    source "$DEVKIT_DATA/plugins/$_devkit_plugin/$_devkit_plugin.zsh"
done
unset _devkit_plugin _devkit_zcompdump
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

[[ -r $DEVKIT_CONFIG/local.zsh ]] && source "$DEVKIT_CONFIG/local.zsh"
