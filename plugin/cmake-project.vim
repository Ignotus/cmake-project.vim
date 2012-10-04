if !has('perl')
  echo "Error: perl not found"
  finish
endif

let g:cmake_project_bufname = ''
let g:cmake_project_filename = ''

highlight CurrentGroup ctermbg=green guibg=green
autocmd CursorMoved * call s:cmake_project_cursor_moved() 
command -nargs=0 -bar CMakePro call s:cmake_project_window()

function! s:cmake_project_window()
  vnew
  badd 'CMakeProject'
  b 'CMakeProject'
  let g:cmake_project_bufname = bufname("%")
perl << EOF
  use lib './cmake-project';
  use cmakeproject;

  $curbuf->Append(0, cmakeproject::cmake_project_files('build'));
EOF

endfunction

function! s:cmake_project_cursor_moved()
   
  if bufname("%") == g:cmake_project_bufname
    let g:cmake_project_filename = getline('.')
    echo g:cmake_project_filename
    if filereadable(g:cmake_project_filename)
      exec "vnew" g:cmake_project_filename
    endif
  endif
endfunction


