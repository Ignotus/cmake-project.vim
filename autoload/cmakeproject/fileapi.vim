" cmake-project.vim -- CMake File API client
"
" Replaces the 2.x approach of running the deprecated "CodeBlocks - Unix
" Makefiles" extra generator and parsing its .cbp XML. The File API is
" supported, generator-agnostic, and emits JSON that json_decode() reads
" natively -- so no Python interpreter is involved anywhere.
"
" See :help cmake-file-api or https://cmake.org/cmake/help/latest/manual/
" cmake-file-api.7.html. Requires CMake 3.14 or newer.
"
" Every failure here is raised as a 'cmake-project: ...' exception; callers
" catch it and report through cmakeproject#error(). Nothing reaches the user
" as a raw E-code.

let s:save_cpo = &cpoptions
set cpoptions&vim

" Our own query directory, rather than the shared top-level one, so we do not
" impose queries on build trees we share with other tools.
let s:client = 'client-vim-cmake-project'
let s:kinds = ['codemodel-v2', 'cmakeFiles-v1']

function! cmakeproject#fileapi#api_dir(build) abort
  return substitute(a:build, '/\+$', '', '') . '/.cmake/api/v1'
endfunction

function! cmakeproject#fileapi#reply_dir(build) abort
  return cmakeproject#fileapi#api_dir(a:build) . '/reply'
endfunction

" Ask CMake for the objects we need on its next run. The query files are
" empty and persist, so any later configure -- including one triggered by
" `make` or another editor -- refreshes the reply for free.
function! cmakeproject#fileapi#write_query(build) abort
  let l:dir = cmakeproject#fileapi#api_dir(a:build) . '/query/' . s:client
  if !isdirectory(l:dir)
    try
      call mkdir(l:dir, 'p')
    catch
      throw 'cmake-project: cannot create query directory ' . l:dir
    endtry
  endif
  for l:kind in s:kinds
    let l:file = l:dir . '/' . l:kind
    if !filereadable(l:file)
      if writefile([], l:file) != 0
        throw 'cmake-project: cannot write query file ' . l:file
      endif
    endif
  endfor
endfunction

" CMake documents the current index as "the one with the largest name in
" lexicographic order" -- deliberately not the newest mtime, since during a
" rewrite two index files briefly coexist.
function! cmakeproject#fileapi#index_file(build) abort
  let l:pattern = cmakeproject#fileapi#reply_dir(a:build) . '/index-*.json'
  let l:found = sort(glob(l:pattern, 1, 1))
  return empty(l:found) ? '' : l:found[-1]
endfunction

" Resolve an object kind ('codemodel-v2') to its jsonFile, relative to the
" reply directory. Prefers our own client, then the shared top-level reply,
" then any foreign client -- which is what lets :CMakeLoad read a build tree
" configured by CLion, VS Code or `cmake --preset`.
function! cmakeproject#fileapi#lookup(index, kind) abort
  let l:reply = get(a:index, 'reply', {})
  if type(l:reply) != type({})
    return ''
  endif

  for l:scope in [get(l:reply, s:client, {}), l:reply]
    let l:file = s:json_file(l:scope, a:kind)
    if !empty(l:file)
      return l:file
    endif
  endfor

  for l:name in sort(keys(l:reply))
    if l:name !~# '^client-'
      continue
    endif
    let l:file = s:json_file(l:reply[l:name], a:kind)
    if !empty(l:file)
      return l:file
    endif
  endfor

  return ''
endfunction

function! s:json_file(scope, kind) abort
  if type(a:scope) != type({})
    return ''
  endif
  let l:entry = get(a:scope, a:kind, 0)
  if type(l:entry) != type({})
    return ''
  endif
  let l:file = get(l:entry, 'jsonFile', '')
  return type(l:file) == type('') ? l:file : ''
endfunction

