add_library(capture STATIC ${CMAKE_CURRENT_SOURCE_DIR}/audiocapturemanager.mm)

target_compile_features(capture PUBLIC cxx_std_23)

target_include_directories(capture PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

find_library(CORE_AUDIO_LIBRARY CoreAudio REQUIRED)
find_library(FOUNDATION_LIBRARY Foundation REQUIRED)
find_library(CORE_FOUNDATION_LIBRARY CoreFoundation REQUIRED)
target_link_libraries(capture PUBLIC
    ${CORE_AUDIO_LIBRARY}
    ${FOUNDATION_LIBRARY}
    ${CORE_FOUNDATION_LIBRARY}
    utils
)
