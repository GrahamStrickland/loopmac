// Copyright (C) 2026 Graham Strickland
//
// This file is part of LoopMac.
//
// LoopMac is free software: you can redistribute it and/or modify it under the
// terms of the GNU Lesser General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option) any
// later version.
//
// LoopMac is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
// details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with LoopMac. If not, see <https://www.gnu.org/licenses/>.

#ifndef TIME_FORMAT_H
#define TIME_FORMAT_H

#include <cstdio>
#include <string>

namespace loopmac {

/**
 * @brief Format a duration in milliseconds as "M:SS.mmm".
 *
 * The minutes component is unpadded while the seconds component is zero-padded 
 * to two integer digits with three decimal places (e.g. 65000 -> "1:05.000"). 
 * Negative inputs are clamped to zero.
 *
 * @param milliseconds Duration to format.
 * @return Formatted time string.
 */
inline std::string format_to_minutes(long long milliseconds) {
  if (milliseconds < 0) {
    milliseconds = 0;
  }

  const long long minutes = milliseconds / 60000;
  const double seconds = (milliseconds - minutes * 60000) / 1000.0;

  char buffer[32];
  std::snprintf(buffer, sizeof(buffer), "%lld:%06.3f", minutes, seconds);
  return std::string(buffer);
}

} // namespace loopmac

#endif // TIME_FORMAT_H
