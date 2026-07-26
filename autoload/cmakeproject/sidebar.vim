" cmake-project.vim -- the project sidebar
"
" Deliberately holds no logic: what to display is computed by tree.vim, and
" this module only puts it on screen. Buffers are tracked by number, never by
" name -- :buffer matches names as patterns, which is how 2.x could raise E93
" on an ambiguous path.

let s:save_cpo = &cpoptions
set cpoptions&vim

" Kept for backwards compatibility; the buffer is identified by s:state.bufnr.
let s:bufname = '@CMakeProject'

function! s:width() abort
  return get(g:, 'cmake_project_bar_width', 40)
endfunction

" The window showing the sidebar in this tab page, or 0.
function! cmakeproject#sidebar#winid() abort
  let l:state = cmakeproject#state()
  if l:state.bufnr < 0
    return 0
  endif
  for l:nr in range(1, winnr('$'))
    if winbufnr(l:nr) == l:state.bufnr
      return win_getid(l:nr)
    endif
  endfor
  return 0
endfunction

function! cmakeproject#sidebar#is_open() abort
  return cmakeproject#sidebar#winid() != 0
endfunction

function! cmakeproject#sidebar#open() abort
  let l:state = cmakeproject#state()
  let l:winid = cmakeproject#sidebar#winid()

  if l:winid != 0
    call win_gotoid(l:winid)
    let l:state.sidebar_winid = l:winid
    call cmakeproject#sidebar#render()
    return
  endif

  " Remember where the user was, so opening a file returns there.
  if l:state.target_winid == 0 || win_id2win(l:state.target_winid) == 0
    let l:state.target_winid = win_getid()
  endif

  if bufexists(l:state.bufnr)
    execute 'topleft vertical sbuffer' l:state.bufnr
  else
    topleft vnew
    execute 'silent file' fnameescape(s:bufname)
    let l:state.bufnr = bufnr('%')
  endif

  execute 'vertical resize' s:width()
  let l:state.sidebar_winid = win_getid()
  call s:setup_buffer()
  call cmakeproject#sidebar#render()
endfunction

function! cmakeproject#sidebar#close() abort
  let l:winid = cmakeproject#sidebar#winid()
  if l:winid == 0
    return
  endif
  let l:current = win_getid()
  call win_gotoid(l:winid)
  if winnr('$') > 1
    close
  endif
  if l:current != l:winid
    call win_gotoid(l:current)
  endif
endfunction

function! cmakeproject#sidebar#toggle() abort
  if cmakeproject#sidebar#is_open()
    call cmakeproject#sidebar#close()
  else
    call cmakeproject#sidebar#open()
  endif
endfunction

" Re-render if the sidebar happens to be open, from wherever we are now.
" A no-op otherwise, so :CMakeGen does not force the bar open -- same as 2.x.
function! cmakeproject#sidebar#refresh() abort
  let l:winid = cmakeproject#sidebar#winid()
  if l:winid == 0
    return
  endif
  let l:current = win_getid()
  call win_gotoid(l:winid)
  try
    call cmakeproject#sidebar#render()
  finally
    call win_gotoid(l:current)
  endtry
endfunction

" Must be called with the sidebar as the current window.
function! cmakeproject#sidebar#render() abort
  let l:state = cmakeproject#state()
  if bufnr('%') != l:state.bufnr
    return
  endif

  let l:flat = s:contents(l:state)
  let b:cmakeproject_index = l:flat.index

  setlocal modifiable
  " No :normal dd/dG here: those obeyed user mappings (2.x even re-entered its
  " own <Space> map through a stray trailing space) and clobbered registers.
  silent keepjumps %delete _
  call append(0, l:flat.lines)
  silent keepjumps $delete _
  setlocal nomodifiable nomodified
endfunction

function! s:contents(state) abort
  if empty(a:state.tree)
    return s:placeholder([
          \ '" no CMake project loaded',
          \ '" :CMakeGen <build-dir>',
          \ ])
  endif

  let l:flat = cmakeproject#tree#flatten(
        \ a:state.tree, a:state.collapsed, cmakeproject#tree#default_opts())
  if empty(l:flat.lines)
    return s:placeholder(['" no sources found in ' . a:state.build])
  endif
  return l:flat
endfunction

" Placeholder rows carry empty index entries, so activate() ignores them and
" len(lines) == len(index) still holds.
function! s:placeholder(lines) abort
  return {'lines': a:lines, 'index': map(copy(a:lines), '{}')}
endfunction

