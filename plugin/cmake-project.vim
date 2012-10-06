if !has('perl')
  echo "Error: perl not found"
  finish
endif

if !exists('g:cmake_project_build_dir')
  let g:cmake_project_build_dir = "build"
endif

autocmd CursorMoved * call s:cmake_project_cursor_moved() 
command -nargs=0 -bar CMakePro call s:cmake_project_window()
"command -nargs=+ -bar CMake call s:cmake_project_cmake(srcdir, arg)
command -nargs=1 -bar CMake call s:cmake_project_cmake(<f-args>)

function! s:cmake_project_cmake(srcdir)
  if !isdirectory(a:srcdir)
    echo "This directory not exists!" . a:srcdir
    return
  endif
  
  let s:cmake_project_dir = a:srcdir

  exec "cd" a:srcdir
  if !isdirectory(g:cmake_project_build_dir)
    call mkdir(g:cmake_project_build_dir)
  endif
  
  cd build

  exec "!cmake" "../"
  cd ..
  call s:cmake_project_window()
endfunction

function! s:cmake_project_window()
  vnew
  badd CMakeProject
  buffer CMakeProject
  setlocal buftype=nofile
  let s:cmake_project_bufname = bufname("%")
  let g:filedict = {}
perl << EOF
  use lib "$ENV{'HOME'}/.vim/plugin/cmake-project";
  use cmakeproject;

  my $dir = VIM::Eval('g:cmake_project_build_dir');
  my @result = cmakeproject::cmake_project_files($dir);

  foreach $line(@result) {
    $filename = $line->{'file'}; 
    $curbuf->Append(0, $filename);
    VIM::DoCommand("let g:filedict[\"$filename\"] = \"$line->{'dir'}\"");
  }
EOF
endfunction

function! s:cmake_project_cursor_moved()
  if exists('s:cmake_project_bufname') && bufname("%") == s:cmake_project_bufname
    let cmake_project_filename = getline('.')
    let cmake_project_full_file_name = g:filedict[cmake_project_filename] . "/" . cmake_project_filename
 
    if filereadable(cmake_project_full_file_name)
      wincmd l
      exec "e" cmake_project_full_file_name 
      wincmd h
    else
      echo "Cannot read: " cmake_project_full_file_name
    endif
  endif
endfunction

