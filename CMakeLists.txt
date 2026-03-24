add_compile_options("/utf-8")
cmake_minimum_required(VERSION 3.15)
project(Noah_ASI VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)
link_directories(${CMAKE_CURRENT_SOURCE_DIR}/lib)

# 외부 라이브러리 (vcpkg로 설치 필요)
find_package(CURL REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

add_executable(Noah_ASI src/main.cpp src/gemini_client.cpp)

target_link_libraries(Noah_ASI PRIVATE llama ggml ggml-base ggml-cuda CURL::libcurl nlohmann_json::nlohmann_json)

add_custom_command(TARGET Noah_ASI POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CMAKE_CURRENT_SOURCE_DIR}/bin/llama.dll"
    $<TARGET_FILE_DIR:Noah_ASI>
)
add_compile_options("$<$<CXX_COMPILER_ID:MSVC>:/utf-8>")
