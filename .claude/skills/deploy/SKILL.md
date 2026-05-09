---
name: deploy
description: Push local dotfiles changes to all four hosts (local, home, home2, ep). Use when the user says "deploy this", "push to other hosts", "他のPCにも反映", or after committing changes that need to land on remote machines.
---

# deploy

Roll committed dotfiles changes out to all four hosts.

## Hosts

| alias  | OS    | Hammerspoon | iTerm2 |
|--------|-------|-------------|--------|
| local  | macOS | yes         | yes    |
| home   | macOS | yes         | yes    |
| home2  | Linux | no          | no     |
| ep     | macOS | yes         | yes    |

`local` is wherever the user is editing right now (the `~/dotfiles/`
on this machine). The other three are reachable via the SSH config
aliases (`ssh home`, `ssh home2`, `ssh ep`).

## Standard sequence

1. **Verify the local repo is clean and pushed.**
   ```sh
   cd ~/dotfiles && git status && git log -1 --oneline
   ```
   If there are uncommitted changes the user wanted included, commit
   them first. If origin is behind, push.

2. **Decide what kind of change this is.** The remote-side steps differ:

   | Change touches…             | Extra step on remote? |
   |-----------------------------|-----------------------|
   | Lua/Vim/shell config only   | none — `git pull` is enough |
   | `iterm2/com.googlecode.iterm2.plist` | iTerm2 must be killed before the pull on macOS hosts (iTerm2 will rewrite the plist on quit otherwise). After pull, also patch `~/Library/Preferences/com.googlecode.iterm2.plist` if it has the same key cached. |
   | `.hammerspoon/init.lua`      | The auto-reload pathwatcher will re-pick the new lua *if* a previous reload had already wired it up. Otherwise the user has to Reload Config manually from the menu bar (note this in your status update). |
   | New iTerm2 profile-scoped `defaults` (e.g. `NeverWarnAboutShortLivedSessions_<GUID>`) | Run the corresponding `defaults write` on the remote — those keys don't ride along with PrefsCustomFolder. |
   | New Vim plugin or test framework | `git clone --depth 1 ... ~/.vim/pack/plugins/start/<name>` on the remote (use the same URL install.sh would). |

3. **Pull on each remote.**
   ```sh
   for h in home home2 ep; do
     echo "=== $h ==="
     ssh "$h" 'cd ~/dotfiles && git pull --rebase origin master 2>&1 | tail -3'
   done
   ```

   If a host has uncommitted local changes blocking the rebase
   (commonly `.skk/userJisyo` from SKK learning), `git stash push` that
   path before pulling and `git stash pop` after.

4. **For iTerm2 plist changes:** kill iTerm2 first, *then* pull, then
   patch the Library/Preferences plist if needed:
   ```sh
   ssh "$h" '
     pkill -9 -f "iTerm" 2>/dev/null; sleep 1
     cd ~/dotfiles && git pull --rebase origin master
     # Optional follow-up: patch ~/Library/Preferences/com.googlecode.iterm2.plist
     # if a key was changed that iTerm2 caches there (e.g. Rows).
   '
   ```

5. **Verify.** For each macOS host, confirm the relevant plist key:
   ```sh
   ssh "$h" 'plutil -p ~/dotfiles/iterm2/com.googlecode.iterm2.plist \
     | awk "/Japanese Input/,/^      \},$/" | grep -E "Rows|Normal Font"'
   ```

   For other config, reading back the file via ssh is enough.

## Anti-patterns

- **Don't run `bash install.sh` on remotes.** It still contains legacy
  AstroNvim-clone logic and a couple of other surprises. Lift the
  specific lines you need out of it manually.

- **Don't `git pull` while iTerm2 is running** if the change touches
  the plist. iTerm2 will dutifully overwrite your new plist on its
  next quit.

- **Don't assume Hammerspoon picked up `init.lua` changes.** Always
  remind the user to Reload Config the first time the new pathwatcher
  arrives. After that it's automatic.

- **Don't push GUI-side iTerm2 changes blindly.** GUI-driven plist
  edits are fine, but they include host-specific paths sometimes
  (`Working Directory`, `PrefsCustomFolder`). Sanitize first; check
  with `plutil -p iterm2/com.googlecode.iterm2.plist | grep -E '/Users/(yuto\.ida|yida|ida)'`
  — that grep should produce nothing.
