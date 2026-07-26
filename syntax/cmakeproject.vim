" cmake-project.vim -- sidebar syntax

if exists('b:current_syntax')
  finish
endif

let s:save_cpo = &cpoptions
set cpoptions&vim

" The fold markers are user-configurable, so the patterns are built at load
" time rather than hard-coded.
let s:open = escape(get(g:, 'cmake_project_folder_open_symbol', '-'),
      \ '\/.*$^~[]')
let s:close = escape(get(g:, 'cmake_project_folder_close_symbol', '+'),
      \ '\/.*$^~[]')

execute 'syntax match cmakeProjectDirOpen /^\s*' . s:open . '.*$/'
execute 'syntax match cmakeProjectDirClosed /^\s*' . s:close . '.*$/'
syntax match cmakeProjectMessage /^".*$/

highlight default link cmakeProjectDirOpen Directory
highlight default link cmakeProjectDirClosed Special
highlight default link cmakeProjectMessage Comment

unlet s:open s:close
let b:current_syntax = 'cmakeproject'

let &cpoptions = s:save_cpo
unlet s:save_cpo
