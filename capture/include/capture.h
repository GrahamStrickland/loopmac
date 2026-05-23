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

#ifndef CAPTURE_H
#define CAPTURE_H

#include <future>

/**
 * @file capture.h
 * @brief C++ interface for macOS audio capture permission management.
 */

namespace capture {

/**
 * @enum `permission_status`
 * @brief Permission states returned by the capture permission API.
 */
enum permission_status {
  PermissionStatusNotDetermined,
  PermissionStatusDenied,
  PermissionStatusAuthorized,
  PermissionStatusRestricted
};

/**
 * @class `audio_capture_manager`
 * @brief Thin C++ wrapper around platform-specific audio permission handling.
 *
 * This class exposes synchronous permission inspection and asynchronous
 * permission requests through a pure C++ API.
 */
class audio_capture_manager {
public:
  /**
   * @brief Construct a new `audio_capture_manager` instance.
   *
   * Initializes the underlying platform permission manager.
   */
  audio_capture_manager();

  /**
   * @brief Destroy the `audio_capture_manager` instance.
   */
  ~audio_capture_manager();

  /**
   * @brief Retrieve the current audio capture permission state.
   * @return Current `permission_status` value.
   */
  permission_status get_permission();

  /**
   * @brief Request audio capture permission asynchronously.
   * @return A `std::future` that resolves to the resulting `permission_status`.
   *
   * If permission is already determined by the system, the future may become
   * ready quickly. Otherwise, completion depends on user interaction with the
   * system permission prompt.
   */
  std::future<permission_status> request_permission();

private:
  struct impl;
  impl *pimpl;
};
} // end namespace capture

#endif // CAPTURE_H
