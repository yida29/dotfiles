set -gx VOLTA_HOME "$HOME/.volta"
set -gx PATH "$VOLTA_HOME/bin" $PATH
set -gx PATH $HOME/.claude/local $PATH
set -gx PATH /opt/homebrew/bin $PATH
fish_add_path /opt/homebrew/opt/postgresql@16/bin
starship init fish | source

if test -f ~/.backlog_domain
  set -gx BACKLOG_DOMAIN (cat ~/.backlog_domain)
end
if test -f ~/.backlog_key
  set -gx BACKLOG_API_KEY (cat ~/.backlog_key)
end
if test -f ~/.gemini_key
  set -gx GEMINI_API_KEY (cat ~/.gemini_key)
end

function cc
  claude --dangerously-skip-permissions --resume $argv
end
function cx
   codex --dangerously-bypass-approvals-and-sandbox $argv
end
function cop
  COPILOT_MODEL=gpt-5 copilot --allow-all-tools --banner $argv
end
function ge
  gemini --model gemini-3-pro --yolo $argv
end

# Neovide aliases
alias nv='nvim'
alias nvi='neovide'

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /Users/yida/.lmstudio/bin
# End of LM Studio CLI section

