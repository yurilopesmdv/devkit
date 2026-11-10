# devkit prompt — sem dependências; uma chamada ao git por prompt.
#
#   ╭─ yuri ~/projects/app   main a1b2c3d ✎3 ●1 ?1 ↑2 ↓1 ≡1  ⎈ prod-eks:api  ☁ prod(sa-east-1)
#      ⛅ tf:dev  ⬢ 22.11.0  🐍 venv  ✦1  took 4s  ¯\_(ツ)_/¯ 🐧
#   ╰─ ❯                                                          Mon, 10 Nov · 14:02
#
# Branch: vermelho = alterações não commitadas · verde = tudo commitado mas
# não sincronizado (à frente do remoto) · amarelo = atrás · ciano = em dia (✔).
# Contadores: ✎ alterados · ● staged · ? novos · ✖ conflitos · ↑ à frente
#             ↓ atrás · ≡ stashes · (local) = branch sem upstream.
#
# Ajustes (em ~/.config/devkit/local.zsh):
#   DEVKIT_PROMPT_GIT=0             desliga o git (repos gigantes)
#   DEVKIT_PROMPT_SHA=0             esconde o hash do commit
#   DEVKIT_PROMPT_K8S=0             esconde o contexto do Kubernetes
#   DEVKIT_PROMPT_AWS=0             esconde o perfil da AWS
#   DEVKIT_PROMPT_LANGS=0           esconde versões de node/rust/go
#   DEVKIT_PROMPT_USER=0            esconde o usuário
#   DEVKIT_PROMPT_TIME=0            esconde data/hora à direita
#   DEVKIT_PROMPT_SHRUG=0           esconde o ¯\_(ツ)_/¯
#   DEVKIT_PROMPT_CHAR='🔶'          caractere do prompt (padrão ❯)
#   DEVKIT_PROMPT_SLOW_SECONDS=3    a partir de quando mostrar "took"
#   DEVKIT_PROMPT_PROD_PATTERN=prod padrão que conta como produção (vermelho)
#   DEVKIT_PROMPT_STAGE_PATTERN='(qa|hml|homolog|stg|staging|sandbox)'  (amarelo)

zmodload zsh/datetime 2>/dev/null
autoload -Uz add-zsh-hook

typeset -g _devkit_cmd_start=0
typeset -gA _devkit_version_cache

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

# Cor por ambiente: produção vermelho, homologação amarelo, resto verde.
_devkit_env_color() {
  local name=${1:l}
  if [[ $name == *${DEVKIT_PROMPT_PROD_PATTERN:-prod}* ]]; then print red
  elif [[ $name =~ ${DEVKIT_PROMPT_STAGE_PATTERN:-(qa|hml|homolog|stg|staging|sandbox)} ]]; then print yellow
  else print green
  fi
}

# --- git ---------------------------------------------------------------------

# Lê `git status --porcelain=v2 --branch` (stdin) e imprime o segmento git.
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
  if [[ ${DEVKIT_PROMPT_SHA:-1} != 0 && -n $oid && $oid != '(initial)' && $branch != @* ]]; then
    out+=" %F{8}${oid[1,7]}%f"
  fi
  (( changed > 0 ))   && out+=" %F{red}✎${changed}%f"
  (( staged > 0 ))    && out+=" %F{green}●${staged}%f"
  (( untracked > 0 )) && out+=" %F{red}?${untracked}%f"
  (( conflicts > 0 )) && out+=" %F{magenta}✖${conflicts}%f"
  (( ahead > 0 ))     && out+=" %F{green}↑${ahead}%f"
  (( behind > 0 ))    && out+=" %F{yellow}↓${behind}%f"
  (( changed + untracked + ahead + behind == 0 )) && out+=" %F{green}✔%f"
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

# --- nuvem e infra ------------------------------------------------------------

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
  print -r -- "  %F{$(_devkit_env_color "$ctx")}⎈ $(_devkit_escape "${ctx##*/}")${ns:+:$(_devkit_escape "$ns")}%f"
}

# Perfil da AWS ativo (só variáveis de ambiente; não chama a CLI).
_devkit_segment_aws() {
  [[ ${DEVKIT_PROMPT_AWS:-1} == 0 ]] && return
  local profile=${AWS_PROFILE:-${AWS_VAULT:-}}
  [[ -z $profile ]] && return
  local region=${AWS_REGION:-${AWS_DEFAULT_REGION:-}}
  print -r -- "  %F{$(_devkit_env_color "$profile")}☁ $(_devkit_escape "$profile")${region:+($(_devkit_escape "$region"))}%f"
}

