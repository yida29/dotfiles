set -gx VOLTA_HOME "$HOME/.volta"
set -gx PATH \
  $HOME/.local/bin \
  $HOME/.local/share/aquaproj-aqua/bin \
  $HOME/.claude/local \
  "$VOLTA_HOME/bin" \
  /opt/homebrew/bin \
  $PATH
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
if test -f ~/.jira_token
  set -gx JIRA_API_TOKEN (cat ~/.jira_token)
end

function cc
  claude --dangerously-skip-permissions $argv
end
function ccr
  claude --dangerously-skip-permissions --resume $argv
end
function claude
  if test -x $HOME/.local/bin/claude
    $HOME/.local/bin/claude $argv
  else if test -x $HOME/.local/share/aquaproj-aqua/bin/claude
    $HOME/.local/share/aquaproj-aqua/bin/claude $argv
  else if test -x /Users/yida/.volta/tools/image/node/24.9.0/bin/claude
    /Users/yida/.volta/tools/image/node/24.9.0/bin/claude $argv
  else if test -x /opt/homebrew/bin/claude
    /opt/homebrew/bin/claude $argv
  else
    command claude $argv
  end
end
function cx
   codex --dangerously-bypass-approvals-and-sandbox $argv
end
function cop
  COPILOT_MODEL=gpt-5.2 copilot --allow-all-tools --banner $argv
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

function prossm
    set target (aws ec2 describe-instances \
        --filter "Name=instance-state-name,Values=running" "Name=tag:Role,Values=gui-bastion" \
        --query "Reservations[*].Instances[*].{Instance:InstanceId}" \
        --output text \
        --profile aws-jse \
        --region ap-northeast-1)
    aws --profile=aws-jse ssm --region=ap-northeast-1 start-session --target $target
end

function devssm
    set target (aws ec2 describe-instances \
        --filter "Name=instance-state-name,Values=running" "Name=tag:Role,Values=gui-bastion" \
        --query "Reservations[*].Instances[*].{Instance:InstanceId}" \
        --output text \
        --profile aws-jse-dev \
        --region ap-northeast-1)
    aws --profile=aws-jse-dev --region=ap-northeast-1 ssm start-session --target $target
end


# ghq + fzf + tmux
function repo
  set selected (ghq list --full-path | fzf --preview "ls -la {}")
  if test -z "$selected"
    return
  end

  set session_name (basename "$selected" | tr "." "_")
  set current_session (tmux display-message -p "#S" 2>/dev/null)

  if set -q TMUX
    if test "$session_name" = "$current_session"
      cd "$selected"
    else if tmux has-session -t="$session_name" 2>/dev/null
      tmux switch-client -t "$session_name"
    else
      tmux new-session -d -s "$session_name" -c "$selected"
      tmux switch-client -t "$session_name"
    end
  else
    if tmux has-session -t="$session_name" 2>/dev/null
      tmux attach -t "$session_name"
    else
      tmux new-session -s "$session_name" -c "$selected"
    end
  end
end
