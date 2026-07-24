add_library(audio STATIC ${CMAKE_CURRENT_SOURCE_DIR}/audio.cpp)

target_compile_features(audio PUBLIC cxx_std_23)

target_include_directories(audio PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
