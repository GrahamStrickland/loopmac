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

find_package(Qt6 6.11 REQUIRED COMPONENTS 
    Core 
    Quick 
    QuickControls2 
    Svg 
    Multimedia
)
qt_standard_project_setup(REQUIRES 6.11)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTORCC ON)

add_library(loopmac_lib STATIC 
    ${CMAKE_CURRENT_SOURCE_DIR}/loopmac.cpp 
    ${CMAKE_CURRENT_SOURCE_DIR}/include/loopmac.h
)
target_include_directories(loopmac_lib PUBLIC include)
target_link_libraries(loopmac_lib PRIVATE Qt6::Core)

qt_add_executable(LoopMac 
    ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp
)
set_target_properties(LoopMac PROPERTIES 
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in
)
qt_add_qml_module(loopmac_lib
    URI LoopMacUI
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/LoopMacUI
    QML_FILES
        Main.qml
        controls/PlaybackControl.qml
        controls/AudioControl.qml
        controls/PlaybackSeekControl.qml
    RESOURCES
        images/angle-double-small-left.svg
        images/angle-double-small-right.svg
        images/dot-circle.svg
        images/folder-open.svg
        images/pause-circle.svg
        images/play-circle.svg
        images/stop-circle.svg
        images/volume-slash.svg
        images/volume.svg
)
target_link_libraries(LoopMac PRIVATE
    loopmac_libplugin
    Qt6::Quick 
    Qt6::QuickControls2
    Qt6::Svg
    Qt6::Multimedia
)
target_compile_definitions(LoopMac PRIVATE 
    APP_VERSION="${PROJECT_VERSION}"
)

qt_generate_deploy_qml_app_script(
    TARGET LoopMac
    OUTPUT_SCRIPT deploy_script
    NO_UNSUPPORTED_PLATFORM_ERROR
    DEPLOY_USER_QML_MODULES_ON_UNSUPPORTED_PLATFORM
)
install(SCRIPT ${deploy_script})

install(TARGETS LoopMac
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