function! s:setup_buffer() abort
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted nomodeline
  setlocal nowrap nonumber nolist nospell cursorline
  setlocal winfixwidth foldcolumn=0 nofoldenable nomodifiable
  if exists('+relativenumber')
    setlocal norelativenumber
  endif
  if exists('+signcolumn')
    setlocal signcolumn=no
  endif
  " Triggers ftplugin/cmakeproject.vim and syntax/cmakeproject.vim.
  setlocal filetype=cmakeproject
  " Fallback for users running with 'filetype plugin' off, who would
  " otherwise get a sidebar with no keys at all.
  call cmakeproject#sidebar#setup_mappings()
endfunction

function! cmakeproject#sidebar#setup_mappings() abort
  if exists('b:cmakeproject_mapped') || get(g:, 'cmake_project_no_mappings', 0)
    return
  endif
  let b:cmakeproject_mapped = 1

  " Buffer-local and non-recursive. 2.x installed a global, recursive
  " `map <Space>`, which also caught visual, select and operator-pending mode
  " in every buffer -- so d<Space> was broken editor-wide.
  nnoremap <buffer> <silent> <Space> :<C-u>call cmakeproject#sidebar#activate()<CR>
  nnoremap <buffer> <silent> <CR>    :<C-u>call cmakeproject#sidebar#activate()<CR>
  nnoremap <buffer> <silent> o       :<C-u>call cmakeproject#sidebar#activate()<CR>
  nnoremap <buffer> <silent> <2-LeftMouse> :<C-u>call cmakeproject#sidebar#activate()<CR>
  nnoremap <buffer> <silent> R       :<C-u>call cmakeproject#refresh()<CR>
  nnoremap <buffer> <silent> q       :<C-u>call cmakeproject#sidebar#close()<CR>
endfunction

function! cmakeproject#sidebar#activate() abort
  let l:entry = get(get(b:, 'cmakeproject_index', []), line('.') - 1, {})
  if empty(l:entry)
    return
  endif

  if get(l:entry, 'kind', '') ==# 'dir'
    call s:toggle_fold(l:entry.path)
  else
    call cmakeproject#sidebar#open_file(l:entry.abs)
  endif
endfunction

function! s:toggle_fold(path) abort
  let l:state = cmakeproject#state()
  if has_key(l:state.collapsed, a:path)
    call remove(l:state.collapsed, a:path)
  else
    let l:state.collapsed[a:path] = 1
  endif

  let l:view = winsaveview()
  call cmakeproject#sidebar#render()
  " Folding only adds or removes lines below the toggled one, so the cursor
  " line survives; clamp anyway in case the tree changed underneath us.
  let l:view.lnum = min([l:view.lnum, line('$')])
  call winrestview(l:view)
endfunction

function! cmakeproject#sidebar#open_file(path) abort
  let l:state = cmakeproject#state()
  let l:target = s:target_winid()

  if l:target != 0
    call win_gotoid(l:target)
  else
    " The sidebar is the only window; make one for the file and undo the
    " sidebar's window-local options that :vsplit just copied into it.
    botright vsplit
    call s:reset_window_options()
  endif

  " :edit rather than badd + :buffer -- the latter matches buffer names as
  " patterns, so paths with regex characters mis-target or raise E93.
  execute 'edit' fnameescape(a:path)
  let l:state.target_winid = win_getid()
endfunction

" 2.x used `wincmd l`, which assumed the sidebar was immediately left of
" exactly the window the user wanted. Any horizontal split broke that.
function! s:target_winid() abort
  let l:state = cmakeproject#state()
  let l:sidebar = cmakeproject#sidebar#winid()

  if l:state.target_winid != 0 && l:state.target_winid != l:sidebar
        \ && win_id2win(l:state.target_winid) != 0
    return l:state.target_winid
  endif

  for l:nr in range(1, winnr('$'))
    let l:id = win_getid(l:nr)
    if l:id == l:sidebar || getwinvar(l:nr, '&previewwindow', 0)
      continue
    endif
    if getbufvar(winbufnr(l:nr), '&buftype', '') !=# ''
      continue
    endif
    return l:id
  endfor

  return 0
endfunction

" '<' restores each window-local option to its global value.
function! s:reset_window_options() abort
  setlocal wrap< number< list< spell< cursorline<
  setlocal winfixwidth< foldcolumn< foldenable<
  if exists('+relativenumber')
    setlocal relativenumber<
  endif
  if exists('+signcolumn')
    setlocal signcolumn<
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
