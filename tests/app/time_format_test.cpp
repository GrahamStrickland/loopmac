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
