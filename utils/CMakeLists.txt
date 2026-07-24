add_library(utils STATIC ${CMAKE_CURRENT_SOURCE_DIR}/logutil.mm)

target_compile_features(utils PUBLIC cxx_std_23)

target_include_directories(utils PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

find_library(FOUNDATION_LIBRARY Foundation REQUIRED)
target_link_libraries(utils PUBLIC ${FOUNDATION_LIBRARY})

# os_log does not write to the terminal, so mirror log messages to stderr for
# local development. Enabled automatically for Debug builds, or explicitly via
# -Dscribe_LOG_STDERR=ON.
option(scribe_LOG_STDERR "Mirror Scribe log output to stderr" OFF)
target_compile_definitions(utils PRIVATE
  $<$<OR:$<BOOL:${scribe_LOG_STDERR}>,$<CONFIG:Debug>>:scribe_LOG_STDERR>)
