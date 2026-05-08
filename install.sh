#!/bin/bash

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
# iTerm2 profile GUID for "Japanese Input" (used by nvim-ime hotkey window).
# Defined once in iterm2/com.googlecode.iterm2.plist; we reference it here so
# we can scope per-profile defaults like NeverWarnAboutShortLivedSessions.
ITERM2_JAPANESE_PROFILE_GUID="B21BB39C-36F0-4C5D-A289-1E33C172D5D3"

if [[ "$OSTYPE" != "msys" ]]; then
ln -sf ~/dotfiles/.vimrc ~/.vimrc
ln -sf ~/dotfiles/.ctags ~/.ctags
ln -sf ~/dotfiles/.ctags.d ~/.ctags.d
fi
ln -sf ~/dotfiles/zsh/.zshrc ~/.zshrc
mkdir -p ~/.config/ghostty
ln -sf ~/dotfiles/ghostty/config ~/.config/ghostty/config
mkdir -p ~/.config/tmux
ln -sf ~/dotfiles/tmux/tmux.conf ~/.config/tmux/tmux.conf
# Also create ~/.tmux.conf symlink for tmux-sensible plugin compatibility
ln -sf ~/dotfiles/tmux/tmux.conf ~/.tmux.conf
mkdir -p "$HOME/Library/Application Support/lazygit"
ln -sf ~/dotfiles/lazygit/config.yml "$HOME/Library/Application Support/lazygit/config.yml"
mkdir -p ~/.config/fish/functions
ln -sf ~/dotfiles/fish/config.fish ~/.config/fish/config.fish
ln -sf ~/dotfiles/fish/functions/fish_prompt.fish ~/.config/fish/functions/fish_prompt.fish

mkdir -p ~/.local/bin
ln -sf ~/dotfiles/bin/sshs ~/.local/bin/sshs

# nvim-ime: standalone Neovim config used as a SKK-only IME
mkdir -p ~/.config
if [ -e ~/.config/nvim-ime ] && [ ! -L ~/.config/nvim-ime ]; then
  echo "Backing up existing ~/.config/nvim-ime..."
  mv ~/.config/nvim-ime ~/.config/nvim-ime.local-backup-$(date +%Y%m%d_%H%M%S)
fi
ln -sf ~/dotfiles/.config/nvim-ime ~/.config/nvim-ime

# Hammerspoon (macOS only): used for nvim-ime → previous-app paste hand-off
if [[ "$OSTYPE" == "darwin"* ]]; then
  if ! [ -d "/Applications/Hammerspoon.app" ]; then
    echo "Installing Hammerspoon..."
    brew install --cask hammerspoon
  fi
  ln -sf ~/dotfiles/.hammerspoon ~/.hammerspoon
fi

# iTerm2 (macOS only): point preferences to dotfiles for cross-host sync.
# Note: NeverWarnAboutShortLivedSessions_<GUID> doesn't get written to the
# shared plist, so we set it per-host here. Without it, the "Japanese Input"
# profile (which :qa!s on commit) triggers iTerm2's "session ended very soon"
# dialog every time.
if [[ "$OSTYPE" == "darwin"* ]]; then
  defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$HOME/dotfiles/iterm2"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  defaults write com.googlecode.iterm2 \
    "NeverWarnAboutShortLivedSessions_${ITERM2_JAPANESE_PROFILE_GUID}" -bool true
fi

# AstroNvim installation
# Only install AstroNvim if it doesn't exist
if [ ! -d ~/.config/nvim ]; then
    echo "Installing AstroNvim..."
    git clone --depth 1 https://github.com/AstroNvim/template ~/.config/nvim
    rm -rf ~/.config/nvim/.git
else
    echo "AstroNvim already installed, skipping installation..."
fi

# Copy custom plugin configurations
echo "Copying custom plugin configurations..."
mkdir -p ~/.config/nvim/lua/plugins

