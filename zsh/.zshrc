export GOENV_ROOT=$HOME/.goenv
export PATH=$GOENV_ROOT/bin:$PATH
eval "$(goenv init -)"
export PATH="$HOME/.nodenv/bin:$PATH"
eval "$(nodenv init -)"
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"

. "$HOME/.local/bin/env"

# opencode
export PATH=$HOME/.opencode/bin:$PATH

# Added by Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"

# ghq + fzf + tmux
function repo() {
  local selected=$(ghq list --full-path | fzf --preview 'ls -la {}')
  if [[ -z "$selected" ]]; then
    return
  fi

  local session_name=$(basename "$selected" | tr '.' '_')
  local current_session=$(tmux display-message -p '#S' 2>/dev/null)

  if [[ -n "$TMUX" ]]; then
    if [[ "$session_name" == "$current_session" ]]; then
      cd "$selected"
    elif tmux has-session -t="$session_name" 2>/dev/null; then
      tmux switch-client -t "$session_name"
    else
      tmux new-session -d -s "$session_name" -c "$selected"
      tmux switch-client -t "$session_name"
    fi
  else
    if tmux has-session -t="$session_name" 2>/dev/null; then
      tmux attach -t "$session_name"
    else
      tmux new-session -s "$session_name" -c "$selected"
    fi
  fi
}

# マシン固有の設定（APIキー等）
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
