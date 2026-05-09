---
paths:
  - ".hammerspoon/**"
---

# Hammerspoon gotchas

Things that broke once and we'd rather not rediscover.

## Performance

- **Don't call `hs.window.get(id)` on hot paths.** It enumerates every
  window in the system. On a host with lots of Chrome tabs we measured
  ~1.8s per call from inside the URL handler. Trust the cached window
  handle (`focus()` is fine to call on a stale one — worst case it's a
  no-op).

## Lua GC

- **Watchers and timers must be reachable from a strong root.** Storing
  them in file-local variables silently breaks: Lua may GC them at any
  time. We've seen `appWatcher` stop firing mid-session. Pin them on
  `_G` (e.g. `_G.imeAppWatcher = ...`). The `---@diagnostic
  disable-next-line: unused-local` annotation only quiets the linter,
  it does not extend the variable's lifetime.

## pathwatcher and symlinks

- **`hs.pathwatcher` doesn't follow symlinks transparently.** macOS will
  resolve a symlink to its target for the *initial* path, but writes
  that happen via the original path (e.g. a `git pull` into
  `~/dotfiles/.hammerspoon/`) are not picked up by a watcher pointed at
  `~/.hammerspoon/`. We watch both paths in `init.lua` so reloads work
  no matter which side of the symlink the change came from.

## iTerm2 hotkey window title

- **`looksLikeImeWindow` must cover *every* transient title.** The
  hotkey window cycles through `zsh` / `bash` / `fish` while the shell
  is starting, `vim` / `nvim` once the editor takes over, `ime-scratch`
  once the scratch buffer loads, `open` while the URL handler runs, `""`
  during transitions — and crucially **whitespace-only strings like
  `" "` between sessions**. Missing any of those lets the hotkey window
  itself slip into `previousWindow` and we end up pasting back into the
  IME pad. The lib treats anything matching `/^%s*$/` as IME.

## Window-focus tracking

- **`hs.application.watcher` only fires on app-level activation.**
  Switching between two windows of the same app (Slack ↔ iTerm2 main vs.
  Slack ↔ iTerm2 hotkey) doesn't trigger `activated`. The poller
  (`hs.timer.doEvery(POLL_INTERVAL, refreshTracking)`) is what keeps
  `previousWindow` honest in those cases. Don't rely on the watcher
  alone.

## Reloading

- **`hs.allowAppleScript(true)` is not enabled and the `hs` IPC module
  is not loaded.** That means there is no remote way to trigger
  `hs.reload()`: not via `osascript`, not via the `hs` CLI. Reloading
  must come from the menubar Reload Config item or pathwatcher
  detecting a `.lua` change on disk.

- **Reloads aren't always visible.** If the user just `git pull`-ed a
  change to this very file, the *new* pathwatcher / reload behaviour
  only takes effect after one manual Reload Config — until then,
  whatever was running before is still running. Tell the user to do
  that the first time.

## Testing

- **Pure helpers go in `lib/`, tests in `test/`.** We test with busted
  (`brew install lua@5.4 luarocks && luarocks install busted`) and pass
  in plain table stubs for windows / apps. Anything that touches `hs.*`
  is *not* covered by tests; verify those manually.

  ```sh
  cd ~/dotfiles/.hammerspoon && busted test/
  ```

- **Don't try to mock `hs.*` to test wider areas.** The Hammerspoon API
  surface is too large and the bugs we hit (GC, symlinks, focus
  ordering) live in glue code that wouldn't survive mocking anyway. Keep
  tests on the truly pure parts; trust manual verification for the rest.
