---
name: add-host
description: Onboard a new machine into the dotfiles fleet. Use when the user mentions a new PC/laptop they want to share configuration with, or asks to "set up dotfiles on a new machine".
---

# add-host

Get a fresh machine to the same dotfiles state as the existing fleet.

## Prerequisites

- The new machine has working SSH access from the user's primary box.
- The user can run commands locally on the new machine (graphical or
  console; for the bootstrap step we need to type a few things in).
- A GitHub SSH key on the new machine (see step 2).

## Sequence

### 1. Pick an alias and add it to ~/.ssh/config

The alias becomes the `ssh <name>` shortcut and the label everywhere
in CLAUDE.md / skills. Existing aliases: `local`, `home`, `home2`, `ep`.

Append to `~/.ssh/config` on the user's primary box:

```
Host <alias>
    HostName <ip-or-tailscale-name>
    User <username>
```

### 2. Bootstrap the new machine

On the new machine itself:

```sh
# Install minimal tooling first
xcode-select --install        # macOS only, brings git
# (Linux: apt-get install -y git)

# Set up an SSH key for GitHub
ssh-keygen -t ed25519 -C "<machine-label>"
cat ~/.ssh/id_ed25519.pub     # add this to github.com/settings/keys

# Clone dotfiles
git clone git@github.com:yida29/dotfiles.git ~/dotfiles
```

### 3. Run the (manual, lifted-out) install steps

`install.sh` exists but contains legacy AstroNvim and other things you
don't want on a clean machine. Pick out only the parts you need:

**Always:**
```sh
# Symlink shell + ctags
ln -sf ~/dotfiles/zsh/.zshrc ~/.zshrc
ln -sf ~/dotfiles/.ctags ~/.ctags
ln -sf ~/dotfiles/.ctags.d ~/.ctags.d
ln -sf ~/dotfiles/tmux/tmux.conf ~/.tmux.conf
mkdir -p ~/.config/fish && ln -sf ~/dotfiles/fish/config.fish ~/.config/fish/config.fish

# Personal bin
mkdir -p ~/.local/bin
ln -sf ~/dotfiles/bin/sshs ~/.local/bin/sshs

# Vim IME pad (only worth setting up on macOS where the iTerm2 hotkey
# window exists; on Linux you can skip the vim plugins).
ln -sf ~/dotfiles/.vimrc ~/.vimrc
mkdir -p ~/.vim/autoload ~/.vim/test
ln -sf ~/dotfiles/.vim/autoload/vim_ime.vim ~/.vim/autoload/vim_ime.vim
ln -sf ~/dotfiles/.vim/test/vim_ime.vimspec ~/.vim/test/vim_ime.vimspec

# Vim plugins
VIM_PACK="$HOME/.vim/pack/plugins/start"
mkdir -p "$VIM_PACK"
git clone --depth 1 https://github.com/vim-denops/denops.vim "$VIM_PACK/denops.vim"
git clone --depth 1 https://github.com/vim-skk/skkeleton "$VIM_PACK/skkeleton"
git clone --depth 1 https://github.com/azumakuniyuki/vim-colorschemes "$VIM_PACK/azuma-vim-colorschemes"
mkdir -p "$VIM_PACK/azuma-vim-colorschemes/colors"
mv "$VIM_PACK/azuma-vim-colorschemes/"*.vim "$VIM_PACK/azuma-vim-colorschemes/colors/" 2>/dev/null
git clone --depth 1 https://github.com/kyoh86/momiji "$VIM_PACK/momiji"
git clone --depth 1 https://github.com/thinca/vim-themis "$VIM_PACK/vim-themis"

# SKK dictionary
mkdir -p ~/.skk
curl -L https://skk-dev.github.io/dict/SKK-JISYO.L.gz | gunzip > ~/.skk/SKK-JISYO.L
[ -f ~/dotfiles/.skk/userJisyo ] && ln -sf ~/dotfiles/.skk/userJisyo ~/.skkeleton

# Claude Code
mkdir -p ~/.claude
ln -sf ~/dotfiles/.claude/settings.json ~/.claude/settings.json
ln -sf ~/dotfiles/.claude/statusline.sh ~/.claude/statusline.sh
mkdir -p ~/.claude/output-styles
for s in ~/dotfiles/.claude/output-styles/*.md; do
  ln -sf "$s" ~/.claude/output-styles/
done
```

**macOS only:**
```sh
# Hammerspoon for IME pad focus hand-off
brew install --cask hammerspoon
ln -sf ~/dotfiles/.hammerspoon ~/.hammerspoon
# After first launch, manually grant Accessibility permission in
# System Settings > Privacy & Security.

# Vim 9.2+ (system vim is too old; denops needs ≥ 9.1.1646)
brew install vim deno

# iTerm2 PrefsCustomFolder + per-profile defaults
defaults write com.googlecode.iterm2 PrefsCustomFolder \
  -string "$HOME/dotfiles/iterm2"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
defaults write com.googlecode.iterm2 \
  "NeverWarnAboutShortLivedSessions_B21BB39C-36F0-4C5D-A289-1E33C172D5D3" \
  -bool true
```

**Linux only (home2-style):**
- Vim 9.2+ may need building from source; the system apt vim is 8.x.
  See `home2`'s history if you hit this — it requires `unzip`,
  `libclang-dev`, and a Rust toolchain to build `tree-sitter-cli`.
- `home2` doesn't run Hammerspoon or iTerm2; skip those entirely.

### 4. Update CLAUDE.md and skills

Add the new alias to:
- `~/dotfiles/CLAUDE.md` (the host table at the top)
- `~/dotfiles/.claude/skills/deploy/SKILL.md` (its host loop)

Commit the docs update so other hosts see the new fleet member on
their next pull.

### 5. Verify

```sh
ssh <alias> 'cd ~/dotfiles && git log -1 --oneline'
```

If the new machine resolves and the HEAD matches origin/master, you're
done. Optionally run the test suites on it as a smoke test:

```sh
ssh <alias> 'cd ~/dotfiles/.hammerspoon && busted test/'   # macOS
ssh <alias> '~/.vim/pack/plugins/start/vim-themis/bin/themis ~/dotfiles/.vim/test/'
```
