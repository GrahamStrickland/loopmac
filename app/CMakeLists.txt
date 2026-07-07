# Copyright (C) 2026 Graham Strickland
#
# This file is part of LoopMac.
#
# LoopMac is free software: you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# LoopMac is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with LoopMac. If not, see <https://www.gnu.org/licenses/>.

include(GNUInstallDirs)

# UI-facing wrapper around the capture library. Built separately so the test
# suite can link it without the AppKit executable.
add_library(loopmac_lib STATIC
    ${CMAKE_CURRENT_SOURCE_DIR}/audio_manager.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/PlaybackEngine.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/include/audio_manager.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/time_format.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/PlaybackEngine.h
)
target_include_directories(loopmac_lib PUBLIC include)
target_link_libraries(loopmac_lib PUBLIC capture "-framework AVFoundation")
target_compile_options(loopmac_lib PRIVATE -fobjc-arc)

add_executable(LoopMac MACOSX_BUNDLE
    ${CMAKE_CURRENT_SOURCE_DIR}/main.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/AppDelegate.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/MainWindowController.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/PlaybackControlView.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/include/AppDelegate.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/MainWindowController.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/PlaybackControlView.h
)
target_include_directories(LoopMac PRIVATE include)
target_compile_options(LoopMac PRIVATE -fobjc-arc)
target_compile_definitions(LoopMac PRIVATE
    APP_VERSION="${PROJECT_VERSION}"
)
target_link_libraries(LoopMac PRIVATE
    loopmac_lib
    "-framework AppKit"
    "-framework AVFoundation"
    "-framework UniformTypeIdentifiers"
)

set_target_properties(LoopMac PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in
    MACOSX_BUNDLE_BUNDLE_NAME "LoopMac"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.grahamstrickland.loopmac"
    MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
)

install(TARGETS LoopMac
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
