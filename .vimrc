" =============================================================================
" .vimrc — used purely as a SKK Japanese-input pad these days. Coding lives
" in Neovim (~/.config/nvim). When Vim launches (Cmd+J hotkey window, git
" commit, etc.) it opens straight into hira mode.
"
" Plugins (denops.vim, skkeleton, vim-hybrid) live under ~/.vim/pack/plugins/
" start/ and are loaded by Vim's native :h packages mechanism. install.sh
" clones them.
" =============================================================================

" Some launch paths (e.g. `vim -u ~/.vimrc`, sourced by another vimrc) don't
" auto-enable nocompatible, which breaks line-continuation `\` and several
" plugin macros. Force it on.
set nocompatible

" Enable syntax highlighting and filetype-aware indent/plugins. Without
" `syntax enable`, custom `:syntax match` rules silently do nothing.
syntax enable
filetype plugin indent on

" Truecolor: iTerm2 advertises COLORTERM=truecolor even when $TERM is set to
" something conservative like screen-256color (e.g. when tmux is the parent
" and exports it down). Without these escape sequences and termguicolors,
" all the kanagawa hex colors silently round to the nearest 256-color
" approximation and our highlights look washed out / identical.
if $COLORTERM ==# 'truecolor' || $COLORTERM ==# '24bit'
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  set termguicolors
endif

let s:scratch_file = expand('~/Documents/ime-scratch')
let s:skk_dict     = expand('~/.skk/SKK-JISYO.L')
let s:commit_url   = 'hammerspoon://nvim-ime-commit'

" iTerm2's hotkey window may launch Vim via `bash -c`, which bypasses .zshrc
" / .bashrc, so $PATH only contains the system defaults. denops needs `deno`
" in $PATH; explicitly add the locations it can live in.
let $PATH = $HOME . '/.local/bin:/opt/homebrew/bin:' . $HOME . '/.deno/bin:' . $PATH

" -----------------------------------------------------------------------------
" Minimal UI / behaviour.
" -----------------------------------------------------------------------------
set number
set norelativenumber
set signcolumn=no
set laststatus=2
set cmdheight=1
set noruler
" The mode indicator goes into the statusline below; no need to also have
" Vim print "-- INSERT --" in the command line area.
set noshowmode
set noshowcmd
set clipboard=unnamedplus
set noswapfile
set nobackup
set nowritebackup
set encoding=utf-8

" Snappy mode switching: in a terminal, <Esc> is the prefix of escape codes
" for arrow keys, function keys, etc., so Vim waits 'ttimeoutlen' before
" treating a lone <Esc> as ESC. Default is -1 (== timeoutlen, 1000ms),
" which makes leaving insert mode feel like pressing through molasses.
" 5ms is fine for a local iTerm2 hotkey window — escape sequences arrive
" within microseconds when the terminal lives on the same machine.
set ttimeout
set ttimeoutlen=5

" Disable <C-c> in insert / cmdline modes so it stops standing in for <Esc>.
" Vim's default behaviour treats <C-c> like a weak Esc; map it to <Nop> to
" force ourselves to actually use <Esc> (or <C-[>).
inoremap <C-c> <Nop>
cnoremap <C-c> <Nop>

" Colorscheme. termguicolors is set above when COLORTERM is truecolor.
set background=dark
" azumakuniyuki/vim-colorschemes — Japanese-traditional-color themes.
" Try: heiankyo / michitsuna / mikeneko / nebuchadnezzar / russian-blue /
" sabineko / shironeko / soba / tatami
silent! colorscheme sabineko

" -----------------------------------------------------------------------------
" Statusline: only show what's actually useful for an IME pad, and colour each
" piece using the kanagawa palette so it's pleasant to glance at.
"   center: SKK mode  ([hira] green / [kata] violet / [off] gray)
"   right : current line's char count (yellow) · clock (blue)
" -----------------------------------------------------------------------------

" Status segments. To keep redraws fast we read pre-computed string vars
" instead of calling functions on every redraw. The mode label and color
" are updated by ModeChanged below; SKK mode by skkeleton's User events.
function! StatusMode() abort
  return get(g:, 'vim_ime_mode_label', '  普 ')
endfunction

function! StatusSkk() abort
  return get(g:, 'vim_ime_skk_mode', ' 󰊠 英 ')
endfunction

function! StatusCharCount() abort
  return '  字 ' . strchars(getline('.')) . ' '
endfunction

