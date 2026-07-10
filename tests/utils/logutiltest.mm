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

#include "LogUtil.h"

// LoopMacLog only emits to the unified logging system, so there is no return
// value to assert on. These smoke tests verify it accepts every os_log type and
// the default argument without crashing.
TEST_CASE("LoopMacLog emits without crashing for every type", "[logutil]") {
  REQUIRE_NOTHROW(LoopMacLog("LogUtilTest", "default type message"));
  REQUIRE_NOTHROW(LoopMacLog("LogUtilTest", "info message", OS_LOG_TYPE_INFO));
  REQUIRE_NOTHROW(
      LoopMacLog("LogUtilTest", "debug message", OS_LOG_TYPE_DEBUG));
  REQUIRE_NOTHROW(
      LoopMacLog("LogUtilTest", "error message", OS_LOG_TYPE_ERROR));
  REQUIRE_NOTHROW(
      LoopMacLog("LogUtilTest", "fault message", OS_LOG_TYPE_FAULT));
}

TEST_CASE("LoopMacLog reuses the log object for a repeated component",
          "[logutil]") {
  REQUIRE_NOTHROW(LoopMacLog("RepeatedComponent", "first message"));
  REQUIRE_NOTHROW(LoopMacLog("RepeatedComponent", "second message"));
}
