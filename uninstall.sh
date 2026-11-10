#!/usr/bin/env bash
# Desfaz a configuração do devkit: restaura o último backup do ~/.zshrc,
# remove o comando `devkit` e os plugins. Pacotes instalados ficam.
set -euo pipefail

DEVKIT_HOME=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
. "$DEVKIT_HOME/lib/common.sh"

[[ ${1:-} == --dry-run ]] && DRY_RUN=1

step "Restaurando ~/.zshrc"
backup=$(find "$HOME" -maxdepth 1 -name '.zshrc.devkit-backup-*' 2>/dev/null | sort | tail -1)
if [[ -n $backup ]]; then
  run cp "$backup" "$HOME/.zshrc"
  ok "restaurado de $backup"
elif grep -q 'gerado pelo devkit' "$HOME/.zshrc" 2>/dev/null; then
  run rm -f "$HOME/.zshrc"
  warn "não havia backup; ~/.zshrc removido"
fi

step "Removendo arquivos do devkit"
run rm -f "$DEVKIT_BIN/devkit"
run rm -rf "$DEVKIT_DATA"
ok "comando e plugins removidos"
warn "suas personalizações continuam em $DEVKIT_CONFIG (apague se não quiser)"
