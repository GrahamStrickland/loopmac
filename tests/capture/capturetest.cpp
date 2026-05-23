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

#include "capture.h"

TEST_CASE("Audio capture manager constructor", "[audio_capture_manager]") {
  auto capture_manager = capture::audio_capture_manager{};
};

TEST_CASE("Audio capture manager get permission", "[get_permission]") {
  GIVEN("Audio capture manager") {
    auto capture_manager = capture::audio_capture_manager{};

    THEN("Permission status denied") {
      capture::permission_status result = capture_manager.get_permission();

      REQUIRE(result == capture::permission_status::PermissionStatusAuthorized);
    }
  }
};
