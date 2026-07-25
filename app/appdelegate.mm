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

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)sender {
  return YES;
}

- (void)buildMenuBar {
  NSString *appName = @"Scribe";
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
  [windowMenu addItemWithTitle:@"Zoom"
                        action:@selector(performZoom:)
                 keyEquivalent:@""];
  windowMenuItem.submenu = windowMenu;
  NSApp.windowsMenu = windowMenu;

  NSApp.mainMenu = menuBar;
}

@end
