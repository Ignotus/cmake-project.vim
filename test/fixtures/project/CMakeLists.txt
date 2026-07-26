cmake_minimum_required(VERSION 3.14)
project(cmake_project_fixture CXX)

add_subdirectory(src)

add_executable(app src/main.cpp)
target_link_libraries(app PRIVATE util)