" Powerline-style statusline. Layout:
"
"    普   󰊠 あ    字 42                       󰥔 22:05
"   ╰mode╯╰────skk───╯╰─chars─╯       ╰──clock──╯
"
" Each chip has its own bg color and the powerline arrow between two
" chips uses the previous chip's bg as fg, so the arrow appears to flow
" from one chip into the next. Requires a Nerd Font (provided by
" JetBrainsMono Nerd Font in the "Japanese Input" iTerm2 profile).
let g:vim_ime_sep_right = ''   " powerline arrow pointing right
let g:vim_ime_sep_left  = ''   " powerline arrow pointing left
let g:vim_ime_clock_icon = '󰥔'

set statusline=%#StatusLine#%{StatusMode()}
set statusline+=%#StatusSep1#%{g:vim_ime_sep_right}
set statusline+=%#StatusSkkChip#%{StatusSkk()}
set statusline+=%#StatusSep2#%{g:vim_ime_sep_right}
set statusline+=%#StatusCharsChip#%{StatusCharCount()}
set statusline+=%#StatusSep3#%{g:vim_ime_sep_right}
set statusline+=%#StatusFill#\ %=
set statusline+=%#StatusSep4#%{g:vim_ime_sep_left}
set statusline+=%#StatusClock#\ %{g:vim_ime_clock_icon}\ %{strftime('%H:%M')}\ %*

" Update the cached SKK mode whenever skkeleton tells us about a state
" change. This avoids calling skkeleton functions from the statusline
" expression on every cursor movement.
function! s:refresh_skk_mode() abort
  " 󰊠 (nf-md-translate) suggests "this is the language toggle".
  if !exists('g:loaded_skkeleton') || !skkeleton#is_enabled()
    let g:vim_ime_skk_mode = ' 󰊠 英 '
    return
  endif
  let l:m = skkeleton#mode()
  if l:m ==# 'hira'
    let g:vim_ime_skk_mode = ' 󰊠 あ '
  elseif l:m ==# 'kata'
    let g:vim_ime_skk_mode = ' 󰊠 ア '
  elseif l:m ==# 'hankata'
    let g:vim_ime_skk_mode = ' 󰊠 ｱ '
  elseif l:m ==# 'abbrev'
    let g:vim_ime_skk_mode = ' 󰊠 ab '
  else
    let g:vim_ime_skk_mode = ' 󰊠 ' . l:m . ' '
  endif
endfunction

augroup vim_ime_skk_mode_cache
  autocmd!
  autocmd User skkeleton-mode-changed call s:refresh_skk_mode()
  autocmd User skkeleton-enable-pre   call s:refresh_skk_mode()
  autocmd User skkeleton-enable-post  call s:refresh_skk_mode()
  autocmd User skkeleton-disable-pre  call s:refresh_skk_mode()
  autocmd User skkeleton-disable-post call s:refresh_skk_mode()
  autocmd VimEnter                    * let g:vim_ime_skk_mode = ' 英 '
augroup END

" Update both the mode label string and the StatusLine highlight on every
" mode change. Reading a pre-computed string in the statusline is much
" cheaper than calling mode() inside %{...}.
" The mode chip is `<vim icon> <kanji>` for that fish-prompt feel; the
" icon needs a Nerd Font (provided by JetBrainsMono Nerd Font in iTerm2).
function! s:refresh_mode() abort
  let l:m = mode()
  if l:m ==# 'n'
    let g:vim_ime_mode_label = '  普 '
    highlight! link StatusLine StatusModeN
  elseif l:m ==# 'i'
    let g:vim_ime_mode_label = '  入 '
    highlight! link StatusLine StatusModeI
  elseif l:m ==# 'v' || l:m ==# 'V' || l:m ==# "\<C-v>"
    let g:vim_ime_mode_label = '  選 '
    highlight! link StatusLine StatusModeV
  elseif l:m ==# 'R'
    let g:vim_ime_mode_label = '  換 '
    highlight! link StatusLine StatusModeR
  elseif l:m ==# 'c'
    let g:vim_ime_mode_label = '  令 '
    highlight! link StatusLine StatusModeC
  else
    let g:vim_ime_mode_label = '  ' . l:m . ' '
    highlight! link StatusLine StatusModeN
  endif
endfunction

augroup vim_ime_mode_refresh
  autocmd!
  autocmd ModeChanged * call s:refresh_mode() | call s:refresh_sep1_color()
  autocmd VimEnter    * call s:refresh_mode() | call s:refresh_sep1_color()
augroup END


