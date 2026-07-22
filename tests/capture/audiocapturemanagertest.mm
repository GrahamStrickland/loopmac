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

#import "audiocapturemanager.h"
#import <Foundation/Foundation.h>

#include <catch2/catch_approx.hpp>
#include <catch2/catch_test_macros.hpp>

#include <atomic>
#include <chrono>
#include <cmath>
#include <future>
#include <memory>
#include <vector>

namespace {
bool is_valid_status(int status) {
  switch (status) {
  case 0:
  case 1:
  case 2:
    return true;
  }
  return false;
}

// Incremented by CallbackSentinel's dealloc so tests can observe exactly when
// the block that captured it is released.
std::atomic<int> sentinel_dealloc_count{0};
} // namespace

// Resampling is an implementation detail of the capture path, so it is not
// declared in the public header. Redeclaring it here lets the tests exercise
// it directly; the implementation lives in audiocapturemanager.mm.
@interface AudioCaptureManager (Testing)
- (Float32 *)resampleBuffer:(Float32 *)inputBuffer
                inputFrames:(UInt32)inputFrames
               outputFrames:(UInt32 *)outputFrames;
@end

// Sentinel whose lifetime tracks the lifetime of the block that captures it.
@interface CallbackSentinel : NSObject
@end

@implementation CallbackSentinel
- (void)dealloc {
  sentinel_dealloc_count.fetch_add(1);
  [super dealloc];
}
@end

// Exposes the source format so resampling can be tested without a live
// aggregate device, which would otherwise be the only thing that sets it.
@interface ResamplingTestManager : AudioCaptureManager
- (void)setTestSourceSampleRate:(Float64)sampleRate;
@end

@implementation ResamplingTestManager
- (void)setTestSourceSampleRate:(Float64)sampleRate {
  _sourceFormat.mSampleRate = sampleRate;
  _sourceFormat.mChannelsPerFrame = 1;
}
@end

TEST_CASE("AudioCaptureManager sharedInstance returns the same singleton",
          "[AudioCaptureManager][sharedInstance]") {
  @autoreleasepool {
    AudioCaptureManager *first = [AudioCaptureManager sharedInstance];
    AudioCaptureManager *second = [AudioCaptureManager sharedInstance];
    REQUIRE(first != nil);
    REQUIRE(first == second);
  }
}

TEST_CASE("AudioCaptureManager starts and stops audio capture correctly",
          "[AudioCaptureManager][start/stopCapture]") {
  @autoreleasepool {
    AudioCaptureManager *manager = [AudioCaptureManager sharedInstance];

    if ([manager checkTCCPermission:@"kTCCServiceAudioCapture"] != 0) {
      SKIP("startCapture requires audio capture permission, which "
           "cannot be granted in a non-interactive environment such as CI.");
    }

    NSError *error = nil;
    BOOL startResult = [manager startCapture:&error];
    REQUIRE(startResult == YES);
    REQUIRE(error == nil);

    BOOL stopResult = [manager stopCapture:&error];
    REQUIRE(stopResult == YES);
    REQUIRE(error == nil);

    stopResult = [manager stopCapture:&error];
    REQUIRE(stopResult == YES);
    REQUIRE(error == nil);
  }
}

TEST_CASE(
    "AudioCaptureManager setupAudioTapIfNeeded succeeds and is idempotent",
    "[AudioCaptureManager][setupAudioTapIfNeeded]") {
  @autoreleasepool {
    AudioCaptureManager *manager = [AudioCaptureManager sharedInstance];

    if ([manager checkTCCPermission:@"kTCCServiceAudioCapture"] != 0) {
      SKIP("setupAudioTapIfNeeded requires audio capture permission, which "
           "cannot be granted in a non-interactive environment such as CI.");
    }

    NSError *firstError = nil;
    BOOL firstResult = [manager setupAudioTapIfNeeded:&firstError];
    REQUIRE(firstResult == YES);
    REQUIRE(firstError == nil);

    NSError *secondError = nil;
    BOOL secondResult = [manager setupAudioTapIfNeeded:&secondError];
    REQUIRE(secondResult == YES);
    REQUIRE(secondError == nil);
  }
}

TEST_CASE("AudioCaptureManager setupAggregateDeviceIfNeeded succeeds and is "
          "idempotent",
          "[AudioCaptureManager][setupAggregateDeviceIfNeeded]") {
  @autoreleasepool {
    AudioCaptureManager *manager = [AudioCaptureManager sharedInstance];

    if ([manager checkTCCPermission:@"kTCCServiceAudioCapture"] != 0) {
      SKIP("setupAggregateDeviceIfNeeded requires audio capture permission, "
           "which "
           "cannot be granted in a non-interactive environment such as CI.");
    }

    NSError *firstError = nil;
    BOOL firstResult = [manager setupAggregateDeviceIfNeeded:&firstError];
    REQUIRE(firstResult == YES);
    REQUIRE(firstError == nil);

    NSError *secondError = nil;
    BOOL secondResult = [manager setupAggregateDeviceIfNeeded:&secondError];
    REQUIRE(secondResult == YES);
    REQUIRE(secondError == nil);
  }
}

