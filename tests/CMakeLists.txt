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

add_library(utils STATIC 
    ${CMAKE_CURRENT_SOURCE_DIR}/utils/utils.cpp
)
target_compile_features(utils PUBLIC cxx_std_23)
target_include_directories(utils PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/utils/include)
target_link_libraries(utils PUBLIC capture)

add_executable(audio_test audio/audiotest.cpp)
target_link_libraries(audio_test Catch2::Catch2WithMain audio)
catch_discover_tests(audio_test)

add_executable(capture_test capture/capturetest.cpp)
target_link_libraries(capture_test Catch2::Catch2WithMain utils)
catch_discover_tests(capture_test)

add_executable(audio_capture_manager_test capture/audiocapturemanagertest.mm)
target_link_libraries(audio_capture_manager_test Catch2::Catch2WithMain capture)
catch_discover_tests(audio_capture_manager_test)

add_executable(playback_test playback/playbacktest.cpp)
target_link_libraries(playback_test Catch2::Catch2WithMain playback)
catch_discover_tests(playback_test)

add_executable(playback_engine_test playback/playbackenginetest.mm)
target_link_libraries(playback_engine_test Catch2::Catch2WithMain loopmac_lib)
target_compile_options(playback_engine_test PRIVATE -fobjc-arc)
catch_discover_tests(playback_engine_test)

# App (native UI) tests
add_executable(time_format_test app/time_format_test.cpp)
target_link_libraries(time_format_test Catch2::Catch2WithMain loopmac_lib)
catch_discover_tests(time_format_test)

add_executable(audio_manager_test app/audio_manager_test.cpp)
target_link_libraries(audio_manager_test Catch2::Catch2WithMain loopmac_lib utils)
catch_discover_tests(audio_manager_test)