" Read a build tree's reply and return {'root': <source dir>, 'paths': [...]}.
" Paths are raw File API values: relative to the top-level source directory
" when inside it, absolute otherwise. Sorting out which is which is
" cmakeproject#tree#relativize's job, not ours.
function! cmakeproject#fileapi#load(build) abort
  if !isdirectory(a:build)
    throw 'cmake-project: no such build directory: ' . a:build
  endif

  let l:index_file = cmakeproject#fileapi#index_file(a:build)
  if empty(l:index_file)
    throw 'cmake-project: no File API reply in ' . a:build
          \ . ' -- run :CMakeGen to configure it'
  endif

  let l:reply_dir = cmakeproject#fileapi#reply_dir(a:build)
  let l:index = s:read_json(l:index_file)

  let l:codemodel_ref = cmakeproject#fileapi#lookup(l:index, 'codemodel-v2')
  if empty(l:codemodel_ref)
    throw 'cmake-project: reply in ' . a:build . ' has no codemodel-v2'
          \ . ' -- run :CMakeGen to refresh it'
  endif

  let l:codemodel = s:read_json(l:reply_dir . '/' . l:codemodel_ref)
  let l:root = substitute(
        \ get(get(l:codemodel, 'paths', {}), 'source', ''), '/\+$', '', '')
  if empty(l:root)
    throw 'cmake-project: codemodel in ' . a:build . ' has no source path'
  endif

  let l:paths = []
  let l:seen_targets = {}
  for l:config in s:list(get(l:codemodel, 'configurations', []))
    for l:target in s:list(get(l:config, 'targets', []))
      let l:file = get(l:target, 'jsonFile', '')
      " One target object is shared by every configuration that builds it.
      if empty(l:file) || has_key(l:seen_targets, l:file)
        continue
      endif
      let l:seen_targets[l:file] = 1
      for l:source in s:list(get(s:read_json(l:reply_dir . '/' . l:file),
            \ 'sources', []))
        if get(l:source, 'isGenerated', 0)
          continue
        endif
        call add(l:paths, get(l:source, 'path', ''))
      endfor
    endfor
  endfor

  " CMakeLists.txt and project .cmake modules. The CodeBlocks generator used
  " to list these alongside the sources; cmakeFiles-v1 is where they live now.
  let l:cmakefiles_ref = cmakeproject#fileapi#lookup(l:index, 'cmakeFiles-v1')
  if !empty(l:cmakefiles_ref)
    for l:input in s:list(get(s:read_json(
          \ l:reply_dir . '/' . l:cmakefiles_ref), 'inputs', []))
      if get(l:input, 'isGenerated', 0) || get(l:input, 'isExternal', 0)
            \ || get(l:input, 'isCMake', 0)
        continue
      endif
      call add(l:paths, get(l:input, 'path', ''))
    endfor
  endif

  return {'root': l:root, 'paths': filter(l:paths, '!empty(v:val)')}
endfunction

" Configure the project. Synchronous on purpose: a configure takes seconds,
" the 2.x `:!cmake` was blocking too (and cleared the screen), and an async
" shim would need to paper over Vim's out_cb/err_cb/exit_cb against Neovim's
" on_stdout/on_stderr/on_exit for no user-visible gain at this scope.
"
" Returns {'ok': 0|1, 'code': N, 'output': '...', 'cmd': '...'}; it never
" throws on a cmake failure, so the caller decides how to report.
function! cmakeproject#fileapi#configure(build, source, extra) abort
  call cmakeproject#fileapi#write_query(a:build)

  let l:argv = [shellescape(get(g:, 'cmake_project_cmake_program', 'cmake')),
        \ '-S', shellescape(a:source),
        \ '-B', shellescape(a:build)]
  call extend(l:argv, map(copy(a:extra), 'shellescape(v:val)'))

  " 2>&1 is required: neither editor's system() captures stderr, and cmake
  " reports every error there. Passing a String (not a List) keeps this going
  " through 'shell', which is what makes the redirection take effect.
  let l:cmd = join(l:argv) . ' 2>&1'
  let l:output = system(l:cmd)

  return {
        \ 'ok': v:shell_error == 0,
        \ 'code': v:shell_error,
        \ 'output': l:output,
        \ 'cmd': l:cmd,
        \ }
endfunction

function! s:read_json(path) abort
  if !filereadable(a:path)
    throw 'cmake-project: cannot read ' . a:path
  endif
  try
    let l:decoded = json_decode(join(readfile(a:path), "\n"))
  catch
    throw 'cmake-project: invalid JSON in ' . a:path
  endtry
  if type(l:decoded) != type({})
    throw 'cmake-project: expected a JSON object in ' . a:path
  endif
  return l:decoded
endfunction

" Guard against a malformed reply handing us a non-list where the schema
" promises an array.
function! s:list(value) abort
  return type(a:value) == type([]) ? a:value : []
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
