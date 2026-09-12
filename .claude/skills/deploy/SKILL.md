---
name: deploy
description: Deploy committed dotfiles changes to remote hosts from config/sshs/hosts.json. Use when the user says "deploy this", "push to other hosts", or "他のPCにも反映".
---

# deploy

Update the registry-defined fleet, excluding the actual current machine.
The canonical checkout is `~/work/dotfiles`; `local` is not an SSH alias.
Do not maintain a separate hard-coded host list.

## Before pulling

1. Review local changes and commit only what the user intended, then
   push. Never automatically stash, reset, or include unrelated changes.
   SKK learning is per-host; `.skk/userJisyo` is ignored, not shared.
2. Inspect incoming changes on each host before applying them. Stop on
   dirty work, divergent history, unknown local identity, or SSH/Git
   failure. Do not hide failures behind `tail` or other pipelines.
3. If an update touches the iTerm2 plist, follow the GUI procedure below
   **before pulling**. Other Lua changes can reload Hammerspoon immediately;
   coordinate changes affecting active IME sessions.

## Registry-derived update

Run this from the local checkout in Bash. It requires Python 3 and working
SSH aliases on this client. It matches `local_hostname` / `tailscale_name`
against the current hostname, falling back to Tailscale's self identity.
Unknown or ambiguous identity stops deployment rather than risking self-SSH.
The example uses the canonical remote path; review any host-specific
`DOTFILES_DIR` overrides before adapting it.

```sh
cd ~/work/dotfiles && python3 - <<'PY'
import json
import re
import socket
import subprocess
from pathlib import Path

def output(*args):
    return subprocess.check_output(args, text=True).strip()

def short(name):
    return name.lower().rstrip(".").split(".")[0]

hosts = json.loads(Path("config/sshs/hosts.json").read_text())["hosts"]
if not hosts or any(not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", h) for h in hosts):
    raise SystemExit("Invalid or empty host registry; stop and fix it.")

def matches(names):
    names = {short(n) for n in names if n}
    return [
        alias for alias, host in hosts.items()
        if names.intersection(short(host[k]) for k in ("local_hostname", "tailscale_name") if host.get(k))
    ]

local = matches([socket.gethostname()])
if not local:
    try:
        own = json.loads(output("tailscale", "status", "--json"))["Self"]
        local = matches([own.get("HostName"), own.get("DNSName")])
    except (OSError, subprocess.CalledProcessError, ValueError, KeyError):
        raise SystemExit("Cannot identify local host; fix registry local_hostname/Tailscale first.")
if len(local) != 1:
    raise SystemExit("Unknown or ambiguous local host; stop and fix the registry.")
print("Excluding local host:", local[0], flush=True)

if output("git", "status", "--porcelain"):
    raise SystemExit("Local worktree is dirty; preserve and review it before deployment.")
subprocess.run(["git", "fetch", "origin"], check=True)
expected = output("git", "rev-parse", "HEAD")
if expected != output("git", "rev-parse", "@{upstream}"):
    raise SystemExit("Local HEAD differs from upstream; review and push/synchronize first.")

remote = r'''
set -eu
cd "$HOME/work/dotfiles"
dirty=$(git status --porcelain)
if [ -n "$dirty" ]; then
  printf '%s\n' "$dirty" >&2
  echo "Dirty remote worktree; preserve it and stop." >&2
  exit 1
fi
git fetch origin
git log --oneline HEAD..'@{upstream}'
git diff --stat HEAD '@{upstream}'
if git diff --quiet HEAD '@{upstream}' -- iterm2/com.googlecode.iterm2.plist; then
  :
else
  echo "Plist differs (or diff failed): stop for review and approved iTerm2 shutdown." >&2
  exit 1
fi
git -c merge.autostash=false -c rebase.autostash=false pull --ff-only
'''
for alias in hosts:
    if alias == local[0]:
        continue
    print(f"=== {alias} ===", flush=True)
    subprocess.run(["ssh", "-o", "BatchMode=yes", alias, remote], check=True)
    actual = output("ssh", "-o", "BatchMode=yes", alias,
                    'cd "$HOME/work/dotfiles" && git rev-parse HEAD')
    if actual != expected:
        raise SystemExit(f"{alias}: unexpected HEAD; stop and inspect its upstream.")
PY
```