# Remove orphaned symlinks first
echo "Removing orphaned plugin symlinks..."
for link in ~/.config/nvim/lua/plugins/*.lua; do
    if [ -L "$link" ] && [ ! -e "$link" ]; then
        plugin_name=$(basename "$link")
        rm "$link"
        echo "Removed orphaned symlink: $plugin_name"
    fi
done

# Create symlinks for all custom plugins
for plugin in ~/dotfiles/.config/nvim/lua/plugins/*.lua; do
    if [ -f "$plugin" ]; then
        plugin_name=$(basename "$plugin")
        ln -sf "$plugin" ~/.config/nvim/lua/plugins/"$plugin_name"
        echo "Linked $plugin_name"
    fi
done

curl https://git.io/fisher --create-dirs -sLo ~/.config/fish/functions/fisher.fish
curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Also install vim-plug for Neovim
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# ~/.tmux/plugins/tpm を最新化するスクリプト
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "TPM not found. Cloning..."
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
  echo "TPM already exists. Updating..."
  (cd ~/.tmux/plugins/tpm && git pull origin master)
fi

# Install ghq
if ! command -v ghq &> /dev/null; then
  echo "Installing ghq..."
  brew install ghq
fi

# Install fzf
if ! command -v fzf &> /dev/null; then
  echo "Installing fzf..."
  brew install fzf
fi

# Install delta (git pager for lazygit & git diff)
if ! command -v delta &> /dev/null; then
  echo "Installing delta..."
  brew install git-delta
fi

# Install Deno (required by denops.vim for skkeleton)
if ! command -v deno &> /dev/null; then
  echo "Installing deno..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install deno
  else
    curl -fsSL https://deno.land/install.sh | sh
    # Symlink into ~/.local/bin so it picks up the existing PATH entry
    if [ -x "$HOME/.deno/bin/deno" ]; then
      mkdir -p "$HOME/.local/bin"
      ln -sf "$HOME/.deno/bin/deno" "$HOME/.local/bin/deno"
    fi
  fi
fi

# Install SKK dictionary for skkeleton
if [ ! -f ~/.skk/SKK-JISYO.L ]; then
  echo "Downloading SKK-JISYO.L..."
  mkdir -p ~/.skk
  curl -L https://skk-dev.github.io/dict/SKK-JISYO.L.gz | gunzip > ~/.skk/SKK-JISYO.L
fi

# Link skkeleton user dictionary (shared across hosts via dotfiles)
if [ -f ~/dotfiles/.skk/userJisyo ]; then
  if [ -e ~/.skkeleton ] && [ ! -L ~/.skkeleton ]; then
    # Existing real file: merge into dotfiles version then back up
    echo "Merging existing ~/.skkeleton into dotfiles..."
    mv ~/.skkeleton ~/.skkeleton.local-backup-$(date +%Y%m%d_%H%M%S)
  fi
  ln -sf ~/dotfiles/.skk/userJisyo ~/.skkeleton
fi

git config --global ghq.root ~/work
git config --global core.editor 'vim -c "set fenc=utf-8"'

# Claude Code configuration
echo "Setting up Claude Code..."

# Install jq (required for statusline.sh)
if ! command -v jq &> /dev/null; then
  echo "Installing jq..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install jq
  elif command -v apt &> /dev/null; then
    sudo apt install -y jq
  elif command -v yum &> /dev/null; then
    sudo yum install -y jq
  else
    echo "Warning: Could not install jq. Please install it manually for statusline to work."
  fi
fi

mkdir -p ~/.claude/output-styles
ln -sf ~/dotfiles/.claude/settings.json ~/.claude/settings.json
# settings.local.json contains machine-specific paths, so don't symlink it
# Instead, copy as template if it doesn't exist
if [ ! -f ~/.claude/settings.local.json ]; then
  echo "Creating settings.local.json template (edit paths as needed)..."
  cp ~/dotfiles/.claude/settings.local.json ~/.claude/settings.local.json
fi

# Continuous-Claude: Set CLAUDE_OPC_DIR with absolute path in settings.local.json
# XDG compliant location: ~/.local/share/continuous-claude/opc
if [ -d "$HOME/.local/share/continuous-claude/opc" ]; then
  echo "Configuring Continuous-Claude OPC directory..."
  # Add or update env.CLAUDE_OPC_DIR in settings.local.json
  tmp_file=$(mktemp)
  jq --arg opc_dir "$HOME/.local/share/continuous-claude/opc" \
    '.env = (.env // {}) | .env.CLAUDE_OPC_DIR = $opc_dir' \
    ~/.claude/settings.local.json > "$tmp_file" && mv "$tmp_file" ~/.claude/settings.local.json
fi
ln -sf ~/dotfiles/.claude/statusline.sh ~/.claude/statusline.sh
chmod +x ~/dotfiles/.claude/statusline.sh
# Output styles
for style in ~/dotfiles/.claude/output-styles/*.md; do
  if [ -f "$style" ]; then
    ln -sf "$style" ~/.claude/output-styles/
  fi
done
