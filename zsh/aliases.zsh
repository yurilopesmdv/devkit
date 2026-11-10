# Aliases — só são criados quando a ferramenta existe.
# Git e kubectl usam os mesmos nomes dos plugins do oh-my-zsh.

_has() { (( $+commands[$1] )) }

# --- navegação e diretórios (como no oh-my-zsh) --------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias -- -='cd -'
alias d='dirs -v | head -10'
for _i in {1..9}; do alias "$_i"="cd -$_i"; done; unset _i
alias md='mkdir -p'
alias rd='rmdir'
take() { mkdir -p -- "$1" && cd -- "$1" }
mkcd() { take "$@" }

# --- listagem: eza > ls ---------------------------------------------------------
if _has eza; then
  alias ls='eza --group-directories-first --icons=auto'
  alias l='eza -lah --group-directories-first --icons=auto --git'
  alias ll='eza -lh --group-directories-first --icons=auto --git'
  alias la='eza -lah --group-directories-first --icons=auto --git'
  alias lsa='eza -lah --group-directories-first --icons=auto --git'
  alias lt='eza --tree --level=2 --icons=auto'
else
  alias ls='ls --color=auto --group-directories-first'
  alias l='ls -lah'
  alias ll='ls -lh'
  alias la='ls -lAh'
  alias lsa='ls -lah'
fi

# --- utilitários ----------------------------------------------------------------
_has batcat && ! _has bat && alias bat='batcat'
_has fdfind && ! _has fd && alias fd='fdfind'
if _has bat || _has batcat; then
  alias cat='bat --paging=never --style=plain'
  export MANPAGER="sh -c 'col -bx | ${commands[bat]:-batcat} -l man -p'"
fi
_has rg && alias rgrep='rg'
if _has btop; then alias top='btop'; elif _has htop; then alias top='htop'; fi
_has python || { _has python3 && alias python='python3'; }
_has pip || { _has pip3 && alias pip='pip3'; }

alias less='less -iR'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias ports='ss -tulpn'
alias myip='curl -s https://ifconfig.me && echo'
alias reload='exec zsh'
alias path='print -l $path'
alias _='sudo '
extract() { devkit extract "$@" }
serve() { devkit serve "$@" }

# Gerenciador de pacotes da distro com os mesmos nomes em todas
# (pkgu atualiza tudo · pkgi instala · pkgr remove · pkgs busca)
if _has apt-get; then
  alias pkgu='sudo apt update && sudo apt upgrade -y' pkgi='sudo apt install' pkgr='sudo apt remove' pkgs='apt search'
elif _has dnf; then
  alias pkgu='sudo dnf upgrade -y' pkgi='sudo dnf install' pkgr='sudo dnf remove' pkgs='dnf search'
elif _has pacman; then
  alias pkgu='sudo pacman -Syu' pkgi='sudo pacman -S' pkgr='sudo pacman -Rs' pkgs='pacman -Ss'
elif _has zypper; then
  alias pkgu='sudo zypper update' pkgi='sudo zypper install' pkgr='sudo zypper remove' pkgs='zypper search'
elif _has brew; then
  alias pkgu='brew update && brew upgrade' pkgi='brew install' pkgr='brew uninstall' pkgs='brew search'
fi

# --- git (nomes do plugin git do oh-my-zsh) -------------------------------------
# git_current_branch vem do devkit.zsh; git_main_branch do plugin do oh-my-zsh (se baixado)
(( $+functions[git_main_branch] )) || git_main_branch() {
  local b
  for b in main trunk mainline default master; do
    command git show-ref -q --verify "refs/heads/$b" && { print -r -- "$b"; return }
  done
  print -r -- main
}

alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gapa='git add --patch'
alias gb='git branch'
alias gba='git branch --all'
alias gbd='git branch --delete'
alias gbD='git branch --delete --force'
alias gc='git commit --verbose'
alias 'gc!'='git commit --verbose --amend'
alias gcn!='git commit --verbose --no-edit --amend'
alias gca='git commit --verbose --all'
alias gcam='git commit --all --message'
alias gcmsg='git commit --message'
alias gcl='git clone --recurse-submodules'
alias gclean='git clean --interactive -d'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gcm='git checkout $(git_main_branch)'
alias gcp='git cherry-pick'
alias gd='git diff'
alias gds='git diff --staged'
alias gdca='git diff --cached'
alias gf='git fetch'
alias gfa='git fetch --all --prune'
alias gl='git pull'
alias gpr='git pull --rebase'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gpsup='git push --set-upstream origin $(git_current_branch)'
alias ggpull='git pull origin "$(git_current_branch)"'
alias ggpush='git push origin "$(git_current_branch)"'
alias glo='git log --oneline --decorate'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias glol='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"'
alias gm='git merge'
alias grb='git rebase'
alias grbi='git rebase --interactive'
alias grbc='git rebase --continue'
alias grba='git rebase --abort'
alias grbm='git rebase $(git_main_branch)'
alias grh='git reset'
alias grhh='git reset --hard'
alias grs='git restore'
alias grst='git restore --staged'
alias grv='git remote --verbose'
alias gst='git status'
alias gss='git status --short'
alias gsb='git status --short --branch'
alias gs='git status --short --branch'
alias gsta='git stash push'
alias gstp='git stash pop'
alias gstl='git stash list'
alias gsw='git switch'
alias gswc='git switch --create'
alias gswm='git switch $(git_main_branch)'
alias gwip='git add -A; git rm $(git ls-files --deleted) 2>/dev/null; git commit --no-verify -m "--wip-- [skip ci]"'
_has lazygit && alias lg='lazygit'

# Volta para a raiz do repositório
groot() { cd -- "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" }

# Troca de branch com fzf (mostra o log da branch ao lado)
gbf() {
  _has fzf || { print -u2 "gbf precisa do fzf"; return 1 }
  local branch
  branch=$(git branch --all --sort=-committerdate --format='%(refname:short)' |
    grep -v HEAD | fzf --height=40% --preview 'git log --oneline -15 --color {}') || return
  git switch "${branch#origin/}"
}

# --- docker ----------------------------------------------------------------------
if _has docker; then
  alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'
  alias dpsa='docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'
  alias di='docker images'
  alias dex='docker exec -it'
  alias dlog='docker logs -f'
  alias dstop='docker stop'
  alias drm='docker rm'
  alias drmi='docker rmi'
  alias dprune='docker system prune -f'
  alias dc='docker compose'
  alias dcu='docker compose up -d'
  alias dcd='docker compose down'
  alias dcl='docker compose logs -f'
fi

# --- kubernetes (nomes do plugin kubectl do oh-my-zsh) ---------------------------
if _has kubectl; then
  alias k='kubectl'
  alias kaf='kubectl apply -f'
  alias kdel='kubectl delete'
  alias kdelf='kubectl delete -f'
  alias keti='kubectl exec -t -i'
  alias kex='kubectl exec -it'
  alias kcuc='kubectl config use-context'
  alias kcsc='kubectl config set-context'
  alias kccc='kubectl config current-context'
  alias kcgc='kubectl config get-contexts'
  alias kcn='kubectl config set-context --current --namespace'
  alias kctx='kubectl config use-context'
  alias kns='kubectl config set-context --current --namespace'
  alias kga='kubectl get all'
  alias kgaa='kubectl get all --all-namespaces'
  alias kgp='kubectl get pods'
  alias kgpa='kubectl get pods --all-namespaces'
  alias kgpw='kubectl get pods --watch'
  alias kgpwide='kubectl get pods -o wide'
  alias kdp='kubectl describe pods'
  alias kdelp='kubectl delete pods'
  alias kgs='kubectl get svc'
  alias kds='kubectl describe svc'
  alias kgd='kubectl get deployment'
  alias kdd='kubectl describe deployment'
  alias ked='kubectl edit deployment'
  alias krsd='kubectl rollout status deployment'
  alias krrd='kubectl rollout restart deployment'
  alias kgi='kubectl get ingress'
  alias kgcm='kubectl get configmaps'
  alias kgsec='kubectl get secret'
  alias kgns='kubectl get namespaces'
  alias kgn='kubectl get nodes'
  alias kdn='kubectl describe node'
  alias kge='kubectl get events --sort-by=.lastTimestamp'
  alias kl='kubectl logs'
  alias klf='kubectl logs -f'
  alias kpf='kubectl port-forward'
  alias ktop='kubectl top pods'
fi
_has helm && alias h='helm'

# --- terraform -------------------------------------------------------------------
if _has terraform; then
  alias tf='terraform'
  alias tfi='terraform init'
  alias tfp='terraform plan'
  alias tfa='terraform apply'
  alias tfd='terraform destroy'
  alias tfv='terraform validate'
  alias tff='terraform fmt -recursive'
  alias tfw='terraform workspace'
fi

# --- azure ------------------------------------------------------------------------
if _has az; then
  alias azl='az login'
  alias azs='az account show -o table'
  alias azset='az account set --subscription'
  alias azg='az group list -o table'
  alias azvm='az vm list -o table'
fi