For a plist update this intentionally stops before the pull. Use only the
alias identified by this registry-driven run, review that host's changes
and complete the GUI procedure. After confirming a clean worktree and
stopped iTerm2, fast-forward that host, then rerun the registry check.
Do not bypass the guard for unattended deployment.

## iTerm2 safety

- Prefer live settings changes through the iTerm2 UI. Never directly
  edit/defaults-write or pull `iterm2/com.googlecode.iterm2.plist` while
  iTerm2 is running: its in-memory copy can overwrite the new file.
- Inspect `ps -axo pid,comm` on the affected Mac to identify the exact
  iTerm2 application PIDs. Ask the user to save sessions and approve
  quitting. Prefer a normal GUI quit; arrange a separate connection if
  the deployment terminal would close.
- If process termination is necessary, recheck each exact PID and get
  approval before `kill <approved-pid>`. Do not use name-wide termination
  or force-kill without explicit approval. Verify the app has stopped.
- After the pull, inspect cached keys in
  `~/Library/Preferences/com.googlecode.iterm2.plist` if needed, and patch
  only the reviewed keys while stopped. Profile-specific `defaults` keys
  such as `NeverWarnAboutShortLivedSessions_<GUID>` need the corresponding
  reviewed installer step; they do not sync through PrefsCustomFolder.
- Inspect shared plist changes for host-specific absolute paths before
  committing them. Reopen iTerm2 only when the stopped-app edits are done.

## Extra steps and verification

| Change | Follow-up |
|--------|-----------|
| Existing linked Lua/Vim/shell files | Pull updates the files; restart affected editors/shells as appropriate. |
| New managed files / initial Neovim bootstrap | Apply only the relevant config blocks from `install.sh`, including its backup-preserving helpers. Do not source the whole script. Back up conflicting `init.vim`; link tracked `init.lua`, `lua/config/lazy.lua`, `options.lua`, other config/plugins, and the Vim compatibility entry `~/.config/vim-ime/vimrc` when first introduced. |
| Existing local config at a new link destination | Use `backup_config(target)` / `link_config(source, target)`: nonmatching files/directories/symlinks are preserved at `<target>.backup.XXXXXX/original`; matching links are no-ops. Review/merge host customizations. Never nest a link inside a real `~/.hammerspoon` directory. |
| New Vim plugins/tests | Use the canonical installer clone/link steps; inspect existing plugin directories instead of overwriting them. |
| Hammerspoon Lua / watcher changes | First deployment needs manual Reload Config. Thereafter the watcher uses the resolved `~/.hammerspoon` target, including custom checkout paths. |
| docserver service definitions | Linux needs `systemctl --user daemon-reload`; coordinate a restart if needed. On macOS use the relevant reviewed launchd steps. Confirm the service responds on its registry port at `127.0.0.1`. |

Do not blindly run the full installer on existing hosts: it installs tools,
restarts services, writes iTerm2 preferences and changes global settings.
It is the canonical fresh-host bootstrap, not a side-effect-free updater.
Claude settings remain per-host copies seeded from
`.claude/settings.json.example`; do not replace them with symlinks.

Verify deployed commit IDs, actual link targets and affected runtime
behavior, not just file contents. Neovim needs a restart; test both the
IME scratch pad and ordinary Vim editing when `.vimrc` changes. Run the
relevant existing suites for code changes; the Vim suite includes isolated
real-vimrc scope regressions in `.vim/test/vim_ime_scope.vimspec`.
Report blocked hosts and
manual steps explicitly rather than claiming the entire fleet is updated.
