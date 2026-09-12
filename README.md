# dotfiles

Personal configuration files for Vim, Neovim, Fish shell, tmux, and other development tools.

## Features

- Self-contained LazyVim configuration for Neovim
- Vim SKK input pad; IME commit/autosave/startup apply only to `~/Documents/ime-scratch`
- Fish shell with Starship prompt
- tmux with custom keybindings
- Language support for Go, Vue.js, Ruby, PHP, Python, and more
- Neovim LSP integration
- GitHub Copilot support

## Install

Prerequisites: Git, curl, Python 3, fish, tmux, and a Neovim version
supported by current LazyVim. The SKK pad needs Vim ≥ 9.1.1646 and Deno
(the installer installs Deno). On macOS, install Xcode Command Line Tools,
Homebrew, and iTerm2 first; on Debian/Ubuntu, have `apt`, sudo access, and
archive tools (`tar`, `gzip`, `unzip`) available. The installer does **not**
install every prerequisite.
The macOS hotkey profile expects Homebrew Vim at `/opt/homebrew/bin/vim`.

On a fresh host, review `install.sh` before running it: it installs tools
and plugins, links configs, starts docserver, and changes global Git/CLI
settings. Preserve existing configs and work first. On macOS, save active
iTerm2 sessions and quit with the user's approval before installation:
it writes iTerm2 preferences. Never edit/pull its plist while iTerm2 runs.

```sh
mkdir -p ~/work &&
git clone https://github.com/yida29/dotfiles.git ~/work/dotfiles &&
cd ~/work/dotfiles && bash install.sh
```

If that checkout already exists, inspect its status instead of cloning
over it; never automatically stash or reset dirty work. For a different
checkout location, run `DOTFILES_DIR="$PWD" bash install.sh` from its root.

The installer links tracked Neovim entry/bootstrap/options files and
backs up replaced local configs (including conflicting `init.vim`) at
`<target>.backup.XXXXXX/original`. No separate LazyVim template or manual
`options.lua` edits are needed. The existing iTerm2 command
`~/.config/vim-ime/vimrc` is a compatibility entry sourcing `~/.vimrc`;
ordinary Vim editing does not use the pad's commit/autosave behavior.

Fleet membership comes from `config/sshs/hosts.json` (`local` means the
current machine, not an SSH alias). Add registry entries and SSH aliases
on relevant clients before onboarding. See `.claude/skills/add-host/SKILL.md`
and `.claude/skills/deploy/SKILL.md` for fresh-host setup and safe updates.
Existing hosts may need targeted installer links/bootstrap for new files;
do not blindly rerun the full installer during deployment.

Claude settings are seeded from `.claude/settings.json.example`, not
symlinked. SKK learning is per-host; `.skk/userJisyo` is ignored, not shared.
