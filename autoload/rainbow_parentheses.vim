"==============================================================================
"  Description: Rainbow colors for parentheses, based on rainbow_parenthsis.vim
"               by Martin Krischik and others.
"==============================================================================

function! s:uniq(list) abort
  let l:ret = []
  let l:map = {}
  for l:items in a:list
    let l:ok = 1
    for l:item in filter(copy(l:items), '!empty(v:val)')
      if has_key(l:map, l:item)
        let l:ok = 0
      endif
      let l:map[l:item] = 1
    endfor
    if l:ok
      call add(l:ret, l:items)
    endif
  endfor
  return l:ret
endfunction

" Excerpt from https://github.com/junegunn/vim-journal
" http://stackoverflow.com/questions/27159322/rgb-values-of-the-colors-in-the-ansi-extended-colors-index-17-255
let s:ansi16 = {
  \ 0:  '#000000', 1:  '#800000', 2:  '#008000', 3:  '#808000',
  \ 4:  '#000080', 5:  '#800080', 6:  '#008080', 7:  '#c0c0c0',
  \ 8:  '#808080', 9:  '#ff0000', 10: '#00ff00', 11: '#ffff00',
  \ 12: '#0000ff', 13: '#ff00ff', 14: '#00ffff', 15: '#ffffff' }
function! s:rgb(color) abort
  if a:color[0] ==# '#'
    let l:r = str2nr(a:color[1:2], 16)
    let l:g = str2nr(a:color[3:4], 16)
    let l:b = str2nr(a:color[5:6], 16)
    return [l:r, l:g, l:b]
  endif

  let l:ansi = str2nr(a:color)

  if l:ansi < 16
    return s:rgb(s:ansi16[l:ansi])
  endif

  if l:ansi >= 232
    let l:v = (l:ansi - 232) * 10 + 8
    return [l:v, l:v, l:v]
  endif

  let l:r = (l:ansi - 16) / 36
  let l:g = ((l:ansi - 16) % 36) / 6
  let l:b = (l:ansi - 16) % 6

  return map([l:r, l:g, l:b], 'v:val > 0 ? (55 + v:val * 40) : 0')
endfunction

" http://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color
" http://alienryderflex.com/hsp.html
function! s:brightness_(rgb) abort
  let [l:max, l:min] = map([max(a:rgb), min(a:rgb)], 'v:val / 255.0')
  let [l:r, l:g, l:b]  = map(a:rgb, 'v:val / 255.0')
  if l:max == l:min
    return (l:max + l:min) / 2.0
  endif
  return sqrt(0.299 * l:r * l:r + 0.587 * l:g * l:g + 0.114 * l:b * l:b)
endfunction

let s:brightness = {}
function! s:brightness(color) abort
  let l:color = filter(copy(a:color), '!empty(v:val)')[0]
  if has_key(s:brightness, l:color)
    return s:brightness[l:color]
  endif
  let l:b = s:brightness_(s:rgb(l:color))
  let s:brightness[l:color] = l:b
  return l:b
endfunction

function! s:colors_to_hi(colors) abort
  return
    \ join(
    \   values(
    \     map(
    \       filter({ 'ctermfg': a:colors[0], 'guifg': a:colors[1] },
    \              '!empty(v:val)'),
    \       'v:key."=".v:val')), ' ')
endfunction

function! s:extract_fg(line) abort
  let l:cterm = matchstr(a:line, 'ctermfg=\zs\S*\ze')
  let l:gui   = matchstr(a:line, 'guifg=\zs\S*\ze')
  return [l:cterm, l:gui]
endfunction

function! s:blacklist() abort
  redir => l:output
    silent! hi Normal
  redir END
  let l:line  = split(l:output, '\n')[0]
  let l:cterm = matchstr(l:line, 'ctermbg=\zs\S*\ze')
  let l:gui   = matchstr(l:line, 'guibg=\zs\S*\ze')
  let l:blacklist = {}
  if !empty(l:cterm) | let l:blacklist[l:cterm] = 1 | endif
  if !empty(l:gui)   | let l:blacklist[l:gui]   = 1 | endif
  return [l:blacklist, s:extract_fg(l:line)]
endfunction

