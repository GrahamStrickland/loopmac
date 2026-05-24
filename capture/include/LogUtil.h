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
 * @file LogUtil.h
 * @brief Logging utility for the native audio manager module.
 *
 * Provides a simple logging interface that can be used throughout the native
 * module to log messages with different severity levels. This utility helps
 * with debugging and monitoring the module's behavior.
 */

#import <Foundation/Foundation.h>
#import <string>

/**
 * @brief Log a message with a specified severity level.
 *
 * This function provides a consistent way to log messages across the native
 * module. It can be used for debugging, error reporting, and general status
 * updates.
 *
 * @param message The message to log
 * @param level The severity level of the message (default: "info")
 *              Supported levels: "info", "warn", "error", "debug"
 *
 * Example usage:
 * @code
 *   Log("Starting audio capture", "info");
 *   Log("Failed to initialize device", "error");
 * @endcode
 */
void Log(const std::string &message, const std::string &level = "info");
