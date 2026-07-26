" vim-cmake-project
" Copyright (C) 2012-2014 Minh Ngo <nlminhtl@gmail.com>
"
" Permission is hereby granted, free of charge, to any person obtaining a
" copy of this software and associated documentation files (the "Software"),
" to deal in the Software without restriction, including without limitation
" the rights to use, copy, modify, merge, publish, distribute, sublicense,
" and/or sell copies of the Software, and to permit persons to whom the
" Software is furnished to do so, subject to the following conditions:

" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.

" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
" SOFTWARE.

if exists('g:loaded_cmake_project')
  finish
endif

if !has('nvim') && v:version < 801
  echomsg 'cmake-project: requires Vim 8.1 or newer, or Neovim'
  finish
endif

if !exists('*json_decode')
  echomsg 'cmake-project: requires a Vim with json_decode()'
  finish
endif

let g:loaded_cmake_project = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

if !exists('g:cmake_project_show_bar')
  let g:cmake_project_show_bar = 0
endif

if !exists('g:cmake_project_bar_width')
  let g:cmake_project_bar_width = 40
endif

if !exists('g:cmake_project_folder_open_symbol')
  let g:cmake_project_folder_open_symbol = '-'
endif

if !exists('g:cmake_project_folder_close_symbol')
  let g:cmake_project_folder_close_symbol = '+'
endif

if !exists('g:cmake_project_no_mappings')
  let g:cmake_project_no_mappings = 0
endif

if !exists('g:cmake_project_cmake_program')
  let g:cmake_project_cmake_program = 'cmake'
endif

" Interface
command! -nargs=* -complete=customlist,cmakeproject#complete
      \ CMakeGen call cmakeproject#gen(<f-args>)
command! -nargs=? -complete=customlist,cmakeproject#complete
      \ CMakeLoad call cmakeproject#load(<f-args>)
command! -nargs=0 -bar CMakeRefresh call cmakeproject#refresh()
command! -nargs=0 -bar CMakeBar call cmakeproject#sidebar#open()
command! -nargs=0 -bar CMakeBarClose call cmakeproject#sidebar#close()
command! -nargs=0 -bar CMakeBarToggle call cmakeproject#sidebar#toggle()
command! -nargs=0 -bar CMakeOutput call cmakeproject#output()

" The sidebar keys are buffer-local and live in ftplugin/cmakeproject.vim.
" These <Plug> maps are the supported way to reach the plugin from a global
" key of your own; nothing is bound by default.
nnoremap <silent> <Plug>(cmake-project-bar-toggle)
      \ :<C-u>call cmakeproject#sidebar#toggle()<CR>
nnoremap <silent> <Plug>(cmake-project-bar-open)
      \ :<C-u>call cmakeproject#sidebar#open()<CR>
nnoremap <silent> <Plug>(cmake-project-refresh)
      \ :<C-u>call cmakeproject#refresh()<CR>
nnoremap <silent> <Plug>(cmake-project-activate)
      \ :<C-u>call cmakeproject#sidebar#activate()<CR>

" 2.x called s:cmake_show_bar() straight from this file, which ran before the
" function was defined and fired whenever the variable merely existed -- so
" `let g:cmake_project_show_bar = 0` opened the bar anyway.
if g:cmake_project_show_bar
  augroup cmake_project_show_bar
    autocmd!
    autocmd VimEnter * call cmakeproject#sidebar#open()
  augroup END
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo
