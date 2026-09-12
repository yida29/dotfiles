#!/bin/bash
#
# install.sh — bootstrap a fresh host into the dotfiles fleet.
#
# Idempotent: re-running on an already-set-up host should be a no-op.
# Cross-platform: macOS uses Homebrew, Linux uses apt + curl-installed
# binaries dropped into ~/.local/bin.

set -eo pipefail

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
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/work/dotfiles}"
DOTFILES_DIR="$(cd "$DOTFILES_DIR" && pwd)"

# Make sure ~/.local/bin and ~/.cargo/bin are visible to *this script*'s
# subshells, so command -v finds binaries we just installed.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

install_via_brew() {  # $1 = formula
  if [[ "$OS" == macos ]] && command -v brew >/dev/null; then
    brew install "$1"
    return $?
  fi
  return 1
}

install_via_apt() {  # $1 = package
  if [[ "$OS" == linux ]] && command -v apt >/dev/null; then
    sudo apt install -y "$1"
    return $?
  fi
  return 1
}

install_starship() {
  command -v starship >/dev/null && return 0
  echo "Installing starship..."
  if install_via_brew starship; then return; fi
  # Linux: official installer, scoped to ~/.local/bin.
  curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
}

install_ghq() {
  command -v ghq >/dev/null && return 0
  echo "Installing ghq..."
  if install_via_brew ghq; then return; fi
  if [[ "$OS" != linux ]]; then
    echo "Error: failed to install ghq with Homebrew" >&2
    return 1
  fi
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
  echo "Error: could not install fzf" >&2
  return 1
}

install_delta() {
  command -v delta >/dev/null && return 0
  echo "Installing delta..."
  if install_via_brew git-delta; then return; fi
  # Linux: prebuilt tarball from the upstream release. apt has it too on
  # newer Ubuntu, but Jammy / WSL2 default repos don't.
  if [[ "$OS" == linux ]]; then
    if install_via_apt git-delta; then return; fi
    local arch="x86_64"
    [[ "$(uname -m)" == "aarch64" ]] && arch="aarch64"
    local ver="0.18.2"
    local tmp; tmp=$(mktemp -d)
    curl -fsSL "https://github.com/dandavison/delta/releases/download/${ver}/delta-${ver}-${arch}-unknown-linux-gnu.tar.gz" -o "$tmp/delta.tgz"
    (cd "$tmp" && tar xzf delta.tgz && mv "delta-${ver}-${arch}-unknown-linux-gnu/delta" "$HOME/.local/bin/")
    rm -rf "$tmp"
  else
    echo "Error: failed to install delta with Homebrew" >&2
    return 1
  fi
}

install_deno() {
  command -v deno >/dev/null && return 0
  echo "Installing deno..."
  if install_via_brew deno; then return; fi
  curl -fsSL https://deno.land/install.sh | sh
  if [ -x "$HOME/.deno/bin/deno" ]; then
    ln -sf "$HOME/.deno/bin/deno" "$HOME/.local/bin/deno"
  else
    echo "Error: the Deno installer did not create a binary" >&2
    return 1
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
  echo "Error: could not install jq" >&2
  return 1
}

install_ripgrep() {
  command -v rg >/dev/null && return 0
  echo "Installing ripgrep..."
  if install_via_brew ripgrep; then return; fi
  if install_via_apt ripgrep; then return; fi
  echo "Error: could not install ripgrep" >&2
  return 1
}

# Official `agy install` appends a PATH block to every shell profile it
# finds. ~/.local/bin is already on PATH via this repo, so we drop that
# marker afterwards (tracked files would otherwise go dirty, and login
# profiles would grow a duplicate on every fresh host).
strip_agy_installer_path_block() {
  local f tmp
  for f in \
    "$DOTFILES_DIR/zsh/.zshrc" \
    "$DOTFILES_DIR/fish/config.fish" \
    "$HOME/.zprofile" \
    "$HOME/.profile" \
    "$HOME/.bash_profile"
  do
    [[ -f "$f" ]] || continue
    tmp=$(mktemp)
    awk '
      $0 == "# Added by Antigravity CLI installer" { skip=1; next }
      skip { skip=0; next }
      { print }
    ' "$f" > "$tmp" && mv "$tmp" "$f"
  done
}

