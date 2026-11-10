# devkit prompt — sem dependências; uma chamada ao git por prompt.
#
#   ╭─ ~/projects/app   main ✎3 ●1 ?1 ↑2 ↓1 ≡1  ⎈ prod-eks:api  ⛅ tf:dev  🐍 venv  took 4s
#   ╰─ ❯                                                                       14:02
#
# Branch: vermelho = alterações não commitadas · verde = tudo commitado mas
# não sincronizado (à frente do remoto) · amarelo = atrás · ciano = em dia.
# Contadores: ✎ alterados · ● staged · ? novos · ✖ conflitos · ↑ à frente
#             ↓ atrás · ≡ stashes · (local) = branch sem upstream.
#
# Ajustes (defina no ~/.zshrc antes de carregar o devkit):
#   DEVKIT_PROMPT_GIT=0             desliga o git (repos gigantes)
#   DEVKIT_PROMPT_K8S=0             desliga o contexto do Kubernetes
#   DEVKIT_PROMPT_TIME=0            desliga a hora à direita
#   DEVKIT_PROMPT_SLOW_SECONDS=3    a partir de quando mostrar "took"
#   DEVKIT_PROMPT_PROD_PATTERN=prod padrão que pinta contexto/workspace de vermelho

zmodload zsh/datetime 2>/dev/null
autoload -Uz add-zsh-hook

typeset -g _devkit_cmd_start=0

_devkit_preexec() { _devkit_cmd_start=$EPOCHREALTIME }

# Escapa % para o texto não virar sequência de prompt.
_devkit_escape() { print -r -- "${1//\%/%%}" }

_devkit_format_duration() {
  local -i total=$1 h m s
  (( h = total / 3600, m = total % 3600 / 60, s = total % 60 ))
  if (( h > 0 )); then print -r -- "${h}h${m}m"
  elif (( m > 0 )); then print -r -- "${m}m${s}s"
  else print -r -- "${s}s"
  fi
}

_devkit_is_prod() { [[ $1 == *${DEVKIT_PROMPT_PROD_PATTERN:-prod}* ]] }

# Lê `git status --porcelain=v2 --branch` (stdin) e imprime o segmento git.
# Separado para ser testável sem terminal.
_devkit_git_segment_from_status() {
  local line ab branch="" oid="" upstream=""
  local -i ahead=0 behind=0 changed=0 staged=0 untracked=0 conflicts=0

  while IFS= read -r line; do
    case $line in
      '# branch.head '*)     branch=${line#\# branch.head } ;;
      '# branch.oid '*)      oid=${line#\# branch.oid } ;;
      '# branch.upstream '*) upstream=${line#\# branch.upstream } ;;
      '# branch.ab '*)
        ab=${line#\# branch.ab }
        ahead=${${ab%% *}#+}
        behind=${${ab##* }#-}
        ;;
      '1 '*|'2 '*)
        (( ++changed ))
        [[ ${line[3]} != '.' ]] && (( ++staged ))
        ;;
      'u '*) (( ++changed, ++conflicts )) ;;
      '? '*) (( ++untracked )) ;;
    esac
  done

  [[ -z $branch ]] && return 1
  [[ $branch == '(detached)' ]] && branch="@${oid[1,7]}"

  local color=cyan
  if (( changed + untracked > 0 )); then color=red
  elif (( ahead > 0 )); then color=green
  elif (( behind > 0 )); then color=yellow
  fi

  local out="%F{$color} $(_devkit_escape "$branch")%f"
  (( changed > 0 ))   && out+=" %F{red}✎${changed}%f"
  (( staged > 0 ))    && out+=" %F{green}●${staged}%f"
  (( untracked > 0 )) && out+=" %F{red}?${untracked}%f"
  (( conflicts > 0 )) && out+=" %F{magenta}✖${conflicts}%f"
  (( ahead > 0 ))     && out+=" %F{green}↑${ahead}%f"
  (( behind > 0 ))    && out+=" %F{yellow}↓${behind}%f"
  if [[ -z $upstream && $oid != '(initial)' ]]; then out+=" %F{8}(local)%f"; fi
  print -r -- "$out"
}

