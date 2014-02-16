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

if !has('python')
    echo 'Error: Required vim compiled with +python'
    finish
endif

if !exists('g:cmake_project_show_bar')
    let g:cmake_project_show_bar = 0 
else
    call s:cmake_show_bar()
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


python << EOF
import vim
from sets import Set

s_cmake_project_show_bar = vim.eval('g:cmake_project_show_bar')
s_cmake_project_bar_width = vim.eval('g:cmake_project_bar_width')


create_tree_node = lambda: ({}, Set(), True)

s_cmake_project_file_tree = create_tree_node(0)
EOF


" Interface
command -nargs=1 -complete=file CMakeGen call s:cmake_gen_project(<f-args>)
command -nargs=0 -bar CMakeBar call s:cmake_show_bar()
map <Space> :call g:cmake_on_space_clicked()<CR>

" Implementation
function! s:run_cmake(i_directory)
    exec 'cd' a:i_directory
    exec '!cmake' "-G\"CodeBlocks - Unix Makefiles\" " . s:cmake_project_directory
    exec 'cd' s:cmake_project_directory
endfunction


function! s:gen_file_tree(i_directory)
    exec 'cd' a:i_directory

python << EOF
import vim
import glob
import xml.etree.ElementTree as ET

cm_files_rel_dir = vim.eval('a:i_directory')
current_dir = vim.eval('s:cmake_project_directory')
current_dir_len = len(current_dir) + 1

cmake_files_folder = current_dir + '/' + cm_files_rel_dir + '/'

project_file = glob.glob(cmake_files_folder + '*.cbp')[0]
tree = ET.parse(project_file)
root = tree.getroot()

files = [file_name.get('filename') for file_name in root.findall("./Project/Unit")]

s_cmake_project_file_tree = create_tree_node()

for file in files:
    paths = file[current_dir_len:].split('/')
    file_name = paths[-1]
    paths.pop()

    current_tree_ref = s_cmake_project_file_tree 
    for path in paths:
        if not current_tree_ref[0].has_key(path):
            current_tree_ref[0][path] = create_tree_node()
        current_tree_ref = current_tree_ref[0][path]

    current_tree_ref[1].add(file_name)

EOF

    exec 'cd' s:cmake_project_directory
endfunction


function! s:cmake_gen_project(i_directory)
    let s:cmake_project_directory = getcwd()
    call s:run_cmake(a:i_directory)
    call s:gen_file_tree(a:i_directory)
endfunction


function! s:cmake_print_file_tree()

python << EOF

folder_open_symbol = vim.eval('g:cmake_project_folder_open_symbol')
folder_close_symbol = vim.eval('g:cmake_project_folder_close_symbol')

def process_folder(i_directory, i_recursion_level):
    for file_name in sorted(i_directory[1], key = lambda item: (int(item.partition(' ')[0])
                                                                if item[0].isdigit() else float('inf'), item)):
        text = '   ' * i_recursion_level
        text += file_name
        vim.current.buffer.append(text)
    

    for folder_name, folder_content  in i_directory[0].items():
        text = '   ' * i_recursion_level
        text += (folder_open_symbol if folder_content[2] == True else folder_close_symbol) + folder_name
        vim.current.buffer.append(text)
        if folder_content[2] == True:
            process_folder(folder_content, i_recursion_level + 1)
        
process_folder(s_cmake_project_file_tree, 0)
EOF

    " Remove first line
    normal gg
    normal dd 
endfunction


function! s:cmake_show_bar()
    vnew
    badd CMakeProject
    buffer CMakeProject
    setlocal buftype=nofile
    exec 'vertical' 'resize ' . g:cmake_project_bar_width

    let s:cmake_project_bufname = bufname('%')
    normal gg    
    normal dG

    call s:cmake_print_file_tree()
    setlocal nomodifiable
endfunction


function! g:cmake_on_space_clicked()
    if !exists('s:cmake_project_bufname') || bufname('%') != s:cmake_project_bufname
        return
    endif

python << EOF
current_line_id = vim.current.window.cursor[0]
current_line = vim.current.buffer[current_line_id]
non_spaces = filter(lambda x: x != ' ', current_line)
if not non_spaces:
    return

folder_open_symbol = vim.eval('g:cmake_project_folder_open_symbol')

def spaces_count(line):
    spaces = 0
    for i in range(len(line)):
        if line[i] != ' ':
            break
        spaces += 1
    spaces


def find_first_symbol_and_replace(line, symbol, replaced_symbol)
    for i in range(len(line)):
        if line[i] == symbol:
            line[i] = replaced_symbol 
            break


def hide():
    find_first_symbol_and_replace(current_line, non_spaces, folder_close_symbol)
    
    spaces = spaces_count(current_line)
    vim.current.buffer[current_line_id] = current_line
    
    current_line_id += 1
    while current_line_id < len(vim.current.buffer):
        if spaces_count(vim.current.buffer[current_line_id]) < spaces:
            del vim.current.buffer[current_line_id]
        else
            break


def show():
    find_first_symbol_and_replace(current_line, non_spaces, folder_open_symbol)
    spaces = spaces_count(current_line)
    pass


def open()
    pass


if non_spaces[0] == folder_open_symbol:
    hide()
elif non_spaces[0] == folder_close_symbol:
    show()
else:
    open()

EOF
endfunction
