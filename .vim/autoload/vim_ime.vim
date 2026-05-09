" =============================================================================
" autoload/vim_ime.vim
"
" Pure-ish helpers for the SKK IME pad (~/.vimrc). Kept in autoload so they
" can be unit-tested with vim-themis without the rest of .vimrc booting up.
"
" Each function is deterministic given its inputs (no global state, no
" plugin calls). The .vimrc passes Vim's mode() / skkeleton#mode() into
" them and uses the returned label/highlight strings to build the
" statusline.
" =============================================================================

" Map a Vim mode() return value to {label, highlight_group}. The label is
" what we render in the statusline; the highlight is the StatusModeX
" group that should be linked into StatusLine while we're in that mode.
"
" The kanji label is always exactly three columns wide (` X `) so the
" powerline arrow that follows it lines up cleanly.
function! vim_ime#mode_label(mode) abort
  if a:mode ==# 'n'
    return {'label': '  普 ', 'hl': 'StatusModeN'}
  elseif a:mode ==# 'i'
    return {'label': '  入 ', 'hl': 'StatusModeI'}
  elseif a:mode ==# 'v' || a:mode ==# 'V' || a:mode ==# "\<C-v>"
    return {'label': '  選 ', 'hl': 'StatusModeV'}
  elseif a:mode ==# 'R'
    return {'label': '  換 ', 'hl': 'StatusModeR'}
  elseif a:mode ==# 'c'
    return {'label': '  令 ', 'hl': 'StatusModeC'}
  else
    return {'label': '  ' . a:mode . ' ', 'hl': 'StatusModeN'}
  endif
endfunction

" The arrow chip between the mode chip and the SKK chip needs its fg to
" track the current mode chip's background colour. Centralise that
" mapping here so the .vimrc just looks up a hex string.
function! vim_ime#mode_arrow_color(mode) abort
  if a:mode ==# 'n'
    return '#f39800'
  elseif a:mode ==# 'i'
    return '#f4b3c2'
  elseif a:mode ==# 'v' || a:mode ==# 'V' || a:mode ==# "\<C-v>"
    return '#e2041b'
  elseif a:mode ==# 'R'
    return '#eb6101'
  elseif a:mode ==# 'c'
    return '#f7c114'
  else
    return '#f39800'
  endif
endfunction

" Map a skkeleton mode string (or empty / nil for "off") to the chip
" label shown in the statusline. ' 󰊠 ' (U+F00A0) is a Nerd Font glyph
" that suggests "language toggle".
"
" `enabled` is whether SKK is currently on; when false the mode value
" is irrelevant and we always show 英 (English).
function! vim_ime#skk_label(enabled, mode) abort
  if !a:enabled
    return ' 󰊠 英 '
  endif
  if a:mode ==# 'hira'
    return ' 󰊠 あ '
  elseif a:mode ==# 'kata'
    return ' 󰊠 ア '
  elseif a:mode ==# 'hankata'
    return ' 󰊠 ｱ '
  elseif a:mode ==# 'abbrev'
    return ' 󰊠 ab '
  else
    return ' 󰊠 ' . a:mode . ' '
  endif
endfunction

" Whether the buffer needs a trailing blank line appended for the IME pad
" to "always start a fresh line at the bottom" semantics. Returns true
" when the last line is non-empty.
function! vim_ime#needs_trailing_blank(lines) abort
  if empty(a:lines)
    return v:false
  endif
  return a:lines[-1] !=# ''
endfunction