let s:colors = { 'light': {}, 'dark': {} }
function! s:extract_colors() abort
  if exists('g:colors_name') && has_key(s:colors[&background], g:colors_name)
    return s:colors[&background][g:colors_name]
  endif
  redir => l:output
    silent hi
  redir END
  let l:lines = filter(split(l:output, '\n'), 'v:val =~# "fg" && v:val !~? "links" && v:val !~# "bg"')
  let l:colors = s:uniq(reverse(map(l:lines, 's:extract_fg(v:val)')))
  let [l:blacklist, l:fg] = s:blacklist()
  for l:c in get(g:, 'rainbow#blacklist', [])
    let l:blacklist[l:c] = 1
  endfor
  let l:colors = filter(l:colors,
        \ '!has_key(l:blacklist, v:val[0]) && !has_key(l:blacklist, v:val[1])')

  if !empty(filter(copy(l:fg), '!empty(v:val)'))
    let l:nb = s:brightness(l:fg)
    let [l:first, l:second] = [[], []]
    for l:cpair in l:colors
      let l:b = s:brightness(l:cpair)
      let l:diff = abs(l:nb - l:b)
      if l:diff <= 0.25
        call add(l:first, l:cpair)
      elseif l:diff <= 0.5
        call add(l:second, l:cpair)
      endif
    endfor
    let l:colors = extend(l:first, l:second)
  endif

  let l:colors = map(l:colors, 's:colors_to_hi(v:val)')
  if exists('g:colors_name')
    let s:colors[&background][g:colors_name] = l:colors
  endif
  return l:colors
endfunction

function! s:show_colors() abort
  for l:level in reverse(range(1, s:max_level))
    execute 'hi rainbowParensShell'.l:level
  endfor
endfunction

let s:generation = 0
function! rainbow_parentheses#activate(...) abort
  let l:force = get(a:000, 0, 0)
  if exists('#rainbow_parentheses') && get(b:, 'rainbow_enabled', -1) == s:generation && !l:force
    return
  endif

  let s:generation += 1
  let s:max_level = get(g:, 'rainbow#max_level', 16)
  let l:colors = exists('g:rainbow#colors') ?
    \ map(copy(g:rainbow#colors[&bg]), 's:colors_to_hi(v:val)') :
    \ s:extract_colors()

  for l:level in range(1, s:max_level)
    let l:col = l:colors[(l:level - 1) % len(l:colors)]
    execute printf('hi rainbowParensShell%d %s', s:max_level - l:level + 1, l:col)
  endfor
  call s:regions(s:max_level)

  command! -bang -nargs=? -bar RainbowParenthesesColors call s:show_colors()
  augroup rainbow_parentheses
    autocmd!
    autocmd ColorScheme,Syntax * call rainbow_parentheses#activate(1)
  augroup END
  let b:rainbow_enabled = s:generation
endfunction

function! rainbow_parentheses#deactivate() abort
  if exists('#rainbow_parentheses')
    for l:level in range(1, s:max_level)
      " FIXME How to cope with changes in rainbow#max_level?
      silent! execute 'hi clear rainbowParensShell'.l:level
      " FIXME buffer-local
      silent! execute 'syntax clear rainbowParens'.l:level
    endfor
    augroup rainbow_parentheses
      autocmd!
    augroup END
    augroup! rainbow_parentheses
    delc RainbowParenthesesColors
  endif
endfunction

function! rainbow_parentheses#toggle() abort
  if exists('#rainbow_parentheses')
    call rainbow_parentheses#deactivate()
  else
    call rainbow_parentheses#activate()
  endif
endfunction

function! s:regions(max) abort
  let l:pairs = get(g:, 'rainbow#pairs', [['(',')']])
  for l:level in range(1, a:max)
    let l:cmd = 'syntax region rainbowParens%d matchgroup=rainbowParensShell%d start=/%s/ end=/%s/ contains=%s fold'
    let l:children = extend(['TOP'], map(range(l:level, a:max), '"rainbowParens".v:val'))
    for l:pair in l:pairs
      let [l:open, l:close] = map(copy(l:pair), 'escape(v:val, "[]/")')
      execute printf(l:cmd, l:level, l:level, l:open, l:close, join(l:children, ','))
    endfor
  endfor
endfunction

