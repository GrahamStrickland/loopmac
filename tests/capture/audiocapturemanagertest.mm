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

#import "AudioCaptureManager.h"
#import <Foundation/Foundation.h>

#include <catch2/catch_test_macros.hpp>

#include <chrono>
#include <future>
#include <memory>

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
} // namespace

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
