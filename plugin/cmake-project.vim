if !has('perl')
  echo "Error: perl not found"
  finish
endif

if !exists('g:cmake_project_temp_dir')
  let g:cmake_project_temp_dir = "/tmp"
endif

let s:cmake_project_dir = g:cmake_project_temp_dir . "/vim_cmake_project_" . getpid()

call mkdir(s:cmake_project_dir)

autocmd CursorMoved * call s:cmake_project_cursor_moved() 
autocmd VimLeave * call s:cmake_project_destruct()
command -nargs=0 -bar CMakePro call s:cmake_project_window()

function! s:cmake_project_destruct()
perl << EOF
  use File::Path qw(remove_tree);
  my $dir = VIM::Eval("s:cmake_project_dir");
  remove_tree($dir);
EOF
endfunction

function! s:cmake_project_window()
  vnew
  exec "file" s:cmake_project_dir . "CMakeProject"
  let s:cmake_project_bufname = bufname("%")
perl << EOF
  use lib './cmake-project';
  use cmakeproject;

  $curbuf->Append(0, cmakeproject::cmake_project_files('build'));
EOF
  w
endfunction

function! s:cmake_project_cursor_moved()
  if exists('s:cmake_project_bufname') && bufname("%") == s:cmake_project_bufname
    let s:cmake_project_filename = getline('.')
    if filereadable(s:cmake_project_filename)
      wincmd l
      exec "e" s:cmake_project_filename
    endif
  endif
endfunction


