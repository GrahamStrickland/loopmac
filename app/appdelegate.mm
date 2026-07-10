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

#import "appdelegate.h"

#import "mainwindowcontroller.h"

@implementation AppDelegate {
  MainWindowController *_windowController;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  [self buildMenuBar];

  _windowController = [[MainWindowController alloc] init];
  [_windowController showWindow:nil];
  [_windowController.window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  return YES;
}

- (void)buildMenuBar {
  NSString *appName = @"LoopMac";
  NSMenu *menuBar = [[NSMenu alloc] init];

  // Application menu.
  NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
  [menuBar addItem:appMenuItem];
  NSMenu *appMenu = [[NSMenu alloc] init];
  [appMenu addItemWithTitle:[@"About " stringByAppendingString:appName]
                     action:@selector(orderFrontStandardAboutPanel:)
              keyEquivalent:@""];
  [appMenu addItem:[NSMenuItem separatorItem]];
  [appMenu addItemWithTitle:[@"Hide " stringByAppendingString:appName]
                     action:@selector(hide:)
              keyEquivalent:@"h"];
  [appMenu addItem:[NSMenuItem separatorItem]];
  [appMenu addItemWithTitle:[@"Quit " stringByAppendingString:appName]
                     action:@selector(terminate:)
              keyEquivalent:@"q"];
  appMenuItem.submenu = appMenu;

  // File menu.
  NSMenuItem *fileMenuItem = [[NSMenuItem alloc] init];
  [menuBar addItem:fileMenuItem];
  NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
  [fileMenu addItemWithTitle:@"Open…"
                      action:@selector(openDocument:)
               keyEquivalent:@"o"];
  [fileMenu addItem:[NSMenuItem separatorItem]];
  [fileMenu addItemWithTitle:@"Close"
                      action:@selector(performClose:)
               keyEquivalent:@"w"];
  fileMenuItem.submenu = fileMenu;

  // Window menu.
  NSMenuItem *windowMenuItem = [[NSMenuItem alloc] init];
  [menuBar addItem:windowMenuItem];
  NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
  [windowMenu addItemWithTitle:@"Minimize"
                        action:@selector(performMiniaturize:)
                 keyEquivalent:@"m"];
  [windowMenu addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
  windowMenuItem.submenu = windowMenu;
  NSApp.windowsMenu = windowMenu;

  NSApp.mainMenu = menuBar;
}

@end
