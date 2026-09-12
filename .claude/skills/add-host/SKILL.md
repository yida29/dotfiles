---
name: add-host
description: Onboard a new machine into the dotfiles fleet. Use when the user mentions a new PC/laptop they want to share configuration with, or asks to "set up dotfiles on a new machine".
---

# add-host

Use the canonical `install.sh` for a fresh host; there is no separate
AstroNvim clone or hand-maintained bootstrap recipe. Existing hosts use
the targeted update procedure in `../deploy/SKILL.md`.

## Prerequisites and safety

- Working SSH access and a local console on the new machine.
- Git, curl, Python 3, fish, tmux, and Neovim supported by current
  LazyVim. For the SKK pad, Vim ≥ 9.1.1646 and Deno are required (the
  installer installs Deno). Check actual versions; distribution packages
  may be too old. The installer does not install all prerequisites.
- macOS: Xcode Command Line Tools, Homebrew and iTerm2 installed first.
  The hotkey profile expects Homebrew Vim at `/opt/homebrew/bin/vim`.
  Linux: on Debian/Ubuntu, `apt`, sudo access, `tar`, `gzip`, and `unzip`;
  systemd user services are needed for automatic docserver startup.
- Review `install.sh` and preserve existing dotfiles before running:
  it installs tools/plugins, starts services and changes global Git/CLI
  settings. Backup-preserving config links do not make all its other
  operations non-destructive.
- On macOS, save sessions and obtain approval to quit iTerm2 before
  installation writes preferences. Never edit/pull its plist while the
  app runs. Use the deploy skill's exact-PID procedure if termination is
  necessary; do not automatically shut down GUI applications.

## 1. Register the host

`config/sshs/hosts.json` is the source of truth. Choose a unique SSH alias
(currently `stb`, `ep`, `home`, `home2`, `ubuntu`; never `local`) and add:

- `tailscale_name`: the machine's Tailscale name.
- `local_hostname`: the actual short hostname when it differs from the
  Tailscale name; verify with `hostname` on the new machine.
- `color`: an RGB triplet string; `forward_port`: a unique available port.
- Optional `docserver_root`: a host-specific document root when `~/work`
  is not appropriate.

Add or carefully merge the SSH entry on every relevant client, including
the new host for other fleet members; preserve existing SSH settings:

```sshconfig
Host <alias>
    HostName <ip-or-tailscale-name>
    User <username>
```

Validate the JSON with `python3 -m json.tool config/sshs/hosts.json`.
Review, commit and push only the intended registry change before cloning
on the new host. The deploy workflow derives targets automatically; no
hard-coded host loop needs updating. Keep CLAUDE.md's descriptive OS table
accurate if needed.

## 2. Clone and install

Use an existing GitHub SSH key where possible. If creating one, choose an
unused filename and do not overwrite existing keys; register only its
public key with GitHub. HTTPS cloning is also supported.

On the new machine, after prerequisites and the iTerm2 safety check:

```sh
mkdir -p ~/work &&
git clone git@github.com:yida29/dotfiles.git ~/work/dotfiles &&
cd ~/work/dotfiles &&
bash install.sh
```

If the checkout already exists, stop and inspect it rather than cloning
over it, stashing or resetting. For another checkout location, run
`DOTFILES_DIR="$PWD" bash install.sh` from its root and account for that
path in future deployments.

The installer:

- Links tracked Neovim entry/bootstrap/options and plugin files, backing
  up replaced local config and conflicting `init.vim`. Helpers
  `backup_config(target)` / `link_config(source, target)` preserve
  nonmatching files, directories and symlinks at
  `<target>.backup.XXXXXX/original`; matching symlinks are no-ops.
  No untracked LazyVim template or manual
  clipboard/neovide require lines are needed; tracked `lazy.lua` disables
  `netrwPlugin`.
- Links `.vimrc` and the compatibility entry
  `~/.config/vim-ime/vimrc` used by the existing iTerm2 command. IME Enter
  commit, autosave and hira startup affect only `~/Documents/ime-scratch`,
  not ordinary Vim buffers.
- Preserves an existing real `~/.hammerspoon` directory in a backup before
  linking it on macOS. Its watcher resolves `hs.configdir` using
  `hs.fs.pathToAbsolute`.
- Links `fish/functions/neovide.fish`; there are no installer links to
  nonexistent `.ctags`, `.ctags.d` or `fish_prompt.fish` sources. Installs
  `jq` before starting docserver.
- Seeds per-host Claude settings from `.claude/settings.json.example`,
  not a shared symlink. SKK learning remains per-host (`~/.skkeleton`);
  `.skk/userJisyo` is ignored and must not be linked as shared learning.

On macOS, launch Hammerspoon after installation, grant Accessibility
permission and manually Reload Config once. Linux skips Hammerspoon,
iTerm2 preferences and the GUI IME hand-off.

## 3. Verify

Run these on the new host; no hard-coded deployment target is needed:

```sh
cd ~/work/dotfiles &&
git status --short &&
git log -1 --oneline
```

- Confirm HEAD matches the reviewed pushed commit and inspect symlink
  targets/backups. Preserve and reconcile any previous host customizations.
- Start Neovim, allow lazy.nvim/LazyVim bootstrap to finish, and check
  plugin loading. Restart existing editor sessions after config changes.
- Test the IME pad separately from ordinary Vim file editing: only the
  scratch file should get Enter commit/autosave/hira startup.
- Confirm local identity uniquely matches the registry and SSH access
  works from relevant clients. Unknown identity must block deployment.
- Confirm docserver is running and responds at `127.0.0.1` on this host's
  registry port; inspect launchd/systemd status if not.

Existing test suites (install busted separately if needed):

```sh
# macOS Hammerspoon helpers
cd ~/work/dotfiles/.hammerspoon && busted test/
# Vim helpers and isolated real-vimrc scope regressions
~/.vim/pack/plugins/start/vim-themis/bin/themis ~/work/dotfiles/.vim/test/
```

These do not validate window focus or GUI reloads; verify those manually
without discarding active sessions.
