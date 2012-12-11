" vim-cmake-project
" Copyright (C) 2012 Minh Ngo <nlminhtl@gmail.com>
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
"
"
" 05.12.12 remove external (perl or python) dependencies
" g:cmake_project_use_viml=1 for function s:cmake_project_find_file calling
" let g:cmake_project_use_viml=1
" TODO: Change [►▼] to global variable like in TagBar plugin
" TODO: Add syntax coloring?

function s:cmake_project_find_files()
    let currentdir = getcwd() . '/' . g:cmake_project_build_dir
    let dependencies = globpath(currentdir, "**/DependInfo.cmake")
    let internals = globpath(currentdir, "**/depend.internal")
    let result = []
    for depend in split(dependencies)
        if filereadable(depend)
            for line in readfile(depend)
               let filename = matchlist(line, '\(^\s\+"\)\([[:graph:]]\+[.c|.cpp|.cc]\)"')
                if len(filename) > 1 && strlen(filename[2])
                   call add(result, filename[2])
                endif
            endfor
        endif
    endfor

    for internal in split(internals)
        if filereadable(internal)
            for line in readfile(internal)
                let filename = matchlist(line, '\(^\s\+\)\([[:graph:]]\+[.h|.hh|.hpp]\)')
                if len(filename) >1 && strlen(filename[2]) && match(getcwd(), filename[2]) != -1
                    call add(result, filename[2])
                endif
            endfor
        endif
    endfor
    return sort(result)
endfunction


if exists('b:loaded_winmanager') || &cp
" Already loaded by winmanager
    finish
endif


" Register in winmanager
let g:CMakeProject_title = "[Cmake Explorer]"

function! CMakeProject_Start()
    " Entry point winamager plugin
    let b:loaded_winmanager=1

    call s:cmake_project_cmake(getcwd())
endfunction

function! CMakeProject_IsValid()
    return 1
endfu



if !exists('g:cmake_project_build_dir')
  let g:cmake_project_build_dir = "build"
endif

if !exists('g:cmake_project_window_width')
  let g:cmake_project_window_width = 40
endif

let s:cmake_project_current_line = {}

autocmd BufWinLeave * call s:cmake_project_on_hidden()
command -nargs=0 -bar CMakePro call s:cmake_project_window()
command -nargs=* -complete=file CMake call s:cmake_project_cmake(<f-args>)
map <Space> :call g:cmake_project_hide_tree()<CR>
"autocmd CursorMoved * call s:cmake_project_cursor_moved() 
map <silent><Return> :call <SID>cmake_project_cursor_moved(0)<cr> 

function! g:cmake_project_hide_tree()
  if exists('b:loaded_winmanager')
"      return
  endif
  if exists('s:cmake_project_bufname') && bufname('%') == s:cmake_project_bufname
    let current_line = getline('.')
    let stat = s:cmake_project_hiding_status(current_line)
    if stat == '▼'   
      s/▼/►/ 
      let level = s:cmake_project_level(current_line)
      let current_index = line('.') + 1
      while s:cmake_project_level(getline(current_index)) > level 
        exec current_index 'delete'
      endwhile
    elseif stat == '►'
      s/►/▼/
      let current_line_level = s:cmake_project_level(current_line)
      let level = current_line_level
      let current_line_index = line('.')
      let current_index = current_line_index
      let path = [s:cmake_project_var(getline('.'))]
      
      while current_index > 1
        let current_index -= 1
        let current = getline(current_index)
        let current_level = s:cmake_project_level(current)
        if current_level < level
          let level = current_level
          call insert(path,s:cmake_project_var(current)) 
          if current_level == 0
            break
          endif
        endif
      endwhile
      
      let tree = s:cmake_project_file_tree
      
      let key = path[0]
      while !has_key(tree, key)
        let tree = tree[keys(tree)[0]]
      endwhile

      for val in path
        let tree = tree[val]
      endfor
      
      call s:cmake_project_print_bar(tree, current_line_level + 1)
      exec current_line_index 
    else
      call s:cmake_project_cursor_moved(0) 
    endif
  endif
endfunction

function! s:cmake_project_on_hidden()
  if exists('s:cmake_project_bufname') && bufname('%') == s:cmake_project_bufname
    unlet s:cmake_project_bufname
  endif
endfunction

function! s:cmake_project_check_dir(srcdir)
  if !isdirectory(a:srcdir)
    echo "This directory not exists!" . a:srcdir
    return
  endif
  
  let s:cmake_project_dir = a:srcdir

  exec 'cd' fnameescape(a:srcdir)
  if !isdirectory(g:cmake_project_build_dir)
    call mkdir(g:cmake_project_build_dir)
  endif
endfunction

function! s:cmake_project_cmake(srcdir)
  call s:cmake_project_check_dir(a:srcdir)  

  cd build
  if exists('g:cmake_project_keys')
    exec '!cmake' g:cmake_project_keys . ' ../'
  else
    exec '!cmake' '../'
  endif
  cd ..
  call s:cmake_project_window()
endfunction