" Highlight groups (kanagawa wave palette).
" Statusline background is the same as the editor background (#1F1F28 sumiInk3)
" so the bar blends in instead of looking like a separate plate. Mode pills
" use the dark background as foreground so the colored chip really pops.
function! s:apply_status_highlights() abort
  " Sabineko palette. Each chip has its own bg, and the powerline arrow
  " between two chips uses the previous chip's bg as its fg so the arrow
  " visually flows from one section into the next.
  "
  " Chip palette (warm tones only, no blue/violet):
  "   mode  : 山吹橙 / 桜 / 真紅 / 鮮橙 / 山吹黄  (per-mode)
  "   skk   : 焦茶 (#3f312b) bg + 生成り fg
  "   chars : 古茶 (#583822) bg + 山吹黄 fg
  "   clock : 焦茶 bg + 灰 fg
  let l:editor_bg = '#16160e'
  let l:skk_bg    = '#3f312b'  " 焦茶
  let l:chars_bg  = '#583822'  " 古茶
  let l:clock_bg  = '#3f312b'

  " Mode chips (left).
  highlight! StatusModeN guifg=#16160e guibg=#f39800 gui=bold
  highlight! StatusModeI guifg=#16160e guibg=#f4b3c2 gui=bold
  highlight! StatusModeV guifg=#ede4cd guibg=#e2041b gui=bold
  highlight! StatusModeR guifg=#16160e guibg=#eb6101 gui=bold
  highlight! StatusModeC guifg=#16160e guibg=#f7c114 gui=bold

  " Right-side chips.
  execute 'highlight! StatusSkkChip guifg=#ede4cd guibg=' . l:skk_bg . ' gui=bold'
  execute 'highlight! StatusCharsChip guifg=#f7c114 guibg=' . l:chars_bg
  execute 'highlight! StatusClock guifg=#afafb0 guibg=' . l:clock_bg

  " Filler in the middle uses the editor background.
  execute 'highlight! StatusFill guifg=#ede4cd guibg=' . l:editor_bg

  " Separators. Each arrow's fg = previous chip's bg, bg = next chip's bg.
  "   sep1: mode    -> skk    (fg follows mode color, set in refresh_sep1_color)
  "   sep2: skk     -> chars
  "   sep3: chars   -> fill (editor bg)
  "   sep4: fill    -> clock
  execute 'highlight! StatusSep2 guifg=' . l:skk_bg   . ' guibg=' . l:chars_bg
  execute 'highlight! StatusSep3 guifg=' . l:chars_bg . ' guibg=' . l:editor_bg
  execute 'highlight! StatusSep4 guifg=' . l:clock_bg . ' guibg=' . l:editor_bg

  " StatusLine itself starts as the normal-mode chip.
  highlight! link StatusLine StatusModeN
  execute 'highlight! StatusLineNC guifg=#595857 guibg=' . l:editor_bg
    \ . ' gui=NONE cterm=NONE'
endfunction

" Sep1 needs its fg to track whichever color the current mode chip uses.
" Re-define on every mode change.
function! s:refresh_sep1_color() abort
  let l:skk_bg = '#3f312b'
  let l:m = mode()
  if l:m ==# 'n'
    let l:fg = '#f39800'
  elseif l:m ==# 'i'
    let l:fg = '#f4b3c2'
  elseif l:m ==# 'v' || l:m ==# 'V' || l:m ==# "\<C-v>"
    let l:fg = '#e2041b'
  elseif l:m ==# 'R'
    let l:fg = '#eb6101'
  elseif l:m ==# 'c'
    let l:fg = '#f7c114'
  else
    let l:fg = '#f39800'
  endif
  execute 'highlight! StatusSep1 guifg=' . l:fg . ' guibg=' . l:skk_bg . ' gui=bold'
endfunction

augroup vim_ime_status_colors
  autocmd!
  autocmd VimEnter,ColorScheme * call s:apply_status_highlights()
augroup END

" -----------------------------------------------------------------------------
" Japanese script highlighting + skkeleton conversion markers.
"
" Color tracks the writing system so the eye picks out hiragana / katakana /
" kanji at a glance, and makes SKK's conversion state visually obvious:
"   ▽xxxxx   pre-conversion kana being typed (carpYellow)
"   ▼xxxxx   active conversion choosing a candidate (surimiOrange)
"   *        okurigana marker inside ▽ blocks (autumnRed)
" -----------------------------------------------------------------------------
function! s:apply_japanese_syntax() abort
  " Skip when called outside a real buffer context (e.g. ColorScheme that
  " fires before VimEnter).
  if !exists('b:changedtick')
    return
  endif

  " Toplevel matches; SKK markers come first so they win against the
  " bare kana matches that follow.
  syntax match JpSkkPre   /▽[^▼\n]*/
  syntax match JpSkkConv  /▼[^\n]*/
  syntax match JpSkkOkuri /\*/    contained containedin=JpSkkPre

  syntax match JpHiragana /[ぁ-ゖ゛-ゟ]\+/
  syntax match JpKatakana /[゠-ヿ]\+/
  syntax match JpKanji    /[一-龯々]\+/

  " Sabineko (rusty cat) palette — all warm tones, no blue/violet.
  "   ひらがな: 生成り (kinari, off-white) — 主役、最も読みやすい
  "   カタカナ: 桜色 (sakura, soft pink) — 外来語、柔らかく
  "   漢字    : 山吹橙 (yamabuki orange) — 強調、暖色
  "   ▽       : 山吹黄 (yellow) — 確定前、進行中
  "   ▼       : 鮮やかオレンジ — 変換候補、選択中
  "   *       : 真紅 — 送り仮名マーカー、警告色
  highlight! JpHiragana guifg=#ede4cd
  highlight! JpKatakana guifg=#f4b3c2
  highlight! JpKanji    guifg=#f39800
  highlight! JpSkkPre   guifg=#f7c114 gui=italic
  highlight! JpSkkConv  guifg=#eb6101 gui=bold
  highlight! JpSkkOkuri guifg=#e2041b gui=bold

