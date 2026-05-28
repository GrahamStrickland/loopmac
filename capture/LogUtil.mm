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

#import "LogUtil.h"

void Log(const std::string &message, const std::string &level) {
  // Format the message
  NSString *formattedMessage = [NSString
      stringWithFormat:@"[capture] [%@] \033[38;5;141m%@\033[0m",
                       [NSString stringWithUTF8String:level.c_str()],
                       [NSString stringWithUTF8String:message.c_str()]];

  // Log to system log, it also prints to console
  NSLog(@"%@", formattedMessage);
}
