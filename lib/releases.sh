#!/usr/bin/env bash
# Instala ferramentas a partir do release oficial no GitHub quando o
# gerenciador de pacotes da distro não tem (ex.: eza e lazygit no Ubuntu 20.04).
# Binários vão para ~/.local/bin, sem precisar de root.

# "repo regex-do-asset binário" (a regex usa {arch}, {goarch}, {goarch2})
release_spec() {
  case $1 in
    eza)     echo 'eza-community/eza eza_{arch}-unknown-linux-gnu\.tar\.gz$ eza' ;;
    zoxide)  echo 'ajeetdsouza/zoxide zoxide-[0-9.]+-{arch}-unknown-linux-musl\.tar\.gz$ zoxide' ;;
    delta)   echo 'dandavison/delta delta-[0-9.]+-{arch}-unknown-linux-(musl|gnu)\.tar\.gz$ delta' ;;
    lazygit) echo 'jesseduffield/lazygit lazygit_[0-9.]+_[Ll]inux_{goarch}\.tar\.gz$ lazygit' ;;
    yq)      echo 'mikefarah/yq yq_linux_{goarch2}$ yq' ;;
    *) return 1 ;;
  esac
}

release_install() (
  # subshell: o trap de limpeza vale só aqui dentro
  local tool=$1 spec repo pattern bin goarch goarch2 url tmp
  spec=$(release_spec "$tool") || { warn "$tool: sem release conhecido"; return 1; }
  read -r repo pattern bin <<<"$spec"
  detect_arch
  case $ARCH in x86_64) goarch=x86_64 goarch2=amd64 ;; aarch64) goarch=arm64 goarch2=arm64 ;; *) goarch=$ARCH goarch2=$ARCH ;; esac
  pattern=${pattern//\{arch\}/$ARCH}
  pattern=${pattern//\{goarch\}/$goarch}
  pattern=${pattern//\{goarch2\}/$goarch2}

  if [[ $DRY_RUN == 1 ]]; then
    printf '  %s$ baixar %s (github.com/%s, asset ~ %s) -> %s%s\n' "$C_DIM" "$bin" "$repo" "$pattern" "$DEVKIT_BIN" "$C_RESET"
    return 0
  fi

  url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" |
    grep -oE '"browser_download_url": *"[^"]+"' | cut -d'"' -f4 | grep -E "$pattern" | head -1) || true
  [[ -n $url ]] || { warn "$tool: nenhum asset para $ARCH em $repo"; return 1; }

  tmp=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT
  curl -fsSL "$url" -o "$tmp/asset" || { warn "$tool: download falhou"; return 1; }
  mkdir -p "$DEVKIT_BIN"
  if [[ $url == *.tar.gz ]]; then
    tar -xzf "$tmp/asset" -C "$tmp"
    local found
    found=$(find "$tmp" -type f -name "$bin" -perm -u+x | head -1)
    [[ -z $found ]] && found=$(find "$tmp" -type f -name "$bin" | head -1)
    [[ -n $found ]] || { warn "$tool: binário não encontrado no pacote"; return 1; }
    install -m 755 "$found" "$DEVKIT_BIN/$bin"
  else
    install -m 755 "$tmp/asset" "$DEVKIT_BIN/$bin"
  fi
  ok "$tool $(basename "$url")"
)
