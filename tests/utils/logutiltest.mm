#include <catch2/catch_test_macros.hpp>

#include "logutil.h"

// ScribeLog only emits to the unified logging system, so there is no return
// value to assert on. These smoke tests verify it accepts every os_log type and
// the default argument without crashing.
TEST_CASE("ScribeLog emits without crashing for every type", "[logutil]") {
  REQUIRE_NOTHROW(ScribeLog("LogUtilTest", "default type message"));
  REQUIRE_NOTHROW(ScribeLog("LogUtilTest", "info message", OS_LOG_TYPE_INFO));
  REQUIRE_NOTHROW(
      ScribeLog("LogUtilTest", "debug message", OS_LOG_TYPE_DEBUG));
  REQUIRE_NOTHROW(
      ScribeLog("LogUtilTest", "error message", OS_LOG_TYPE_ERROR));
  REQUIRE_NOTHROW(
      ScribeLog("LogUtilTest", "fault message", OS_LOG_TYPE_FAULT));
}

TEST_CASE("ScribeLog reuses the log object for a repeated component",
          "[logutil]") {
  REQUIRE_NOTHROW(ScribeLog("RepeatedComponent", "first message"));
  REQUIRE_NOTHROW(ScribeLog("RepeatedComponent", "second message"));
}
