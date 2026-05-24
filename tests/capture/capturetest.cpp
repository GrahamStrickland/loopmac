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

#include <catch2/catch_test_macros.hpp>

#include <chrono>

#include "capture.h"

namespace {
bool is_valid_permission_status(capture::permission_status status) {
  switch (status) {
  case capture::permission_status::PermissionStatusNotDetermined:
  case capture::permission_status::PermissionStatusDenied:
  case capture::permission_status::PermissionStatusAuthorized:
  case capture::permission_status::PermissionStatusRestricted:
    return true;
  default:
    return false;
  }
}

bool is_request_result_status(capture::permission_status status) {
  return status == capture::permission_status::PermissionStatusDenied ||
         status == capture::permission_status::PermissionStatusAuthorized;
}
} // namespace

TEST_CASE("Audio capture manager constructor", "[audio_capture_manager]") {
  auto capture_manager = capture::audio_capture_manager{};
  SUCCEED();
}

TEST_CASE("Audio capture manager get permission returns enum value",
          "[get_permission]") {
  auto capture_manager = capture::audio_capture_manager{};

  auto result = capture_manager.get_permission();

  REQUIRE(is_valid_permission_status(result));
}

TEST_CASE("Audio capture manager request permission resolves future",
          "[request_permission]") {
  auto capture_manager = capture::audio_capture_manager{};

  if (capture_manager.get_permission() ==
      capture::permission_status::PermissionStatusNotDetermined) {
    SKIP("Audio capture permission is undetermined; resolving it requires an "
         "interactive system prompt that cannot be answered in a "
         "non-interactive environment such as CI.");
  }

  auto result_future = capture_manager.request_permission();

  REQUIRE(result_future.valid());
  REQUIRE(result_future.wait_for(std::chrono::seconds(5)) ==
          std::future_status::ready);

  auto result = result_future.get();
  REQUIRE(is_request_result_status(result));
}