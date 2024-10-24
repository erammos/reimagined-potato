include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(reimagined_potato_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(reimagined_potato_setup_options)
  option(reimagined_potato_ENABLE_HARDENING "Enable hardening" ON)
  option(reimagined_potato_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    reimagined_potato_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    reimagined_potato_ENABLE_HARDENING
    OFF)

  reimagined_potato_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR reimagined_potato_PACKAGING_MAINTAINER_MODE)
    option(reimagined_potato_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(reimagined_potato_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(reimagined_potato_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(reimagined_potato_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(reimagined_potato_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(reimagined_potato_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(reimagined_potato_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(reimagined_potato_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(reimagined_potato_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(reimagined_potato_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(reimagined_potato_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(reimagined_potato_ENABLE_PCH "Enable precompiled headers" OFF)
    option(reimagined_potato_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(reimagined_potato_ENABLE_IPO "Enable IPO/LTO" ON)
    option(reimagined_potato_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(reimagined_potato_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(reimagined_potato_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(reimagined_potato_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(reimagined_potato_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(reimagined_potato_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(reimagined_potato_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(reimagined_potato_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(reimagined_potato_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(reimagined_potato_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(reimagined_potato_ENABLE_PCH "Enable precompiled headers" OFF)
    option(reimagined_potato_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      reimagined_potato_ENABLE_IPO
      reimagined_potato_WARNINGS_AS_ERRORS
      reimagined_potato_ENABLE_USER_LINKER
      reimagined_potato_ENABLE_SANITIZER_ADDRESS
      reimagined_potato_ENABLE_SANITIZER_LEAK
      reimagined_potato_ENABLE_SANITIZER_UNDEFINED
      reimagined_potato_ENABLE_SANITIZER_THREAD
      reimagined_potato_ENABLE_SANITIZER_MEMORY
      reimagined_potato_ENABLE_UNITY_BUILD
      reimagined_potato_ENABLE_CLANG_TIDY
      reimagined_potato_ENABLE_CPPCHECK
      reimagined_potato_ENABLE_COVERAGE
      reimagined_potato_ENABLE_PCH
      reimagined_potato_ENABLE_CACHE)
  endif()

  reimagined_potato_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (reimagined_potato_ENABLE_SANITIZER_ADDRESS OR reimagined_potato_ENABLE_SANITIZER_THREAD OR reimagined_potato_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(reimagined_potato_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(reimagined_potato_global_options)
  if(reimagined_potato_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    reimagined_potato_enable_ipo()
  endif()

  reimagined_potato_supports_sanitizers()

  if(reimagined_potato_ENABLE_HARDENING AND reimagined_potato_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR reimagined_potato_ENABLE_SANITIZER_UNDEFINED
       OR reimagined_potato_ENABLE_SANITIZER_ADDRESS
       OR reimagined_potato_ENABLE_SANITIZER_THREAD
       OR reimagined_potato_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${reimagined_potato_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${reimagined_potato_ENABLE_SANITIZER_UNDEFINED}")
    reimagined_potato_enable_hardening(reimagined_potato_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(reimagined_potato_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(reimagined_potato_warnings INTERFACE)
  add_library(reimagined_potato_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  reimagined_potato_set_project_warnings(
    reimagined_potato_warnings
    ${reimagined_potato_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(reimagined_potato_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    reimagined_potato_configure_linker(reimagined_potato_options)
  endif()

  include(cmake/Sanitizers.cmake)
  reimagined_potato_enable_sanitizers(
    reimagined_potato_options
    ${reimagined_potato_ENABLE_SANITIZER_ADDRESS}
    ${reimagined_potato_ENABLE_SANITIZER_LEAK}
    ${reimagined_potato_ENABLE_SANITIZER_UNDEFINED}
    ${reimagined_potato_ENABLE_SANITIZER_THREAD}
    ${reimagined_potato_ENABLE_SANITIZER_MEMORY})

  set_target_properties(reimagined_potato_options PROPERTIES UNITY_BUILD ${reimagined_potato_ENABLE_UNITY_BUILD})

  if(reimagined_potato_ENABLE_PCH)
    target_precompile_headers(
      reimagined_potato_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(reimagined_potato_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    reimagined_potato_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(reimagined_potato_ENABLE_CLANG_TIDY)
    reimagined_potato_enable_clang_tidy(reimagined_potato_options ${reimagined_potato_WARNINGS_AS_ERRORS})
  endif()

  if(reimagined_potato_ENABLE_CPPCHECK)
    reimagined_potato_enable_cppcheck(${reimagined_potato_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(reimagined_potato_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    reimagined_potato_enable_coverage(reimagined_potato_options)
  endif()

  if(reimagined_potato_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(reimagined_potato_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(reimagined_potato_ENABLE_HARDENING AND NOT reimagined_potato_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR reimagined_potato_ENABLE_SANITIZER_UNDEFINED
       OR reimagined_potato_ENABLE_SANITIZER_ADDRESS
       OR reimagined_potato_ENABLE_SANITIZER_THREAD
       OR reimagined_potato_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    reimagined_potato_enable_hardening(reimagined_potato_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