TEST_CASE("AudioCaptureManager checkTCCPermission returns a valid status",
          "[AudioCaptureManager][checkTCCPermission]") {
  @autoreleasepool {
    AudioCaptureManager *manager = [AudioCaptureManager sharedInstance];
    auto result = [manager checkTCCPermission:@"kTCCServiceAudioCapture"];
    REQUIRE(is_valid_status(result));
  }
}

TEST_CASE("AudioCaptureManager requestTCCPermission resolves via callback",
          "[AudioCaptureManager][requestTCCPermission]") {
  @autoreleasepool {
    AudioCaptureManager *manager = [AudioCaptureManager sharedInstance];

    // shared_ptr so the promise outlives this scope: on timeout we SKIP and
    // return, but the callback may still fire later (writing to the promise).
    auto promise = std::make_shared<std::promise<BOOL>>();
    auto result_future = promise->get_future();

    [manager requestTCCPermission:@"kTCCServiceAudioCapture"
                       completion:^(BOOL granted) {
                         promise->set_value(granted);
                       }];

    if (result_future.wait_for(std::chrono::seconds(5)) !=
        std::future_status::ready) {
      SKIP("requestTCCPermission did not resolve within the timeout; this "
           "requires an interactive system permission prompt that cannot be "
           "answered in a non-interactive environment such as CI.");
    }

    (void)result_future.get();
    SUCCEED();
  }
}

TEST_CASE("AudioCaptureManager releases the previous audio data callback",
          "[AudioCaptureManager][setAudioDataCallback]") {
  @autoreleasepool {
    AudioCaptureManager *manager = [[AudioCaptureManager alloc] init];
    sentinel_dealloc_count.store(0);

    CallbackSentinel *sentinel = [[CallbackSentinel alloc] init];
    [manager setAudioDataCallback:^(NSData *audioData) {
      (void)audioData;
      (void)sentinel;
    }];

    // Copying the block onto the heap retained the sentinel, so dropping our
    // own reference leaves the installed callback as its only owner.
    [sentinel release];
    REQUIRE(sentinel_dealloc_count.load() == 0);

    // Installing a second callback must release the first one rather than
    // simply overwriting the pointer, which would leak it under manual
    // retain/release.
    [manager setAudioDataCallback:^(NSData *audioData) {
      (void)audioData;
    }];
    REQUIRE(sentinel_dealloc_count.load() == 1);

    [manager release];
  }
}

TEST_CASE("AudioCaptureManager releases its audio data callback on dealloc",
          "[AudioCaptureManager][setAudioDataCallback]") {
  @autoreleasepool {
    AudioCaptureManager *manager = [[AudioCaptureManager alloc] init];
    sentinel_dealloc_count.store(0);

    CallbackSentinel *sentinel = [[CallbackSentinel alloc] init];
    [manager setAudioDataCallback:^(NSData *audioData) {
      (void)audioData;
      (void)sentinel;
    }];
    [sentinel release];
    REQUIRE(sentinel_dealloc_count.load() == 0);

    [manager release];
    REQUIRE(sentinel_dealloc_count.load() == 1);
  }
}

TEST_CASE("AudioCaptureManager resampleBuffer fills exactly the frames it "
          "reports",
          "[AudioCaptureManager][resampleBuffer]") {
  @autoreleasepool {
    ResamplingTestManager *manager = [[ResamplingTestManager alloc] init];
    [manager setTestSourceSampleRate:44100.0];

    const UInt32 inputFrames = 1024;
    auto input = std::vector<Float32>(inputFrames, 0.5f);

    UInt32 outputFrames = 0;
    Float32 *output = [manager resampleBuffer:input.data()
                                  inputFrames:inputFrames
                                 outputFrames:&outputFrames];
    REQUIRE(output != NULL);

    // 44100 Hz down to the 22050 Hz target halves the frame count. The buffer
    // is allocated with exactly this many elements, so writing index
    // outputFrames would run past the end of the allocation.
    REQUIRE(outputFrames == inputFrames / 2);

    for (UInt32 i = 0; i < outputFrames; ++i) {
      REQUIRE(std::isfinite(output[i]));
    }

    // The sinc weights are normalised by their own sum, so a constant input
    // resamples to the same constant.
    for (UInt32 i = 0; i < outputFrames; ++i) {
      REQUIRE(output[i] == Catch::Approx(0.5f).margin(0.001));
    }

    free(output);
    [manager release];
  }
}

TEST_CASE("AudioCaptureManager resampleBuffer rejects input too short to "
          "resample",
          "[AudioCaptureManager][resampleBuffer]") {
  @autoreleasepool {
    ResamplingTestManager *manager = [[ResamplingTestManager alloc] init];
    [manager setTestSourceSampleRate:44100.0];

    // One input frame downsamples to zero output frames, which cannot be
    // allocated or filled.
    auto input = std::vector<Float32>(1, 0.5f);

    UInt32 outputFrames = 0;
    Float32 *output = [manager resampleBuffer:input.data()
                                  inputFrames:1
                                 outputFrames:&outputFrames];
    REQUIRE(output == NULL);
    REQUIRE(outputFrames == 0);

    [manager release];
  }
}
