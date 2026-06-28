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

#import "MainWindowController.h"

#import "PlaybackControlView.h"
#import "PlaybackEngine.h"

@implementation MainWindowController {
  PlaybackEngine *_engine;
  PlaybackControlView *_controlView;
}

- (instancetype)init {
  NSRect frame = NSMakeRect(0, 0, 1280, 720);
  NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                            NSWindowStyleMaskMiniaturizable |
                            NSWindowStyleMaskResizable;
  NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                styleMask:style
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
  window.title = @"LoopMac";
  window.minSize = NSMakeSize(960, 540);
  [window center];

  if ((self = [super initWithWindow:window])) {
    _engine = [[PlaybackEngine alloc] init];
    [self buildContentView];
  }
  return self;
}

- (void)buildContentView {
  NSView *content = self.window.contentView;

  // Dark "stage" area; double-click toggles full screen.
  NSView *stage = [[NSView alloc] initWithFrame:NSZeroRect];
  stage.wantsLayer = YES;
  stage.layer.backgroundColor = NSColor.blackColor.CGColor;
  stage.translatesAutoresizingMaskIntoConstraints = NO;

  NSClickGestureRecognizer *doubleClick = [[NSClickGestureRecognizer alloc]
      initWithTarget:self
              action:@selector(toggleFullScreen:)];
  doubleClick.numberOfClicksRequired = 2;
  [stage addGestureRecognizer:doubleClick];

  _controlView = [[PlaybackControlView alloc] initWithEngine:_engine];
  _controlView.translatesAutoresizingMaskIntoConstraints = NO;

  [content addSubview:stage];
  [content addSubview:_controlView];

  [NSLayoutConstraint activateConstraints:@[
    [stage.topAnchor constraintEqualToAnchor:content.topAnchor],
    [stage.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
    [stage.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
    [stage.bottomAnchor constraintEqualToAnchor:_controlView.topAnchor],

    [_controlView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
    [_controlView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
    [_controlView.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
    [_controlView.heightAnchor constraintEqualToConstant:168],
  ]];
}

- (void)toggleFullScreen:(id)sender {
  [self.window toggleFullScreen:sender];
}

@end
