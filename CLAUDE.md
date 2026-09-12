# dotfiles

Personal dotfiles for `yida29@github`. Fleet membership is defined by
`config/sshs/hosts.json` (currently `stb`, `ep`, `home`, `home2`, `ubuntu`).
`local` means the current machine, not an SSH alias. Hosts normally hold
their own clone at `~/work/dotfiles/`; the installer also accepts
`DOTFILES_DIR`. Updates are shared through Git.

This file is read by Claude Code when working in `~/work/dotfiles/`. Skim it
before editing anything; quite a few things here have hard-won subtle
behaviours that look fine but break in surprising ways if you guess.

## Tour

```
.config/nvim/        Self-contained LazyVim editor (used for coding):
                     tracked init.lua, lazy.lua, options.lua and plugins.
.config/vim-ime/     Compatibility vimrc sourcing ~/.vimrc for the
                     existing iTerm2 command; no plist change needed.
.hammerspoon/        macOS app glue. Currently: nvim-ime/vim-ime focus
                     hand-off, EmmyLua spoon for hs.* completion. Pure
                     helpers in lib/ime.lua, busted tests in test/.
.skk/                SKK dictionaries (SKK-JISYO.L is downloaded by
                     install.sh; userJisyo is ignored, not shared).
.vim/                Plugins / autoload / tests for the vim-ime pad.
                     symlinks into ~/.vim/ are created by install.sh.
.vimrc               Vim + SKK input pad. Enter commit, autosave and hira
                     startup are scoped to ~/Documents/ime-scratch;
                     ordinary Vim file editing remains safe.
.claude/             Claude Code config. User settings are seeded from
                     settings.json.example, not symlinked; mutable
                     settings remain local to each host.
bin/                 Personal scripts. sshs (multi-host iTerm2 fan-out)
                     and docserver (per-host static doc server, 127.0.0.1
                     only, used together with sshs's per-host -L).
config/              Plain-data config consumed by bin/ scripts and OS
                     service managers. sshs/hosts.json (host registry —
                     alias, Tailscale name, tab color, forward_port,
                     optional local_hostname and docserver_root).
                     launchd/ and systemd/
                     hold the docserver service definitions; install.sh
                     symlinks them and bootstraps via launchctl /
                     systemctl --user. The docserver process binds to
                     127.0.0.1 so the only way to reach it from another
                     machine is the ssh -L tunnel sshs sets up.
fish/, zsh/          Shell config. Both export EDITOR=nvim.
iterm2/              iTerm2 preferences plist. iTerm2 reads/writes here
                     via PrefsCustomFolder.
lazygit/             Lazygit config.
tmux/                tmux.conf. truecolor is enabled.
install.sh           Run on a fresh host to symlink everything into
                     place + clone needed plugins.
```

## Hosts and what only works where

| Feature                 | macOS (`stb`, `home`, `ep`) | Linux (`home2`, `ubuntu`) |
|-------------------------|----------------------------|--------------------------|
| Neovim (LazyVim)         | ✅                         | ✅                       |
| vim-ime GUI hand-off     | ✅                         | ❌                       |
| Hammerspoon / iTerm2     | ✅                         | ❌                       |

The registry, not this descriptive table, determines deployment targets.
Match the current hostname against `local_hostname` / `tailscale_name`,
with Tailscale identity as a fallback. Stop if identity is unknown or
ambiguous; never guess or SSH back into the current host.

## Editing rules

**Always pause and check before doing any of these:**

- **Editing `iterm2/com.googlecode.iterm2.plist`** — iTerm2 reads/writes
  the same file via `PrefsCustomFolder`, so plist changes made while
  iTerm2 is running get clobbered on its next quit. Prefer the iTerm2 UI
  for live settings. Before direct file/defaults edits or a pull touching
  the plist, save sessions and get approval to quit iTerm2. If termination
  is needed, identify and recheck exact iTerm2 PIDs, obtain approval, and
  signal only those PIDs; force-killing needs explicit approval. Verify
  it is stopped first. Do not disrupt active sessions automatically.

- **Editing `.hammerspoon/init.lua`** — there is now a pathwatcher on
  the resolved target of `hs.configdir` (normally `~/.hammerspoon/`,
  resolved with `hs.fs.pathToAbsolute`) that auto-reloads on `.lua`
  changes (including nonstandard checkout locations), BUT
  it has to have been picked up by an earlier reload first. After the
  *very first* deploy of a new init.lua, the user still has to manually
  Reload Config from the Hammerspoon menu bar. Subsequent changes will
  reload themselves.

