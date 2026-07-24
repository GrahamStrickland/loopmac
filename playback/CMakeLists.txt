add_library(playback STATIC ${CMAKE_CURRENT_SOURCE_DIR}/playback.cpp)

target_compile_features(playback PUBLIC cxx_std_23)

target_include_directories(playback PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
