" cmake-project.vim -- sidebar filetype plugin

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

call cmakeproject#sidebar#setup_mappings()

let b:undo_ftplugin = 'unlet! b:cmakeproject_mapped b:cmakeproject_index'
      \ . ' | mapclear <buffer>'

let &cpoptions = s:save_cpo
unlet s:save_cpo
