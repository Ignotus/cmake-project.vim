" cmake-project.vim -- pure tree construction and rendering
"
" Everything in this file is a pure function: no buffers, no windows, no
" globals (except #default_opts, which exists to read them in one place).
" That is what makes it testable without an editor session or a cmake run.

let s:save_cpo = &cpoptions
set cpoptions&vim

" A node is:
"   {'name': 'util', 'path': 'src/util', 'dirs': {name -> node}, 'files': [file]}
" A file is:
"   {'name': 'x.cpp', 'path': 'src/util/x.cpp', 'abs': '/root/src/util/x.cpp'}
"
" Fold state deliberately does NOT live here -- it is a separate path-keyed
" dict owned by the caller, so rebuilding the tree cannot destroy it.
function! cmakeproject#tree#new(name, path) abort
  return {'name': a:name, 'path': a:path, 'dirs': {}, 'files': []}
endfunction

function! cmakeproject#tree#default_opts() abort
  return {
        \ 'indent': '   ',
        \ 'open_symbol': get(g:, 'cmake_project_folder_open_symbol', '-'),
        \ 'close_symbol': get(g:, 'cmake_project_folder_close_symbol', '+'),
        \ 'file_prefix': ' ',
        \ }
endfunction

" Return a:path expressed relative to a:root, or v:null when the path lies
" outside the source tree. Returning v:null (rather than a mangled string) is
" what lets the caller skip such files instead of corrupting their names.
function! cmakeproject#tree#relativize(root, path) abort
  let l:path = substitute(a:path, '\\', '/', 'g')
  let l:root = substitute(substitute(a:root, '\\', '/', 'g'), '/\+$', '', '')

  if !s:is_absolute(l:path)
    return substitute(l:path, '^\%(\./\)\+', '', '')
  endif

  if empty(l:root)
    return v:null
  endif

  " Compare against root plus the separator, so /srcfoo/x.c is correctly
  " rejected for root /src rather than silently becoming 'oo/x.c'.
  let l:prefix = l:root . '/'
  if stridx(l:path, l:prefix) != 0
    return v:null
  endif

  let l:rel = strpart(l:path, strlen(l:prefix))
  return empty(l:rel) ? v:null : l:rel
endfunction

function! s:is_absolute(path) abort
  return a:path =~# '^/' || a:path =~# '^\a:/'
endfunction

" Build a tree from a list of File API source paths (each either relative to
" a:root or absolute). Out-of-tree paths are skipped; duplicates -- which the
" File API produces routinely, since a target appears once per configuration
" -- collapse to a single entry.
function! cmakeproject#tree#build(root, paths) abort
  let l:root = substitute(substitute(a:root, '\\', '/', 'g'), '/\+$', '', '')
  let l:tree = cmakeproject#tree#new('', '')
  let l:seen = {}

  for l:raw in a:paths
    let l:rel = cmakeproject#tree#relativize(l:root, l:raw)
    if type(l:rel) != type('') || empty(l:rel) || has_key(l:seen, l:rel)
      continue
    endif
    let l:seen[l:rel] = 1

    let l:parts = split(l:rel, '/')
    if empty(l:parts)
      continue
    endif
    let l:fname = remove(l:parts, -1)

    let l:node = l:tree
    let l:acc = ''
    for l:part in l:parts
      let l:acc = empty(l:acc) ? l:part : l:acc . '/' . l:part
      if !has_key(l:node.dirs, l:part)
        let l:node.dirs[l:part] = cmakeproject#tree#new(l:part, l:acc)
      endif
      let l:node = l:node.dirs[l:part]
    endfor

    call add(l:node.files, {
          \ 'name': l:fname,
          \ 'path': l:rel,
          \ 'abs': empty(l:root) ? l:rel : l:root . '/' . l:rel,
          \ })
  endfor

  return l:tree
endfunction

" Case-insensitive, numeric-aware comparison: 'a2' sorts before 'a10'.
" This is what the 2.x sort-key lambda was reaching for before it was broken
" by being written for strings while operating on tuples.
function! cmakeproject#tree#compare(a, b) abort
  let l:x = s:chunks(tolower(a:a))
  let l:y = s:chunks(tolower(a:b))
  let l:n = min([len(l:x), len(l:y)])

  let l:i = 0
  while l:i < l:n
    let l:p = l:x[l:i]
    let l:q = l:y[l:i]
    if l:p =~# '^\d' && l:q =~# '^\d'
      let l:np = str2nr(l:p)
      let l:nq = str2nr(l:q)
      if l:np != l:nq
        return l:np < l:nq ? -1 : 1
      endif
    elseif l:p !=# l:q
      return l:p <# l:q ? -1 : 1
    endif
    let l:i += 1
  endwhile

  if len(l:x) != len(l:y)
    return len(l:x) < len(l:y) ? -1 : 1
  endif

  " Break tolower() ties on the original strings so the order is total.
  return a:a ==# a:b ? 0 : (a:a <# a:b ? -1 : 1)
endfunction

" Split into alternating digit / non-digit runs.
function! s:chunks(s) abort
  return split(substitute(a:s, '\d\+', "\x01&\x01", 'g'), "\x01")
endfunction

" Flatten the tree into parallel lists:
"   lines[i]  -- the text of buffer line i+1
"   index[i]  -- what that line refers to
"
" One dense list per render, rather than the 2.x pair of dicts of which only
" one was ever reset. len(lines) == len(index) always holds.
function! cmakeproject#tree#flatten(tree, collapsed, opts) abort
  let l:acc = {'lines': [], 'index': []}
  call s:walk(a:tree, 0, a:collapsed, a:opts, l:acc)
  return l:acc
endfunction

function! s:walk(node, depth, collapsed, opts, acc) abort
  let l:indent = repeat(a:opts.indent, a:depth)

  " Directories first, then files -- both deterministically ordered.
  for l:name in sort(keys(a:node.dirs), function('cmakeproject#tree#compare'))
    let l:child = a:node.dirs[l:name]
    let l:shut = get(a:collapsed, l:child.path, 0)
    let l:symbol = l:shut ? a:opts.close_symbol : a:opts.open_symbol
    call add(a:acc.lines, l:indent . l:symbol . l:name)
    call add(a:acc.index, {'kind': 'dir', 'path': l:child.path})
    if !l:shut
      call s:walk(l:child, a:depth + 1, a:collapsed, a:opts, a:acc)
    endif
  endfor

  for l:file in sort(copy(a:node.files), function('s:compare_files'))
    call add(a:acc.lines, l:indent . a:opts.file_prefix . l:file.name)
    call add(a:acc.index, {'kind': 'file', 'path': l:file.path, 'abs': l:file.abs})
  endfor
endfunction

function! s:compare_files(a, b) abort
  return cmakeproject#tree#compare(a:a.name, a:b.name)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
