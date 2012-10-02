if !has('perl')
  echo "Error: perl not found"
  finish
endif

function! s:cmake_project_window()
  vnew

perl << EOF
  use lib 'cmake-project';
  use cmakeproject;

  $curbuf->Append(0, cmakeproject::cmake_project_files('build'));
EOF

endfunction

command -nargs=0 CMakePro call s:cmake_project_window()
