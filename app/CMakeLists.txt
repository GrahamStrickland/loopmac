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

find_package(Qt6 6.11 REQUIRED COMPONENTS Core Quick QuickControls2 Svg Multimedia)
qt_standard_project_setup(REQUIRES 6.11)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTORCC ON)

add_library(loopmac_lib STATIC 
    ${CMAKE_CURRENT_SOURCE_DIR}/loopmac.cpp 
    ${CMAKE_CURRENT_SOURCE_DIR}/include/loopmac.h
)
target_include_directories(loopmac_lib PUBLIC include)
target_link_libraries(loopmac_lib PRIVATE Qt6::Core)

qt_add_executable(apploopmac 
    ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp
)
set_target_properties(apploopmac PROPERTIES MACOSX_BUNDLE TRUE)
qt_add_qml_module(apploopmac
    URI LoopMac
    QML_FILES
        qml/Main.qml
        qml/controls/PlaybackControl.qml
        qml/controls/AudioControl.qml
        qml/controls/PlaybackSeekControl.qml
)
target_link_libraries(apploopmac PRIVATE 
    loopmac_lib
    Qt6::Quick 
    Qt6::QuickControls2
    Qt6::Svg
    Qt6::Multimedia
)

qt_generate_deploy_qml_app_script(
    TARGET apploopmac
    OUTPUT_SCRIPT deploy_script
    MACOS_BUNDLE_POST_BUILD
    NO_UNSUPPORTED_PLATFORM_ERROR
    DEPLOY_USER_QML_MODULES_ON_UNSUPPORTED_PLATFORM
)
install(SCRIPT ${deploy_script})

install(TARGETS apploopmac
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
