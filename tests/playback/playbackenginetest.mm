#import "playbackengine.h"
#import <Foundation/Foundation.h>

#include <catch2/catch_test_macros.hpp>

#include <cstdint>

namespace {

// Builds a minimal 16-bit PCM mono WAV of `seconds` of silence and writes it to
// a temp file, returning its URL. Generating the clip at runtime keeps the test
// hermetic — no binary fixture is committed to the repo. Assumes a
// little-endian host (all Apple targets are), matching the WAV byte order.
NSURL *write_temp_silence_wav(double seconds) {
  const uint32_t sample_rate = 8000;
  const uint16_t channels = 1;
  const uint16_t bits_per_sample = 16;
  const uint16_t block_align = channels * (bits_per_sample / 8);
  const uint32_t byte_rate = sample_rate * block_align;
  const uint32_t data_bytes =
      static_cast<uint32_t>(sample_rate * seconds) * block_align;
  const uint32_t riff_size = 36 + data_bytes;

  NSMutableData *wav = [NSMutableData data];
  void (^put32)(uint32_t) = ^(uint32_t v) { [wav appendBytes:&v length:4]; };
  void (^put16)(uint16_t) = ^(uint16_t v) { [wav appendBytes:&v length:2]; };

  [wav appendBytes:"RIFF" length:4];
  put32(riff_size);
  [wav appendBytes:"WAVE" length:4];
  [wav appendBytes:"fmt " length:4];
  put32(16);       // PCM fmt chunk size
  put16(1);        // audio format: PCM
  put16(channels);
  put32(sample_rate);
  put32(byte_rate);
  put16(block_align);
  put16(bits_per_sample);
  [wav appendBytes:"data" length:4];
  put32(data_bytes);
  [wav increaseLengthBy:data_bytes];  // zero-filled samples == silence

  NSURL *url = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
      URLByAppendingPathComponent:@"scribe_playbackengine_test.wav"];
  return [wav writeToURL:url atomically:YES] ? url : nil;
}

}  // namespace

TEST_CASE("PlaybackEngine clearMedia reports no media on a fresh engine",
          "[PlaybackEngine][clearMedia]") {
  @autoreleasepool {
    PlaybackEngine *engine = [[PlaybackEngine alloc] init];

    REQUIRE([engine clearMedia] == NO);
    REQUIRE(engine.hasMedia == NO);
    REQUIRE(engine.position == 0.0);
    REQUIRE(engine.duration == 0.0);
    REQUIRE(engine.isPlaying == NO);
  }
}

TEST_CASE("PlaybackEngine clearMedia releases loaded media and resets state",
          "[PlaybackEngine][clearMedia]") {
  @autoreleasepool {
    NSURL *url = write_temp_silence_wav(0.2);
    REQUIRE(url != nil);

    PlaybackEngine *engine = [[PlaybackEngine alloc] init];
    NSError *error = nil;
    REQUIRE([engine openURL:url error:&error] == YES);
    REQUIRE(error == nil);
    REQUIRE(engine.hasMedia == YES);
    REQUIRE(engine.duration > 0.0);

    REQUIRE([engine clearMedia] == YES);

    // The regression: every state accessor keys off the player, so releasing it
    // must return them all to empty (previously the player was left non-nil).
    REQUIRE(engine.hasMedia == NO);
    REQUIRE(engine.position == 0.0);
    REQUIRE(engine.duration == 0.0);
    REQUIRE(engine.isPlaying == NO);

    // Idempotent: a second clear has nothing left to release.
    REQUIRE([engine clearMedia] == NO);

    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
  }
}
