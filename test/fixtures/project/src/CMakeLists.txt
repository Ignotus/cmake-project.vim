# Headers are listed explicitly: the File API reports a target's declared
# sources, so headers that no target mentions are invisible to the plugin.
add_library(util
  util/util.cpp
  util/util.h
)
target_include_directories(util PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
