export GOENV_ROOT=$HOME/.goenv
export PATH=$GOENV_ROOT/bin:$PATH
command -v goenv >/dev/null && eval "$(goenv init -)"
export PATH="$HOME/.nodenv/bin:$PATH"
command -v nodenv >/dev/null && eval "$(nodenv init -)"
export PATH="$HOME/.pyenv/bin:$PATH"
command -v pyenv >/dev/null && eval "$(pyenv init -)"

[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"

# Editor
if command -v nvim >/dev/null; then
  export EDITOR='nvim'
  export VISUAL='nvim'
else
  export EDITOR='vim'
  export VISUAL='vim'
fi

# opencode
export PATH=$HOME/.opencode/bin:$PATH

# Added by Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"

# aqua (グローバルCLIツール管理) — node/codex等をバージョン固定で一元管理
export AQUA_GLOBAL_CONFIG="$HOME/.config/aquaproj-aqua/aqua.yaml"
export PATH="$HOME/.local/share/aquaproj-aqua/bin:$PATH"

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

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/yida/.lmstudio/bin"
# End of LM Studio CLI section

export PATH="$HOME/.local/bin:$PATH"

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<
