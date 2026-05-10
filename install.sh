#!/bin/bash
#
# install.sh — bootstrap a fresh host into the dotfiles fleet.
#
# Idempotent: re-running on an already-set-up host should be a no-op.
# Cross-platform: macOS uses Homebrew, Linux uses apt + curl-installed
# binaries dropped into ~/.local/bin.

set -e

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
# iTerm2 profile GUID for "Japanese Input" (used by nvim-ime hotkey window).
# Defined once in iterm2/com.googlecode.iterm2.plist; we reference it here so
# we can scope per-profile defaults like NeverWarnAboutShortLivedSessions.
ITERM2_JAPANESE_PROFILE_GUID="B21BB39C-36F0-4C5D-A289-1E33C172D5D3"

case "$OSTYPE" in
  darwin*) OS=macos ;;
  linux*)  OS=linux ;;
  msys*)   OS=windows ;;
  *)       OS=unknown ;;
esac

# -----------------------------------------------------------------------------
# Tool installation helpers.
#
# Every tool we need either ships in the OS package manager (brew on macOS,
# apt on Debian/Ubuntu) or has a documented install script that lands a
# binary in ~/.local/bin. install_tool dispatches to the right one.
#
# Already-installed tools are left alone. We deliberately don't try to
# upgrade — homebrew users already have `brew upgrade`, apt users
# already have `apt upgrade`, and we don't want to surprise either.
# -----------------------------------------------------------------------------
mkdir -p ~/.local/bin

# Make sure ~/.local/bin and ~/.cargo/bin are visible to *this script*'s
# subshells, so command -v finds binaries we just installed.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

install_via_brew() {  # $1 = formula
  if [[ "$OS" == macos ]] && command -v brew >/dev/null; then
    brew install "$1"
    return 0
  fi
  return 1
}

install_via_apt() {  # $1 = package
  if [[ "$OS" == linux ]] && command -v apt >/dev/null; then
    sudo apt install -y "$1"
    return 0
  fi
  return 1
}

install_starship() {
  command -v starship >/dev/null && return 0
  echo "Installing starship..."
  if install_via_brew starship; then return; fi
  # Linux: official installer, scoped to ~/.local/bin.
  curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
}

install_ghq() {
  command -v ghq >/dev/null && return 0
  echo "Installing ghq..."
  if install_via_brew ghq; then return; fi
  # Linux: prebuilt binary tarball release.
  local arch="amd64"
  [[ "$(uname -m)" == "aarch64" ]] && arch="arm64"
  local tmp; tmp=$(mktemp -d)
  curl -fsSL "https://github.com/x-motemen/ghq/releases/latest/download/ghq_linux_${arch}.zip" -o "$tmp/ghq.zip"
  (cd "$tmp" && unzip -q ghq.zip && mv ghq_linux_${arch}/ghq "$HOME/.local/bin/")
  rm -rf "$tmp"
}

install_fzf() {
  command -v fzf >/dev/null && return 0
  echo "Installing fzf..."
  if install_via_brew fzf; then return; fi
  if install_via_apt fzf; then return; fi
}

install_delta() {
  command -v delta >/dev/null && return 0
  echo "Installing delta..."
  if install_via_brew git-delta; then return; fi
  # Linux: prebuilt .deb from the upstream release. apt has it too on
  # newer Ubuntu, but Jammy / WSL2 default repos don't.
  if [[ "$OS" == linux ]]; then
    if install_via_apt git-delta; then return; fi
    local arch="amd64"
    [[ "$(uname -m)" == "aarch64" ]] && arch="arm64"
    local ver="0.18.2"
    local tmp; tmp=$(mktemp -d)
    curl -fsSL "https://github.com/dandavison/delta/releases/download/${ver}/delta-${ver}-x86_64-unknown-linux-gnu.tar.gz" -o "$tmp/delta.tgz"
    (cd "$tmp" && tar xzf delta.tgz && mv "delta-${ver}-x86_64-unknown-linux-gnu/delta" "$HOME/.local/bin/")
    rm -rf "$tmp"
  fi
}

install_deno() {
  command -v deno >/dev/null && return 0
  echo "Installing deno..."
  if install_via_brew deno; then return; fi
  curl -fsSL https://deno.land/install.sh | sh
  if [ -x "$HOME/.deno/bin/deno" ]; then
    ln -sf "$HOME/.deno/bin/deno" "$HOME/.local/bin/deno"
  fi
}

install_jq() {
  command -v jq >/dev/null && return 0
  echo "Installing jq..."
  if install_via_brew jq; then return; fi
  if install_via_apt jq; then return; fi
  if [[ "$OS" == linux ]] && command -v yum >/dev/null; then
    sudo yum install -y jq
    return
  fi
  echo "Warning: don't know how to install jq on this OS"
}

