#ifndef TIME_FORMAT_H
#define TIME_FORMAT_H

#include <cstdio>
#include <string>

namespace scribe {

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

} // namespace scribe

#endif // TIME_FORMAT_H