endfunction

" Highlights only — re-applied when the colorscheme changes so kanagawa
" can't accidentally clobber them. The actual :syntax match commands run
" inside open_scratch_at_bottom() once the scratch buffer is loaded.
augroup vim_ime_japanese_syntax
  autocmd!
  autocmd ColorScheme * call s:apply_japanese_syntax()
augroup END

" -----------------------------------------------------------------------------
" Plugin configuration.
" -----------------------------------------------------------------------------
augroup vim_ime_skkeleton
  autocmd!
  autocmd User skkeleton-initialize-pre call s:skkeleton_init()
augroup END

function! s:skkeleton_init() abort
  call skkeleton#config({'globalDictionaries': [[s:skk_dict, 'euc-jp']]})
endfunction

" enable (not toggle): pressing <C-j> always lands in hira regardless of
" current state. Disable by leaving insert mode (<Esc>).
imap <C-j> <Plug>(skkeleton-enable)
cmap <C-j> <Plug>(skkeleton-enable)

" -----------------------------------------------------------------------------
" Helpers.
" -----------------------------------------------------------------------------
function! s:ensure_trailing_blank_line() abort
  let last = line('$')
  if last > 0 && getline(last) !=# ''
    call append(last, '')
  endif
endfunction

function! s:open_scratch_at_bottom() abort
  if !filereadable(s:scratch_file)
    call writefile([], s:scratch_file)
  endif
  execute 'edit ' . fnameescape(s:scratch_file)
  " Force a non-empty filetype so the syntax engine actually loads in this
  " buffer; without it our :syntax match commands silently noop. text.vim
  " is tiny and harmless for our use.
  setlocal filetype=text
  call s:apply_japanese_syntax()
  call s:ensure_trailing_blank_line()
  normal! G$
  startinsert!
endfunction

function! s:enter_hira() abort
  if mode() !~# 'i'
    startinsert!
  endif
  silent! call skkeleton#handle('enable', {})
endfunction

function! s:commit_and_quit() abort
  call system('open -g ' . shellescape(s:commit_url))
  silent! wall
  qa!
endfunction

function! s:autosave() abort
  if &modified && &buftype ==# '' && expand('%') !=# ''
    silent! write
  endif
endfunction

" -----------------------------------------------------------------------------
" Startup: only auto-open the scratch file when Vim is launched with no
" arguments (i.e. plain `vim` or the iTerm2 hotkey window). When invoked
" with a file (e.g. `vim foo.md`, `git commit`'s COMMIT_EDITMSG), respect
" that file but still drop into hira mode for convenience.
" -----------------------------------------------------------------------------
augroup vim_ime_startup
  autocmd!
  autocmd VimEnter * if argc() == 0 | call s:open_scratch_at_bottom() | endif
  autocmd User DenopsPluginPost:skkeleton call s:enter_hira()
augroup END

" -----------------------------------------------------------------------------
" Commit (normal/visual <CR>): yank current line / selection without trailing
" newline, hand off to Hammerspoon, then quit so the next Cmd+J starts fresh.
"
" Only enabled when editing the scratch file, otherwise <CR> behaves
" normally (so it doesn't break git commit messages, etc.).
" -----------------------------------------------------------------------------
function! s:commit_line() abort
  call setreg('+', getline('.'))
  call s:commit_and_quit()
endfunction

function! s:commit_selection() abort
  silent normal! gv"+y
  call setreg('+', substitute(getreg('+'), '\n$', '', ''))
  call s:commit_and_quit()
endfunction

nnoremap <silent> <CR> :call <SID>commit_line()<CR>
xnoremap <silent> <CR> :<C-u>call <SID>commit_selection()<CR>

" -----------------------------------------------------------------------------
" Auto-save the scratch buffer so :qa! never has to discard unsaved edits.
" -----------------------------------------------------------------------------
augroup vim_ime_autosave
  autocmd!
  autocmd InsertLeave,TextChanged,FocusLost * call s:autosave()
augroup END

