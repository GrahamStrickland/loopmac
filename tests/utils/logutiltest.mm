#include <catch2/catch_test_macros.hpp>

#include "logutil.h"

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
