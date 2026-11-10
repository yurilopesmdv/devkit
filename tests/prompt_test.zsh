#!/usr/bin/env zsh
# Testes do prompt: cria repositórios git temporários e confere os segmentos.
emulate -L zsh
setopt no_unset pipe_fail

ROOT=${0:A:h:h}
source "$ROOT/zsh/prompt.zsh"

typeset -i failures=0 passed=0
check() { # check <descrição> <texto> <trecho esperado>
  if [[ $2 == *"$3"* ]]; then (( ++passed ))
  else (( ++failures )); print -u2 "FALHOU: $1\n  esperado: $3\n  obtido:   $2"
  fi
}
check_not() {
  if [[ $2 != *"$3"* ]]; then (( ++passed ))
  else (( ++failures )); print -u2 "FALHOU: $1\n  não esperado: $3\n  obtido: $2"
  fi
}

tmp=$(mktemp -d)
trap 'rm -rf $tmp' EXIT
mkdir -p "$tmp/home"; export HOME=$tmp/home GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# Remoto + clone
git init -q --bare "$tmp/remote.git"
git --git-dir="$tmp/remote.git" symbolic-ref HEAD refs/heads/main
git clone -q "$tmp/remote.git" "$tmp/work" 2>/dev/null
cd "$tmp/work"
git checkout -q -b main 2>/dev/null || true
print a > a.txt && git add a.txt && git commit -qm init && git push -q -u origin main 2>/dev/null

seg=$(_devkit_segment_git)
check "em dia: branch ciano" "$seg" "%F{cyan} main%f"
check_not "em dia: sem contadores" "$seg" "✎"

print b >> a.txt
seg=$(_devkit_segment_git)
check "alterado: branch vermelha" "$seg" "%F{red} main%f"
check "alterado: conta 1" "$seg" "✎1"

git add a.txt
print c > novo.txt
seg=$(_devkit_segment_git)
check "staged" "$seg" "●1"
check "novo arquivo" "$seg" "?1"

git commit -qm two
rm novo.txt
seg=$(_devkit_segment_git)
check "commitado não sincronizado: verde" "$seg" "%F{green} main%f"
check "à frente 1" "$seg" "↑1"

git push -q 2>/dev/null
git reset -q --hard HEAD~1
seg=$(_devkit_segment_git)
check "atrás: amarelo" "$seg" "%F{yellow} main%f"
check "atrás 1" "$seg" "↓1"

git checkout -q -b feature/50%
seg=$(_devkit_segment_git)
check "branch sem upstream" "$seg" "(local)"
check "escapa %" "$seg" "feature/50%%"

print x > s.txt && git add s.txt && git stash -q
seg=$(_devkit_segment_git)
check "stash" "$seg" "≡1"

DEVKIT_PROMPT_GIT=0
check "git desligado" "$(_devkit_segment_git)" ""
[[ -z $(_devkit_segment_git) ]] && (( ++passed )) || { (( ++failures )); print -u2 "FALHOU: git desligado deveria ser vazio"; }
unset DEVKIT_PROMPT_GIT

cd "$tmp" && check "fora de repo: vazio" "x$(_devkit_segment_git)" "x"

# Kubernetes
mkdir -p "$tmp/kube"
cat > "$tmp/kube/config" <<'EOF'
apiVersion: v1
contexts:
- context:
    cluster: c1
    namespace: api
  name: prod-eks
- context:
    cluster: c2
  name: kind-dev
current-context: prod-eks
kind: Config
EOF
KUBECONFIG=$tmp/kube/config
check "k8s prod vermelho" "$(_devkit_segment_k8s)" "%F{red}⎈ prod-eks:api%f"
sed -i 's/^current-context: .*/current-context: kind-dev/' "$tmp/kube/config"
check "k8s dev verde sem ns" "$(_devkit_segment_k8s)" "%F{green}⎈ kind-dev%f"
unset KUBECONFIG

# Terraform
mkdir -p "$tmp/tf/.terraform" && cd "$tmp/tf"
check "tf default" "$(_devkit_segment_terraform)" "tf:default"
print prod-us > .terraform/environment
check "tf prod vermelho" "$(_devkit_segment_terraform)" "%F{red}⛅ tf:prod-us%f"

# Duração e código de saída
check "duração" "$(_devkit_format_duration 75)" "1m15s"
( exit 3 ); _devkit_precmd
check "código de saída" "$PROMPT" "✘ 3"

print "prompt: $passed ok, $failures falha(s)"
(( failures == 0 ))
