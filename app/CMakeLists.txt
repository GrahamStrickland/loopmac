include(GNUInstallDirs)

# UI-facing wrapper around the capture library. Built separately so the test
# suite can link it without the AppKit executable.
add_library(scribe_lib STATIC
    ${CMAKE_CURRENT_SOURCE_DIR}/audiomanager.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/playbackengine.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/include/audiomanager.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/playbackengine.h
)
target_include_directories(scribe_lib PUBLIC include)
target_link_libraries(scribe_lib PUBLIC capture utils "-framework AVFoundation")
target_compile_options(scribe_lib PRIVATE -fobjc-arc)

add_executable(Scribe MACOSX_BUNDLE
    ${CMAKE_CURRENT_SOURCE_DIR}/main.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/appdelegate.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/mainwindowcontroller.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/playbackcontrolview.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/include/appdelegate.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/mainwindowcontroller.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/playbackcontrolview.h
)
target_include_directories(Scribe PRIVATE include)
target_compile_options(Scribe PRIVATE -fobjc-arc)
target_compile_definitions(Scribe PRIVATE
    APP_VERSION="${PROJECT_VERSION}"
)
target_link_libraries(Scribe PRIVATE
    scribe_lib
    "-framework AppKit"
    "-framework AVFoundation"
    "-framework UniformTypeIdentifiers"
)

set_target_properties(Scribe PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in
    MACOSX_BUNDLE_BUNDLE_NAME "Scribe"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.grahamstrickland.scribe"
    MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
)

install(TARGETS Scribe
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
