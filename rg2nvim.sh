#!/usr/bin/env bash
# rg2nvim.sh — ripgrep → fzf (vim keybindings) → open in neovim at exact line
#
# Usage:
#   ./rg2nvim.sh [PATTERN] [RG_OPTIONS...]
#   ./rg2nvim.sh            (interactive: fzf starts empty, type to search live)

set -euo pipefail

# dependencies check
for cmd in rg fzf nvim; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' is not installed or not in PATH." >&2
    exit 1
  fi
done

# config
PATTERN="${1:-}"
shift 2>/dev/null || true          # remaining args forwarded to rg

RG_CMD=(rg --color=always --line-number --no-heading --smart-case "$@")

if [[ -n "$PATTERN" ]]; then
  # static mode: run rg once, browse results in fzf
  SELECTED=$(
    "${RG_CMD[@]}" -- "$PATTERN" 2>/dev/null \
    | fzf \
        --ansi \
        --delimiter=':' \
        --preview='
          file={1}; line={2}
          bat --color=always --highlight-line "$line" \
              --style=numbers,changes "$file" 2>/dev/null \
          || grep -n "" "$file" \
          | sed -n "$((line>5 ? line-5 : 1)),$((line+20))p"
        ' \
        --preview-window='right:55%:wrap' \
        --bind='ctrl-/:toggle-preview' \
        --bind='j:down,k:up,ctrl-d:half-page-down,ctrl-u:half-page-up' \
        --bind='ctrl-f:page-down,ctrl-b:page-up' \
        --bind='alt-g:first,alt-G:last' \
        --header='[ENTER] open in nvim  [alt-g/G] first/last  [ctrl-/] preview  [ESC] quit' \
        --prompt="rg/$PATTERN> "
  )
else
  # live/interactive mode: fzf drives rg
  SELECTED=$(
    fzf \
      --ansi \
      --disabled \
      --delimiter=':' \
      --bind="change:reload:${RG_CMD[*]} -- {q} 2>/dev/null || true" \
      --preview='
        file={1}; line={2}
        bat --color=always --highlight-line "$line" \
            --style=numbers,changes "$file" 2>/dev/null \
        || grep -n "" "$file" \
        | sed -n "$((line>5 ? line-5 : 1)),$((line+20))p"
      ' \
      --preview-window='right:55%:wrap' \
      --bind='ctrl-/:toggle-preview' \
      --bind='j:down,k:up,ctrl-d:half-page-down,ctrl-u:half-page-up' \
      --bind='ctrl-f:page-down,ctrl-b:page-up' \
      --bind='alt-g:first,alt-G:last' \
      --header='[TYPE] live search  [ENTER] open in nvim  [alt-g/G] first/last  [ctrl-/] preview  [ESC] quit' \
      --prompt='rg> '
  )
fi

# open in neovim
if [[ -n "$SELECTED" ]]; then
  FILE=$(echo "$SELECTED" | cut -d':' -f1)
  LINE=$(echo "$SELECTED" | cut -d':' -f2)
  nvim +"$LINE" -- "$FILE"
fi