install_ripgrep() {
  command -v rg >/dev/null && return 0
  echo "Installing ripgrep..."
  if install_via_brew ripgrep; then return; fi
  if install_via_apt ripgrep; then return; fi
  echo "Warning: don't know how to install ripgrep on this OS"
}

# -----------------------------------------------------------------------------
# Symlink config files
# -----------------------------------------------------------------------------
if [[ "$OS" != windows ]]; then
  ln -sf ~/dotfiles/.vimrc ~/.vimrc
  ln -sf ~/dotfiles/.ctags ~/.ctags
  ln -sf ~/dotfiles/.ctags.d ~/.ctags.d
fi
ln -sf ~/dotfiles/zsh/.zshrc ~/.zshrc

mkdir -p ~/.config/tmux
ln -sf ~/dotfiles/tmux/tmux.conf ~/.config/tmux/tmux.conf
# tmux-sensible expects ~/.tmux.conf
ln -sf ~/dotfiles/tmux/tmux.conf ~/.tmux.conf

# lazygit config — only macOS path because the Linux config dir is
# ~/.config/lazygit/ and we don't currently need that.
if [[ "$OS" == macos ]]; then
  mkdir -p "$HOME/Library/Application Support/lazygit"
  ln -sf ~/dotfiles/lazygit/config.yml "$HOME/Library/Application Support/lazygit/config.yml"
else
  mkdir -p "$HOME/.config/lazygit"
  ln -sf ~/dotfiles/lazygit/config.yml "$HOME/.config/lazygit/config.yml"
fi

mkdir -p ~/.config/fish/functions
ln -sf ~/dotfiles/fish/config.fish ~/.config/fish/config.fish
ln -sf ~/dotfiles/fish/functions/fish_prompt.fish ~/.config/fish/functions/fish_prompt.fish

ln -sf ~/dotfiles/bin/sshs ~/.local/bin/sshs

# -----------------------------------------------------------------------------
# Vim-ime (SKK Japanese-input pad). Plugins live under
# ~/.vim/pack/plugins/start/ and are loaded by Vim's native :h packages
# mechanism.
# -----------------------------------------------------------------------------
VIM_PACK="$HOME/.vim/pack/plugins/start"
mkdir -p "$VIM_PACK"
[ ! -d "$VIM_PACK/denops.vim" ] \
  && git clone --depth 1 https://github.com/vim-denops/denops.vim "$VIM_PACK/denops.vim"
[ ! -d "$VIM_PACK/skkeleton" ] \
  && git clone --depth 1 https://github.com/vim-skk/skkeleton "$VIM_PACK/skkeleton"

# Japanese-traditional-color schemes (sabineko, etc).
if [ ! -d "$VIM_PACK/azuma-vim-colorschemes" ]; then
  git clone --depth 1 https://github.com/azumakuniyuki/vim-colorschemes "$VIM_PACK/azuma-vim-colorschemes"
  # The repo ships colorschemes at the top level; Vim's :h packages
  # mechanism only picks up colors/ subdirectories.
  if [ ! -d "$VIM_PACK/azuma-vim-colorschemes/colors" ]; then
    mkdir -p "$VIM_PACK/azuma-vim-colorschemes/colors"
    mv "$VIM_PACK/azuma-vim-colorschemes/"*.vim "$VIM_PACK/azuma-vim-colorschemes/colors/" 2>/dev/null || true
  fi
fi
[ ! -d "$VIM_PACK/momiji" ] \
  && git clone --depth 1 https://github.com/kyoh86/momiji "$VIM_PACK/momiji"
# Test runner for autoload/vim_ime.vim.
[ ! -d "$VIM_PACK/vim-themis" ] \
  && git clone --depth 1 https://github.com/thinca/vim-themis "$VIM_PACK/vim-themis"

# autoload/test files for vim-ime are tracked in dotfiles. Symlink them
# into ~/.vim/ so Vim's :h packages mechanism finds them.
mkdir -p "$HOME/.vim/autoload" "$HOME/.vim/test"
ln -sf "$HOME/dotfiles/.vim/autoload/vim_ime.vim" "$HOME/.vim/autoload/vim_ime.vim"
ln -sf "$HOME/dotfiles/.vim/test/vim_ime.vimspec" "$HOME/.vim/test/vim_ime.vimspec"