install_agy() {
  # Antigravity CLI (successor to Gemini CLI). Distinct from the desktop
  # IDE wrapper at ~/.antigravity/antigravity/bin/agy — that one is a
  # VS Code fork and reports 1.104.x. The CLI is a real binary at
  # ~/.local/bin/agy. Official installer is a no-op if that path exists.
  if [[ -x "$HOME/.local/bin/agy" && ! -L "$HOME/.local/bin/agy" ]]; then
    return 0
  fi
  echo "Installing Antigravity CLI..."
  curl -fsSL https://antigravity.google/cli/install.sh | bash
  strip_agy_installer_path_block
}

backup_config() {
  local target="$1" backup
  if [[ -e "$target" || -L "$target" ]]; then
    backup="$(mktemp -d "${target}.backup.XXXXXX")"
    mv "$target" "$backup/original"
    echo "Saved existing config: $backup/original"
  fi
}

link_config() {
  local source="$1" target="$2"
  if [[ ! -e "$source" ]]; then
    echo "Error: config source does not exist: $source" >&2
    return 1
  fi
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  backup_config "$target"
  ln -sfn "$source" "$target"
}

# docserver needs jq before its service is started.
install_jq

# -----------------------------------------------------------------------------
# Symlink config files
# -----------------------------------------------------------------------------
if [[ "$OS" != windows ]]; then
  link_config "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"
  link_config "$DOTFILES_DIR/.config/vim-ime/vimrc" "$HOME/.config/vim-ime/vimrc"
fi
ln -sf "$DOTFILES_DIR/zsh/.zshrc" ~/.zshrc

mkdir -p ~/.config/tmux
ln -sf "$DOTFILES_DIR/tmux/tmux.conf" ~/.config/tmux/tmux.conf
# tmux-sensible expects ~/.tmux.conf
ln -sf "$DOTFILES_DIR/tmux/tmux.conf" ~/.tmux.conf

# lazygit config — only macOS path because the Linux config dir is
# ~/.config/lazygit/ and we don't currently need that.
if [[ "$OS" == macos ]]; then
  mkdir -p "$HOME/Library/Application Support/lazygit"
  ln -sf "$DOTFILES_DIR/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"
else
  mkdir -p "$HOME/.config/lazygit"
  ln -sf "$DOTFILES_DIR/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
fi

mkdir -p ~/.config/fish/functions
ln -sf "$DOTFILES_DIR/fish/config.fish" ~/.config/fish/config.fish
ln -sf "$DOTFILES_DIR/fish/functions/neovide.fish" ~/.config/fish/functions/neovide.fish

ln -sf "$DOTFILES_DIR/bin/sshs" ~/.local/bin/sshs
ln -sf "$DOTFILES_DIR/bin/docserver" ~/.local/bin/docserver

# sshs reads its host registry (aliases, tab colors, default forward
# ports, Tailscale names) from ~/.config/sshs/hosts.json. Same file on
# every host — sshs itself is a thin reader.
mkdir -p ~/.config/sshs
ln -sf "$DOTFILES_DIR/config/sshs/hosts.json" ~/.config/sshs/hosts.json

# aqua — global CLI tool manager (node, codex, ...). One shared aqua.yaml
# across the fleet; aqua resolves the right per-OS binary. Shell rc files
# put ~/.local/share/aquaproj-aqua/bin on PATH and set AQUA_GLOBAL_CONFIG.
if ! command -v aqua >/dev/null && [[ ! -x "$HOME/.local/share/aquaproj-aqua/bin/aqua" ]]; then
  curl -sSfL https://raw.githubusercontent.com/aquaproj/aqua-installer/v4.0.2/aqua-installer | bash