- **Editing `.config/nvim/lua/plugins/*.lua`** — Neovim doesn't pick up
  changes in already-running sessions; restart `nvim` to see them.
  `lua/config/*.lua` (e.g. `neovide.lua`, `clipboard.lua`) is symlinked
  the same way and loads earlier than plugin specs — anything that has to
  be set before lazy.nvim starts (neovide font, OSC 52 clipboard
  override, etc.) belongs there, required from
  tracked `.config/nvim/lua/config/options.lua`. The installer links the
  entry point, bootstrap and config files, backing up existing local
  files before replacement, including a conflicting `init.vim`.
  `options.lua` already requires clipboard
  and, when running Neovide, neovide settings.
  `clipboard.lua` no-ops on local hosts and only kicks in over SSH; the
  full OSC 52 path also needs `set-clipboard on` + `allow-passthrough on`
  on every tmux layer (already in `tmux/tmux.conf`, but `home2`'s tmux
  3.2a skips passthrough — OSC 52 from inside a nested tmux there will
  not reach the outer terminal).
  Tracked `.config/nvim/lua/config/lazy.lua` keeps `netrwPlugin` in
  `disabled_plugins`, so netrw doesn't open a second buffer next to
  neo-tree when you `nvim ./somedir`. No out-of-band template edits.

- **Renaming or deleting a tracked file** — check whether `install.sh`
  references it. Deleting a symlink target without removing the
  corresponding `ln -sf` line in install.sh leaves dangling links on
  the next deploy.

- **SKK learning is per-host.** `~/.skkeleton` is local learning state;
  `.skk/userJisyo` is ignored, not shared. Never add learned dictionaries
  to an unrelated commit or automatically stash/reset local work.

- **`~/.hammerspoon` may already be a real directory.** Use the
  installer's `link_config(source, target)` helper, which uses
  `backup_config(target)` to preserve nonmatching files, directories or
  symlinks at `<target>.backup.XXXXXX/original`. Matching links are no-ops.
  Don't nest a symlink inside an existing directory or delete its config.

## Deploy

Use `.claude/skills/deploy/SKILL.md` for registry-derived targets and
failure-preserving commands. The pattern across all hosts:

1. Make changes locally.
2. Review and commit only intended changes, then push.
3. Detect the actual local host and exclude it. Inspect each remote's
   status; stop on dirty work rather than stashing/resetting. Fetch,
   review incoming changes and fast-forward only, then verify HEAD.

Things that need extra steps after `git pull`:

- **iTerm2 plist changes** — follow the approval/quit checks above
  before the pull. If necessary, inspect cached values in
  `~/Library/Preferences/com.googlecode.iterm2.plist` while stopped;
  patch only reviewed keys, not the entire host-specific preferences.

- **New Vim plugin or test framework added** — the plugin/test runner
  has to be cloned into `~/.vim/pack/plugins/start/`. install.sh has
  the canonical clone commands; lift them out and run them manually,
  don't run install.sh in full on an existing host: it also installs
  tools, restarts services and changes global settings.

- **New managed files / bootstrap changes** — pulling doesn't create
  new home-directory links. Apply the relevant `install.sh` config
  blocks and their backup-preserving helpers (not by sourcing the full
  script), including the Vim compatibility entry and Neovim bootstrap
  when first introduced. Preserve and review backed-up host settings.

- **Service changes** — refresh the relevant service manager; for
  Linux docserver unit changes, `systemctl --user daemon-reload` is
  required. Coordinate any needed restart with the user.

- **iTerm2 profile structural changes (Custom Command, fonts, GUID-
  scoped warning suppressions)** — those settings live in the plist
  itself and ride along with the file, but `defaults`-only keys like
  `NeverWarnAboutShortLivedSessions_<GUID>` don't sync via
  PrefsCustomFolder. install.sh has a `defaults write` block for those.

## Testing

```sh
# Hammerspoon pure helpers (busted, lua + luarocks via brew)
cd ~/work/dotfiles/.hammerspoon && busted test/

# Vim helpers and real-vimrc scope regression tests (vim-themis)
~/.vim/pack/plugins/start/vim-themis/bin/themis ~/work/dotfiles/.vim/test/
```

Hammerspoon tests cover window classification and target selection,
not `hs.*` integration. The Vim suite also includes
`.vim/test/vim_ime_scope.vimspec`, which loads the real `.vimrc` in isolated
Vim processes to check scratch-pad versus ordinary-buffer behavior.

Run the relevant suite when changing helpers or `.vimrc`. Window focus,
GUI reloads and live SKK/clipboard integration still need manual runtime
checks by reloading Hammerspoon / restarting Vim.

## Commit style

- Subject line under 72 chars, imperative voice ("Add X", "Fix Y").
- Body: explain the *why*. The *what* is in the diff.
- Reference unfamiliar plumbing (e.g. `pathwatcher`, `denops`) with a
  one-line gloss when it shows up in the message — past-self forgets
  this stuff fast.
- Co-Author trailer for Claude:
  `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`

## Skills

Reusable workflows live under `.claude/skills/`. Each is a directory
containing a `SKILL.md`. Today there are:

- **deploy** — update registry-derived remote hosts, preserving dirty
  work and coordinating any required GUI shutdown.
- **add-host** — onboard a new machine into the dotfiles fleet.

When a request looks like "deploy this everywhere" or "set up dotfiles
on a new machine", use these skills as the playbook.
