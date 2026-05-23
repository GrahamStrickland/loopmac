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

add_library(capture STATIC 
    ${CMAKE_CURRENT_SOURCE_DIR}/capture.mm
    ${CMAKE_CURRENT_SOURCE_DIR}/AudioCaptureManager.mm
)

target_compile_features(capture PUBLIC cxx_std_23)

target_include_directories(capture PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

find_library(FOUNDATION_LIBRARY Foundation REQUIRED)
find_library(CORE_FOUNDATION_LIBRARY CoreFoundation REQUIRED)
target_link_libraries(capture PUBLIC ${FOUNDATION_LIBRARY} ${CORE_FOUNDATION_LIBRARY})