fi
mkdir -p ~/.config/aquaproj-aqua
ln -sf "$DOTFILES_DIR/config/aquaproj-aqua/aqua.yaml" ~/.config/aquaproj-aqua/aqua.yaml
AQUA_GLOBAL_CONFIG="$HOME/.config/aquaproj-aqua/aqua.yaml" \
  "$HOME/.local/share/aquaproj-aqua/bin/aqua" install -l 2>/dev/null || true

# Per-host static doc server (companion to sshs). Lifecycle managed by
# launchd on macOS, systemd --user on Linux. The service ExecStart's
# ~/.local/bin/docserver, which reads its port/root from hosts.json
# above. Bind is hardcoded to 127.0.0.1 inside docserver itself.
#
# We need ~/work to exist (the default doc root) before starting the
# service, otherwise it errors out.
mkdir -p "$HOME/work"

if [[ "$OS" == macos ]]; then
  mkdir -p ~/Library/LaunchAgents
  ln -sf "$DOTFILES_DIR/config/launchd/com.yida.docserver.plist" \
    ~/Library/LaunchAgents/com.yida.docserver.plist
  # Idempotent (re-)bootstrap.
  domain="gui/$(id -u)"
  launchctl bootout "$domain/com.yida.docserver" 2>/dev/null || true
  launchctl bootstrap "$domain" \
    ~/Library/LaunchAgents/com.yida.docserver.plist
elif [[ "$OS" == linux ]]; then
  mkdir -p ~/.config/systemd/user
  ln -sf "$DOTFILES_DIR/config/systemd/docserver.service" \
    ~/.config/systemd/user/docserver.service
  if command -v systemctl >/dev/null && systemctl --user status >/dev/null 2>&1; then
    systemctl --user daemon-reload
    systemctl --user enable --now docserver.service
  else
    echo "Warning: systemd --user not available; docserver not enabled" >&2
  fi
