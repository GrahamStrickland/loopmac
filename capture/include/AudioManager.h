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

/**
 * @file AudioManager.h
 * @brief Handles macOS Core Audio device permissions.
 */

#import <Foundation/Foundation.h>
#import <dlfcn.h>

/**
 * @enum PermissionStatus
 * @brief Represents the current status of audio permission.
 */
typedef NS_ENUM(NSInteger, PermissionStatus) {
  PermissionStatusNotDetermined,
  PermissionStatusDenied,
  PermissionStatusAuthorized,
  PermissionStatusRestricted
};

// TCC function types
typedef int (*TCCPreflightFuncType)(CFStringRef service,
                                    CFDictionaryRef options);
typedef void (*TCCRequestFuncType)(CFStringRef service, CFDictionaryRef options,
                                   void (^completionHandler)(BOOL granted));

/**
 * @class AudioManager
 * @brief Manages permissions for audio device access and capture on macOS.
 */
@interface AudioManager : NSObject {
  void *_tccHandle;
  TCCPreflightFuncType _preflightFunc;
  TCCRequestFuncType _requestFunc;
}

/**
 * @brief returns the singleton instance of AudioManager
 * @return The shared AudioManager instance.
 */
+ (instancetype)sharedInstance;

/**
 * @name Permission Methods
 */

/**
 * @brief Get current permission status for audio devices.
 * @return String containing permission status.
 */
- (NSString *)getPermission;

/**
 * @brief Request permission to access system audio.
 * @param completion Block called with permission result.
 */
- (void)requestPermission:(void (^)(NSString *))completion;

/**
 * @name Private TCC (Transparency, Consent, and Control) Methods
 */

/**
 * @brief Intialize the TCC framework for permission handling.
 * @note This is called internally during initialization.
 */
- (void)initializeTCCFramework;

/**
 * @brief Check current TCC permission status for a service.
 * @param service The service identifier to check.
 * @return Integer representing the permission status.
 */
- (int)checkTCCPermission:(NSString *)service;

/**
 * @brief Request TCC permission for a specific service.
 * @param service The service identifier to request permission for.
 * @param completion Block called with the grant status.
 */
- (void)requestTCCPermission:(NSString *)service
                  completion:(void (^)(BOOL granted))completion;
@end
