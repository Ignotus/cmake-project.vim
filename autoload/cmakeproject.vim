" cmake-project.vim -- state and command entry points
"
" Autoload files cannot share script-local state, so all of it lives here and
" the other modules reach it through cmakeproject#state(). That is what keeps
" tree.vim and fileapi.vim free of globals, and therefore testable.

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:state = {
      \ 'build': '',
      \ 'source': '',
      \ 'root': '',
      \ 'tree': {},
      \ 'collapsed': {},
      \ 'bufnr': -1,
      \ 'sidebar_winid': 0,
      \ 'target_winid': 0,
      \ 'last_output': '',
      \ 'last_cmd': '',
      \ }

" Returned by reference, so callers can both read and mutate it.
function! cmakeproject#state() abort
  return s:state
endfunction

" Test seam: drop everything except the collapsed set's identity.
function! cmakeproject#reset() abort
  let s:state.build = ''
  let s:state.source = ''
  let s:state.root = ''
  let s:state.tree = {}
  let s:state.collapsed = {}
  let s:state.bufnr = -1
  let s:state.sidebar_winid = 0
  let s:state.target_winid = 0
  let s:state.last_output = ''
  let s:state.last_cmd = ''
endfunction

function! cmakeproject#error(msg) abort
  echohl ErrorMsg
  for l:line in split(a:msg, "\n")
    echomsg l:line
  endfor
  echohl None
endfunction

function! cmakeproject#info(msg) abort
  echohl None
  echomsg a:msg
endfunction

" :CMakeGen [builddir] [cmake args...]
" Configure, then load. Anything after the build directory goes straight to
" cmake, so -DCMAKE_BUILD_TYPE=Debug and friends need no plugin option.
function! cmakeproject#gen(...) abort
  let l:args = copy(a:000)
  let l:build = s:resolve_build(empty(l:args) ? '' : remove(l:args, 0))
  let l:source = getcwd()

  try
    call cmakeproject#fileapi#write_query(l:build)
  catch /^cmake-project:/
    call cmakeproject#error(v:exception)
    return 0
  endtry

  call cmakeproject#info('cmake-project: configuring ' . l:build . '...')
  redraw
  let l:result = cmakeproject#fileapi#configure(l:build, l:source, l:args)
  let s:state.last_output = l:result.output
  let s:state.last_cmd = l:result.cmd

  if !l:result.ok
    call cmakeproject#error('cmake-project: cmake exited with '
          \ . l:result.code . ' -- :CMakeOutput for the full log')
    call cmakeproject#error(s:tail(l:result.output, 15))
    return 0
  endif

  let s:state.source = l:source
  return cmakeproject#load(l:build)
endfunction

" :CMakeLoad [builddir]
" Read an existing reply without configuring. Kept separate from :CMakeGen on
" purpose: silently skipping the configure when a reply already exists would
" leave the user wondering why their new source file never showed up.
function! cmakeproject#load(...) abort
  let l:build = s:resolve_build(a:0 ? a:1 : '')

  try
    let l:reply = cmakeproject#fileapi#load(l:build)
  catch /^cmake-project:/
    call cmakeproject#error(v:exception)
    return 0
  endtry

  let s:state.build = l:build
  let s:state.root = l:reply.root
  let s:state.tree = cmakeproject#tree#build(l:reply.root, l:reply.paths)

  " s:state.collapsed is deliberately left alone: fold state is keyed by path
  " and lives outside the tree, so rebuilding cannot lose it.
  call cmakeproject#sidebar#refresh()
  return 1
endfunction

" :CMakeRefresh -- reload the remembered build directory.
function! cmakeproject#refresh() abort
  if empty(s:state.build)
    call cmakeproject#error(
          \ 'cmake-project: nothing loaded yet -- run :CMakeGen <build-dir>')
    return 0
  endif
  return cmakeproject#load(s:state.build)
endfunction

" :CMakeOutput -- the last cmake invocation's log, in a scratch buffer.
function! cmakeproject#output() abort
  if empty(s:state.last_output) && empty(s:state.last_cmd)
    call cmakeproject#info('cmake-project: cmake has not been run yet')
    return
  endif

  new
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  silent file [cmake-output]
  call setline(1, ['$ ' . s:state.last_cmd, ''])
  call append(line('$'), split(s:state.last_output, "\n"))
  setlocal nomodifiable nomodified
endfunction

" Fall back to the remembered build directory, then to 'build'.
function! s:resolve_build(arg) abort
  let l:build = a:arg
  if empty(l:build)
    let l:build = !empty(s:state.build) ? s:state.build : 'build'
  endif
  " Expand ~ and $VAR, then make it absolute so a later :cd cannot strand us.
  let l:build = expand(l:build)
  return substitute(fnamemodify(l:build, ':p'), '/\+$', '', '')
endfunction

function! s:tail(text, count) abort
  let l:lines = filter(split(a:text, "\n"), '!empty(trim(v:val))')
  return join(l:lines[-a:count :], "\n")
endfunction

" Completion for :CMakeGen / :CMakeLoad. Only the first argument is a
" directory; the rest are cmake flags, which we must not dir-complete.
function! cmakeproject#complete(arglead, cmdline, cursorpos) abort
  if a:arglead =~# '^-'
    return []
  endif
  let l:head = substitute(a:cmdline, '\s*\S*$', '', '')
  if l:head =~# '^\s*\S\+\s\+\S'
    return []
  endif
  return sort(map(glob(a:arglead . '*', 1, 1),
        \ 'isdirectory(v:val) ? v:val . "/" : v:val'))
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