fi

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
ln -sf "$DOTFILES_DIR/.vim/autoload/vim_ime.vim" "$HOME/.vim/autoload/vim_ime.vim"
for spec in "$DOTFILES_DIR"/.vim/test/*.vimspec; do
  link_config "$spec" "$HOME/.vim/test/$(basename "$spec")"
done

# -----------------------------------------------------------------------------
# macOS-only desktop integration
# -----------------------------------------------------------------------------
if [[ "$OS" == macos ]]; then
  # Hammerspoon: nvim-ime → previous-app paste hand-off
  if [ ! -d "/Applications/Hammerspoon.app" ]; then
    echo "Installing Hammerspoon..."
    brew install --cask hammerspoon
  fi
  link_config "$DOTFILES_DIR/.hammerspoon" "$HOME/.hammerspoon"

  # iTerm2: PrefsCustomFolder + per-profile defaults that don't sync via
  # the shared plist. Without this, the "Japanese Input" profile (which
  # :qa!s on commit) triggers iTerm2's "session ended very soon" dialog
  # every time.
  defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$DOTFILES_DIR/iterm2"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  defaults write com.googlecode.iterm2 \
    "NeverWarnAboutShortLivedSessions_${ITERM2_JAPANESE_PROFILE_GUID}" -bool true
fi

# -----------------------------------------------------------------------------
# Neovim entry point, LazyVim bootstrap and plugin/config symlinks.
# -----------------------------------------------------------------------------
mkdir -p ~/.config/nvim/lua/plugins ~/.config/nvim/lua/config
backup_config "$HOME/.config/nvim/init.vim"
link_config "$DOTFILES_DIR/.config/nvim/init.lua" "$HOME/.config/nvim/init.lua"

# Remove orphaned symlinks first
for link in ~/.config/nvim/lua/plugins/*.lua ~/.config/nvim/lua/config/*.lua; do
  if [ -L "$link" ] && [ ! -e "$link" ]; then
    rm "$link"
  fi
done
# Create symlinks for all custom plugins
for plugin in "$DOTFILES_DIR"/.config/nvim/lua/plugins/*.lua; do
  if [ -f "$plugin" ]; then
    link_config "$plugin" "$HOME/.config/nvim/lua/plugins/$(basename "$plugin")"
  fi
done
# options.lua loads clipboard/neovide settings; lazy.lua disables netrwPlugin.
for cfg in "$DOTFILES_DIR"/.config/nvim/lua/config/*.lua; do
  if [ -f "$cfg" ]; then
    link_config "$cfg" "$HOME/.config/nvim/lua/config/$(basename "$cfg")"
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
install_ripgrep
install_agy

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

# The canonical checkout lives directly under ghq.root.
mkdir -p ~/work

# -----------------------------------------------------------------------------
# Claude Code
# -----------------------------------------------------------------------------
mkdir -p ~/.claude/output-styles
# settings.json is NOT symlinked. Claude Code rewrites model / effort /
# theme / plugins on use, which used to dirty the git worktree on every
# host (#4). Seed from the example once; afterwards each host owns its copy.
if [ ! -f ~/.claude/settings.json ] || [ -L ~/.claude/settings.json ]; then
  src="$DOTFILES_DIR/.claude/settings.json.example"
  [ -f "$src" ] || src="$DOTFILES_DIR/.claude/settings.json"
  if [ -f "$src" ]; then
    tmp=$(mktemp)
    # If currently a symlink into the repo, preserve content then replace.
    if [ -L ~/.claude/settings.json ]; then
      cp -L ~/.claude/settings.json "$tmp"
      rm -f ~/.claude/settings.json
      mv "$tmp" ~/.claude/settings.json
    else
      cp "$src" ~/.claude/settings.json
    fi
  fi
fi
# settings.local.json contains machine-specific paths, so don't symlink it
# Instead, copy as template if it doesn't exist
if [ ! -f ~/.claude/settings.local.json ] && [ -f "$DOTFILES_DIR/.claude/settings.local.json" ]; then
  cp "$DOTFILES_DIR/.claude/settings.local.json" ~/.claude/settings.local.json
fi

# Continuous-Claude: set CLAUDE_OPC_DIR if its data dir exists.
if [ -d "$HOME/.local/share/continuous-claude/opc" ]; then
  [ -f ~/.claude/settings.local.json ] || printf '{}\n' > ~/.claude/settings.local.json
  tmp_file=$(mktemp)
  jq --arg opc_dir "$HOME/.local/share/continuous-claude/opc" \
    '.env = (.env // {}) | .env.CLAUDE_OPC_DIR = $opc_dir' \
    ~/.claude/settings.local.json > "$tmp_file" && mv "$tmp_file" ~/.claude/settings.local.json
fi

ln -sf "$DOTFILES_DIR/.claude/statusline.sh" ~/.claude/statusline.sh
chmod +x "$DOTFILES_DIR/.claude/statusline.sh"
for style in "$DOTFILES_DIR"/.claude/output-styles/*.md; do
  if [ -f "$style" ]; then
    ln -sf "$style" ~/.claude/output-styles/
  fi
done

# -----------------------------------------------------------------------------
# Codex CLI
# -----------------------------------------------------------------------------
# Start every session in YOLO mode: no approval prompts, no sandbox.
#
# config.toml is NOT symlinked. Codex writes into it itself (a
# [projects."<path>"] trust_level block per directory you open), so a symlink
# would leave dotfiles permanently dirty with per-host paths. Instead we set
# just the two keys we care about, in place, idempotently.
codex_config_set() {
  key="$1"
  value="$2"
  file="$HOME/.codex/config.toml"
  tmp_file=$(mktemp)
  if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
    sed -E "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$file" > "$tmp_file"
  else
    # Top-level keys must come before the first [table] header, otherwise TOML
    # reads them as members of that table.
    printf '%s = %s\n' "$key" "$value" > "$tmp_file"
    if head -1 "$file" | grep -q '^\['; then
      printf '\n' >> "$tmp_file"
    fi
    cat "$file" >> "$tmp_file"
  fi
  mv "$tmp_file" "$file"
  chmod 600 "$file"
}

mkdir -p ~/.codex
touch ~/.codex/config.toml
codex_config_set approval_policy '"never"'
codex_config_set sandbox_mode '"danger-full-access"'

# -----------------------------------------------------------------------------
# Grok CLI
# -----------------------------------------------------------------------------
# Keep Grok's mutable/user-specific config in place and manage only the setting
# that keeps the readable fullscreen UI while avoiding excessive redraws.
grok_config_set() {
  table="$1"
  key="$2"
  value="$3"
  file="$HOME/.grok/config.toml"
  tmp_file=$(mktemp)

  awk -v table="$table" -v key="$key" -v value="$value" '
    BEGIN {
      header = "[" table "]"
      in_table = 0
      table_found = 0
      key_set = 0
    }
    $0 == header {
      in_table = 1
      table_found = 1
      print
      next
    }
    /^\[[^]]+\][[:space:]]*$/ {
      if (in_table && !key_set) {
        print key " = " value
        key_set = 1
      }
      in_table = 0
      print
      next
    }
    in_table && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      print key " = " value
      key_set = 1
      next
    }
    { print }
    END {
      if (in_table && !key_set) {
        print key " = " value
      } else if (!table_found) {
        print ""
        print header
        print key " = " value
      }
    }
  ' "$file" > "$tmp_file"

  mv "$tmp_file" "$file"
  chmod 600 "$file"
}

mkdir -p ~/.grok
touch ~/.grok/config.toml
grok_config_set ui screen_mode '"fullscreen"'
ln -sf "$DOTFILES_DIR/grok/pager.toml" ~/.grok/pager.toml

# -----------------------------------------------------------------------------
# Antigravity CLI (successor to Gemini CLI)
# -----------------------------------------------------------------------------
# settings.json is NOT symlinked. The CLI writes trustedWorkspaces / model
# into it, so a symlink would leave dotfiles dirty with per-host paths.
# We only pin the keys we care about, in place, idempotently.
#
# Auth is Google-account OAuth (AI Pro / Ultra). Do not set
# modelProvider=gemini — that switches to GEMINI_API_KEY and bypasses the
# subscription quota.
agy_settings_set() {
  key="$1"
  value="$2"
  file="$HOME/.gemini/antigravity-cli/settings.json"
  mkdir -p "$(dirname "$file")"
  [ -f "$file" ] || printf '{}\n' > "$file"
  tmp_file=$(mktemp)
  jq --argjson v "$value" --arg k "$key" '.[$k] = $v' "$file" > "$tmp_file" \
    && mv "$tmp_file" "$file"
}

agy_settings_set enableTelemetry false
agy_settings_set showFeedbackSurvey false
agy_settings_set permissions '{"allow":["command(*)","read_file(*)","write_file(*)","read_url(*)","execute_url(*)","unsandboxed(*)"]}'

# Desktop IDE (if present): VS Code-style telemetry off. Shared agent
# harness also honours enableTelemetry above; this covers the editor
# process itself.
if [[ "$OS" == macos ]]; then
  ide_settings="$HOME/Library/Application Support/Antigravity/User/settings.json"
  if [[ -f "$ide_settings" ]] && command -v jq >/dev/null; then
    tmp_file=$(mktemp)
    jq '."telemetry.telemetryLevel" = "off"' "$ide_settings" > "$tmp_file" \
      && mv "$tmp_file" "$ide_settings"
  fi
fi

# -----------------------------------------------------------------------------
# GitHub Copilot CLI
# -----------------------------------------------------------------------------
mkdir -p ~/.copilot
[ -f ~/.copilot/settings.json ] || printf '{}\n' > ~/.copilot/settings.json
tmp_file=$(mktemp)
jq '.model = "gpt-5.6-sol"' ~/.copilot/settings.json > "$tmp_file" && mv "$tmp_file" ~/.copilot/settings.json
chmod 600 ~/.copilot/settings.json
