# Aliases — só são criados quando a ferramenta existe.

_has() { (( $+commands[$1] )) }

# Navegação
alias ..='cd ..'
alias ...='cd ../..'
alias -- -='cd -'
mkcd() { mkdir -p -- "$1" && cd -- "$1" }

# Listagem: eza > ls
if _has eza; then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -lh --group-directories-first --icons=auto --git'
  alias la='eza -lah --group-directories-first --icons=auto --git'
  alias lt='eza --tree --level=2 --icons=auto'
else
  alias ls='ls --color=auto --group-directories-first'
  alias ll='ls -lh'
  alias la='ls -lAh'
fi

# Nomes do Debian/Ubuntu
_has batcat && ! _has bat && alias bat='batcat'
_has fdfind && ! _has fd && alias fd='fdfind'
if _has bat || _has batcat; then
  alias cat='bat --paging=never --style=plain'
  export MANPAGER="sh -c 'col -bx | ${commands[bat]:-batcat} -l man -p'"
fi

alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias ports='ss -tulpn'
alias myip='curl -s https://ifconfig.me && echo'
alias reload='exec zsh'

# Git
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend --no-edit'
alias gco='git checkout'
alias gsw='git switch'
alias gcb='git switch -c'
alias gb='git branch'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git pull --ff-only'
alias gp='git push'
alias gpu='git push -u origin HEAD'
alias glog='git log --oneline --graph --decorate -20'
alias gst='git stash'
alias gstp='git stash pop'
_has lazygit && alias lg='lazygit'

# Volta para a raiz do repositório git atual
groot() { cd -- "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" }

# Troca de branch com fzf (mostra o log da branch ao lado)
gbf() {
  _has fzf || { print -u2 "gbf precisa do fzf"; return 1 }
  local branch
  branch=$(git branch --all --sort=-committerdate --format='%(refname:short)' |
    grep -v HEAD | fzf --height=40% --preview 'git log --oneline -15 --color {}') || return
  git switch "${branch#origin/}"
}

# Docker
if _has docker; then
  alias d='docker'
  alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
  alias dc='docker compose'
  alias dclean='docker system prune -f'
fi

# Kubernetes
if _has kubectl; then
  alias k='kubectl'
  alias kgp='kubectl get pods'
  alias kgs='kubectl get svc'
  alias kgd='kubectl get deploy'
  alias kl='kubectl logs -f'
  alias kd='kubectl describe'
  alias kctx='kubectl config use-context'
  alias kns='kubectl config set-context --current --namespace'
fi

_has terraform && alias tf='terraform'
