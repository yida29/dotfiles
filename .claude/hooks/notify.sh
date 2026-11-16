#!/usr/bin/env bash
# Notification hook: desktop notification when Claude Code is waiting.
#   macOS        -> osascript (Notification Center)
#   Windows/WSL  -> PowerShell WinRT toast
# Body is the hook's .message (e.g. "Claude needs your permission to use
# Bash"), falling back to a fixed line.
input=$(cat)
title="Claude Code"
body=$(printf '%s' "$input" | jq -r '.message // empty' 2>/dev/null)
[ -n "$body" ] || body="Claude Codeが入力待ちです"

if command -v osascript >/dev/null 2>&1; then
  # argv instead of string interpolation so quotes in the message are safe.
  osascript -e 'on run argv' \
    -e 'display notification (item 2 of argv) with title (item 1 of argv)' \
    -e 'end run' "$title" "$body" >/dev/null 2>&1
elif command -v powershell.exe >/dev/null 2>&1; then
  ps_quote() { printf "'%s'" "${1//\'/\'\'}"; }
  script="
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
\$x = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
\$t = \$x.GetElementsByTagName('text')
\$t.Item(0).AppendChild(\$x.CreateTextNode($(ps_quote "$title"))) | Out-Null
\$t.Item(1).AppendChild(\$x.CreateTextNode($(ps_quote "$body"))) | Out-Null
\$aumid = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe'
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier(\$aumid).Show([Windows.UI.Notifications.ToastNotification]::new(\$x))
"
  # -EncodedCommand (UTF-16LE base64) keeps Japanese text and quoting intact
  # across the WSL -> Windows boundary.
  enc=$(printf '%s' "$script" | iconv -f UTF-8 -t UTF-16LE | base64 -w0)
  # PowerShell takes ~1s to start; don't block Claude Code on it. Run from a
  # Windows path so it doesn't warn about a UNC cwd.
  (cd /mnt/c && setsid powershell.exe -NoProfile -NonInteractive -EncodedCommand "$enc" >/dev/null 2>&1 &)
fi
exit 0
