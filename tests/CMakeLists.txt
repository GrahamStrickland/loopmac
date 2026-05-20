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

# Catch2 tests
include(FetchContent)

FetchContent_Declare(
  Catch2
  GIT_REPOSITORY https://github.com/catchorg/Catch2.git
  GIT_TAG        6ee0826dcae55ed1e06b2c5701981221e979e1e6 # v3.15.0
  FIND_PACKAGE_ARGS
)

FetchContent_MakeAvailable(Catch2)
list(APPEND CMAKE_MODULE_PATH ${catch2_SOURCE_DIR}/extras)
include(Catch)

add_executable(audio_test audio/audiotest.cpp)
target_link_libraries(audio_test Catch2::Catch2WithMain audio)
catch_discover_tests(audio_test)

add_executable(capture_test capture/capturetest.cpp)
target_link_libraries(capture_test Catch2::Catch2WithMain capture)
catch_discover_tests(capture_test)

add_executable(playback_test playback/playbacktest.cpp)
target_link_libraries(playback_test Catch2::Catch2WithMain playback)
catch_discover_tests(playback_test)

# Qt tests
find_package(Qt6 6.11 REQUIRED COMPONENTS Test QuickTest)
qt_standard_project_setup(REQUIRES 6.11)

qt_add_executable(loopmactest 
    ${CMAKE_CURRENT_SOURCE_DIR}/app/tst_loopmac.cpp 
    ${CMAKE_CURRENT_SOURCE_DIR}/app/include/tst_loopmac.h
)
target_link_libraries(loopmactest PRIVATE Qt6::Test loopmac_lib)
add_test(NAME loopmactest COMMAND loopmactest)
target_include_directories(loopmactest PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/app/include)

qt_add_executable(loopmacqmltest app/ui/tst_qml.cpp)
target_link_libraries(loopmacqmltest PRIVATE Qt6::QuickTest)
add_test(NAME loopmacqmltest COMMAND loopmacqmltest -input ${CMAKE_CURRENT_SOURCE_DIR}/app/ui)
