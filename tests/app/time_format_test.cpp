#include <catch2/catch_test_macros.hpp>

#include "time_format.h"

TEST_CASE("format_to_minutes formats zero", "[time_format]") {
  REQUIRE(loopmac::format_to_minutes(0) == "0:00.000");
}

TEST_CASE("format_to_minutes pads the seconds component", "[time_format]") {
  REQUIRE(loopmac::format_to_minutes(5000) == "0:05.000");
  REQUIRE(loopmac::format_to_minutes(65000) == "1:05.000");
}

TEST_CASE("format_to_minutes preserves milliseconds", "[time_format]") {
  REQUIRE(loopmac::format_to_minutes(5500) == "0:05.500");
  REQUIRE(loopmac::format_to_minutes(59999) == "0:59.999");
}

TEST_CASE("format_to_minutes handles multiple minutes", "[time_format]") {
  REQUIRE(loopmac::format_to_minutes(600000) == "10:00.000");
}

TEST_CASE("format_to_minutes clamps negatives to zero", "[time_format]") {
  REQUIRE(loopmac::format_to_minutes(-1) == "0:00.000");
}