# -----------------------------------------------------------------------------
# macOS-only desktop integration
# -----------------------------------------------------------------------------
if [[ "$OS" == macos ]]; then
  # Hammerspoon: nvim-ime → previous-app paste hand-off
  if [ ! -d "/Applications/Hammerspoon.app" ]; then
    echo "Installing Hammerspoon..."
    brew install --cask hammerspoon
  fi
  ln -sf ~/dotfiles/.hammerspoon ~/.hammerspoon

  # iTerm2: PrefsCustomFolder + per-profile defaults that don't sync via
  # the shared plist. Without this, the "Japanese Input" profile (which
  # :qa!s on commit) triggers iTerm2's "session ended very soon" dialog
  # every time.
  defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$HOME/dotfiles/iterm2"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  defaults write com.googlecode.iterm2 \
    "NeverWarnAboutShortLivedSessions_${ITERM2_JAPANESE_PROFILE_GUID}" -bool true
fi

# -----------------------------------------------------------------------------
# Neovim plugin symlinks (LazyVim is bootstrapped by lazy.nvim itself
# when nvim first runs; we just make sure our custom plugin specs are
# there to be picked up).
# -----------------------------------------------------------------------------
mkdir -p ~/.config/nvim/lua/plugins ~/.config/nvim/lua/config

# Remove orphaned symlinks first
for link in ~/.config/nvim/lua/plugins/*.lua ~/.config/nvim/lua/config/*.lua; do
  if [ -L "$link" ] && [ ! -e "$link" ]; then
    rm "$link"
  fi
done
# Create symlinks for all custom plugins
for plugin in ~/dotfiles/.config/nvim/lua/plugins/*.lua; do
  if [ -f "$plugin" ]; then
    ln -sf "$plugin" ~/.config/nvim/lua/plugins/"$(basename "$plugin")"
  fi
done
# lua/config/ holds dotfiles-managed config snippets that need to load before
# lazy.nvim (e.g. neovide GUI font). lua/config/options.lua itself stays in
# the LazyVim template and is responsible for `require`ing these.
for cfg in ~/dotfiles/.config/nvim/lua/config/*.lua; do
  if [ -f "$cfg" ]; then
    ln -sf "$cfg" ~/.config/nvim/lua/config/"$(basename "$cfg")"
  fi
done

# -----------------------------------------------------------------------------
# fish + tmux plugin managers
# -----------------------------------------------------------------------------
curl -fsSL https://git.io/fisher --create-dirs -o ~/.config/fish/functions/fisher.fish

if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# -----------------------------------------------------------------------------
# CLI tools
# -----------------------------------------------------------------------------
install_starship
install_ghq
install_fzf
install_delta
install_deno
install_jq
install_ripgrep

# -----------------------------------------------------------------------------
# SKK dictionary for skkeleton (cross-host, OS-independent)
# -----------------------------------------------------------------------------
if [ ! -f ~/.skk/SKK-JISYO.L ]; then
  echo "Downloading SKK-JISYO.L..."
  mkdir -p ~/.skk
  curl -fsSL https://skk-dev.github.io/dict/SKK-JISYO.L.gz | gunzip > ~/.skk/SKK-JISYO.L
fi
# skkeleton creates ~/.skkeleton on first save; we no longer share it
# across hosts via dotfiles (it's in .gitignore now). Each host keeps
# its own learning.

# -----------------------------------------------------------------------------
# Git config
# -----------------------------------------------------------------------------
git config --global ghq.root ~/work
git config --global core.editor 'vim -c "set fenc=utf-8"'

# Surface this dotfiles checkout to ghq. The repo lives at ~/dotfiles
# for historical / convention reasons, but ghq only walks ghq.root
# (~/work/), so without this link `ghq list` doesn't see it.
mkdir -p ~/work
[ ! -e ~/work/dotfiles ] && ln -s ~/dotfiles ~/work/dotfiles

# -----------------------------------------------------------------------------
# Claude Code
# -----------------------------------------------------------------------------
mkdir -p ~/.claude/output-styles
ln -sf ~/dotfiles/.claude/settings.json ~/.claude/settings.json
# settings.local.json contains machine-specific paths, so don't symlink it
# Instead, copy as template if it doesn't exist
if [ ! -f ~/.claude/settings.local.json ]; then
  cp ~/dotfiles/.claude/settings.local.json ~/.claude/settings.local.json
fi

# Continuous-Claude: set CLAUDE_OPC_DIR if its data dir exists.
if [ -d "$HOME/.local/share/continuous-claude/opc" ]; then
  tmp_file=$(mktemp)
  jq --arg opc_dir "$HOME/.local/share/continuous-claude/opc" \
    '.env = (.env // {}) | .env.CLAUDE_OPC_DIR = $opc_dir' \
    ~/.claude/settings.local.json > "$tmp_file" && mv "$tmp_file" ~/.claude/settings.local.json
fi

ln -sf ~/dotfiles/.claude/statusline.sh ~/.claude/statusline.sh
chmod +x ~/dotfiles/.claude/statusline.sh
for style in ~/dotfiles/.claude/output-styles/*.md; do
  if [ -f "$style" ]; then
    ln -sf "$style" ~/.claude/output-styles/
  fi
done
