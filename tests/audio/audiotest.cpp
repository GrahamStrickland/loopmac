#include <catch2/catch_test_macros.hpp>

#include "audio.h"

TEST_CASE("Audio test", "[audio]") {
  audio::audio();

  REQUIRE(1 + 1 == 2);
};
