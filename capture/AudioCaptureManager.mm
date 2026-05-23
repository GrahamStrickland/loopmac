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

@interface AudioCaptureManager () {
}
@end

@implementation AudioCaptureManager

#pragma mark - Singleton

static AudioCaptureManager *sharedInstance = nil;

+ (instancetype)sharedInstance {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    [self initializeTCCFramework];
  }

  if ([self checkTCCPermission:@"kTCCServiceAudioCapture"] == 0) {
  }

  return self;
}

- (void)dealloc {
  if (_tccHandle) {
    dlclose(_tccHandle);
  }
  [super dealloc];
}

#pragma mark - TCC Framework Methods

- (void)initializeTCCFramework {
  // Load TCC framework
  NSString *tccPath =
      @"/System/Library/PrivateFrameworks/TCC.framework/Versions/A/TCC";
  _tccHandle = dlopen([tccPath UTF8String], RTLD_NOW);
  if (!_tccHandle) {
    return;
  }

  // Get function pointers
  _preflightFunc =
      (TCCPreflightFuncType)dlsym(_tccHandle, "TCCAccessPreflight");
  _requestFunc = (TCCRequestFuncType)dlsym(_tccHandle, "TCCAccessRequest");

  if (!_preflightFunc || !_requestFunc) {
    dlclose(_tccHandle);
    _tccHandle = NULL;
    return;
  }
}

- (PermissionStatus)checkTCCPermission:(NSString *)service {
  if (!_preflightFunc) {
    return PermissionStatusNotDetermined; // Not determined
  }

  auto result =
      (PermissionStatus)_preflightFunc((__bridge CFStringRef)service, NULL);
  return result;
}

- (void)requestTCCPermission:(NSString *)service
                  completion:(void (^)(BOOL granted))completion {
  if (!_requestFunc) {
    completion(NO);
    return;
  }

  _requestFunc((__bridge CFStringRef)service, NULL, ^(BOOL granted) {
    completion(granted);
  });
}

#pragma mark - Permission Methods

- (PermissionStatus)getPermission {
  // Check audio recording permission using TCC
  auto audioResult =
      (PermissionStatus)[self checkTCCPermission:@"kTCCServiceAudioCapture"];
  return audioResult;
}

- (void)requestPermission:(void (^)(PermissionStatus))completion {
  [self requestTCCPermission:@"kTCCServiceAudioCapture"
                  completion:^(BOOL granted) {
                    auto status =
                        granted ? PermissionStatus::PermissionStatusAuthorized
                                : PermissionStatus::PermissionStatusDenied;
                    completion(status);
                  }];
}
@end