_devkit_segment_terraform() {
  [[ -d .terraform ]] || return
  local ws=default
  [[ -r .terraform/environment ]] && ws=$(<.terraform/environment)
  print -r -- "  %F{$(_devkit_env_color "$ws")}⛅ tf:$(_devkit_escape "$ws")%f"
}

# --- linguagens (só dentro de projetos; versão em cache por binário) ----------

_devkit_version() { # _devkit_version <comando> [args...]
  local bin=${commands[$1]:-}
  [[ -z $bin ]] && return 1
  if [[ -z ${_devkit_version_cache[$bin]:-} ]]; then
    local out
    out=$("$@" 2>/dev/null) || return 1
    [[ $out =~ '[0-9]+\.[0-9]+(\.[0-9]+)?' ]] || return 1
    _devkit_version_cache[$bin]=$MATCH
  fi
  print -r -- "${_devkit_version_cache[$bin]}"
}

_devkit_segment_langs() {
  [[ ${DEVKIT_PROMPT_LANGS:-1} == 0 ]] && return
  local out="" v
  if [[ -f package.json ]] && v=$(_devkit_version node --version); then out+="  %F{green}⬢ ${v}%f"; fi
  if [[ -f Cargo.toml ]] && v=$(_devkit_version rustc --version); then out+="  %F{yellow}🦀 ${v}%f"; fi
  if [[ -f go.mod ]] && v=$(_devkit_version go version); then out+="  %F{cyan}🐹 ${v}%f"; fi
  [[ -n ${VIRTUAL_ENV:-} ]] && out+="  %F{green}🐍 $(_devkit_escape "${VIRTUAL_ENV:t}")%f"
  print -r -- "$out"
}

# --- sessão --------------------------------------------------------------------

# Usuário (vermelho se root) e host só quando for SSH.
_devkit_segment_user() {
  [[ ${DEVKIT_PROMPT_USER:-1} == 0 ]] && return
  local color=yellow
  (( EUID == 0 )) && color=red
  local host=""
  [[ -n ${SSH_CONNECTION:-}${SSH_TTY:-} ]] && host="%F{8}@%f%F{magenta}%m%f"
  print -r -- "%F{$color}%n%f${host} "
}

_devkit_os_icon() {
  case $OSTYPE in
    darwin*) print -r -- '🍎' ;;
    linux*)  print -r -- '🐧' ;;
    *)       print -r -- '💻' ;;
  esac
}

# Título da janela/aba: "usuário@host: pasta" e, enquanto roda, o comando.
_devkit_title() { [[ -t 1 ]] && print -Pn -- "\e]0;$1\a" }

_devkit_preexec() {
  _devkit_cmd_start=$EPOCHREALTIME
  _devkit_title "%n@%m: $(_devkit_escape "${1[1,60]}")"
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
  _devkit_title "%n@%m: %~"

  local jobs_seg=""
  (( ${#jobstates} > 0 )) && jobs_seg="  %F{magenta}✦${#jobstates}%f"

  local tail_seg=""
  [[ ${DEVKIT_PROMPT_SHRUG:-1} == 0 ]] || tail_seg+="  %F{8}¯\\_(ツ)_/¯%f"
  tail_seg+=" $(_devkit_os_icon)"

  local char=${DEVKIT_PROMPT_CHAR:-❯}
  local exit_mark="%F{green}${char}%f"
  (( last_status != 0 )) && exit_mark="%K{red}%F{white} ✘ ${last_status} %f%k %F{red}${char}%f"

  local line1="%F{8}╭─%f $(_devkit_segment_user)%F{blue}%B%~%b%f"
  line1+="$(_devkit_segment_git)$(_devkit_segment_k8s)$(_devkit_segment_aws)$(_devkit_segment_terraform)"
  line1+="$(_devkit_segment_langs)${jobs_seg}${took}${tail_seg}"

  PROMPT=$'\n'"${line1}"$'\n'"%F{8}╰─%f ${exit_mark} "
  RPROMPT=""
  [[ ${DEVKIT_PROMPT_TIME:-1} == 0 ]] || RPROMPT="%F{8}%D{%a, %d %b} · %D{%H:%M}%f"
}

# O venv tem seu próprio prefixo; o devkit já mostra.
export VIRTUAL_ENV_DISABLE_PROMPT=1

add-zsh-hook preexec _devkit_preexec
add-zsh-hook precmd _devkit_precmd