_devkit_segment_git() {
  [[ ${DEVKIT_PROMPT_GIT:-1} == 0 ]] && return
  local status_out seg
  status_out=$(command git --no-optional-locks status --porcelain=v2 --branch 2>/dev/null) || return
  seg=$(print -r -- "$status_out" | _devkit_git_segment_from_status) || return
  local -a stashes
  stashes=("${(@f)$(command git stash list 2>/dev/null)}")
  (( ${#stashes} > 0 )) && [[ -n ${stashes[1]} ]] && seg+=" %F{8}≡${#stashes}%f"
  print -r -- "  $seg"
}

# Contexto/namespace do kubectl lidos direto do kubeconfig (sem chamar kubectl).
_devkit_segment_k8s() {
  [[ ${DEVKIT_PROMPT_K8S:-1} == 0 ]] && return
  local cfg=${${KUBECONFIG:-}%%:*}
  [[ -z $cfg ]] && cfg=$HOME/.kube/config
  [[ -r $cfg ]] || return
  local ctx ns
  ctx=$(command awk '/^current-context:/ { gsub(/["'\'']/, "", $2); print $2; exit }' "$cfg")
  [[ -z $ctx ]] && return
  ns=$(command awk -v want="$ctx" '
    /^- context:/ { inctx = 1; ns = ""; next }
    inctx && /^[[:space:]]+namespace:/ { ns = $2 }
    inctx && /^[[:space:]]+name:/ { if ($2 == want) { print ns; exit } }
    /^[^ -]/ { inctx = 0 }' "$cfg")
  local color=green
  _devkit_is_prod "$ctx" && color=red
  print -r -- "  %F{$color}⎈ $(_devkit_escape "${ctx##*/}")${ns:+:$(_devkit_escape "$ns")}%f"
}

_devkit_segment_terraform() {
  [[ -d .terraform ]] || return
  local ws=default
  [[ -r .terraform/environment ]] && ws=$(<.terraform/environment)
  local color=green
  _devkit_is_prod "$ws" && color=red
  print -r -- "  %F{$color}⛅ tf:$(_devkit_escape "$ws")%f"
}

_devkit_segment_venv() {
  [[ -n ${VIRTUAL_ENV:-} ]] && print -r -- "  %F{green}🐍 $(_devkit_escape "${VIRTUAL_ENV:t}")%f"
}

_devkit_precmd() {
  local -i last_status=$?
  local took=""
  if (( _devkit_cmd_start > 0 )); then
    local -i elapsed=$(( EPOCHREALTIME - _devkit_cmd_start ))
    (( elapsed >= ${DEVKIT_PROMPT_SLOW_SECONDS:-3} )) && \
      took="  %F{yellow}took $(_devkit_format_duration $elapsed)%f"
    _devkit_cmd_start=0
  fi

  local exit_mark="%F{green}❯%f"
  (( last_status != 0 )) && exit_mark="%F{red}✘ ${last_status} ❯%f"

  local line1="%F{8}╭─%f %F{blue}%B%~%b%f"
  line1+="$(_devkit_segment_git)$(_devkit_segment_k8s)$(_devkit_segment_terraform)$(_devkit_segment_venv)${took}"

  PROMPT=$'\n'"${line1}"$'\n'"%F{8}╰─%f ${exit_mark} "
  RPROMPT=""
  [[ ${DEVKIT_PROMPT_TIME:-1} == 0 ]] || RPROMPT="%F{8}%D{%H:%M}%f"
}

# O venv tem seu próprio prefixo; o devkit já mostra.
export VIRTUAL_ENV_DISABLE_PROMPT=1

add-zsh-hook preexec _devkit_preexec
add-zsh-hook precmd _devkit_precmd
