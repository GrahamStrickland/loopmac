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

add_library(utils STATIC ${CMAKE_CURRENT_SOURCE_DIR}/logutil.mm)

target_compile_features(utils PUBLIC cxx_std_23)

target_include_directories(utils PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

find_library(FOUNDATION_LIBRARY Foundation REQUIRED)
target_link_libraries(utils PUBLIC ${FOUNDATION_LIBRARY})

# os_log does not write to the terminal, so mirror log messages to stderr for
# local development. Enabled automatically for Debug builds, or explicitly via
# -DLOOPMAC_LOG_STDERR=ON.
option(LOOPMAC_LOG_STDERR "Mirror LoopMac log output to stderr" OFF)
target_compile_definitions(utils PRIVATE
  $<$<OR:$<BOOL:${LOOPMAC_LOG_STDERR}>,$<CONFIG:Debug>>:LOOPMAC_LOG_STDERR>)
