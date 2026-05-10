# dotfiles

Personal dotfiles for `yida29@github`. Used across four hosts: a stanby
work Mac (`local`, the one you're usually editing on), a home Mac mini
(`home`), a Linux WSL2 box (`home2`), and an eco-pork Mac (`ep`). All
hosts hold their own clone of this repo at `~/dotfiles/` and live-share
state through plain `git pull`.

This file is read by Claude Code when working in `~/dotfiles/`. Skim it
before editing anything; quite a few things here have hard-won subtle
behaviours that look fine but break in surprising ways if you guess.

## Tour

```
.config/nvim/        AstroNvim/LazyVim mainline editor (used for coding)
.hammerspoon/        macOS app glue. Currently: nvim-ime/vim-ime focus
                     hand-off, EmmyLua spoon for hs.* completion. Pure
                     helpers in lib/ime.lua, busted tests in test/.
.skk/                SKK dictionaries (SKK-JISYO.L is downloaded by
                     install.sh; userJisyo is shared learned conversions).
.vim/                Plugins / autoload / tests for the vim-ime pad.
                     symlinks into ~/.vim/ are created by install.sh.
.vimrc               vim-ime config (SKK Japanese-input pad). Coding is
                     in nvim; .vimrc only exists to drive the iTerm2
                     hotkey window.
.claude/             Claude Code config. settings.json is shared between
                     user-level (~/.claude/) and project-level (this
                     repo) — touching it affects both.
bin/                 Personal scripts. sshs (multi-host iTerm2 fan-out)
                     and docserver (per-host static doc server, 127.0.0.1
                     only, used together with sshs's per-host -L).
config/              Plain-data config consumed by bin/ scripts and OS
                     service managers. sshs/hosts.json (host registry —
                     alias, Tailscale name, tab color, forward_port,
                     optional docserver_root). launchd/ and systemd/
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

| Feature                  | local | home | home2 | ep |
|--------------------------|-------|------|-------|----|
| Neovim (LazyVim)         | ✅    | ✅   | ✅    | ✅ |
| vim-ime (SKK pad)        | ✅    | ✅   | ⚠️ no GUI | ✅ |
| Hammerspoon              | ✅    | ✅   | ❌    | ✅ |
| iTerm2 + hotkey window   | ✅    | ✅   | ❌    | ✅ |

`home2` is Linux; everything macOS-specific (Hammerspoon, iTerm2 plist,
the IME-pad focus hand-off) is a no-op there.

## Editing rules

**Always pause and check before doing any of these:**

- **Editing `iterm2/com.googlecode.iterm2.plist`** — iTerm2 reads/writes
  the same file via `PrefsCustomFolder`, so plist changes made while
  iTerm2 is running get clobbered on its next quit. Either kill iTerm2
  with `pkill -9 -f iTerm` first, or (preferred) edit through the
  iTerm2 UI. Never write to the plist via `defaults` while iTerm2 is up.

- **Editing `.hammerspoon/init.lua`** — there is now a pathwatcher on
  `~/dotfiles/.hammerspoon/` that auto-reloads on `.lua` changes, BUT
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
  `~/.config/nvim/lua/config/options.lua` (LazyVim template, not in
  dotfiles, so the require line has to be added by hand on each host).
  `clipboard.lua` no-ops on local hosts and only kicks in over SSH; the
  full OSC 52 path also needs `set-clipboard on` + `allow-passthrough on`
  on every tmux layer (already in `tmux/tmux.conf`, but `home2`'s tmux
  3.2a skips passthrough — OSC 52 from inside a nested tmux there will
  not reach the outer terminal).

- **Renaming or deleting a tracked file** — check whether `install.sh`
  references it. Deleting a symlink target without removing the
  corresponding `ln -sf` line in install.sh leaves dangling links on
  the next deploy.

- **`.skk/userJisyo`** is the user dictionary, shared between hosts.
  It changes constantly as SKK learns conversions; expect to see it
  modified every time you run `git status`. Including its diffs in
  unrelated commits is fine and routine.

## Deploy

The pattern across all hosts:

1. Make changes locally.
2. `git commit && git push`.
3. On each remote host: `cd ~/dotfiles && git pull --rebase`.

Things that need extra steps after `git pull`:

- **iTerm2 plist changes** — iTerm2 must be killed before the pull, or
  it'll write its in-memory copy back over the new plist on quit. Use
  `pkill -9 -f iTerm`. Also patch `~/Library/Preferences/com.googlecode.iterm2.plist`
  directly if iTerm2 has cached profile values there (e.g. Rows count).

- **New Vim plugin or test framework added** — the plugin/test runner
  has to be cloned into `~/.vim/pack/plugins/start/`. install.sh has
  the canonical clone commands; lift them out and run them manually,
  don't run install.sh in full (it still has some legacy bits).

- **iTerm2 profile structural changes (Custom Command, fonts, GUID-
  scoped warning suppressions)** — those settings live in the plist
  itself and ride along with the file, but `defaults`-only keys like
  `NeverWarnAboutShortLivedSessions_<GUID>` don't sync via
  PrefsCustomFolder. install.sh has a `defaults write` block for those.

## Testing

```sh
# Hammerspoon pure helpers (busted, lua + luarocks via brew)
cd ~/dotfiles/.hammerspoon && busted test/

# vim-ime pure helpers (vim-themis, the runner is in pack/plugins/start/)
~/.vim/pack/plugins/start/vim-themis/bin/themis ~/dotfiles/.vim/test/
```

Both test suites cover only the *pure* helpers (mode-label / SKK-label /
window classification). Anything that touches `hs.*`, `vim.fn`,
filesystem state, or the running window manager is out of scope and
verified manually.

When you change those pure helpers, run the relevant suite before
committing. When you change `init.lua` or `.vimrc` glue, the suites
won't catch your bug — check the runtime behaviour by reloading
Hammerspoon / restarting Vim.

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

- **deploy** — push local changes to all hosts (handles iTerm2 kill,
  plist patching, etc).
- **add-host** — onboard a new machine into the dotfiles fleet.

When a request looks like "deploy this everywhere" or "set up dotfiles
on a new machine", use these skills as the playbook.
