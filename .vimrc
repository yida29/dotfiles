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

let s:scratch_file = expand('~/Documents/ime-scratch.md')
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
set noshowmode
set noshowcmd
set clipboard=unnamedplus
set noswapfile
set nobackup
set nowritebackup
set encoding=utf-8

" Disable <C-c> in insert / cmdline modes so it stops standing in for <Esc>.
" Vim's default behaviour treats <C-c> like a weak Esc; map it to <Nop> to
" force ourselves to actually use <Esc> (or <C-[>).
inoremap <C-c> <Nop>
cnoremap <C-c> <Nop>

" Colorscheme.
set background=dark
if has('termguicolors')
  set termguicolors
endif
" Kanagawa variants: kanagawa (wave) / kanagawa-dragon / kanagawa-lotus
silent! colorscheme kanagawa

" -----------------------------------------------------------------------------
" Statusline: only show what's actually useful for an IME pad, and colour each
" piece using the kanagawa palette so it's pleasant to glance at.
"   center: SKK mode  ([hira] green / [kata] violet / [off] gray)
"   right : current line's char count (yellow) · clock (blue)
" -----------------------------------------------------------------------------

" Status segments — each calls into a tiny helper that picks a highlight
" group based on current state. The %#GroupName# escape switches the
" highlight group used to render subsequent text.
function! StatusSkk() abort
  if !exists('g:loaded_skkeleton') || !skkeleton#is_enabled()
    return '%#StatusSkkOff#[off]%*'
  endif
  let l:mode = skkeleton#mode()
  if l:mode ==# 'hira'
    return '%#StatusSkkHira#[hira]%*'
  elseif l:mode ==# 'kata' || l:mode ==# 'hankata'
    return '%#StatusSkkKata#[' . l:mode . ']%*'
  else
    return '%#StatusSkkOther#[' . l:mode . ']%*'
  endif
endfunction

function! LineCharCount() abort
  return strchars(getline('.'))
endfunction

set statusline=%=%{%StatusSkk()%}%=
set statusline+=%#StatusChars#%{LineCharCount()}\ chars%*
set statusline+=%#StatusDot#\ ·\ %*
set statusline+=%#StatusClock#%{strftime('%H:%M')}%*\

" Tick the clock once a minute so %{strftime} stays fresh without typing.
let s:clock_timer = timer_start(60000, { -> execute('redrawstatus') }, {'repeat': -1})

" Highlight groups (kanagawa wave palette).
" Statusline background is the same as the editor background (#1F1F28 sumiInk3)
" so the bar blends in instead of looking like a separate plate.
function! s:apply_status_highlights() abort
  highlight! StatusSkkHira  guifg=#98BB6C guibg=#1F1F28 gui=bold
  highlight! StatusSkkKata  guifg=#957FB8 guibg=#1F1F28 gui=bold
  highlight! StatusSkkOff   guifg=#54546D guibg=#1F1F28
  highlight! StatusSkkOther guifg=#7FB4CA guibg=#1F1F28 gui=bold
  highlight! StatusChars    guifg=#E6C384 guibg=#1F1F28
  highlight! StatusDot      guifg=#54546D guibg=#1F1F28
  highlight! StatusClock    guifg=#7E9CD8 guibg=#1F1F28
  highlight! StatusLine     guifg=#DCD7BA guibg=#1F1F28 gui=NONE cterm=NONE
  highlight! StatusLineNC   guifg=#54546D guibg=#1F1F28 gui=NONE cterm=NONE
endfunction

augroup vim_ime_status_colors
  autocmd!
  autocmd VimEnter,ColorScheme * call s:apply_status_highlights()
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
  call s:ensure_trailing_blank_line()
  normal! G
  call timer_start(0, { -> execute('startinsert!') })
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
