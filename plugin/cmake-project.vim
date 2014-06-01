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

class Prop:
    visible = True
    def __init__(self, visible):
        self.visible = visible

create_tree_node = lambda: ({}, Set(), Prop(True))

s_cmake_project_node_dict = {}
s_cmake_project_file_dict = {}
s_cmake_project_file_tree = create_tree_node()
EOF


" Interface
command -nargs=1 -complete=file CMakeGen call s:cmake_gen_project(<f-args>)
command -nargs=0 -bar CMakeBar call s:cmake_show_bar()
map <Space> :call g:cmake_on_space_clicked()<CR>

" Implementation
function! s:run_cmake(i_directory) abort
    exec 'cd' a:i_directory
    exec '!cmake' "-G\"CodeBlocks - Unix Makefiles\" " . s:cmake_project_directory
    exec 'cd' s:cmake_project_directory
endfunction


function! s:gen_file_tree(i_directory) abort
    exec 'cd' a:i_directory

python << EOF
import vim
import glob
import xml.etree.ElementTree as ET

current_dir = vim.eval('s:cmake_project_directory')
current_dir_len = len(current_dir) + 1

project_file = glob.glob('*.cbp')[0]
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
        directories, _, _ = current_tree_ref
        if not directories.has_key(path):
            directories[path] = create_tree_node()
        current_tree_ref = directories[path]

    _, files, _ = current_tree_ref
    files.add((file_name, file))

EOF

    exec 'cd' s:cmake_project_directory
endfunction


function! s:cmake_gen_project(i_directory) abort
    let s:cmake_project_directory = getcwd()
    call s:run_cmake(a:i_directory)
    call s:gen_file_tree(a:i_directory)
endfunction


function! s:cmake_print_file_tree() abort

python << EOF

folder_open_symbol = vim.eval('g:cmake_project_folder_open_symbol')
folder_close_symbol = vim.eval('g:cmake_project_folder_close_symbol')

def process_folder(i_directory, i_recursion_level):
    directories, files, _ = i_directory
    for (file_name, full_path) in sorted(files, key = lambda item: (int(item.partition(' ')[0])
                                                                    if item[0].isdigit() else float('inf'), item)):
        text = '   ' * i_recursion_level
        text += file_name
        s_cmake_project_file_dict[len(vim.current.buffer)] = full_path
        vim.current.buffer.append(text)
    

    for folder_name in directories.keys():
        text = '   ' * i_recursion_level
        folder_content = directories[folder_name]
        subdir, subfiles, prop = folder_content
        text += (folder_open_symbol if prop.visible == True else folder_close_symbol) + folder_name
        s_cmake_project_node_dict[len(vim.current.buffer)] = prop
        vim.current.buffer.append(text)
        if prop.visible == True:
            process_folder(folder_content, i_recursion_level + 1)
        
s_cmake_project_node_dict =  {}
process_folder(s_cmake_project_file_tree, 0)
EOF

    " Remove first line
    normal gg
    normal dd 
endfunction


function! s:cmake_show_bar() abort
    try
        bdelete @CMakeProject
    catch
    endtry

    topleft vsplit
    badd @CMakeProject
    buffer @CMakeProject
    setlocal buftype=nofile
    exec 'vertical' 'resize ' . g:cmake_project_bar_width
    setlocal modifiable

    let s:cmake_project_bufname = bufname('%')
    normal gg    
    normal dG

    call s:cmake_print_file_tree()
    setlocal nomodifiable
endfunction


function! g:cmake_on_space_clicked() abort
    if !exists('s:cmake_project_bufname') || bufname('%') != s:cmake_project_bufname
        return
    endif

    let current_line = line('.')
python << EOF
current_row, current_col = vim.current.window.cursor
current_line = vim.current.buffer[current_row - 1]
non_spaces = filter(lambda x: x != ' ', current_line)

def hide():
    if s_cmake_project_node_dict.has_key(current_row):
        s_cmake_project_node_dict[current_row].visible = False
        vim.command('hide')
        vim.command('call s:cmake_show_bar()')

def show():
    if s_cmake_project_node_dict.has_key(current_row):
        s_cmake_project_node_dict[current_row].visible = True
        vim.command('hide')
        vim.command('call s:cmake_show_bar()')

get_file_path = lambda: s_cmake_project_file_dict[current_row]

def open():
    vim.command('wincmd l')

    file_path = get_file_path()
    vim.command('badd ' + file_path) 
    vim.command('buffer ' + file_path)
    vim.command('setlocal switchbuf=useopen')
    vim.command('sbuffer @CMakeProject')


if non_spaces:
    if non_spaces[0] == folder_open_symbol:
        hide()
    elif non_spaces[0] == folder_close_symbol:
        show()
    else:
        open()
EOF
    exec l:current_line

endfunction
