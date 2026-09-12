# =============================================================================
# Environment Variables
# =============================================================================

set -gx VOLTA_HOME "$HOME/.volta"

# aqua (グローバルCLIツール管理) — 全ツールがこのグローバル設定を参照する
set -gx AQUA_GLOBAL_CONFIG "$HOME/.config/aquaproj-aqua/aqua.yaml"

# =============================================================================
# PATH
# =============================================================================

set -gx PATH \
    $HOME/.local/bin \
    $HOME/.claude/local \
    "$VOLTA_HOME/bin" \
    /opt/homebrew/bin \
    $HOME/.lmstudio/bin \
    $PATH \
    $HOME/.local/share/aquaproj-aqua/bin

fish_add_path /opt/homebrew/opt/postgresql@16/bin

# =============================================================================
# API Keys (loaded from dotfiles)
# =============================================================================

if test -f ~/.backlog_domain
    set -gx BACKLOG_DOMAIN (cat ~/.backlog_domain)
end
if test -f ~/.backlog_key
    set -gx BACKLOG_API_KEY (cat ~/.backlog_key)
end
if test -f ~/.jira_token
    set -gx JIRA_API_TOKEN (cat ~/.jira_token)
end

# =============================================================================
# Prompt
# =============================================================================

starship init fish | source

# =============================================================================
# AI Tools
# =============================================================================

function claude
    # 探索順は従来どおり (IDE 等の同名ラッパーを踏まないよう実体を直接叩く)
    set -l bin
    for c in $HOME/.local/bin/claude \
             $HOME/.local/share/aquaproj-aqua/bin/claude \
             /Users/yida/.volta/tools/image/node/24.9.0/bin/claude \
             /opt/homebrew/bin/claude
        if test -x $c
            set bin $c
            break
        end
    end
    test -z "$bin"; and set bin claude

    # OpenTelemetry 送信。送信先は ~/work/claude-code-telemetry の docker-compose が
    # 立てるローカル collector。bash/zsh 版 setup/claude-telemetry.sh の fish 相当。
    # 計測せずに起動したいとき:  env -u CLAUDE_CODE_ENABLE_TELEMETRY claude
    #
    # ponytail: 送信間隔は 10s のまま。対話セッションは分単位なので届くが、数秒で
    # 終わる `claude -p` は flush 前に終了して送信されない (実測)。headless も
    # 計測したくなったら OTEL_METRIC_EXPORT_INTERVAL を下げる。
    set -l project unknown
    set -l branch unknown

    # git 管理外で ~/.gitconfig の remote.origin.url を拾わないよう、リポジトリ内
    # 判定を先に置き、git config には --local を必ず付ける。
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1
        set -l url (git config --local --get remote.origin.url)
        if test -n "$url"
            # clone 先や worktree のディレクトリ名は環境ごとに割れるので remote 名を優先
            set project (string replace -r '\.git$' '' (basename $url))
        else
            set project (basename (git rev-parse --show-toplevel))
        end
        # --abbrev-ref は detached HEAD で文字列 "HEAD" を返すので symbolic-ref を使う
        set -l b (git symbolic-ref --quiet --short HEAD 2>/dev/null)
        # OTEL_RESOURCE_ATTRIBUTES は key=value,... 形式なので , と = は潰す
        test -n "$b"; and set branch (string replace -ra '[^A-Za-z0-9._/-]' _ $b)
    end

    # OTEL_LOG_TOOL_DETAILS / OTEL_LOG_TOOL_CONTENT / OTEL_LOG_RAW_API_BODIES は
    # 意図的に設定しない (Bash コマンド全文・応答本文は送らない)。
    env \
        CLAUDE_CODE_ENABLE_TELEMETRY=1 \
        OTEL_METRICS_EXPORTER=otlp \
        OTEL_LOGS_EXPORTER=otlp \
        OTEL_EXPORTER_OTLP_PROTOCOL=grpc \
        OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317 \
        OTEL_METRIC_EXPORT_INTERVAL=10000 \
        OTEL_LOGS_EXPORT_INTERVAL=5000 \
        OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative \
        OTEL_LOG_USER_PROMPTS=1 \
        OTEL_RESOURCE_ATTRIBUTES="project=$project,branch=$branch" \
        $bin $argv
end

function cc
    CLAUDE_CODE_NO_FLICKER=1 HOMEBREW_NO_AUTO_UPDATE=1 claude --resume $argv
end

function cx
    codex --dangerously-bypass-approvals-and-sandbox $argv
end

function cop
    copilot --model gpt-6-astra --allow-all-tools --banner $argv
end

function agy
    # Antigravity CLI (successor to Gemini CLI).
    # ~/.local/bin/agy を直接叩いて、IDE の同名ラッパーを踏まない。
    if test -x $HOME/.local/bin/agy
        $HOME/.local/bin/agy --dangerously-skip-permissions $argv
    else
        command agy --dangerously-skip-permissions $argv
    end
end

function ge
    agy $argv
end

# =============================================================================
# Editor
# =============================================================================

set -gx EDITOR nvim
set -gx VISUAL nvim
alias nv='nvim'
alias nvi='neovide'

# =============================================================================
# ghq + fzf + tmux
# =============================================================================

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

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /Users/yida/.lmstudio/bin
# End of LM Studio CLI section
