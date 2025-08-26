cmake_minimum_required(VERSION 3.10.2)

project(llama_bindings LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Path to llama.cpp clone (relative to this file)
set(LLAMA_DIR "${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp")

if(NOT EXISTS "${LLAMA_DIR}")
    message(FATAL_ERROR "llama.cpp directory not found at ${LLAMA_DIR}. Please clone llama.cpp into android/app/src/main/cpp/llama.cpp")
endif()

# Include roots (add current dir so includes like "llama.cpp/llama.h" resolve)
set(LLAMA_INCLUDES
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${LLAMA_DIR}"
    "${LLAMA_DIR}/include"
    "${LLAMA_DIR}/src"
    "${LLAMA_DIR}/common"
    "${LLAMA_DIR}/ggml"
    "${LLAMA_DIR}/ggml/include"
    "${LLAMA_DIR}/ggml/src"
    "${LLAMA_DIR}/ggml/src/ggml-cpu"
    "${LLAMA_DIR}/vendor"
    "${LLAMA_DIR}/vendor/nlohmann"
)

message(STATUS "LLAMA_DIR: ${LLAMA_DIR}")
foreach(inc IN LISTS LLAMA_INCLUDES)
    if(EXISTS "${inc}")
        message(STATUS "LLAMA include (exists): ${inc}")
    else()
        message(STATUS "LLAMA include (missing): ${inc}")
    endif()
endforeach()

# Extended patterns to exclude from building on Android
set(EXCLUDE_PATTERNS
    "/ggml-opencl/"
    "/ggml-sycl/"
    "/dpct/"
    "/ggml-cann/"
    "/ggml-blas/"
    "/kleidiai/"
    "/kai_"                # KAI-related headers
    "/ggml-cuda/"
    "/ggml-vulkan/"        # Added Vulkan exclusion
    "/ggml-webgpu/"        # Added WebGPU exclusion
    "/ggml-zdnn/"          # Added ZDNN exclusion
    "/arch/wasm/"
    "/arch/loongarch/"
    "/arch/amx/"
    "/aclnn/"
    "/acl/"
    "/examples/"
    "/tests/"
    "/python/"
    "/tools/"              # Exclude tools directory which has server utils
    "/convert"             # Exclude convert scripts
    "/quantize"            # Exclude quantize tools
    "/llamafile/"          # Exclude llamafile SGEMM optimizations that cause FP16 issues
)

# Gather all C/C++ sources recursively but skip excluded patterns and headers
file(GLOB_RECURSE ALL_SOURCES CONFIGURE_DEPENDS
    "${LLAMA_DIR}/*.c" "${LLAMA_DIR}/*.cpp" "${LLAMA_DIR}/*.cc" "${LLAMA_DIR}/*.cxx"
)

set(LLAMA_SOURCES "")
foreach(f IN LISTS ALL_SOURCES)
    set(skip FALSE)
    
    # Check exclusion patterns
    foreach(pat IN LISTS EXCLUDE_PATTERNS)
        if(f MATCHES "${pat}")
            set(skip TRUE)
            break()
        endif()
    endforeach()
    
    # Skip git and other hidden directories
    if(f MATCHES "/\\.git/" OR f MATCHES "/\\.github/")
        set(skip TRUE)
    endif()
    
    # Skip specific problematic files
    get_filename_component(fname "${f}" NAME)
    if(fname MATCHES "ggml-vulkan\\." OR 
       fname MATCHES "ggml-webgpu\\." OR 
       fname MATCHES "ggml-zdnn\\." OR
       fname MATCHES "ggml-opencl\\." OR
       fname MATCHES "ggml-cuda\\." OR
       fname MATCHES "ggml-sycl\\.")
        set(skip TRUE)
    endif()
    
    if(NOT skip)
        list(APPEND LLAMA_SOURCES "${f}")
    else()
        message(STATUS "Skipping source (excluded): ${f}")
    endif()
endforeach()

# Remove duplicates
list(REMOVE_DUPLICATES LLAMA_SOURCES)
message(STATUS "LLAMA_SOURCES count: ${LLAMA_SOURCES}")

if(NOT LLAMA_SOURCES)
    message(FATAL_ERROR "No llama.cpp source files were found under ${LLAMA_DIR}.")
endif()

# Check for version header and create if missing
set(GGML_VERSION_H "${LLAMA_DIR}/ggml/include/ggml-version.h")
if(NOT EXISTS "${GGML_VERSION_H}")
    message(STATUS "Creating missing ggml-version.h")
    file(WRITE "${GGML_VERSION_H}" 
"#ifndef GGML_VERSION_H
#define GGML_VERSION_H

#define GGML_VERSION \"0.0.0\"
#define GGML_COMMIT \"unknown\"

#endif // GGML_VERSION_H
")
endif()

# Also create version header in src directory if needed
set(GGML_VERSION_H_SRC "${LLAMA_DIR}/ggml/src/ggml-version.h")
if(NOT EXISTS "${GGML_VERSION_H_SRC}")
    message(STATUS "Creating missing ggml-version.h in src directory")
    file(WRITE "${GGML_VERSION_H_SRC}" 
"#ifndef GGML_VERSION_H
#define GGML_VERSION_H

#define GGML_VERSION \"0.0.0\"
#define GGML_COMMIT \"unknown\"

#endif // GGML_VERSION_H
")
endif()

# Create static library from collected sources
add_library(llama STATIC ${LLAMA_SOURCES})

# Add include dirs
target_include_directories(llama PUBLIC ${LLAMA_INCLUDES})

# Compiler definitions
target_compile_definitions(llama PRIVATE
    GGML_USE_K_QUANTS
    NDEBUG
    GGML_USE_CPU
    GGML_VERSION="0.0.0"
    GGML_COMMIT="unknown"
    LLAMA_BUILD_NUMBER=1
    LLAMA_COMMIT="unknown"
    LLAMA_COMPILER="unknown"
    LLAMA_BUILD_TARGET="unknown"
)

# Compiler flags
target_compile_options(llama PRIVATE 
    -fPIC 
    -O3
    -fno-finite-math-only
    -Wall
    -Wextra
    -Wno-unused-parameter
    -Wno-unused-function
)

# Architecture-specific flags - FIXED: Removed -mfloat-abi=hard for Android compatibility
if(ANDROID_ABI STREQUAL "armeabi-v7a")
    target_compile_options(llama PRIVATE -mfpu=neon)
    target_compile_definitions(llama PRIVATE GGML_USE_ARM_NEON)
elseif(ANDROID_ABI STREQUAL "arm64-v8a")
    target_compile_definitions(llama PRIVATE GGML_USE_ARM_NEON)
    target_compile_options(llama PRIVATE -march=armv8-a+simd)
elseif(ANDROID_ABI STREQUAL "x86_64")
    target_compile_options(llama PRIVATE -mavx -mavx2 -mfma -mf16c -msse4.1)
    target_compile_definitions(llama PRIVATE GGML_USE_X86)
elseif(ANDROID_ABI STREQUAL "x86")
    target_compile_options(llama PRIVATE -msse4.1)
    target_compile_definitions(llama PRIVATE GGML_USE_X86)
endif()

# JNI/native bridge library
add_library(llama_bindings SHARED
    llama_bindings.cpp
)

# Fix include paths for llama_bindings - use direct paths instead of relative
target_include_directories(llama_bindings PRIVATE 
    ${LLAMA_INCLUDES} 
    ${CMAKE_CURRENT_SOURCE_DIR}
    "${LLAMA_DIR}/include"
    "${LLAMA_DIR}/src"
)

target_link_libraries(llama_bindings PRIVATE llama log android)
target_compile_options(llama_bindings PRIVATE -fPIC -O3)