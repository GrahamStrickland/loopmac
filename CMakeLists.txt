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

cmake_minimum_required(VERSION 3.24)
project(LoopMac 
    VERSION 0.0.5 
    SPDX_LICENSE "LGPL-3.0-or-later"
    DESCRIPTION "Audio loopback and replay application for macOS"
    HOMEPAGE_URL "https://github.com/GrahamStrickland/loopmac"
    LANGUAGES CXX OBJCXX
)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(CTest)

# Libraries
add_subdirectory(audio)
add_subdirectory(capture)
add_subdirectory(playback)

# Executable
add_subdirectory(app)

# Tests
if(BUILD_TESTING)
    add_subdirectory(tests)
endif()
