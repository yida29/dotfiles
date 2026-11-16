; =============================================================================
; vim-ime pad for Windows — AutoHotkey v2.
;
; The Windows counterpart of iTerm2's "Japanese Input" hotkey profile plus
; .hammerspoon/init.lua on macOS:
;
;   Alt+J  -> remember the active window, open the pad (WezTerm running
;             `vim-ime` in WSL), wait for the pad window to close, then
;             paste the committed text into the remembered window.
;
; The pad writes the committed text to VIM_IME_COMMIT (see .vimrc
; s:commit_and_quit) instead of the clipboard, because WSL's Vim has no
; clipboard support. Quitting the pad without committing pastes nothing.
;
; install.sh copies this file into the Windows Startup folder.
; =============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
; Let a second Alt+J run while the first one is waiting for the pad to close,
; so it can bring the existing pad to the front.
#MaxThreadsPerHotkey 2

WEZTERM := EnvGet("ProgramFiles") "\WezTerm\wezterm-gui.exe"
COMMIT_FILE := A_Temp "\vim-ime-commit.txt"
PASTE_DELAY := 150

padPid := 0

!j:: OpenPad()

OpenPad() {
    global padPid

    if padPid && WinExist("ahk_pid " padPid) {
        WinActivate
        return
    }

    target := WinExist("A")
    try FileDelete(COMMIT_FILE)

    ; WezTerm reads VIM_IME_COMMIT to switch into pad mode (wezterm.lua).
    ; --always-new-process: otherwise it may open the window inside an
    ; already-running WezTerm that doesn't have this variable.
    EnvSet("VIM_IME_COMMIT", COMMIT_FILE)
    try {
        Run('"' WEZTERM '" start --always-new-process', , , &pid)
    } catch {
        EnvSet("VIM_IME_COMMIT")
        MsgBox("WezTerm not found: " WEZTERM, "vim-ime")
        return
    }
    EnvSet("VIM_IME_COMMIT")
    padPid := pid

    if !WinWait("ahk_pid " pid, , 10) {
        padPid := 0
        return
    }
    CenterOnScreen("ahk_pid " pid)
    WinActivate("ahk_pid " pid)

    WinWaitClose("ahk_pid " pid)
    padPid := 0

    if !FileExist(COMMIT_FILE)
        return
    text := FileRead(COMMIT_FILE, "UTF-8")
    FileDelete(COMMIT_FILE)
    if text = ""
        return

    A_Clipboard := StrReplace(StrReplace(text, "`r`n", "`n"), "`n", "`r`n")

    if target && WinExist("ahk_id " target) {
        WinActivate("ahk_id " target)
        WinWaitActive("ahk_id " target, , 1)
    }
    Sleep(PASTE_DELAY)
    ; Ctrl+V in a terminal sends a literal ^V; WezTerm pastes with Ctrl+Shift+V.
    if target && WinExist("ahk_id " target) && WinGetProcessName("ahk_id " target) = "wezterm-gui.exe"
        Send("^+v")
    else
        Send("^v")
}

CenterOnScreen(win) {
    WinGetPos(, , &w, &h, win)
    MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
    WinMove(left + (right - left - w) // 2, top + (bottom - top - h) // 2, , , win)
}
