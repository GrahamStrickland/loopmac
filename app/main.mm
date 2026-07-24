#import <AppKit/AppKit.h>

#import "appdelegate.h"

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSApplication *app = [NSApplication sharedApplication];
    app.activationPolicy = NSApplicationActivationPolicyRegular;

    // Held for the lifetime of the run loop; NSApplication.delegate is weak.
    AppDelegate *delegate = [[AppDelegate alloc] init];
    app.delegate = delegate;

    [app run];
  }
  return 0;
}
