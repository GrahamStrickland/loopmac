#include <catch2/catch_test_macros.hpp>

#include "playback.h"

TEST_CASE("Playback test", "[playback]") {
  playback::playback();

  REQUIRE(1 + 1 == 2);
};