function! s:cmake_project_window()
  if exists('s:cmake_project_bufname')
    return
  endif
  if exists('b:loaded_winmanager')
   " Winmanager has already created buffer for us
  else
      vnew
      badd CMakeProject
      buffer CMakeProject
      setlocal buftype=nofile
      exec 'vertical' 'resize ' . g:cmake_project_window_width
  endif

  let s:cmake_project_bufname = bufname('%')
  let s:cmake_project_files = s:cmake_project_find_files()
 
  let s:cmake_project_file_tree = {}
  
  for fullpath in s:cmake_project_files
    let current_tree = s:cmake_project_file_tree
    let cmake_project_args = split(fullpath, '\/')

    let filename = remove(cmake_project_args, -1)
    for path in cmake_project_args
      if !has_key(current_tree, path)
        let current_tree[path] = {}
      endif

      let current_tree = current_tree[path]
    endfor

    let current_tree[filename] = 1
  endfor
"  call s:cmake_project_print_bar(s:cmake_project_find_tree(s:cmake_project_file_tree), 0)
  call s:cmake_project_print_bar(s:cmake_project_file_tree,0)
  normal gg 
  normal dd
endfunction

function! s:cmake_project_find_tree(tree)
  if len(a:tree) == 1
    let subtree = a:tree[keys(a:tree)[0]]
    if len(subtree) == 1
      return s:cmake_project_find_tree(subtree)
    endif
  endif

  return a:tree
endfunction

function! s:cmake_project_indent(level)
  let result = ''
  for i in range(1, a:level)
    let result .= '  '
  endfor

  return result
endfunction

function! s:cmake_project_print_bar(tree, level)
  for pair in items(a:tree)
    if type(pair[1]) == type({})
      let name = s:cmake_project_indent(a:level) . '▼' . pair[0] . '/'
      call append('.', name) 
      normal j
      let newlevel = a:level + 1
      call s:cmake_project_print_bar(pair[1], newlevel)
    else
      let name = s:cmake_project_indent(a:level) . pair[0]
      call append('.', name) 
      normal j
    endif
  endfor
endfunction

function! s:cmake_project_level(str)
  return match(a:str, '[▼►_a-zA-Z]') / 2
endfunction
      
function! s:cmake_project_hiding_status(str)
 return matchstr(a:str, '[►▼]')
endfunction

function! s:cmake_project_var(str)
  return matchstr(a:str, '[^ ►▼/]\+')
endfunction

function! s:cmake_project_find_parent(ident_level, finding_line)
  if a:finding_line == 1
    return -1
  endif

  let fline = a:finding_line - 1
  while fline > 0
    let l = getline(fline)
    let level = s:cmake_project_level(l)
    if level == a:ident_level
      return fline
    endif
    let fline -= 1
  endwhile
  return -1
endfunction

function! s:cmake_project_highlight_pattern(path)
  let highlight_pattern = substitute(a:path, '[.]', '\\.', '')
  let highlight_pattern = substitute(highlight_pattern, '[/]', '\\/', '')
  exec "match" "ErrorMsg /" . highlight_pattern . "/"
endfunction

function! s:cmake_project_cursor_moved(split)
  if exists('s:cmake_project_bufname') && bufname('%') == s:cmake_project_bufname
    let cmake_project_filename = getline('.')
    let fullpath = s:cmake_project_var(cmake_project_filename)
    call s:cmake_project_highlight_pattern(fullpath)

    let level = s:cmake_project_level(cmake_project_filename)
    
    let level -= 1
    let finding_line = s:cmake_project_find_parent(level, line('.'))
    let l:path = ''
    while level > -1
      let l:path = s:cmake_project_var(getline(finding_line))
      let fullpath = l:path . '/' . fullpath
      let level -= 1
      let finding_line = s:cmake_project_find_parent(level, finding_line)
    endwhile
    
    let current_tree = s:cmake_project_file_tree
    let l:begin_path = []

    while !has_key(current_tree, l:path) 
      let key = keys(current_tree)[0]
      call insert(l:begin_path, key)
      if type(current_tree[key]) != type({})
        break
      endif

      let current_tree = current_tree[key]
    endwhile

    if has('win32')
        let result_path = ''
    else
        let result_path  = '/'
    endif

    for val in begin_path
      let result_path =  '/' . val . result_path
    endfor

    let result_path .= fullpath
    echo result_path
    if filereadable(result_path)
        if !exists('b:loaded_winmanager')
      wincmd l
      if exists('s:cmake_project_current_open_file')
        let s:cmake_project_current_line[s:cmake_project_current_open_file] = line('.')
      endif
      exec 'e' result_path 
      setf cpp
    else
        " Winmanger knows how and where open file
        call WinManagerFileEdit(result_path, a:split)
    endif

      let s:cmake_project_current_open_file = result_path
      if has_key(s:cmake_project_current_line, result_path)
        exec s:cmake_project_current_line[result_path] 
      else
        let s:cmake_project_current_line[result_path] = 1
      endif
    endif
  endif
endfunction

